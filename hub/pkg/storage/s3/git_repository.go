/*
 * [INPUT]: Depends on one R2/S3 bucket, canonical Package Path, standard bare Git repository files, and AWS SDK object listing/read/write operations.
 * [OUTPUT]: Hydrates repositories, uploads only absent immutable Git objects, refreshes mutable discovery files, and reclaims stale repository objects.
 * [POS]: Serves as the R2/S3 replication adapter for Git Artifact Repository distribution.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package s3

import (
	"context"
	"fmt"
	"io"
	"mime"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	awss3 "github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/s3/types"
	"github.com/aws/smithy-go"
	huberrors "github.com/skillsgo/skillsgo/hub/pkg/errors"
	pkgstorage "github.com/skillsgo/skillsgo/hub/pkg/storage"
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
	paginator := awss3.NewListObjectsV2Paginator(s.s3API, &awss3.ListObjectsV2Input{Bucket: aws.String(s.bucket), Prefix: aws.String(prefix)})
	found := false
	for paginator.HasMorePages() {
		page, err := paginator.NextPage(ctx)
		if err != nil {
			return false, err
		}
		for _, item := range page.Contents {
			key := aws.ToString(item.Key)
			relative := strings.TrimPrefix(key, prefix)
			if relative == "" || relative == key || filepath.IsAbs(relative) || strings.HasPrefix(relative, "../") {
				continue
			}
			output, err := s.s3API.GetObject(ctx, &awss3.GetObjectInput{Bucket: aws.String(s.bucket), Key: aws.String(key)})
			if err != nil {
				return false, err
			}
			target, err := pkgstorage.GitRepositoryTarget(destination, relative)
			if err != nil {
				_ = output.Body.Close()
				return false, err
			}
			if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
				_ = output.Body.Close()
				return false, err
			}
			writer, err := os.OpenFile(target, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0o644)
			if err != nil {
				_ = output.Body.Close()
				return false, err
			}
			_, copyErr := io.Copy(writer, output.Body)
			closeBodyErr := output.Body.Close()
			closeFileErr := writer.Close()
			if copyErr != nil {
				return false, copyErr
			}
			if closeBodyErr != nil {
				return false, closeBodyErr
			}
			if closeFileErr != nil {
				return false, closeFileErr
			}
			found = true
		}
	}
	return found, nil
}

func (s *Storage) PublishGitRepository(ctx context.Context, packagePath, source string) error {
	prefix, err := gitRepositoryPrefix(packagePath)
	if err != nil {
		return err
	}
	type upload struct{ relative, filename string }
	uploads := make([]upload, 0)
	desired := make(map[string]bool)
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
		uploads = append(uploads, upload{relative: filepath.ToSlash(relative), filename: current})
		desired[prefix+filepath.ToSlash(relative)] = true
		return nil
	})
	if err != nil {
		return err
	}
	// Immutable object data becomes resident before mutable discovery files.
	sort.SliceStable(uploads, func(i, j int) bool {
		return !mutableGitFile(uploads[i].relative) && mutableGitFile(uploads[j].relative)
	})
	for _, item := range uploads {
		file, err := os.Open(item.filename)
		if err != nil {
			return err
		}
		info, err := file.Stat()
		if err != nil {
			_ = file.Close()
			return err
		}
		key := prefix + item.relative
		if contentAddressedGitFile(item.relative) {
			head, headErr := s.s3API.HeadObject(ctx, &awss3.HeadObjectInput{Bucket: aws.String(s.bucket), Key: aws.String(key)})
			if headErr == nil {
				_ = file.Close()
				if aws.ToInt64(head.ContentLength) != info.Size() {
					return fmt.Errorf("immutable Git Artifact object %s has conflicting size", item.relative)
				}
				continue
			}
			var apiErr smithy.APIError
			if !huberrors.AsErr(headErr, &apiErr) || (apiErr.ErrorCode() != "NotFound" && apiErr.ErrorCode() != "NoSuchKey") {
				_ = file.Close()
				return headErr
			}
		}
		contentType := mime.TypeByExtension(filepath.Ext(item.relative))
		if contentType == "" {
			contentType = "application/octet-stream"
		}
		cacheControl := "public, max-age=31536000, immutable"
		if mutableGitFile(item.relative) {
			cacheControl = "no-cache"
		}
		_, putErr := s.s3API.PutObject(ctx, &awss3.PutObjectInput{
			Bucket: aws.String(s.bucket), Key: aws.String(key), Body: file,
			ContentLength: aws.Int64(info.Size()), ContentType: aws.String(contentType), CacheControl: aws.String(cacheControl),
		})
		closeErr := file.Close()
		if putErr != nil {
			return putErr
		}
		if closeErr != nil {
			return closeErr
		}
		head, headErr := s.s3API.HeadObject(ctx, &awss3.HeadObjectInput{Bucket: aws.String(s.bucket), Key: aws.String(key)})
		if headErr != nil {
			return headErr
		}
		if aws.ToInt64(head.ContentLength) != info.Size() {
			return fmt.Errorf("verify uploaded Git Artifact object %s: size mismatch", item.relative)
		}
	}
	// The repository is a replaceable static generation. Once discovery files
	// point at the new pack set, remove superseded objects after a stale-CDN grace period.
	paginator := awss3.NewListObjectsV2Paginator(s.s3API, &awss3.ListObjectsV2Input{Bucket: aws.String(s.bucket), Prefix: aws.String(prefix)})
	stale := make([]types.ObjectIdentifier, 0)
	for paginator.HasMorePages() {
		page, listErr := paginator.NextPage(ctx)
		if listErr != nil {
			return listErr
		}
		for _, object := range page.Contents {
			key := aws.ToString(object.Key)
			if !desired[key] && object.LastModified != nil && object.LastModified.Before(time.Now().Add(-24*time.Hour)) {
				stale = append(stale, types.ObjectIdentifier{Key: aws.String(key)})
			}
		}
	}
	for len(stale) > 0 {
		batch := stale
		if len(batch) > 1000 {
			batch = batch[:1000]
		}
		if _, deleteErr := s.s3API.DeleteObjects(ctx, &awss3.DeleteObjectsInput{Bucket: aws.String(s.bucket), Delete: &types.Delete{Objects: batch, Quiet: aws.Bool(true)}}); deleteErr != nil {
			return deleteErr
		}
		stale = stale[len(batch):]
	}
	return nil
}

func mutableGitFile(relative string) bool {
	return relative == "HEAD" || relative == "info/refs" || relative == "objects/info/packs" || relative == "packed-refs" || strings.HasPrefix(relative, "refs/")
}

func contentAddressedGitFile(relative string) bool {
	return strings.HasPrefix(relative, "objects/pack/pack-") && (strings.HasSuffix(relative, ".pack") || strings.HasSuffix(relative, ".idx"))
}
