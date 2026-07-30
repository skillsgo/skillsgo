/*
 * [INPUT]: Depends on request-scoped logging, canonical Package Paths, persisted Package Info, Catalog publication membership, singleflight coordination, and one Repository materializer.
 * [OUTPUT]: Serves Package Info carrying the static Git Artifact Repository URL and deduplicated demand-driven exact Package publication at the Package distribution API.
 * [POS]: Serves as the Package publication protocol decorator; Skills are members and never independent artifact resources.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/skillsgo/skillsgo/hub/pkg/download"
	huberrors "github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	"github.com/skillsgo/skillsgo/hub/pkg/skill"
	protocolapi "github.com/skillsgo/skillsgo/protocol/api"
	"golang.org/x/sync/singleflight"
)

func withPackageInfo(protocol download.Protocol, metadata *catalog.Catalog, materializer repositoryMaterializer, origins ...string) download.Protocol {
	artifactOrigin := ""
	if len(origins) > 0 {
		artifactOrigin = origins[0]
	}
	return &moduleInfoProtocol{Protocol: protocol, metadata: metadata, materializer: materializer, artifactOrigin: strings.TrimRight(artifactOrigin, "/")}
}

type moduleInfoProtocol struct {
	download.Protocol
	metadata       *catalog.Catalog
	materializer   repositoryMaterializer
	artifactOrigin string
	publication    singleflight.Group
}

func (p *moduleInfoProtocol) List(ctx context.Context, packagePath string) ([]string, error) {
	if err := validatePackageResource(packagePath); err != nil {
		return nil, huberrors.E("moduleInfoProtocol.List", err, huberrors.KindBadRequest)
	}
	published, err := p.metadata.PackagePublishedVersions(ctx, packagePath)
	if err != nil {
		return nil, err
	}
	upstream, upstreamErr := p.Protocol.List(ctx, packagePath)
	if upstreamErr != nil {
		if len(published) > 0 && huberrors.IsRepoNotFoundErr(upstreamErr) {
			return published, nil
		}
		return nil, upstreamErr
	}
	return mergeVersions(upstream, published), nil
}

func mergeVersions(first, second []string) []string {
	seen := make(map[string]struct{}, len(first)+len(second))
	merged := make([]string, 0, len(first)+len(second))
	for _, versions := range [][]string{first, second} {
		for _, version := range versions {
			if _, ok := seen[version]; ok {
				continue
			}
			seen[version] = struct{}{}
			merged = append(merged, version)
		}
	}
	return merged
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
		var info protocolapi.PackageInfo
		if err := json.Unmarshal(persisted, &info); err != nil {
			return nil, fmt.Errorf("decode persisted Package Info: %w", err)
		}
		info.ArtifactRepository = p.artifactOrigin + "/packages/" + packagePath
		return json.Marshal(info)
	}
	return nil, fmt.Errorf("Package publication has no immutable Info for %s@%s", packagePath, canonicalVersion)
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
	if version == "latest" {
		current, found, err := p.metadata.CurrentPackageVersion(ctx, packagePath)
		if err != nil {
			return "", err
		}
		if found {
			logPackagePublicationLookup(ctx, packagePath, current, "hit")
			return current, nil
		}
	}
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
