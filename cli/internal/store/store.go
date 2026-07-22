/*
 * [INPUT]: Depends on validated Skill IDs, enriched immutable Hub Info or Local Skill metadata, ZIP archives, and filesystem containment rules.
 * [OUTPUT]: Provides concurrency-safe confined immutable Store put/get operations, safe extraction, immutable-content checks, Info-named Hub/Local/captured provenance receipts, and refreshable assessment metadata.
 * [POS]: Serves as the local Content-addressed Store boundary beneath installation and inventory flows.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package store

import (
	"archive/zip"
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/skillsgo/skillsgo/cli/internal/hub"
	"github.com/skillsgo/skillsgo/cli/internal/source"
	protocolmanifest "github.com/skillsgo/skillsgo/protocol/skillmanifest"
	"gopkg.in/yaml.v3"
)

var ErrNotFound = fmt.Errorf("Store 条目不存在")

type Receipt struct {
	SkillID       string     `yaml:"skillId"`
	SourceSkillID string     `yaml:"sourceSkillId,omitempty"`
	Version       string     `yaml:"version"`
	Name          string     `yaml:"name,omitempty"`
	Provenance    Provenance `yaml:"provenance,omitempty"`
	SHA256        string     `yaml:"sha256"`
	Sum           string     `yaml:"sum"`
	Risk          hub.Risk   `yaml:"risk"`
	Ref           string     `yaml:"ref,omitempty"`
	CommitSHA     string     `yaml:"commitSHA,omitempty"`
	TreeSHA       string     `yaml:"treeSHA,omitempty"`
}

type Provenance string

const (
	ProvenanceHub      Provenance = "hub"
	ProvenanceLocal    Provenance = "local"
	ProvenanceCaptured Provenance = "captured"
)

func (receipt Receipt) EffectiveProvenance() Provenance {
	if receipt.Provenance == "" {
		return ProvenanceHub
	}
	return receipt.Provenance
}

func (receipt Receipt) EffectiveSourceSkillID() string {
	if receipt.SourceSkillID != "" {
		return receipt.SourceSkillID
	}
	return receipt.SkillID
}

type Entry struct {
	Root     string
	Artifact string
	Receipt  Receipt
}

type Store struct{ Root string }

func DefaultRoot(home string) string { return filepath.Join(home, ".skillsgo", "store") }

func (s Store) Get(skillID, version string) (*Entry, error) {
	root, err := s.entryRoot(skillID, version)
	if err != nil {
		return nil, err
	}
	receipt, err := readReceipt(filepath.Join(root, "receipt.yaml"))
	if os.IsNotExist(err) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	if receipt.SkillID != skillID || receipt.Version != version {
		return nil, fmt.Errorf("Store 条目身份不匹配：期望 %s@%s，得到 %s@%s", skillID, version, receipt.SkillID, receipt.Version)
	}
	if !receipt.Risk.Valid() || !hub.ValidSum(receipt.Sum) {
		return nil, fmt.Errorf("Store entry is missing immutable assessment metadata")
	}
	artifact := filepath.Join(root, "artifact")
	if info, err := os.Stat(filepath.Join(artifact, "SKILL.md")); err != nil || !info.Mode().IsRegular() {
		if err == nil {
			err = fmt.Errorf("不是普通文件")
		}
		return nil, fmt.Errorf("Store 条目缺少有效 SKILL.md: %w", err)
	}
	if err := hub.VerifyDirectorySum(artifact, receipt.Sum); err != nil {
		return nil, fmt.Errorf("Store artifact integrity check failed: %w", err)
	}
	return &Entry{Root: root, Artifact: artifact, Receipt: receipt}, nil
}

func (s Store) entryRoot(skillID, version string) (string, error) {
	if err := source.ValidateSkillID(skillID); err != nil {
		return "", err
	}
	if err := source.ValidateVersion(version); err != nil {
		return "", fmt.Errorf("invalid immutable Skill version %q: %w", version, err)
	}
	root, err := filepath.Abs(s.Root)
	if err != nil {
		return "", err
	}
	candidate := filepath.Join(root, filepath.FromSlash(skillID+"@"+version))
	relative, err := filepath.Rel(root, candidate)
	if err != nil || relative == ".." || strings.HasPrefix(relative, ".."+string(filepath.Separator)) {
		return "", fmt.Errorf("Store entry escapes configured root")
	}
	return candidate, nil
}

func (s Store) Put(artifact *hub.Artifact) (*Entry, error) {
	return s.put(artifact, ProvenanceHub, "")
}

func (s Store) put(artifact *hub.Artifact, provenance Provenance, sourceSkillID string) (*Entry, error) {
	if !artifact.Info.Risk.Valid() || !hub.ValidSum(artifact.Info.Sum) {
		return nil, fmt.Errorf("Hub artifact is missing immutable assessment metadata")
	}
	if err := hub.VerifySum(
		artifact.ZIP, artifact.SkillID, artifact.Info.Version, artifact.Info.Sum,
	); err != nil {
		return nil, err
	}
	name := artifact.Info.Name
	if err := validateArtifactName(name); err != nil {
		return nil, err
	}
	receipt := Receipt{
		SkillID: artifact.SkillID, Version: artifact.Info.Version, Name: name,
		Provenance: provenance, SourceSkillID: sourceSkillID, Sum: artifact.Info.Sum,
		Risk: artifact.Info.Risk, Ref: artifact.Info.Ref,
		CommitSHA: artifact.Info.CommitSHA, TreeSHA: artifact.Info.TreeSHA,
	}
	hash := sha256.Sum256(artifact.ZIP)
	receipt.SHA256 = hex.EncodeToString(hash[:])
	root, err := s.entryRoot(artifact.SkillID, artifact.Info.Version)
	if err != nil {
		return nil, err
	}
	if err := os.MkdirAll(filepath.Dir(root), 0o700); err != nil {
		return nil, err
	}
	unlock, err := acquireEntryLock(root)
	if err != nil {
		return nil, err
	}
	defer unlock()
	// Re-check after acquiring the version lock: another process may have
	// completed the same immutable entry while this writer was waiting.
	artifactRoot := filepath.Join(root, "artifact")
	if existing, err := readReceipt(filepath.Join(root, "receipt.yaml")); err == nil && existing.SHA256 == receipt.SHA256 {
		return s.RefreshAssessment(artifact.SkillID, artifact.Info.Version, artifact.Info)
	}
	if _, err := os.Stat(root); err == nil {
		return nil, fmt.Errorf("Store 条目 %q 已存在，但制品摘要不同", root)
	} else if !os.IsNotExist(err) {
		return nil, err
	}

	temp, err := os.MkdirTemp(filepath.Dir(root), ".skillsgo-store-")
	if err != nil {
		return nil, err
	}
	defer os.RemoveAll(temp)
	if err := extract(artifact.ZIP, artifact.SkillID+"@"+artifact.Info.Version+"/", filepath.Join(temp, "artifact")); err != nil {
		return nil, err
	}
	if err := os.WriteFile(filepath.Join(temp, "info.json"), mustJSON(artifact.Info), 0o600); err != nil {
		return nil, err
	}
	receiptBytes, err := yaml.Marshal(receipt)
	if err != nil {
		return nil, err
	}
	if err := os.WriteFile(filepath.Join(temp, "receipt.yaml"), receiptBytes, 0o600); err != nil {
		return nil, err
	}
	if err := os.Rename(temp, root); err != nil {
		return nil, err
	}
	return &Entry{Root: root, Artifact: artifactRoot, Receipt: receipt}, nil
}

func validateArtifactName(name string) error {
	if !protocolmanifest.ValidName(name) {
		return fmt.Errorf("invalid Hub artifact Info Skill name %q", name)
	}
	return nil
}

// RefreshAssessment updates risk metadata for an already cached immutable
// artifact without changing its content, provenance, or files.
func (s Store) RefreshAssessment(skillID, version string, info hub.Info) (*Entry, error) {
	if info.Version != version || !info.Risk.Valid() || !hub.ValidSum(info.Sum) {
		return nil, fmt.Errorf("Hub returned incomplete assessed Info for %s@%s", skillID, version)
	}
	entry, err := s.Get(skillID, version)
	if err != nil {
		return nil, err
	}
	if entry.Receipt.Sum != info.Sum {
		return nil, fmt.Errorf(
			"immutable Sum changed for %s@%s: %s != %s",
			skillID, version, entry.Receipt.Sum, info.Sum,
		)
	}
	if entry.Receipt.Ref != info.Ref || entry.Receipt.CommitSHA != info.CommitSHA || entry.Receipt.TreeSHA != info.TreeSHA {
		return nil, fmt.Errorf("immutable source identity changed for %s@%s", skillID, version)
	}
	updated := entry.Receipt
	updated.Risk = info.Risk
	receiptBytes, err := yaml.Marshal(updated)
	if err != nil {
		return nil, err
	}
	// Persist the enforcement receipt first so an interrupted refresh cannot
	// leave a newly elevated risk only in the informational metadata file.
	if err := writeFileAtomic(filepath.Join(entry.Root, "receipt.yaml"), receiptBytes, 0o600); err != nil {
		return nil, err
	}
	if err := writeFileAtomic(filepath.Join(entry.Root, "info.json"), mustJSON(info), 0o600); err != nil {
		return nil, err
	}
	entry.Receipt = updated
	return entry, nil
}

func writeFileAtomic(path string, data []byte, mode os.FileMode) error {
	temporary, err := os.CreateTemp(filepath.Dir(path), ".skillsgo-metadata-")
	if err != nil {
		return err
	}
	temporaryPath := temporary.Name()
	defer os.Remove(temporaryPath)
	if err := temporary.Chmod(mode); err != nil {
		_ = temporary.Close()
		return err
	}
	if _, err := temporary.Write(data); err != nil {
		_ = temporary.Close()
		return err
	}
	if err := temporary.Close(); err != nil {
		return err
	}
	return os.Rename(temporaryPath, path)
}

func extract(data []byte, prefix, destination string) error {
	zr, err := zip.NewReader(bytes.NewReader(data), int64(len(data)))
	if err != nil {
		return fmt.Errorf("读取 Skill ZIP: %w", err)
	}
	if err := os.MkdirAll(destination, 0o700); err != nil {
		return err
	}
	for _, file := range zr.File {
		if !strings.HasPrefix(file.Name, prefix) {
			return fmt.Errorf("ZIP 文件 %q 不属于预期前缀 %q", file.Name, prefix)
		}
		rel := strings.TrimPrefix(file.Name, prefix)
		if rel == "" {
			continue
		}
		clean := filepath.Clean(filepath.FromSlash(rel))
		if clean == "." || filepath.IsAbs(clean) || clean == ".." || strings.HasPrefix(clean, ".."+string(filepath.Separator)) {
			return fmt.Errorf("ZIP 包含不安全路径 %q", file.Name)
		}
		target := filepath.Join(destination, clean)
		if file.FileInfo().IsDir() {
			mode := file.Mode().Perm()
			if mode == 0 {
				mode = 0o700
			}
			if err := os.MkdirAll(target, mode); err != nil {
				return err
			}
			if err := os.Chmod(target, mode); err != nil {
				return err
			}
			continue
		}
		if !file.Mode().IsRegular() {
			return fmt.Errorf("ZIP 包含不支持的文件类型 %q", file.Name)
		}
		if err := os.MkdirAll(filepath.Dir(target), 0o700); err != nil {
			return err
		}
		source, err := file.Open()
		if err != nil {
			return err
		}
		mode := file.Mode().Perm()
		if mode == 0 {
			mode = 0o644
		}
		destinationFile, err := os.OpenFile(target, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, mode)
		if err != nil {
			source.Close()
			return err
		}
		_, copyErr := io.Copy(destinationFile, source)
		closeDestErr, closeSourceErr := destinationFile.Close(), source.Close()
		if copyErr != nil {
			return copyErr
		}
		if closeDestErr != nil {
			return closeDestErr
		}
		if closeSourceErr != nil {
			return closeSourceErr
		}
	}
	if _, err := os.Stat(filepath.Join(destination, "SKILL.md")); err != nil {
		return fmt.Errorf("ZIP 缺少根目录 SKILL.md: %w", err)
	}
	return nil
}

func readReceipt(path string) (Receipt, error) {
	var receipt Receipt
	data, err := os.ReadFile(path)
	if err != nil {
		return receipt, err
	}
	err = yaml.Unmarshal(data, &receipt)
	return receipt, err
}

func ReadReceipt(path string) (Receipt, error) {
	return readReceipt(path)
}

func mustJSON(value any) []byte {
	data, _ := json.MarshalIndent(value, "", "  ")
	data = append(data, '\n')
	return data
}
