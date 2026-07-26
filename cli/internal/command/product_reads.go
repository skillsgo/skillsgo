/*
 * [INPUT]: Depends on Cobra, bounded single/file/stdin Find input, exact Module Path/Version/Skill Path coordinates, and the CLI-owned Hub client.
 * [OUTPUT]: Provides single and batch `find`, version-scoped `detail`, `hub info`, and `hub check` domain commands with Human-default and explicit JSON results.
 * [POS]: Serves as the deep read-only product boundary that hides Hub routes and query parameters behind CLI domain language.
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

func validateProductOutput(output string) error {
	if output != "human" && output != "json" {
		return fmt.Errorf("output must be human or json")
	}
	return nil
}

func writeFindHuman(cmd *cobra.Command, document []byte, batch bool) error {
	if batch {
		var response protocolapi.FindCandidatesResponse
		if err := json.Unmarshal(document, &response); err != nil {
			return fmt.Errorf("decode Find response: %w", err)
		}
		for index, candidates := range response.Candidates {
			if _, err := fmt.Fprintf(cmd.OutOrStdout(), "Query %d\n", index+1); err != nil {
				return err
			}
			if len(candidates) == 0 {
				if _, err := fmt.Fprintln(cmd.OutOrStdout(), "  No Skills found."); err != nil {
					return err
				}
				continue
			}
			for _, skill := range candidates {
				if _, err := fmt.Fprintf(cmd.OutOrStdout(), "  %s  %s@%s  %s\n", skill.Name, skill.ModulePath, skill.Version, skill.Path); err != nil {
					return err
				}
			}
		}
		return nil
	}
	var response struct {
		Skills     []protocolapi.FindSkill `json:"skills"`
		Pagination protocolapi.Pagination  `json:"pagination"`
	}
	if err := json.Unmarshal(document, &response); err != nil {
		return fmt.Errorf("decode Find response: %w", err)
	}
	if len(response.Skills) == 0 {
		_, err := fmt.Fprintln(cmd.OutOrStdout(), "No Skills found.")
		return err
	}
	for _, skill := range response.Skills {
		if _, err := fmt.Fprintf(cmd.OutOrStdout(), "%s  %s@%s  %s\n", skill.Name, skill.ModulePath, skill.LatestVersion, skill.Path); err != nil {
			return err
		}
		if skill.Description != "" {
			if _, err := fmt.Fprintf(cmd.OutOrStdout(), "  %s\n", skill.Description); err != nil {
				return err
			}
		}
	}
	return nil
}

func newFindCommand() *cobra.Command {
	var hubURL, contentLocale, modulePath, input, output string
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
			if err := validateProductOutput(output); err != nil {
				return err
			}
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
				if output == "json" {
					return writeProductDocument(cmd, document)
				}
				return writeFindHuman(cmd, document, true)
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
			if output == "json" {
				return writeProductDocument(cmd, document)
			}
			return writeFindHuman(cmd, document, false)
		},
	}
	cmd.Flags().StringVar(&hubURL, "hub", defaultHubURL(), "Hub origin")
	cmd.Flags().IntVar(&page, "page", 0, "zero-based result page")
	cmd.Flags().IntVar(&perPage, "per-page", 20, "results per page")
	cmd.Flags().StringVar(&contentLocale, "content-locale", "", "preferred locale for descriptions")
	cmd.Flags().StringVar(&modulePath, "module", "", "canonical Module Path")
	cmd.Flags().StringVar(&input, "input", "", "batch Find JSON file or - for stdin")
	cmd.Flags().BoolVar(&exactName, "exact-name", false, "return only exact Skill names")
	cmd.Flags().StringVar(&output, "output", "human", "output format: human or json")
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
	var hubURL, output string
	cmd := &cobra.Command{
		Use:  "detail <module-path> <version> <skill-path>",
		Args: cobra.ExactArgs(3),
		RunE: func(cmd *cobra.Command, args []string) error {
			if err := validateProductOutput(output); err != nil {
				return err
			}
			client, err := hub.New(hubURL, nil)
			if err != nil {
				return err
			}
			document, err := client.Detail(cmd.Context(), args[0], args[1], args[2])
			if err != nil {
				return err
			}
			if output == "json" {
				return writeProductDocument(cmd, document)
			}
			var detail protocolapi.ModuleVersionSkill
			if err := json.Unmarshal(document, &detail); err != nil {
				return fmt.Errorf("decode Skill detail: %w", err)
			}
			_, err = fmt.Fprintf(cmd.OutOrStdout(), "%s  %s@%s  %s\n%s\n", detail.Name, detail.ModulePath, detail.Version, detail.Path, detail.Description)
			return err
		},
	}
	cmd.Flags().StringVar(&hubURL, "hub", defaultHubURL(), "Hub origin")
	cmd.Flags().StringVar(&output, "output", "human", "output format: human or json")
	return cmd
}

func newHubCommand() *cobra.Command {
	root := &cobra.Command{Use: "hub"}
	info := &cobra.Command{
		Use:  "info",
		Args: cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			output, _ := cmd.Flags().GetString("output")
			if err := validateProductOutput(output); err != nil {
				return err
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
			if output == "json" {
				return writeProductDocument(cmd, document)
			}
			var info struct {
				Mode  string `json:"mode"`
				Cloud string `json:"cloud"`
			}
			if err := json.Unmarshal(document, &info); err != nil {
				return fmt.Errorf("decode Hub info: %w", err)
			}
			if info.Cloud != "" {
				_, err = fmt.Fprintf(cmd.OutOrStdout(), "Mode: %s\nCloud: %s\n", info.Mode, info.Cloud)
			} else {
				_, err = fmt.Fprintf(cmd.OutOrStdout(), "Mode: %s\n", info.Mode)
			}
			return err
		},
	}
	info.Flags().String("hub", defaultHubURL(), "Hub origin")
	info.Flags().String("output", "human", "output format: human or json")
	check := &cobra.Command{
		Use:  "check",
		Args: cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			output, _ := cmd.Flags().GetString("output")
			if err := validateProductOutput(output); err != nil {
				return err
			}
			hubURL, _ := cmd.Flags().GetString("hub")
			client, err := hub.New(hubURL, nil)
			if err != nil {
				return err
			}
			document, err := client.Check(cmd.Context())
			if err != nil {
				return err
			}
			if output == "json" {
				return writeProductDocument(cmd, document)
			}
			_, err = fmt.Fprintln(cmd.OutOrStdout(), "Hub is reachable.")
			return err
		},
	}
	check.Flags().String("hub", defaultHubURL(), "Hub origin")
	check.Flags().String("output", "human", "output format: human or json")
	root.AddCommand(info, check)
	return root
}
