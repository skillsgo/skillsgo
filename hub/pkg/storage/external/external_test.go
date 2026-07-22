/*
 * [INPUT]: Depends on an in-memory backend, external client/server transport, compliance suite, and conflicting immutable uploads.
 * [OUTPUT]: Specifies bounded external transport plus idempotent and conflicting create-only publication.
 * [POS]: Serves as test coverage for the external package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package external

import (
	"bytes"
	"context"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	"github.com/skillsgo/skillsgo/hub/pkg/storage/compliance"
	"github.com/skillsgo/skillsgo/hub/pkg/storage/mem"
)

func TestExternal(t *testing.T) {
	strg, err := mem.NewStorage()
	if err != nil {
		t.Fatal(err)
	}
	handler := NewServer(strg)
	srv := httptest.NewServer(handler)
	defer srv.Close()
	externalStrg := NewClient(srv.URL, nil)
	clear := strg.(interface{ Clear() error }).Clear
	compliance.RunTests(t, externalStrg, clear)
}

func TestExternalServerRejectsConflictingImmutableSave(t *testing.T) {
	strg, err := mem.NewStorage()
	if err != nil {
		t.Fatal(err)
	}
	srv := httptest.NewServer(NewServer(strg))
	defer srv.Close()
	client := NewClient(srv.URL, nil)
	ctx := context.Background()
	if err := client.Save(ctx, "github.com/acme/skills", "v1.0.0", strings.NewReader("first"), nil, []byte(`{"Version":"v1.0.0"}`)); err != nil {
		t.Fatal(err)
	}
	if err := client.Save(ctx, "github.com/acme/skills", "v1.0.0", strings.NewReader("first"), nil, []byte(`{"Version":"v1.0.0"}`)); err != nil {
		t.Fatalf("identical publication must be idempotent: %v", err)
	}
	err = client.Save(ctx, "github.com/acme/skills", "v1.0.0", bytes.NewReader([]byte("second")), nil, []byte(`{"Version":"v1.0.0"}`))
	if err == nil || !strings.Contains(err.Error(), "409") {
		t.Fatalf("conflicting publication returned %v", err)
	}
}

func TestExternalClientReportsServerAuthoritativeCreation(t *testing.T) {
	strg, err := mem.NewStorage()
	if err != nil {
		t.Fatal(err)
	}
	srv := httptest.NewServer(NewServer(strg))
	defer srv.Close()
	client := NewClient(srv.URL, nil)
	immutable, ok := client.(storage.ImmutableSaver)
	if !ok {
		t.Fatal("external client must expose PutIfAbsent")
	}
	created, err := immutable.PutIfAbsent(context.Background(), "github.com/acme/skills", "v1.0.0", strings.NewReader("first"), nil, []byte(`{"Version":"v1.0.0"}`))
	if err != nil || !created {
		t.Fatalf("first publication: created=%v err=%v", created, err)
	}
	created, err = immutable.PutIfAbsent(context.Background(), "github.com/acme/skills", "v1.0.0", strings.NewReader("first"), nil, []byte(`{"Version":"v1.0.0"}`))
	if err != nil || created {
		t.Fatalf("identical retry: created=%v err=%v", created, err)
	}
}
