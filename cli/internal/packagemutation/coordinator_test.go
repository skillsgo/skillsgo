/*
 * [INPUT]: Uses the Package mutation interface with deterministic transaction doubles and invalid durable-write roots.
 * [OUTPUT]: Specifies ordered multi-transaction commit, preview discard, reverse rollback, durable-write failure handling, and post-publication cleanup errors.
 * [POS]: Serves as state-machine contract coverage for the commit coordinator shared by Package commands.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package packagemutation

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
	transaction := &recordedTransaction{name: "packages", log: &log, commitErr: fmt.Errorf("commit failed"), rollbackErr: fmt.Errorf("restore failed")}
	err := (Plan{Transactions: []Transaction{transaction}}).Commit()
	if err == nil || !containsAll(err.Error(), "commit failed", "rollback Package transaction 0", "restore failed") {
		t.Fatalf("rollback diagnostics lost: %v", err)
	}
}

func TestDiscardRollsBackPreparedTransactionsWithoutCommit(t *testing.T) {
	log := []string{}
	first := &recordedTransaction{name: "first", log: &log}
	second := &recordedTransaction{name: "second", log: &log}
	requireNoError(t, (Plan{Transactions: []Transaction{first, second}}).Discard())
	want := []string{"rollback:second", "rollback:first"}
	if fmt.Sprint(log) != fmt.Sprint(want) {
		t.Fatalf("unexpected discard order: got %v want %v", log, want)
	}
}

func requireNoError(t *testing.T, err error) {
	t.Helper()
	if err != nil {
		t.Fatal(err)
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
	transaction := &recordedTransaction{name: "packages", log: &log}
	blockedRoot := filepath.Join(t.TempDir(), "not-a-directory")
	if err := os.WriteFile(blockedRoot, []byte("blocked"), 0o600); err != nil {
		t.Fatal(err)
	}
	state := &WorkspaceState{Root: blockedRoot, Manifest: project.WorkspaceManifest{Dependencies: map[string]project.PackageDependency{}}, Lock: project.DependencyLock{Dependencies: map[string]project.LockedPackage{}}}
	if err := (Plan{Transactions: []Transaction{transaction}, Workspace: state}).Commit(); err == nil {
		t.Fatal("Workspace publication failure accepted")
	}
	want := []string{"commit:packages", "rollback:packages"}
	if fmt.Sprint(log) != fmt.Sprint(want) {
		t.Fatalf("unexpected state order: got %v want %v", log, want)
	}
}

func TestFinalizeFailureDoesNotRollBackPublishedMutation(t *testing.T) {
	log := []string{}
	transaction := &recordedTransaction{name: "packages", log: &log, finalizeErr: fmt.Errorf("cleanup")}
	err := (Plan{Transactions: []Transaction{transaction}, Operation: "Package add"}).Commit()
	if err == nil || err.Error() != "Package add committed but transaction cleanup failed: cleanup" {
		t.Fatalf("unexpected finalize result: %v", err)
	}
	want := []string{"commit:packages", "finalize:packages"}
	if fmt.Sprint(log) != fmt.Sprint(want) {
		t.Fatalf("unexpected state order: got %v want %v", log, want)
	}
}
