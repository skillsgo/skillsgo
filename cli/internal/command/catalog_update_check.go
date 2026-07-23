/*
 * [INPUT]: Depends on repeated App-supplied Repository ID plus Skill name coordinates and the Hub client's Repository-fresh batch head/release read.
 * [OUTPUT]: Provides the read-only `updates check` machine command with independent head and release status per Library entry.
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
	protocolskillmanifest "github.com/skillsgo/skillsgo/protocol/skillmanifest"
	"github.com/spf13/cobra"
)

type catalogUpdateCandidate struct {
	Key          string   `json:"key"`
	RepositoryID string   `json:"repositoryId"`
	Name         string   `json:"name"`
	Versions     []string `json:"versions"`
}

type catalogUpdateResult struct {
	Key            string   `json:"key"`
	RepositoryID   string   `json:"repositoryId"`
	Name           string   `json:"name"`
	Versions       []string `json:"versions"`
	HeadVersion    string   `json:"headVersion,omitempty"`
	ReleaseVersion string   `json:"releaseVersion,omitempty"`
	HeadStatus     string   `json:"headStatus,omitempty"`
	ReleaseStatus  string   `json:"releaseStatus,omitempty"`
	Status         string   `json:"status"`
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
			coordinates := make([]hub.SkillCoordinate, 0, len(candidates))
			seenCoordinates := map[string]bool{}
			for _, candidate := range candidates {
				key := candidate.RepositoryID + "\x00" + candidate.Name
				if !seenCoordinates[key] {
					seenCoordinates[key] = true
					coordinates = append(coordinates, hub.SkillCoordinate{RepositoryID: candidate.RepositoryID, Name: candidate.Name})
				}
			}
			resolvedItems, err := client.CatalogUpdates(cmd.Context(), coordinates)
			if err != nil {
				return err
			}
			report := catalogUpdateReport{SchemaVersion: 1, Phase: "update-check", Items: make([]catalogUpdateResult, 0, len(candidates))}
			resolvedByCoordinate := make(map[string]hub.CatalogUpdateItem, len(resolvedItems))
			for _, item := range resolvedItems {
				resolvedByCoordinate[item.RepositoryID+"\x00"+item.Name] = item
			}
			for _, candidate := range candidates {
				resolved := resolvedByCoordinate[candidate.RepositoryID+"\x00"+candidate.Name]
				item := catalogUpdateResult{
					Key: candidate.Key, RepositoryID: candidate.RepositoryID, Name: candidate.Name, Versions: candidate.Versions,
					HeadVersion: resolved.HeadVersion, ReleaseVersion: resolved.ReleaseVersion, Status: "unsupported",
				}
				if resolved.Status == "available" {
					item.HeadStatus = catalogCandidateStatus(candidate.Versions, resolved.HeadVersion)
					item.ReleaseStatus = catalogCandidateStatus(candidate.Versions, resolved.ReleaseVersion)
					item.Status = "current"
					if item.HeadStatus == "update_available" || item.ReleaseStatus == "update_available" {
						item.Status = "update_available"
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
		if json.Unmarshal([]byte(encoded), &candidate) != nil || strings.TrimSpace(candidate.Key) == "" || source.ValidateRepositoryID(candidate.RepositoryID) != nil || !protocolskillmanifest.ValidName(candidate.Name) || len(candidate.Versions) == 0 || seenKeys[candidate.Key] {
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
