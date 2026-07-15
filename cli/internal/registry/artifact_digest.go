/*
 * [INPUT]: Depends on immutable Skill ZIP bytes or extracted Store directories, canonical coordinates, resolved versions, and the Registry digest framing contract.
 * [OUTPUT]: Provides bounded compression-independent ZIP/directory Content Digest computation and declared-digest verification.
 * [POS]: Serves as the CLI integrity boundary binding assessed Info metadata to downloaded and locally cached artifact files.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package registry

import (
	"archive/zip"
	"bytes"
	"crypto/sha256"
	"encoding/binary"
	"fmt"
	"io"
	"os"
	"path"
	"path/filepath"
	"sort"
	"strings"
)

const (
	maxArtifactArchiveBytes = 64 << 20
	maxArtifactFiles        = 5000
	maxArtifactUncompressed = 64 << 20
)

// VerifyContentDigest rejects artifact bytes that do not match assessed Info.
func VerifyContentDigest(data []byte, coordinate, version, expected string) error {
	actual, err := ContentDigest(data, coordinate, version)
	if err != nil {
		return err
	}
	if actual != expected {
		return fmt.Errorf("Registry Content Digest mismatch for %s@%s: %s != %s", coordinate, version, actual, expected)
	}
	return nil
}

// VerifyContentDirectory rejects a locally modified extracted Store artifact.
func VerifyContentDirectory(root, expected string) error {
	actual, err := ContentDirectoryDigest(root)
	if err != nil {
		return err
	}
	if actual != expected {
		return fmt.Errorf("Store Content Digest mismatch: %s != %s", actual, expected)
	}
	return nil
}

// ContentDirectoryDigest applies the Registry framing contract to an extracted
// artifact while rejecting symlinks, special files, and oversized content.
func ContentDirectoryDigest(root string) (string, error) {
	root, err := filepath.Abs(root)
	if err != nil {
		return "", err
	}
	paths := make([]string, 0)
	var total uint64
	err = filepath.WalkDir(root, func(current string, entry os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if current == root || entry.IsDir() {
			return nil
		}
		info, err := entry.Info()
		if err != nil {
			return err
		}
		if !info.Mode().IsRegular() || info.Size() < 0 {
			return fmt.Errorf("Store artifact contains unsupported file %q", current)
		}
		relative, err := filepath.Rel(root, current)
		if err != nil {
			return err
		}
		relative = filepath.ToSlash(relative)
		if !validArtifactRelativePath(relative) {
			return fmt.Errorf("Store artifact contains invalid path %q", relative)
		}
		size := uint64(info.Size())
		if size > maxArtifactUncompressed || total > maxArtifactUncompressed-size {
			return fmt.Errorf("Store artifact exceeds %d bytes", maxArtifactUncompressed)
		}
		total += size
		paths = append(paths, relative)
		if len(paths) > maxArtifactFiles {
			return fmt.Errorf("Store artifact contains more than %d files", maxArtifactFiles)
		}
		return nil
	})
	if err != nil {
		return "", err
	}
	sort.Strings(paths)
	hash := sha256.New()
	for _, relative := range paths {
		contents, err := readArtifactPath(filepath.Join(root, filepath.FromSlash(relative)))
		if err != nil {
			return "", fmt.Errorf("read Store artifact file %q: %w", relative, err)
		}
		if err := writeContentDigestEntry(hash, relative, contents); err != nil {
			return "", err
		}
	}
	if _, err := os.Stat(filepath.Join(root, "SKILL.md")); err != nil {
		return "", fmt.Errorf("Store artifact does not contain SKILL.md: %w", err)
	}
	return fmt.Sprintf("sha256:%x", hash.Sum(nil)), nil
}

// ContentDigest implements the Registry's normalized file-path/content framing.
func ContentDigest(data []byte, coordinate, version string) (string, error) {
	if len(data) == 0 || len(data) > maxArtifactArchiveBytes {
		return "", fmt.Errorf("artifact archive size must be between 1 and %d bytes", maxArtifactArchiveBytes)
	}
	reader, err := zip.NewReader(bytes.NewReader(data), int64(len(data)))
	if err != nil {
		return "", fmt.Errorf("open artifact archive: %w", err)
	}
	if len(reader.File) > maxArtifactFiles {
		return "", fmt.Errorf("artifact contains more than %d files", maxArtifactFiles)
	}
	entries := append([]*zip.File(nil), reader.File...)
	sort.Slice(entries, func(i, j int) bool { return entries[i].Name < entries[j].Name })
	prefix := coordinate + "@" + version + "/"
	hash := sha256.New()
	seen := map[string]bool{}
	var total uint64
	for _, entry := range entries {
		if entry.FileInfo().IsDir() {
			continue
		}
		if !strings.HasPrefix(entry.Name, prefix) {
			return "", fmt.Errorf("artifact file %q is outside expected prefix %q", entry.Name, prefix)
		}
		relative := strings.TrimPrefix(entry.Name, prefix)
		if !validArtifactRelativePath(relative) || seen[relative] {
			return "", fmt.Errorf("artifact file has invalid or duplicate path %q", relative)
		}
		seen[relative] = true
		if entry.UncompressedSize64 > maxArtifactUncompressed ||
			total > maxArtifactUncompressed-entry.UncompressedSize64 {
			return "", fmt.Errorf("artifact expands beyond %d bytes", maxArtifactUncompressed)
		}
		total += entry.UncompressedSize64
		contents, err := readArtifactEntry(entry)
		if err != nil {
			return "", fmt.Errorf("read artifact file %q: %w", relative, err)
		}
		if err := writeContentDigestEntry(hash, relative, contents); err != nil {
			return "", err
		}
	}
	if !seen["SKILL.md"] {
		return "", fmt.Errorf("artifact does not contain SKILL.md")
	}
	return fmt.Sprintf("sha256:%x", hash.Sum(nil)), nil
}

func readArtifactPath(filePath string) ([]byte, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return nil, err
	}
	defer file.Close()
	contents, err := io.ReadAll(io.LimitReader(file, maxArtifactUncompressed+1))
	if err != nil {
		return nil, err
	}
	if len(contents) > maxArtifactUncompressed {
		return nil, fmt.Errorf("file exceeds %d bytes", maxArtifactUncompressed)
	}
	return contents, nil
}

func writeContentDigestEntry(writer io.Writer, relative string, contents []byte) error {
	if err := binary.Write(writer, binary.BigEndian, uint64(len(relative))); err != nil {
		return err
	}
	if _, err := io.WriteString(writer, relative); err != nil {
		return err
	}
	if err := binary.Write(writer, binary.BigEndian, uint64(len(contents))); err != nil {
		return err
	}
	_, err := writer.Write(contents)
	return err
}

func readArtifactEntry(entry *zip.File) ([]byte, error) {
	reader, err := entry.Open()
	if err != nil {
		return nil, err
	}
	defer reader.Close()
	contents, err := io.ReadAll(io.LimitReader(reader, maxArtifactUncompressed+1))
	if err != nil {
		return nil, err
	}
	if len(contents) > maxArtifactUncompressed || uint64(len(contents)) != entry.UncompressedSize64 {
		return nil, fmt.Errorf("uncompressed size does not match archive metadata")
	}
	return contents, nil
}

func validArtifactRelativePath(value string) bool {
	return value != "" && value != "." && !strings.HasPrefix(value, "/") &&
		!strings.Contains(value, "\\") && path.Clean(value) == value &&
		value != ".." && !strings.HasPrefix(value, "../")
}
