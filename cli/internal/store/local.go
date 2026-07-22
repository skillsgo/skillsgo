/*
 * [INPUT]: Depends on reviewed existing Skill directories, canonical source identity, content framing, safe ZIP construction, and an explicit export destination.
 * [OUTPUT]: Imports immutable private Local Skill artifacts, captures stable source/content/filesystem-state-identified takeover baselines with explicit change detection, and exports only Local-provenance entries without network access.
 * [POS]: Serves as the local and captured Skill persistence boundary beside Hub-backed Store ingestion.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package store

import (
	"archive/zip"
	"bytes"
	"compress/flate"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/skillsgo/skillsgo/cli/internal/hub"
	"github.com/skillsgo/skillsgo/cli/internal/source"
)

var ErrCaptureChanged = errors.New("captured Skill changed while reading")

// CaptureExisting imports the exact current bytes of a source-identified Skill
// as an immutable Store baseline without changing the live target directory.
func (s Store) CaptureExisting(root, name, skillID, _ string) (*Entry, error) {
	if err := validateArtifactName(name); err != nil {
		return nil, err
	}
	if err := source.ValidateSkillID(skillID); err != nil {
		return nil, err
	}
	info, err := os.Lstat(root)
	if err != nil {
		return nil, err
	}
	if !info.IsDir() || info.Mode()&os.ModeSymlink != 0 {
		return nil, fmt.Errorf("captured Skill requires a real directory")
	}
	digest, err := hub.DirectorySum(root)
	if err != nil {
		return nil, err
	}
	stateDigest, err := capturedDirectoryDigest(root)
	if err != nil {
		return nil, err
	}
	hexDigest := sumKey(digest)
	sourceDigest := sha256.Sum256([]byte(skillID))
	artifactSkillID := "captured.skillsgo/" + hex.EncodeToString(sourceDigest[:]) + "/" + hexDigest + "/" + stateDigest + "/" + name
	version := "captured-" + stateDigest[:12]
	if existing, getErr := s.Get(artifactSkillID, version); getErr == nil {
		if existing.Receipt.EffectiveProvenance() != ProvenanceCaptured ||
			existing.Receipt.EffectiveSourceSkillID() != skillID ||
			existing.Receipt.Sum != digest {
			return nil, fmt.Errorf("captured Store baseline identity conflicts with existing entry")
		}
		existingState, stateErr := capturedDirectoryDigest(existing.Artifact)
		if stateErr != nil || existingState != stateDigest {
			return nil, fmt.Errorf("captured Store baseline state conflicts with existing entry")
		}
		return existing, nil
	}
	archive, err := archiveDirectory(root, artifactSkillID+"@"+version)
	if err != nil {
		return nil, err
	}
	afterDigest, err := hub.DirectorySum(root)
	if err != nil || afterDigest != digest {
		return nil, ErrCaptureChanged
	}
	afterStateDigest, err := capturedDirectoryDigest(root)
	if err != nil || afterStateDigest != stateDigest {
		return nil, ErrCaptureChanged
	}
	if err := hub.VerifySum(archive, artifactSkillID, version, digest); err != nil {
		return nil, ErrCaptureChanged
	}
	return s.put(&hub.Artifact{
		SkillID: artifactSkillID,
		Info: hub.Info{
			SchemaVersion: 1,
			Kind:          "Skill",
			ID:            artifactSkillID,
			Version:       version,
			Name:          name,
			Description:   "Captured existing Skill baseline",
			Risk:          hub.RiskUnknown,
			Sum:           digest,
			Ref:           version,
		},
		ZIP: archive,
	}, ProvenanceCaptured, skillID)
}

func sumKey(sum string) string {
	digest := sha256.Sum256([]byte(sum))
	return hex.EncodeToString(digest[:])
}

// capturedDirectoryDigest binds a captured baseline to the exact regular-file
// tree that archiveDirectory preserves, including empty directories and modes.
func capturedDirectoryDigest(root string) (string, error) {
	hash := sha256.New()
	_, _ = hash.Write([]byte("skillsgo-captured-directory-v1\x00"))
	err := filepath.WalkDir(root, func(current string, entry fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if current == root {
			return nil
		}
		relative, err := filepath.Rel(root, current)
		if err != nil {
			return err
		}
		info, err := entry.Info()
		if err != nil {
			return err
		}
		kind := byte('f')
		if entry.IsDir() {
			kind = 'd'
		} else if !info.Mode().IsRegular() {
			return fmt.Errorf("captured Skill contains unsupported file %q", current)
		}
		relative = filepath.ToSlash(relative)
		_, _ = hash.Write([]byte{kind})
		if err := binary.Write(hash, binary.BigEndian, uint64(len(relative))); err != nil {
			return err
		}
		_, _ = io.WriteString(hash, relative)
		if err := binary.Write(hash, binary.BigEndian, uint32(info.Mode().Perm())); err != nil {
			return err
		}
		if entry.IsDir() {
			return nil
		}
		if err := binary.Write(hash, binary.BigEndian, uint64(info.Size())); err != nil {
			return err
		}
		file, err := os.Open(current)
		if err != nil {
			return err
		}
		_, copyErr := io.Copy(hash, file)
		closeErr := file.Close()
		if copyErr != nil {
			return copyErr
		}
		return closeErr
	})
	if err != nil {
		return "", err
	}
	return hex.EncodeToString(hash.Sum(nil)), nil
}

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
	digest, err := hub.DirectorySum(root)
	if err != nil {
		return nil, err
	}
	hexDigest := sumKey(digest)
	skillID := "local.skillsgo/" + hexDigest + "/" + name
	version := "local-" + hexDigest[:12]
	if err := source.ValidateSkillID(skillID); err != nil {
		return nil, err
	}
	archive, err := archiveDirectory(root, skillID+"@"+version)
	if err != nil {
		return nil, err
	}
	if _, err := localManifest(filepath.Join(root, "SKILL.md"), name); err != nil {
		return nil, err
	}
	return s.put(&hub.Artifact{
		SkillID: skillID,
		Info: hub.Info{
			SchemaVersion: 1, Kind: "Skill", ID: skillID, Version: version,
			Name: name, Description: "Private local Skill", Risk: hub.RiskUnknown, Sum: digest,
			Ref: version,
		},
		ZIP: archive,
	}, ProvenanceLocal, "")
}

func (s Store) ExportLocal(skillID, version, destination string) error {
	entry, err := s.Get(skillID, version)
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
		if path == root {
			return nil
		}
		info, err := entry.Info()
		if err != nil {
			return err
		}
		relative, err := filepath.Rel(root, path)
		if err != nil {
			return err
		}
		if entry.IsDir() {
			header, err := zip.FileInfoHeader(info)
			if err != nil {
				return err
			}
			header.Name = filepath.ToSlash(filepath.Join(prefix, relative)) + "/"
			header.SetModTime(time.Date(1980, time.January, 1, 0, 0, 0, 0, time.UTC))
			_, err = writer.CreateHeader(header)
			return err
		}
		if !info.Mode().IsRegular() {
			return fmt.Errorf("Local Skill contains unsupported file %q", path)
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
