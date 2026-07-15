package skill

import (
	"archive/zip"
	"bytes"
	"compress/flate"
	"fmt"
	"io"
	"time"

	"github.com/spf13/afero"
)

// recompressZipBest rewrites a validated module-format ZIP using Deflate's
// highest compression level. x/mod/zip deliberately owns file selection and
// archive validation, but does not expose a compression-level option.
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
