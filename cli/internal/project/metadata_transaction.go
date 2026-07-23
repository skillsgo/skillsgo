/*
 * [INPUT]: Depends on the workspace metadata file lock, exact YAML/Lock paths, filesystem snapshots, and atomic rename.
 * [OUTPUT]: Provides crash-recoverable paired workspace metadata publication with rollback and no Receipt storage.
 * [POS]: Serves as the private transaction primitive beneath skillsgo.yaml and skillsgo-lock.yaml.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package project

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"

	"gopkg.in/yaml.v3"
)

const metadataTransactionSchemaVersion = 1

type metadataFileSnapshot struct {
	Path    string `yaml:"path"`
	Data    []byte `yaml:"data,omitempty"`
	Existed bool   `yaml:"existed"`
}

type metadataTransaction struct {
	SchemaVersion int                    `yaml:"schemaVersion"`
	Snapshots     []metadataFileSnapshot `yaml:"snapshots"`
}

func workspaceMetadataLockPath(root string) string {
	return filepath.Join(root, ".skillsgo.metadata.lock")
}

func metadataTransactionPath(root string) string {
	return filepath.Join(root, ".skillsgo.metadata-transaction.yaml")
}

func withWorkspaceMetadataLock(root string, operation func() error) error {
	if err := os.MkdirAll(root, 0o700); err != nil {
		return err
	}
	unlock, err := acquireFileLock(workspaceMetadataLockPath(root))
	if err != nil {
		return err
	}
	defer unlock()
	if err := recoverMetadataTransaction(root); err != nil {
		return err
	}
	return operation()
}

func snapshotMetadataFile(path string) (metadataFileSnapshot, error) {
	data, err := os.ReadFile(path)
	if os.IsNotExist(err) {
		return metadataFileSnapshot{Path: path}, nil
	}
	if err != nil {
		return metadataFileSnapshot{}, err
	}
	return metadataFileSnapshot{Path: path, Data: data, Existed: true}, nil
}

func beginMetadataTransaction(root string, snapshots []metadataFileSnapshot) (string, error) {
	journal := metadataTransactionPath(root)
	if _, err := os.Stat(journal); err == nil {
		return "", fmt.Errorf("unfinished workspace metadata transaction requires recovery")
	} else if !os.IsNotExist(err) {
		return "", err
	}
	data, err := yaml.Marshal(metadataTransaction{SchemaVersion: metadataTransactionSchemaVersion, Snapshots: snapshots})
	if err != nil {
		return "", err
	}
	if err := writeProjectFileAtomic(journal, data, 0o600); err != nil {
		return "", err
	}
	return journal, nil
}

func abortMetadataTransaction(journal string, snapshots []metadataFileSnapshot, cause error) error {
	if restoreErr := restoreMetadataFiles(snapshots); restoreErr != nil {
		return errors.Join(cause, fmt.Errorf("workspace metadata rollback failed: %w", restoreErr))
	}
	if err := os.Remove(journal); err != nil && !os.IsNotExist(err) {
		return errors.Join(cause, fmt.Errorf("remove workspace metadata transaction journal: %w", err))
	}
	return cause
}

func recoverMetadataTransaction(root string) error {
	journal := metadataTransactionPath(root)
	data, err := os.ReadFile(journal)
	if os.IsNotExist(err) {
		return nil
	}
	if err != nil {
		return err
	}
	var transaction metadataTransaction
	if yaml.Unmarshal(data, &transaction) != nil || transaction.SchemaVersion != metadataTransactionSchemaVersion || len(transaction.Snapshots) != 2 {
		return fmt.Errorf("invalid workspace metadata transaction journal")
	}
	for _, snapshot := range transaction.Snapshots {
		if !validMetadataSnapshotPath(root, snapshot.Path) {
			return fmt.Errorf("workspace metadata transaction contains unsafe path %q", snapshot.Path)
		}
	}
	if err := restoreMetadataFiles(transaction.Snapshots); err != nil {
		return fmt.Errorf("recover workspace metadata transaction: %w", err)
	}
	return os.Remove(journal)
}

func validMetadataSnapshotPath(root, candidate string) bool {
	candidate = filepath.Clean(candidate)
	return candidate == filepath.Join(root, WorkspaceManifestName) || candidate == filepath.Join(root, DependencyLockName)
}

func restoreMetadataFiles(snapshots []metadataFileSnapshot) error {
	var result error
	for _, snapshot := range snapshots {
		if snapshot.Existed {
			result = errors.Join(result, writeProjectFileAtomic(snapshot.Path, snapshot.Data, 0o600))
		} else if err := os.Remove(snapshot.Path); err != nil && !os.IsNotExist(err) {
			result = errors.Join(result, err)
		}
	}
	return result
}

func writeProjectFileAtomic(path string, data []byte, mode os.FileMode) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	temporary, err := os.CreateTemp(filepath.Dir(path), ".skillsgo-project-")
	if err != nil {
		return err
	}
	temporaryPath := temporary.Name()
	defer os.Remove(temporaryPath)
	if err := temporary.Chmod(mode); err != nil {
		_ = temporary.Close()
		return err
	}
	if _, err := temporary.Write(data); err != nil {
		_ = temporary.Close()
		return err
	}
	if err := temporary.Sync(); err != nil {
		_ = temporary.Close()
		return err
	}
	if err := temporary.Close(); err != nil {
		return err
	}
	return os.Rename(temporaryPath, path)
}
