/*
 * [INPUT]: Depends on request-scoped logging, canonical Package Paths, persisted Package Info, Catalog publication membership, singleflight coordination, and one Repository materializer.
 * [OUTPUT]: Serves byte-stable Package Info/ZIP resources and deduplicated demand-driven exact Package publication at the Package distribution API.
 * [POS]: Serves as the Package publication protocol decorator; Skills are members and never independent artifact resources.
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
	"golang.org/x/sync/singleflight"
)

func withPackageInfo(protocol download.Protocol, metadata *catalog.Catalog, materializer repositoryMaterializer) download.Protocol {
	return &moduleInfoProtocol{Protocol: protocol, metadata: metadata, materializer: materializer}
}

type moduleInfoProtocol struct {
	download.Protocol
	metadata     *catalog.Catalog
	materializer repositoryMaterializer
	publication  singleflight.Group
}

func (p *moduleInfoProtocol) List(ctx context.Context, packagePath string) ([]string, error) {
	if err := validatePackageResource(packagePath); err != nil {
		return nil, huberrors.E("moduleInfoProtocol.List", err, huberrors.KindBadRequest)
	}
	return p.Protocol.List(ctx, packagePath)
}

func (p *moduleInfoProtocol) Info(ctx context.Context, packagePath, version string) ([]byte, error) {
	if err := validatePackageResource(packagePath); err != nil {
		return nil, huberrors.E("moduleInfoProtocol.Info", err, huberrors.KindBadRequest)
	}
	canonicalVersion, err := p.ensurePublished(ctx, packagePath, version)
	if err != nil {
		return nil, err
	}
	if persisted, ok, err := p.metadata.PackageVersionInfo(ctx, packagePath, canonicalVersion); err != nil {
		return nil, err
	} else if ok {
		return persisted, nil
	}
	return nil, fmt.Errorf("Package publication has no immutable Info for %s@%s", packagePath, canonicalVersion)
}

func (p *moduleInfoProtocol) Zip(ctx context.Context, packagePath, version string) (storage.SizeReadCloser, error) {
	if err := validatePackageResource(packagePath); err != nil {
		return nil, huberrors.E("moduleInfoProtocol.Zip", err, huberrors.KindBadRequest)
	}
	canonicalVersion, err := p.ensurePublished(ctx, packagePath, version)
	if err != nil {
		return nil, err
	}
	return p.Protocol.Zip(ctx, packagePath, canonicalVersion)
}

func (p *moduleInfoProtocol) ensurePublished(ctx context.Context, packagePath, version string) (string, error) {
	result, err, _ := p.publication.Do(packagePath+"@"+version, func() (any, error) {
		return p.ensurePublishedOnce(ctx, packagePath, version)
	})
	if err != nil {
		return "", err
	}
	return result.(string), nil
}

func (p *moduleInfoProtocol) ensurePublishedOnce(ctx context.Context, packagePath, version string) (string, error) {
	members, err := p.metadata.VersionSkills(ctx, packagePath, version)
	if err != nil {
		return "", err
	}
	if len(members) > 0 {
		logPackagePublicationLookup(ctx, packagePath, version, "hit")
		return version, nil
	}
	logPackagePublicationLookup(ctx, packagePath, version, "miss")
	if p.materializer == nil {
		return "", huberrors.E("moduleInfoProtocol.ensurePublished", huberrors.S(packagePath), huberrors.V(version), huberrors.KindNotFound)
	}
	canonicalVersion, err := p.materializer.Materialize(ctx, packagePath, version)
	if err != nil {
		return "", err
	}
	members, err = p.metadata.VersionSkills(ctx, packagePath, canonicalVersion)
	if err != nil {
		return "", err
	}
	if len(members) == 0 {
		return "", fmt.Errorf("Package publication produced no visible members for %s@%s", packagePath, canonicalVersion)
	}
	return canonicalVersion, nil
}

func validatePackageResource(packagePath string) error {
	parsed, err := skill.ParsePackagePath(packagePath)
	if err != nil || parsed.String() != packagePath {
		return fmt.Errorf("invalid canonical Package Path %q", packagePath)
	}
	return nil
}

func logPackagePublicationLookup(ctx context.Context, packagePath, version, result string) {
	log.EntryFromContext(ctx).WithFields(map[string]any{
		"cache_resource": "package_publication",
		"cache_result":   result,
		"package_path":   packagePath,
		"version":        version,
	}).Debugf("repository publication lookup")
}
