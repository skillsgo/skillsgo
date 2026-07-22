/*
 * [INPUT]: Depends on request-scoped structured logging, one resolved Repository snapshot, immutable artifact storage, and enriched per-Skill protocol indexing.
 * [OUTPUT]: Materializes every accepted Repository member, commits its byte-stable Repository Release Record, and emits a correlated bounded publication lifecycle without logging credentials or artifact content.
 * [POS]: Serves as the observable cold-publication coordinator between Git Repository discovery, artifact storage, and Repository Info visibility.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"context"
	"encoding/json"
	"fmt"
	"sync"
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/skillsgo/skillsgo/hub/pkg/download"
	huberrors "github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	"github.com/skillsgo/skillsgo/hub/pkg/skill"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	protocolapi "github.com/skillsgo/skillsgo/protocol/api"
	"golang.org/x/sync/singleflight"
)

type repositoryMaterializer interface {
	Materialize(ctx context.Context, repositoryID, query string) (string, error)
}

type historicalRepositoryMaterializer interface {
	MaterializeHistorical(ctx context.Context, repositoryID, query string) (string, error)
}

type repositoryPublisher struct {
	fetcher     skill.RepositoryFetcher
	storage     storage.Backend
	protocol    download.Protocol
	metadata    *catalog.Catalog
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

func newRepositoryPublisher(fetcher skill.RepositoryFetcher, backend storage.Backend, protocol download.Protocol, metadata *catalog.Catalog) *repositoryPublisher {
	backend = storage.WithImmutableWrites(backend)
	return &repositoryPublisher{fetcher: fetcher, storage: backend, protocol: protocol, metadata: metadata, upstream: make(chan struct{}, 8), negative: make(map[string]negativePublication), now: time.Now, negativeTTL: 10 * time.Second}
}

func (p *repositoryPublisher) Materialize(ctx context.Context, repositoryID, query string) (string, error) {
	return p.materializePublication(ctx, repositoryID, query, catalog.CurrentPublication)
}

func (p *repositoryPublisher) MaterializeHistorical(ctx context.Context, repositoryID, query string) (string, error) {
	return p.materializePublication(ctx, repositoryID, query, catalog.HistoricalPublication)
}

func (p *repositoryPublisher) VerifyHistorical(ctx context.Context, repositoryID, query, expectedCommitSHA string) error {
	snapshot, err := p.fetcher.DiscoverRepository(ctx, repositoryID, query)
	if err != nil {
		return err
	}
	defer closeRepositorySnapshot(snapshot)
	if snapshot.RepositoryID != repositoryID || snapshot.Version != query || snapshot.CommitSHA == "" {
		return fmt.Errorf("Repository source returned an invalid snapshot for %s@%s", repositoryID, query)
	}
	if snapshot.CommitSHA != expectedCommitSHA {
		return fmt.Errorf("immutable Repository version conflict for %s@%s", repositoryID, query)
	}
	return nil
}

func (p *repositoryPublisher) materializePublication(ctx context.Context, repositoryID, query string, visibility catalog.PublicationVisibility) (string, error) {
	started := time.Now()
	key := "publish:" + string(visibility) + ":" + repositoryID + "@" + query
	entry := log.EntryFromContext(ctx).WithFields(map[string]any{
		"component":     "repository_publisher",
		"repository_id": repositoryID,
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
			return "", huberrors.E("repositoryPublisher.Materialize", "upstream Repository resolution is at capacity", huberrors.KindRateLimit)
		}
		version, materializeErr := p.materialize(workCtx, repositoryID, query, visibility)
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

func (p *repositoryPublisher) materialize(ctx context.Context, repositoryID, query string, visibility catalog.PublicationVisibility) (string, error) {
	started := time.Now()
	snapshot, err := p.fetcher.DiscoverRepository(ctx, repositoryID, query)
	if err != nil {
		return "", err
	}
	if snapshot.RepositoryID != repositoryID || snapshot.Version == "" || snapshot.CommitSHA == "" || len(snapshot.Members) == 0 {
		closeRepositorySnapshot(snapshot)
		return "", fmt.Errorf("Repository source returned an invalid snapshot for %s@%s", repositoryID, query)
	}
	log.EntryFromContext(ctx).WithFields(map[string]any{
		"commit_sha":    snapshot.CommitSHA,
		"duration_ms":   time.Since(started).Milliseconds(),
		"member_count":  len(snapshot.Members),
		"repository_id": repositoryID,
		"version":       snapshot.Version,
	}).Debugf("repository snapshot discovered")
	invoked := false
	result, err, _ := p.commit.Do("commit:"+string(visibility)+":"+repositoryID+"@"+snapshot.Version, func() (any, error) {
		invoked = true
		return p.publishSnapshot(ctx, repositoryID, query, snapshot, visibility)
	})
	if !invoked {
		closeRepositorySnapshot(snapshot)
	}
	if err != nil {
		return "", err
	}
	return result.(string), nil
}

func (p *repositoryPublisher) publishSnapshot(ctx context.Context, repositoryID, query string, snapshot *skill.RepositorySnapshot, visibility catalog.PublicationVisibility) (string, error) {
	memberIDs := make([]string, 0, len(snapshot.Members))
	stored := make(map[string]bool, len(snapshot.Members))
	newlyStored := make([]string, 0, len(snapshot.Members))
	publicationCommitted := false
	defer func() {
		if publicationCommitted {
			return
		}
		cleanupCtx, cancel := context.WithTimeout(context.WithoutCancel(ctx), 30*time.Second)
		defer cancel()
		for index := len(newlyStored) - 1; index >= 0; index-- {
			if err := p.storage.Delete(cleanupCtx, newlyStored[index], snapshot.Version); err != nil {
				log.EntryFromContext(ctx).WithFields(map[string]any{
					"repository_id": repositoryID,
					"skill_id":      newlyStored[index],
					"version":       snapshot.Version,
				}).Warnf("repository publication rollback failed: %v", err)
			}
		}
	}()
	for _, member := range snapshot.Members {
		if member.Version == nil || member.Version.Semver != snapshot.Version || member.Version.Zip == nil {
			return "", fmt.Errorf("Repository source returned an invalid member for %s@%s", repositoryID, query)
		}
		archive := member.Version.Zip
		defer func() { _ = archive.Close() }()
		existingInfo, existingErr := p.storage.Info(ctx, member.SkillID, snapshot.Version)
		if existingErr == nil {
			var existing catalogArtifactInfo
			if json.Unmarshal(existingInfo, &existing) != nil || existing.CommitSHA != snapshot.CommitSHA {
				return "", fmt.Errorf("immutable Repository version conflict for %s@%s", repositoryID, snapshot.Version)
			}
			stored[member.SkillID] = true
		} else if !huberrors.IsNotFoundErr(existingErr) {
			return "", existingErr
		}
		memberIDs = append(memberIDs, member.SkillID)
	}
	for _, member := range snapshot.Members {
		if stored[member.SkillID] {
			continue
		}
		created, err := p.storage.(storage.ImmutableSaver).PutIfAbsent(
			ctx, member.SkillID, snapshot.Version,
			member.Version.Zip, member.Version.ZipMD5, member.Version.Info,
		)
		if err != nil {
			return "", err
		}
		if created {
			newlyStored = append(newlyStored, member.SkillID)
		}
	}
	published := make([]catalog.PublishedSkill, 0, len(memberIDs))
	release := protocolapi.RepositoryInfo{
		SchemaVersion: protocolapi.SchemaVersion,
		Kind:          protocolapi.KindRepository,
		ID:            repositoryID,
		Version:       snapshot.Version,
		Time:          snapshot.CommitTime,
		CommitSHA:     snapshot.CommitSHA,
		Skills:        make([]json.RawMessage, 0, len(memberIDs)),
	}
	for _, memberID := range memberIDs {
		publicationCtx := withoutCatalogIndex(ctx)
		immutableInfo, err := p.protocol.Info(publicationCtx, memberID, snapshot.Version)
		if err != nil {
			return "", err
		}
		var info struct {
			Name        string    `json:"Name"`
			Description string    `json:"Description"`
			Version     string    `json:"Version"`
			Time        time.Time `json:"Time"`
			Sum         string    `json:"Sum"`
			ArchiveSize int64     `json:"ArchiveSize"`
			CommitSHA   string    `json:"CommitSHA"`
			TreeSHA     string    `json:"TreeSHA"`
			Ref         string    `json:"Ref"`
		}
		if err := json.Unmarshal(immutableInfo, &info); err != nil {
			return "", fmt.Errorf("decode immutable Repository member Info: %w", err)
		}
		published = append(published, catalog.PublishedSkill{
			Skill: catalog.Skill{SkillID: memberID, Name: info.Name, Description: info.Description, LatestVersion: info.Version},
			Version: catalog.SkillVersion{Version: info.Version, CommitSHA: info.CommitSHA, TreeSHA: info.TreeSHA,
				Sum: info.Sum, CommitTime: info.Time, ArchiveSize: info.ArchiveSize},
		})
		if info.CommitSHA != snapshot.CommitSHA || info.Ref == "" {
			return "", fmt.Errorf("Repository member Info is inconsistent for %s@%s", repositoryID, snapshot.Version)
		}
		if release.Ref == "" {
			release.Ref = info.Ref
		} else if release.Ref != info.Ref {
			return "", fmt.Errorf("Repository member refs are inconsistent for %s@%s", repositoryID, snapshot.Version)
		}
		release.Skills = append(release.Skills, json.RawMessage(append([]byte(nil), immutableInfo...)))
	}
	releaseInfo, err := json.Marshal(release)
	if err != nil {
		return "", fmt.Errorf("encode Repository Release Record: %w", err)
	}
	if err := p.metadata.PublishRepositoryReleaseWithVisibility(ctx, repositoryID, published, visibility, releaseInfo); err != nil {
		return "", err
	}
	publicationCommitted = true
	log.EntryFromContext(ctx).WithFields(map[string]any{
		"member_count":       len(memberIDs),
		"new_artifact_count": len(newlyStored),
		"repository_id":      repositoryID,
		"version":            snapshot.Version,
	}).Debugf("repository publication committed")
	return snapshot.Version, nil
}

func closeRepositorySnapshot(snapshot *skill.RepositorySnapshot) {
	if snapshot == nil {
		return
	}
	for _, member := range snapshot.Members {
		if member.Version != nil && member.Version.Zip != nil {
			_ = member.Version.Zip.Close()
		}
	}
}
