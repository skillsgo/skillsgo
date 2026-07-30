/*
 * [INPUT]: Depends on successful local installation facts, cryptographic event IDs, the current Hub Origin, and the shared install-event route.
 * [OUTPUT]: Provides best-effort, non-blocking current-Hub install-event reporting that never changes an installation result.
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
	SkillName   string
	SkillPath   string
	Version     string
	Agents      []string
	Scope       install.Scope
}

func reportHubInstall(ctx context.Context, hubURL string, fact hubInstallFact) {
	if strings.TrimSpace(fact.PackagePath) == "" || strings.TrimSpace(fact.SkillName) == "" || strings.TrimSpace(fact.SkillPath) == "" || strings.TrimSpace(fact.Version) == "" || len(fact.Agents) == 0 {
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
		EventID: hex.EncodeToString(eventID), PackagePath: fact.PackagePath, SkillName: fact.SkillName,
		SkillPath: fact.SkillPath, Version: fact.Version, Agents: fact.Agents,
		Scope: cloud.Scope(fact.Scope), CLIVersion: version, OccurredAt: time.Now().UTC(),
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
