/*
 * [INPUT]: Depends on prepared Repository filesystem transactions plus caller-owned immutable-cache and Workspace-state publication operations.
 * [OUTPUT]: Provides one ordered Repository mutation commit state machine with reverse rollback and post-commit cleanup.
 * [POS]: Serves as the deep transaction coordinator between command intent and Scope Vendor/project persistence adapters.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package repositorymutation

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
	Cache        infocache.Cache
	RepositoryID string
	Version      string
	Kind         string
	Bytes        []byte
}

type WorkspaceState struct {
	Root     string
	Manifest project.WorkspaceManifest
	Lock     project.DependencyLock
}

func (plan Plan) Commit() error {
	rollback := func(cause error) error {
		failures := []error{cause}
		for index := len(plan.Transactions) - 1; index >= 0; index-- {
			if err := plan.Transactions[index].Rollback(); err != nil {
				failures = append(failures, fmt.Errorf("rollback Repository transaction %d: %w", index, err))
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
		if err := info.Cache.Put(info.RepositoryID, info.Version, info.Kind, info.Bytes); err != nil {
			return rollback(fmt.Errorf("persist immutable Repository Info: %w", err))
		}
	}
	if plan.Workspace != nil {
		if err := project.WriteWorkspaceState(plan.Workspace.Root, plan.Workspace.Manifest, plan.Workspace.Lock); err != nil {
			return rollback(fmt.Errorf("persist Workspace Repository state: %w", err))
		}
	}
	for _, transaction := range plan.Transactions {
		if err := transaction.Finalize(); err != nil {
			operation := plan.Operation
			if operation == "" {
				operation = "Repository mutation"
			}
			return fmt.Errorf("%s committed but transaction cleanup failed: %w", operation, err)
		}
	}
	return nil
}
