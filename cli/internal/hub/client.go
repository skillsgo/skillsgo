/*
 * [INPUT]: Depends on a configured Hub origin, canonical Skill IDs, Hub-owned selector resolution, exact content-match responses, and enriched immutable Info/ZIP protocol responses.
 * [OUTPUT]: Provides delegated selector resolution, validated content-identity matching, immutable artifact fetch with optional byte progress, normalized Skill metadata, Hub-bound Risk and Content Digest metadata, and typed HTTP failures.
 * [POS]: Serves as the CLI HTTP boundary to the public SkillsGo Hub protocol.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package hub

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
	modmodule "golang.org/x/mod/module"
	modsemver "golang.org/x/mod/semver"
)

type Info struct {
	SchemaVersion int               `json:"SchemaVersion" yaml:"schemaVersion"`
	Kind          string            `json:"Kind" yaml:"kind"`
	ID            string            `json:"ID" yaml:"id"`
	Version       string            `json:"Version" yaml:"version"`
	Time          time.Time         `json:"Time" yaml:"time"`
	Ref           string            `json:"Ref" yaml:"ref"`
	CommitSHA     string            `json:"CommitSHA" yaml:"commitSHA"`
	TreeSHA       string            `json:"TreeSHA" yaml:"treeSHA"`
	Name          string            `json:"Name" yaml:"name"`
	Description   string            `json:"Description" yaml:"description"`
	License       string            `json:"License,omitempty" yaml:"license,omitempty"`
	Compatibility string            `json:"Compatibility,omitempty" yaml:"compatibility,omitempty"`
	AllowedTools  string            `json:"AllowedTools,omitempty" yaml:"allowedTools,omitempty"`
	Metadata      map[string]string `json:"Metadata,omitempty" yaml:"metadata,omitempty"`
	Risk          Risk              `json:"Risk" yaml:"risk"`
	ContentDigest string            `json:"ContentDigest" yaml:"contentDigest"`
	ArchiveSize   int64             `json:"ArchiveSize" yaml:"archiveSize"`
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
	SkillID   string
	Info      Info
	InfoBytes []byte
	ZIP       []byte
}

type RepositoryInfo struct {
	SchemaVersion int               `json:"SchemaVersion"`
	Kind          string            `json:"Kind"`
	ID            string            `json:"ID"`
	Version       string            `json:"Version"`
	Time          time.Time         `json:"Time"`
	Ref           string            `json:"Ref"`
	CommitSHA     string            `json:"CommitSHA"`
	Skills        []json.RawMessage `json:"Skills"`
}

type RepositoryResource struct {
	Info      RepositoryInfo
	InfoBytes []byte
	Members   []RepositoryMember
}

type RepositoryMember struct {
	Info      Info
	InfoBytes []byte
}

type ContentMatch struct {
	SkillID          string `json:"skillId"`
	Name             string `json:"name"`
	Source           string `json:"source"`
	SkillPath        string `json:"skillPath"`
	ImmutableVersion string `json:"immutableVersion"`
	CommitSHA        string `json:"commitSHA"`
	TreeSHA          string `json:"treeSHA"`
	ContentDigest    string `json:"contentDigest"`
}

type SkillProductMetadata struct {
	ID             string  `json:"id"`
	ImageURL       *string `json:"imageUrl"`
	Installs       int64   `json:"installs"`
	GitHubStars    int64   `json:"githubStars"`
	TrustLevel     string  `json:"trustLevel"`
	RiskAssessment struct {
		Level Risk `json:"level"`
	} `json:"riskAssessment"`
}

type SkillSummary struct {
	SkillID       string `json:"id"`
	Name          string `json:"name"`
	Repository    string `json:"repository"`
	LatestVersion string `json:"latestVersion"`
}

type skillsResponse struct {
	Skills []SkillSummary `json:"skills"`
}

type contentMatchesResponse struct {
	SchemaVersion int            `json:"schemaVersion"`
	ContentDigest string         `json:"contentDigest"`
	Matches       []ContentMatch `json:"matches"`
}

type Client struct {
	baseURL string
	http    *http.Client
}

type HTTPError struct {
	StatusCode int
	Body       string
}

func (e *HTTPError) Error() string {
	return fmt.Sprintf("Hub 返回 HTTP %d: %s", e.StatusCode, e.Body)
}

func New(baseURL string, client *http.Client) (*Client, error) {
	parsed, err := url.Parse(strings.TrimRight(baseURL, "/"))
	if err != nil || parsed.Scheme == "" || parsed.Host == "" {
		return nil, fmt.Errorf("无效 Hub URL %q", baseURL)
	}
	if client == nil {
		client = &http.Client{Timeout: 5 * time.Minute}
	}
	return &Client{baseURL: parsed.String(), http: client}, nil
}

func (c *Client) Fetch(ctx context.Context, skillID, requestedVersion string) (*Artifact, error) {
	return c.FetchWithProgress(ctx, skillID, requestedVersion, nil)
}

func (c *Client) Repository(ctx context.Context, repositoryID, query string) (*RepositoryResource, error) {
	if query == "" {
		query = "latest"
	}
	if query == "latest" {
		versions, err := c.Versions(ctx, repositoryID)
		if err != nil {
			return nil, err
		}
		if selected := latestVersion(versions); selected != "" {
			query = selected
		} else {
			var latest struct {
				Version string `json:"Version"`
			}
			if err := c.getJSON(ctx, c.latestEndpoint(repositoryID), &latest); err != nil {
				return nil, err
			}
			if err := source.ValidateVersion(latest.Version); err != nil {
				return nil, fmt.Errorf("Hub returned invalid latest Repository version for %s: %w", repositoryID, err)
			}
			query = latest.Version
		}
	}
	infoBytes, err := c.get(ctx, c.endpoint(repositoryID, query+".info"))
	if err != nil {
		return nil, err
	}
	return ParseRepositoryInfo(repositoryID, infoBytes)
}

func (c *Client) Versions(ctx context.Context, resourceID string) ([]string, error) {
	body, err := c.get(ctx, c.endpoint(resourceID, "list"))
	if err != nil {
		return nil, err
	}
	versions := make([]string, 0)
	seen := map[string]bool{}
	for _, candidate := range strings.Fields(string(body)) {
		if !modsemver.IsValid(candidate) || modmodule.IsPseudoVersion(candidate) || seen[candidate] {
			continue
		}
		seen[candidate] = true
		versions = append(versions, candidate)
	}
	return versions, nil
}

func latestVersion(versions []string) string {
	stable, prerelease := "", ""
	for _, version := range versions {
		if !modsemver.IsValid(version) || modmodule.IsPseudoVersion(version) {
			continue
		}
		if modsemver.Prerelease(version) == "" {
			if stable == "" || modsemver.Compare(version, stable) > 0 {
				stable = version
			}
		} else if prerelease == "" || modsemver.Compare(version, prerelease) > 0 {
			prerelease = version
		}
	}
	if stable != "" {
		return stable
	}
	return prerelease
}

func ParseRepositoryInfo(repositoryID string, infoBytes []byte) (*RepositoryResource, error) {
	var info RepositoryInfo
	if err := json.Unmarshal(infoBytes, &info); err != nil {
		return nil, fmt.Errorf("解析 Repository Info: %w", err)
	}
	if info.SchemaVersion != 1 || info.Kind != "Repository" || info.ID != repositoryID ||
		info.Version == "" || info.CommitSHA == "" || len(info.Skills) == 0 {
		return nil, fmt.Errorf("Hub returned incomplete Repository Info for %s", repositoryID)
	}
	if err := source.ValidateVersion(info.Version); err != nil {
		return nil, fmt.Errorf("Hub returned invalid Repository version for %s: %w", repositoryID, err)
	}
	resource := &RepositoryResource{Info: info, InfoBytes: append([]byte(nil), infoBytes...), Members: make([]RepositoryMember, 0, len(info.Skills))}
	seen := map[string]bool{}
	prefix := strings.TrimSuffix(repositoryID, "/") + "/-/"
	for _, raw := range info.Skills {
		var member Info
		if err := json.Unmarshal(raw, &member); err != nil {
			return nil, fmt.Errorf("parse Repository member Info: %w", err)
		}
		if member.ID != repositoryID && !strings.HasPrefix(member.ID, prefix) {
			return nil, fmt.Errorf("Repository Info contains foreign Skill %q", member.ID)
		}
		if seen[member.ID] || member.Version != info.Version || member.CommitSHA != info.CommitSHA || member.Ref != info.Ref {
			return nil, fmt.Errorf("Repository Info contains inconsistent Skill %q", member.ID)
		}
		if err := validateAssessedInfo(member.ID, info.Version, member); err != nil {
			return nil, err
		}
		seen[member.ID] = true
		resource.Members = append(resource.Members, RepositoryMember{Info: member, InfoBytes: append([]byte(nil), raw...)})
	}
	return resource, nil
}

func (c *Client) FetchRepositoryMember(ctx context.Context, member RepositoryMember, progress func(current, total int64)) (*Artifact, error) {
	info := member.Info
	zipBytes, err := c.getWithProgress(ctx, c.endpoint(info.ID, info.Version+".zip"), progress)
	if err != nil {
		return nil, err
	}
	if info.ArchiveSize > 0 && info.ArchiveSize != int64(len(zipBytes)) {
		return nil, fmt.Errorf("Hub returned an unexpected Archive Size for %s@%s", info.ID, info.Version)
	}
	if err := VerifyContentDigest(zipBytes, info.ID, info.Version, info.ContentDigest); err != nil {
		return nil, err
	}
	return &Artifact{SkillID: info.ID, Info: info, InfoBytes: member.InfoBytes, ZIP: zipBytes}, nil
}

func (c *Client) FetchWithProgress(ctx context.Context, skillID, requestedVersion string, progress func(current, total int64)) (*Artifact, error) {
	if requestedVersion == "" {
		requestedVersion = "latest"
	}
	infoBytes, err := c.get(ctx, c.endpoint(skillID, requestedVersion+".info"))
	if err != nil {
		return nil, err
	}
	var info Info
	if err := json.Unmarshal(infoBytes, &info); err != nil {
		return nil, fmt.Errorf("解析 Hub 响应: %w", err)
	}
	if err := validateAssessedInfo(skillID, requestedVersion, info); err != nil {
		return nil, err
	}
	zipBytes, err := c.getWithProgress(ctx, c.endpoint(skillID, info.Version+".zip"), progress)
	if err != nil {
		return nil, err
	}
	if info.ArchiveSize > 0 && info.ArchiveSize != int64(len(zipBytes)) {
		return nil, fmt.Errorf("Hub returned an unexpected Archive Size for %s@%s", skillID, info.Version)
	}
	if err := VerifyContentDigest(zipBytes, skillID, info.Version, info.ContentDigest); err != nil {
		return nil, err
	}
	return &Artifact{SkillID: skillID, Info: info, InfoBytes: infoBytes, ZIP: zipBytes}, nil
}

func (c *Client) Resolve(ctx context.Context, skillID, requestedVersion string) (Info, error) {
	if requestedVersion == "" {
		requestedVersion = "latest"
	}
	var info Info
	if err := c.getJSON(ctx, c.endpoint(skillID, requestedVersion+".info"), &info); err != nil {
		return Info{}, err
	}
	if err := validateAssessedInfo(skillID, requestedVersion, info); err != nil {
		return Info{}, err
	}
	return info, nil
}

func (c *Client) SkillProduct(ctx context.Context, skillID string) (SkillProductMetadata, error) {
	var metadata SkillProductMetadata
	if err := c.getJSON(ctx, c.baseURL+"/v1/skills/"+skillID, &metadata); err != nil {
		return SkillProductMetadata{}, err
	}
	if metadata.ID != skillID {
		return SkillProductMetadata{}, fmt.Errorf("Hub returned mismatched Skill product metadata for %s", skillID)
	}
	return metadata, nil
}

func (c *Client) MatchContent(ctx context.Context, contentDigest, sourceHint string) ([]ContentMatch, error) {
	query := url.Values{"contentDigest": []string{contentDigest}}
	if strings.TrimSpace(sourceHint) != "" {
		query.Set("sourceHint", strings.TrimSpace(sourceHint))
	}
	var response contentMatchesResponse
	if err := c.getJSON(ctx, c.baseURL+"/v1/matches?"+query.Encode(), &response); err != nil {
		return nil, err
	}
	if response.SchemaVersion != 1 || response.ContentDigest != contentDigest || response.Matches == nil {
		return nil, fmt.Errorf("Hub returned an invalid content-match response")
	}
	seen := map[string]bool{}
	for _, match := range response.Matches {
		key := match.SkillID + "\x00" + match.ImmutableVersion
		if source.ValidateSkillID(match.SkillID) != nil ||
			source.ValidateVersion(match.ImmutableVersion) != nil ||
			match.Name == "" || match.Source == "" || match.CommitSHA == "" || match.TreeSHA == "" ||
			match.ContentDigest != contentDigest || seen[key] {
			return nil, fmt.Errorf("Hub returned an invalid content match")
		}
		seen[key] = true
	}
	return response.Matches, nil
}

func validateAssessedInfo(skillID, requestedVersion string, info Info) error {
	if info.Version == "" || !info.Risk.Valid() || !strings.HasPrefix(info.ContentDigest, "sha256:") || info.ArchiveSize < 0 {
		return fmt.Errorf("Hub returned incomplete assessed Info for %s", skillID)
	}
	if info.SchemaVersion != 1 || info.Kind != "Skill" || info.ID != skillID || info.Name == "" || info.Description == "" {
		return fmt.Errorf("Hub returned incomplete assessed Info for %s", skillID)
	}
	if err := source.ValidateVersion(info.Version); err != nil {
		return fmt.Errorf("Hub returned an invalid immutable version for %s: %w", skillID, err)
	}
	if strings.HasPrefix(requestedVersion, "v") && info.Version != requestedVersion {
		return fmt.Errorf(
			"Hub resolved %s@%s as unexpected immutable version %s",
			skillID, requestedVersion, info.Version,
		)
	}
	return nil
}

func (c *Client) endpoint(skillID, file string) string {
	escapedID, err := modmodule.EscapePath(strings.Trim(skillID, "/"))
	if err != nil {
		// Canonical IDs have already crossed the source parser boundary. Keep
		// this helper total while allowing the Router to reject impossible IDs.
		escapedID = strings.Trim(skillID, "/")
	}
	if file == "list" {
		return c.baseURL + "/" + escapedID + "/@v/list"
	}
	for _, suffix := range []string{".info", ".zip"} {
		if strings.HasSuffix(file, suffix) {
			version := strings.TrimSuffix(file, suffix)
			escapedVersion, escapeErr := modmodule.EscapeVersion(version)
			if escapeErr == nil {
				file = escapedVersion + suffix
			}
			break
		}
	}
	return c.baseURL + "/" + escapedID + "/@v/" + file
}

func (c *Client) latestEndpoint(skillID string) string {
	escapedID, err := modmodule.EscapePath(strings.Trim(skillID, "/"))
	if err != nil {
		escapedID = strings.Trim(skillID, "/")
	}
	return c.baseURL + "/" + escapedID + "/@latest"
}

func (c *Client) getJSON(ctx context.Context, endpoint string, target any) error {
	body, err := c.get(ctx, endpoint)
	if err != nil {
		return err
	}
	if err := json.Unmarshal(body, target); err != nil {
		return fmt.Errorf("解析 Hub 响应: %w", err)
	}
	return nil
}

func (c *Client) get(ctx context.Context, endpoint string) ([]byte, error) {
	return c.getWithProgress(ctx, endpoint, nil)
}

func (c *Client) getWithProgress(ctx context.Context, endpoint string, progress func(current, total int64)) ([]byte, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return nil, err
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("请求 Hub: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		return nil, &HTTPError{StatusCode: resp.StatusCode, Body: strings.TrimSpace(string(body))}
	}
	reader := io.Reader(resp.Body)
	if progress != nil {
		reader = &progressReader{reader: resp.Body, total: resp.ContentLength, progress: progress}
	}
	body, err := io.ReadAll(reader)
	if err != nil {
		return nil, err
	}
	return body, nil
}

type progressReader struct {
	reader   io.Reader
	current  int64
	total    int64
	progress func(current, total int64)
}

func (reader *progressReader) Read(buffer []byte) (int, error) {
	count, err := reader.reader.Read(buffer)
	if count > 0 {
		reader.current += int64(count)
		total := reader.total
		if total < 0 {
			total = 0
		}
		reader.progress(reader.current, total)
	}
	return count, err
}
