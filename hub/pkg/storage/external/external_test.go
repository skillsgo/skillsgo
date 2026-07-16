/*
 * [INPUT]: Depends on the external package imports and contracts declared in this file.
 * [OUTPUT]: Specifies the external package behavior covered by external_test.go.
 * [POS]: Serves as test coverage for the external package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package external

import (
	"net/http/httptest"
	"testing"

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
