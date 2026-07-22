// Copyright 2018 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license.

/*
 * [INPUT]: Depends on a validated list of normalized Skill-relative file paths and repeatable file readers.
 * [OUTPUT]: Provides the Go dirhash Hash1 algorithm and h1-encoded directory sums.
 * [POS]: Serves as the vendored checksum primitive used by ZIP, directory, Hub, and CLI artifact verification.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package artifact

import (
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"fmt"
	"io"
	"sort"
	"strings"
)

// Hash1 is the Go h1 directory hash algorithm, vendored from
// golang.org/x/mod/sumdb/dirhash. The caller owns file selection and paths.
func Hash1(files []string, open func(string) (io.ReadCloser, error)) (string, error) {
	h := sha256.New()
	files = append([]string(nil), files...)
	sort.Strings(files)
	for _, file := range files {
		if strings.Contains(file, "\n") {
			return "", errors.New("artifact: filenames with newlines are not supported")
		}
		r, err := open(file)
		if err != nil {
			return "", err
		}
		hf := sha256.New()
		_, copyErr := io.Copy(hf, r)
		closeErr := r.Close()
		if copyErr != nil {
			return "", copyErr
		}
		if closeErr != nil {
			return "", closeErr
		}
		if err := writeHash1Entry(h, file, hf.Sum(nil)); err != nil {
			return "", err
		}
	}
	return "h1:" + base64.StdEncoding.EncodeToString(h.Sum(nil)), nil
}

func writeHash1Content(destination io.Writer, relative string, contents []byte) error {
	if strings.Contains(relative, "\n") {
		return errors.New("artifact: filenames with newlines are not supported")
	}
	digest := sha256.Sum256(contents)
	return writeHash1Entry(destination, relative, digest[:])
}

func writeHash1Entry(destination io.Writer, relative string, digest []byte) error {
	_, err := fmt.Fprintf(destination, "%x  %s\n", digest, relative)
	return err
}
