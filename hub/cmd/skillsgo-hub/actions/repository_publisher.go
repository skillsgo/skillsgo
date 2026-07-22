/*
 * [INPUT]: Depends on request-scoped structured logging, one resolved Repository snapshot, immutable artifact storage, and enriched per-Skill protocol indexing.
 * [OUTPUT]: Materializes every accepted Repository member, commits its byte-stable Repository Release Record, and emits a correlated bounded publication lifecycle without logging credentials or artifact content.
 * [POS]: Serves as the observable cold-publication coordinator between Git Repository discovery, artifact storage, and Repository Info visibility.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"sync"
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/skillsgo/skillsgo/hub/pkg/download"
	huberrors "github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	"github.com/skillsgo/skillsgo/hub/pkg/skill"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	protocolapi "github.com/skillsgo/skillsgo/protocol/api"
	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
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
	if snapshot.Archive == nil || snapshot.ArchiveSize <= 0 || snapshot.Sum == "" || snapshot.Ref == "" || snapshot.TreeSHA == "" {
		return "", fmt.Errorf("Repository source returned an incomplete Artifact for %s@%s", repositoryID, query)
	}
	archive, err := io.ReadAll(io.LimitReader(snapshot.Archive, protocolartifact.MaxArchiveBytes+1))
	if err != nil {
		return "", fmt.Errorf("read Repository Artifact: %w", err)
	}
	if int64(len(archive)) != snapshot.ArchiveSize || len(archive) > protocolartifact.MaxArchiveBytes {
		return "", fmt.Errorf("Repository Artifact size mismatch for %s@%s", repositoryID, snapshot.Version)
	}
	if sum, sumErr := protocolartifact.RepositorySum(archive, repositoryID, snapshot.Version); sumErr != nil || sum != snapshot.Sum {
		return "", fmt.Errorf("Repository Artifact Sum mismatch for %s@%s", repositoryID, snapshot.Version)
	}

	published := make([]catalog.PublishedSkill, 0, len(snapshot.Members))
	release := protocolapi.RepositoryInfo{
		SchemaVersion: protocolapi.SchemaVersion,
		Kind:          protocolapi.KindRepository,
		ID:            repositoryID,
		Version:       snapshot.Version,
		Time:          snapshot.CommitTime,
		Ref:           snapshot.Ref,
		CommitSHA:     snapshot.CommitSHA,
		TreeSHA:       snapshot.TreeSHA,
		Sum:           snapshot.Sum,
		ArchiveSize:   snapshot.ArchiveSize,
		Skills:        make([]protocolapi.SkillInfo, 0, len(snapshot.Members)),
	}
	for _, member := range snapshot.Members {
		if member.SkillID == "" || member.Path == "" || member.TreeSHA == "" || member.Manifest.Name == "" || member.Manifest.Description == "" {
			return "", fmt.Errorf("Repository source returned an invalid member for %s@%s", repositoryID, query)
		}
		info := protocolapi.SkillInfo{
			SchemaVersion: protocolapi.SchemaVersion, Kind: protocolapi.KindSkill,
			ID: member.SkillID, RepositoryID: repositoryID, Path: member.Path,
			Version: snapshot.Version, Time: snapshot.CommitTime, Ref: snapshot.Ref,
			CommitSHA: snapshot.CommitSHA, TreeSHA: member.TreeSHA,
			Name: member.Manifest.Name, Description: member.Manifest.Description,
			License: member.Manifest.License, Compatibility: member.Manifest.Compatibility,
			AllowedTools: member.Manifest.AllowedTools, Metadata: member.Manifest.Metadata,
		}
		release.Skills = append(release.Skills, info)
		published = append(published, catalog.PublishedSkill{
			Skill: catalog.Skill{SkillID: member.SkillID, Name: member.Manifest.Name, Description: member.Manifest.Description, LatestVersion: snapshot.Version},
			Version: catalog.SkillVersion{Version: snapshot.Version, CommitSHA: snapshot.CommitSHA, TreeSHA: member.TreeSHA,
				Sum: snapshot.Sum, CommitTime: snapshot.CommitTime, ArchiveSize: snapshot.ArchiveSize},
		})
	}
	releaseInfo, err := json.Marshal(release)
	if err != nil {
		return "", fmt.Errorf("encode Repository Info: %w", err)
	}

	created := false
	publicationCommitted := false
	defer func() {
		if publicationCommitted || !created {
			return
		}
		cleanupCtx, cancel := context.WithTimeout(context.WithoutCancel(ctx), 30*time.Second)
		defer cancel()
		if err := p.storage.Delete(cleanupCtx, repositoryID, snapshot.Version); err != nil {
			log.EntryFromContext(ctx).WithFields(map[string]any{
				"repository_id": repositoryID, "version": snapshot.Version,
			}).Warnf("repository publication rollback failed: %v", err)
		}
	}()
	created, err = p.storage.(storage.ImmutableSaver).PutIfAbsent(ctx, repositoryID, snapshot.Version,
		bytes.NewReader(archive), snapshot.ArchiveMD5, releaseInfo)
	if err != nil {
		return "", err
	}
	if err := p.metadata.PublishRepositoryReleaseWithVisibility(ctx, repositoryID, published, visibility, releaseInfo); err != nil {
		return "", err
	}
	publicationCommitted = true
	log.EntryFromContext(ctx).WithFields(map[string]any{
		"member_count":       len(snapshot.Members),
		"new_artifact_count": map[bool]int{true: 1, false: 0}[created],
		"repository_id":      repositoryID,
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
