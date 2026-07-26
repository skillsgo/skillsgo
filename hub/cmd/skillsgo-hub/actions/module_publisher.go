/*
 * [INPUT]: Depends on request-scoped structured logging, one resolved Repository snapshot, and the ordered immutable publication commit boundary.
 * [OUTPUT]: Materializes every accepted Module Skill, prepares byte-stable Module Version Info plus direct Skill content objects, and emits a correlated bounded publication lifecycle without logging credentials or artifact content.
 * [POS]: Serves as the observable cold-publication coordinator between Git Repository discovery, artifact storage, and Module Info visibility.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"sync"
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	huberrors "github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	"github.com/skillsgo/skillsgo/hub/pkg/skill"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	protocolapi "github.com/skillsgo/skillsgo/protocol/api"
	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
	"golang.org/x/sync/singleflight"
)

type repositoryMaterializer interface {
	Materialize(ctx context.Context, modulePath, query string) (string, error)
}

type historicalRepositoryMaterializer interface {
	MaterializeHistorical(ctx context.Context, modulePath, query string) (string, error)
}

type modulePublisher struct {
	fetcher     skill.RepositoryFetcher
	publication *modulePublicationCommit
	work        singleflight.Group
	commit      singleflight.Group
	upstream    chan struct{}
	mu          sync.Mutex
	negative    map[string]negativePublication
	now         func() time.Time
	negativeTTL time.Duration
}

type negativePublication struct {
	expires time.Time
	err     error
}

func newModulePublisher(fetcher skill.RepositoryFetcher, backend storage.Backend, metadata *catalog.Catalog) *modulePublisher {
	return &modulePublisher{fetcher: fetcher, publication: newModulePublicationCommit(backend, metadata), upstream: make(chan struct{}, 8), negative: make(map[string]negativePublication), now: time.Now, negativeTTL: 10 * time.Second}
}

func (p *modulePublisher) Materialize(ctx context.Context, modulePath, query string) (string, error) {
	return p.materializePublication(ctx, modulePath, query, catalog.CurrentPublication)
}

func (p *modulePublisher) MaterializeHistorical(ctx context.Context, modulePath, query string) (string, error) {
	return p.materializePublication(ctx, modulePath, query, catalog.HistoricalPublication)
}

func (p *modulePublisher) VerifyHistorical(ctx context.Context, modulePath, query, expectedCommitSHA string) error {
	snapshot, err := p.fetcher.DiscoverRepository(ctx, modulePath, query)
	if err != nil {
		return err
	}
	defer closeRepositorySnapshot(snapshot)
	if snapshot.ModulePath != modulePath || snapshot.Version != query || snapshot.CommitSHA == "" {
		return fmt.Errorf("Repository source returned an invalid snapshot for %s@%s", modulePath, query)
	}
	if snapshot.CommitSHA != expectedCommitSHA {
		return fmt.Errorf("immutable Module Version conflict for %s@%s", modulePath, query)
	}
	return nil
}

func (p *modulePublisher) materializePublication(ctx context.Context, modulePath, query string, visibility catalog.PublicationVisibility) (string, error) {
	started := time.Now()
	key := "publish:" + string(visibility) + ":" + modulePath + "@" + query
	entry := log.EntryFromContext(ctx).WithFields(map[string]any{
		"component":     "module_publisher",
		"module_path":   modulePath,
		"requested_ref": query,
	})
	entry.Debugf("repository publication requested")
	p.mu.Lock()
	negative, cached := p.negative[key]
	if cached && p.now().Before(negative.expires) {
		p.mu.Unlock()
		entry.WithFields(map[string]any{
			"cache":       "negative",
			"duration_ms": time.Since(started).Milliseconds(),
		}).Debugf("repository publication cache hit")
		return "", negative.err
	}
	if cached {
		delete(p.negative, key)
	}
	p.mu.Unlock()
	result := p.work.DoChan(key, func() (any, error) {
		entry.Debugf("repository publication started")
		workCtx, cancel := context.WithTimeout(context.WithoutCancel(ctx), 15*time.Minute)
		defer cancel()
		select {
		case p.upstream <- struct{}{}:
			defer func() { <-p.upstream }()
		default:
			entry.Warnf("repository publication upstream capacity exhausted")
			return "", huberrors.E("modulePublisher.Materialize", "upstream Repository resolution is at capacity", huberrors.KindRateLimit)
		}
		version, materializeErr := p.materialize(workCtx, modulePath, query, visibility)
		if materializeErr != nil && huberrors.IsNotFoundErr(materializeErr) {
			p.mu.Lock()
			p.negative[key] = negativePublication{expires: p.now().Add(p.negativeTTL), err: materializeErr}
			p.mu.Unlock()
		}
		return version, materializeErr
	})
	select {
	case <-ctx.Done():
		return "", ctx.Err()
	case resolved := <-result:
		if resolved.Err != nil {
			failed := entry.WithFields(map[string]any{
				"duration_ms":         time.Since(started).Milliseconds(),
				"singleflight_shared": resolved.Shared,
			})
			switch {
			case huberrors.IsNotFoundErr(resolved.Err):
				failed.Infof("repository publication not found")
			case huberrors.Kind(resolved.Err) == huberrors.KindRateLimit:
				failed.Warnf("repository publication rate limited")
			default:
				failed.SystemErr(resolved.Err)
			}
			return "", resolved.Err
		}
		version := resolved.Val.(string)
		entry.WithFields(map[string]any{
			"duration_ms":         time.Since(started).Milliseconds(),
			"singleflight_shared": resolved.Shared,
			"version":             version,
		}).Infof("repository publication completed")
		return version, nil
	}
}

func (p *modulePublisher) materialize(ctx context.Context, modulePath, query string, visibility catalog.PublicationVisibility) (string, error) {
	started := time.Now()
	snapshot, err := p.fetcher.DiscoverRepository(ctx, modulePath, query)
	if err != nil {
		return "", err
	}
	if snapshot.ModulePath != modulePath || snapshot.Version == "" || snapshot.CommitSHA == "" || len(snapshot.Members) == 0 {
		closeRepositorySnapshot(snapshot)
		return "", fmt.Errorf("Repository source returned an invalid snapshot for %s@%s", modulePath, query)
	}
	log.EntryFromContext(ctx).WithFields(map[string]any{
		"commit_sha":   snapshot.CommitSHA,
		"duration_ms":  time.Since(started).Milliseconds(),
		"member_count": len(snapshot.Members),
		"module_path":  modulePath,
		"version":      snapshot.Version,
	}).Debugf("repository snapshot discovered")
	invoked := false
	result, err, _ := p.commit.Do("commit:"+string(visibility)+":"+modulePath+"@"+snapshot.Version, func() (any, error) {
		invoked = true
		return p.publishSnapshot(ctx, modulePath, query, snapshot, visibility)
	})
	if !invoked {
		closeRepositorySnapshot(snapshot)
	}
	if err != nil {
		return "", err
	}
	return result.(string), nil
}

func (p *modulePublisher) publishSnapshot(ctx context.Context, modulePath, query string, snapshot *skill.RepositorySnapshot, visibility catalog.PublicationVisibility) (string, error) {
	if snapshot.Archive == nil || snapshot.ArchiveSize <= 0 || snapshot.Sum == "" || snapshot.Ref == "" || snapshot.TreeSHA == "" {
		return "", fmt.Errorf("Repository source returned an incomplete Artifact for %s@%s", modulePath, query)
	}
	archive, err := io.ReadAll(io.LimitReader(snapshot.Archive, protocolartifact.MaxArchiveBytes+1))
	if err != nil {
		return "", fmt.Errorf("read Module Artifact: %w", err)
	}
	if int64(len(archive)) != snapshot.ArchiveSize || len(archive) > protocolartifact.MaxArchiveBytes {
		return "", fmt.Errorf("Module Artifact size mismatch for %s@%s", modulePath, snapshot.Version)
	}
	if sum, sumErr := protocolartifact.ModuleSum(archive, modulePath, snapshot.Version); sumErr != nil || sum != snapshot.Sum {
		return "", fmt.Errorf("Module Artifact Sum mismatch for %s@%s", modulePath, snapshot.Version)
	}

	published := make([]catalog.Skill, 0, len(snapshot.Members))
	skillContents := make([]moduleSkillContent, 0, len(snapshot.Members))
	release := protocolapi.ModuleInfo{
		SchemaVersion: protocolapi.SchemaVersion,
		Kind:          protocolapi.KindModule,
		ModulePath:    modulePath,
		Version:       snapshot.Version,
		Time:          snapshot.CommitTime,
		Sum:           snapshot.Sum,
		ArchiveSize:   snapshot.ArchiveSize,
		Skills:        make([]protocolapi.ModuleSkill, 0, len(snapshot.Members)),
	}
	for _, member := range snapshot.Members {
		if member.Path == "" || member.TreeSHA == "" || member.Manifest.Name == "" || member.Manifest.Description == "" || len(member.Content) == 0 {
			return "", fmt.Errorf("Repository source returned an invalid member for %s@%s", modulePath, query)
		}
		release.Skills = append(release.Skills, protocolapi.ModuleSkill{Name: member.Manifest.Name, Path: member.Path})
		published = append(published, catalog.Skill{
			ModulePath: modulePath, Path: member.Path, Name: member.Manifest.Name, Description: member.Manifest.Description,
		})
		skillContents = append(skillContents, moduleSkillContent{path: member.Path, content: member.Content})
	}
	releaseInfo, err := json.Marshal(release)
	if err != nil {
		return "", fmt.Errorf("encode Module Info: %w", err)
	}

	version := catalog.ModuleVersion{
		Version: snapshot.Version, Ref: snapshot.Ref, CommitSHA: snapshot.CommitSHA, TreeSHA: snapshot.TreeSHA,
		Sum: snapshot.Sum, ArchiveSize: snapshot.ArchiveSize, CommitTime: snapshot.CommitTime,
	}
	created, err := p.publication.Publish(ctx, modulePath, version, archive, snapshot.ArchiveMD5, releaseInfo, published, skillContents, visibility)
	if err != nil {
		return "", err
	}
	log.EntryFromContext(ctx).WithFields(map[string]any{
		"member_count":       len(snapshot.Members),
		"new_artifact_count": map[bool]int{true: 1, false: 0}[created],
		"module_path":        modulePath,
		"version":            snapshot.Version,
	}).Debugf("repository publication committed")
	return snapshot.Version, nil
}

func closeRepositorySnapshot(snapshot *skill.RepositorySnapshot) {
	if snapshot == nil {
		return
	}
	if snapshot.Archive != nil {
		_ = snapshot.Archive.Close()
	}
}
