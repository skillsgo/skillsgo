/*
 * [INPUT]: Depends on immutable Git revisions, accepted Package pathspecs containing Skill subtrees, an optional authored root README, applicable plugin manifests, canonical Package coordinates, deterministic plugin-manifest completion, the shared Package Artifact tree contract, and Go tar primitives.
 * [OUTPUT]: Adapts the minimal selected Git-tracked Package tree into canonical safe Artifact entries that preserve the authored root README and complete cross-Agent root plugin manifests, precise source failure codes, and a coordinate-bound Sum without exposing tar/PAX transport metadata or constructing a ZIP.
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
	"path"
	"strings"

	"github.com/skillsgo/skillsgo/hub/pkg/log"
	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
)

func createRepositoryArtifact(ctx context.Context, packagePath, version, repoDir, revision string, selection packageArtifactSelection) ([]protocolartifact.Entry, string, error) {
	args := []string{"-c", "core.autocrlf=input", "-c", "core.eol=lf", "archive", "--format=tar", revision, "--"}
	args = append(args, selection.paths...)
	raw := &boundedArchiveBuffer{limit: protocolartifact.MaxUncompressedBytes + protocolartifact.MaxFiles*1024}
	stderr := &bytes.Buffer{}
	command := exec.CommandContext(ctx, "git", args...)
	command.Dir = repoDir
	command.Env = append(os.Environ(), "PWD="+repoDir, "GIT_LITERAL_PATHSPECS=1")
	command.Stdout = raw
	command.Stderr = stderr
	if err := command.Run(); err != nil {
		if ctx.Err() != nil {
			return nil, "", withSourceFailure(SourceFailureArchiveCommand, fmt.Errorf("create Git Repository tree stream: %w", ctx.Err()))
		}
		if raw.exceeded {
			return nil, "", withSourceFailure(SourceFailureArchiveTooLarge, fmt.Errorf("Git Repository tree stream exceeds %d bytes", raw.limit))
		}
		return nil, "", withSourceFailure(SourceFailureArchiveCommand, fmt.Errorf("create Git Repository tree stream: %w: %s", err, strings.TrimSpace(stderr.String())))
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
			return nil, "", withSourceFailure(SourceFailureArchiveRead, fmt.Errorf("read Git Repository tree stream: %w", err))
		}
		switch file.Typeflag {
		case tar.TypeDir, tar.TypeXHeader, tar.TypeXGlobalHeader:
			continue
		case tar.TypeReg, tar.TypeRegA, tar.TypeSymlink:
		default:
			return nil, "", withSourceFailure(SourceFailureUnsupportedEntry, fmt.Errorf("Git Repository contains unsupported tar entry %q with type %d", file.Name, file.Typeflag))
		}
		artifactPath := strings.TrimSuffix(file.Name, "/")
		mode := file.FileInfo().Mode()
		var contents []byte
		if mode&os.ModeSymlink != 0 {
			contents = []byte(file.Linkname)
		} else {
			if file.Size < 0 || file.Size > remainingBytes {
				return nil, "", withSourceFailure(SourceFailureArtifactTooLarge, fmt.Errorf("Git Repository files exceed %d uncompressed bytes", protocolartifact.MaxUncompressedBytes))
			}
			contents, err = io.ReadAll(io.LimitReader(source, remainingBytes+1))
			if err != nil {
				return nil, "", withSourceFailure(SourceFailureArchiveRead, fmt.Errorf("read Git Repository file %q: %w", file.Name, err))
			}
			if int64(len(contents)) > remainingBytes {
				return nil, "", withSourceFailure(SourceFailureArtifactTooLarge, fmt.Errorf("Git Repository files exceed %d uncompressed bytes", protocolartifact.MaxUncompressedBytes))
			}
		}
		remainingBytes -= int64(len(contents))
		files = append(files, protocolartifact.Entry{Path: artifactPath, Contents: contents, Mode: mode, Size: int64(len(contents))})
	}
	files = omitCrossSkillSymlinks(ctx, packagePath, revision, files, selection.skillDirectories)
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
	files, completionErr := completeRootPluginManifests(files, packagePath, selection.skillDirectories)
	if completionErr != nil {
		return nil, "", withSourceFailure(SourceFailureArtifactBuild, fmt.Errorf("complete Package plugin manifests: %w", completionErr))
	}
	validated, err := protocolartifact.ValidateEntries(files)
	if err != nil {
		return nil, "", withSourceFailure(sourceArtifactValidationCode(err), fmt.Errorf("build Repository Artifact tree: %w", err))
	}
	sum, err := protocolartifact.PackageEntriesSum(validated, packagePath, version)
	if err != nil {
		return nil, "", withSourceFailure(SourceFailureArtifactSum, fmt.Errorf("verify Repository Artifact tree: %w", err))
	}
	return validated, sum, nil
}

func omitCrossSkillSymlinks(ctx context.Context, packagePath, revision string, files []protocolartifact.Entry, skillDirectories []string) []protocolartifact.Entry {
	filtered := files[:0]
	for _, file := range files {
		if !file.IsSymlink() {
			filtered = append(filtered, file)
			continue
		}
		owner := ""
		for _, directory := range skillDirectories {
			if directory == "." || file.Path == directory || strings.HasPrefix(file.Path, directory+"/") {
				if len(directory) > len(owner) {
					owner = directory
				}
			}
		}
		target := path.Clean(path.Join(path.Dir(file.Path), string(file.Contents)))
		insideOwner := owner == "." || target == owner || strings.HasPrefix(target, owner+"/")
		if owner != "" && insideOwner {
			filtered = append(filtered, file)
			continue
		}
		log.EntryFromContext(ctx).WithFields(map[string]any{
			"package_path": packagePath,
			"path":         file.Path,
			"reason":       "symlink escapes its owning Skill directory",
			"revision":     revision,
		}).Warnf("cross-Skill symlink omitted from artifact")
	}
	return filtered
}

func sourceArtifactValidationCode(err error) SourceFailureCode {
	code, ok := protocolartifact.ValidationFailure(err)
	if !ok {
		return SourceFailureArtifactBuild
	}
	switch code {
	case protocolartifact.ValidationFileCount:
		return SourceFailureArtifactFileCount
	case protocolartifact.ValidationInvalidPath:
		return SourceFailureArtifactPath
	case protocolartifact.ValidationPathCollision:
		return SourceFailureArtifactCollision
	case protocolartifact.ValidationInvalidMode:
		return SourceFailureArtifactMode
	case protocolartifact.ValidationTooLarge:
		return SourceFailureArtifactTooLarge
	case protocolartifact.ValidationMissingSkill:
		return SourceFailureNoSkills
	default:
		return SourceFailureArtifactBuild
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
