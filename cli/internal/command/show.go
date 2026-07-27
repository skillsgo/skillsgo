/*
 * [INPUT]: Depends on the source coordinate parser, the public Hub Repository Info client, Cobra output selection, and terminal writers.
 * [OUTPUT]: Provides the read-only `skillsgo show <module>` command for Package summaries, named Skills, and exact-path Skill content.
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
	PackagePath   string  `json:"packagePath"`
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
	PackagePath   string          `json:"packagePath"`
	Version       string          `json:"version"`
	Time          time.Time       `json:"time"`
	Description   string          `json:"description"`
	Skills        []skillInfoView `json:"skills"`
}

func productSkillInfo(ctx context.Context, client *hub.Client, packagePath, version, lang string, info hub.Info) (skillInfoView, string, error) {
	metadata, err := client.PackageVersionSkill(ctx, packagePath, version, info.Path, lang)
	if err != nil {
		return skillInfoView{}, "", err
	}
	return skillInfoView{
		SchemaVersion: 1, Kind: "Skill", PackagePath: packagePath, Path: info.Path, Version: version, Name: info.Name, Description: metadata.Description,
	}, "", nil
}

func newShowCommand() *cobra.Command {
	var hubURL, output, skillName, skillPath, lang string
	cmd := &cobra.Command{
		Use:   "show <module>",
		Short: appi18n.T("show.short"),
		Args:  cobra.ExactArgs(1),
		Example: `  # Show the latest Package
  skillsgo show mattpocock/skills

  # Show a Package branch
  skillsgo show mattpocock/skills@main

  # Select a Skill by name
  skillsgo show mattpocock/skills@main --skill setup-matt-pocock-skills

  # Read a Skill by exact path, including its content
  skillsgo show mattpocock/skills@main --path skills/setup-matt-pocock-skills

  # Request the stable machine document
  skillsgo show mattpocock/skills@main --output json`,
		RunE: func(cmd *cobra.Command, args []string) error {
			if output != "human" && output != "json" {
				return fmt.Errorf("%s", appi18n.T("show.error.output"))
			}
			if skillName != "" && skillPath != "" {
				return fmt.Errorf("--skill and --path are mutually exclusive")
			}
			canonical, langErr := canonicalLang(lang)
			if langErr != nil {
				return langErr
			}
			reference, err := source.Parse(args[0])
			if err != nil {
				return err
			}
			packagePath := reference.PackagePath
			client, err := hub.New(hubURL, nil)
			if err != nil {
				return err
			}
			if skillPath != "" {
				resource, resolveErr := client.Package(cmd.Context(), packagePath, reference.Version)
				if resolveErr != nil {
					return resolveErr
				}
				detail, detailErr := client.PackageVersionSkill(cmd.Context(), packagePath, resource.Info.Version, skillPath, canonical)
				if detailErr != nil {
					return detailErr
				}
				if output == "json" {
					encoder := json.NewEncoder(cmd.OutOrStdout())
					encoder.SetIndent("", "  ")
					return encoder.Encode(detail)
				}
				_, err = fmt.Fprintf(cmd.OutOrStdout(), "%s  %s@%s  %s\n%s\n\n%s\n", detail.Name, detail.PackagePath, detail.Version, detail.Path, detail.Description, detail.Content)
				return err
			}
			if skillName != "" {
				resource, resolveErr := client.Package(cmd.Context(), packagePath, reference.Version)
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
					return fmt.Errorf("Repository %s@%s does not contain Skill named %s", packagePath, resource.Info.Version, skillName)
				}
				view, _, productErr := productSkillInfo(cmd.Context(), client, packagePath, resource.Info.Version, canonical, info)
				if productErr != nil {
					return productErr
				}
				if output == "json" {
					encoder := json.NewEncoder(cmd.OutOrStdout())
					encoder.SetIndent("", "  ")
					return encoder.Encode(view)
				}
				_, err = fmt.Fprintf(cmd.OutOrStdout(), "%s:%s@%s\n%s\n", packagePath, info.Name, resource.Info.Version, view.Description)
				return err
			}
			resource, err := client.Package(cmd.Context(), packagePath, reference.Version)
			if err != nil {
				return err
			}
			if output == "json" {
				view := moduleInfoView{
					SchemaVersion: resource.Info.SchemaVersion, Kind: resource.Info.Kind, PackagePath: resource.Info.PackagePath,
					Version: resource.Info.Version, Time: resource.Info.Time, Skills: make([]skillInfoView, 0, len(resource.Members)),
				}
				for _, member := range resource.Members {
					skillView, description, productErr := productSkillInfo(cmd.Context(), client, packagePath, resource.Info.Version, canonical, member.Info)
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
			if _, err = fmt.Fprintf(cmd.OutOrStdout(), "%s@%s\n", resource.Info.PackagePath, resource.Info.Version); err != nil {
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
	flags.StringVar(&skillPath, "path", "", "exact Skill path within the Repository")
	flags.StringVar(&lang, "lang", "", "preferred presentation language")
	return cmd
}
