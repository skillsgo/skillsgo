/*
 * [INPUT]: Depends on explicit or locally inferred Library scopes, the Agent Catalog, the Hub origin, and the unified inventory reconciliation domain with read-through metadata restoration.
 * [OUTPUT]: Provides `skillsgo verify` health verification and `skillsgo why` direct declaration/target explanations in human or JSON form.
 * [POS]: Serves as the CLI inspection adapter over inventory truth without mutating declarations or Projections; explicit verify may rebuild disposable dependency caches.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"strings"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
	"github.com/skillsgo/skillsgo/cli/internal/hub"
	appi18n "github.com/skillsgo/skillsgo/cli/internal/i18n"
	"github.com/skillsgo/skillsgo/cli/internal/inventory"
	"github.com/skillsgo/skillsgo/cli/internal/packageprovider"
	"github.com/skillsgo/skillsgo/cli/internal/project"
	"github.com/skillsgo/skillsgo/cli/internal/terminalui"
	"github.com/spf13/cobra"
)

type verificationReport struct {
	Healthy bool              `json:"healthy"`
	Entries []verificationRow `json:"entries"`
}

type verificationRow struct {
	PackagePath string           `json:"packagePath,omitempty"`
	Name        string           `json:"name"`
	Health      inventory.Health `json:"health"`
	Targets     int              `json:"targets"`
}

type whyReport struct {
	Query   string            `json:"query"`
	Entries []inventory.Entry `json:"entries"`
}

func newVerifyCommand(catalog *agent.Catalog) *cobra.Command {
	var includeGlobal bool
	var projects []string
	var output string
	var hubURL string
	cmd := &cobra.Command{
		Use:     "verify",
		Short:   appi18n.T("verify.short"),
		Args:    cobra.NoArgs,
		Example: "  skillsgo verify\n  skillsgo verify --global\n  skillsgo verify --project ./my-project --output json",
		RunE: func(cmd *cobra.Command, _ []string) error {
			user, roots, err := resolveInspectionLocations(includeGlobal, projects)
			if err != nil {
				return err
			}
			client, err := hub.New(hubURL, nil)
			if err != nil {
				return err
			}
			provider := packageprovider.Default("", client)
			reconciled, err := inventory.Build(inventory.Options{IncludeGlobal: user, Projects: roots, Catalog: catalog, Context: cmd.Context(), Packages: &provider, VerifyContent: true})
			if err != nil {
				return err
			}
			report := verificationReport{Healthy: true, Entries: make([]verificationRow, 0, len(reconciled.Entries))}
			for _, entry := range reconciled.Entries {
				report.Entries = append(report.Entries, verificationRow{PackagePath: entry.PackagePath, Name: entry.Name, Health: entry.Health, Targets: len(entry.Targets)})
				if entry.Health != inventory.HealthHealthy {
					report.Healthy = false
				}
			}
			if err := writeVerificationReport(cmd, output, report); err != nil {
				return err
			}
			if !report.Healthy {
				return errors.New(appi18n.T("verify.error.unhealthy"))
			}
			return nil
		},
	}
	addInspectionFlags(cmd, &includeGlobal, &projects, &output)
	cmd.Flags().StringVar(&hubURL, "hub", defaultHubURL(), appi18n.T("flag.hub"))
	return cmd
}

func newWhyCommand(catalog *agent.Catalog) *cobra.Command {
	var includeGlobal bool
	var projects []string
	var output string
	var hubURL string
	cmd := &cobra.Command{
		Use:     "why <skill-name>",
		Short:   appi18n.T("why.short"),
		Args:    cobra.ExactArgs(1),
		Example: "  skillsgo why setup-matt-pocock-skills\n  skillsgo why setup-matt-pocock-skills --global\n  skillsgo why setup-matt-pocock-skills --project ./my-project --output json",
		RunE: func(cmd *cobra.Command, args []string) error {
			user, roots, err := resolveInspectionLocations(includeGlobal, projects)
			if err != nil {
				return err
			}
			client, err := hub.New(hubURL, nil)
			if err != nil {
				return err
			}
			provider := packageprovider.Default("", client)
			reconciled, err := inventory.Build(inventory.Options{IncludeGlobal: user, Projects: roots, Catalog: catalog, Context: cmd.Context(), Packages: &provider})
			if err != nil {
				return err
			}
			query := strings.TrimSpace(args[0])
			report := whyReport{Query: query, Entries: make([]inventory.Entry, 0)}
			for _, entry := range reconciled.Entries {
				if entry.Name == query {
					report.Entries = append(report.Entries, entry)
				}
			}
			if len(report.Entries) == 0 {
				return fmt.Errorf(appi18n.T("why.error.missing"), query)
			}
			switch output {
			case "json":
				return json.NewEncoder(cmd.OutOrStdout()).Encode(report)
			case "human":
				rows := make([]terminalui.Row, 0)
				for _, entry := range report.Entries {
					for _, target := range entry.Targets {
						scope := string(target.Scope)
						if target.ProjectRoot != "" {
							scope += ":" + target.ProjectRoot
						}
						rows = append(rows, terminalui.Row{State: "•", Primary: entry.Name, Secondary: target.Version, Meta: []string{entry.PackagePath, scope, target.Agent, target.Path}})
					}
				}
				ui, err := humanUI(cmd)
				if err != nil {
					return err
				}
				return ui.Render(terminalui.Document{Title: appi18n.F("why.title", query), Sections: []terminalui.Section{{Rows: rows}}})
			default:
				return fmt.Errorf(appi18n.T("list.error.output"), output)
			}
		},
	}
	addInspectionFlags(cmd, &includeGlobal, &projects, &output)
	cmd.Flags().StringVar(&hubURL, "hub", defaultHubURL(), appi18n.T("flag.hub"))
	return cmd
}

func addInspectionFlags(cmd *cobra.Command, includeGlobal *bool, projects *[]string, output *string) {
	cmd.Flags().BoolVarP(includeGlobal, "global", "g", false, appi18n.T("list.flag.global"))
	cmd.Flags().StringArrayVar(projects, "project", nil, appi18n.T("list.flag.project"))
	cmd.Flags().StringVar(output, "output", "human", appi18n.T("flag.output"))
}

func resolveInspectionLocations(includeGlobal bool, projects []string) (bool, []string, error) {
	if includeGlobal || len(projects) > 0 {
		return includeGlobal, projects, nil
	}
	cwd, err := os.Getwd()
	if err != nil {
		return false, nil, err
	}
	if root, findErr := project.FindWorkspaceRoot(cwd); findErr == nil {
		return false, []string{root}, nil
	}
	return true, nil, nil
}

func writeVerificationReport(cmd *cobra.Command, output string, report verificationReport) error {
	switch output {
	case "json":
		return json.NewEncoder(cmd.OutOrStdout()).Encode(report)
	case "human":
		rows := make([]terminalui.Row, 0, len(report.Entries))
		for _, entry := range report.Entries {
			state := "✓"
			if entry.Health != inventory.HealthHealthy {
				state = "!"
			}
			rows = append(rows, terminalui.Row{State: state, Primary: entry.Name, Secondary: string(entry.Health), Meta: []string{entry.PackagePath, fmt.Sprintf("%d", entry.Targets)}})
		}
		ui, err := humanUI(cmd)
		if err != nil {
			return err
		}
		return ui.Render(terminalui.Document{Title: appi18n.T("verify.title"), Sections: []terminalui.Section{{Rows: rows}}})
	default:
		return fmt.Errorf(appi18n.T("list.error.output"), output)
	}
}
