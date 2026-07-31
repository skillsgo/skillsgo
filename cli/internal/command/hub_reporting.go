/*
 * [INPUT]: Depends on successful local installation facts, cryptographic event IDs, the current Hub Origin, and the shared install-event route.
 * [OUTPUT]: Provides one best-effort batch Package install-event request with stable event identity, exact Skill facts, optional App version, and bounded network time that never changes an installation result.
 * [POS]: Serves as the narrow post-commit adapter between CLI-owned installation facts and the Hub's always-present community-data surface.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/protocol/cloud"
)

type hubInstallFact struct {
	PackagePath string
	Version     string
	Skills      []cloud.InstallEventSkill
	Agents      []string
	Scope       install.Scope
	AppVersion  string
}

func reportHubInstall(ctx context.Context, hubURL string, fact hubInstallFact) {
	if strings.TrimSpace(fact.PackagePath) == "" || strings.TrimSpace(fact.Version) == "" || len(fact.Skills) == 0 || len(fact.Agents) == 0 {
		return
	}
	origin, err := url.Parse(hubURL)
	if err != nil || (origin.Scheme != "http" && origin.Scheme != "https") || origin.Host == "" || origin.User != nil {
		return
	}
	reportCtx, cancel := context.WithTimeout(context.WithoutCancel(ctx), 3*time.Second)
	defer cancel()
	eventID := make([]byte, 16)
	if _, err := rand.Read(eventID); err != nil {
		return
	}
	body, err := json.Marshal(cloud.InstallEvent{
		EventID: hex.EncodeToString(eventID), PackagePath: fact.PackagePath,
		Version: fact.Version, Skills: fact.Skills, Agents: fact.Agents,
		Scope: cloud.Scope(fact.Scope), CLIVersion: version, AppVersion: fact.AppVersion, OccurredAt: time.Now().UTC(),
	})
	if err != nil {
		return
	}
	endpoint := strings.TrimRight(origin.String(), "/") + cloud.InstallEventsPath
	request, err := http.NewRequestWithContext(reportCtx, http.MethodPost, endpoint, bytes.NewReader(body))
	if err != nil {
		return
	}
	request.Header.Set("Content-Type", "application/json")
	response, err := http.DefaultClient.Do(request)
	if err == nil {
		response.Body.Close()
	}
}
