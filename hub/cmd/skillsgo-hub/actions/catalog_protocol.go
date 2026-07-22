/*
 * [INPUT]: Depends on immutable artifact protocol reads, Catalog metadata, shared bounded ZIP traversal, and normalized SKILL.md frontmatter.
 * [OUTPUT]: Provides a protocol decorator that persists canonical immutable Skill Info with source metadata, Sum, and Archive Size while indexing separate Catalog projections.
 * [POS]: Serves as the immutable Info construction seam between source artifacts, publication, and public protocol bytes; mutable assessment stays downstream.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/skillsgo/skillsgo/hub/pkg/download"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
	protocolmanifest "github.com/skillsgo/skillsgo/protocol/skillmanifest"
)

func withCatalog(protocol download.Protocol, metadata *catalog.Catalog) download.Protocol {
	return &catalogProtocol{Protocol: protocol, metadata: metadata}
}

type catalogProtocol struct {
	download.Protocol
	metadata *catalog.Catalog
}

type suppressCatalogIndexKey struct{}

func withoutCatalogIndex(ctx context.Context) context.Context {
	return context.WithValue(ctx, suppressCatalogIndexKey{}, true)
}

func shouldIndexCatalog(ctx context.Context) bool {
	suppressed, _ := ctx.Value(suppressCatalogIndexKey{}).(bool)
	return !suppressed
}

type catalogArtifactInfo struct {
	Version     string    `json:"Version"`
	Time        time.Time `json:"Time"`
	Ref         string    `json:"Ref"`
	CommitSHA   string    `json:"CommitSHA"`
	TreeSHA     string    `json:"TreeSHA"`
	Sum         string    `json:"Sum"`
	ArchiveSize int64     `json:"ArchiveSize"`
}

func (p *catalogProtocol) Info(ctx context.Context, skillID, version string) ([]byte, error) {
	info, err := p.Protocol.Info(ctx, skillID, version)
	if err != nil {
		return nil, err
	}
	immutable, err := p.bindImmutableInfo(ctx, skillID, info, nil)
	if err != nil {
		return nil, err
	}
	if shouldIndexCatalog(ctx) {
		if err := p.index(ctx, skillID, immutable); err != nil {
			return nil, err
		}
	}
	return immutable, nil
}

func (p *catalogProtocol) bindImmutableInfo(ctx context.Context, skillID string, infoBytes, archiveBytes []byte) ([]byte, error) {
	var info catalogArtifactInfo
	if err := json.Unmarshal(infoBytes, &info); err != nil || info.Version == "" {
		return nil, fmt.Errorf("decode immutable Skill Info: Version is required")
	}
	if archiveBytes == nil {
		archive, err := p.Protocol.Zip(ctx, skillID, info.Version)
		if err != nil {
			return nil, fmt.Errorf("read Skill archive for immutable Info: %w", err)
		}
		archiveBytes, err = readAuditArchive(archive)
		if err != nil {
			return nil, err
		}
	}
	metadata, sum, err := metadataFromArchive(archiveBytes, skillID, info.Version)
	if err != nil {
		return nil, err
	}
	if metadata.Name == "" || metadata.Description == "" {
		return nil, fmt.Errorf("decode Skill metadata for Info: name and description are required")
	}
	var response map[string]any
	if err := json.Unmarshal(infoBytes, &response); err != nil {
		return nil, fmt.Errorf("decode Skill info response: %w", err)
	}
	delete(response, "Risk")
	response["Sum"] = sum
	response["SchemaVersion"] = 1
	response["Kind"] = "Skill"
	response["ID"] = skillID
	response["Name"] = metadata.Name
	response["Description"] = metadata.Description
	response["ArchiveSize"] = len(archiveBytes)
	if metadata.License != "" {
		response["License"] = metadata.License
	}
	if metadata.Compatibility != "" {
		response["Compatibility"] = metadata.Compatibility
	}
	if metadata.AllowedTools != "" {
		response["AllowedTools"] = metadata.AllowedTools
	}
	if len(metadata.Metadata) > 0 {
		response["Metadata"] = metadata.Metadata
	}
	encoded, err := json.Marshal(response)
	if err != nil {
		return nil, fmt.Errorf("encode assessed Skill info: %w", err)
	}
	return encoded, nil
}

func (p *catalogProtocol) Zip(ctx context.Context, skillID, version string) (storage.SizeReadCloser, error) {
	archive, err := p.Protocol.Zip(ctx, skillID, version)
	if err != nil {
		return nil, err
	}
	archiveBytes, err := readAuditArchive(archive)
	if err != nil {
		return nil, err
	}
	info, err := p.Protocol.Info(ctx, skillID, version)
	if err != nil {
		return nil, err
	}
	immutable, err := p.bindImmutableInfo(ctx, skillID, info, archiveBytes)
	if err != nil {
		return nil, err
	}
	if shouldIndexCatalog(ctx) {
		if err := p.index(ctx, skillID, immutable); err != nil {
			return nil, err
		}
	}
	return storage.NewSizer(io.NopCloser(bytes.NewReader(archiveBytes)), int64(len(archiveBytes))), nil
}

func (p *catalogProtocol) index(ctx context.Context, skillID string, infoBytes []byte) error {
	var info catalogArtifactInfo
	if err := json.Unmarshal(infoBytes, &info); err != nil {
		return fmt.Errorf("decode Skill info for catalog: %w", err)
	}
	if info.Version == "" {
		return fmt.Errorf("decode Skill info for catalog: Version is required")
	}
	known, err := p.metadata.SkillVersionExists(ctx, skillID, info.Version)
	if err != nil {
		return fmt.Errorf("check existing Skill version metadata: %w", err)
	}
	if known {
		return nil
	}
	var metadata struct {
		Name        string `json:"Name"`
		Description string `json:"Description"`
	}
	if err := json.Unmarshal(infoBytes, &metadata); err != nil || metadata.Name == "" || metadata.Description == "" {
		return fmt.Errorf("decode Skill metadata for catalog: name and description are required")
	}
	if err := p.metadata.UpsertSkill(ctx, &catalog.Skill{
		SkillID:       skillID,
		Name:          metadata.Name,
		Description:   metadata.Description,
		LatestVersion: info.Version,
	}); err != nil {
		return fmt.Errorf("upsert Skill catalog metadata: %w", err)
	}
	if _, err := p.metadata.RecordSkillVersion(ctx, skillID, catalog.SkillVersion{
		Version: info.Version, CommitSHA: info.CommitSHA, TreeSHA: info.TreeSHA,
		RelativePath: ".", CommitTime: info.Time,
	}); err != nil {
		return fmt.Errorf("record Skill version metadata: %w", err)
	}
	return nil
}

func metadataFromArchive(archiveBytes []byte, skillID, version string) (protocolmanifest.Manifest, string, error) {
	var metadata protocolmanifest.Manifest
	digest, err := protocolartifact.WalkContent(archiveBytes, skillID, version, func(entry protocolartifact.Entry) error {
		if entry.Directory || entry.Path != "SKILL.md" {
			return nil
		}
		parsed, err := protocolmanifest.ValidatePublished(entry.Contents)
		if err != nil {
			return err
		}
		metadata = parsed
		return nil
	})
	if err != nil {
		return protocolmanifest.Manifest{}, "", fmt.Errorf("read Skill archive metadata: %w", err)
	}
	if metadata.Name == "" || metadata.Description == "" {
		return protocolmanifest.Manifest{}, "", fmt.Errorf("decode SKILL.md frontmatter: name and description are required")
	}
	return metadata, digest, nil
}
