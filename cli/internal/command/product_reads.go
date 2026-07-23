/*
 * [INPUT]: Depends on Cobra, separate Repository ID and canonical Skill name coordinates, and the CLI-owned Hub client.
 * [OUTPUT]: Provides App-facing `find`, `detail`, `hub info`, and `hub check` domain commands with JSON-only machine results.
 * [POS]: Serves as the deep read-only product boundary that hides Hub routes and query parameters from App callers.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"fmt"
	"strings"

	"github.com/skillsgo/skillsgo/cli/internal/hub"
	protocollocale "github.com/skillsgo/skillsgo/protocol/locale"
	"github.com/spf13/cobra"
)

func canonicalContentLocale(value string) (string, error) {
	if value == "" {
		return "", nil
	}
	return protocollocale.Canonical(value)
}

func writeProductDocument(cmd *cobra.Command, document []byte) error {
	_, err := fmt.Fprintln(cmd.OutOrStdout(), string(document))
	return err
}

func newFindCommand() *cobra.Command {
	var hubURL, contentLocale string
	var offset, limit int
	cmd := &cobra.Command{
		Use:   "find <query>",
		Short: "Search public Skills",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			query := strings.TrimSpace(args[0])
			if query == "" {
				return fmt.Errorf("search query is required")
			}
			canonicalLocale, localeErr := canonicalContentLocale(contentLocale)
			if localeErr != nil {
				return localeErr
			}
			if offset < 0 || limit < 1 || limit > 100 {
				return fmt.Errorf("invalid search page")
			}
			client, err := hub.New(hubURL, nil)
			if err != nil {
				return err
			}
			document, err := client.DiscoverLocalized(cmd.Context(), "search", query, canonicalLocale, offset, limit)
			if err != nil {
				return err
			}
			return writeProductDocument(cmd, document)
		},
	}
	cmd.Flags().StringVar(&hubURL, "hub", defaultHubURL(), "Hub origin")
	cmd.Flags().IntVar(&offset, "offset", 0, "result offset")
	cmd.Flags().IntVar(&limit, "limit", 20, "result limit")
	cmd.Flags().StringVar(&contentLocale, "content-locale", "", "preferred locale for descriptions")
	return cmd
}

func newDetailCommand() *cobra.Command {
	var hubURL, contentLocale string
	var repositories, skillNames []string
	cmd := &cobra.Command{
		Use:  "detail [repository-id skill-name]",
		Args: cobra.MaximumNArgs(2),
		RunE: func(cmd *cobra.Command, args []string) error {
			batch := len(repositories) > 0 || len(skillNames) > 0
			if (len(args) == 0) == !batch || (len(args) > 0 && len(args) != 2) || len(repositories) != len(skillNames) {
				return fmt.Errorf("provide one Repository ID and Skill name, or paired --repository and --skill values")
			}
			canonicalLocale, localeErr := canonicalContentLocale(contentLocale)
			if localeErr != nil {
				return localeErr
			}
			client, err := hub.New(hubURL, nil)
			if err != nil {
				return err
			}
			var document []byte
			if batch {
				coordinates := make([]hub.SkillCoordinate, 0, len(skillNames))
				for index := range skillNames {
					coordinates = append(coordinates, hub.SkillCoordinate{RepositoryID: repositories[index], Name: skillNames[index]})
				}
				document, err = client.BatchSkills(cmd.Context(), coordinates)
			} else {
				document, err = client.DetailLocalized(cmd.Context(), args[0], args[1], canonicalLocale)
			}
			if err != nil {
				return err
			}
			return writeProductDocument(cmd, document)
		},
	}
	cmd.Flags().StringVar(&hubURL, "hub", defaultHubURL(), "Hub origin")
	cmd.Flags().StringVar(&contentLocale, "content-locale", "", "preferred locale for descriptions")
	cmd.Flags().StringSliceVar(&repositories, "repository", nil, "ordered Repository IDs to hydrate")
	cmd.Flags().StringSliceVar(&skillNames, "skill", nil, "ordered canonical Skill names to hydrate")
	return cmd
}

func newHubCommand() *cobra.Command {
	root := &cobra.Command{Use: "hub"}
	info := &cobra.Command{
		Use:  "info",
		Args: cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			output, _ := cmd.Flags().GetString("output")
			if output != "json" {
				return fmt.Errorf("hub info supports only JSON output")
			}
			hubURL, _ := cmd.Flags().GetString("hub")
			client, err := hub.New(hubURL, nil)
			if err != nil {
				return err
			}
			document, err := client.HubInfo(cmd.Context())
			if err != nil {
				return err
			}
			return writeProductDocument(cmd, document)
		},
	}
	info.Flags().String("hub", defaultHubURL(), "Hub origin")
	info.Flags().String("output", "json", "output format")
	check := &cobra.Command{
		Use:  "check",
		Args: cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			hubURL, _ := cmd.Flags().GetString("hub")
			client, err := hub.New(hubURL, nil)
			if err != nil {
				return err
			}
			document, err := client.Check(cmd.Context())
			if err != nil {
				return err
			}
			return writeProductDocument(cmd, document)
		},
	}
	check.Flags().String("hub", defaultHubURL(), "Hub origin")
	root.AddCommand(info, check)
	return root
}
