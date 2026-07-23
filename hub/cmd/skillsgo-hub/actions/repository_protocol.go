/*
 * [INPUT]: Depends on request-scoped logging, canonical bare Repository IDs, persisted Repository Info, Catalog publication membership, and one Repository materializer.
 * [OUTPUT]: Serves byte-stable Repository Info/ZIP resources and demand-driven exact Repository publication at the root Repository Proxy.
 * [POS]: Serves as the Repository publication protocol decorator; Skills are members and never independent artifact resources.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"context"
	"fmt"

	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/skillsgo/skillsgo/hub/pkg/download"
	huberrors "github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	"github.com/skillsgo/skillsgo/hub/pkg/skill"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
)

func withRepositoryInfo(protocol download.Protocol, metadata *catalog.Catalog, materializer repositoryMaterializer) download.Protocol {
	return &repositoryInfoProtocol{Protocol: protocol, metadata: metadata, materializer: materializer}
}

type repositoryInfoProtocol struct {
	download.Protocol
	metadata     *catalog.Catalog
	materializer repositoryMaterializer
}

func (p *repositoryInfoProtocol) List(ctx context.Context, repositoryID string) ([]string, error) {
	if err := validateRepositoryResource(repositoryID); err != nil {
		return nil, huberrors.E("repositoryInfoProtocol.List", err, huberrors.KindBadRequest)
	}
	return p.Protocol.List(ctx, repositoryID)
}

func (p *repositoryInfoProtocol) Info(ctx context.Context, repositoryID, version string) ([]byte, error) {
	if err := validateRepositoryResource(repositoryID); err != nil {
		return nil, huberrors.E("repositoryInfoProtocol.Info", err, huberrors.KindBadRequest)
	}
	canonicalVersion, err := p.ensurePublished(ctx, repositoryID, version)
	if err != nil {
		return nil, err
	}
	if persisted, ok, err := p.metadata.RepositoryReleaseInfo(ctx, repositoryID, canonicalVersion); err != nil {
		return nil, err
	} else if ok {
		return persisted, nil
	}
	return nil, fmt.Errorf("Repository publication has no immutable Info for %s@%s", repositoryID, canonicalVersion)
}

func (p *repositoryInfoProtocol) Zip(ctx context.Context, repositoryID, version string) (storage.SizeReadCloser, error) {
	if err := validateRepositoryResource(repositoryID); err != nil {
		return nil, huberrors.E("repositoryInfoProtocol.Zip", err, huberrors.KindBadRequest)
	}
	canonicalVersion, err := p.ensurePublished(ctx, repositoryID, version)
	if err != nil {
		return nil, err
	}
	return p.Protocol.Zip(ctx, repositoryID, canonicalVersion)
}

func (p *repositoryInfoProtocol) ensurePublished(ctx context.Context, repositoryID, version string) (string, error) {
	members, err := p.metadata.RepositoryVersionMembers(ctx, repositoryID, version)
	if err != nil {
		return "", err
	}
	if len(members) > 0 {
		logRepositoryPublicationLookup(ctx, repositoryID, version, "hit")
		return version, nil
	}
	logRepositoryPublicationLookup(ctx, repositoryID, version, "miss")
	if p.materializer == nil {
		return "", huberrors.E("repositoryInfoProtocol.ensurePublished", huberrors.S(repositoryID), huberrors.V(version), huberrors.KindNotFound)
	}
	canonicalVersion, err := p.materializer.Materialize(ctx, repositoryID, version)
	if err != nil {
		return "", err
	}
	members, err = p.metadata.RepositoryVersionMembers(ctx, repositoryID, canonicalVersion)
	if err != nil {
		return "", err
	}
	if len(members) == 0 {
		return "", fmt.Errorf("Repository publication produced no visible members for %s@%s", repositoryID, canonicalVersion)
	}
	return canonicalVersion, nil
}

func validateRepositoryResource(repositoryID string) error {
	parsed, err := skill.ParseSkillID(repositoryID)
	if err != nil || parsed.String() != repositoryID || parsed.SkillPath != "." {
		return fmt.Errorf("invalid canonical Repository ID %q", repositoryID)
	}
	return nil
}

func logRepositoryPublicationLookup(ctx context.Context, repositoryID, version, result string) {
	log.EntryFromContext(ctx).WithFields(map[string]any{
		"cache_resource": "repository_publication",
		"cache_result":   result,
		"repository_id":  repositoryID,
		"version":        version,
	}).Debugf("repository publication lookup")
}
