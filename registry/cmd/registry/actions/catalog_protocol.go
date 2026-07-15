package actions

import (
	"context"
	"encoding/json"
	"fmt"

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
	if err := p.index(ctx, coordinate, info, nil); err != nil {
		return nil, err
	}
	return info, nil
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
	if err := p.index(ctx, coordinate, info, manifest); err != nil {
		return nil, err
	}
	return manifest, nil
}

func (p *catalogProtocol) Zip(ctx context.Context, coordinate, version string) (storage.SizeReadCloser, error) {
	archive, err := p.Protocol.Zip(ctx, coordinate, version)
	if err != nil {
		return nil, err
	}
	info, err := p.Protocol.Info(ctx, coordinate, version)
	if err != nil {
		_ = archive.Close()
		return nil, err
	}
	if err := p.index(ctx, coordinate, info, nil); err != nil {
		_ = archive.Close()
		return nil, err
	}
	return archive, nil
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
