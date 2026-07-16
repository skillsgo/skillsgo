/*
 * [INPUT]: Depends on one strict external-target JSON object, Agent inventory, configured Hub origin, Store, and adoption domain.
 * [OUTPUT]: Exposes adoption preflight and confirmed Hub-association or Local-import JSON at the public CLI boundary.
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

	"github.com/skillsgo/skillsgo/cli/internal/adoption"
	"github.com/skillsgo/skillsgo/cli/internal/agent"
	"github.com/skillsgo/skillsgo/cli/internal/hub"
	appi18n "github.com/skillsgo/skillsgo/cli/internal/i18n"
	"github.com/skillsgo/skillsgo/cli/internal/store"
	"github.com/spf13/cobra"
)

func newAdoptCommand(catalog *agent.Catalog) *cobra.Command {
	var rawTarget, hubURL, output string
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
				client, err := hub.New(hubURL, nil)
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
			var client *hub.Client
			if request.Action == adoption.ActionAssociateHub {
				client, err = hub.New(hubURL, nil)
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
	defaultHub := defaultHubURL()
	cmd.Flags().StringVar(&hubURL, "hub", defaultHub, appi18n.T("flag.hub"))
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
