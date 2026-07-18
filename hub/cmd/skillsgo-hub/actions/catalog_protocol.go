/*
 * [INPUT]: Depends on immutable artifact protocol reads, Catalog metadata, ZIP audit analysis, and normalized SKILL.md frontmatter.
 * [OUTPUT]: Provides a protocol decorator that indexes resolved Skills and enriches exact Info with normalized install metadata, Risk, Content Digest, and Archive Size.
 * [POS]: Serves as the Hub distribution boundary connecting source artifacts, immutable assessment, and public protocol bytes.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"archive/zip"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"strings"
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/audit"
	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/skillsgo/skillsgo/hub/pkg/download"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	"gopkg.in/yaml.v3"
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
	Version       string    `json:"Version"`
	Time          time.Time `json:"Time"`
	Ref           string    `json:"Ref"`
	CommitSHA     string    `json:"CommitSHA"`
	TreeSHA       string    `json:"TreeSHA"`
	Risk          string    `json:"Risk"`
	ContentDigest string    `json:"ContentDigest"`
	ArchiveSize   int64     `json:"ArchiveSize"`
}

type skillFrontmatter struct {
	Name          string            `yaml:"name"`
	Description   string            `yaml:"description"`
	License       string            `yaml:"license"`
	Compatibility string            `yaml:"compatibility"`
	AllowedTools  string            `yaml:"allowed-tools"`
	Metadata      map[string]string `yaml:"metadata"`
}

func (p *catalogProtocol) Info(ctx context.Context, skillID, version string) ([]byte, error) {
	info, err := p.Protocol.Info(ctx, skillID, version)
	if err != nil {
		return nil, err
	}
	assessed, err := p.bindAssessment(ctx, skillID, info, nil)
	if err != nil {
		return nil, err
	}
	if shouldIndexCatalog(ctx) {
		if err := p.index(ctx, skillID, assessed); err != nil {
			return nil, err
		}
	}
	return assessed, nil
}

func (p *catalogProtocol) bindAssessment(ctx context.Context, skillID string, infoBytes, archiveBytes []byte) ([]byte, error) {
	var info catalogArtifactInfo
	if err := json.Unmarshal(infoBytes, &info); err != nil || info.Version == "" {
		return nil, fmt.Errorf("decode Skill info for assessment: Version is required")
	}
	if archiveBytes == nil {
		archive, err := p.Protocol.Zip(ctx, skillID, info.Version)
		if err != nil {
			return nil, fmt.Errorf("read Skill archive for assessment: %w", err)
		}
		archiveBytes, err = readAuditArchive(archive)
		if err != nil {
			return nil, err
		}
	}
	metadata, err := metadataFromArchive(archiveBytes)
	if err != nil {
		return nil, err
	}
	if metadata.Name == "" || metadata.Description == "" {
		return nil, fmt.Errorf("decode Skill metadata for Info: name and description are required")
	}
	analysis, err := audit.AnalyzeArtifact(archiveBytes, skillID, info.Version)
	if err != nil {
		return nil, fmt.Errorf("assess Skill archive: %w", err)
	}
	var response map[string]any
	if err := json.Unmarshal(infoBytes, &response); err != nil {
		return nil, fmt.Errorf("decode Skill info response: %w", err)
	}
	response["Risk"] = analysis.Risk.Level
	response["ContentDigest"] = analysis.ContentDigest
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
	assessed, err := p.bindAssessment(ctx, skillID, info, archiveBytes)
	if err != nil {
		return nil, err
	}
	if shouldIndexCatalog(ctx) {
		if err := p.index(ctx, skillID, assessed); err != nil {
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
		ContentDigest: info.ContentDigest, CommitTime: info.Time, ArchiveSize: info.ArchiveSize,
	}); err != nil {
		return fmt.Errorf("record Skill version metadata: %w", err)
	}
	return nil
}

func metadataFromArchive(archiveBytes []byte) (skillFrontmatter, error) {
	reader, err := zip.NewReader(bytes.NewReader(archiveBytes), int64(len(archiveBytes)))
	if err != nil {
		return skillFrontmatter{}, fmt.Errorf("read Skill archive metadata: %w", err)
	}
	for _, file := range reader.File {
		if !strings.HasSuffix(file.Name, "/SKILL.md") {
			continue
		}
		opened, err := file.Open()
		if err != nil {
			return skillFrontmatter{}, err
		}
		contents, readErr := io.ReadAll(opened)
		closeErr := opened.Close()
		if readErr != nil {
			return skillFrontmatter{}, readErr
		}
		if closeErr != nil {
			return skillFrontmatter{}, closeErr
		}
		parts := bytes.SplitN(contents, []byte("---"), 3)
		if len(parts) != 3 || len(bytes.TrimSpace(parts[0])) != 0 {
			return skillFrontmatter{}, fmt.Errorf("SKILL.md is missing YAML frontmatter")
		}
		var metadata skillFrontmatter
		if err := yaml.Unmarshal(parts[1], &metadata); err != nil {
			return skillFrontmatter{}, fmt.Errorf("decode SKILL.md frontmatter: %w", err)
		}
		if metadata.Name == "" || metadata.Description == "" {
			return skillFrontmatter{}, fmt.Errorf("decode SKILL.md frontmatter: name and description are required")
		}
		return metadata, nil
	}
	return skillFrontmatter{}, fmt.Errorf("Skill archive contains no SKILL.md")
}
