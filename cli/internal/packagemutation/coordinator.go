/*
 * [INPUT]: Depends on prepared Package filesystem transactions plus caller-owned immutable-cache and Workspace-state publication operations.
 * [OUTPUT]: Provides one ordered Package mutation state machine with preview discard, commit-time reverse rollback, and post-commit cleanup.
 * [POS]: Serves as the deep transaction coordinator between command intent and Scope Package Store/project persistence adapters.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package packagemutation

import (
	"errors"
	"fmt"

	"github.com/skillsgo/skillsgo/cli/internal/infocache"
	"github.com/skillsgo/skillsgo/cli/internal/project"
)

type Transaction interface {
	Commit() error
	Rollback() error
	Finalize() error
}

type Plan struct {
	Transactions  []Transaction
	ImmutableInfo []ImmutableInfo
	Workspace     *WorkspaceState
	Operation     string
}

type ImmutableInfo struct {
	Cache       infocache.Cache
	PackagePath string
	Version     string
	Kind        string
	Bytes       []byte
}

type WorkspaceState struct {
	Root     string
	Manifest project.WorkspaceManifest
	Lock     project.DependencyLock
}

// Discard releases every prepared filesystem transaction without publishing
// immutable metadata or Workspace state. Preview executors use it after they
// have inspected the exact Plan that an apply executor would commit.
func (plan Plan) Discard() error {
	failures := make([]error, 0)
	for index := len(plan.Transactions) - 1; index >= 0; index-- {
		if err := plan.Transactions[index].Rollback(); err != nil {
			failures = append(failures, fmt.Errorf("discard Package transaction %d: %w", index, err))
		}
	}
	return errors.Join(failures...)
}

func (plan Plan) Commit() error {
	rollback := func(cause error) error {
		failures := []error{cause}
		for index := len(plan.Transactions) - 1; index >= 0; index-- {
			if err := plan.Transactions[index].Rollback(); err != nil {
				failures = append(failures, fmt.Errorf("rollback Package transaction %d: %w", index, err))
			}
		}
		return errors.Join(failures...)
	}
	for _, transaction := range plan.Transactions {
		if err := transaction.Commit(); err != nil {
			return rollback(err)
		}
	}
	for _, info := range plan.ImmutableInfo {
		if err := info.Cache.Put(info.PackagePath, info.Version, info.Kind, info.Bytes); err != nil {
			return rollback(fmt.Errorf("persist immutable Package Info: %w", err))
		}
	}
	if plan.Workspace != nil {
		if err := project.WriteWorkspaceState(plan.Workspace.Root, plan.Workspace.Manifest, plan.Workspace.Lock); err != nil {
			return rollback(fmt.Errorf("persist Workspace Package state: %w", err))
		}
	}
	for _, transaction := range plan.Transactions {
		if err := transaction.Finalize(); err != nil {
			operation := plan.Operation
			if operation == "" {
				operation = "Package mutation"
			}
			return fmt.Errorf("%s committed but transaction cleanup failed: %w", operation, err)
		}
	}
	return nil
}
