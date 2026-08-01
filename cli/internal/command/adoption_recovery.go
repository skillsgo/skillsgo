/*
 * [INPUT]: Depends on durable adoption manifests in the SkillsGo recovery vault, the ordinary managed-removal transaction, Agent catalog state, and Hub-backed Package metadata.
 * [OUTPUT]: Provides `skillsgo recovery list`, `skillsgo recovery restore`, and `skillsgo recovery delete` machine commands for reviewing and safely reverting adopted Skills.
 * [POS]: Serves as the user-facing recovery adapter around adoption's durable per-Skill records; it never mutates the filesystem outside CLI-owned transactions.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
	appi18n "github.com/skillsgo/skillsgo/cli/internal/i18n"
	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/spf13/cobra"
)

type adoptionRecoveryBackup struct {
	ID           string        `json:"id"`
	InventoryKey string        `json:"inventoryKey"`
	Name         string        `json:"name"`
	PackagePath  string        `json:"packagePath"`
	Version      string        `json:"version"`
	SkillPath    string        `json:"skillPath"`
	Scope        install.Scope `json:"scope"`
	ProjectRoot  string        `json:"projectRoot,omitempty"`
	Agents       []string      `json:"agents"`
	Targets      []string      `json:"targets"`
	CreatedAt    time.Time     `json:"createdAt"`
	ExpiresAt    time.Time     `json:"expiresAt"`
	Status       string        `json:"status"`
}

func newRecoveryCommand(catalog *agent.Catalog) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "recovery",
		Short: appi18n.Pick("Manage adoption backups", "管理托管备份"),
		Example: `  skillsgo recovery list --output json
  skillsgo recovery restore --backup-id 123-000 --yes --output json`,
		Args: cobra.NoArgs,
	}
	cmd.AddCommand(newRecoveryListCommand(), newRecoveryRestoreCommand(catalog), newRecoveryDeleteCommand())
	return cmd
}

func newRecoveryListCommand() *cobra.Command {
	var output string
	cmd := &cobra.Command{
		Use:     "list",
		Short:   appi18n.Pick("List adoption backups", "列出托管备份"),
		Example: "  skillsgo recovery list --output json",
		Args:    cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			if output != "json" {
				return fmt.Errorf("recovery list requires --output json")
			}
			backups, err := loadRecoveryBackups()
			if err != nil {
				return err
			}
			return json.NewEncoder(cmd.OutOrStdout()).Encode(struct {
				SchemaVersion int                      `json:"schemaVersion"`
				Backups       []adoptionRecoveryBackup `json:"backups"`
			}{SchemaVersion: 1, Backups: backups})
		},
	}
	cmd.Flags().StringVar(&output, "output", "json", "output format: json")
	return cmd
}

func newRecoveryRestoreCommand(catalog *agent.Catalog) *cobra.Command {
	var backupID, output, hubURL string
	var yes bool
	cmd := &cobra.Command{
		Use:     "restore",
		Short:   appi18n.Pick("Restore an adopted Skill", "恢复托管前的 Skill"),
		Example: "  skillsgo recovery restore --backup-id 123-000 --yes --output json",
		Args:    cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			if output != "json" {
				return fmt.Errorf("recovery restore requires --output json")
			}
			if strings.TrimSpace(backupID) == "" {
				return fmt.Errorf("recovery restore requires --backup-id")
			}
			if !yes {
				return fmt.Errorf("recovery restore requires --yes")
			}
			if err := restoreAdoptionBackup(cmd, catalog, backupID, hubURL); err != nil {
				return err
			}
			return json.NewEncoder(cmd.OutOrStdout()).Encode(struct {
				SchemaVersion int    `json:"schemaVersion"`
				Phase         string `json:"phase"`
				BackupID      string `json:"backupId"`
				Status        string `json:"status"`
			}{SchemaVersion: 1, Phase: "adoption-recovery-restore", BackupID: backupID, Status: "restored"})
		},
	}
	cmd.Flags().StringVar(&backupID, "backup-id", "", "adoption backup ID")
	cmd.Flags().StringVar(&output, "output", "json", "output format: json")
	cmd.Flags().StringVar(&hubURL, "hub", defaultHubURL(), "Hub origin")
	cmd.Flags().BoolVar(&yes, "yes", false, "confirm restoration")
	return cmd
}

func newRecoveryDeleteCommand() *cobra.Command {
	var backupID, output string
	var yes bool
	cmd := &cobra.Command{
		Use:     "delete",
		Short:   appi18n.Pick("Delete an adoption backup", "删除托管备份"),
		Example: "  skillsgo recovery delete --backup-id 123-000 --yes --output json",
		Args:    cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			if output != "json" {
				return fmt.Errorf("recovery delete requires --output json")
			}
			if strings.TrimSpace(backupID) == "" {
				return fmt.Errorf("recovery delete requires --backup-id")
			}
			if !yes {
				return fmt.Errorf("recovery delete requires --yes")
			}
			if err := deleteAdoptionBackup(backupID); err != nil {
				return err
			}
			return json.NewEncoder(cmd.OutOrStdout()).Encode(struct {
				SchemaVersion int    `json:"schemaVersion"`
				Phase         string `json:"phase"`
				BackupID      string `json:"backupId"`
				Status        string `json:"status"`
			}{SchemaVersion: 1, Phase: "adoption-recovery-delete", BackupID: backupID, Status: "deleted"})
		},
	}
	cmd.Flags().StringVar(&backupID, "backup-id", "", "adoption backup ID")
	cmd.Flags().StringVar(&output, "output", "json", "output format: json")
	cmd.Flags().BoolVar(&yes, "yes", false, "confirm deletion")
	return cmd
}

func recoveryRoot() (string, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".skillsgo", "recovery", "adopt"), nil
}

func loadRecoveryBackups() ([]adoptionRecoveryBackup, error) {
	root, err := recoveryRoot()
	if err != nil {
		return nil, err
	}
	directories, err := os.ReadDir(root)
	if os.IsNotExist(err) {
		return []adoptionRecoveryBackup{}, nil
	}
	if err != nil {
		return nil, err
	}
	backups := make([]adoptionRecoveryBackup, 0)
	now := time.Now().UTC()
	for _, directory := range directories {
		if !directory.IsDir() {
			continue
		}
		manifest, err := readAdoptionRecoveryManifest(filepath.Join(root, directory.Name()))
		if err != nil {
			return nil, err
		}
		if manifest.SchemaVersion != adoptionRecoverySchemaVersion {
			continue
		}
		if err := validateRecoveryManifestBackups(filepath.Join(root, directory.Name()), manifest); err != nil {
			return nil, err
		}
		if manifest.Status == "ready" && !manifest.ExpiresAt.IsZero() && now.After(manifest.ExpiresAt) {
			if err := os.RemoveAll(filepath.Join(root, directory.Name())); err != nil {
				return nil, err
			}
			continue
		}
		for _, item := range manifest.Items {
			if item.Status != "ready" && item.Status != "restore-failed" && item.Status != "restored" {
				continue
			}
			backups = append(backups, adoptionRecoveryBackup{
				ID: item.ID, InventoryKey: item.InventoryKey, Name: item.Name,
				PackagePath: item.PackagePath, Version: item.Version, SkillPath: item.SkillPath,
				Scope: item.Scope, ProjectRoot: item.ProjectRoot, Agents: append([]string(nil), item.Agents...),
				Targets: recoveryTargetPaths(item.Targets), CreatedAt: manifest.CreatedAt, ExpiresAt: manifest.ExpiresAt,
				Status: item.Status,
			})
		}
	}
	return backups, nil
}

func recoveryTargetPaths(targets []adoptionRecoveryTarget) []string {
	paths := make([]string, 0, len(targets))
	for _, target := range targets {
		paths = append(paths, target.Original)
	}
	return paths
}

func readAdoptionRecoveryManifest(root string) (adoptionRecoveryManifest, error) {
	contents, err := os.ReadFile(filepath.Join(root, "recovery.json"))
	if err != nil {
		return adoptionRecoveryManifest{}, err
	}
	var manifest adoptionRecoveryManifest
	if err := json.Unmarshal(contents, &manifest); err != nil {
		return adoptionRecoveryManifest{}, fmt.Errorf("invalid adoption recovery manifest: %s", root)
	}
	return manifest, nil
}

func validateRecoveryManifestBackups(root string, manifest adoptionRecoveryManifest) error {
	for _, item := range manifest.Items {
		for _, target := range item.Targets {
			relative, err := filepath.Rel(root, target.Backup)
			if err != nil || relative == ".." || strings.HasPrefix(relative, ".."+string(filepath.Separator)) || filepath.IsAbs(relative) {
				return fmt.Errorf("adoption recovery backup escapes its vault: %s", target.Backup)
			}
		}
	}
	return nil
}

func findAdoptionRecoveryBackup(backupID string) (string, adoptionRecoveryManifest, int, error) {
	if strings.ContainsAny(backupID, `/\\`) || strings.TrimSpace(backupID) != backupID {
		return "", adoptionRecoveryManifest{}, -1, fmt.Errorf("invalid adoption backup ID")
	}
	backups, err := loadRecoveryBackups()
	if err != nil {
		return "", adoptionRecoveryManifest{}, -1, err
	}
	for _, backup := range backups {
		if backup.ID != backupID {
			continue
		}
		root, rootErr := recoveryRoot()
		if rootErr != nil {
			return "", adoptionRecoveryManifest{}, -1, rootErr
		}
		directories, readErr := os.ReadDir(root)
		if readErr != nil {
			return "", adoptionRecoveryManifest{}, -1, readErr
		}
		for _, directory := range directories {
			if !directory.IsDir() {
				continue
			}
			manifestRoot := filepath.Join(root, directory.Name())
			manifest, manifestErr := readAdoptionRecoveryManifest(manifestRoot)
			if manifestErr != nil {
				return "", adoptionRecoveryManifest{}, -1, manifestErr
			}
			for index, item := range manifest.Items {
				if item.ID == backupID {
					return manifestRoot, manifest, index, nil
				}
			}
		}
	}
	return "", adoptionRecoveryManifest{}, -1, fmt.Errorf("adoption backup %q was not found", backupID)
}

func restoreAdoptionBackup(cmd *cobra.Command, catalog *agent.Catalog, backupID, hubURL string) error {
	root, manifest, index, err := findAdoptionRecoveryBackup(backupID)
	if err != nil {
		return err
	}
	item := manifest.Items[index]
	if err := validateRecoveryManifestBackups(root, manifest); err != nil {
		return err
	}
	if item.Status != "ready" && item.Status != "restore-failed" {
		return fmt.Errorf("adoption backup %q is already %s", backupID, item.Status)
	}
	if !manifest.ExpiresAt.IsZero() && time.Now().UTC().After(manifest.ExpiresAt) {
		return fmt.Errorf("adoption backup %q has expired", backupID)
	}
	if len(item.Targets) == 0 {
		return fmt.Errorf("adoption backup %q has no recoverable targets", backupID)
	}
	for _, target := range item.Targets {
		if _, err := os.Lstat(target.Backup); err != nil {
			return fmt.Errorf("adoption backup %q is incomplete: %w", backupID, err)
		}
	}
	removeCommand := &cobra.Command{}
	removeCommand.SetContext(cmd.Context())
	removeCommand.SetOut(io.Discard)
	removeCommand.SetErr(io.Discard)
	removeCommand.Flags().String("output", "json", "")
	globalScope := item.Scope == install.ScopeGlobal
	handled, err := tryRemoveVersionSkillInPackage(removeCommand, catalog, item.SkillPath, item.PackagePath, globalScope, item.ProjectRoot, hubURL)
	if err != nil {
		return fmt.Errorf("remove managed Skill before restore: %w", err)
	}
	if !handled {
		return fmt.Errorf("managed Skill %q is no longer declared", item.Name)
	}
	item.Status = "restoring"
	manifest.Items[index] = item
	if err := persistAdoptionRecoveryManifest(root, manifest); err != nil {
		return err
	}
	staged := make([]stagedExternal, 0, len(item.Targets))
	for _, target := range item.Targets {
		staged = append(staged, stagedExternal{original: target.Original, backup: target.Backup})
	}
	if err := restoreStaged(staged, false); err != nil {
		item.Status = "restore-failed"
		manifest.Items[index] = item
		_ = persistAdoptionRecoveryManifest(root, manifest)
		return fmt.Errorf("restore original Skill: %w", err)
	}
	restoredAt := time.Now().UTC()
	item.Status = "restored"
	item.RestoredAt = &restoredAt
	manifest.Items[index] = item
	return persistAdoptionRecoveryManifest(root, manifest)
}

func deleteAdoptionBackup(backupID string) error {
	root, manifest, index, err := findAdoptionRecoveryBackup(backupID)
	if err != nil {
		return err
	}
	item := manifest.Items[index]
	for _, target := range item.Targets {
		if err := os.RemoveAll(target.Backup); err != nil && !os.IsNotExist(err) {
			return err
		}
	}
	manifest.Items = append(manifest.Items[:index], manifest.Items[index+1:]...)
	if len(manifest.Items) == 0 {
		return os.RemoveAll(root)
	}
	return persistAdoptionRecoveryManifest(root, manifest)
}
