/*
 * [INPUT]: Depends on explicit Workspace roots, the CLI-owned general user configuration, user home resolution, Cobra, and stable JSON output.
 * [OUTPUT]: Provides `project add`, `project remove`, and `project list` commands for Managed Workspace Scopes.
 * [POS]: Serves as the command adapter over the projects section of durable user configuration shared by terminal and App callers.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/skillsgo/skillsgo/cli/internal/config"
	appi18n "github.com/skillsgo/skillsgo/cli/internal/i18n"
	"github.com/spf13/cobra"
)

type projectRegistryReport struct {
	SchemaVersion int              `json:"schemaVersion"`
	Phase         string           `json:"phase"`
	Projects      []config.Project `json:"projects"`
}

func newProjectCommand() *cobra.Command {
	root := &cobra.Command{Use: "project", Short: appi18n.Pick("Manage explicit Workspace Scopes", "管理显式工作区范围"), Example: "  skillsgo project add ./my-project\n  skillsgo project list", RunE: func(cmd *cobra.Command, args []string) error {
		if len(args) > 0 {
			return fmt.Errorf("unknown command %q for %q", args[0], cmd.CommandPath())
		}
		return cmd.Help()
	}}
	root.AddCommand(newProjectAddCommand(), newProjectRemoveCommand(), newProjectListCommand())
	return root
}

func userConfigStore() (config.Store, error) {
	home, err := os.UserHomeDir()
	return config.Store{Home: home}, err
}

func newProjectAddCommand() *cobra.Command {
	var output string
	cmd := &cobra.Command{Use: "add <path>", Short: appi18n.Pick("Register a Workspace Scope", "注册工作区范围"), Example: "  skillsgo project add ./my-project", Args: cobra.ExactArgs(1), RunE: func(cmd *cobra.Command, args []string) error {
		if err := validateProductOutput(output); err != nil {
			return err
		}
		registry, err := userConfigStore()
		if err != nil {
			return err
		}
		project, err := registry.AddProject(args[0])
		if err != nil {
			return err
		}
		if output == "json" {
			return json.NewEncoder(cmd.OutOrStdout()).Encode(projectRegistryReport{SchemaVersion: 1, Phase: "project-add", Projects: []config.Project{project}})
		}
		_, err = fmt.Fprintf(cmd.OutOrStdout(), "Added %s (%s).\n", project.Name, project.Root)
		return err
	}}
	cmd.Flags().StringVar(&output, "output", "human", "output format: human or json")
	return cmd
}

func newProjectRemoveCommand() *cobra.Command {
	var output string
	cmd := &cobra.Command{Use: "remove <path>", Short: appi18n.Pick("Unregister a Workspace Scope", "取消注册工作区范围"), Example: "  skillsgo project remove ./my-project", Args: cobra.ExactArgs(1), RunE: func(cmd *cobra.Command, args []string) error {
		if err := validateProductOutput(output); err != nil {
			return err
		}
		registry, err := userConfigStore()
		if err != nil {
			return err
		}
		removed, err := registry.RemoveProject(args[0])
		if err != nil {
			return err
		}
		if !removed {
			return fmt.Errorf("Managed Workspace not found")
		}
		if output == "json" {
			return json.NewEncoder(cmd.OutOrStdout()).Encode(projectRegistryReport{SchemaVersion: 1, Phase: "project-remove", Projects: []config.Project{}})
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
		registry, err := userConfigStore()
		if err != nil {
			return err
		}
		projects, err := registry.ListProjects()
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
