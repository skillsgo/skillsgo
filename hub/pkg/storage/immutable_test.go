/*
 * [INPUT]: Uses the memory Backend with repeated and conflicting immutable artifact writes.
 * [OUTPUT]: Specifies created/idempotent/conflict outcomes and preservation of the first authoritative bytes.
 * [POS]: Serves as contract coverage for the storage immutable write membrane.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package storage_test

import (
	"bytes"
	"testing"

	huberrors "github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	"github.com/skillsgo/skillsgo/hub/pkg/storage/mem"
)

func TestImmutableBackendPutIfAbsent(t *testing.T) {
	raw, err := mem.NewStorage()
	if err != nil {
		t.Fatal(err)
	}
	backend := storage.WithImmutableWrites(raw)
	saver := backend.(storage.ImmutableSaver)
	created, err := saver.PutIfAbsent(t.Context(), "github.com/acme/skills", "v1.0.0", bytes.NewReader([]byte("zip-one")), nil, []byte("info-one"))
	if err != nil || !created {
		t.Fatalf("first write: created=%v err=%v", created, err)
	}
	created, err = saver.PutIfAbsent(t.Context(), "github.com/acme/skills", "v1.0.0", bytes.NewReader([]byte("zip-one")), nil, []byte("info-one"))
	if err != nil || created {
		t.Fatalf("idempotent write: created=%v err=%v", created, err)
	}
	created, err = saver.PutIfAbsent(t.Context(), "github.com/acme/skills", "v1.0.0", bytes.NewReader([]byte("zip-two")), nil, []byte("info-two"))
	if err == nil || created || huberrors.Kind(err) != huberrors.KindAlreadyExists {
		t.Fatalf("conflicting write: created=%v err=%v", created, err)
	}
	info, err := backend.Info(t.Context(), "github.com/acme/skills", "v1.0.0")
	if err != nil || string(info) != "info-one" {
		t.Fatalf("first authority was not preserved: info=%q err=%v", info, err)
	}
}
