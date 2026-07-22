/*
 * [INPUT]: Depends on validated Skill IDs, immutable Hub Info or Local Skill metadata, shared validated ZIP traversal, and filesystem containment rules.
 * [OUTPUT]: Provides concurrency-safe confined coordinate put/get operations, cross-coordinate Hub CAS objects, collision-safe extraction, read-only immutable artifacts, integrity checks, provenance receipts, and separately refreshable assessment metadata.
 * [POS]: Serves as the local Content-addressed Store boundary beneath installation and inventory flows.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package store

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/skillsgo/skillsgo/cli/internal/hub"
	"github.com/skillsgo/skillsgo/cli/internal/source"
	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
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
	artifact, err := s.referencedArtifactRoot(root)
	if err != nil {
		return nil, err
	}
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
	if artifact.Info.Risk == "" {
		artifact.Info.Risk = hub.RiskUnknown
	}
	if !artifact.Info.Risk.Valid() || !hub.ValidSum(artifact.Info.Sum) {
		return nil, fmt.Errorf("Hub artifact is missing immutable content metadata")
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
	temporaryArtifact := filepath.Join(temp, "artifact")
	if err := extract(artifact.ZIP, artifact.SkillID, artifact.Info.Version, temporaryArtifact); err != nil {
		return nil, err
	}
	if provenance == ProvenanceHub {
		var objectKey string
		artifactRoot, objectKey, err = s.publishHubObject(temporaryArtifact, receipt.Sum)
		if err != nil {
			return nil, err
		}
		if err := os.WriteFile(filepath.Join(temp, objectReferenceFile), []byte(objectKey+"\n"), 0o600); err != nil {
			return nil, err
		}
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

func extract(data []byte, skillID, version, destination string) error {
	if err := os.MkdirAll(destination, 0o700); err != nil {
		return err
	}
	_, err := protocolartifact.WalkContent(data, skillID, version, func(entry protocolartifact.Entry) error {
		target := filepath.Join(destination, filepath.FromSlash(entry.Path))
		if entry.Directory {
			mode := entry.Mode.Perm()
			if mode == 0 {
				mode = 0o700
			}
			if err := os.MkdirAll(target, mode); err != nil {
				return err
			}
			return os.Chmod(target, mode)
		}
		if err := os.MkdirAll(filepath.Dir(target), 0o700); err != nil {
			return err
		}
		mode := entry.Mode.Perm()
		if mode == 0 {
			mode = 0o600
		}
		return os.WriteFile(target, entry.Contents, mode)
	})
	return err
}

func makeArtifactReadOnly(root string) error {
	var directories []string
	err := filepath.WalkDir(root, func(path string, entry os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if entry.IsDir() {
			directories = append(directories, path)
			return nil
		}
		info, err := entry.Info()
		if err != nil {
			return err
		}
		mode := os.FileMode(0o444)
		if info.Mode()&0o111 != 0 {
			mode = 0o555
		}
		return os.Chmod(path, mode)
	})
	if err != nil {
		return err
	}
	for index := len(directories) - 1; index >= 0; index-- {
		if err := os.Chmod(directories[index], 0o755); err != nil {
			return err
		}
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
