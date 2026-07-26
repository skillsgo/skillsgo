/*
 * [INPUT]: Depends on request-scoped logging, canonical Module Paths, persisted Module Info, Catalog publication membership, and one Repository materializer.
 * [OUTPUT]: Serves byte-stable Module Info/ZIP resources and demand-driven exact Module publication at the Module distribution API.
 * [POS]: Serves as the Module publication protocol decorator; Skills are members and never independent artifact resources.
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

func withModuleInfo(protocol download.Protocol, metadata *catalog.Catalog, materializer repositoryMaterializer) download.Protocol {
	return &moduleInfoProtocol{Protocol: protocol, metadata: metadata, materializer: materializer}
}

type moduleInfoProtocol struct {
	download.Protocol
	metadata     *catalog.Catalog
	materializer repositoryMaterializer
}

func (p *moduleInfoProtocol) List(ctx context.Context, modulePath string) ([]string, error) {
	if err := validateModuleResource(modulePath); err != nil {
		return nil, huberrors.E("moduleInfoProtocol.List", err, huberrors.KindBadRequest)
	}
	return p.Protocol.List(ctx, modulePath)
}

func (p *moduleInfoProtocol) Info(ctx context.Context, modulePath, version string) ([]byte, error) {
	if err := validateModuleResource(modulePath); err != nil {
		return nil, huberrors.E("moduleInfoProtocol.Info", err, huberrors.KindBadRequest)
	}
	canonicalVersion, err := p.ensurePublished(ctx, modulePath, version)
	if err != nil {
		return nil, err
	}
	if persisted, ok, err := p.metadata.ModuleVersionInfo(ctx, modulePath, canonicalVersion); err != nil {
		return nil, err
	} else if ok {
		return persisted, nil
	}
	return nil, fmt.Errorf("Module publication has no immutable Info for %s@%s", modulePath, canonicalVersion)
}

func (p *moduleInfoProtocol) Zip(ctx context.Context, modulePath, version string) (storage.SizeReadCloser, error) {
	if err := validateModuleResource(modulePath); err != nil {
		return nil, huberrors.E("moduleInfoProtocol.Zip", err, huberrors.KindBadRequest)
	}
	canonicalVersion, err := p.ensurePublished(ctx, modulePath, version)
	if err != nil {
		return nil, err
	}
	return p.Protocol.Zip(ctx, modulePath, canonicalVersion)
}

func (p *moduleInfoProtocol) ensurePublished(ctx context.Context, modulePath, version string) (string, error) {
	members, err := p.metadata.VersionSkills(ctx, modulePath, version)
	if err != nil {
		return "", err
	}
	if len(members) > 0 {
		logModulePublicationLookup(ctx, modulePath, version, "hit")
		return version, nil
	}
	logModulePublicationLookup(ctx, modulePath, version, "miss")
	if p.materializer == nil {
		return "", huberrors.E("moduleInfoProtocol.ensurePublished", huberrors.S(modulePath), huberrors.V(version), huberrors.KindNotFound)
	}
	canonicalVersion, err := p.materializer.Materialize(ctx, modulePath, version)
	if err != nil {
		return "", err
	}
	members, err = p.metadata.VersionSkills(ctx, modulePath, canonicalVersion)
	if err != nil {
		return "", err
	}
	if len(members) == 0 {
		return "", fmt.Errorf("Module publication produced no visible members for %s@%s", modulePath, canonicalVersion)
	}
	return canonicalVersion, nil
}

func validateModuleResource(modulePath string) error {
	parsed, err := skill.ParseModulePath(modulePath)
	if err != nil || parsed.String() != modulePath {
		return fmt.Errorf("invalid canonical Module Path %q", modulePath)
	}
	return nil
}

func logModulePublicationLookup(ctx context.Context, modulePath, version, result string) {
	log.EntryFromContext(ctx).WithFields(map[string]any{
		"cache_resource": "module_publication",
		"cache_result":   result,
		"module_path":    modulePath,
		"version":        version,
	}).Debugf("repository publication lookup")
}
