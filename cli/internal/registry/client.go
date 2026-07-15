/*
 * [INPUT]: Depends on a configured Registry origin, canonical Skill Coordinates, and exact assessed Info/Manifest/ZIP protocol responses.
 * [OUTPUT]: Provides validated immutable artifact fetch and resolution with Registry-bound Risk and Content Digest metadata.
 * [POS]: Serves as the CLI HTTP boundary to the public SkillsGo Registry protocol.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package registry

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/skillsgo/skillsgo/cli/internal/source"
)

type Origin struct {
	VCS       string `json:"VCS" yaml:"vcs"`
	URL       string `json:"URL" yaml:"url"`
	Subdir    string `json:"Subdir" yaml:"subdir"`
	Ref       string `json:"Ref" yaml:"ref"`
	CommitSHA string `json:"CommitSHA" yaml:"commitSHA"`
	TreeSHA   string `json:"TreeSHA" yaml:"treeSHA"`
}

type Info struct {
	Version       string    `json:"Version" yaml:"version"`
	Time          time.Time `json:"Time" yaml:"time"`
	Origin        Origin    `json:"Origin" yaml:"origin"`
	Risk          Risk      `json:"Risk" yaml:"risk"`
	ContentDigest string    `json:"ContentDigest" yaml:"contentDigest"`
}

type Risk string

const (
	RiskUnknown  Risk = "unknown"
	RiskLow      Risk = "low"
	RiskMedium   Risk = "medium"
	RiskHigh     Risk = "high"
	RiskCritical Risk = "critical"
)

func (r Risk) Valid() bool {
	return r == RiskUnknown || r == RiskLow || r == RiskMedium || r == RiskHigh || r == RiskCritical
}

type Artifact struct {
	Coordinate string
	Info       Info
	Manifest   []byte
	ZIP        []byte
}

type Client struct {
	baseURL string
	http    *http.Client
}

func New(baseURL string, client *http.Client) (*Client, error) {
	parsed, err := url.Parse(strings.TrimRight(baseURL, "/"))
	if err != nil || parsed.Scheme == "" || parsed.Host == "" {
		return nil, fmt.Errorf("无效 Registry URL %q", baseURL)
	}
	if client == nil {
		client = &http.Client{Timeout: 5 * time.Minute}
	}
	return &Client{baseURL: parsed.String(), http: client}, nil
}

func (c *Client) Fetch(ctx context.Context, coordinate, requestedVersion string) (*Artifact, error) {
	if requestedVersion == "" {
		requestedVersion = "main"
	}
	var info Info
	if err := c.getJSON(ctx, c.endpoint(coordinate, requestedVersion+".info"), &info); err != nil {
		return nil, err
	}
	if err := validateAssessedInfo(coordinate, requestedVersion, info); err != nil {
		return nil, err
	}
	manifest, err := c.get(ctx, c.endpoint(coordinate, info.Version+".manifest"))
	if err != nil {
		return nil, err
	}
	zipBytes, err := c.get(ctx, c.endpoint(coordinate, info.Version+".zip"))
	if err != nil {
		return nil, err
	}
	if err := VerifyContentDigest(zipBytes, coordinate, info.Version, info.ContentDigest); err != nil {
		return nil, err
	}
	return &Artifact{Coordinate: coordinate, Info: info, Manifest: manifest, ZIP: zipBytes}, nil
}

func (c *Client) Resolve(ctx context.Context, coordinate, requestedVersion string) (Info, error) {
	if requestedVersion == "" {
		requestedVersion = "main"
	}
	var info Info
	if err := c.getJSON(ctx, c.endpoint(coordinate, requestedVersion+".info"), &info); err != nil {
		return Info{}, err
	}
	if err := validateAssessedInfo(coordinate, requestedVersion, info); err != nil {
		return Info{}, err
	}
	return info, nil
}

func validateAssessedInfo(coordinate, requestedVersion string, info Info) error {
	if info.Version == "" || !info.Risk.Valid() || !strings.HasPrefix(info.ContentDigest, "sha256:") {
		return fmt.Errorf("Registry returned incomplete assessed Info for %s", coordinate)
	}
	if err := source.ValidateVersion(info.Version); err != nil {
		return fmt.Errorf("Registry returned an invalid immutable version for %s: %w", coordinate, err)
	}
	if requestedVersion != "" &&
		requestedVersion != "main" &&
		info.Version != requestedVersion &&
		info.Origin.Ref != "refs/heads/"+requestedVersion {
		return fmt.Errorf(
			"Registry resolved %s@%s as unexpected immutable version %s",
			coordinate, requestedVersion, info.Version,
		)
	}
	return nil
}

func (c *Client) endpoint(coordinate, file string) string {
	return c.baseURL + "/" + strings.Trim(coordinate, "/") + "/@v/" + file
}

func (c *Client) getJSON(ctx context.Context, endpoint string, target any) error {
	body, err := c.get(ctx, endpoint)
	if err != nil {
		return err
	}
	if err := json.Unmarshal(body, target); err != nil {
		return fmt.Errorf("解析 Registry 响应: %w", err)
	}
	return nil
}

func (c *Client) get(ctx context.Context, endpoint string) ([]byte, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return nil, err
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("请求 Registry: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		return nil, fmt.Errorf("Registry 返回 HTTP %d: %s", resp.StatusCode, strings.TrimSpace(string(body)))
	}
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}
	return body, nil
}
