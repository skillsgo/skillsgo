/*
 * [INPUT]: Depends on Cobra, bounded single/file/stdin Find input, separate Repository ID and canonical Skill name coordinates, and the CLI-owned Hub client.
 * [OUTPUT]: Provides App-facing single and batch `find`, `detail`, `hub info`, and `hub check` domain commands with JSON-only machine results.
 * [POS]: Serves as the deep read-only product boundary that hides Hub routes and query parameters from App callers.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"strings"

	"github.com/skillsgo/skillsgo/cli/internal/hub"
	"github.com/skillsgo/skillsgo/cli/internal/source"
	protocolapi "github.com/skillsgo/skillsgo/protocol/api"
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
	var hubURL, contentLocale, sourceID, input string
	var exactName bool
	var offset, limit int
	cmd := &cobra.Command{
		Use:   "find <query>",
		Short: "Find public Skills",
		Args: func(_ *cobra.Command, args []string) error {
			if input == "" && len(args) != 1 {
				return fmt.Errorf("find requires one query or --input")
			}
			if input != "" && len(args) != 0 {
				return fmt.Errorf("query and --input cannot be used together")
			}
			return nil
		},
		RunE: func(cmd *cobra.Command, args []string) error {
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
			if input != "" {
				if sourceID != "" || exactName || offset != 0 {
					return fmt.Errorf("--source, --exact-name, and --offset are unavailable with --input")
				}
				batchLimit := 10
				if cmd.Flags().Changed("limit") {
					batchLimit = limit
				}
				request, err := readFindInput(cmd, input, batchLimit, canonicalLocale)
				if err != nil {
					return err
				}
				document, err := client.FindBatch(cmd.Context(), request)
				if err != nil {
					return err
				}
				return writeProductDocument(cmd, document)
			}
			query := strings.TrimSpace(args[0])
			if query == "" {
				return fmt.Errorf("find query is required")
			}
			if sourceID != "" {
				sourceID = strings.TrimSpace(sourceID)
				if err := source.ValidateRepositoryID(sourceID); err != nil {
					return err
				}
			}
			document, err := client.FindLocalized(cmd.Context(), query, sourceID, canonicalLocale, exactName, offset, limit)
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
	cmd.Flags().StringVar(&sourceID, "source", "", "canonical Repository source")
	cmd.Flags().StringVar(&input, "input", "", "batch Find JSON file or - for stdin")
	cmd.Flags().BoolVar(&exactName, "exact-name", false, "return only exact Skill names")
	return cmd
}

type findInput struct {
	SchemaVersion int                     `json:"schemaVersion"`
	Queries       []protocolapi.FindQuery `json:"queries"`
	Limit         int                     `json:"limit"`
	ContentLocale string                  `json:"contentLocale,omitempty"`
}

func readFindInput(cmd *cobra.Command, path string, flagLimit int, flagLocale string) (protocolapi.FindRequest, error) {
	var reader io.Reader = cmd.InOrStdin()
	var file *os.File
	var err error
	if path != "-" {
		file, err = os.Open(path)
		if err != nil {
			return protocolapi.FindRequest{}, err
		}
		defer file.Close()
		reader = file
	}
	decoder := json.NewDecoder(io.LimitReader(reader, 1<<20))
	decoder.DisallowUnknownFields()
	var input findInput
	if err := decoder.Decode(&input); err != nil {
		return protocolapi.FindRequest{}, fmt.Errorf("decode Find input: %w", err)
	}
	if err := decoder.Decode(&struct{}{}); err != io.EOF {
		return protocolapi.FindRequest{}, fmt.Errorf("Find input must contain one JSON object")
	}
	if input.SchemaVersion != protocolapi.SchemaVersion || len(input.Queries) == 0 || len(input.Queries) > 100 {
		return protocolapi.FindRequest{}, fmt.Errorf("invalid Find input")
	}
	if input.Limit == 0 {
		input.Limit = flagLimit
	}
	if input.Limit < 1 || input.Limit > 10 {
		return protocolapi.FindRequest{}, fmt.Errorf("Find input limit must be between 1 and 10")
	}
	locale := flagLocale
	if locale == "" {
		locale, err = canonicalContentLocale(input.ContentLocale)
		if err != nil {
			return protocolapi.FindRequest{}, err
		}
	}
	return protocolapi.FindRequest{SchemaVersion: protocolapi.SchemaVersion, Queries: input.Queries, Limit: input.Limit, Locale: locale}, nil
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
