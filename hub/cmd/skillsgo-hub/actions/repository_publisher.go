/*
 * [INPUT]: Depends on one resolved Repository snapshot, immutable artifact storage, and enriched per-Skill protocol indexing.
 * [OUTPUT]: Materializes every accepted Repository member from one source discovery and returns its canonical immutable version.
 * [POS]: Serves as the cold-publication coordinator between Git Repository discovery, artifact storage, and Repository Info visibility.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"context"
	"fmt"

	"github.com/skillsgo/skillsgo/hub/pkg/download"
	"github.com/skillsgo/skillsgo/hub/pkg/skill"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	"golang.org/x/sync/singleflight"
)

type repositoryMaterializer interface {
	Materialize(ctx context.Context, repositoryID, query string) (string, error)
}

type repositoryPublisher struct {
	fetcher  skill.RepositoryFetcher
	storage  storage.Backend
	protocol download.Protocol
	work     singleflight.Group
	upstream chan struct{}
}

func newRepositoryPublisher(fetcher skill.RepositoryFetcher, backend storage.Backend, protocol download.Protocol) repositoryMaterializer {
	return &repositoryPublisher{fetcher: fetcher, storage: backend, protocol: protocol, upstream: make(chan struct{}, 8)}
}

func (p *repositoryPublisher) Materialize(ctx context.Context, repositoryID, query string) (string, error) {
	value, err, _ := p.work.Do("publish:"+repositoryID+"@"+query, func() (any, error) {
		select {
		case p.upstream <- struct{}{}:
			defer func() { <-p.upstream }()
		case <-ctx.Done():
			return "", ctx.Err()
		}
		return p.materialize(ctx, repositoryID, query)
	})
	if err != nil {
		return "", err
	}
	return value.(string), nil
}

func (p *repositoryPublisher) materialize(ctx context.Context, repositoryID, query string) (string, error) {
	snapshot, err := p.fetcher.DiscoverRepository(ctx, repositoryID, query)
	if err != nil {
		return "", err
	}
	if snapshot.RepositoryID != repositoryID || snapshot.Version == "" || snapshot.CommitSHA == "" || len(snapshot.Members) == 0 {
		return "", fmt.Errorf("Repository source returned an invalid snapshot for %s@%s", repositoryID, query)
	}
	memberIDs := make([]string, 0, len(snapshot.Members))
	for _, member := range snapshot.Members {
		if member.Version == nil || member.Version.Semver != snapshot.Version || member.Version.Zip == nil {
			return "", fmt.Errorf("Repository source returned an invalid member for %s@%s", repositoryID, query)
		}
		if err := p.storage.Save(
			ctx, member.SkillID, snapshot.Version, member.Version.Manifest,
			member.Version.Zip, member.Version.ZipMD5, member.Version.Info,
		); err != nil {
			_ = member.Version.Zip.Close()
			return "", err
		}
		if err := member.Version.Zip.Close(); err != nil {
			return "", err
		}
		memberIDs = append(memberIDs, member.SkillID)
	}
	for _, memberID := range memberIDs {
		if _, err := p.protocol.Info(ctx, memberID, snapshot.Version); err != nil {
			return "", err
		}
	}
	return snapshot.Version, nil
}
