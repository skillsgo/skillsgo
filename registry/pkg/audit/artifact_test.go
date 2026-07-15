/*
 * [INPUT]: Uses in-memory ZIP fixtures representing immutable Registry Skill artifacts.
 * [OUTPUT]: Specifies bounded duplicate-safe file inspection, golden Content Digests, instruction extraction, executable evidence, and deterministic risk levels.
 * [POS]: Serves as the behavior contract for the Registry artifact audit boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package audit

import (
	"archive/zip"
	"bytes"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestAnalyzeArtifactExtractsInspectableFilesAndRiskEvidence(t *testing.T) {
	coordinate, version := "github.com/acme/skills/-/demo", "v0.0.0-test"
	data := auditZIP(t, coordinate+"@"+version+"/", map[string][]byte{
		"SKILL.md":            []byte("---\nname: demo\ndescription: Demo\n---\n# Real instructions\n"),
		"references/guide.md": []byte("# Guide\n"),
		"scripts/run.sh":      []byte("#!/bin/sh\necho demo\n"),
		"bin/helper.exe":      {0, 1, 2, 3},
	})

	result, err := AnalyzeArtifact(data, coordinate, version)
	require.NoError(t, err)
	require.Contains(t, result.Instructions, "# Real instructions")
	require.Equal(t, "high", result.Risk.Level)
	require.Equal(t, ScannerVersion, result.Risk.ScannerVersion)
	require.ElementsMatch(t, []Evidence{
		{Code: "script_file", Path: "scripts/run.sh"},
		{Code: "binary_executable", Path: "bin/helper.exe"},
	}, result.Risk.Evidence)
	require.True(t, result.HasExecutableContent)
	require.Equal(t, []string{"bin/helper.exe", "scripts/run.sh"}, result.ExecutableFiles)

	files := map[string]File{}
	for _, file := range result.Files {
		files[file.Path] = file
	}
	require.Equal(t, "instructions", files["SKILL.md"].Kind)
	require.Equal(t, "# Guide\n", files["references/guide.md"].Content)
	require.Equal(t, "script", files["scripts/run.sh"].Kind)
	require.True(t, files["scripts/run.sh"].Executable)
	require.True(t, files["bin/helper.exe"].Binary)
	require.Empty(t, files["bin/helper.exe"].Content)
}

func TestAnalyzeArtifactUsesUnknownWhenStaticSignalsCannotEstablishSafety(t *testing.T) {
	coordinate, version := "github.com/acme/skills/-/docs", "v1.0.0"
	data := auditZIP(t, coordinate+"@"+version+"/", map[string][]byte{
		"SKILL.md": []byte("---\nname: docs\ndescription: Docs\n---\n# Instructions\n"),
	})

	result, err := AnalyzeArtifact(data, coordinate, version)
	require.NoError(t, err)
	require.Equal(t, "unknown", result.Risk.Level)
	require.Empty(t, result.Risk.Evidence)
	require.False(t, result.HasExecutableContent)
}

func TestAnalyzeArtifactRejectsWrongPrefixAndMissingInstructions(t *testing.T) {
	coordinate, version := "github.com/acme/skills/-/demo", "v1.0.0"
	for name, data := range map[string][]byte{
		"wrong prefix": auditZIP(t, "github.com/other/skill@v1.0.0/", map[string][]byte{
			"SKILL.md": []byte("# Wrong"),
		}),
		"missing SKILL.md": auditZIP(t, coordinate+"@"+version+"/", map[string][]byte{
			"README.md": []byte("# Missing"),
		}),
	} {
		t.Run(name, func(t *testing.T) {
			_, err := AnalyzeArtifact(data, coordinate, version)
			require.Error(t, err)
		})
	}
}

func TestAnalyzeArtifactTruncatesLargeSupportingText(t *testing.T) {
	coordinate, version := "github.com/acme/skills/-/demo", "v1.0.0"
	data := auditZIP(t, coordinate+"@"+version+"/", map[string][]byte{
		"SKILL.md":        []byte("# Instructions"),
		"references/a.md": []byte(strings.Repeat("a", maxFileContentBytes+1)),
	})

	result, err := AnalyzeArtifact(data, coordinate, version)
	require.NoError(t, err)
	require.True(t, result.Files[1].Truncated)
	require.Len(t, result.Files[1].Content, maxFileContentBytes)
}

func TestAnalyzeArtifactContentDigestIgnoresArchiveCompressionAndEntryOrder(t *testing.T) {
	coordinate, version := "github.com/acme/skills/-/demo", "v1.0.0"
	prefix := coordinate + "@" + version + "/"
	files := []struct {
		name     string
		contents []byte
	}{
		{name: "SKILL.md", contents: []byte("# Instructions")},
		{name: "references/guide.md", contents: []byte("# Guide")},
	}
	stored := auditZIPEntries(t, prefix, zip.Store, files)
	deflated := auditZIPEntries(t, prefix, zip.Deflate, []struct {
		name     string
		contents []byte
	}{files[1], files[0]})

	storedResult, err := AnalyzeArtifact(stored, coordinate, version)
	require.NoError(t, err)
	deflatedResult, err := AnalyzeArtifact(deflated, coordinate, version)
	require.NoError(t, err)
	require.NotEqual(t, stored, deflated)
	require.Equal(t, storedResult.ContentDigest, deflatedResult.ContentDigest)
	require.Contains(t, storedResult.ContentDigest, "sha256:")
}

func TestAnalyzeArtifactRejectsDuplicatePaths(t *testing.T) {
	coordinate, version := "github.com/acme/skills/-/demo", "v1.0.0"
	data := auditZIPEntries(t, coordinate+"@"+version+"/", zip.Store, []struct {
		name     string
		contents []byte
	}{
		{name: "SKILL.md", contents: []byte("first")},
		{name: "SKILL.md", contents: []byte("second")},
	})

	_, err := AnalyzeArtifact(data, coordinate, version)
	require.ErrorContains(t, err, "duplicate")
}

func TestAnalyzeArtifactContentDigestGoldenVector(t *testing.T) {
	coordinate, version := "github.com/example/skills/-/demo", "v1"
	data := auditZIP(t, coordinate+"@"+version+"/", map[string][]byte{
		"SKILL.md": []byte("# Demo\n"),
	})

	result, err := AnalyzeArtifact(data, coordinate, version)
	require.NoError(t, err)
	require.Equal(t, "sha256:bf005aa0d71df7bbcdc3bbd01138efd6274f8cef648cf74a2a17528bfaa54399", result.ContentDigest)
}

func auditZIP(t *testing.T, prefix string, files map[string][]byte) []byte {
	t.Helper()
	var buffer bytes.Buffer
	writer := zip.NewWriter(&buffer)
	for name, contents := range files {
		entry, err := writer.Create(prefix + name)
		require.NoError(t, err)
		_, err = entry.Write(contents)
		require.NoError(t, err)
	}
	require.NoError(t, writer.Close())
	return buffer.Bytes()
}

func auditZIPEntries(t *testing.T, prefix string, method uint16, files []struct {
	name     string
	contents []byte
}) []byte {
	t.Helper()
	var buffer bytes.Buffer
	writer := zip.NewWriter(&buffer)
	for _, file := range files {
		header := &zip.FileHeader{Name: prefix + file.name, Method: method}
		entry, err := writer.CreateHeader(header)
		require.NoError(t, err)
		_, err = entry.Write(file.contents)
		require.NoError(t, err)
	}
	require.NoError(t, writer.Close())
	return buffer.Bytes()
}
