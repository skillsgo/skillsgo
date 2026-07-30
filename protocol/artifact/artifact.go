/*
 * [INPUT]: Depends on immutable Package file inventories, legacy ZIP bytes, extracted Package directories, and canonical Package Path identity.
 * [OUTPUT]: Provides validated Package trees with typed validation reasons, deterministic legacy ZIP construction, shared limits, portable collision-safe paths, Package-contained symlink validation, normalized traversal, and coordinate-bound Sum calculation.
 * [POS]: Serves as the executable Package Artifact format contract shared by Hub producers and clients.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package artifact

import (
	"archive/zip"
	"bytes"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"fmt"
	"io"
	"os"
	"path"
	"path/filepath"
	"sort"
	"strings"
	"time"
	"unicode/utf8"

	"golang.org/x/mod/module"
	"golang.org/x/text/cases"
	"golang.org/x/text/unicode/norm"
)

const (
	MaxArchiveBytes      = 200 << 20
	MaxFiles             = 5000
	MaxUncompressedBytes = 200 << 20
)

// Entry is one validated file or explicit directory in normalized artifact-path order.
type Entry struct {
	Path      string
	Contents  []byte
	Mode      os.FileMode
	Size      int64
	Directory bool
}

type ValidationCode string

const (
	ValidationFileCount     ValidationCode = "file_count_out_of_range"
	ValidationInvalidPath   ValidationCode = "invalid_path"
	ValidationPathCollision ValidationCode = "path_collision"
	ValidationInvalidMode   ValidationCode = "invalid_file_mode"
	ValidationTooLarge      ValidationCode = "artifact_too_large"
	ValidationMissingSkill  ValidationCode = "missing_skill_manifest"
	ValidationUnsafeSymlink ValidationCode = "unsafe_symlink"
)

type ValidationError struct {
	Code ValidationCode
	Err  error
}

func (err *ValidationError) Error() string { return err.Err.Error() }
func (err *ValidationError) Unwrap() error { return err.Err }

func validationError(code ValidationCode, err error) error {
	return &ValidationError{Code: code, Err: err}
}

func ValidationFailure(err error) (ValidationCode, bool) {
	var validation *ValidationError
	if errors.As(err, &validation) {
		return validation.Code, true
	}
	var symlink *UnsafeSymlinkError
	if errors.As(err, &symlink) {
		return ValidationUnsafeSymlink, true
	}
	return "", false
}

func (entry Entry) IsSymlink() bool {
	return entry.Mode&os.ModeSymlink != 0
}

// VisitFunc observes each validated artifact entry while its Sum is
// calculated. File contents are owned by the call and must not be retained.
type VisitFunc func(Entry) error

func ValidRelativePath(value string) bool {
	_, err := PortablePathKey(value)
	return err == nil
}

// PortablePathKey validates one artifact-relative path and returns the key
// used to reject Unicode/case-insensitive filesystem collisions.
func PortablePathKey(value string) (string, error) {
	if value == "" || value == "." || !utf8.ValidString(value) || strings.HasPrefix(value, "/") ||
		strings.Contains(value, "\\") || path.Clean(value) != value ||
		value == ".." || strings.HasPrefix(value, "../") {
		return "", fmt.Errorf("invalid relative path %q", value)
	}
	if err := module.CheckFilePath(value); err != nil {
		return "", fmt.Errorf("path %q is not portable: %w", value, err)
	}
	for _, segment := range strings.Split(value, "/") {
		if strings.HasSuffix(segment, " ") {
			return "", fmt.Errorf("path %q has a Windows-ambiguous trailing space", value)
		}
	}
	return cases.Fold().String(norm.NFC.String(value)), nil
}

func ValidSum(value string) bool {
	if !strings.HasPrefix(value, "h1:") {
		return false
	}
	decoded, err := base64.StdEncoding.DecodeString(strings.TrimPrefix(value, "h1:"))
	return err == nil && len(decoded) == sha256.Size
}

// PackageEntriesSum validates a complete in-memory Package tree and returns
// the coordinate-bound Sum without requiring an archive representation.
func PackageEntriesSum(entries []Entry, packagePath, version string) (string, error) {
	validated, err := ValidateEntries(entries)
	if err != nil {
		return "", err
	}
	hash := sha256.New()
	prefix := packagePath + "@" + version + "/"
	for _, entry := range validated {
		if err := writeHash1Content(hash, prefix+entry.Path, entry.Contents); err != nil {
			return "", err
		}
	}
	return "h1:" + base64.StdEncoding.EncodeToString(hash.Sum(nil)), nil
}

// ValidateEntries returns a canonical path-ordered copy of one complete safe
// Package tree. Directory entries are omitted because Git Trees and local
// filesystems derive directories from file paths.
func ValidateEntries(entries []Entry) ([]Entry, error) {
	if len(entries) == 0 || len(entries) > MaxFiles {
		return nil, validationError(ValidationFileCount, fmt.Errorf("Package Artifact file count must be between 1 and %d", MaxFiles))
	}
	validated := make([]Entry, 0, len(entries))
	seen := make(map[string]string, len(entries))
	var total uint64
	hasSkill := false
	for _, entry := range entries {
		if entry.Directory {
			continue
		}
		collisionKey, err := PortablePathKey(entry.Path)
		if err != nil {
			return nil, validationError(ValidationInvalidPath, err)
		}
		if previous, exists := seen[collisionKey]; exists {
			return nil, validationError(ValidationPathCollision, fmt.Errorf("artifact paths %q and %q collide on portable filesystems", previous, entry.Path))
		}
		for parent := path.Dir(entry.Path); parent != "."; parent = path.Dir(parent) {
			parentKey, _ := PortablePathKey(parent)
			if previous, exists := seen[parentKey]; exists {
				return nil, validationError(ValidationPathCollision, fmt.Errorf("artifact file %q conflicts with parent file %q", entry.Path, previous))
			}
		}
		mode, err := canonicalMode(entry.Mode)
		if err != nil {
			return nil, validationError(ValidationInvalidMode, fmt.Errorf("Package Artifact file %q: %w", entry.Path, err))
		}
		size := uint64(len(entry.Contents))
		if size > MaxUncompressedBytes || total > MaxUncompressedBytes-size {
			return nil, validationError(ValidationTooLarge, fmt.Errorf("Package Artifact exceeds %d bytes", MaxUncompressedBytes))
		}
		total += size
		if path.Base(entry.Path) == "SKILL.md" && mode.IsRegular() {
			hasSkill = true
		}
		seen[collisionKey] = entry.Path
		validated = append(validated, Entry{Path: entry.Path, Contents: append([]byte(nil), entry.Contents...), Mode: mode, Size: int64(size)})
	}
	if !hasSkill {
		return nil, validationError(ValidationMissingSkill, fmt.Errorf("Package Artifact does not contain a SKILL.md member"))
	}
	sort.Slice(validated, func(i, j int) bool { return validated[i].Path < validated[j].Path })
	if err := ValidateSymlinks(validated); err != nil {
		return nil, err
	}
	return validated, nil
}

// BuildPackage serializes one complete validated Package file inventory
// beneath the canonical <packagePath>@<version>/ ZIP prefix.
func BuildPackage(packagePath, version string, files []Entry) ([]byte, error) {
	if packagePath == "" || version == "" {
		return nil, errors.New("Package Artifact identity and version are required")
	}
	if len(files) == 0 || len(files) > MaxFiles {
		return nil, fmt.Errorf("Package Artifact file count must be between 1 and %d", MaxFiles)
	}
	files = append([]Entry(nil), files...)
	sort.Slice(files, func(i, j int) bool { return files[i].Path < files[j].Path })
	var total uint64
	for _, file := range files {
		if file.Directory {
			return nil, fmt.Errorf("Package Artifact input %q is a directory; only regular files are accepted", file.Path)
		}
		size := uint64(len(file.Contents))
		if size > MaxUncompressedBytes || total > MaxUncompressedBytes-size {
			return nil, fmt.Errorf("Package Artifact exceeds %d bytes", MaxUncompressedBytes)
		}
		total += size
	}

	var buffer bytes.Buffer
	writer := zip.NewWriter(&buffer)
	prefix := packagePath + "@" + version + "/"
	for _, file := range files {
		header := &zip.FileHeader{Name: prefix + file.Path, Method: zip.Deflate}
		header.Modified = time.Date(1980, time.January, 1, 0, 0, 0, 0, time.UTC)
		mode, err := canonicalMode(file.Mode)
		if err != nil {
			_ = writer.Close()
			return nil, fmt.Errorf("Package Artifact file %q: %w", file.Path, err)
		}
		header.SetMode(mode)
		entry, err := writer.CreateHeader(header)
		if err != nil {
			_ = writer.Close()
			return nil, fmt.Errorf("create Package Artifact file %q: %w", file.Path, err)
		}
		if _, err := entry.Write(file.Contents); err != nil {
			_ = writer.Close()
			return nil, fmt.Errorf("write Package Artifact file %q: %w", file.Path, err)
		}
	}
	if err := writer.Close(); err != nil {
		return nil, fmt.Errorf("close Package Artifact ZIP: %w", err)
	}
	if buffer.Len() > MaxArchiveBytes {
		return nil, fmt.Errorf("Package Artifact archive exceeds %d bytes", MaxArchiveBytes)
	}
	archive := buffer.Bytes()
	if _, err := PackageSum(archive, packagePath, version); err != nil {
		return nil, err
	}
	return archive, nil
}

func canonicalMode(mode os.FileMode) (os.FileMode, error) {
	if mode == 0 {
		return 0o644, nil
	}
	if mode&os.ModeSymlink != 0 {
		if mode&os.ModeType != os.ModeSymlink {
			return 0, errors.New("mode is not a supported symlink")
		}
		return os.ModeSymlink | 0o777, nil
	}
	if mode&os.ModeType != 0 {
		return 0, errors.New("mode is not regular")
	}
	if mode.Perm()&0o111 != 0 {
		return 0o755, nil
	}
	return 0o644, nil
}

// PackageSum validates an immutable Package ZIP and returns the Go
// HashZip-compatible Sum over every full ZIP file name and its contents.
func PackageSum(data []byte, packagePath, version string) (string, error) {
	return WalkPackage(data, packagePath, version, nil)
}

// WalkPackage validates and reads one complete Package Artifact exactly
// once, visits entries in normalized path order, and returns its Sum.
func WalkPackage(data []byte, packagePath, version string, visit VisitFunc) (string, error) {
	return walkContent(data, packagePath, version, visit)
}

func walkContent(data []byte, artifactID, version string, visit VisitFunc) (string, error) {
	if len(data) == 0 || len(data) > MaxArchiveBytes {
		return "", fmt.Errorf("artifact archive size must be between 1 and %d bytes", MaxArchiveBytes)
	}
	reader, err := zip.NewReader(bytes.NewReader(data), int64(len(data)))
	if err != nil {
		return "", fmt.Errorf("open artifact archive: %w", err)
	}
	if len(reader.File) > MaxFiles {
		return "", fmt.Errorf("artifact contains more than %d files", MaxFiles)
	}
	entries := append([]*zip.File(nil), reader.File...)
	sort.Slice(entries, func(i, j int) bool { return entries[i].Name < entries[j].Name })
	type seenPath struct {
		path      string
		directory bool
	}
	prefix, hash, seen := artifactID+"@"+version+"/", sha256.New(), map[string]seenPath{}
	var total uint64
	hasSkill := false
	validated := make([]Entry, 0, len(entries))
	for _, entry := range entries {
		if !strings.HasPrefix(entry.Name, prefix) {
			return "", fmt.Errorf("artifact file %q is outside expected prefix %q", entry.Name, prefix)
		}
		relative := strings.TrimPrefix(entry.Name, prefix)
		if entry.FileInfo().IsDir() {
			relative = strings.TrimSuffix(relative, "/")
			if relative == "" {
				continue
			}
			collisionKey, pathErr := PortablePathKey(relative)
			if pathErr != nil {
				return "", pathErr
			}
			if previous, exists := seen[collisionKey]; exists {
				return "", fmt.Errorf("artifact paths %q and %q collide on portable filesystems", previous.path, relative)
			}
			seen[collisionKey] = seenPath{path: relative, directory: true}
			if visit != nil {
				if err := visit(Entry{Path: relative, Mode: entry.Mode(), Directory: true}); err != nil {
					return "", fmt.Errorf("visit artifact directory %q: %w", relative, err)
				}
			}
			continue
		}
		if entry.Method != zip.Store && entry.Method != zip.Deflate {
			return "", fmt.Errorf("artifact file %q uses unsupported compression method %d", relative, entry.Method)
		}
		if !entry.Mode().IsRegular() && entry.Mode()&os.ModeSymlink == 0 {
			return "", fmt.Errorf("artifact file %q is not a regular file", relative)
		}
		collisionKey, pathErr := PortablePathKey(relative)
		if pathErr != nil {
			return "", pathErr
		}
		if previous, exists := seen[collisionKey]; exists {
			return "", fmt.Errorf("artifact paths %q and %q collide on portable filesystems", previous.path, relative)
		}
		for parent := path.Dir(relative); parent != "."; parent = path.Dir(parent) {
			parentKey, _ := PortablePathKey(parent)
			if previous, exists := seen[parentKey]; exists && !previous.directory {
				return "", fmt.Errorf("artifact file %q conflicts with parent file %q", relative, previous.path)
			}
		}
		seen[collisionKey] = seenPath{path: relative}
		if path.Base(relative) == "SKILL.md" && entry.Mode().IsRegular() {
			hasSkill = true
		}
		if entry.UncompressedSize64 > MaxUncompressedBytes || total > MaxUncompressedBytes-entry.UncompressedSize64 {
			return "", fmt.Errorf("artifact expands beyond %d bytes", MaxUncompressedBytes)
		}
		total += entry.UncompressedSize64
		contents, err := ReadEntry(entry)
		if err != nil {
			return "", fmt.Errorf("read artifact file %q: %w", relative, err)
		}
		if err := writeHash1Content(hash, entry.Name, contents); err != nil {
			return "", err
		}
		validated = append(validated, Entry{Path: relative, Contents: contents, Mode: entry.Mode(), Size: int64(entry.UncompressedSize64)})
	}
	if !hasSkill {
		return "", fmt.Errorf("Package Artifact does not contain a SKILL.md member")
	}
	if err := ValidateSymlinks(validated); err != nil {
		return "", err
	}
	if visit != nil {
		for _, entry := range validated {
			if err := visit(entry); err != nil {
				return "", fmt.Errorf("visit artifact file %q: %w", entry.Path, err)
			}
		}
	}
	return "h1:" + base64.StdEncoding.EncodeToString(hash.Sum(nil)), nil
}

// ValidateSymlinks requires every symlink to use a relative target that
// resolves, possibly through other symlinks, to an entry inside the Package.
func ValidateSymlinks(entries []Entry) error {
	byPath := make(map[string]Entry, len(entries))
	directories := map[string]bool{".": true}
	for _, entry := range entries {
		byPath[entry.Path] = entry
		for parent := path.Dir(entry.Path); parent != "."; parent = path.Dir(parent) {
			directories[parent] = true
		}
	}
	for _, entry := range entries {
		if !entry.IsSymlink() {
			continue
		}
		current := entry.Path
		seen := map[string]bool{}
		for depth := 0; depth <= len(entries); depth++ {
			link, exists := byPath[current]
			if !exists || !link.IsSymlink() {
				if exists || directories[current] {
					break
				}
				return &UnsafeSymlinkError{Path: entry.Path, Reason: fmt.Sprintf("missing target %q", current)}
			}
			if seen[current] {
				return &UnsafeSymlinkError{Path: entry.Path, Reason: "cycle"}
			}
			seen[current] = true
			target := string(link.Contents)
			if target == "" || strings.HasPrefix(target, "/") || strings.Contains(target, "\\") {
				return &UnsafeSymlinkError{Path: entry.Path, Reason: fmt.Sprintf("invalid target %q", target)}
			}
			resolved := path.Clean(path.Join(path.Dir(current), target))
			if resolved == "." || resolved == ".." || strings.HasPrefix(resolved, "../") {
				return &UnsafeSymlinkError{Path: entry.Path, Reason: "target escapes the Package"}
			}
			if _, err := PortablePathKey(resolved); err != nil {
				return &UnsafeSymlinkError{Path: entry.Path, Reason: fmt.Sprintf("invalid resolved target: %v", err)}
			}
			current = resolved
		}
	}
	return nil
}

type UnsafeSymlinkError struct {
	Path   string
	Reason string
}

func (err *UnsafeSymlinkError) Error() string {
	return fmt.Sprintf("artifact symlink %q is unsafe: %s", err.Path, err.Reason)
}

// PackageDirectorySum calculates the coordinate-bound Package Sum for
// an extracted Package Artifact whose Skill members may be rooted or nested.
func PackageDirectorySum(root, packagePath, version string) (string, error) {
	if packagePath == "" || version == "" {
		return "", errors.New("Package Artifact identity and version are required")
	}
	return directorySum(root, packagePath+"@"+version+"/")
}

func directorySum(root, prefix string) (string, error) {
	root, err := filepath.Abs(root)
	if err != nil {
		return "", err
	}
	paths := make([]string, 0)
	inventory := make([]Entry, 0)
	seen := make(map[string]string)
	var total uint64
	hasSkill := false
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
		if !info.Mode().IsRegular() && info.Mode()&os.ModeSymlink == 0 {
			return fmt.Errorf("artifact contains unsupported file %q", current)
		}
		relative, err := filepath.Rel(root, current)
		if err != nil {
			return err
		}
		relative = filepath.ToSlash(relative)
		collisionKey, pathErr := PortablePathKey(relative)
		if pathErr != nil {
			return fmt.Errorf("artifact contains invalid path %q: %w", relative, pathErr)
		}
		if previous, exists := seen[collisionKey]; exists {
			return fmt.Errorf("artifact paths %q and %q collide on portable filesystems", previous, relative)
		}
		seen[collisionKey] = relative
		if path.Base(relative) == "SKILL.md" {
			hasSkill = true
		}
		size := uint64(info.Size())
		if info.Mode()&os.ModeSymlink != 0 {
			target, readErr := os.Readlink(current)
			if readErr != nil {
				return readErr
			}
			size = uint64(len(target))
		}
		if size > MaxUncompressedBytes || total > MaxUncompressedBytes-size {
			return fmt.Errorf("artifact exceeds %d bytes", MaxUncompressedBytes)
		}
		total += size
		paths = append(paths, relative)
		artifactEntry := Entry{Path: relative, Mode: info.Mode(), Size: int64(size)}
		if info.Mode()&os.ModeSymlink != 0 {
			target, readErr := os.Readlink(current)
			if readErr != nil {
				return readErr
			}
			artifactEntry.Contents = []byte(filepath.ToSlash(target))
		}
		inventory = append(inventory, artifactEntry)
		if len(paths) > MaxFiles {
			return fmt.Errorf("artifact contains more than %d files", MaxFiles)
		}
		return nil
	})
	if err != nil {
		return "", err
	}
	if err := ValidateSymlinks(inventory); err != nil {
		return "", err
	}
	sort.Strings(paths)
	hash := sha256.New()
	for _, relative := range paths {
		current := filepath.Join(root, filepath.FromSlash(relative))
		info, err := os.Lstat(current)
		if err != nil {
			return "", err
		}
		var contents []byte
		if info.Mode()&os.ModeSymlink != 0 {
			target, readErr := os.Readlink(current)
			if readErr != nil {
				return "", readErr
			}
			contents = []byte(filepath.ToSlash(target))
		} else {
			contents, err = os.ReadFile(current)
		}
		if err != nil {
			return "", err
		}
		if len(contents) > MaxUncompressedBytes {
			return "", fmt.Errorf("file exceeds %d bytes", MaxUncompressedBytes)
		}
		if err := writeHash1Content(hash, prefix+relative, contents); err != nil {
			return "", err
		}
	}
	if !hasSkill {
		return "", fmt.Errorf("Package Artifact does not contain a SKILL.md member")
	}
	return "h1:" + base64.StdEncoding.EncodeToString(hash.Sum(nil)), nil
}

func ReadEntry(entry *zip.File) ([]byte, error) {
	reader, err := entry.Open()
	if err != nil {
		return nil, err
	}
	defer reader.Close()
	return readBounded(reader, entry.UncompressedSize64)
}

func readBounded(reader io.Reader, declaredSize uint64) ([]byte, error) {
	contents, err := io.ReadAll(io.LimitReader(reader, MaxUncompressedBytes+1))
	if err != nil {
		return nil, err
	}
	if len(contents) > MaxUncompressedBytes || uint64(len(contents)) != declaredSize {
		return nil, fmt.Errorf("uncompressed size does not match archive metadata")
	}
	return contents, nil
}
