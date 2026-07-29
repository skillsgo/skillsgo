/*
 * [INPUT]: Depends on immutable Git revisions, canonical Package coordinates, the shared Package Artifact tree contract, and Go tar primitives.
 * [OUTPUT]: Adapts a complete Git-tracked tree into canonical safe Artifact entries and a coordinate-bound Sum without constructing a ZIP.
 * [POS]: Serves as the safe tree boundary between Git source resolution and immutable Package publication.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skill

import (
	"archive/tar"
	"bytes"
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strings"

	"github.com/skillsgo/skillsgo/hub/pkg/log"
	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
)

func createRepositoryArtifact(ctx context.Context, packagePath, version, repoDir, revision string) ([]protocolartifact.Entry, string, error) {
	args := []string{"-c", "core.autocrlf=input", "-c", "core.eol=lf", "archive", "--format=tar", revision}
	raw := &boundedArchiveBuffer{limit: protocolartifact.MaxUncompressedBytes + protocolartifact.MaxFiles*1024}
	stderr := &bytes.Buffer{}
	command := exec.CommandContext(ctx, "git", args...)
	command.Dir = repoDir
	command.Env = append(os.Environ(), "PWD="+repoDir)
	command.Stdout = raw
	command.Stderr = stderr
	if err := command.Run(); err != nil {
		if raw.exceeded {
			return nil, "", fmt.Errorf("Git Repository tree stream exceeds %d bytes", raw.limit)
		}
		return nil, "", fmt.Errorf("create Git Repository tree stream: %w: %s", err, strings.TrimSpace(stderr.String()))
	}
	source := tar.NewReader(bytes.NewReader(raw.Bytes()))
	files := make([]protocolartifact.Entry, 0)
	remainingBytes := int64(protocolartifact.MaxUncompressedBytes)
	for {
		file, err := source.Next()
		if errors.Is(err, io.EOF) {
			break
		}
		if err != nil {
			return nil, "", fmt.Errorf("read Git Repository tree stream: %w", err)
		}
		if file.FileInfo().IsDir() {
			continue
		}
		artifactPath := strings.TrimSuffix(file.Name, "/")
		if isExcludedArtifactPath(artifactPath) {
			continue
		}
		mode := file.FileInfo().Mode()
		if !mode.IsRegular() && mode&os.ModeSymlink == 0 {
			return nil, "", fmt.Errorf("Git Repository contains non-regular file %q", file.Name)
		}
		var contents []byte
		if mode&os.ModeSymlink != 0 {
			contents = []byte(file.Linkname)
		} else {
			if file.Size < 0 || file.Size > remainingBytes {
				return nil, "", fmt.Errorf("Git Repository files exceed %d uncompressed bytes", protocolartifact.MaxUncompressedBytes)
			}
			contents, err = io.ReadAll(io.LimitReader(source, remainingBytes+1))
			if err != nil || int64(len(contents)) > remainingBytes {
				return nil, "", fmt.Errorf("read Git Repository file %q: %w", file.Name, err)
			}
		}
		remainingBytes -= int64(len(contents))
		files = append(files, protocolartifact.Entry{Path: artifactPath, Contents: contents, Mode: mode, Size: int64(len(contents))})
	}
	for {
		err := protocolartifact.ValidateSymlinks(files)
		if err == nil {
			break
		}
		var unsafe *protocolartifact.UnsafeSymlinkError
		if !errors.As(err, &unsafe) {
			return nil, "", err
		}
		log.EntryFromContext(ctx).WithFields(map[string]any{
			"package_path": packagePath,
			"path":         unsafe.Path,
			"reason":       unsafe.Reason,
			"revision":     revision,
		}).Warnf("unsafe Package symlink omitted from artifact")
		filtered := files[:0]
		for _, file := range files {
			if file.Path != unsafe.Path {
				filtered = append(filtered, file)
			}
		}
		files = filtered
	}
	validated, err := protocolartifact.ValidateEntries(files)
	if err != nil {
		return nil, "", fmt.Errorf("build Repository Artifact tree: %w", err)
	}
	sum, err := protocolartifact.PackageEntriesSum(validated, packagePath, version)
	if err != nil {
		return nil, "", fmt.Errorf("verify Repository Artifact tree: %w", err)
	}
	return validated, sum, nil
}

func isExcludedArtifactPath(path string) bool {
	first, _, _ := strings.Cut(path, "/")
	switch first {
	case ".agents", ".claude", ".codex":
		return true
	default:
		return false
	}
}

type boundedArchiveBuffer struct {
	bytes.Buffer
	exceeded bool
	limit    int
}

func (buffer *boundedArchiveBuffer) Write(data []byte) (int, error) {
	if buffer.Len()+len(data) > buffer.limit {
		buffer.exceeded = true
		return 0, fmt.Errorf("Git Repository tree stream exceeds %d bytes", buffer.limit)
	}
	return buffer.Buffer.Write(data)
}
