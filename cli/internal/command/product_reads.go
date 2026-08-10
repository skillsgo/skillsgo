/*
 * [INPUT]: Depends on Cobra, bounded file/stdin candidate input, the source coordinate parser, exact Package Path/Version/Skill Path coordinates, and the CLI-owned Hub client.
 * [OUTPUT]: Provides keyword and immutable-version-preserving explicit-source `find`, including best-effort cold Package publication before version-scoped reads, plus grouped Hub service commands for connectivity, capability discovery, user-triggered Package update checks, and source-language `find-candidates` with Human-default and explicit JSON results.
 * [POS]: Serves as the deep read-only product boundary that owns source normalization and hides Hub routes and query parameters behind CLI domain language.
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
	appi18n "github.com/skillsgo/skillsgo/cli/internal/i18n"
	"github.com/skillsgo/skillsgo/cli/internal/source"
	protocolapi "github.com/skillsgo/skillsgo/protocol/api"
	protocolcloud "github.com/skillsgo/skillsgo/protocol/cloud"
	protocollocale "github.com/skillsgo/skillsgo/protocol/locale"
	"github.com/spf13/cobra"
)

func canonicalLang(value string) (string, error) {
	if value == "" {
		return "", nil
	}
	return protocollocale.CanonicalSupported(value)
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
				if _, err := fmt.Fprintf(cmd.OutOrStdout(), "  %s  %s@[%s]  %s\n", skill.Name, skill.PackagePath, strings.Join(skill.Versions, ", "), skill.Path); err != nil {
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
		if _, err := fmt.Fprintf(cmd.OutOrStdout(), "%s  %s@%s  %s\n", skill.Name, skill.PackagePath, skill.LatestVersion, skill.Path); err != nil {
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
	var hubURL, lang, packagePath, output string
	var exactName bool
	var page, perPage int
	cmd := &cobra.Command{
		Use:   "find <query>",
		Short: appi18n.Pick("Find public Skills", "查找公开 Skill"),
		Example: `  # Search across public Skills
  skillsgo find typescript

  # Find an exact Skill within one Package
  skillsgo find setup-matt-pocock-skills --module github.com/mattpocock/skills --exact-name

  # Read another result page
  skillsgo find typescript --page 1 --per-page 50`,
		Args: cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			if err := validateProductOutput(output); err != nil {
				return err
			}
			canonical, langErr := canonicalLang(lang)
			if langErr != nil {
				return langErr
			}
			if page < 0 || perPage < 1 || perPage > 100 {
				return fmt.Errorf("invalid search page")
			}
			client, err := hub.New(hubURL, nil)
			if err != nil {
				return err
			}
			query := strings.TrimSpace(args[0])
			resolvedVersion := ""
			if query == "" {
				return fmt.Errorf("find query is required")
			}
			if packagePath != "" {
				packagePath = strings.TrimSpace(packagePath)
				if err := source.ValidatePackagePath(packagePath); err != nil {
					return err
				}
			}
			if packagePath == "" {
				if reference, parseErr := source.Parse(query); parseErr == nil {
					resource, err := client.Package(cmd.Context(), reference.PackagePath, reference.Version)
					if err != nil {
						return err
					}
					query = reference.PackagePath
					packagePath = reference.PackagePath
					resolvedVersion = resource.Info.Version
				}
			}
			document, err := client.FindLocalized(cmd.Context(), query, packagePath, resolvedVersion, canonical, exactName, page, perPage)
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
	cmd.Flags().StringVar(&lang, "lang", "", "preferred presentation language")
	cmd.Flags().StringVar(&packagePath, "module", "", "canonical Package Path")
	cmd.Flags().BoolVar(&exactName, "exact-name", false, "return only exact Skill names")
	cmd.Flags().StringVar(&output, "output", "human", "output format: human or json")
	return cmd
}

func newRankingsCommand() *cobra.Command {
	var hubURL, lang, output string
	var page, perPage int
	cmd := &cobra.Command{
		Use:     "rankings <all_time|trending|hot>",
		Short:   appi18n.Pick("Read public Skill rankings", "读取公开 Skill 排名"),
		Example: "  skillsgo rankings trending --page 0 --per-page 20 --output json",
		Args:    cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			if err := validateProductOutput(output); err != nil {
				return err
			}
			kind := protocolcloud.RankingKind(args[0])
			if !kind.Valid() || page < 0 || perPage < 1 || perPage > 100 {
				return fmt.Errorf("invalid ranking request")
			}
			canonical, err := canonicalLang(lang)
			if err != nil {
				return err
			}
			client, err := hub.New(hubURL, nil)
			if err != nil {
				return err
			}
			document, err := client.Rankings(cmd.Context(), kind, canonical, page, perPage)
			if err != nil {
				return err
			}
			return writeProductDocument(cmd, document)
		},
	}
	cmd.Flags().StringVar(&hubURL, "hub", defaultHubURL(), "Hub origin")
	cmd.Flags().IntVar(&page, "page", 0, "zero-based result page")
	cmd.Flags().IntVar(&perPage, "per-page", 20, "results per page")
	cmd.Flags().StringVar(&lang, "lang", "", "preferred presentation language")
	cmd.Flags().StringVar(&output, "output", "json", "output format: human or json")
	return cmd
}

type findInput struct {
	Queries []protocolapi.CandidateQuery `json:"queries"`
	Limit   int                          `json:"limit"`
}

func readFindCandidatesInput(cmd *cobra.Command, path string, flagLimit int) (protocolapi.FindCandidatesRequest, error) {
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
	return protocolapi.FindCandidatesRequest{Queries: input.Queries, Limit: input.Limit}, nil
}

func newHubFindCandidatesCommand() *cobra.Command {
	var hubURL, input, output string
	var limit int
	cmd := &cobra.Command{
		Use:     "find-candidates",
		Short:   appi18n.Pick("Find source-language Skill candidates", "查找原文 Skill 候选"),
		Args:    cobra.NoArgs,
		Example: "  skillsgo hub find-candidates --input - --output json < find-queries.json",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if err := validateProductOutput(output); err != nil {
				return err
			}
			request, err := readFindCandidatesInput(cmd, input, limit)
			if err != nil {
				return err
			}
			client, err := hub.New(hubURL, nil)
			if err != nil {
				return err
			}
			document, err := client.FindCandidates(cmd.Context(), request)
			if err != nil {
				return err
			}
			if output == "json" {
				return writeProductDocument(cmd, document)
			}
			return writeFindHuman(cmd, document, true)
		},
	}
	cmd.Flags().StringVar(&hubURL, "hub", defaultHubURL(), "Hub origin")
	cmd.Flags().StringVar(&input, "input", "-", "candidate Find JSON file or - for stdin")
	cmd.Flags().IntVar(&limit, "limit", 10, "maximum candidates per query")
	cmd.Flags().StringVar(&output, "output", "human", "output format: human or json")
	return cmd
}

func newHubCommand() *cobra.Command {
	root := &cobra.Command{Use: "hub", Short: appi18n.Pick("Inspect the configured Hub", "检查已配置的 Hub"), Example: "  skillsgo hub check"}
	info := &cobra.Command{
		Use:     "info",
		Short:   appi18n.Pick("Read Hub capabilities", "读取 Hub 能力"),
		Args:    cobra.NoArgs,
		Example: "  skillsgo hub info --output json",
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
			var decoded protocolapi.HubInfo
			if err := json.Unmarshal(document, &decoded); err != nil {
				return err
			}
			if decoded.ImageProxyOrigin == "" {
				_, err = fmt.Fprintln(cmd.OutOrStdout(), "Hub image proxy is not configured.")
			} else {
				_, err = fmt.Fprintf(cmd.OutOrStdout(), "Hub image proxy: %s\n", decoded.ImageProxyOrigin)
			}
			return err
		},
	}
	info.Flags().String("hub", defaultHubURL(), "Hub origin")
	info.Flags().String("output", "human", "output format: human or json")
	check := &cobra.Command{
		Use:     "check",
		Short:   appi18n.Pick("Check Hub connectivity", "检查 Hub 连通性"),
		Args:    cobra.NoArgs,
		Example: "  skillsgo hub check\n  skillsgo hub check --output json",
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
	checkUpdate := &cobra.Command{
		Use:     "check-update <Package>",
		Short:   appi18n.Pick("Check a Package for updates", "检查 Package 更新"),
		Args:    cobra.ExactArgs(1),
		Example: "  skillsgo hub check-update github.com/owner/repo --output json",
		RunE: func(cmd *cobra.Command, args []string) error {
			output, _ := cmd.Flags().GetString("output")
			if err := validateProductOutput(output); err != nil {
				return err
			}
			reference, err := source.Parse(args[0])
			if err != nil {
				return err
			}
			if reference.Version != "latest" {
				return fmt.Errorf("Package update checks do not accept a Version selector")
			}
			hubURL, _ := cmd.Flags().GetString("hub")
			client, err := hub.New(hubURL, nil)
			if err != nil {
				return err
			}
			document, err := client.CheckPackageUpdate(cmd.Context(), reference.PackagePath)
			if err != nil {
				return err
			}
			if output == "json" {
				return writeProductDocument(cmd, document)
			}
			var result protocolapi.PackageUpdateCheckResult
			if err := json.Unmarshal(document, &result); err != nil {
				return err
			}
			if result.Status == protocolapi.PackageUpdateUpToDate {
				_, err = fmt.Fprintln(cmd.OutOrStdout(), appi18n.Pick("Already up to date.", "已是最新。"))
			} else {
				_, err = fmt.Fprintf(cmd.OutOrStdout(), appi18n.Pick("Preparing %s...\n", "正在准备 %s…\n"), result.Version)
			}
			return err
		},
	}
	checkUpdate.Flags().String("hub", defaultHubURL(), "Hub origin")
	checkUpdate.Flags().String("output", "human", "output format: human or json")
	root.AddCommand(info, check, checkUpdate, newHubFindCandidatesCommand())
	return root
}
