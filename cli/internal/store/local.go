/*
 * [INPUT]: Depends on a reviewed external Skill directory, content framing, safe ZIP construction, and an explicit export destination.
 * [OUTPUT]: Imports immutable private Local Skill artifacts into the Store and exports only provenance-confirmed Local Skills without network access.
 * [POS]: Serves as the private Local Skill persistence boundary beside Registry-backed Store ingestion.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package store

import (
	"archive/zip"
	"bytes"
	"compress/flate"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/skillsgo/skillsgo/cli/internal/registry"
	"github.com/skillsgo/skillsgo/cli/internal/source"
	"gopkg.in/yaml.v3"
)

func (s Store) ImportLocal(root, name string) (*Entry, error) {
	if err := validateLocalName(name); err != nil {
		return nil, err
	}
	info, err := os.Lstat(root)
	if err != nil {
		return nil, err
	}
	if !info.IsDir() {
		return nil, fmt.Errorf("Local Skill import requires a real directory")
	}
	digest, err := registry.ContentDirectoryDigest(root)
	if err != nil {
		return nil, err
	}
	hexDigest := strings.TrimPrefix(digest, "sha256:")
	coordinate := "local.skillsgo/" + hexDigest + "/" + name
	version := "local-" + hexDigest[:12]
	if err := source.ValidateCoordinate(coordinate); err != nil {
		return nil, err
	}
	archive, err := archiveDirectory(root, coordinate+"@"+version)
	if err != nil {
		return nil, err
	}
	manifest, err := localManifest(filepath.Join(root, "SKILL.md"), name)
	if err != nil {
		return nil, err
	}
	entry, err := s.Put(&registry.Artifact{
		Coordinate: coordinate,
		Info: registry.Info{
			Version: version, Risk: registry.RiskUnknown, ContentDigest: digest,
			Origin: registry.Origin{VCS: "local", Ref: version},
		},
		Manifest: manifest,
		ZIP:      archive,
	})
	if err != nil {
		return nil, err
	}
	receipt := entry.Receipt
	receipt.Name = name
	receipt.Provenance = ProvenanceLocal
	data, err := yaml.Marshal(receipt)
	if err != nil {
		return nil, err
	}
	if err := writeFileAtomic(filepath.Join(entry.Root, "receipt.yaml"), data, 0o600); err != nil {
		return nil, err
	}
	entry.Receipt = receipt
	return entry, nil
}

func (s Store) ExportLocal(coordinate, version, destination string) error {
	entry, err := s.Get(coordinate, version)
	if err != nil {
		return err
	}
	if entry.Receipt.EffectiveProvenance() != ProvenanceLocal {
		return fmt.Errorf("only private Local Skills can be exported")
	}
	name := entry.Receipt.Name
	if err := validateLocalName(name); err != nil {
		return err
	}
	archive, err := archiveDirectory(entry.Artifact, name)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(destination), 0o700); err != nil {
		return err
	}
	temporary, err := os.CreateTemp(filepath.Dir(destination), ".skillsgo-export-")
	if err != nil {
		return err
	}
	temporaryPath := temporary.Name()
	defer os.Remove(temporaryPath)
	if err := temporary.Chmod(0o600); err != nil {
		_ = temporary.Close()
		return err
	}
	if _, err := temporary.Write(archive); err != nil {
		_ = temporary.Close()
		return err
	}
	if err := temporary.Close(); err != nil {
		return err
	}
	return os.Rename(temporaryPath, destination)
}

func archiveDirectory(root, prefix string) ([]byte, error) {
	var buffer bytes.Buffer
	writer := zip.NewWriter(&buffer)
	writer.RegisterCompressor(zip.Deflate, func(output io.Writer) (io.WriteCloser, error) {
		return flate.NewWriter(output, flate.BestCompression)
	})
	err := filepath.WalkDir(root, func(path string, entry fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if path == root || entry.IsDir() {
			return nil
		}
		info, err := entry.Info()
		if err != nil {
			return err
		}
		if !info.Mode().IsRegular() {
			return fmt.Errorf("Local Skill contains unsupported file %q", path)
		}
		relative, err := filepath.Rel(root, path)
		if err != nil {
			return err
		}
		header, err := zip.FileInfoHeader(info)
		if err != nil {
			return err
		}
		header.Name = filepath.ToSlash(filepath.Join(prefix, relative))
		header.Method = zip.Deflate
		header.SetModTime(time.Date(1980, time.January, 1, 0, 0, 0, 0, time.UTC))
		output, err := writer.CreateHeader(header)
		if err != nil {
			return err
		}
		input, err := os.Open(path)
		if err != nil {
			return err
		}
		_, copyErr := io.Copy(output, input)
		closeErr := input.Close()
		if copyErr != nil {
			return copyErr
		}
		return closeErr
	})
	if err != nil {
		_ = writer.Close()
		return nil, err
	}
	if err := writer.Close(); err != nil {
		return nil, err
	}
	return buffer.Bytes(), nil
}

func localManifest(path, name string) ([]byte, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	normalized := strings.ReplaceAll(string(data), "\r\n", "\n")
	if strings.HasPrefix(normalized, "---\n") {
		if end := strings.Index(normalized[4:], "\n---\n"); end >= 0 {
			return []byte(normalized[4 : 4+end]), nil
		}
	}
	return []byte("name: " + name + "\n"), nil
}

func validateLocalName(name string) error {
	if name == "" || name == "." || name == ".." || name != filepath.Base(name) || strings.ContainsAny(name, `/\\\x00`) {
		return fmt.Errorf("invalid Local Skill name %q", name)
	}
	return nil
}
