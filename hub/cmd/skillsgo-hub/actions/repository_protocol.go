/*
 * [INPUT]: Depends on canonical bare Repository IDs, immutable per-Skill Info resources, and Catalog Repository/version membership.
 * [OUTPUT]: Provides self-contained immutable Repository Info on the bare coordinate while preserving per-Skill ZIP delivery.
 * [POS]: Serves as the Repository aggregation protocol decorator outside enriched per-Skill Catalog behavior.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/skillsgo/skillsgo/hub/pkg/download"
	huberrors "github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/skill"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
)

func withRepositoryInfo(protocol download.Protocol, metadata *catalog.Catalog, materializers ...repositoryMaterializer) download.Protocol {
	var materializer repositoryMaterializer
	if len(materializers) > 0 {
		materializer = materializers[0]
	}
	return &repositoryInfoProtocol{Protocol: protocol, metadata: metadata, materializer: materializer}
}

type repositoryInfoProtocol struct {
	download.Protocol
	metadata     *catalog.Catalog
	materializer repositoryMaterializer
}

type repositoryInfo struct {
	SchemaVersion int               `json:"SchemaVersion"`
	Kind          string            `json:"Kind"`
	ID            string            `json:"ID"`
	Version       string            `json:"Version"`
	Time          time.Time         `json:"Time"`
	CommitSHA     string            `json:"CommitSHA"`
	Skills        []json.RawMessage `json:"Skills"`
}

func (p *repositoryInfoProtocol) Info(ctx context.Context, resourceID, version string) ([]byte, error) {
	parsed, err := skill.ParseSkillID(resourceID)
	if err != nil || parsed.String() != resourceID {
		return nil, huberrors.E("repositoryInfoProtocol.Info", err, huberrors.KindBadRequest)
	}
	if parsed.SkillPath != "." {
		canonicalVersion, ensureErr := p.ensurePublished(ctx, parsed.Repository, resourceID, version)
		if ensureErr != nil {
			return nil, ensureErr
		}
		return p.Protocol.Info(ctx, resourceID, canonicalVersion)
	}
	members, err := p.metadata.RepositoryVersionMembers(ctx, resourceID, version)
	if err != nil {
		return nil, err
	}
	if len(members) == 0 {
		if p.materializer == nil {
			return nil, huberrors.E("repositoryInfoProtocol.Info", huberrors.S(resourceID), huberrors.V(version), huberrors.KindNotFound)
		}
		canonicalVersion, materializeErr := p.materializer.Materialize(ctx, resourceID, version)
		if materializeErr != nil {
			return nil, materializeErr
		}
		version = canonicalVersion
		members, err = p.metadata.RepositoryVersionMembers(ctx, resourceID, version)
		if err != nil {
			return nil, err
		}
		if len(members) == 0 {
			return nil, fmt.Errorf("Repository publication produced no visible members for %s@%s", resourceID, version)
		}
	}
	response := repositoryInfo{
		SchemaVersion: 1, Kind: "Repository", ID: resourceID, Version: version,
		Time: members[0].CommitTime, CommitSHA: members[0].CommitSHA,
		Skills: make([]json.RawMessage, 0, len(members)),
	}
	for _, member := range members {
		if member.Version != version || member.CommitSHA != response.CommitSHA {
			return nil, fmt.Errorf("Repository publication metadata is inconsistent for %s@%s", resourceID, version)
		}
		info, err := p.Protocol.Info(ctx, member.SkillID, version)
		if err != nil {
			return nil, err
		}
		response.Skills = append(response.Skills, json.RawMessage(info))
	}
	encoded, err := json.Marshal(response)
	if err != nil {
		return nil, fmt.Errorf("encode Repository Info: %w", err)
	}
	return encoded, nil
}

func (p *repositoryInfoProtocol) Zip(ctx context.Context, resourceID, version string) (storage.SizeReadCloser, error) {
	parsed, err := skill.ParseSkillID(resourceID)
	if err != nil || parsed.String() != resourceID {
		return nil, huberrors.E("repositoryInfoProtocol.Zip", err, huberrors.KindBadRequest)
	}
	canonicalVersion, err := p.ensurePublished(ctx, parsed.Repository, resourceID, version)
	if err != nil {
		return nil, err
	}
	return p.Protocol.Zip(ctx, resourceID, canonicalVersion)
}

func (p *repositoryInfoProtocol) ensurePublished(ctx context.Context, repositoryID, resourceID, version string) (string, error) {
	members, err := p.metadata.RepositoryVersionMembers(ctx, repositoryID, version)
	if err != nil {
		return "", err
	}
	canonicalVersion := version
	if len(members) == 0 {
		if p.materializer == nil {
			return "", huberrors.E("repositoryInfoProtocol.ensurePublished", huberrors.S(resourceID), huberrors.V(version), huberrors.KindNotFound)
		}
		canonicalVersion, err = p.materializer.Materialize(ctx, repositoryID, version)
		if err != nil {
			return "", err
		}
		members, err = p.metadata.RepositoryVersionMembers(ctx, repositoryID, canonicalVersion)
		if err != nil {
			return "", err
		}
	}
	for _, member := range members {
		if member.SkillID == resourceID {
			return canonicalVersion, nil
		}
	}
	return "", huberrors.E("repositoryInfoProtocol.ensurePublished", huberrors.S(resourceID), huberrors.V(canonicalVersion), huberrors.KindNotFound)
}
