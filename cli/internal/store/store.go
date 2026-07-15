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

	"github.com/skillsgo/skillsgo/cli/internal/registry"
	"gopkg.in/yaml.v3"
)

var ErrNotFound = fmt.Errorf("Store 条目不存在")

type Receipt struct {
	Coordinate string          `yaml:"coordinate"`
	Version    string          `yaml:"version"`
	SHA256     string          `yaml:"sha256"`
	Origin     registry.Origin `yaml:"origin"`
}

type Entry struct {
	Root     string
	Artifact string
	Receipt  Receipt
}

type Store struct{ Root string }

func DefaultRoot(home string) string { return filepath.Join(home, ".skillsgo", "store") }

func (s Store) Get(coordinate, version string) (*Entry, error) {
	root := s.entryRoot(coordinate, version)
	receipt, err := readReceipt(filepath.Join(root, "receipt.yaml"))
	if os.IsNotExist(err) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	if receipt.Coordinate != coordinate || receipt.Version != version {
		return nil, fmt.Errorf("Store 条目身份不匹配：期望 %s@%s，得到 %s@%s", coordinate, version, receipt.Coordinate, receipt.Version)
	}
	artifact := filepath.Join(root, "artifact")
	if info, err := os.Stat(filepath.Join(artifact, "SKILL.md")); err != nil || !info.Mode().IsRegular() {
		if err == nil {
			err = fmt.Errorf("不是普通文件")
		}
		return nil, fmt.Errorf("Store 条目缺少有效 SKILL.md: %w", err)
	}
	return &Entry{Root: root, Artifact: artifact, Receipt: receipt}, nil
}

func (s Store) entryRoot(coordinate, version string) string {
	return filepath.Join(s.Root, filepath.FromSlash(coordinate+"@"+version))
}

func (s Store) Put(artifact *registry.Artifact) (*Entry, error) {
	receipt := Receipt{Coordinate: artifact.Coordinate, Version: artifact.Info.Version, Origin: artifact.Info.Origin}
	hash := sha256.Sum256(artifact.ZIP)
	receipt.SHA256 = hex.EncodeToString(hash[:])
	root := s.entryRoot(artifact.Coordinate, artifact.Info.Version)
	artifactRoot := filepath.Join(root, "artifact")
	if existing, err := readReceipt(filepath.Join(root, "receipt.yaml")); err == nil && existing.SHA256 == receipt.SHA256 {
		return &Entry{Root: root, Artifact: artifactRoot, Receipt: existing}, nil
	}
	if _, err := os.Stat(root); err == nil {
		return nil, fmt.Errorf("Store 条目 %q 已存在，但制品摘要不同", root)
	} else if !os.IsNotExist(err) {
		return nil, err
	}

	if err := os.MkdirAll(filepath.Dir(root), 0o700); err != nil {
		return nil, err
	}
	temp, err := os.MkdirTemp(filepath.Dir(root), ".skillsgo-store-")
	if err != nil {
		return nil, err
	}
	defer os.RemoveAll(temp)
	if err := extract(artifact.ZIP, artifact.Coordinate+"@"+artifact.Info.Version+"/", filepath.Join(temp, "artifact")); err != nil {
		return nil, err
	}
	if err := os.WriteFile(filepath.Join(temp, "info.json"), mustJSON(artifact.Info), 0o600); err != nil {
		return nil, err
	}
	if err := os.WriteFile(filepath.Join(temp, "manifest.yaml"), artifact.Manifest, 0o600); err != nil {
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
			if err := os.MkdirAll(target, 0o700); err != nil {
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
