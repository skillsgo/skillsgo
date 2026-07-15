/*
 * [INPUT]: Depends on immutable artifact protocol reads, Catalog metadata, ZIP audit analysis, and normalized Manifest YAML.
 * [OUTPUT]: Provides a protocol decorator that indexes resolved Skills and binds Risk plus Content Digest to exact Info responses.
 * [POS]: Serves as the Registry distribution boundary connecting source artifacts, immutable assessment, and public protocol bytes.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"

	"github.com/skillsgo/skillsgo/registry/pkg/audit"
	"github.com/skillsgo/skillsgo/registry/pkg/catalog"
	"github.com/skillsgo/skillsgo/registry/pkg/download"
	"github.com/skillsgo/skillsgo/registry/pkg/storage"
	"gopkg.in/yaml.v3"
)

func withCatalog(protocol download.Protocol, metadata *catalog.Catalog) download.Protocol {
	return &catalogProtocol{Protocol: protocol, metadata: metadata}
}

type catalogProtocol struct {
	download.Protocol
	metadata *catalog.Catalog
}

type catalogArtifactInfo struct {
	Version string `json:"Version"`
}

type catalogManifest struct {
	Name        string `yaml:"name"`
	Description string `yaml:"description"`
}

func (p *catalogProtocol) Info(ctx context.Context, coordinate, version string) ([]byte, error) {
	info, err := p.Protocol.Info(ctx, coordinate, version)
	if err != nil {
		return nil, err
	}
	assessed, err := p.bindAssessment(ctx, coordinate, info, nil)
	if err != nil {
		return nil, err
	}
	if err := p.index(ctx, coordinate, assessed, nil); err != nil {
		return nil, err
	}
	return assessed, nil
}

func (p *catalogProtocol) bindAssessment(ctx context.Context, coordinate string, infoBytes, archiveBytes []byte) ([]byte, error) {
	var info catalogArtifactInfo
	if err := json.Unmarshal(infoBytes, &info); err != nil || info.Version == "" {
		return nil, fmt.Errorf("decode Skill info for assessment: Version is required")
	}
	if archiveBytes == nil {
		archive, err := p.Protocol.Zip(ctx, coordinate, info.Version)
		if err != nil {
			return nil, fmt.Errorf("read Skill archive for assessment: %w", err)
		}
		archiveBytes, err = readAuditArchive(archive)
		if err != nil {
			return nil, err
		}
	}
	analysis, err := audit.AnalyzeArtifact(archiveBytes, coordinate, info.Version)
	if err != nil {
		return nil, fmt.Errorf("assess Skill archive: %w", err)
	}
	var response map[string]any
	if err := json.Unmarshal(infoBytes, &response); err != nil {
		return nil, fmt.Errorf("decode Skill info response: %w", err)
	}
	response["Risk"] = analysis.Risk.Level
	response["ContentDigest"] = analysis.ContentDigest
	encoded, err := json.Marshal(response)
	if err != nil {
		return nil, fmt.Errorf("encode assessed Skill info: %w", err)
	}
	return encoded, nil
}

func (p *catalogProtocol) Manifest(ctx context.Context, coordinate, version string) ([]byte, error) {
	manifest, err := p.Protocol.Manifest(ctx, coordinate, version)
	if err != nil {
		return nil, err
	}
	info, err := p.Protocol.Info(ctx, coordinate, version)
	if err != nil {
		return nil, err
	}
	assessed, err := p.bindAssessment(ctx, coordinate, info, nil)
	if err != nil {
		return nil, err
	}
	if err := p.index(ctx, coordinate, assessed, manifest); err != nil {
		return nil, err
	}
	return manifest, nil
}

func (p *catalogProtocol) Zip(ctx context.Context, coordinate, version string) (storage.SizeReadCloser, error) {
	archive, err := p.Protocol.Zip(ctx, coordinate, version)
	if err != nil {
		return nil, err
	}
	archiveBytes, err := readAuditArchive(archive)
	if err != nil {
		return nil, err
	}
	info, err := p.Protocol.Info(ctx, coordinate, version)
	if err != nil {
		return nil, err
	}
	assessed, err := p.bindAssessment(ctx, coordinate, info, archiveBytes)
	if err != nil {
		return nil, err
	}
	if err := p.index(ctx, coordinate, assessed, nil); err != nil {
		return nil, err
	}
	return storage.NewSizer(io.NopCloser(bytes.NewReader(archiveBytes)), int64(len(archiveBytes))), nil
}

func (p *catalogProtocol) index(ctx context.Context, coordinate string, infoBytes, manifestBytes []byte) error {
	var info catalogArtifactInfo
	if err := json.Unmarshal(infoBytes, &info); err != nil {
		return fmt.Errorf("decode Skill info for catalog: %w", err)
	}
	if info.Version == "" {
		return fmt.Errorf("decode Skill info for catalog: Version is required")
	}
	if manifestBytes == nil {
		var err error
		manifestBytes, err = p.Protocol.Manifest(ctx, coordinate, info.Version)
		if err != nil {
			return fmt.Errorf("read Skill manifest for catalog: %w", err)
		}
	}
	var manifest catalogManifest
	if err := yaml.Unmarshal(manifestBytes, &manifest); err != nil {
		return fmt.Errorf("decode Skill manifest for catalog: %w", err)
	}
	if manifest.Name == "" || manifest.Description == "" {
		return fmt.Errorf("decode Skill manifest for catalog: name and description are required")
	}
	if err := p.metadata.UpsertSkill(ctx, &catalog.Skill{
		Coordinate:    coordinate,
		Name:          manifest.Name,
		Description:   manifest.Description,
		LatestVersion: info.Version,
	}); err != nil {
		return fmt.Errorf("upsert Skill catalog metadata: %w", err)
	}
	return nil
}
