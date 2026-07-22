/*
 * [INPUT]: Depends on Cobra, canonical Skill IDs, the CLI-owned Hub client, and strict discovery collection values.
 * [OUTPUT]: Provides App-facing `discover`, `detail`, and `hub check` domain commands with JSON-only machine results.
 * [POS]: Serves as the deep read-only product boundary that hides Hub routes and query parameters from App callers.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"fmt"

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

func newDiscoverCommand() *cobra.Command {
	var hubURL, collection, query, contentLocale string
	var offset, limit int
	cmd := &cobra.Command{
		Use:  "discover",
		Args: cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			canonicalLocale, localeErr := canonicalContentLocale(contentLocale)
			if localeErr != nil {
				return localeErr
			}
			if collection != "search" && collection != "all_time" && collection != "trending" && collection != "hot" {
				return fmt.Errorf("invalid discovery collection")
			}
			if collection == "search" && query == "" {
				return fmt.Errorf("search query is required")
			}
			if offset < 0 || limit < 1 || limit > 100 {
				return fmt.Errorf("invalid discovery page")
			}
			client, err := hub.New(hubURL, nil)
			if err != nil {
				return err
			}
			document, err := client.DiscoverLocalized(cmd.Context(), collection, query, canonicalLocale, offset, limit)
			if err != nil {
				return err
			}
			return writeProductDocument(cmd, document)
		},
	}
	cmd.Flags().StringVar(&hubURL, "hub", defaultHubURL(), "Hub origin")
	cmd.Flags().StringVar(&collection, "collection", "all_time", "search, all_time, trending, or hot")
	cmd.Flags().StringVar(&query, "query", "", "search query")
	cmd.Flags().IntVar(&offset, "offset", 0, "result offset")
	cmd.Flags().IntVar(&limit, "limit", 20, "result limit")
	cmd.Flags().StringVar(&contentLocale, "content-locale", "", "preferred locale for descriptions")
	return cmd
}

func newDetailCommand() *cobra.Command {
	var hubURL, contentLocale string
	cmd := &cobra.Command{
		Use:  "detail <skill-id>",
		Args: cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			canonicalLocale, localeErr := canonicalContentLocale(contentLocale)
			if localeErr != nil {
				return localeErr
			}
			client, err := hub.New(hubURL, nil)
			if err != nil {
				return err
			}
			document, err := client.DetailLocalized(cmd.Context(), args[0], canonicalLocale)
			if err != nil {
				return err
			}
			return writeProductDocument(cmd, document)
		},
	}
	cmd.Flags().StringVar(&hubURL, "hub", defaultHubURL(), "Hub origin")
	cmd.Flags().StringVar(&contentLocale, "content-locale", "", "preferred locale for descriptions")
	return cmd
}

func newHubCommand() *cobra.Command {
	var hubURL string
	root := &cobra.Command{Use: "hub"}
	check := &cobra.Command{
		Use:  "check",
		Args: cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
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
	check.Flags().StringVar(&hubURL, "hub", defaultHubURL(), "Hub origin")
	root.AddCommand(check)
	return root
}
