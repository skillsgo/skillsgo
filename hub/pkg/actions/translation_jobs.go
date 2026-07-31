/*
 * [INPUT]: Depends on translation workers, the background Catalog, Skill content storage, River job semantics, and validated LLM configuration.
 * [OUTPUT]: Registers blocked-window-aware description/document dispatch, snoozable execution, failure finalization, and periodic scheduling on the Hub task runtime.
 * [POS]: Serves as the presentation-localization behavior-registration unit beneath the App composition root.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/riverqueue/river"
	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	"github.com/skillsgo/skillsgo/hub/pkg/taskqueue"
	"github.com/skillsgo/skillsgo/hub/pkg/translation"
)

func registerTranslationJobs(logger *log.Logger, conf *config.LLMConfig, metadata *catalog.Catalog, store storage.Backend, tasks *taskqueue.Runtime) error {
	if !conf.Enabled() {
		return nil
	}
	schedule, err := translation.NewExecutionSchedule(conf.TranslationTimeZone, conf.TranslationBlockedWindows)
	if err != nil {
		return fmt.Errorf("configure translation execution schedule: %w", err)
	}

	translator := translation.NewOpenAITranslator(conf.BaseURL, conf.APIKey, conf.Model)
	languageAnalyzer := translation.NewLanguageAnalyzer()
	descriptionWorker := translation.NewWorker(metadata, translator, languageAnalyzer, conf.TranslationLangs, conf.DescriptionPromptVersion, conf.TranslationBatch)
	documentWorker := translation.NewDocumentWorker(metadata, store, translator, languageAnalyzer, conf.TranslationLangs, conf.DocumentPromptVersion, conf.TranslationBatch)
	recordFailure := func(ctx context.Context, resourceKind, digest, lang, prompt, kind string, retryable bool, cause error) error {
		message := cause.Error()
		runes := []rune(message)
		if len(runes) > 2048 {
			message = string(runes[:2048])
		}
		return metadata.UpsertLocalizationFailure(ctx, catalog.LocalizationFailure{
			ResourceKind: resourceKind, SourceDigest: digest, Lang: lang, PromptVersion: prompt,
			ErrorKind: kind, ErrorMessage: message, Retryable: retryable,
		})
	}

	if err := taskqueue.Register(tasks, func(ctx context.Context, _ descriptionTranslationDispatchArgs) error {
		if schedule.Delay(time.Now()) > 0 {
			return nil
		}
		work, err := descriptionWorker.Plan(ctx)
		if err != nil {
			return err
		}
		for _, item := range work {
			if err := tasks.Enqueue(ctx, descriptionTranslationArgs{
				ResourceKind: item.ResourceKind, ResourceID: item.ResourceID, Description: item.Description,
				SourceDigest: item.SourceDigest, Lang: item.Lang, PromptVersion: item.PromptVersion,
			}, taskqueue.InsertOptions{Unique: true, MaxAttempts: 8, Queue: river.QueueDefault}); err != nil {
				return err
			}
		}
		logger.Infof("description translation dispatcher submitted %d localization jobs", len(work))
		return nil
	}); err != nil {
		return fmt.Errorf("register description translation dispatcher: %w", err)
	}
	if err := taskqueue.Register(tasks, func(ctx context.Context, args descriptionTranslationArgs) error {
		if delay := schedule.Delay(time.Now()); delay > 0 {
			return river.JobSnooze(delay)
		}
		err := descriptionWorker.RunOne(ctx, translation.DescriptionWork{
			ResourceKind: args.ResourceKind, ResourceID: args.ResourceID, Description: args.Description,
			SourceDigest: args.SourceDigest, Lang: args.Lang, PromptVersion: args.PromptVersion,
		})
		if translation.IsPermanent(err) {
			logger.Warnf("description translation permanently failed for %s to %s: %v", args.SourceDigest, args.Lang, err)
			if persistErr := recordFailure(ctx, args.ResourceKind, args.SourceDigest, args.Lang, args.PromptVersion, translation.FailureKind(err), false, err); persistErr != nil {
				return persistErr
			}
			return river.JobCancel(err)
		}
		if err != nil {
			logger.Warnf("description translation attempt failed for %s to %s: %v", args.SourceDigest, args.Lang, err)
		}
		return err
	}); err != nil {
		return fmt.Errorf("register description translation job: %w", err)
	}
	if err := taskqueue.RegisterFailureHandler(tasks, func(ctx context.Context, args descriptionTranslationArgs, cause error) error {
		return recordFailure(ctx, args.ResourceKind, args.SourceDigest, args.Lang, args.PromptVersion, translation.FailureKind(cause), true, cause)
	}); err != nil {
		return fmt.Errorf("register description translation failure handler: %w", err)
	}
	if err := taskqueue.Register(tasks, func(ctx context.Context, _ documentTranslationDispatchArgs) error {
		if schedule.Delay(time.Now()) > 0 {
			return nil
		}
		work, err := documentWorker.Plan(ctx)
		if err != nil {
			return err
		}
		for _, item := range work {
			if err := tasks.Enqueue(ctx, documentTranslationArgs{
				SourceDigest: item.SourceDigest, Lang: item.Lang, PromptVersion: item.PromptVersion,
			}, taskqueue.InsertOptions{Unique: true, MaxAttempts: 8, Queue: river.QueueDefault}); err != nil {
				return err
			}
		}
		logger.Infof("document translation dispatcher submitted %d localization jobs", len(work))
		return nil
	}); err != nil {
		return fmt.Errorf("register document translation dispatcher: %w", err)
	}
	if err := taskqueue.Register(tasks, func(ctx context.Context, args documentTranslationArgs) error {
		if delay := schedule.Delay(time.Now()); delay > 0 {
			return river.JobSnooze(delay)
		}
		err := documentWorker.RunOne(ctx, translation.DocumentWork{SourceDigest: args.SourceDigest, Lang: args.Lang, PromptVersion: args.PromptVersion})
		if translation.IsPermanent(err) {
			logger.Warnf("document translation permanently failed for %s to %s: %v", args.SourceDigest, args.Lang, err)
			if persistErr := recordFailure(ctx, catalog.LocalizedSkillDocument, args.SourceDigest, args.Lang, args.PromptVersion, translation.FailureKind(err), false, err); persistErr != nil {
				return persistErr
			}
			return river.JobCancel(err)
		}
		if err != nil {
			logger.Warnf("document translation attempt failed for %s to %s: %v", args.SourceDigest, args.Lang, err)
		}
		return err
	}); err != nil {
		return fmt.Errorf("register document translation job: %w", err)
	}
	if err := taskqueue.RegisterFailureHandler(tasks, func(ctx context.Context, args documentTranslationArgs, cause error) error {
		return recordFailure(ctx, catalog.LocalizedSkillDocument, args.SourceDigest, args.Lang, args.PromptVersion, translation.FailureKind(cause), true, cause)
	}); err != nil {
		return fmt.Errorf("register document translation failure handler: %w", err)
	}
	if err := tasks.Every(descriptionTranslationDispatchArgs{}, taskqueue.InsertOptions{Unique: true, MaxAttempts: 3, Queue: taskqueue.QueueMaintenance}, time.Duration(conf.TranslationInterval)*time.Second, true); err != nil {
		return fmt.Errorf("register description translation dispatcher: %w", err)
	}
	if err := tasks.Every(documentTranslationDispatchArgs{}, taskqueue.InsertOptions{Unique: true, MaxAttempts: 3, Queue: taskqueue.QueueMaintenance}, time.Duration(conf.TranslationInterval)*time.Second, true); err != nil {
		return fmt.Errorf("register document translation dispatcher: %w", err)
	}
	logger.Infof("presentation localization enabled with model %s for languages %s", conf.Model, strings.Join(conf.TranslationLangs, ","))
	return nil
}
