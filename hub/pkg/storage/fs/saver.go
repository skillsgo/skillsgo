/*
 * [INPUT]: Depends on canonical artifact paths, bounded immutable Info and ZIP bytes, and atomic filesystem directory rename.
 * [OUTPUT]: Provides cross-process create-only artifact-pair persistence with identical-write idempotency and conflict rejection.
 * [POS]: Serves as the native immutable write implementation for disk and in-memory filesystem storage backends.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package fs

import (
	"bytes"
	"context"
	"fmt"
	"hash/fnv"
	"io"
	"path/filepath"
	"sync"
	"time"

	"github.com/gofrs/flock"
	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/observ"
	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
	"github.com/spf13/afero"
)

var artifactWriteLocks [256]sync.Mutex

func (s *storageImpl) Save(ctx context.Context, module, version string, zip io.Reader, zipMD5, info []byte) error {
	_, err := s.PutIfAbsent(ctx, module, version, zip, zipMD5, info)
	return err
}

func (s *storageImpl) PutIfAbsent(ctx context.Context, module, version string, zip io.Reader, _ []byte, info []byte) (bool, error) {
	const op errors.Op = "fs.Save"
	_, span := observ.StartSpan(ctx, op.String())
	defer span.End()
	dir := s.versionLocation(module, version)
	archive, err := io.ReadAll(io.LimitReader(zip, protocolartifact.MaxArchiveBytes+1))
	if err != nil {
		return false, errors.E(op, err, errors.S(module), errors.V(version))
	}
	if len(archive) == 0 || len(archive) > protocolartifact.MaxArchiveBytes {
		return false, errors.E(op, fmt.Errorf("artifact archive size must be between 1 and %d bytes", protocolartifact.MaxArchiveBytes), errors.S(module), errors.V(version), errors.KindBadRequest)
	}
	if err := s.filesystem.MkdirAll(filepath.Dir(dir), 0o777); err != nil {
		return false, errors.E(op, err, errors.S(module), errors.V(version))
	}
	release, err := s.acquireArtifactWriteLock(ctx, dir)
	if err != nil {
		return false, errors.E(op, err, errors.S(module), errors.V(version))
	}
	defer release()
	if identical, exists := s.artifactPairState(dir, version, info, archive); exists {
		if identical {
			return false, nil
		}
		return false, errors.E(op, fmt.Sprintf("immutable artifact conflict for %s@%s", module, version), errors.S(module), errors.V(version), errors.KindAlreadyExists)
	}
	temporary, err := afero.TempDir(s.filesystem, filepath.Dir(dir), ".skillsgo-artifact-")
	if err != nil {
		return false, errors.E(op, err, errors.S(module), errors.V(version))
	}
	defer s.filesystem.RemoveAll(temporary)
	if err := afero.WriteFile(s.filesystem, filepath.Join(temporary, "source.zip"), archive, 0o666); err != nil {
		return false, errors.E(op, err, errors.S(module), errors.V(version))
	}
	if err := afero.WriteFile(s.filesystem, filepath.Join(temporary, version+".info"), info, 0o666); err != nil {
		return false, errors.E(op, err, errors.S(module), errors.V(version))
	}
	if err := s.filesystem.Rename(temporary, dir); err == nil {
		return true, nil
	}
	if identical, _ := s.artifactPairState(dir, version, info, archive); identical {
		return false, nil
	}
	return false, errors.E(op, fmt.Sprintf("immutable artifact conflict for %s@%s", module, version), errors.S(module), errors.V(version), errors.KindAlreadyExists)
}

func (s *storageImpl) artifactPairState(dir, version string, info, archive []byte) (identical, exists bool) {
	existingInfo, infoErr := afero.ReadFile(s.filesystem, filepath.Join(dir, version+".info"))
	existingArchive, archiveErr := afero.ReadFile(s.filesystem, filepath.Join(dir, "source.zip"))
	if infoErr != nil && archiveErr != nil {
		return false, false
	}
	return infoErr == nil && archiveErr == nil && bytes.Equal(existingInfo, info) && bytes.Equal(existingArchive, archive), true
}

func (s *storageImpl) acquireArtifactWriteLock(ctx context.Context, artifactDir string) (func(), error) {
	hash := fnv.New32a()
	_, _ = hash.Write([]byte(artifactDir))
	processLock := &artifactWriteLocks[hash.Sum32()%uint32(len(artifactWriteLocks))]
	processLock.Lock()
	if _, ok := s.filesystem.(*afero.OsFs); !ok {
		return processLock.Unlock, nil
	}
	lock := flock.New(artifactDir+".publish.lock", flock.SetPermissions(0o600))
	lockContext := ctx
	cancel := func() {}
	if _, hasDeadline := ctx.Deadline(); !hasDeadline {
		lockContext, cancel = context.WithTimeout(ctx, 30*time.Second)
	}
	locked, err := lock.TryLockContext(lockContext, 10*time.Millisecond)
	cancel()
	if err != nil || !locked {
		processLock.Unlock()
		if err != nil {
			return nil, err
		}
		return nil, fmt.Errorf("timed out waiting for immutable artifact lock")
	}
	return func() {
		_ = lock.Unlock()
		processLock.Unlock()
	}, nil
}
