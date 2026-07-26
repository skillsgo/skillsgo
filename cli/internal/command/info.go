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
	SchemaVersion int     `json:"schemaVersion"`
	Kind          string  `json:"kind"`
	ModulePath    string  `json:"modulePath"`
	Path          string  `json:"path"`
	Version       string  `json:"version"`
	Name          string  `json:"name"`
	Description   string  `json:"description"`
	ImageURL      *string `json:"imageUrl,omitempty"`
	Stars         int64   `json:"stars"`
}

type moduleInfoView struct {
	SchemaVersion int             `json:"schemaVersion"`
	Kind          string          `json:"kind"`
	ModulePath    string          `json:"modulePath"`
	Version       string          `json:"version"`
	Time          time.Time       `json:"time"`
	Description   string          `json:"description"`
	Skills        []skillInfoView `json:"skills"`
}

func productSkillInfo(ctx context.Context, client *hub.Client, modulePath, version string, info hub.Info) (skillInfoView, string, error) {
	metadata, err := client.ModuleVersionSkill(ctx, modulePath, version, info.Path)
	if err != nil {
		return skillInfoView{}, "", err
	}
	return skillInfoView{
		SchemaVersion: 1, Kind: "Skill", ModulePath: modulePath, Path: info.Path, Version: version, Name: info.Name, Description: metadata.Description,
	}, "", nil
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
			modulePath := reference.ModulePath
			client, err := hub.New(hubURL, nil)
			if err != nil {
				return err
			}
			if skillName != "" {
				resource, resolveErr := client.Module(cmd.Context(), modulePath, reference.Version)
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
					return fmt.Errorf("Repository %s@%s does not contain Skill named %s", modulePath, resource.Info.Version, skillName)
				}
				view, _, productErr := productSkillInfo(cmd.Context(), client, modulePath, resource.Info.Version, info)
				if productErr != nil {
					return productErr
				}
				if output == "json" {
					encoder := json.NewEncoder(cmd.OutOrStdout())
					encoder.SetIndent("", "  ")
					return encoder.Encode(view)
				}
				_, err = fmt.Fprintf(cmd.OutOrStdout(), "%s:%s@%s\n%s\n", modulePath, info.Name, resource.Info.Version, view.Description)
				return err
			}
			resource, err := client.Module(cmd.Context(), modulePath, reference.Version)
			if err != nil {
				return err
			}
			if output == "json" {
				view := moduleInfoView{
					SchemaVersion: resource.Info.SchemaVersion, Kind: resource.Info.Kind, ModulePath: resource.Info.ModulePath,
					Version: resource.Info.Version, Time: resource.Info.Time, Skills: make([]skillInfoView, 0, len(resource.Members)),
				}
				for _, member := range resource.Members {
					skillView, description, productErr := productSkillInfo(cmd.Context(), client, modulePath, resource.Info.Version, member.Info)
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
			if _, err = fmt.Fprintf(cmd.OutOrStdout(), "%s@%s\n", resource.Info.ModulePath, resource.Info.Version); err != nil {
				return err
			}
			for _, member := range resource.Members {
				if _, err = fmt.Fprintf(cmd.OutOrStdout(), "- %s\t%s\n", member.Info.Name, member.Info.Path); err != nil {
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
