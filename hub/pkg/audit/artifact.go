/*
 * [INPUT]: Depends on immutable ZIP bytes, canonical Skill IDs, and resolved artifact versions.
 * [OUTPUT]: Provides bounded duplicate-safe artifact inspection with compression-independent content identity, real instructions, file metadata/content, executable signals, and deterministic risk evidence.
 * [POS]: Serves as the artifact-analysis boundary between Hub storage bytes and public audit metadata.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package audit

import (
	"archive/zip"
	"bytes"
	"crypto/sha256"
	"encoding/binary"
	"fmt"
	"io"
	"path"
	"sort"
	"strings"
	"unicode/utf8"
)

const (
	ScannerVersion      = "file-signals/v1"
	MaxArchiveBytes     = 64 << 20
	maxFileContentBytes = 256 << 10
	maxInstructions     = 1 << 20
	maxTotalTextBytes   = 2 << 20
	maxUncompressed     = 64 << 20
	maxFiles            = 5000
)

type File struct {
	Path       string `json:"path"`
	Size       int64  `json:"size"`
	Kind       string `json:"kind"`
	Executable bool   `json:"executable"`
	Binary     bool   `json:"binary"`
	Content    string `json:"content,omitempty"`
	Truncated  bool   `json:"truncated"`
}

type Evidence struct {
	Code string `json:"code"`
	Path string `json:"path"`
}

type RiskAssessment struct {
	Level          string     `json:"level"`
	ScannerVersion string     `json:"scannerVersion"`
	ArtifactDigest string     `json:"artifactDigest"`
	Evidence       []Evidence `json:"evidence"`
}

type Result struct {
	Instructions         string         `json:"instructions"`
	ContentDigest        string         `json:"contentDigest"`
	Files                []File         `json:"files"`
	HasExecutableContent bool           `json:"hasExecutableContent"`
	ExecutableFiles      []string       `json:"executableFiles"`
	Risk                 RiskAssessment `json:"riskAssessment"`
}

var scriptExtensions = map[string]bool{
	".sh": true, ".bash": true, ".zsh": true, ".fish": true,
	".ps1": true, ".bat": true, ".cmd": true,
	".js": true, ".mjs": true, ".cjs": true, ".ts": true,
	".py": true, ".rb": true, ".pl": true, ".php": true,
}

var binaryExtensions = map[string]bool{
	".exe": true, ".dll": true, ".dylib": true, ".so": true,
	".bin": true, ".app": true, ".jar": true,
}

func AnalyzeArtifact(data []byte, skillID, version string) (*Result, error) {
	if len(data) == 0 || len(data) > MaxArchiveBytes {
		return nil, fmt.Errorf("artifact archive size must be between 1 and %d bytes", MaxArchiveBytes)
	}
	reader, err := zip.NewReader(bytes.NewReader(data), int64(len(data)))
	if err != nil {
		return nil, fmt.Errorf("open artifact archive: %w", err)
	}
	if len(reader.File) > maxFiles {
		return nil, fmt.Errorf("artifact contains more than %d files", maxFiles)
	}
	prefix := skillID + "@" + version + "/"
	entries := append([]*zip.File(nil), reader.File...)
	sort.Slice(entries, func(i, j int) bool { return entries[i].Name < entries[j].Name })
	var uncompressed uint64
	for _, entry := range entries {
		if entry.FileInfo().IsDir() {
			continue
		}
		if entry.UncompressedSize64 > maxUncompressed || uncompressed > maxUncompressed-entry.UncompressedSize64 {
			return nil, fmt.Errorf("artifact expands beyond %d bytes", maxUncompressed)
		}
		uncompressed += entry.UncompressedSize64
	}

	result := &Result{
		Files:           make([]File, 0, len(entries)),
		ExecutableFiles: make([]string, 0),
		Risk: RiskAssessment{
			Level: "unknown", ScannerVersion: ScannerVersion, Evidence: make([]Evidence, 0),
		},
	}
	textBudget := maxTotalTextBytes
	contentHash := sha256.New()
	seenPaths := make(map[string]bool, len(entries))
	for _, entry := range entries {
		if entry.FileInfo().IsDir() {
			continue
		}
		if !strings.HasPrefix(entry.Name, prefix) {
			return nil, fmt.Errorf("artifact file %q is outside expected prefix %q", entry.Name, prefix)
		}
		relative := strings.TrimPrefix(entry.Name, prefix)
		if !validRelativePath(relative) || seenPaths[relative] {
			return nil, fmt.Errorf("artifact file has invalid or duplicate path %q", relative)
		}
		seenPaths[relative] = true
		contents, err := readEntry(entry)
		if err != nil {
			return nil, fmt.Errorf("read artifact file %q: %w", relative, err)
		}
		if err := writeDigestEntry(contentHash, relative, contents); err != nil {
			return nil, fmt.Errorf("hash artifact file %q: %w", relative, err)
		}
		readLimit := maxFileContentBytes
		if relative == "SKILL.md" {
			readLimit = maxInstructions
		}
		truncated := len(contents) > readLimit
		visibleContents := contents
		if truncated {
			visibleContents = contents[:readLimit]
		}
		binaryByExtension := binaryExtensions[strings.ToLower(path.Ext(relative))]
		binary := binaryByExtension || !utf8.Valid(visibleContents) || bytes.IndexByte(visibleContents, 0) >= 0
		executable := isExecutable(entry, relative)
		kind := "text"
		if relative == "SKILL.md" {
			kind = "instructions"
		} else if binary {
			kind = "binary"
		} else if executable {
			kind = "script"
		}
		content := ""
		if !binary && textBudget > 0 {
			allowed := len(visibleContents)
			if allowed > textBudget {
				allowed = textBudget
				truncated = true
			}
			content = string(visibleContents[:allowed])
			textBudget -= allowed
		}
		file := File{
			Path: relative, Size: int64(entry.UncompressedSize64), Kind: kind,
			Executable: executable, Binary: binary, Content: content, Truncated: truncated,
		}
		result.Files = append(result.Files, file)
		if relative == "SKILL.md" {
			if binary || truncated || content == "" {
				return nil, fmt.Errorf("SKILL.md must be complete UTF-8 text")
			}
			result.Instructions = content
		}
		if executable {
			result.HasExecutableContent = true
			result.ExecutableFiles = append(result.ExecutableFiles, relative)
			code := "script_file"
			if binary {
				code = "binary_executable"
				result.Risk.Level = "high"
			} else if result.Risk.Level == "unknown" {
				result.Risk.Level = "medium"
			}
			result.Risk.Evidence = append(result.Risk.Evidence, Evidence{Code: code, Path: relative})
		}
	}
	if result.Instructions == "" {
		return nil, fmt.Errorf("artifact does not contain SKILL.md")
	}
	result.ContentDigest = fmt.Sprintf("sha256:%x", contentHash.Sum(nil))
	result.Risk.ArtifactDigest = result.ContentDigest
	return result, nil
}

func readEntry(entry *zip.File) ([]byte, error) {
	reader, err := entry.Open()
	if err != nil {
		return nil, err
	}
	defer reader.Close()
	contents, err := io.ReadAll(io.LimitReader(reader, maxUncompressed+1))
	if err != nil {
		return nil, err
	}
	if len(contents) > maxUncompressed || uint64(len(contents)) != entry.UncompressedSize64 {
		return nil, fmt.Errorf("uncompressed size does not match archive metadata")
	}
	return contents, nil
}

func writeDigestEntry(destination io.Writer, relative string, contents []byte) error {
	if err := binary.Write(destination, binary.BigEndian, uint64(len(relative))); err != nil {
		return err
	}
	if _, err := io.WriteString(destination, relative); err != nil {
		return err
	}
	if err := binary.Write(destination, binary.BigEndian, uint64(len(contents))); err != nil {
		return err
	}
	_, err := destination.Write(contents)
	return err
}

func validRelativePath(value string) bool {
	return value != "" && value != "." && !strings.HasPrefix(value, "/") &&
		!strings.Contains(value, "\\") && path.Clean(value) == value &&
		value != ".." && !strings.HasPrefix(value, "../")
}

func isExecutable(entry *zip.File, relative string) bool {
	extension := strings.ToLower(path.Ext(relative))
	return entry.Mode()&0o111 != 0 || scriptExtensions[extension] || binaryExtensions[extension] ||
		strings.HasPrefix(strings.ToLower(relative), "scripts/") ||
		strings.Contains(strings.ToLower(relative), "/scripts/")
}
