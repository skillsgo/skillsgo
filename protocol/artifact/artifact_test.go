/*
 * [INPUT]: Uses deterministic, malformed, adversarial, and resource-boundary ZIP/directory fixtures plus failing writers.
 * [OUTPUT]: Specifies Content Digest stability, ZIP/directory parity, safe paths, bounded resource use, required manifests, and framing failures.
 * [POS]: Serves as exhaustive compatibility and hostile-input coverage shared transitively by Hub and CLI.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package artifact

import (
	"archive/zip"
	"bytes"
	"errors"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"
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

func TestContentDigestGoldenAndArchiveEncodingIndependence(t *testing.T) {
	stored := makeZIP(t, zipEntry{"example@v1.0.0/a.txt", "a", false, zip.Store}, zipEntry{"example@v1.0.0/SKILL.md", "instructions", false, zip.Store}, zipEntry{"example@v1.0.0/empty", "", true, zip.Store})
	deflated := makeZIP(t, zipEntry{"example@v1.0.0/SKILL.md", "instructions", false, zip.Deflate}, zipEntry{"example@v1.0.0/a.txt", "a", false, zip.Deflate})
	want := "sha256:849c5ecf256d3c1b65ff50bfef893efe951a6b5d22cdebea37d9628f392de847"
	for _, archive := range [][]byte{stored, deflated} {
		digest, err := ContentDigest(archive, "example", "v1.0.0")
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
	want, err := ContentDigest(archive, "example", "v1")
	if err != nil {
		t.Fatal(err)
	}
	if digest != want {
		t.Fatalf("walk digest %s != content digest %s", digest, want)
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

func TestContentDigestRejectsMalformedAndUnsafeArchives(t *testing.T) {
	valid := zipEntry{"example@v1/SKILL.md", "ok", false, zip.Store}
	tests := []struct {
		name     string
		archive  []byte
		contains string
	}{
		{"empty", nil, "size must be"}, {"not zip", []byte("not-a-zip"), "open artifact"},
		{"wrong prefix", makeZIP(t, zipEntry{"other@v1/SKILL.md", "ok", false, zip.Store}), "outside expected prefix"},
		{"absolute path", makeZIP(t, valid, zipEntry{"example@v1//etc/passwd", "x", false, zip.Store}), "invalid or duplicate path"},
		{"backslash", makeZIP(t, valid, zipEntry{"example@v1/a\\b", "x", false, zip.Store}), "invalid or duplicate path"},
		{"dot segment", makeZIP(t, valid, zipEntry{"example@v1/a/../b", "x", false, zip.Store}), "invalid or duplicate path"},
		{"duplicate", makeZIP(t, valid, valid), "invalid or duplicate path"},
		{"missing manifest", makeZIP(t, zipEntry{"example@v1/a.txt", "x", false, zip.Store}), "does not contain SKILL.md"},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			_, err := ContentDigest(test.archive, "example", "v1")
			if err == nil || !strings.Contains(err.Error(), test.contains) {
				t.Fatalf("error %v, want %q", err, test.contains)
			}
		})
	}
	oversized := make([]byte, MaxArchiveBytes+1)
	if _, err := ContentDigest(oversized, "example", "v1"); err == nil {
		t.Fatal("expected archive-size rejection")
	}
}

func TestContentDigestRejectsFileCountAndExpandedSize(t *testing.T) {
	entries := make([]zipEntry, 0, MaxFiles+1)
	entries = append(entries, zipEntry{"example@v1/SKILL.md", "ok", false, zip.Store})
	for i := 0; i < MaxFiles; i++ {
		entries = append(entries, zipEntry{filepath.ToSlash(filepath.Join("example@v1", "files", formatIndex(i))), "", false, zip.Store})
	}
	if _, err := ContentDigest(makeZIP(t, entries...), "example", "v1"); err == nil || !strings.Contains(err.Error(), "more than") {
		t.Fatalf("file-count error: %v", err)
	}
	large := strings.Repeat("x", MaxUncompressedBytes+1)
	if _, err := ContentDigest(makeZIP(t, zipEntry{"example@v1/SKILL.md", large, false, zip.Deflate}), "example", "v1"); err == nil || !strings.Contains(err.Error(), "expands beyond") {
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

func TestDirectoryContentDigestMatchesArchiveAndRejectsUnsafeTrees(t *testing.T) {
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
	directoryDigest, err := DirectoryContentDigest(root)
	if err != nil {
		t.Fatal(err)
	}
	archive := makeZIP(t, zipEntry{"example@v1/SKILL.md", "instructions", false, zip.Store}, zipEntry{"example@v1/nested/a.txt", "a", false, zip.Store})
	archiveDigest, err := ContentDigest(archive, "example", "v1")
	if err != nil {
		t.Fatal(err)
	}
	if directoryDigest != archiveDigest {
		t.Fatalf("directory %s != archive %s", directoryDigest, archiveDigest)
	}
	missing := t.TempDir()
	if _, err := DirectoryContentDigest(missing); err == nil || !strings.Contains(err.Error(), "regular SKILL.md") {
		t.Fatalf("missing manifest error: %v", err)
	}
	symlinkRoot := t.TempDir()
	if err := os.WriteFile(filepath.Join(symlinkRoot, "SKILL.md"), []byte("ok"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(filepath.Join(symlinkRoot, "SKILL.md"), filepath.Join(symlinkRoot, "alias")); err != nil {
		t.Fatal(err)
	}
	if _, err := DirectoryContentDigest(symlinkRoot); err == nil || !strings.Contains(err.Error(), "unsupported file") {
		t.Fatalf("symlink error: %v", err)
	}
	largeRoot := t.TempDir()
	if err := os.WriteFile(filepath.Join(largeRoot, "SKILL.md"), []byte("ok"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.Truncate(filepath.Join(largeRoot, "SKILL.md"), MaxUncompressedBytes+1); err != nil {
		t.Fatal(err)
	}
	if _, err := DirectoryContentDigest(largeRoot); err == nil || !strings.Contains(err.Error(), "exceeds") {
		t.Fatalf("large directory error: %v", err)
	}
	if _, err := DirectoryContentDigest(filepath.Join(t.TempDir(), "missing")); err == nil {
		t.Fatal("expected missing-root traversal failure")
	}
}

func TestDirectoryContentDigestRejectsFileCountBoundary(t *testing.T) {
	root := t.TempDir()
	if err := os.WriteFile(filepath.Join(root, "SKILL.md"), []byte("ok"), 0o600); err != nil {
		t.Fatal(err)
	}
	for index := 0; index < MaxFiles; index++ {
		if err := os.WriteFile(filepath.Join(root, "file-"+formatIndex(index)), nil, 0o600); err != nil {
			t.Fatal(err)
		}
	}
	if _, err := DirectoryContentDigest(root); err == nil || !strings.Contains(err.Error(), "more than") {
		t.Fatalf("file-count error: %v", err)
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
	valid := "sha256:" + strings.Repeat("a", 64)
	if !ValidContentDigest(valid) {
		t.Fatal("valid digest rejected")
	}
	for _, value := range []string{"", strings.Repeat("a", 64), "sha512:" + strings.Repeat("a", 64), "sha256:" + strings.Repeat("g", 64), "sha256:" + strings.Repeat("a", 63)} {
		if ValidContentDigest(value) {
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

func TestWriteDigestEntryPropagatesEveryWriteFailure(t *testing.T) {
	for _, limit := range []int{0, 8, 9, 17} {
		writer := &failWriter{remaining: limit}
		if err := WriteDigestEntry(writer, "a", []byte("x")); err == nil {
			t.Fatalf("expected failure after %d bytes", limit)
		}
	}
	var output bytes.Buffer
	if err := WriteDigestEntry(&output, "a", []byte("x")); err != nil {
		t.Fatal(err)
	}
	if output.Len() != 18 {
		t.Fatalf("framed length %d", output.Len())
	}
}
