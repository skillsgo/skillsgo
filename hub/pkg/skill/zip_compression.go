/*
 * [INPUT]: Depends on immutable Git revisions, canonical Repository coordinates, the shared Repository Artifact contract, and Go ZIP primitives.
 * [OUTPUT]: Adapts a full Git-tracked regular-file tree into one deterministic Repository Artifact with bounded source reads.
 * [POS]: Serves as the safe archive boundary between Git source resolution and immutable Repository publication.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skill

import (
	"archive/zip"
	"bytes"
	"context"
	"crypto/md5" //nolint:gosec -- storage envelope compatibility; h1 is the authenticated content identity.
	"fmt"
	"io"
	"os"
	"os/exec"
	"strings"

	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
)

func createRepositoryArtifact(ctx context.Context, repositoryID, version, repoDir, revision string) ([]byte, []byte, string, error) {
	args := []string{"-c", "core.autocrlf=input", "-c", "core.eol=lf", "archive", "--format=zip", revision}
	raw := &boundedArchiveBuffer{}
	stderr := &bytes.Buffer{}
	command := exec.CommandContext(ctx, "git", args...)
	command.Dir = repoDir
	command.Env = append(os.Environ(), "PWD="+repoDir)
	command.Stdout = raw
	command.Stderr = stderr
	if err := command.Run(); err != nil {
		if raw.exceeded {
			return nil, nil, "", fmt.Errorf("Git Repository archive exceeds %d bytes", protocolartifact.MaxArchiveBytes)
		}
		return nil, nil, "", fmt.Errorf("create Git Repository archive: %w: %s", err, strings.TrimSpace(stderr.String()))
	}
	source, err := zip.NewReader(bytes.NewReader(raw.Bytes()), int64(raw.Len()))
	if err != nil {
		return nil, nil, "", fmt.Errorf("open Git Repository archive: %w", err)
	}
	files := make([]protocolartifact.Entry, 0, len(source.File))
	remainingBytes := int64(protocolartifact.MaxUncompressedBytes)
	for _, file := range source.File {
		if file.FileInfo().IsDir() {
			continue
		}
		path := strings.TrimSuffix(file.Name, "/")
		if isExcludedArtifactPath(path) {
			continue
		}
		if !file.Mode().IsRegular() {
			return nil, nil, "", fmt.Errorf("Git Repository contains non-regular file %q", file.Name)
		}
		contents, err := readArchiveFile(file, remainingBytes)
		if err != nil {
			return nil, nil, "", err
		}
		remainingBytes -= int64(len(contents))
		files = append(files, protocolartifact.Entry{Path: path, Contents: contents, Mode: file.Mode(), Size: int64(len(contents))})
	}
	archive, err := protocolartifact.BuildRepository(repositoryID, version, files)
	if err != nil {
		return nil, nil, "", fmt.Errorf("build Repository Artifact: %w", err)
	}
	sum, err := protocolartifact.RepositorySum(archive, repositoryID, version)
	if err != nil {
		return nil, nil, "", fmt.Errorf("verify Repository Artifact: %w", err)
	}
	digest := md5.Sum(archive) //nolint:gosec
	return archive, digest[:], sum, nil
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

func readArchiveFile(file *zip.File, remainingBytes int64) ([]byte, error) {
	if remainingBytes < 0 || file.UncompressedSize64 > uint64(remainingBytes) {
		return nil, fmt.Errorf("Git Repository files exceed %d uncompressed bytes", protocolartifact.MaxUncompressedBytes)
	}
	reader, err := file.Open()
	if err != nil {
		return nil, err
	}
	contents, readErr := io.ReadAll(io.LimitReader(reader, remainingBytes+1))
	closeErr := reader.Close()
	if readErr != nil {
		return nil, readErr
	}
	if closeErr != nil {
		return nil, closeErr
	}
	if int64(len(contents)) > remainingBytes {
		return nil, fmt.Errorf("Git Repository files exceed %d uncompressed bytes", protocolartifact.MaxUncompressedBytes)
	}
	return contents, nil
}

type boundedArchiveBuffer struct {
	bytes.Buffer
	exceeded bool
}

func (buffer *boundedArchiveBuffer) Write(data []byte) (int, error) {
	if buffer.Len()+len(data) > protocolartifact.MaxArchiveBytes {
		buffer.exceeded = true
		return 0, fmt.Errorf("Git Repository archive exceeds %d bytes", protocolartifact.MaxArchiveBytes)
	}
	return buffer.Buffer.Write(data)
}
