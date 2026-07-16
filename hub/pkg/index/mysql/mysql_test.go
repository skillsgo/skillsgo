/*
 * [INPUT]: Depends on the mysql package imports and contracts declared in this file.
 * [OUTPUT]: Specifies the mysql package behavior covered by mysql_test.go.
 * [POS]: Serves as test coverage for the mysql package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package mysql

import (
	"os"
	"testing"

	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/skillsgo/skillsgo/hub/pkg/index/compliance"
)

func TestMySQL(t *testing.T) {
	if os.Getenv("TEST_INDEX_MYSQL") != "true" {
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

func getTestConfig(t *testing.T) *config.MySQL {
	t.Helper()
	cfg, err := config.Load("")
	if err != nil {
		t.Fatal(err)
	}
	return cfg.Index.MySQL
}
