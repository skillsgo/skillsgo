/*
 * [INPUT]: Depends on successful local installation facts, Hub deployment discovery, cryptographic event IDs, and the declared Cloud HTTP origin.
 * [OUTPUT]: Provides best-effort, non-blocking Cloud install-event reporting that never changes an installation result.
 * [POS]: Serves as the narrow post-commit adapter between CLI-owned installation facts and Cloud-owned aggregate statistics.
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

	"github.com/skillsgo/skillsgo/cli/internal/hub"
	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/source"
)

type cloudInstallFact struct {
	SkillID string
	Version string
	Agents  []string
	Scope   install.Scope
}

func reportCloudInstall(ctx context.Context, hubURL string, fact cloudInstallFact) {
	if strings.TrimSpace(fact.SkillID) == "" || source.IsLocalSkillID(fact.SkillID) || strings.TrimSpace(fact.Version) == "" || len(fact.Agents) == 0 {
		return
	}
	reportCtx, cancel := context.WithTimeout(context.WithoutCancel(ctx), 3*time.Second)
	defer cancel()
	client, err := hub.New(hubURL, nil)
	if err != nil {
		return
	}
	rawInfo, err := client.HubInfo(reportCtx)
	if err != nil {
		return
	}
	var info struct {
		Mode  string `json:"mode"`
		Cloud string `json:"cloud"`
	}
	if json.Unmarshal(rawInfo, &info) != nil || info.Mode != "cloud" {
		return
	}
	origin, err := url.Parse(info.Cloud)
	if err != nil || (origin.Scheme != "http" && origin.Scheme != "https") || origin.Host == "" || origin.User != nil {
		return
	}
	eventID := make([]byte, 16)
	if _, err := rand.Read(eventID); err != nil {
		return
	}
	body, err := json.Marshal(struct {
		EventID    string    `json:"eventId"`
		SkillID    string    `json:"skillId"`
		Version    string    `json:"version"`
		Agents     []string  `json:"agents"`
		Scope      string    `json:"scope"`
		CLIVersion string    `json:"cliVersion"`
		OccurredAt time.Time `json:"occurredAt"`
	}{hex.EncodeToString(eventID), fact.SkillID, fact.Version, fact.Agents, string(fact.Scope), version, time.Now().UTC()})
	if err != nil {
		return
	}
	endpoint := strings.TrimRight(origin.String(), "/") + "/api/v1/events/install"
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
