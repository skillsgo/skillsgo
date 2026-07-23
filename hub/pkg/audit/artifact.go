/*
 * [INPUT]: Depends on immutable Repository ZIP bytes, canonical Repository IDs, member paths, and resolved versions.
 * [OUTPUT]: Provides bounded duplicate-safe Repository-member inspection with Repository content identity, member instructions, file metadata/content, executable signals, and deterministic risk evidence.
 * [POS]: Serves as the artifact-analysis boundary between Hub storage bytes and public audit metadata.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package audit

import (
	"bytes"
	"fmt"
	"os"
	"path"
	"strings"
	"unicode/utf8"

	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
)

const (
	ScannerVersion      = "file-signals/v1"
	MaxArchiveBytes     = protocolartifact.MaxArchiveBytes
	maxFileContentBytes = 256 << 10
	maxInstructions     = 1 << 20
	maxTotalTextBytes   = 2 << 20
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
	ArtifactSum    string     `json:"artifactSum"`
	Evidence       []Evidence `json:"evidence"`
}

type Result struct {
	Instructions         string         `json:"instructions"`
	Sum                  string         `json:"sum"`
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

// AnalyzeRepositoryMember validates the complete Repository Artifact while
// projecting one immutable Skill member for detail and enrichment reads.
func AnalyzeRepositoryMember(data []byte, repositoryID, version, relativePath string) (*Result, error) {
	memberPrefix := ""
	if relativePath != "." {
		memberPrefix = strings.TrimSuffix(relativePath, "/") + "/"
	}
	return analyze(data, func(visit protocolartifact.VisitFunc) (string, error) {
		return protocolartifact.WalkRepository(data, repositoryID, version, func(entry protocolartifact.Entry) error {
			if entry.Directory || !strings.HasPrefix(entry.Path, memberPrefix) {
				return nil
			}
			entry.Path = strings.TrimPrefix(entry.Path, memberPrefix)
			return visit(entry)
		})
	}, relativePath)
}

func analyze(_ []byte, walk func(protocolartifact.VisitFunc) (string, error), memberPath string) (*Result, error) {
	result := &Result{
		Files:           make([]File, 0),
		ExecutableFiles: make([]string, 0),
		Risk: RiskAssessment{
			Level: "unknown", ScannerVersion: ScannerVersion, Evidence: make([]Evidence, 0),
		},
	}
	textBudget := maxTotalTextBytes
	digest, err := walk(func(entry protocolartifact.Entry) error {
		if entry.Directory {
			return nil
		}
		relative, contents := entry.Path, entry.Contents
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
		executable := isExecutable(entry.Mode, relative)
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
			Path: relative, Size: entry.Size, Kind: kind,
			Executable: executable, Binary: binary, Content: content, Truncated: truncated,
		}
		result.Files = append(result.Files, file)
		if relative == "SKILL.md" {
			if binary || truncated || content == "" {
				return fmt.Errorf("SKILL.md must be complete UTF-8 text")
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
		return nil
	})
	if err != nil {
		return nil, err
	}
	if result.Instructions == "" {
		return nil, fmt.Errorf("artifact does not contain SKILL.md for member %q", memberPath)
	}
	result.Sum = digest
	result.Risk.ArtifactSum = result.Sum
	return result, nil
}

func isExecutable(mode os.FileMode, relative string) bool {
	extension := strings.ToLower(path.Ext(relative))
	return mode&0o111 != 0 || scriptExtensions[extension] || binaryExtensions[extension] ||
		strings.HasPrefix(strings.ToLower(relative), "scripts/") ||
		strings.Contains(strings.ToLower(relative), "/scripts/")
}
