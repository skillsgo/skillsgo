/*
 * [INPUT]: Depends on the postgres package imports and contracts declared in this file.
 * [OUTPUT]: Specifies the postgres package behavior covered by postgres_test.go.
 * [POS]: Serves as test coverage for the postgres package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package postgres

import (
	"os"
	"testing"

	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/skillsgo/skillsgo/hub/pkg/index/compliance"
)

func TestPostgres(t *testing.T) {
	if os.Getenv("TEST_INDEX_POSTGRES") != "true" {
		t.SkipNow()
	}
	cfg := getTestConfig(t)
	i, err := New(cfg)
	if err != nil {
		t.Fatal(err)
	}
	compliance.RunTests(t, i, i.(*indexer).clear)
}

func (i *indexer) clear() error {
	_, err := i.db.Exec(`DELETE FROM indexes`)
	return err
}

func getTestConfig(t *testing.T) *config.Postgres {
	t.Helper()
	cfg, err := config.Load("")
	if err != nil {
		t.Fatal(err)
	}
	return cfg.Index.Postgres
}
