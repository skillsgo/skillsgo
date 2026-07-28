/*
 * [INPUT]: Depends on explicit Workspace roots, the CLI-owned Managed Scope registry, user home resolution, Cobra, and stable JSON output.
 * [OUTPUT]: Provides `project add`, `project move`, `project remove`, and `project list` commands for Managed Workspace Scopes.
 * [POS]: Serves as the command adapter over durable Managed Scope ownership shared by terminal and App callers.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"encoding/json"
	"fmt"
	"os"

	appi18n "github.com/skillsgo/skillsgo/cli/internal/i18n"
	"github.com/skillsgo/skillsgo/cli/internal/projectregistry"
	"github.com/spf13/cobra"
)

type projectRegistryReport struct {
	SchemaVersion int                       `json:"schemaVersion"`
	Phase         string                    `json:"phase"`
	Projects      []projectregistry.Project `json:"projects"`
}

func newProjectCommand() *cobra.Command {
	root := &cobra.Command{Use: "project", Short: appi18n.Pick("Manage explicit Workspace Scopes", "管理显式工作区范围"), Example: "  skillsgo project add ./my-project\n  skillsgo project list"}
	root.AddCommand(newProjectAddCommand(), newProjectMoveCommand(), newProjectRemoveCommand(), newProjectListCommand())
	return root
}

func newProjectMoveCommand() *cobra.Command {
	var output string
	cmd := &cobra.Command{Use: "move <id> <path>", Short: appi18n.Pick("Relocate a Workspace Scope registration", "迁移工作区范围注册"), Example: "  skillsgo project move <id> ./moved-project", Args: cobra.ExactArgs(2), RunE: func(cmd *cobra.Command, args []string) error {
		if err := validateProductOutput(output); err != nil {
			return err
		}
		registry, err := managedScopeRegistry()
		if err != nil {
			return err
		}
		project, err := registry.Move(args[0], args[1])
		if err != nil {
			return err
		}
		if output == "json" {
			return json.NewEncoder(cmd.OutOrStdout()).Encode(projectRegistryReport{SchemaVersion: 1, Phase: "project-move", Projects: []projectregistry.Project{project}})
		}
		_, err = fmt.Fprintf(cmd.OutOrStdout(), "Moved %s (%s).\n", project.Name, project.Root)
		return err
	}}
	cmd.Flags().StringVar(&output, "output", "human", "output format: human or json")
	return cmd
}

func managedScopeRegistry() (projectregistry.Registry, error) {
	home, err := os.UserHomeDir()
	return projectregistry.Registry{Home: home}, err
}

func newProjectAddCommand() *cobra.Command {
	var output string
	cmd := &cobra.Command{Use: "add <path>", Short: appi18n.Pick("Register a Workspace Scope", "注册工作区范围"), Example: "  skillsgo project add ./my-project", Args: cobra.ExactArgs(1), RunE: func(cmd *cobra.Command, args []string) error {
		if err := validateProductOutput(output); err != nil {
			return err
		}
		registry, err := managedScopeRegistry()
		if err != nil {
			return err
		}
		project, err := registry.Add(args[0])
		if err != nil {
			return err
		}
		if output == "json" {
			return json.NewEncoder(cmd.OutOrStdout()).Encode(projectRegistryReport{SchemaVersion: 1, Phase: "project-add", Projects: []projectregistry.Project{project}})
		}
		_, err = fmt.Fprintf(cmd.OutOrStdout(), "Added %s (%s).\n", project.Name, project.Root)
		return err
	}}
	cmd.Flags().StringVar(&output, "output", "human", "output format: human or json")
	return cmd
}

func newProjectRemoveCommand() *cobra.Command {
	var output string
	cmd := &cobra.Command{Use: "remove <id-or-path>", Short: appi18n.Pick("Unregister a Workspace Scope", "取消注册工作区范围"), Example: "  skillsgo project remove ./my-project", Args: cobra.ExactArgs(1), RunE: func(cmd *cobra.Command, args []string) error {
		if err := validateProductOutput(output); err != nil {
			return err
		}
		registry, err := managedScopeRegistry()
		if err != nil {
			return err
		}
		removed, err := registry.Remove(args[0])
		if err != nil {
			return err
		}
		if !removed {
			return fmt.Errorf("Managed Workspace not found")
		}
		if output == "json" {
			return json.NewEncoder(cmd.OutOrStdout()).Encode(projectRegistryReport{SchemaVersion: 1, Phase: "project-remove", Projects: []projectregistry.Project{}})
		}
		_, err = fmt.Fprintln(cmd.OutOrStdout(), "Removed Managed Workspace registration.")
		return err
	}}
	cmd.Flags().StringVar(&output, "output", "human", "output format: human or json")
	return cmd
}

func newProjectListCommand() *cobra.Command {
	var output string
	cmd := &cobra.Command{Use: "list", Short: appi18n.Pick("List Managed Workspace Scopes", "列出托管工作区范围"), Example: "  skillsgo project list --output json", Args: cobra.NoArgs, RunE: func(cmd *cobra.Command, _ []string) error {
		if err := validateProductOutput(output); err != nil {
			return err
		}
		registry, err := managedScopeRegistry()
		if err != nil {
			return err
		}
		projects, err := registry.List()
		if err != nil {
			return err
		}
		if output == "json" {
			return json.NewEncoder(cmd.OutOrStdout()).Encode(projectRegistryReport{SchemaVersion: 1, Phase: "project-list", Projects: projects})
		}
		for _, project := range projects {
			if _, err := fmt.Fprintf(cmd.OutOrStdout(), "%s  %s\n", project.Name, project.Root); err != nil {
				return err
			}
		}
		return nil
	}}
	cmd.Flags().StringVar(&output, "output", "human", "output format: human or json")
	return cmd
}
