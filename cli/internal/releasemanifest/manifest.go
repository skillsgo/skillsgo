/*
 * [INPUT]: Depends on an exact five-platform CLI archive directory, release version/commit/time, SHA-256, and the fixed SkillsGo CDN origin.
 * [OUTPUT]: Writes deterministic checksums and schema-v1 Manifest bytes whose artifact URLs address immutable CDN version objects.
 * [POS]: Serves as the pure release-assembly boundary before external Ed25519 signing and publication.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package releasemanifest

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/skillsgo/skillsgo/cli/internal/selfupdate"
	"golang.org/x/mod/semver"
)

var targetExtensions = map[string]string{
	"darwin_arm64":  ".tar.gz",
	"darwin_amd64":  ".tar.gz",
	"linux_arm64":   ".tar.gz",
	"linux_amd64":   ".tar.gz",
	"windows_amd64": ".zip",
}

func Assemble(assetDirectory, version, commit, publishedAt, manifestPath, checksumsPath string) error {
	if !semver.IsValid(version) || semver.Canonical(version) != version || strings.TrimSpace(commit) == "" {
		return fmt.Errorf("invalid CLI release identity")
	}
	if _, err := time.Parse(time.RFC3339, publishedAt); err != nil {
		return fmt.Errorf("invalid CLI release publication time")
	}
	entries, err := os.ReadDir(assetDirectory)
	if err != nil {
		return err
	}
	versionNumber := strings.TrimPrefix(version, "v")
	expected := make(map[string]string, len(targetExtensions))
	for platform, extension := range targetExtensions {
		expected["skillsgo_"+versionNumber+"_"+platform+extension] = platform
	}
	archives := make(map[string]string, len(expected))
	for _, entry := range entries {
		if entry.IsDir() || strings.HasSuffix(entry.Name(), ".spdx.json") || strings.HasPrefix(entry.Name(), "skillsgo-") {
			continue
		}
		platform, ok := expected[entry.Name()]
		if !ok {
			return fmt.Errorf("unexpected CLI release asset %s", entry.Name())
		}
		archives[platform] = entry.Name()
	}
	if len(archives) != len(expected) {
		return fmt.Errorf("CLI release requires exactly %d platform archives, found %d", len(expected), len(archives))
	}

	manifest := selfupdate.Manifest{SchemaVersion: 1, Version: version, PublishedAt: publishedAt, Commit: commit, Artifacts: make(map[string]selfupdate.Artifact, len(archives)), GitHubRelease: "https://github.com/skillsgo/skillsgo/releases/tag/cli/" + version}
	checksumLines := make([]string, 0, len(archives))
	for platform, name := range archives {
		path := filepath.Join(assetDirectory, name)
		file, openErr := os.Open(path)
		if openErr != nil {
			return openErr
		}
		digest := sha256.New()
		size, copyErr := io.Copy(digest, file)
		closeErr := file.Close()
		if copyErr != nil {
			return copyErr
		}
		if closeErr != nil {
			return closeErr
		}
		if size <= 0 {
			return fmt.Errorf("empty CLI release asset %s", name)
		}
		sum := hex.EncodeToString(digest.Sum(nil))
		manifest.Artifacts[platform] = selfupdate.Artifact{URL: selfupdate.DefaultOrigin + "/cli/versions/" + version + "/" + name, SHA256: sum, Size: size}
		checksumLines = append(checksumLines, sum+"  "+name)
	}
	sort.Strings(checksumLines)
	manifestBytes, err := json.Marshal(manifest)
	if err != nil {
		return err
	}
	manifestBytes = append(manifestBytes, '\n')
	if err := os.WriteFile(manifestPath, manifestBytes, 0o644); err != nil {
		return err
	}
	return os.WriteFile(checksumsPath, []byte(strings.Join(checksumLines, "\n")+"\n"), 0o644)
}
