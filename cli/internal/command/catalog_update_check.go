/*
 * [INPUT]: Depends on repeated App-supplied installed Skill identities and the Hub client's Catalog-only batch latest-version read.
 * [OUTPUT]: Provides the read-only `updates check` machine command with per-Library-entry current, available, or unsupported results.
 * [POS]: Serves as the batch update-availability boundary between the App's local inventory and the independently built Hub Catalog.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"encoding/json"
	"fmt"
	"strings"

	"github.com/skillsgo/skillsgo/cli/internal/hub"
	"github.com/skillsgo/skillsgo/cli/internal/source"
	"github.com/spf13/cobra"
)

type catalogUpdateCandidate struct {
	Key      string   `json:"key"`
	SkillID  string   `json:"skillId"`
	Versions []string `json:"versions"`
}

type catalogUpdateResult struct {
	Key           string   `json:"key"`
	SkillID       string   `json:"skillId"`
	Versions      []string `json:"versions"`
	LatestVersion string   `json:"latestVersion,omitempty"`
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
			if output != "json" {
				return fmt.Errorf("updates check requires --output json")
			}
			candidates, err := decodeCatalogUpdateCandidates(rawInstalled)
			if err != nil {
				return err
			}
			client, err := hub.New(hubURL, nil)
			if err != nil {
				return err
			}
			skillIDs := make([]string, 0, len(candidates))
			seenSkillIDs := map[string]bool{}
			for _, candidate := range candidates {
				if !seenSkillIDs[candidate.SkillID] {
					seenSkillIDs[candidate.SkillID] = true
					skillIDs = append(skillIDs, candidate.SkillID)
				}
			}
			latest, err := client.CatalogUpdates(cmd.Context(), skillIDs)
			if err != nil {
				return err
			}
			report := catalogUpdateReport{SchemaVersion: 1, Phase: "update-check", Items: make([]catalogUpdateResult, 0, len(candidates))}
			latestBySkillID := make(map[string]hub.CatalogUpdateItem, len(latest))
			for _, item := range latest {
				latestBySkillID[item.SkillID] = item
			}
			for _, candidate := range candidates {
				resolved := latestBySkillID[candidate.SkillID]
				item := catalogUpdateResult{Key: candidate.Key, SkillID: candidate.SkillID, Versions: candidate.Versions, LatestVersion: resolved.LatestVersion, Status: "unsupported"}
				if resolved.Status == "available" {
					item.Status = "current"
					for _, version := range candidate.Versions {
						if version != resolved.LatestVersion {
							item.Status = "update_available"
							break
						}
					}
				}
				report.Items = append(report.Items, item)
			}
			encoder := json.NewEncoder(cmd.OutOrStdout())
			encoder.SetIndent("", "  ")
			return encoder.Encode(report)
		},
	}
	check.Flags().StringArrayVar(&rawInstalled, "installed", nil, "installed Skill JSON; repeatable")
	check.Flags().StringVar(&hubURL, "hub", defaultHubURL(), "Hub origin")
	check.Flags().StringVar(&output, "output", "json", "machine output format")
	root.AddCommand(check)
	return root
}

func decodeCatalogUpdateCandidates(raw []string) ([]catalogUpdateCandidate, error) {
	if len(raw) == 0 || len(raw) > 1000 {
		return nil, fmt.Errorf("updates check requires 1 to 1000 installed Skills")
	}
	candidates := make([]catalogUpdateCandidate, 0, len(raw))
	seenKeys := map[string]bool{}
	for _, encoded := range raw {
		var candidate catalogUpdateCandidate
		if json.Unmarshal([]byte(encoded), &candidate) != nil || strings.TrimSpace(candidate.Key) == "" || source.ValidateSkillID(candidate.SkillID) != nil || len(candidate.Versions) == 0 || seenKeys[candidate.Key] {
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
