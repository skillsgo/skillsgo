/*
 * [INPUT]: Uses deterministic, malformed, adversarial, and resource-boundary ZIP/directory fixtures plus failing writers.
 * [OUTPUT]: Specifies Sum stability, ZIP/directory parity, safe paths, bounded resource use, required manifests, and framing failures.
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

func TestSumRejectsMalformedAndUnsafeArchives(t *testing.T) {
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
