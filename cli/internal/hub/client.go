/*
 * [INPUT]: Depends on a configured Hub origin, canonical Skill IDs, Hub-owned selector resolution, exact content-match responses, and enriched immutable Info/ZIP protocol responses.
 * [OUTPUT]: Provides delegated selector resolution, strict product JSON reads, Catalog-only batch latest-version reads, validated content-identity matching, immutable artifact fetch with optional byte progress, normalized Skill metadata, Hub-bound Risk and Sum metadata, and typed HTTP or malformed-protocol failures.
 * [POS]: Serves as the CLI HTTP boundary to the public SkillsGo Hub protocol.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package hub

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/skillsgo/skillsgo/cli/internal/source"
	protocolapi "github.com/skillsgo/skillsgo/protocol/api"
	protocolversion "github.com/skillsgo/skillsgo/protocol/version"
	modmodule "golang.org/x/mod/module"
	modsemver "golang.org/x/mod/semver"
)

type Info = protocolapi.SkillInfo
type Risk = protocolapi.Risk

const (
	RiskUnknown  = protocolapi.RiskUnknown
	RiskLow      = protocolapi.RiskLow
	RiskMedium   = protocolapi.RiskMedium
	RiskHigh     = protocolapi.RiskHigh
	RiskCritical = protocolapi.RiskCritical
)

type Artifact struct {
	SkillID   string
	Info      Info
	InfoBytes []byte
	ZIP       []byte
}

type RepositoryInfo = protocolapi.RepositoryInfo

type RepositoryResource struct {
	Info      RepositoryInfo
	InfoBytes []byte
	Members   []RepositoryMember
}

type RepositoryMember struct {
	Info      Info
	InfoBytes []byte
}

type ContentMatch = protocolapi.ContentMatch

type SkillProductMetadata struct {
	ID                    string  `json:"id"`
	ImageURL              *string `json:"imageUrl"`
	Installs              int64   `json:"installs"`
	Stars                 int64   `json:"stars"`
	RepositoryDescription string  `json:"repositoryDescription"`
	TrustLevel            string  `json:"trustLevel"`
	RiskAssessment        struct {
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

type contentMatchesResponse = protocolapi.ContentMatchesResponse

type CatalogUpdateItem = protocolapi.CatalogUpdateCheckItem

type catalogUpdateResponse = protocolapi.CatalogUpdateCheckResponse

type Client struct {
	baseURL string
	http    *http.Client
}

type HTTPError struct {
	StatusCode int
	Body       string
	RequestID  string
}

func (e *HTTPError) Error() string {
	return fmt.Sprintf("Hub 返回 HTTP %d: %s", e.StatusCode, e.Body)
}

type ProtocolError struct {
	Err          error
	Incompatible bool
}

func (e *ProtocolError) Error() string { return e.Err.Error() }

func (e *ProtocolError) Unwrap() error { return e.Err }

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
	return protocolversion.LatestPublished(versions)
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
	if err := VerifySum(zipBytes, info.ID, info.Version, info.Sum); err != nil {
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
	if err := VerifySum(zipBytes, skillID, info.Version, info.Sum); err != nil {
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
	if err := c.getJSON(ctx, c.baseURL+"/api/v1/skills/"+skillID, &metadata); err != nil {
		return SkillProductMetadata{}, err
	}
	if metadata.ID != skillID {
		return SkillProductMetadata{}, fmt.Errorf("Hub returned mismatched Skill product metadata for %s", skillID)
	}
	return metadata, nil
}

func (c *Client) readProductJSON(ctx context.Context, path string, query url.Values) (json.RawMessage, error) {
	if !strings.HasPrefix(path, "/api/v1/") || strings.Contains(path, "..") {
		return nil, fmt.Errorf("invalid Hub product path")
	}
	endpoint := c.baseURL + path
	if len(query) > 0 {
		endpoint += "?" + query.Encode()
	}
	var document json.RawMessage
	if err := c.getJSON(ctx, endpoint, &document); err != nil {
		return nil, err
	}
	if !json.Valid(document) || len(document) == 0 {
		return nil, fmt.Errorf("Hub returned invalid JSON")
	}
	return document, nil
}

func (c *Client) Discover(ctx context.Context, collection, search string, offset, limit int) (json.RawMessage, error) {
	return c.DiscoverLocalized(ctx, collection, search, "", offset, limit)
}

func (c *Client) DiscoverLocalized(ctx context.Context, collection, search, locale string, offset, limit int) (json.RawMessage, error) {
	query := url.Values{"offset": {fmt.Sprint(offset)}, "limit": {fmt.Sprint(limit)}}
	if strings.TrimSpace(locale) != "" {
		query.Set("locale", strings.TrimSpace(locale))
	}
	path := "/api/v1/skills"
	if collection == "search" {
		path = "/api/v1/search"
		query.Set("q", search)
	} else {
		query.Set("sort", collection)
	}
	return c.readProductJSON(ctx, path, query)
}

func (c *Client) Detail(ctx context.Context, skillID string) (json.RawMessage, error) {
	return c.DetailLocalized(ctx, skillID, "")
}

func (c *Client) DetailLocalized(ctx context.Context, skillID, locale string) (json.RawMessage, error) {
	if err := source.ValidateSkillID(skillID); err != nil {
		return nil, err
	}
	query := url.Values{}
	if strings.TrimSpace(locale) != "" {
		query.Set("locale", strings.TrimSpace(locale))
	}
	return c.readProductJSON(ctx, "/api/v1/skills/"+skillID, query)
}

func (c *Client) Check(ctx context.Context) (json.RawMessage, error) {
	return c.Discover(ctx, "search", "skillsgo-settings-probe", 0, 1)
}

func (c *Client) MatchContent(ctx context.Context, sum, sourceHint string) ([]ContentMatch, error) {
	query := url.Values{"sum": []string{sum}}
	if strings.TrimSpace(sourceHint) != "" {
		query.Set("sourceHint", strings.TrimSpace(sourceHint))
	}
	var response contentMatchesResponse
	if err := c.getJSON(ctx, c.baseURL+"/api/v1/matches?"+query.Encode(), &response); err != nil {
		return nil, err
	}
	if response.SchemaVersion != 1 || response.Sum != sum || response.Matches == nil {
		return nil, fmt.Errorf("Hub returned an invalid content-match response")
	}
	seen := map[string]bool{}
	for _, match := range response.Matches {
		key := match.SkillID + "\x00" + match.ImmutableVersion
		if source.ValidateSkillID(match.SkillID) != nil ||
			source.ValidateVersion(match.ImmutableVersion) != nil ||
			match.Name == "" || match.Source == "" || match.CommitSHA == "" || match.TreeSHA == "" ||
			match.Sum != sum || seen[key] {
			return nil, fmt.Errorf("Hub returned an invalid content match")
		}
		seen[key] = true
	}
	return response.Matches, nil
}

func (c *Client) CatalogUpdates(ctx context.Context, skillIDs []string) ([]CatalogUpdateItem, error) {
	requestBody, err := json.Marshal(struct {
		SchemaVersion int      `json:"schemaVersion"`
		SkillIDs      []string `json:"skillIds"`
	}{SchemaVersion: 1, SkillIDs: skillIDs})
	if err != nil {
		return nil, err
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/api/v1/updates/check", bytes.NewReader(requestBody))
	if err != nil {
		return nil, err
	}
	request.Header.Set("Content-Type", "application/json")
	response, err := c.http.Do(request)
	if err != nil {
		return nil, fmt.Errorf("请求 Hub: %w", err)
	}
	defer response.Body.Close()
	body, err := io.ReadAll(io.LimitReader(response.Body, 4<<20))
	if err != nil {
		return nil, err
	}
	if response.StatusCode != http.StatusOK {
		return nil, &HTTPError{StatusCode: response.StatusCode, Body: strings.TrimSpace(string(body)), RequestID: response.Header.Get("Athens-Request-ID")}
	}
	var decoded catalogUpdateResponse
	if json.Unmarshal(body, &decoded) != nil || decoded.SchemaVersion != 1 || len(decoded.Items) != len(skillIDs) {
		return nil, &ProtocolError{Err: fmt.Errorf("Hub returned an invalid Catalog update response")}
	}
	for index, item := range decoded.Items {
		if item.SkillID != skillIDs[index] || (item.Status != "available" && item.Status != "unsupported") || (item.Status == "available" && item.LatestVersion == "") {
			return nil, &ProtocolError{Err: fmt.Errorf("Hub returned an invalid Catalog update item")}
		}
	}
	return decoded.Items, nil
}

func validateAssessedInfo(skillID, requestedVersion string, info Info) error {
	if info.Version == "" || !info.Risk.Valid() || !ValidSum(info.Sum) || info.ArchiveSize < 0 {
		return fmt.Errorf("Hub returned incomplete assessed Info for %s", skillID)
	}
	if info.SchemaVersion != 1 {
		return &ProtocolError{Err: fmt.Errorf("Hub returned unsupported Info schema %d for %s", info.SchemaVersion, skillID), Incompatible: true}
	}
	if info.Kind != "Skill" || info.ID != skillID || info.Name == "" || info.Description == "" {
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
		return c.baseURL + "/mod/" + escapedID + "/@v/list"
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
	return c.baseURL + "/mod/" + escapedID + "/@v/" + file
}

func (c *Client) latestEndpoint(skillID string) string {
	escapedID, err := modmodule.EscapePath(strings.Trim(skillID, "/"))
	if err != nil {
		escapedID = strings.Trim(skillID, "/")
	}
	return c.baseURL + "/mod/" + escapedID + "/@latest"
}

func (c *Client) getJSON(ctx context.Context, endpoint string, target any) error {
	body, err := c.get(ctx, endpoint)
	if err != nil {
		return err
	}
	if err := json.Unmarshal(body, target); err != nil {
		return &ProtocolError{Err: fmt.Errorf("解析 Hub 响应: %w", err)}
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
		return nil, &HTTPError{
			StatusCode: resp.StatusCode,
			Body:       strings.TrimSpace(string(body)),
			RequestID:  resp.Header.Get("Athens-Request-ID"),
		}
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
