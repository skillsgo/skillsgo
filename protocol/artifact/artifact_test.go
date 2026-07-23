/*
 * [INPUT]: Uses deterministic, malformed, adversarial, and resource-boundary Repository ZIP/directory fixtures plus the upstream Go dirhash implementation.
 * [OUTPUT]: Specifies Repository build/verification, Go Hash1 parity, ZIP/directory parity, safe paths, bounded resource use, Skill membership, and framing failures.
 * [POS]: Serves as exhaustive compatibility and hostile-input coverage shared transitively by Hub and CLI.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package artifact

import (
	"archive/zip"
	"bytes"
	"encoding/base64"
	"errors"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"golang.org/x/mod/sumdb/dirhash"
)

type zipEntry struct {
	name, body string
	directory  bool
	method     uint16
}

func makeZIP(t *testing.T, entries ...zipEntry) []byte {
	t.Helper()
	var buffer bytes.Buffer
	writer := zip.NewWriter(&buffer)
	for _, item := range entries {
		header := &zip.FileHeader{Name: item.name, Method: item.method}
		if item.directory {
			header.Name += "/"
		}
		entry, err := writer.CreateHeader(header)
		if err != nil {
			t.Fatal(err)
		}
		if !item.directory {
			if _, err := io.WriteString(entry, item.body); err != nil {
				t.Fatal(err)
			}
		}
	}
	if err := writer.Close(); err != nil {
		t.Fatal(err)
	}
	return buffer.Bytes()
}

func TestRepositoryArtifactBuildAndSumMatchGoDirhashWithoutRootSkill(t *testing.T) {
	files := []Entry{
		{Path: "README.md", Contents: []byte("repository")},
		{Path: "bin/tool", Contents: []byte("#!/bin/sh\n"), Mode: 0o755},
		{Path: "skills/review/SKILL.md", Contents: []byte("review instructions")},
	}
	archive, err := BuildRepository("github.com/example/suite", "v1.2.3", files)
	if err != nil {
		t.Fatal(err)
	}
	got, err := RepositorySum(archive, "github.com/example/suite", "v1.2.3")
	if err != nil {
		t.Fatal(err)
	}
	want, err := dirhash.Hash1(
		[]string{"README.md", "bin/tool", "skills/review/SKILL.md"},
		func(name string) (io.ReadCloser, error) {
			for _, file := range files {
				if file.Path == name {
					return io.NopCloser(bytes.NewReader(file.Contents)), nil
				}
			}
			return nil, os.ErrNotExist
		},
	)
	if err != nil {
		t.Fatal(err)
	}
	if got != want {
		t.Fatalf("RepositorySum() = %q, Go dirhash.Hash1() = %q", got, want)
	}

	var visited []string
	walked, err := WalkRepository(archive, "github.com/example/suite", "v1.2.3", func(entry Entry) error {
		if !entry.Directory {
			visited = append(visited, entry.Path)
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	if walked != got {
		t.Fatalf("WalkRepository() = %q, RepositorySum() = %q", walked, got)
	}
	if got, want := strings.Join(visited, ","), "README.md,bin/tool,skills/review/SKILL.md"; got != want {
		t.Fatalf("visited %q, want %q", got, want)
	}
}

func TestRepositoryArtifactDirectoryParityAndDeterministicEnvelope(t *testing.T) {
	root := t.TempDir()
	if err := os.MkdirAll(filepath.Join(root, "skills", "review"), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, "README.md"), []byte("repository"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, "skills", "review", "SKILL.md"), []byte("review"), 0o600); err != nil {
		t.Fatal(err)
	}
	want, err := RepositoryDirectorySum(root)
	if err != nil {
		t.Fatal(err)
	}
	files := []Entry{
		{Path: "skills/review/SKILL.md", Contents: []byte("review")},
		{Path: "README.md", Contents: []byte("repository")},
	}
	first, err := BuildRepository("github.com/example/suite", "v1.2.3", files)
	if err != nil {
		t.Fatal(err)
	}
	second, err := BuildRepository("github.com/example/suite", "v1.2.3", files)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(first, second) {
		t.Fatal("BuildRepository produced different bytes for the same inventory")
	}
	got, err := RepositorySum(first, "github.com/example/suite", "v1.2.3")
	if err != nil {
		t.Fatal(err)
	}
	if got != want {
		t.Fatalf("RepositorySum() = %q, RepositoryDirectorySum() = %q", got, want)
	}
}

func TestBuildRepositoryRejectsInvalidInputsAndCanonicalizesModes(t *testing.T) {
	for _, test := range []struct {
		name       string
		repository string
		version    string
		files      []Entry
		contains   string
	}{
		{name: "missing identity", version: "v1", files: []Entry{{Path: "SKILL.md"}}, contains: "identity and version"},
		{name: "missing version", repository: "example.com/repo", files: []Entry{{Path: "SKILL.md"}}, contains: "identity and version"},
		{name: "empty inventory", repository: "example.com/repo", version: "v1", contains: "file count"},
		{name: "directory input", repository: "example.com/repo", version: "v1", files: []Entry{{Path: "docs", Directory: true}}, contains: "is a directory"},
		{name: "irregular mode", repository: "example.com/repo", version: "v1", files: []Entry{{Path: "link", Mode: os.ModeSymlink}}, contains: "mode is not regular"},
	} {
		t.Run(test.name, func(t *testing.T) {
			_, err := BuildRepository(test.repository, test.version, test.files)
			if err == nil || !strings.Contains(err.Error(), test.contains) {
				t.Fatalf("error %v, want %q", err, test.contains)
			}
		})
	}
	tooMany := make([]Entry, MaxFiles+1)
	if _, err := BuildRepository("example.com/repo", "v1", tooMany); err == nil || !strings.Contains(err.Error(), "file count") {
		t.Fatalf("file-count error: %v", err)
	}
	tooLarge := make([]byte, MaxUncompressedBytes+1)
	if _, err := BuildRepository("example.com/repo", "v1", []Entry{{Path: "SKILL.md", Contents: tooLarge}}); err == nil || !strings.Contains(err.Error(), "exceeds") {
		t.Fatalf("size error: %v", err)
	}

	archive, err := BuildRepository("example.com/repo", "v1", []Entry{
		{Path: "SKILL.md", Contents: []byte("skill")},
		{Path: "default", Contents: []byte("default")},
		{Path: "executable", Mode: 0o700, Contents: []byte("executable")},
		{Path: "regular", Mode: 0o600, Contents: []byte("regular")},
	})
	if err != nil {
		t.Fatal(err)
	}
	reader, err := zip.NewReader(bytes.NewReader(archive), int64(len(archive)))
	if err != nil {
		t.Fatal(err)
	}
	wantModes := map[string]os.FileMode{"SKILL.md": 0o644, "default": 0o644, "executable": 0o755, "regular": 0o644}
	for _, file := range reader.File {
		name := strings.TrimPrefix(file.Name, "example.com/repo@v1/")
		if want, ok := wantModes[name]; ok && file.Mode().Perm() != want {
			t.Errorf("%s mode = %o, want %o", name, file.Mode().Perm(), want)
		}
	}
}

func TestSumGoldenAndArchiveEncodingIndependence(t *testing.T) {
	stored := makeZIP(t, zipEntry{"example@v1.0.0/a.txt", "a", false, zip.Store}, zipEntry{"example@v1.0.0/SKILL.md", "instructions", false, zip.Store}, zipEntry{"example@v1.0.0/empty", "", true, zip.Store})
	deflated := makeZIP(t, zipEntry{"example@v1.0.0/SKILL.md", "instructions", false, zip.Deflate}, zipEntry{"example@v1.0.0/a.txt", "a", false, zip.Deflate})
	want := "h1:MZJbLD1I7JI4vWGTWBFoQDvd7m98NPrqTxv62sLSzxs="
	for _, archive := range [][]byte{stored, deflated} {
		digest, err := Sum(archive, "example", "v1.0.0")
		if err != nil {
			t.Fatal(err)
		}
		if digest != want {
			t.Fatalf("digest %s, want %s", digest, want)
		}
	}
}

func TestWalkContentVisitsNormalizedFilesAndReturnsTheSameDigest(t *testing.T) {
	archive := makeZIP(t,
		zipEntry{"example@v1/z.txt", "z", false, zip.Store},
		zipEntry{"example@v1/SKILL.md", "instructions", false, zip.Store},
	)
	var visited []string
	digest, err := WalkContent(archive, "example", "v1", func(entry Entry) error {
		visited = append(visited, entry.Path+":"+string(entry.Contents))
		if entry.Size != int64(len(entry.Contents)) {
			t.Fatalf("entry size %d != %d", entry.Size, len(entry.Contents))
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	want, err := Sum(archive, "example", "v1")
	if err != nil {
		t.Fatal(err)
	}
	if digest != want {
		t.Fatalf("walk digest %s != sum %s", digest, want)
	}
	if got, want := strings.Join(visited, ","), "SKILL.md:instructions,z.txt:z"; got != want {
		t.Fatalf("visited %q, want %q", got, want)
	}
}

func TestWalkContentPropagatesVisitorFailure(t *testing.T) {
	archive := makeZIP(t, zipEntry{"example@v1/SKILL.md", "instructions", false, zip.Store})
	_, err := WalkContent(archive, "example", "v1", func(Entry) error {
		return errors.New("inspection failed")
	})
	if err == nil || !strings.Contains(err.Error(), `visit artifact file "SKILL.md": inspection failed`) {
		t.Fatalf("visitor error: %v", err)
	}
}

func TestWalkContentVisitsDirectoriesAndRejectsTreeShapeConflicts(t *testing.T) {
	archive := makeZIP(t,
		zipEntry{"example@v1/SKILL.md", "instructions", false, zip.Store},
		zipEntry{"example@v1/docs", "", true, zip.Store},
	)
	visitedDirectory := false
	_, err := WalkContent(archive, "example", "v1", func(entry Entry) error {
		if entry.Directory {
			visitedDirectory = entry.Path == "docs" && entry.Contents == nil && entry.Size == 0
			return errors.New("directory inspection failed")
		}
		return nil
	})
	if !visitedDirectory || err == nil || !strings.Contains(err.Error(), `visit artifact directory "docs": directory inspection failed`) {
		t.Fatalf("directory visit=%v error=%v", visitedDirectory, err)
	}

	for _, test := range []struct {
		name     string
		entries  []zipEntry
		contains string
	}{
		{
			name: "directory and file portable collision",
			entries: []zipEntry{
				{"example@v1/SKILL.md", "instructions", false, zip.Store},
				{"example@v1/Docs", "file", false, zip.Store},
				{"example@v1/docs", "", true, zip.Store},
			},
			contains: "collide on portable filesystems",
		},
		{
			name: "file used as parent directory",
			entries: []zipEntry{
				{"example@v1/SKILL.md", "instructions", false, zip.Store},
				{"example@v1/a", "file", false, zip.Store},
				{"example@v1/a/b", "child", false, zip.Store},
			},
			contains: "conflicts with parent file",
		},
	} {
		t.Run(test.name, func(t *testing.T) {
			_, err := Sum(makeZIP(t, test.entries...), "example", "v1")
			if err == nil || !strings.Contains(err.Error(), test.contains) {
				t.Fatalf("error %v, want %q", err, test.contains)
			}
		})
	}
}

func TestWalkRepositoryAcceptsRootDirectoryAndRejectsInvalidDirectory(t *testing.T) {
	archive := makeZIP(t,
		zipEntry{"example@v1/", "", true, zip.Store},
		zipEntry{"example@v1/skills/demo/SKILL.md", "demo", false, zip.Store},
	)
	if _, err := RepositorySum(archive, "example", "v1"); err != nil {
		t.Fatalf("root directory entry: %v", err)
	}
	invalidDirectory := makeZIP(t,
		zipEntry{"example@v1/bad ", "", true, zip.Store},
		zipEntry{"example@v1/SKILL.md", "root", false, zip.Store},
	)
	if _, err := RepositorySum(invalidDirectory, "example", "v1"); err == nil {
		t.Fatal("expected invalid directory path rejection")
	}
	noSkill := t.TempDir()
	if err := os.WriteFile(filepath.Join(noSkill, "README.md"), []byte("readme"), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := RepositoryDirectorySum(noSkill); err == nil || !strings.Contains(err.Error(), "SKILL.md member") {
		t.Fatalf("missing member error: %v", err)
	}
	noSkillArchive := makeZIP(t, zipEntry{"example@v1/README.md", "readme", false, zip.Store})
	if _, err := RepositorySum(noSkillArchive, "example", "v1"); err == nil || !strings.Contains(err.Error(), "SKILL.md member") {
		t.Fatalf("missing archive member error: %v", err)
	}
	corrupt := append([]byte(nil), makeZIP(t, zipEntry{"example@v1/SKILL.md", "root", false, zip.Store})...)
	central := bytes.Index(corrupt, []byte{'P', 'K', 1, 2})
	if central < 0 {
		t.Fatal("missing ZIP central directory")
	}
	corrupt[central+16]++
	if _, err := RepositorySum(corrupt, "example", "v1"); err == nil || !strings.Contains(err.Error(), "read artifact file") {
		t.Fatalf("corrupt archive error: %v", err)
	}
	unsupported := append([]byte(nil), makeZIP(t, zipEntry{"example@v1/SKILL.md", "root", false, zip.Store})...)
	central = bytes.Index(unsupported, []byte{'P', 'K', 1, 2})
	local := bytes.Index(unsupported, []byte{'P', 'K', 3, 4})
	unsupported[local+8], unsupported[local+9] = 99, 0
	unsupported[central+10], unsupported[central+11] = 99, 0
	if _, err := RepositorySum(unsupported, "example", "v1"); err == nil || !strings.Contains(err.Error(), "unsupported compression") {
		t.Fatalf("unsupported compression error: %v", err)
	}
}

func TestSumRejectsMalformedAndUnsafeArchives(t *testing.T) {
	valid := zipEntry{"example@v1/SKILL.md", "ok", false, zip.Store}
	tests := []struct {
		name     string
		archive  []byte
		contains string
	}{
		{"empty", nil, "size must be"}, {"not zip", []byte("not-a-zip"), "open artifact"},
		{"wrong prefix", makeZIP(t, zipEntry{"other@v1/SKILL.md", "ok", false, zip.Store}), "outside expected prefix"},
		{"absolute path", makeZIP(t, valid, zipEntry{"example@v1//etc/passwd", "x", false, zip.Store}), "invalid relative path"},
		{"backslash", makeZIP(t, valid, zipEntry{"example@v1/a\\b", "x", false, zip.Store}), "invalid relative path"},
		{"dot segment", makeZIP(t, valid, zipEntry{"example@v1/a/../b", "x", false, zip.Store}), "invalid relative path"},
		{"duplicate", makeZIP(t, valid, valid), "collide on portable filesystems"},
		{"Windows reserved", makeZIP(t, valid, zipEntry{"example@v1/CON.txt", "x", false, zip.Store}), "not portable"},
		{"Windows trailing space", makeZIP(t, valid, zipEntry{"example@v1/name ", "x", false, zip.Store}), "trailing space"},
		{"portable case collision", makeZIP(t, valid, zipEntry{"example@v1/Readme.md", "x", false, zip.Store}, zipEntry{"example@v1/README.md", "y", false, zip.Store}), "collide on portable filesystems"},
		{"Unicode fold collision", makeZIP(t, valid, zipEntry{"example@v1/K.txt", "x", false, zip.Store}, zipEntry{"example@v1/K.txt", "y", false, zip.Store}), "collide on portable filesystems"},
		{"missing manifest", makeZIP(t, zipEntry{"example@v1/a.txt", "x", false, zip.Store}), "does not contain SKILL.md"},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			_, err := Sum(test.archive, "example", "v1")
			if err == nil || !strings.Contains(err.Error(), test.contains) {
				t.Fatalf("error %v, want %q", err, test.contains)
			}
		})
	}
	oversized := make([]byte, MaxArchiveBytes+1)
	if _, err := Sum(oversized, "example", "v1"); err == nil {
		t.Fatal("expected archive-size rejection")
	}
}

func TestSumRejectsIrregularModes(t *testing.T) {
	makeModeZIP := func(mode os.FileMode) []byte {
		var buffer bytes.Buffer
		writer := zip.NewWriter(&buffer)
		manifest, err := writer.Create("example@v1/SKILL.md")
		if err != nil {
			t.Fatal(err)
		}
		_, _ = io.WriteString(manifest, "instructions")
		header := &zip.FileHeader{Name: "example@v1/tool", Method: zip.Store}
		header.SetMode(mode)
		entry, err := writer.CreateHeader(header)
		if err != nil {
			t.Fatal(err)
		}
		_, _ = io.WriteString(entry, "tool")
		if err := writer.Close(); err != nil {
			t.Fatal(err)
		}
		return buffer.Bytes()
	}
	for _, test := range []struct {
		name     string
		mode     os.FileMode
		contains string
	}{
		{"symlink", os.ModeSymlink | 0o777, "not a regular file"},
	} {
		t.Run(test.name, func(t *testing.T) {
			_, err := Sum(makeModeZIP(test.mode), "example", "v1")
			if err == nil || !strings.Contains(err.Error(), test.contains) {
				t.Fatalf("error %v, want %q", err, test.contains)
			}
		})
	}
}

func TestSumRejectsFileCountAndExpandedSize(t *testing.T) {
	entries := make([]zipEntry, 0, MaxFiles+1)
	entries = append(entries, zipEntry{"example@v1/SKILL.md", "ok", false, zip.Store})
	for i := 0; i < MaxFiles; i++ {
		entries = append(entries, zipEntry{filepath.ToSlash(filepath.Join("example@v1", "files", formatIndex(i))), "", false, zip.Store})
	}
	if _, err := Sum(makeZIP(t, entries...), "example", "v1"); err == nil || !strings.Contains(err.Error(), "more than") {
		t.Fatalf("file-count error: %v", err)
	}
	large := strings.Repeat("x", MaxUncompressedBytes+1)
	if _, err := Sum(makeZIP(t, zipEntry{"example@v1/SKILL.md", large, false, zip.Deflate}), "example", "v1"); err == nil || !strings.Contains(err.Error(), "expands beyond") {
		t.Fatalf("expanded-size error: %v", err)
	}
}

func formatIndex(value int) string {
	const digits = "0123456789"
	if value == 0 {
		return "0"
	}
	var result [20]byte
	position := len(result)
	for value > 0 {
		position--
		result[position] = digits[value%10]
		value /= 10
	}
	return string(result[position:])
}

func TestDirectorySumMatchesArchiveAndRejectsUnsafeTrees(t *testing.T) {
	root := t.TempDir()
	if err := os.MkdirAll(filepath.Join(root, "nested"), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, "SKILL.md"), []byte("instructions"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, "nested", "a.txt"), []byte("a"), 0o600); err != nil {
		t.Fatal(err)
	}
	directoryDigest, err := DirectorySum(root)
	if err != nil {
		t.Fatal(err)
	}
	archive := makeZIP(t, zipEntry{"example@v1/SKILL.md", "instructions", false, zip.Store}, zipEntry{"example@v1/nested/a.txt", "a", false, zip.Store})
	archiveDigest, err := Sum(archive, "example", "v1")
	if err != nil {
		t.Fatal(err)
	}
	if directoryDigest != archiveDigest {
		t.Fatalf("directory %s != archive %s", directoryDigest, archiveDigest)
	}
	missing := t.TempDir()
	if _, err := DirectorySum(missing); err == nil || !strings.Contains(err.Error(), "regular SKILL.md") {
		t.Fatalf("missing manifest error: %v", err)
	}
	symlinkRoot := t.TempDir()
	if err := os.WriteFile(filepath.Join(symlinkRoot, "SKILL.md"), []byte("ok"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(filepath.Join(symlinkRoot, "SKILL.md"), filepath.Join(symlinkRoot, "alias")); err != nil {
		t.Fatal(err)
	}
	if _, err := DirectorySum(symlinkRoot); err == nil || !strings.Contains(err.Error(), "unsupported file") {
		t.Fatalf("symlink error: %v", err)
	}
	largeRoot := t.TempDir()
	if err := os.WriteFile(filepath.Join(largeRoot, "SKILL.md"), []byte("ok"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.Truncate(filepath.Join(largeRoot, "SKILL.md"), MaxUncompressedBytes+1); err != nil {
		t.Fatal(err)
	}
	if _, err := DirectorySum(largeRoot); err == nil || !strings.Contains(err.Error(), "exceeds") {
		t.Fatalf("large directory error: %v", err)
	}
	if _, err := DirectorySum(filepath.Join(t.TempDir(), "missing")); err == nil {
		t.Fatal("expected missing-root traversal failure")
	}
}

func TestDirectorySumRejectsFileCountBoundary(t *testing.T) {
	root := t.TempDir()
	if err := os.WriteFile(filepath.Join(root, "SKILL.md"), []byte("ok"), 0o600); err != nil {
		t.Fatal(err)
	}
	for index := 0; index < MaxFiles; index++ {
		if err := os.WriteFile(filepath.Join(root, "file-"+formatIndex(index)), nil, 0o600); err != nil {
			t.Fatal(err)
		}
	}
	if _, err := DirectorySum(root); err == nil || !strings.Contains(err.Error(), "more than") {
		t.Fatalf("file-count error: %v", err)
	}
}

func TestDirectorySumRejectsNonPortablePath(t *testing.T) {
	root := t.TempDir()
	if err := os.WriteFile(filepath.Join(root, "SKILL.md"), []byte("ok"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, "trailing "), []byte("bad"), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := DirectorySum(root); err == nil || !strings.Contains(err.Error(), "invalid path") {
		t.Fatalf("portable path error: %v", err)
	}
}

func TestReadEntryRejectsUnsupportedCompressionCorruptionAndSizeMismatch(t *testing.T) {
	archive := makeZIP(t, zipEntry{"example@v1/SKILL.md", "instructions", false, zip.Store})
	reader, err := zip.NewReader(bytes.NewReader(archive), int64(len(archive)))
	if err != nil {
		t.Fatal(err)
	}
	unsupported := *reader.File[0]
	unsupported.Method = 99
	if _, err := ReadEntry(&unsupported); err == nil {
		t.Fatal("expected unsupported compression failure")
	}
	badCRC := *reader.File[0]
	badCRC.CRC32++
	if _, err := ReadEntry(&badCRC); err == nil {
		t.Fatal("expected CRC failure")
	}
	wrongSize := *reader.File[0]
	wrongSize.UncompressedSize64++
	if _, err := ReadEntry(&wrongSize); err == nil {
		t.Fatal("expected ZIP reader to reject inconsistent metadata")
	}
	if _, err := readBounded(strings.NewReader("content"), 8); err == nil || !strings.Contains(err.Error(), "size does not match") {
		t.Fatalf("declared-size mismatch error: %v", err)
	}
}

func TestPathAndDigestSyntaxBoundaries(t *testing.T) {
	for _, value := range []string{"SKILL.md", "nested/file", "a..b"} {
		if !ValidRelativePath(value) {
			t.Fatalf("expected valid %q", value)
		}
	}
	for _, value := range []string{"", ".", "..", "/root", "../escape", "a/../b", "a\\b", "a//b"} {
		if ValidRelativePath(value) {
			t.Fatalf("expected invalid %q", value)
		}
	}
	valid := "h1:" + base64.StdEncoding.EncodeToString(make([]byte, 32))
	if !ValidSum(valid) {
		t.Fatal("valid digest rejected")
	}
	for _, value := range []string{"", strings.Repeat("a", 44), "sha256:" + strings.Repeat("a", 64), "h1:not-base64", "h1:" + base64.StdEncoding.EncodeToString(make([]byte, 31))} {
		if ValidSum(value) {
			t.Fatalf("invalid digest accepted: %q", value)
		}
	}
}

type failWriter struct{ remaining int }

func (writer *failWriter) Write(data []byte) (int, error) {
	if writer.remaining <= 0 {
		return 0, errors.New("write failed")
	}
	if len(data) > writer.remaining {
		written := writer.remaining
		writer.remaining = 0
		return written, errors.New("write failed")
	}
	writer.remaining -= len(data)
	return len(data), nil
}

func TestWriteHash1ContentPropagatesWriteFailure(t *testing.T) {
	if err := writeHash1Content(io.Discard, "bad\nname", []byte("x")); err == nil {
		t.Fatal("expected newline rejection")
	}
	for _, limit := range []int{0, 1, 20} {
		writer := &failWriter{remaining: limit}
		if err := writeHash1Content(writer, "a", []byte("x")); err == nil {
			t.Fatalf("expected failure after %d bytes", limit)
		}
	}
	var output bytes.Buffer
	if err := writeHash1Content(&output, "a", []byte("x")); err != nil {
		t.Fatal(err)
	}
	if got, want := output.String(), "2d711642b726b04401627ca9fbac32f5c8530fb1903cc4db02258717921a4881  a\n"; got != want {
		t.Fatalf("hash1 entry %q, want %q", got, want)
	}
}

func TestHash1SuccessAndReaderFailures(t *testing.T) {
	files := map[string]string{"b": "two", "a": "one"}
	got, err := Hash1([]string{"b", "a"}, func(name string) (io.ReadCloser, error) {
		return io.NopCloser(strings.NewReader(files[name])), nil
	})
	if err != nil || !ValidSum(got) {
		t.Fatalf("Hash1() = %q, %v", got, err)
	}
	if _, err := Hash1([]string{"bad\nname"}, func(string) (io.ReadCloser, error) { return nil, nil }); err == nil {
		t.Fatal("expected newline rejection")
	}
	openErr := errors.New("open failed")
	if _, err := Hash1([]string{"a"}, func(string) (io.ReadCloser, error) { return nil, openErr }); !errors.Is(err, openErr) {
		t.Fatalf("open error = %v", err)
	}
	if _, err := Hash1([]string{"a"}, func(string) (io.ReadCloser, error) { return failingReadCloser{readErr: errors.New("read failed")}, nil }); err == nil {
		t.Fatal("expected read failure")
	}
	closeErr := errors.New("close failed")
	if _, err := Hash1([]string{"a"}, func(string) (io.ReadCloser, error) {
		return failingReadCloser{reader: strings.NewReader("one"), closeErr: closeErr}, nil
	}); !errors.Is(err, closeErr) {
		t.Fatalf("close error = %v", err)
	}
}

type failingReadCloser struct {
	reader   io.Reader
	readErr  error
	closeErr error
}

func (reader failingReadCloser) Read(data []byte) (int, error) {
	if reader.readErr != nil {
		return 0, reader.readErr
	}
	return reader.reader.Read(data)
}

func (reader failingReadCloser) Close() error { return reader.closeErr }
