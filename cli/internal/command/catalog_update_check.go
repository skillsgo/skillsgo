/*
 * [INPUT]: Depends on repeated App-supplied Module Path plus Skill name coordinates and the Hub client's Module-fresh latest read.
 * [OUTPUT]: Provides the read-only `updates check` command with Human-default and explicit JSON status per Library entry.
 * [POS]: Serves as the batch update-availability boundary for terminal users and the App's local inventory.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"encoding/json"
	"fmt"
	"strings"

	"github.com/skillsgo/skillsgo/cli/internal/hub"
	"github.com/skillsgo/skillsgo/cli/internal/source"
	protocolskillmanifest "github.com/skillsgo/skillsgo/protocol/skillmanifest"
	"github.com/spf13/cobra"
)

type catalogUpdateCandidate struct {
	Key        string   `json:"key"`
	ModulePath string   `json:"modulePath"`
	Name       string   `json:"name"`
	Versions   []string `json:"versions"`
}

type catalogUpdateResult struct {
	Key           string   `json:"key"`
	ModulePath    string   `json:"modulePath"`
	Name          string   `json:"name"`
	Versions      []string `json:"versions"`
	LatestVersion string   `json:"latestVersion,omitempty"`
	LatestStatus  string   `json:"latestStatus,omitempty"`
	Status        string   `json:"status"`
}

type catalogUpdateReport struct {
	SchemaVersion int                   `json:"schemaVersion"`
	Phase         string                `json:"phase"`
	Items         []catalogUpdateResult `json:"items"`
}

func newUpdatesCommand() *cobra.Command {
	root := &cobra.Command{Use: "updates", Short: "Inspect available Skill updates"}
	var hubURL, output string
	var rawInstalled []string
	check := &cobra.Command{
		Use:  "check",
		Args: cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			if err := validateProductOutput(output); err != nil { return err }
			candidates, err := decodeCatalogUpdateCandidates(rawInstalled)
			if err != nil {
				return err
			}
			client, err := hub.New(hubURL, nil)
			if err != nil {
				return err
			}
			coordinates := make([]hub.SkillCoordinate, 0, len(candidates))
			seenCoordinates := map[string]bool{}
			for _, candidate := range candidates {
				key := candidate.ModulePath + "\x00" + candidate.Name
				if !seenCoordinates[key] {
					seenCoordinates[key] = true
					coordinates = append(coordinates, hub.SkillCoordinate{ModulePath: candidate.ModulePath, Name: candidate.Name})
				}
			}
			resolvedItems, err := client.CatalogUpdates(cmd.Context(), coordinates)
			if err != nil {
				return err
			}
			report := catalogUpdateReport{SchemaVersion: 1, Phase: "update-check", Items: make([]catalogUpdateResult, 0, len(candidates))}
			resolvedByCoordinate := make(map[string]hub.CatalogUpdateItem, len(resolvedItems))
			for _, item := range resolvedItems {
				resolvedByCoordinate[item.ModulePath+"\x00"+item.Name] = item
			}
			for _, candidate := range candidates {
				resolved := resolvedByCoordinate[candidate.ModulePath+"\x00"+candidate.Name]
				item := catalogUpdateResult{
					Key: candidate.Key, ModulePath: candidate.ModulePath, Name: candidate.Name, Versions: candidate.Versions,
					LatestVersion: resolved.LatestVersion, Status: "unsupported",
				}
				if resolved.Status == "available" {
					item.LatestStatus = catalogCandidateStatus(candidate.Versions, resolved.LatestVersion)
					item.Status = "current"
					if item.LatestStatus == "update_available" {
						item.Status = "update_available"
					}
				}
				report.Items = append(report.Items, item)
			}
			if output == "json" {
				encoder := json.NewEncoder(cmd.OutOrStdout())
				encoder.SetIndent("", "  ")
				return encoder.Encode(report)
			}
			for _, item := range report.Items {
				latest := item.LatestVersion
				if latest == "" { latest = "unavailable" }
				if _, err := fmt.Fprintf(cmd.OutOrStdout(), "%s  %s  latest: %s\n", item.Name, item.Status, latest); err != nil { return err }
			}
			return nil
		},
	}
	check.Flags().StringArrayVar(&rawInstalled, "installed", nil, "installed Skill JSON; repeatable")
	check.Flags().StringVar(&hubURL, "hub", defaultHubURL(), "Hub origin")
	check.Flags().StringVar(&output, "output", "human", "output format: human or json")
	root.AddCommand(check)
	return root
}

func catalogCandidateStatus(installed []string, candidate string) string {
	if candidate == "" {
		return "unavailable"
	}
	for _, version := range installed {
		if version != candidate {
			return "update_available"
		}
	}
	return "current"
}

func decodeCatalogUpdateCandidates(raw []string) ([]catalogUpdateCandidate, error) {
	if len(raw) == 0 || len(raw) > 1000 {
		return nil, fmt.Errorf("updates check requires 1 to 1000 installed Skills")
	}
	candidates := make([]catalogUpdateCandidate, 0, len(raw))
	seenKeys := map[string]bool{}
	for _, encoded := range raw {
		var candidate catalogUpdateCandidate
		if json.Unmarshal([]byte(encoded), &candidate) != nil || strings.TrimSpace(candidate.Key) == "" || source.ValidateModulePath(candidate.ModulePath) != nil || !protocolskillmanifest.ValidName(candidate.Name) || len(candidate.Versions) == 0 || seenKeys[candidate.Key] {
			return nil, fmt.Errorf("invalid installed Skill update candidate")
		}
		seenKeys[candidate.Key] = true
		seenVersions := map[string]bool{}
		for _, version := range candidate.Versions {
			if strings.TrimSpace(version) == "" || seenVersions[version] {
				return nil, fmt.Errorf("invalid installed Skill versions")
			}
			seenVersions[version] = true
		}
		candidates = append(candidates, candidate)
	}
	return candidates, nil
}
