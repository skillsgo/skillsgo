/*
 * [INPUT]: Uses the Repository mutation interface with deterministic transaction doubles and invalid durable-write roots.
 * [OUTPUT]: Specifies ordered multi-transaction commit, reverse rollback, durable-write failure handling, and post-publication cleanup errors.
 * [POS]: Serves as state-machine contract coverage for the commit coordinator shared by Repository commands.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package repositorymutation

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/project"
)

type recordedTransaction struct {
	name        string
	log         *[]string
	commitErr   error
	rollbackErr error
	finalizeErr error
}

func (transaction *recordedTransaction) Commit() error {
	*transaction.log = append(*transaction.log, "commit:"+transaction.name)
	return transaction.commitErr
}

func (transaction *recordedTransaction) Rollback() error {
	*transaction.log = append(*transaction.log, "rollback:"+transaction.name)
	return transaction.rollbackErr
}

func TestRollbackFailureIsReportedWithOriginalFailure(t *testing.T) {
	log := []string{}
	transaction := &recordedTransaction{name: "vendor", log: &log, commitErr: fmt.Errorf("commit failed"), rollbackErr: fmt.Errorf("restore failed")}
	err := (Plan{Transactions: []Transaction{transaction}}).Commit()
	if err == nil || !containsAll(err.Error(), "commit failed", "rollback Repository transaction 0", "restore failed") {
		t.Fatalf("rollback diagnostics lost: %v", err)
	}
}

func containsAll(value string, expected ...string) bool {
	for _, item := range expected {
		if !strings.Contains(value, item) {
			return false
		}
	}
	return true
}

func (transaction *recordedTransaction) Finalize() error {
	*transaction.log = append(*transaction.log, "finalize:"+transaction.name)
	return transaction.finalizeErr
}

func TestCommitFailureRollsBackEveryPreparedTransactionInReverseOrder(t *testing.T) {
	log := []string{}
	first := &recordedTransaction{name: "first", log: &log}
	second := &recordedTransaction{name: "second", log: &log, commitErr: fmt.Errorf("stop")}
	if err := (Plan{Transactions: []Transaction{first, second}}).Commit(); err == nil {
		t.Fatal("commit failure accepted")
	}
	want := []string{"commit:first", "commit:second", "rollback:second", "rollback:first"}
	if fmt.Sprint(log) != fmt.Sprint(want) {
		t.Fatalf("unexpected state order: got %v want %v", log, want)
	}
}

func TestWorkspacePublicationFailureRollsBackCommittedFilesystem(t *testing.T) {
	log := []string{}
	transaction := &recordedTransaction{name: "vendor", log: &log}
	blockedRoot := filepath.Join(t.TempDir(), "not-a-directory")
	if err := os.WriteFile(blockedRoot, []byte("blocked"), 0o600); err != nil {
		t.Fatal(err)
	}
	state := &WorkspaceState{Root: blockedRoot, Manifest: project.WorkspaceManifest{Dependencies: map[string]project.RepositoryDependency{}}, Lock: project.DependencyLock{Dependencies: map[string]project.LockedRepository{}}}
	if err := (Plan{Transactions: []Transaction{transaction}, Workspace: state}).Commit(); err == nil {
		t.Fatal("Workspace publication failure accepted")
	}
	want := []string{"commit:vendor", "rollback:vendor"}
	if fmt.Sprint(log) != fmt.Sprint(want) {
		t.Fatalf("unexpected state order: got %v want %v", log, want)
	}
}

func TestFinalizeFailureDoesNotRollBackPublishedMutation(t *testing.T) {
	log := []string{}
	transaction := &recordedTransaction{name: "vendor", log: &log, finalizeErr: fmt.Errorf("cleanup")}
	err := (Plan{Transactions: []Transaction{transaction}, Operation: "Repository add"}).Commit()
	if err == nil || err.Error() != "Repository add committed but transaction cleanup failed: cleanup" {
		t.Fatalf("unexpected finalize result: %v", err)
	}
	want := []string{"commit:vendor", "finalize:vendor"}
	if fmt.Sprint(log) != fmt.Sprint(want) {
		t.Fatalf("unexpected state order: got %v want %v", log, want)
	}
}
