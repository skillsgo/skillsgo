package skill

import (
	"archive/zip"
	"bytes"
	"io"
	"testing"

	"github.com/spf13/afero"
	"github.com/stretchr/testify/require"
)

func TestRecompressZipBestPreservesFiles(t *testing.T) {
	fs := afero.NewMemMapFs()
	var original bytes.Buffer
	zw := zip.NewWriter(&original)
	w, err := zw.Create("example.com/skill@v1.0.0/SKILL.md")
	require.NoError(t, err)
	content := bytes.Repeat([]byte("agent skill instructions\n"), 100)
	_, err = w.Write(content)
	require.NoError(t, err)
	require.NoError(t, zw.Close())

	const path = "/skill.zip"
	require.NoError(t, afero.WriteFile(fs, path, original.Bytes(), 0o600))
	require.NoError(t, recompressZipBest(fs, path))

	data, err := afero.ReadFile(fs, path)
	require.NoError(t, err)
	zr, err := zip.NewReader(bytes.NewReader(data), int64(len(data)))
	require.NoError(t, err)
	require.Len(t, zr.File, 1)
	require.Equal(t, uint16(zip.Deflate), zr.File[0].Method)
	r, err := zr.File[0].Open()
	require.NoError(t, err)
	got, err := io.ReadAll(r)
	require.NoError(t, err)
	require.NoError(t, r.Close())
	require.Equal(t, content, got)
}
