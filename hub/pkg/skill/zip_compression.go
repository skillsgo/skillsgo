/*
 * [INPUT]: Depends on an immutable Git revision, a canonical Skill ID/version prefix, the shared artifact contract, Repository-root LICENSE inheritance, afero storage, and Go ZIP primitives.
 * [OUTPUT]: Provides bounded, deterministic SkillsGo artifact assembly with portable paths, canonical permission classes, nested root LICENSE inheritance, and best-compression ZIP rewriting.
 * [POS]: Serves as the safe archive boundary between Git source resolution and immutable Hub artifact publication.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skill

import (
	"archive/zip"
	"bytes"
	"compress/flate"
	"context"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"strings"
	"time"
	"unicode/utf8"

	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
	"github.com/spf13/afero"
)

const (
	maxSkillArchiveBytes        = protocolartifact.MaxArchiveBytes
	maxSkillArchiveFiles        = protocolartifact.MaxFiles
	maxSkillArchiveUncompressed = protocolartifact.MaxUncompressedBytes
)

type boundedArchiveBuffer struct {
	bytes.Buffer
	exceeded bool
}

func (buffer *boundedArchiveBuffer) Write(data []byte) (int, error) {
	if buffer.Len()+len(data) > maxSkillArchiveBytes {
		buffer.exceeded = true
		return 0, fmt.Errorf("Git Skill archive exceeds %d bytes", maxSkillArchiveBytes)
	}
	return buffer.Buffer.Write(data)
}

func createSkillZipFromVCS(
	ctx context.Context,
	fs afero.Fs,
	zipPath, skillID, version, repoDir, revision, subdir string,
) error {
	scope := strings.Trim(filepath.ToSlash(subdir), "/")
	if scope == "." {
		scope = ""
	}
	if scope != "" && !validSkillArchivePath(scope) {
		return fmt.Errorf("invalid Skill archive subdirectory %q", subdir)
	}

	args := []string{
		"-c", "core.autocrlf=input",
		"-c", "core.eol=lf",
		"archive", "--format=zip", revision,
	}
	if scope != "" {
		args = append(args, "--", scope)
	}
	raw := &boundedArchiveBuffer{}
	stderr := &bytes.Buffer{}
	command := exec.CommandContext(ctx, "git", args...)
	command.Dir = repoDir
	command.Env = append(os.Environ(), "PWD="+repoDir)
	command.Stdout = raw
	command.Stderr = stderr
	if err := command.Run(); err != nil {
		if raw.exceeded {
			return fmt.Errorf("Git Skill archive exceeds %d bytes", maxSkillArchiveBytes)
		}
		return fmt.Errorf("create Git Skill archive: %w: %s", err, strings.TrimSpace(stderr.String()))
	}

	source, err := zip.NewReader(bytes.NewReader(raw.Bytes()), int64(raw.Len()))
	if err != nil {
		return fmt.Errorf("open Git Skill archive: %w", err)
	}
	output, err := fs.Create(zipPath)
	if err != nil {
		return err
	}
	keepOutput := false
	defer func() {
		_ = output.Close()
		if !keepOutput {
			_ = fs.Remove(zipPath)
		}
	}()

	destination := zip.NewWriter(output)
	prefix := skillID + "@" + version + "/"
	seen := make(map[string]string, len(source.File))
	fileCount := 0
	var uncompressed uint64
	hasManifest := false
	for _, file := range source.File {
		relative, inside := skillArchiveRelativePath(file.Name, scope)
		if !inside {
			if !file.FileInfo().IsDir() {
				_ = destination.Close()
				return fmt.Errorf("Git archive file %q is outside Skill directory %q", file.Name, scope)
			}
			continue
		}
		if relative == "" || file.FileInfo().IsDir() {
			continue
		}
		if !file.Mode().IsRegular() {
			continue
		}
		if !validSkillArchivePath(relative) {
			_ = destination.Close()
			return fmt.Errorf("Git archive contains unsafe Skill path %q", relative)
		}
		collisionKey, err := protocolartifact.PortablePathKey(relative)
		if err != nil {
			_ = destination.Close()
			return fmt.Errorf("Git archive contains unsafe Skill path %q: %w", relative, err)
		}
		if previous, exists := seen[collisionKey]; exists {
			_ = destination.Close()
			return fmt.Errorf("Git archive contains portable path collision %q and %q", previous, relative)
		}
		seen[collisionKey] = relative
		fileCount++
		if fileCount > maxSkillArchiveFiles {
			_ = destination.Close()
			return fmt.Errorf("Git Skill archive contains more than %d files", maxSkillArchiveFiles)
		}
		if file.UncompressedSize64 > maxSkillArchiveUncompressed ||
			uncompressed > maxSkillArchiveUncompressed-file.UncompressedSize64 {
			_ = destination.Close()
			return fmt.Errorf("Git Skill archive expands beyond %d bytes", maxSkillArchiveUncompressed)
		}
		uncompressed += file.UncompressedSize64

		header := file.FileHeader
		header.Name = prefix + relative
		header.Method = zip.Deflate
		header.Comment = ""
		header.Extra = nil
		if file.Mode()&0o111 != 0 {
			header.SetMode(0o755)
		} else {
			header.SetMode(0o644)
		}
		writer, err := destination.CreateHeader(&header)
		if err != nil {
			_ = destination.Close()
			return err
		}
		reader, err := file.Open()
		if err != nil {
			_ = destination.Close()
			return err
		}
		_, copyErr := io.Copy(writer, reader)
		closeErr := reader.Close()
		if copyErr != nil {
			_ = destination.Close()
			return copyErr
		}
		if closeErr != nil {
			_ = destination.Close()
			return closeErr
		}
		hasManifest = hasManifest || relative == "SKILL.md"
	}
	licenseKey, _ := protocolartifact.PortablePathKey("LICENSE")
	if scope != "" {
		if _, exists := seen[licenseKey]; !exists {
			if license, licenseErr := gitFileContent(ctx, repoDir, revision, "LICENSE"); licenseErr == nil {
				fileCount++
				if fileCount > maxSkillArchiveFiles || uint64(len(license)) > maxSkillArchiveUncompressed || uncompressed > maxSkillArchiveUncompressed-uint64(len(license)) {
					_ = destination.Close()
					return fmt.Errorf("Git Skill archive exceeds shared artifact limits while inheriting Repository LICENSE")
				}
				uncompressed += uint64(len(license))
				header := &zip.FileHeader{Name: prefix + "LICENSE", Method: zip.Deflate}
				header.SetMode(0o644)
				writer, createErr := destination.CreateHeader(header)
				if createErr != nil {
					_ = destination.Close()
					return createErr
				}
				if _, writeErr := writer.Write(license); writeErr != nil {
					_ = destination.Close()
					return writeErr
				}
				seen[licenseKey] = "LICENSE"
			}
		}
	}
	if !hasManifest {
		_ = destination.Close()
		return fmt.Errorf("Git Skill archive does not contain SKILL.md")
	}
	if err := destination.Close(); err != nil {
		return err
	}
	if err := output.Close(); err != nil {
		return err
	}
	if err := recompressZipBest(fs, zipPath); err != nil {
		return err
	}
	canonical, err := afero.ReadFile(fs, zipPath)
	if err != nil {
		return err
	}
	if _, err := protocolartifact.Sum(canonical, skillID, version); err != nil {
		return fmt.Errorf("validate generated Skill artifact: %w", err)
	}
	keepOutput = true
	return nil
}

func skillArchiveRelativePath(name, scope string) (string, bool) {
	trimmed := strings.TrimSuffix(name, "/")
	if scope == "" {
		return trimmed, true
	}
	if trimmed == scope {
		return "", true
	}
	prefix := scope + "/"
	if !strings.HasPrefix(trimmed, prefix) {
		return "", false
	}
	return strings.TrimPrefix(trimmed, prefix), true
}

func validSkillArchivePath(value string) bool {
	if value == "" || value == "." || value == ".." || !utf8.ValidString(value) || path.IsAbs(value) {
		return false
	}
	_, err := protocolartifact.PortablePathKey(value)
	return err == nil
}

// recompressZipBest rewrites a validated SkillsGo artifact ZIP using Deflate's
// highest compression level while preserving its paths and file modes.
func recompressZipBest(fs afero.Fs, zipPath string) error {
	data, err := afero.ReadFile(fs, zipPath)
	if err != nil {
		return err
	}

	zr, err := zip.NewReader(bytes.NewReader(data), int64(len(data)))
	if err != nil {
		return err
	}

	tempPath := zipPath + ".best-compression"
	out, err := fs.Create(tempPath)
	if err != nil {
		return err
	}
	keepTemp := true
	defer func() {
		_ = out.Close()
		if keepTemp {
			_ = fs.Remove(tempPath)
		}
	}()

	zw := zip.NewWriter(out)
	zw.RegisterCompressor(zip.Deflate, func(w io.Writer) (io.WriteCloser, error) {
		return flate.NewWriter(w, flate.BestCompression)
	})

	for _, file := range zr.File {
		header := file.FileHeader
		// CreateHeader derives the legacy DOS timestamp from Modified. Copying the
		// parsed time back would add an unnecessary extended-timestamp extra field.
		header.Modified = time.Time{}
		header.Extra = nil
		destination, err := zw.CreateHeader(&header)
		if err != nil {
			_ = zw.Close()
			return err
		}
		if file.FileInfo().IsDir() {
			continue
		}
		source, err := file.Open()
		if err != nil {
			_ = zw.Close()
			return err
		}
		_, copyErr := io.Copy(destination, source)
		closeErr := source.Close()
		if copyErr != nil {
			_ = zw.Close()
			return copyErr
		}
		if closeErr != nil {
			_ = zw.Close()
			return closeErr
		}
	}

	if err := zw.Close(); err != nil {
		return err
	}
	if err := out.Close(); err != nil {
		return err
	}
	if err := fs.Rename(tempPath, zipPath); err != nil {
		return fmt.Errorf("replace ZIP with best-compression archive: %w", err)
	}
	keepTemp = false
	return nil
}
