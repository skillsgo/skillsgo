/*
 * [INPUT]: Depends on one storage Backend plus bounded immutable Info and ZIP byte streams.
 * [OUTPUT]: Provides backend-native or process-safe fallback PutIfAbsent semantics plus shared bounded byte-comparison primitives for native conditional writers.
 * [POS]: Serves as the immutable write membrane for Repository Publication across storage backends.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package storage

import (
	"bytes"
	"context"
	"fmt"
	"hash/fnv"
	"io"
	"sync"

	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
)

type ImmutableSaver interface {
	PutIfAbsent(ctx context.Context, module, version string, zip io.Reader, zipMD5, info []byte) (created bool, err error)
}

type immutableBackend struct {
	Backend
	locks [256]sync.Mutex
}

func WithImmutableWrites(backend Backend) Backend {
	if _, ok := backend.(*immutableBackend); ok {
		return backend
	}
	return &immutableBackend{Backend: backend}
}

func (backend *immutableBackend) Save(ctx context.Context, module, version string, zip io.Reader, zipMD5, info []byte) error {
	_, err := backend.PutIfAbsent(ctx, module, version, zip, zipMD5, info)
	return err
}

func (backend *immutableBackend) PutIfAbsent(ctx context.Context, module, version string, zip io.Reader, zipMD5, info []byte) (bool, error) {
	archive, err := ReadImmutableArchive(zip)
	if err != nil {
		return false, err
	}
	if native, ok := backend.Backend.(ImmutableSaver); ok {
		return native.PutIfAbsent(ctx, module, version, bytes.NewReader(archive), zipMD5, info)
	}
	lock := &backend.locks[immutableLockIndex(module, version)]
	lock.Lock()
	defer lock.Unlock()

	identical, exists, err := backend.identical(ctx, module, version, info, archive)
	if err != nil {
		return false, err
	}
	if exists {
		if identical {
			return false, nil
		}
		return false, ImmutableConflict(module, version)
	}
	if err := backend.Backend.Save(ctx, module, version, bytes.NewReader(archive), zipMD5, info); err != nil {
		return false, err
	}
	identical, exists, err = backend.identical(ctx, module, version, info, archive)
	if err != nil {
		return false, err
	}
	if !exists || !identical {
		return false, ImmutableConflict(module, version)
	}
	return true, nil
}

func (backend *immutableBackend) identical(ctx context.Context, module, version string, info, archive []byte) (identical, exists bool, err error) {
	infoMatches, infoExists, err := ExistingInfoMatches(ctx, backend.Backend, module, version, info)
	if err != nil || !infoExists {
		return false, infoExists, err
	}
	zipMatches, zipExists, err := ExistingZIPMatches(ctx, backend.Backend, module, version, archive)
	return infoMatches && zipMatches, infoExists || zipExists, err
}

func ReadImmutableArchive(reader io.Reader) ([]byte, error) {
	archive, err := io.ReadAll(io.LimitReader(reader, protocolartifact.MaxArchiveBytes+1))
	if err != nil {
		return nil, err
	}
	if len(archive) == 0 || len(archive) > protocolartifact.MaxArchiveBytes {
		return nil, fmt.Errorf("artifact archive size must be between 1 and %d bytes", protocolartifact.MaxArchiveBytes)
	}
	return archive, nil
}

func ExistingInfoMatches(ctx context.Context, getter Getter, module, version string, expected []byte) (matches, exists bool, err error) {
	actual, err := getter.Info(ctx, module, version)
	if errors.Is(err, errors.KindNotFound) {
		return false, false, nil
	}
	if err != nil {
		return false, false, err
	}
	return bytes.Equal(actual, expected), true, nil
}

func ExistingZIPMatches(ctx context.Context, getter Getter, module, version string, expected []byte) (matches, exists bool, err error) {
	actual, err := getter.Zip(ctx, module, version)
	if errors.Is(err, errors.KindNotFound) {
		return false, false, nil
	}
	if err != nil {
		return false, false, err
	}
	defer actual.Close()
	archive, err := ReadImmutableArchive(actual)
	if err != nil {
		return false, true, err
	}
	return bytes.Equal(archive, expected), true, nil
}

func immutableLockIndex(module, version string) uint32 {
	hash := fnv.New32a()
	_, _ = hash.Write([]byte(module))
	_, _ = hash.Write([]byte{0})
	_, _ = hash.Write([]byte(version))
	return hash.Sum32() % 256
}

func ImmutableConflict(module, version string) error {
	return errors.E("storage.PutIfAbsent", fmt.Sprintf("immutable artifact conflict for %s@%s", module, version), errors.S(module), errors.V(version), errors.KindAlreadyExists)
}
