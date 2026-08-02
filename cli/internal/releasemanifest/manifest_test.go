/*
 * [INPUT]: Uses temporary complete and malformed CLI archive sets around Assemble.
 * [OUTPUT]: Specifies deterministic signed-payload inputs, immutable CDN URLs, checksums, and exact target-set enforcement.
 * [POS]: Serves as focused release-assembly contract coverage before workflow signing.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package releasemanifest

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/selfupdate"
	"github.com/stretchr/testify/require"
)

func TestAssembleWritesCompleteImmutableManifest(t *testing.T) {
	directory := t.TempDir()
	writeFixtureArchives(t, directory, "1.2.3")
	manifestPath := filepath.Join(directory, "manifest.json")
	checksumsPath := filepath.Join(directory, "checksums.txt")

	require.NoError(t, Assemble(directory, "v1.2.3", "abcdef", "2026-08-02T00:00:00Z", manifestPath, checksumsPath))
	var manifest selfupdate.Manifest
	data, err := os.ReadFile(manifestPath)
	require.NoError(t, err)
	require.NoError(t, json.Unmarshal(data, &manifest))
	require.Len(t, manifest.Artifacts, 5)
	require.Equal(t, "https://cdn.skillsgo.ai/cli/versions/v1.2.3/skillsgo_1.2.3_darwin_arm64.tar.gz", manifest.Artifacts["darwin_arm64"].URL)
	require.Equal(t, "https://github.com/skillsgo/skillsgo/releases/tag/cli/v1.2.3", manifest.GitHubRelease)
	checksums, err := os.ReadFile(checksumsPath)
	require.NoError(t, err)
	require.Equal(t, 5, len(splitNonEmpty(string(checksums))))
}

func TestAssembleRejectsMissingOrUnexpectedArchive(t *testing.T) {
	directory := t.TempDir()
	writeFixtureArchives(t, directory, "1.2.3")
	require.NoError(t, os.Remove(filepath.Join(directory, "skillsgo_1.2.3_linux_arm64.tar.gz")))
	err := Assemble(directory, "v1.2.3", "abcdef", "2026-08-02T00:00:00Z", filepath.Join(directory, "manifest.json"), filepath.Join(directory, "checksums.txt"))
	require.ErrorContains(t, err, "requires exactly 5")

	directory = t.TempDir()
	writeFixtureArchives(t, directory, "1.2.3")
	require.NoError(t, os.WriteFile(filepath.Join(directory, "surprise.txt"), []byte("x"), 0o600))
	err = Assemble(directory, "v1.2.3", "abcdef", "2026-08-02T00:00:00Z", filepath.Join(directory, "manifest.json"), filepath.Join(directory, "checksums.txt"))
	require.ErrorContains(t, err, "unexpected CLI release asset")
}

func writeFixtureArchives(t *testing.T, directory, version string) {
	t.Helper()
	for platform, extension := range targetExtensions {
		name := "skillsgo_" + version + "_" + platform + extension
		require.NoError(t, os.WriteFile(filepath.Join(directory, name), []byte(platform), 0o600))
	}
}

func splitNonEmpty(value string) []string {
	lines := []string{}
	for _, line := range strings.Split(value, "\n") {
		if line != "" {
			lines = append(lines, line)
		}
	}
	return lines
}
