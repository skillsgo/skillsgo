/*
 * [INPUT]: Depends on Cobra, bounded single/file/stdin Find input, exact Module Path/Version/Skill Path coordinates, and the CLI-owned Hub client.
 * [OUTPUT]: Provides App-facing single and batch `find`, version-scoped `detail`, `hub info`, and `hub check` domain commands with JSON-only machine results.
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
	var hubURL, contentLocale, modulePath, input string
	var exactName bool
	var page, perPage int
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
			if page < 0 || perPage < 1 || perPage > 100 {
				return fmt.Errorf("invalid search page")
			}
			client, err := hub.New(hubURL, nil)
			if err != nil {
				return err
			}
			if input != "" {
				if modulePath != "" || exactName || page != 0 {
					return fmt.Errorf("--module, --exact-name, and --page are unavailable with --input")
				}
				batchLimit := 10
				if cmd.Flags().Changed("per-page") {
					batchLimit = perPage
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
			if modulePath != "" {
				modulePath = strings.TrimSpace(modulePath)
				if err := source.ValidateModulePath(modulePath); err != nil {
					return err
				}
			}
			document, err := client.FindLocalized(cmd.Context(), query, modulePath, canonicalLocale, exactName, page, perPage)
			if err != nil {
				return err
			}
			return writeProductDocument(cmd, document)
		},
	}
	cmd.Flags().StringVar(&hubURL, "hub", defaultHubURL(), "Hub origin")
	cmd.Flags().IntVar(&page, "page", 0, "zero-based result page")
	cmd.Flags().IntVar(&perPage, "per-page", 20, "results per page")
	cmd.Flags().StringVar(&contentLocale, "content-locale", "", "preferred locale for descriptions")
	cmd.Flags().StringVar(&modulePath, "module", "", "canonical Module Path")
	cmd.Flags().StringVar(&input, "input", "", "batch Find JSON file or - for stdin")
	cmd.Flags().BoolVar(&exactName, "exact-name", false, "return only exact Skill names")
	return cmd
}

type findInput struct {
	Queries       []protocolapi.CandidateQuery `json:"queries"`
	Limit         int                          `json:"limit"`
	ContentLocale string                       `json:"contentLocale,omitempty"`
}

func readFindInput(cmd *cobra.Command, path string, flagLimit int, flagLocale string) (protocolapi.FindCandidatesRequest, error) {
	var reader io.Reader = cmd.InOrStdin()
	var file *os.File
	var err error
	if path != "-" {
		file, err = os.Open(path)
		if err != nil {
			return protocolapi.FindCandidatesRequest{}, err
		}
		defer file.Close()
		reader = file
	}
	decoder := json.NewDecoder(io.LimitReader(reader, 1<<20))
	decoder.DisallowUnknownFields()
	var input findInput
	if err := decoder.Decode(&input); err != nil {
		return protocolapi.FindCandidatesRequest{}, fmt.Errorf("decode Find input: %w", err)
	}
	if err := decoder.Decode(&struct{}{}); err != io.EOF {
		return protocolapi.FindCandidatesRequest{}, fmt.Errorf("Find input must contain one JSON object")
	}
	if len(input.Queries) == 0 || len(input.Queries) > 100 {
		return protocolapi.FindCandidatesRequest{}, fmt.Errorf("invalid Find input")
	}
	if input.Limit == 0 {
		input.Limit = flagLimit
	}
	if input.Limit < 1 || input.Limit > 10 {
		return protocolapi.FindCandidatesRequest{}, fmt.Errorf("Find input limit must be between 1 and 10")
	}
	locale := flagLocale
	if locale == "" {
		locale, err = canonicalContentLocale(input.ContentLocale)
		if err != nil {
			return protocolapi.FindCandidatesRequest{}, err
		}
	}
	return protocolapi.FindCandidatesRequest{Queries: input.Queries, Limit: input.Limit, Locale: locale}, nil
}

func newDetailCommand() *cobra.Command {
	var hubURL string
	cmd := &cobra.Command{
		Use:  "detail <module-path> <version> <skill-path>",
		Args: cobra.ExactArgs(3),
		RunE: func(cmd *cobra.Command, args []string) error {
			client, err := hub.New(hubURL, nil)
			if err != nil {
				return err
			}
			document, err := client.Detail(cmd.Context(), args[0], args[1], args[2])
			if err != nil {
				return err
			}
			return writeProductDocument(cmd, document)
		},
	}
	cmd.Flags().StringVar(&hubURL, "hub", defaultHubURL(), "Hub origin")
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
