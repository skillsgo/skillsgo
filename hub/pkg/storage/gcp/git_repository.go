/*
 * [INPUT]: Depends on GCS objects, canonical Package Paths, and local bare Git repository files.
 * [OUTPUT]: Hydrates and publishes complete static Git Artifact repositories with immutable-object reuse.
 * [POS]: Serves as the GCS implementation of storage.GitRepositoryStore.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package gcp

import (
	"context"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"

	gcs "cloud.google.com/go/storage"
	pkgstorage "github.com/skillsgo/skillsgo/hub/pkg/storage"
	"google.golang.org/api/iterator"
)

func gitRepositoryPrefix(packagePath string) (string, error) {
	if packagePath == "" || strings.HasPrefix(packagePath, "/") || strings.Contains(packagePath, "\\") || strings.Contains(packagePath, "../") {
		return "", fmt.Errorf("invalid Git Artifact Package Path")
	}
	return "packages/" + packagePath + "/", nil
}

func (s *Storage) HydrateGitRepository(ctx context.Context, packagePath, destination string) (bool, error) {
	prefix, err := gitRepositoryPrefix(packagePath)
	if err != nil {
		return false, err
	}
	if err := os.RemoveAll(destination); err != nil {
		return false, err
	}
	found := false
	it := s.bucket.Objects(ctx, &gcs.Query{Prefix: prefix})
	for {
		attrs, err := it.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			return false, err
		}
		relative := strings.TrimPrefix(attrs.Name, prefix)
		if relative == "" || relative == attrs.Name || filepath.IsAbs(relative) || strings.HasPrefix(relative, "../") {
			continue
		}
		reader, err := s.bucket.Object(attrs.Name).NewReader(ctx)
		if err != nil {
			return false, err
		}
		target, err := pkgstorage.GitRepositoryTarget(destination, relative)
		if err != nil {
			_ = reader.Close()
			return false, err
		}
		if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
			_ = reader.Close()
			return false, err
		}
		file, err := os.OpenFile(target, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0o644)
		if err != nil {
			_ = reader.Close()
			return false, err
		}
		_, copyErr := io.Copy(file, reader)
		readCloseErr, fileCloseErr := reader.Close(), file.Close()
		if copyErr != nil {
			return false, copyErr
		}
		if readCloseErr != nil {
			return false, readCloseErr
		}
		if fileCloseErr != nil {
			return false, fileCloseErr
		}
		found = true
	}
	return found, nil
}

func (s *Storage) PublishGitRepository(ctx context.Context, packagePath, source string) error {
	prefix, err := gitRepositoryPrefix(packagePath)
	if err != nil {
		return err
	}
	type upload struct{ relative, filename string }
	var uploads []upload
	err = filepath.Walk(source, func(current string, info os.FileInfo, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if info.IsDir() {
			return nil
		}
		relative, err := filepath.Rel(source, current)
		if err != nil || relative == ".." || strings.HasPrefix(relative, ".."+string(filepath.Separator)) {
			return fmt.Errorf("Git Artifact repository path escapes source")
		}
		uploads = append(uploads, upload{filepath.ToSlash(relative), current})
		return nil
	})
	if err != nil {
		return err
	}
	sort.SliceStable(uploads, func(i, j int) bool {
		return !mutableGitFile(uploads[i].relative) && mutableGitFile(uploads[j].relative)
	})
	for _, item := range uploads {
		object := s.bucket.Object(prefix + item.relative)
		if contentAddressedGitFile(item.relative) {
			if attrs, attrsErr := object.Attrs(ctx); attrsErr == nil {
				info, statErr := os.Stat(item.filename)
				if statErr != nil {
					return statErr
				}
				if attrs.Size != info.Size() {
					return fmt.Errorf("immutable Git Artifact object %s has conflicting size", item.relative)
				}
				continue
			} else if attrsErr != gcs.ErrObjectNotExist {
				return attrsErr
			}
		}
		file, err := os.Open(item.filename)
		if err != nil {
			return err
		}
		writer := object.NewWriter(ctx)
		if mutableGitFile(item.relative) {
			writer.CacheControl = "no-cache"
		} else {
			writer.CacheControl = "public, max-age=31536000, immutable"
		}
		_, copyErr := io.Copy(writer, file)
		fileCloseErr, writerCloseErr := file.Close(), writer.Close()
		if copyErr != nil {
			return copyErr
		}
		if fileCloseErr != nil {
			return fileCloseErr
		}
		if writerCloseErr != nil {
			return writerCloseErr
		}
	}
	return nil
}

func mutableGitFile(relative string) bool {
	return relative == "HEAD" || relative == "info/refs" || relative == "objects/info/packs" || relative == "packed-refs" || strings.HasPrefix(relative, "refs/")
}

func contentAddressedGitFile(relative string) bool {
	return strings.HasPrefix(relative, "objects/pack/pack-") && (strings.HasSuffix(relative, ".pack") || strings.HasSuffix(relative, ".idx"))
}
