/*
 * [INPUT]: Depends on a configured Hub origin, canonical Repository/Skill IDs, typed add-time Selector resolution through the product API, exact root Proxy resources, typed Repository Info, bounded Repository ZIP responses, and optional progress reporting.
 * [OUTPUT]: Provides two-phase movable-to-immutable Repository resolution/download with path-unique membership validation and deterministic name-or-path member selection; direct exact reads; bounded product reads; discovery/update reads; and typed HTTP or malformed-protocol failures.
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
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/skillsgo/skillsgo/cli/internal/source"
	protocolapi "github.com/skillsgo/skillsgo/protocol/api"
	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
	protocolskillmanifest "github.com/skillsgo/skillsgo/protocol/skillmanifest"
	protocolversion "github.com/skillsgo/skillsgo/protocol/version"
	modmodule "golang.org/x/mod/module"
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

type RepositoryInfo = protocolapi.RepositoryInfo

type RepositoryResource struct {
	Info      RepositoryInfo
	InfoBytes []byte
	Members   []RepositoryMember
	ZIP       []byte
}

// SelectRepositoryMember restores a persisted exact source path when present,
// then falls back to the lexicographically first path among name matches.
func SelectRepositoryMember(selector string, members []RepositoryMember) (RepositoryMember, bool) {
	for _, member := range members {
		if selector == member.Info.SkillPath {
			return member, true
		}
	}
	matches := make([]RepositoryMember, 0, 1)
	for _, member := range members {
		if selector == member.Info.Name {
			matches = append(matches, member)
		}
	}
	if len(matches) > 0 {
		sort.Slice(matches, func(i, j int) bool { return matches[i].Info.SkillPath < matches[j].Info.SkillPath })
		return matches[0], true
	}
	return RepositoryMember{}, false
}

type RepositoryMember struct {
	Info      Info
	InfoBytes []byte
}

type SkillProductMetadata struct {
	RepositoryID          string  `json:"repositoryId"`
	Name                  string  `json:"name"`
	ImageURL              *string `json:"imageUrl"`
	Stars                 int64   `json:"stars"`
	RepositoryDescription string  `json:"repositoryDescription"`
	TrustLevel            string  `json:"trustLevel"`
	RiskAssessment        struct {
		Level Risk `json:"level"`
	} `json:"riskAssessment"`
}

type SkillSummary struct {
	RepositoryID  string `json:"repositoryId"`
	Name          string `json:"name"`
	Repository    string `json:"repository"`
	LatestVersion string `json:"latestVersion"`
}

type skillsResponse struct {
	Skills []SkillSummary `json:"skills"`
}

type SkillCoordinate = protocolapi.SkillCoordinate

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

func (c *Client) Repository(ctx context.Context, repositoryID, query string) (*RepositoryResource, error) {
	selector, err := protocolversion.ParseSelector(query)
	if err != nil {
		return nil, err
	}
	resolved := selector.Value
	if selector.Movable() {
		resolution, resolveErr := c.ResolveRepository(ctx, repositoryID, selector.Value)
		if resolveErr != nil {
			return nil, resolveErr
		}
		resolved = resolution.Version
	}
	infoBytes, err := c.get(ctx, c.endpoint(repositoryID, resolved+".info"))
	if err != nil {
		return nil, err
	}
	resource, err := ParseRepositoryInfo(repositoryID, infoBytes)
	if err != nil {
		return nil, err
	}
	if resource.Info.Version != resolved {
		return nil, &ProtocolError{Err: fmt.Errorf("Hub returned Repository Info for unexpected immutable version %s", resource.Info.Version)}
	}
	return resource, nil
}

func (c *Client) ResolveRepository(ctx context.Context, repositoryID, selector string) (protocolapi.RepositoryResolutionResponse, error) {
	parsed, err := protocolversion.ParseSelector(selector)
	if err != nil {
		return protocolapi.RepositoryResolutionResponse{}, err
	}
	request := protocolapi.RepositoryResolutionRequest{SchemaVersion: protocolapi.SchemaVersion, RepositoryID: repositoryID, Selector: parsed.Value}
	var response protocolapi.RepositoryResolutionResponse
	if err := c.postJSON(ctx, "/api/v1/repository-resolutions", request, &response); err != nil {
		return response, err
	}
	if response.SchemaVersion != protocolapi.SchemaVersion || response.RepositoryID != repositoryID ||
		!protocolversion.IsImmutable(response.Version) || response.Time.IsZero() || response.Ref == "" || response.CommitSHA == "" {
		return response, &ProtocolError{Err: fmt.Errorf("Hub returned invalid Repository resolution for %s", repositoryID)}
	}
	return response, nil
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

func ParseRepositoryInfo(repositoryID string, infoBytes []byte) (*RepositoryResource, error) {
	if err := source.ValidateRepositoryID(repositoryID); err != nil {
		return nil, err
	}
	var info RepositoryInfo
	if err := json.Unmarshal(infoBytes, &info); err != nil {
		return nil, &ProtocolError{Err: fmt.Errorf("decode Repository Info: %w", err)}
	}
	if info.SchemaVersion != 1 {
		return nil, &ProtocolError{Err: fmt.Errorf("Hub returned unsupported Repository Info schema %d for %s", info.SchemaVersion, repositoryID), Incompatible: true}
	}
	if info.Kind != "Repository" || info.ID != repositoryID ||
		info.Version == "" || info.Ref == "" || info.CommitSHA == "" || info.TreeSHA == "" ||
		!protocolartifact.ValidSum(info.Sum) || info.ArchiveSize <= 0 || len(info.Skills) == 0 {
		return nil, fmt.Errorf("Hub returned incomplete Repository Info for %s", repositoryID)
	}
	if err := source.ValidateVersion(info.Version); err != nil {
		return nil, fmt.Errorf("Hub returned invalid Repository version for %s: %w", repositoryID, err)
	}
	resource := &RepositoryResource{Info: info, InfoBytes: append([]byte(nil), infoBytes...), Members: make([]RepositoryMember, 0, len(info.Skills))}
	seenPaths := map[string]bool{}
	for _, member := range info.Skills {
		validPath := member.SkillPath == "." || protocolartifact.ValidRelativePath(member.SkillPath)
		if !protocolskillmanifest.ValidName(member.Name) || !validPath || seenPaths[member.SkillPath] || member.RepositoryID != repositoryID || member.Version != info.Version || member.CommitSHA != info.CommitSHA || member.Ref != info.Ref {
			return nil, fmt.Errorf("Repository Info contains inconsistent Skill %q", member.Name)
		}
		if err := validateAssessedInfo(repositoryID, member.Name, info.Version, member); err != nil {
			return nil, err
		}
		seenPaths[member.SkillPath] = true
		memberBytes, err := json.Marshal(member)
		if err != nil {
			return nil, fmt.Errorf("encode Repository member Info: %w", err)
		}
		resource.Members = append(resource.Members, RepositoryMember{Info: member, InfoBytes: memberBytes})
	}
	return resource, nil
}

func (c *Client) SkillProduct(ctx context.Context, repositoryID, name string) (SkillProductMetadata, error) {
	var metadata SkillProductMetadata
	query := url.Values{"repositoryId": []string{repositoryID}, "name": []string{name}}
	if err := c.getJSON(ctx, c.baseURL+"/api/v1/skills/detail?"+query.Encode(), &metadata); err != nil {
		return SkillProductMetadata{}, err
	}
	if metadata.RepositoryID != repositoryID || metadata.Name != name {
		return SkillProductMetadata{}, fmt.Errorf("Hub returned mismatched Skill product metadata for %s:%s", repositoryID, name)
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
		path = "/api/v1/find"
		query.Set("q", search)
	} else {
		query.Set("sort", collection)
	}
	return c.readProductJSON(ctx, path, query)
}

func (c *Client) FindLocalized(ctx context.Context, search, source, locale string, exactName bool, offset, limit int) (json.RawMessage, error) {
	query := url.Values{"q": {search}, "offset": {fmt.Sprint(offset)}, "limit": {fmt.Sprint(limit)}}
	if strings.TrimSpace(source) != "" {
		query.Set("source", strings.TrimSpace(source))
	}
	if strings.TrimSpace(locale) != "" {
		query.Set("locale", strings.TrimSpace(locale))
	}
	if exactName {
		query.Set("exactName", "true")
	}
	return c.readProductJSON(ctx, "/api/v1/find", query)
}

func (c *Client) FindBatch(ctx context.Context, request protocolapi.FindRequest) (json.RawMessage, error) {
	body, err := json.Marshal(request)
	if err != nil {
		return nil, err
	}
	httpRequest, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/api/v1/find", bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	httpRequest.Header.Set("Content-Type", "application/json")
	response, err := c.http.Do(httpRequest)
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
	if !json.Valid(encoded) {
		return nil, &ProtocolError{Err: fmt.Errorf("Hub returned an invalid Find response")}
	}
	return json.RawMessage(encoded), nil
}

func (c *Client) Detail(ctx context.Context, repositoryID, name string) (json.RawMessage, error) {
	return c.DetailLocalized(ctx, repositoryID, name, "")
}

func (c *Client) DetailLocalized(ctx context.Context, repositoryID, name, locale string) (json.RawMessage, error) {
	query := url.Values{"repositoryId": []string{repositoryID}, "name": []string{name}}
	if strings.TrimSpace(locale) != "" {
		query.Set("locale", strings.TrimSpace(locale))
	}
	return c.readProductJSON(ctx, "/api/v1/skills/detail", query)
}

func (c *Client) BatchSkills(ctx context.Context, skills []SkillCoordinate) (json.RawMessage, error) {
	if len(skills) == 0 || len(skills) > 100 {
		return nil, fmt.Errorf("Skill batch must contain 1 to 100 coordinates")
	}
	for _, coordinate := range skills {
		if err := source.ValidateRepositoryID(coordinate.RepositoryID); err != nil || !protocolskillmanifest.ValidName(coordinate.Name) {
			return nil, fmt.Errorf("invalid Skill coordinate %q:%q", coordinate.RepositoryID, coordinate.Name)
		}
	}
	body, err := json.Marshal(struct {
		Skills []SkillCoordinate `json:"skills"`
	}{Skills: skills})
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

func (c *Client) CatalogUpdates(ctx context.Context, skills []SkillCoordinate) ([]CatalogUpdateItem, error) {
	requestBody, err := json.Marshal(struct {
		SchemaVersion int               `json:"schemaVersion"`
		Skills        []SkillCoordinate `json:"skills"`
	}{SchemaVersion: 1, Skills: skills})
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
	if json.Unmarshal(body, &decoded) != nil || decoded.SchemaVersion != 1 || len(decoded.Items) != len(skills) {
		return nil, &ProtocolError{Err: fmt.Errorf("Hub returned an invalid Catalog update response")}
	}
	for index, item := range decoded.Items {
		if item.RepositoryID != skills[index].RepositoryID || item.Name != skills[index].Name || (item.Status != "available" && item.Status != "unsupported") ||
			(item.Status == "available" && item.HeadVersion == "" && item.ReleaseVersion == "") ||
			(item.HeadVersion != "" && !protocolversion.IsImmutable(item.HeadVersion)) ||
			(item.ReleaseVersion != "" && !protocolversion.IsImmutable(item.ReleaseVersion)) {
			return nil, &ProtocolError{Err: fmt.Errorf("Hub returned an invalid Catalog update item")}
		}
	}
	return decoded.Items, nil
}

func validateAssessedInfo(repositoryID, skillName, requestedVersion string, info Info) error {
	if info.Version == "" || info.RepositoryID == "" || info.SkillPath == "" || (info.Risk != "" && !info.Risk.Valid()) {
		return fmt.Errorf("Hub returned incomplete immutable Info for %s:%s", repositoryID, skillName)
	}
	if info.SchemaVersion != 1 {
		return &ProtocolError{Err: fmt.Errorf("Hub returned unsupported Info schema %d for %s:%s", info.SchemaVersion, repositoryID, skillName), Incompatible: true}
	}
	if info.Kind != "Skill" || info.RepositoryID != repositoryID || info.Name != skillName || info.Description == "" {
		return fmt.Errorf("Hub returned incomplete immutable Info for %s:%s", repositoryID, skillName)
	}
	if err := source.ValidateVersion(info.Version); err != nil {
		return fmt.Errorf("Hub returned an invalid immutable version for %s:%s: %w", repositoryID, skillName, err)
	}
	if protocolversion.IsImmutable(requestedVersion) && info.Version != requestedVersion {
		return fmt.Errorf(
			"Hub resolved %s@%s as unexpected immutable version %s",
			repositoryID+":"+skillName, requestedVersion, info.Version,
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

func (c *Client) postJSON(ctx context.Context, path string, source, target any) error {
	encoded, err := json.Marshal(source)
	if err != nil {
		return err
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+path, bytes.NewReader(encoded))
	if err != nil {
		return err
	}
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Accept", "application/json")
	response, err := c.http.Do(request)
	if err != nil {
		return err
	}
	defer response.Body.Close()
	body, readErr := io.ReadAll(io.LimitReader(response.Body, 1<<20))
	if readErr != nil {
		return readErr
	}
	if response.StatusCode != http.StatusOK {
		return &HTTPError{StatusCode: response.StatusCode, Body: strings.TrimSpace(string(body)), RequestID: response.Header.Get("X-Request-ID")}
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
