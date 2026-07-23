/*
 * [INPUT]: Depends on the source coordinate parser, the public Hub Repository Info client, Cobra output selection, and terminal writers.
 * [OUTPUT]: Provides the read-only `skillsgo info <source>` command with direct Repository or Skill Info JSON.
 * [POS]: Serves as the explicit-source discovery Adapter used by terminal users and the App without mutating local CLI state.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/skillsgo/skillsgo/cli/internal/hub"
	appi18n "github.com/skillsgo/skillsgo/cli/internal/i18n"
	"github.com/skillsgo/skillsgo/cli/internal/source"
	"github.com/spf13/cobra"
)

type skillInfoView struct {
	hub.Info
	ImageURL       *string  `json:"ImageURL,omitempty"`
	Stars          int64    `json:"Stars"`
	TrustLevel     string   `json:"TrustLevel"`
	RiskAssessment hub.Risk `json:"RiskAssessment"`
}

type repositoryInfoView struct {
	SchemaVersion int             `json:"SchemaVersion"`
	Kind          string          `json:"Kind"`
	ID            string          `json:"ID"`
	Version       string          `json:"Version"`
	Time          time.Time       `json:"Time"`
	Ref           string          `json:"Ref"`
	CommitSHA     string          `json:"CommitSHA"`
	Description   string          `json:"Description"`
	Skills        []skillInfoView `json:"Skills"`
}

func productSkillInfo(ctx context.Context, client *hub.Client, info hub.Info) (skillInfoView, string, error) {
	metadata, err := client.SkillProduct(ctx, info.RepositoryID, info.Name)
	if err != nil {
		return skillInfoView{}, "", err
	}
	risk := metadata.RiskAssessment.Level
	if risk == "" {
		risk = info.Risk
	}
	return skillInfoView{
		Info: info, ImageURL: metadata.ImageURL,
		Stars: metadata.Stars, TrustLevel: metadata.TrustLevel, RiskAssessment: risk,
	}, metadata.RepositoryDescription, nil
}

func newInfoCommand() *cobra.Command {
	var hubURL, output, skillName string
	cmd := &cobra.Command{
		Use:   "info <source>",
		Short: appi18n.T("info.short"),
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			if output != "human" && output != "json" {
				return fmt.Errorf("%s", appi18n.T("info.error.output"))
			}
			reference, err := source.Parse(args[0])
			if err != nil {
				return err
			}
			repositoryID := reference.RepositoryID
			client, err := hub.New(hubURL, nil)
			if err != nil {
				return err
			}
			if skillName != "" {
				resource, resolveErr := client.Repository(cmd.Context(), repositoryID, reference.Version)
				if resolveErr != nil {
					return resolveErr
				}
				var info hub.Info
				for _, member := range resource.Members {
					if member.Info.Name == skillName {
						info = member.Info
						break
					}
				}
				if info.Name == "" {
					return fmt.Errorf("Repository %s@%s does not contain Skill named %s", repositoryID, resource.Info.Version, skillName)
				}
				view, _, productErr := productSkillInfo(cmd.Context(), client, info)
				if productErr != nil {
					return productErr
				}
				if output == "json" {
					encoder := json.NewEncoder(cmd.OutOrStdout())
					encoder.SetIndent("", "  ")
					return encoder.Encode(view)
				}
				_, err = fmt.Fprintf(cmd.OutOrStdout(), "%s:%s@%s\n%s\n", info.RepositoryID, info.Name, info.Version, info.Description)
				return err
			}
			resource, err := client.Repository(cmd.Context(), repositoryID, reference.Version)
			if err != nil {
				return err
			}
			if output == "json" {
				view := repositoryInfoView{
					SchemaVersion: resource.Info.SchemaVersion, Kind: resource.Info.Kind, ID: resource.Info.ID,
					Version: resource.Info.Version, Time: resource.Info.Time, Ref: resource.Info.Ref,
					CommitSHA: resource.Info.CommitSHA, Skills: make([]skillInfoView, 0, len(resource.Members)),
				}
				for _, member := range resource.Members {
					skillView, description, productErr := productSkillInfo(cmd.Context(), client, member.Info)
					if productErr != nil {
						return productErr
					}
					if view.Description == "" {
						view.Description = description
					}
					view.Skills = append(view.Skills, skillView)
				}
				encoder := json.NewEncoder(cmd.OutOrStdout())
				encoder.SetIndent("", "  ")
				return encoder.Encode(view)
			}
			if _, err = fmt.Fprintf(cmd.OutOrStdout(), "%s@%s (%s)\n", resource.Info.ID, resource.Info.Version, resource.Info.CommitSHA); err != nil {
				return err
			}
			for _, member := range resource.Members {
				if _, err = fmt.Fprintf(cmd.OutOrStdout(), "- %s\t%s\n", member.Info.Name, member.Info.SkillPath); err != nil {
					return err
				}
			}
			return nil
		},
	}
	flags := cmd.Flags()
	flags.StringVar(&output, "output", "human", appi18n.T("flag.output"))
	flags.StringVar(&hubURL, "hub", defaultHubURL(), appi18n.T("flag.hub"))
	flags.StringVar(&skillName, "skill", "", "canonical Skill name within the Repository")
	return cmd
}
