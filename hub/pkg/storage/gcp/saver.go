/*
 * [INPUT]: Depends on the gcp package imports and contracts declared in this file.
 * [OUTPUT]: Provides generation-preconditioned create-only GCS publication with byte-verified idempotency.
 * [POS]: Serves as maintained source in the gcp package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package gcp

import (
	"bytes"
	"context"
	"io"
	"time"

	"cloud.google.com/go/storage"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/observ"
	pkgstorage "github.com/skillsgo/skillsgo/hub/pkg/storage"
	googleapi "google.golang.org/api/googleapi"
)

// Save uploads the Skill's .zip and .info files for a given version.
// It expects a context, which can be provided using context.Background
// from the standard library until context has been threaded down the stack.
// see issue: https://github.com/skillsgo/skillsgo/hub/issues/174
//
// Uploaded files are publicly accessible in the storage bucket as per
// an ACL rule.
func (s *Storage) Save(ctx context.Context, module, version string, zip io.Reader, zipMD5, info []byte) error {
	const op errors.Op = "gcp.save"
	ctx, span := observ.StartSpan(ctx, op.String())
	defer span.End()
	_, err := s.PutIfAbsent(ctx, module, version, zip, zipMD5, info)
	if err != nil {
		return errors.E(op, err)
	}
	return nil
}

// SetStaleThreshold sets the threshold of how long we consider
// a lock metadata stale after.
func (s *Storage) SetStaleThreshold(threshold time.Duration) {
	s.staleThreshold = threshold
}

func (s *Storage) PutIfAbsent(ctx context.Context, module, version string, zip io.Reader, zipMD5, info []byte) (bool, error) {
	archive, err := pkgstorage.ReadImmutableArchive(zip)
	if err != nil {
		return false, err
	}
	if matches, exists, matchErr := pkgstorage.ExistingInfoMatches(ctx, s, module, version, info); matchErr != nil {
		return false, matchErr
	} else if exists && !matches {
		return false, pkgstorage.ImmutableConflict(module, version)
	}

	created := false
	zipPath := config.PackageVersionedName(module, version, "zip")
	if err = s.upload(ctx, zipPath, bytes.NewReader(archive), zipMD5); errors.Is(err, errors.KindAlreadyExists) {
		matches, _, matchErr := pkgstorage.ExistingZIPMatches(ctx, s, module, version, archive)
		if matchErr != nil {
			return false, matchErr
		}
		if !matches {
			return false, pkgstorage.ImmutableConflict(module, version)
		}
	} else if err != nil {
		return false, err
	} else {
		created = true
	}

	infoPath := config.PackageVersionedName(module, version, "info")
	if err = s.upload(ctx, infoPath, bytes.NewReader(info), nil); errors.Is(err, errors.KindAlreadyExists) {
		matches, _, matchErr := pkgstorage.ExistingInfoMatches(ctx, s, module, version, info)
		if matchErr != nil {
			return false, matchErr
		}
		if !matches {
			return false, pkgstorage.ImmutableConflict(module, version)
		}
	} else if err != nil {
		return false, err
	} else {
		created = true
	}
	return created, nil
}

func (s *Storage) upload(ctx context.Context, path string, stream io.Reader, md5 []byte) error {
	const op errors.Op = "gcp.upload"
	ctx, span := observ.StartSpan(ctx, op.String())
	defer span.End()
	cancelCtx, cancel := context.WithCancel(ctx)
	defer cancel()

	wc := s.bucket.Object(path).If(storage.Conditions{
		DoesNotExist: true,
	}).NewWriter(cancelCtx)

	if len(md5) > 0 {
		wc.MD5 = md5
	}

	// NOTE: content type is auto detected on GCP side and ACL defaults to public
	// Once we support private storage buckets this may need refactoring
	// unless there is a way to set the default perms in the project.
	if _, err := io.Copy(wc, stream); err != nil {
		// Purposely do not close it to avoid creating a partial file.
		return err
	}

	err := wc.Close()
	if err != nil {
		kind := errors.KindBadRequest
		apiErr := &googleapi.Error{}
		if errors.AsErr(err, &apiErr) && apiErr.Code == 412 {
			kind = errors.KindAlreadyExists
		}
		return errors.E(op, err, kind)
	}
	return nil
}
