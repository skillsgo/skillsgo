/*
 * [INPUT]: Depends on one resolved Repository snapshot, immutable artifact storage, and enriched per-Skill protocol indexing.
 * [OUTPUT]: Materializes every accepted Repository member from one source discovery and returns its canonical immutable version.
 * [POS]: Serves as the cold-publication coordinator between Git Repository discovery, artifact storage, and Repository Info visibility.
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
	"github.com/skillsgo/skillsgo/hub/pkg/skill"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	"golang.org/x/sync/singleflight"
)

type repositoryMaterializer interface {
	Materialize(ctx context.Context, repositoryID, query string) (string, error)
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

func newRepositoryPublisher(fetcher skill.RepositoryFetcher, backend storage.Backend, protocol download.Protocol, metadata *catalog.Catalog) repositoryMaterializer {
	return &repositoryPublisher{fetcher: fetcher, storage: backend, protocol: protocol, metadata: metadata, upstream: make(chan struct{}, 8), negative: make(map[string]negativePublication), now: time.Now, negativeTTL: 10 * time.Second}
}

func (p *repositoryPublisher) Materialize(ctx context.Context, repositoryID, query string) (string, error) {
	key := "publish:" + repositoryID + "@" + query
	p.mu.Lock()
	negative, cached := p.negative[key]
	if cached && p.now().Before(negative.expires) {
		p.mu.Unlock()
		return "", negative.err
	}
	if cached {
		delete(p.negative, key)
	}
	p.mu.Unlock()
	result := p.work.DoChan(key, func() (any, error) {
		workCtx, cancel := context.WithTimeout(context.WithoutCancel(ctx), 15*time.Minute)
		defer cancel()
		select {
		case p.upstream <- struct{}{}:
			defer func() { <-p.upstream }()
		default:
			return "", huberrors.E("repositoryPublisher.Materialize", "upstream Repository resolution is at capacity", huberrors.KindRateLimit)
		}
		version, materializeErr := p.materialize(workCtx, repositoryID, query)
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
			return "", resolved.Err
		}
		return resolved.Val.(string), nil
	}
}

func (p *repositoryPublisher) materialize(ctx context.Context, repositoryID, query string) (string, error) {
	snapshot, err := p.fetcher.DiscoverRepository(ctx, repositoryID, query)
	if err != nil {
		return "", err
	}
	if snapshot.RepositoryID != repositoryID || snapshot.Version == "" || snapshot.CommitSHA == "" || len(snapshot.Members) == 0 {
		closeRepositorySnapshot(snapshot)
		return "", fmt.Errorf("Repository source returned an invalid snapshot for %s@%s", repositoryID, query)
	}
	invoked := false
	result, err, _ := p.commit.Do("commit:"+repositoryID+"@"+snapshot.Version, func() (any, error) {
		invoked = true
		return p.publishSnapshot(ctx, repositoryID, query, snapshot)
	})
	if !invoked {
		closeRepositorySnapshot(snapshot)
	}
	if err != nil {
		return "", err
	}
	return result.(string), nil
}

func (p *repositoryPublisher) publishSnapshot(ctx context.Context, repositoryID, query string, snapshot *skill.RepositorySnapshot) (string, error) {
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
			_ = p.storage.Delete(cleanupCtx, newlyStored[index], snapshot.Version)
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
			if json.Unmarshal(existingInfo, &existing) != nil || existing.Origin.CommitSHA != snapshot.CommitSHA {
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
		if err := p.storage.Save(
			ctx, member.SkillID, snapshot.Version,
			member.Version.Zip, member.Version.ZipMD5, member.Version.Info,
		); err != nil {
			return "", err
		}
		newlyStored = append(newlyStored, member.SkillID)
	}
	published := make([]catalog.PublishedSkill, 0, len(memberIDs))
	for _, memberID := range memberIDs {
		assessed, err := p.protocol.Info(withoutCatalogIndex(ctx), memberID, snapshot.Version)
		if err != nil {
			return "", err
		}
		var info struct {
			Name          string    `json:"Name"`
			Description   string    `json:"Description"`
			Version       string    `json:"Version"`
			Time          time.Time `json:"Time"`
			ContentDigest string    `json:"ContentDigest"`
			ArchiveSize   int64     `json:"ArchiveSize"`
			Origin        struct {
				CommitSHA string `json:"CommitSHA"`
				TreeSHA   string `json:"TreeSHA"`
			} `json:"Origin"`
		}
		if err := json.Unmarshal(assessed, &info); err != nil {
			return "", fmt.Errorf("decode assessed Repository member: %w", err)
		}
		published = append(published, catalog.PublishedSkill{
			Skill: catalog.Skill{SkillID: memberID, Name: info.Name, Description: info.Description, LatestVersion: info.Version},
			Version: catalog.SkillVersion{Version: info.Version, CommitSHA: info.Origin.CommitSHA, TreeSHA: info.Origin.TreeSHA,
				ContentDigest: info.ContentDigest, CommitTime: info.Time, ArchiveSize: info.ArchiveSize},
		})
	}
	if err := p.metadata.PublishRepositoryVersion(ctx, repositoryID, published); err != nil {
		return "", err
	}
	publicationCommitted = true
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
