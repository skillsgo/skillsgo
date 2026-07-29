/*
 * [INPUT]: Depends on Azure Blob objects, canonical Package Paths, and local bare Git repository files.
 * [OUTPUT]: Hydrates and publishes complete static Git Artifact repositories with immutable-object reuse.
 * [POS]: Serves as the Azure Blob implementation of storage.GitRepositoryStore.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package azureblob

import (
	"context"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/Azure/azure-storage-blob-go/azblob"
	pkgstorage "github.com/skillsgo/skillsgo/hub/pkg/storage"
)

func gitRepositoryPrefix(packagePath string) (string, error) {
	if packagePath == "" || strings.HasPrefix(packagePath, "/") || strings.Contains(packagePath, "\\") || strings.Contains(packagePath, "../") {
		return "", fmt.Errorf("invalid Git Artifact Package Path")
	}
	return "git/" + packagePath + ".git/", nil
}

func (s *Storage) HydrateGitRepository(ctx context.Context, packagePath, destination string) (bool, error) {
	prefix, err := gitRepositoryPrefix(packagePath)
	if err != nil {
		return false, err
	}
	if err := os.RemoveAll(destination); err != nil {
		return false, err
	}
	objects, err := s.client.ListBlobs(ctx, prefix)
	if err != nil {
		return false, err
	}
	found := false
	for _, object := range objects {
		relative := strings.TrimPrefix(object, prefix)
		if relative == "" || relative == object || filepath.IsAbs(relative) || strings.HasPrefix(relative, "../") {
			continue
		}
		reader, err := s.client.ReadBlob(ctx, object)
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
		file, err := os.Open(item.filename)
		if err != nil {
			return err
		}
		location := prefix + item.relative
		if contentAddressedGitFile(item.relative) {
			created, createErr := s.client.CreateWithContext(ctx, location, "application/octet-stream", file)
			closeErr := file.Close()
			if createErr != nil {
				return createErr
			}
			if closeErr != nil {
				return closeErr
			}
			if !created {
				existing, err := s.client.ReadBlob(ctx, location)
				if err != nil {
					return err
				}
				defer existing.Close()
				info, err := os.Stat(item.filename)
				if err != nil {
					return err
				}
				if existing.Size() != info.Size() {
					return fmt.Errorf("immutable Git Artifact object %s has conflicting size", item.relative)
				}
			}
			continue
		}
		blobURL := s.client.containerURL.NewBlockBlobURL(location)
		_, uploadErr := azblob.UploadStreamToBlockBlob(ctx, file, blobURL, azblob.UploadStreamToBlockBlobOptions{BufferSize: 1 << 20, MaxBuffers: 3, BlobHTTPHeaders: azblob.BlobHTTPHeaders{CacheControl: "no-cache"}})
		closeErr := file.Close()
		if uploadErr != nil {
			return uploadErr
		}
		if closeErr != nil {
			return closeErr
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
