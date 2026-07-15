/*
 * [INPUT]: Depends on one strict external-target JSON object, Agent inventory, configured Registry origin, Store, and adoption domain.
 * [OUTPUT]: Exposes adoption preflight and confirmed Registry-association or Local-import JSON at the public CLI boundary.
 * [POS]: Serves as the App-facing executable adapter for Bring Under Management.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"strings"

	"github.com/skillsgo/skillsgo/cli/internal/adoption"
	"github.com/skillsgo/skillsgo/cli/internal/agent"
	appi18n "github.com/skillsgo/skillsgo/cli/internal/i18n"
	"github.com/skillsgo/skillsgo/cli/internal/registry"
	"github.com/skillsgo/skillsgo/cli/internal/store"
	"github.com/spf13/cobra"
)

func newAdoptCommand(catalog *agent.Catalog) *cobra.Command {
	var rawTarget, registryURL, output string
	var preflight bool
	cmd := &cobra.Command{
		Use: "adopt", Short: appi18n.T("adopt.short"), Args: cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			if output != "json" {
				return fmt.Errorf("adoption requires --output json")
			}
			request, err := decodeAdoptionRequest(rawTarget)
			if err != nil {
				return err
			}
			if preflight && request.Action != "" {
				return fmt.Errorf("adoption preflight cannot include an action")
			}
			if !preflight && (request.Action == "" || request.StateToken == "") {
				return fmt.Errorf("adoption execution requires reviewed action and stateToken")
			}
			plan, err := adoption.Inspect(catalog, request)
			if err != nil {
				return err
			}
			if preflight {
				client, err := registry.New(registryURL, nil)
				if err != nil {
					return err
				}
				plan, err = adoption.AddMatches(cmd.Context(), plan, client)
				if err != nil {
					return err
				}
				return json.NewEncoder(cmd.OutOrStdout()).Encode(plan)
			}
			home, err := os.UserHomeDir()
			if err != nil {
				return err
			}
			var client *registry.Client
			if request.Action == adoption.ActionAssociateRegistry {
				client, err = registry.New(registryURL, nil)
				if err != nil {
					return err
				}
			}
			result, err := adoption.Execute(cmd.Context(), request, plan, client, store.Store{Root: store.DefaultRoot(home)})
			if err != nil {
				return err
			}
			return json.NewEncoder(cmd.OutOrStdout()).Encode(result)
		},
	}
	cmd.Flags().StringVar(&rawTarget, "target", "", appi18n.T("flag.adoption_target"))
	cmd.Flags().BoolVar(&preflight, "preflight", false, appi18n.T("flag.adoption_preflight"))
	cmd.Flags().StringVar(&output, "output", "human", appi18n.T("flag.output"))
	defaultRegistry := strings.TrimSpace(os.Getenv("SKILLSGO_REGISTRY_URL"))
	if defaultRegistry == "" {
		defaultRegistry = "http://localhost:3000"
	}
	cmd.Flags().StringVar(&registryURL, "registry", defaultRegistry, appi18n.T("flag.registry"))
	return cmd
}

func decodeAdoptionRequest(raw string) (adoption.Request, error) {
	decoder := json.NewDecoder(bytes.NewBufferString(raw))
	decoder.DisallowUnknownFields()
	var request adoption.Request
	if err := decoder.Decode(&request); err != nil {
		return request, fmt.Errorf("invalid adoption target: %w", err)
	}
	if err := decoder.Decode(&struct{}{}); !errors.Is(err, io.EOF) {
		return request, fmt.Errorf("adoption target must contain one JSON object")
	}
	return request, nil
}
