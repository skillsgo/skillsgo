/*
 * [INPUT]: Depends on a configured Hub origin, canonical Repository/Skill IDs, Hub-owned selector resolution, exact content-match responses, typed Repository Info, bounded Repository ZIP responses, and optional progress reporting.
 * [OUTPUT]: Provides root Repository Proxy resolution/download with identity, membership, size, and h1 validation; bounded product reads; discovery/update reads; and typed HTTP or malformed-protocol failures.
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
	"strconv"
	"strings"
	"time"

	"github.com/skillsgo/skillsgo/cli/internal/source"
	protocolapi "github.com/skillsgo/skillsgo/protocol/api"
	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
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
	ZIP       []byte
}

type RepositoryMember struct {
	Info      Info
	InfoBytes []byte
}

type ContentMatch = protocolapi.ContentMatch

type SkillProductMetadata struct {
	ID                    string  `json:"id"`
	ImageURL              *string `json:"imageUrl"`
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
		query = "head"
	}
	resolved, err := c.resolveSelector(ctx, repositoryID, query)
	if err != nil {
		return nil, err
	}
	query = resolved
	infoBytes, err := c.get(ctx, c.endpoint(repositoryID, query+".info"))
	if err != nil {
		return nil, err
	}
	return ParseRepositoryInfo(repositoryID, infoBytes)
}

func (c *Client) FetchRepositoryWithProgress(ctx context.Context, repositoryID, query string, progress func(current, total int64)) (*RepositoryResource, error) {
	resource, err := c.Repository(ctx, repositoryID, query)
	if err != nil {
		return nil, err
	}
	archive, err := c.getWithProgress(ctx, c.endpoint(repositoryID, resource.Info.Version+".zip"), progress)
	if err != nil {
		return nil, err
	}
	if resource.Info.ArchiveSize != int64(len(archive)) {
		return nil, fmt.Errorf("Hub returned an unexpected Repository Archive Size for %s@%s", repositoryID, resource.Info.Version)
	}
	if err := VerifyRepositorySum(archive, repositoryID, resource.Info.Version, resource.Info.Sum); err != nil {
		return nil, err
	}
	resource.ZIP = archive
	return resource, nil
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

func ParseRepositoryInfo(repositoryID string, infoBytes []byte) (*RepositoryResource, error) {
	var info RepositoryInfo
	if err := json.Unmarshal(infoBytes, &info); err != nil {
		return nil, fmt.Errorf("解析 Repository Info: %w", err)
	}
	if info.SchemaVersion != 1 || info.Kind != "Repository" || info.ID != repositoryID ||
		info.Version == "" || info.Ref == "" || info.CommitSHA == "" || info.TreeSHA == "" ||
		!protocolartifact.ValidSum(info.Sum) || info.ArchiveSize <= 0 || len(info.Skills) == 0 {
		return nil, fmt.Errorf("Hub returned incomplete Repository Info for %s", repositoryID)
	}
	if err := source.ValidateVersion(info.Version); err != nil {
		return nil, fmt.Errorf("Hub returned invalid Repository version for %s: %w", repositoryID, err)
	}
	resource := &RepositoryResource{Info: info, InfoBytes: append([]byte(nil), infoBytes...), Members: make([]RepositoryMember, 0, len(info.Skills))}
	seen := map[string]bool{}
	prefix := strings.TrimSuffix(repositoryID, "/") + "/-/"
	for _, member := range info.Skills {
		if member.ID != repositoryID && !strings.HasPrefix(member.ID, prefix) {
			return nil, fmt.Errorf("Repository Info contains foreign Skill %q", member.ID)
		}
		if seen[member.ID] || member.RepositoryID != repositoryID || member.Path == "" || member.Version != info.Version || member.CommitSHA != info.CommitSHA || member.Ref != info.Ref {
			return nil, fmt.Errorf("Repository Info contains inconsistent Skill %q", member.ID)
		}
		if err := validateAssessedInfo(member.ID, info.Version, member); err != nil {
			return nil, err
		}
		seen[member.ID] = true
		memberBytes, err := json.Marshal(member)
		if err != nil {
			return nil, fmt.Errorf("encode Repository member Info: %w", err)
		}
		resource.Members = append(resource.Members, RepositoryMember{Info: member, InfoBytes: memberBytes})
	}
	return resource, nil
}

func (c *Client) FetchRepositoryMember(ctx context.Context, member RepositoryMember, progress func(current, total int64)) (*Artifact, error) {
	return nil, fmt.Errorf("Skill %s is a Repository member and has no independent ZIP", member.Info.ID)
}

func (c *Client) FetchWithProgress(ctx context.Context, skillID, requestedVersion string, progress func(current, total int64)) (*Artifact, error) {
	if requestedVersion == "" {
		requestedVersion = "head"
	}
	resolvedVersion, err := c.resolveSelector(ctx, skillID, requestedVersion)
	if err != nil {
		return nil, err
	}
	infoBytes, err := c.get(ctx, c.endpoint(skillID, resolvedVersion+".info"))
	if err != nil {
		return nil, err
	}
	var info Info
	if err := json.Unmarshal(infoBytes, &info); err != nil {
		return nil, fmt.Errorf("解析 Hub 响应: %w", err)
	}
	if err := validateAssessedInfo(skillID, resolvedVersion, info); err != nil {
		return nil, err
	}
	return nil, fmt.Errorf("Skill %s is a Repository member and has no independent ZIP", skillID)
}

func (c *Client) Resolve(ctx context.Context, skillID, requestedVersion string) (Info, error) {
	if requestedVersion == "" {
		requestedVersion = "head"
	}
	resolvedVersion, err := c.resolveSelector(ctx, skillID, requestedVersion)
	if err != nil {
		return Info{}, err
	}
	var info Info
	if err := c.getJSON(ctx, c.endpoint(skillID, resolvedVersion+".info"), &info); err != nil {
		return Info{}, err
	}
	if err := validateAssessedInfo(skillID, resolvedVersion, info); err != nil {
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

func (c *Client) BatchSkills(ctx context.Context, skillIDs []string) (json.RawMessage, error) {
	if len(skillIDs) == 0 || len(skillIDs) > 100 {
		return nil, fmt.Errorf("Skill batch must contain 1 to 100 IDs")
	}
	for _, skillID := range skillIDs {
		if err := source.ValidateSkillID(skillID); err != nil {
			return nil, err
		}
	}
	body, err := json.Marshal(struct {
		SkillIDs []string `json:"skillIds"`
	}{SkillIDs: skillIDs})
	if err != nil {
		return nil, err
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/api/v1/skills/batch", bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	request.Header.Set("Content-Type", "application/json")
	response, err := c.http.Do(request)
	if err != nil {
		return nil, fmt.Errorf("请求 Hub: %w", err)
	}
	defer response.Body.Close()
	encoded, err := io.ReadAll(io.LimitReader(response.Body, 4<<20))
	if err != nil {
		return nil, err
	}
	if response.StatusCode != http.StatusOK {
		return nil, &HTTPError{StatusCode: response.StatusCode, Body: strings.TrimSpace(string(encoded)), RequestID: response.Header.Get("Athens-Request-ID")}
	}
	var document json.RawMessage
	if json.Unmarshal(encoded, &document) != nil || !json.Valid(document) {
		return nil, &ProtocolError{Err: fmt.Errorf("Hub returned an invalid Skill batch response")}
	}
	return document, nil
}

func (c *Client) Check(ctx context.Context) (json.RawMessage, error) {
	return c.Discover(ctx, "search", "skillsgo-settings-probe", 0, 1)
}

func (c *Client) HubInfo(ctx context.Context) (json.RawMessage, error) {
	var document json.RawMessage
	if err := c.getJSON(ctx, c.baseURL+"/info", &document); err != nil {
		return nil, err
	}
	if !json.Valid(document) || len(document) == 0 {
		return nil, fmt.Errorf("Hub returned invalid JSON")
	}
	return document, nil
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
		if item.SkillID != skillIDs[index] || (item.Status != "available" && item.Status != "unsupported") ||
			(item.Status == "available" && item.HeadVersion == "" && item.ReleaseVersion == "") ||
			(item.HeadVersion != "" && !protocolversion.IsImmutable(item.HeadVersion)) ||
			(item.ReleaseVersion != "" && !protocolversion.IsImmutable(item.ReleaseVersion)) {
			return nil, &ProtocolError{Err: fmt.Errorf("Hub returned an invalid Catalog update item")}
		}
	}
	return decoded.Items, nil
}

func validateAssessedInfo(skillID, requestedVersion string, info Info) error {
	if info.Version == "" || info.RepositoryID == "" || info.Path == "" || (info.Risk != "" && !info.Risk.Valid()) {
		return fmt.Errorf("Hub returned incomplete immutable Info for %s", skillID)
	}
	if info.SchemaVersion != 1 {
		return &ProtocolError{Err: fmt.Errorf("Hub returned unsupported Info schema %d for %s", info.SchemaVersion, skillID), Incompatible: true}
	}
	if info.Kind != "Skill" || info.ID != skillID || info.Name == "" || info.Description == "" {
		return fmt.Errorf("Hub returned incomplete immutable Info for %s", skillID)
	}
	if err := source.ValidateVersion(info.Version); err != nil {
		return fmt.Errorf("Hub returned an invalid immutable version for %s: %w", skillID, err)
	}
	if protocolversion.IsImmutable(requestedVersion) && info.Version != requestedVersion {
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

func (c *Client) selectorEndpoint(skillID, selector string) string {
	escapedID, err := modmodule.EscapePath(strings.Trim(skillID, "/"))
	if err != nil {
		escapedID = strings.Trim(skillID, "/")
	}
	return c.baseURL + "/" + escapedID + "/@" + selector
}

func (c *Client) resolveSelector(ctx context.Context, skillID, requested string) (string, error) {
	if requested != "head" && requested != "release" {
		return requested, nil
	}
	var resolved struct {
		Version string    `json:"Version"`
		Time    time.Time `json:"Time"`
	}
	if err := c.getJSON(ctx, c.selectorEndpoint(skillID, requested), &resolved); err != nil {
		return "", err
	}
	if !protocolversion.IsImmutable(resolved.Version) || resolved.Time.IsZero() {
		return "", &ProtocolError{Err: fmt.Errorf("Hub returned invalid %s Selector result for %s", requested, skillID)}
	}
	return resolved.Version, nil
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
	resp, err := c.retryingGet(ctx, endpoint)
	if err != nil {
		return nil, err
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
	if resp.ContentLength > protocolartifact.MaxArchiveBytes {
		return nil, &ProtocolError{Err: fmt.Errorf("Hub response exceeds %d bytes", protocolartifact.MaxArchiveBytes)}
	}
	reader := io.Reader(resp.Body)
	if progress != nil {
		reader = &progressReader{reader: resp.Body, total: resp.ContentLength, progress: progress}
	}
	body, err := io.ReadAll(io.LimitReader(reader, protocolartifact.MaxArchiveBytes+1))
	if err != nil {
		return nil, err
	}
	if len(body) > protocolartifact.MaxArchiveBytes {
		return nil, &ProtocolError{Err: fmt.Errorf("Hub response exceeds %d bytes", protocolartifact.MaxArchiveBytes)}
	}
	return body, nil
}

func (c *Client) retryingGet(ctx context.Context, endpoint string) (*http.Response, error) {
	const attempts = 3
	for attempt := 0; attempt < attempts; attempt++ {
		req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
		if err != nil {
			return nil, err
		}
		resp, err := c.http.Do(req)
		if err != nil {
			return nil, fmt.Errorf("请求 Hub: %w", err)
		}
		if !retryableGETStatus(resp.StatusCode) || attempt == attempts-1 {
			return resp, nil
		}
		delay := retryDelay(resp.Header.Get("Retry-After"), attempt)
		_, _ = io.Copy(io.Discard, io.LimitReader(resp.Body, 4096))
		_ = resp.Body.Close()
		timer := time.NewTimer(delay)
		select {
		case <-ctx.Done():
			timer.Stop()
			return nil, ctx.Err()
		case <-timer.C:
		}
	}
	panic("unreachable")
}

func retryableGETStatus(status int) bool {
	return status == http.StatusTooManyRequests || status == http.StatusBadGateway ||
		status == http.StatusServiceUnavailable || status == http.StatusGatewayTimeout
}

func retryDelay(header string, attempt int) time.Duration {
	const maximum = 5 * time.Second
	if seconds, err := strconv.Atoi(strings.TrimSpace(header)); err == nil && seconds >= 0 {
		delay := time.Duration(seconds) * time.Second
		if delay > maximum {
			return maximum
		}
		return delay
	}
	if when, err := http.ParseTime(header); err == nil {
		delay := time.Until(when)
		if delay < 0 {
			return 0
		}
		if delay > maximum {
			return maximum
		}
		return delay
	}
	return time.Duration(attempt+1) * 100 * time.Millisecond
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
