/*
 * [INPUT]: Depends on a configured Hub origin, canonical Module/Skill identities, typed add-time Version Queries through unified Module metadata, exact Module Version resources, typed Module Info, bounded Module ZIP responses, and optional progress reporting.
 * [OUTPUT]: Provides single-read revision-to-immutable Module metadata resolution, canonical downloads, direct Module Version Skill content reads, path-unique membership validation and deterministic member selection, discovery/update reads, and typed HTTP or malformed-protocol failures.
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

type Info = protocolapi.ModuleSkill
type ModuleInfo = protocolapi.ModuleInfo

type ModuleResource struct {
	Info      ModuleInfo
	InfoBytes []byte
	Members   []VersionSkill
	ZIP       []byte
}

// SelectVersionSkill restores a persisted exact source path when present,
// then falls back to the lexicographically first path among name matches.
func SelectVersionSkill(selector string, members []VersionSkill) (VersionSkill, bool) {
	for _, member := range members {
		if selector == member.Info.Path {
			return member, true
		}
	}
	matches := make([]VersionSkill, 0, 1)
	for _, member := range members {
		if selector == member.Info.Name {
			matches = append(matches, member)
		}
	}
	if len(matches) > 0 {
		sort.Slice(matches, func(i, j int) bool { return matches[i].Info.Path < matches[j].Info.Path })
		return matches[0], true
	}
	return VersionSkill{}, false
}

type VersionSkill struct {
	Info Info
}

type SkillSummary struct {
	ModulePath    string `json:"modulePath"`
	Name          string `json:"name"`
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

func (c *Client) Module(ctx context.Context, modulePath, query string) (*ModuleResource, error) {
	parsedQuery, err := protocolversion.ParseQuery(query)
	if err != nil {
		return nil, err
	}
	infoBytes, err := c.get(ctx, c.versionEndpoint(modulePath, parsedQuery.Value, false))
	if err != nil {
		return nil, err
	}
	resource, err := ParseModuleInfo(modulePath, infoBytes)
	if err != nil {
		return nil, err
	}
	if !protocolversion.IsImmutable(resource.Info.Version) || (!parsedQuery.Movable() && resource.Info.Version != parsedQuery.Value) {
		return nil, &ProtocolError{Err: fmt.Errorf("Hub returned Module Info for unexpected immutable version %s", resource.Info.Version)}
	}
	return resource, nil
}

func (c *Client) FetchModuleWithProgress(ctx context.Context, modulePath, query string, progress func(current, total int64)) (*ModuleResource, error) {
	resource, err := c.Module(ctx, modulePath, query)
	if err != nil {
		return nil, err
	}
	archive, err := c.getWithProgress(ctx, c.versionEndpoint(modulePath, resource.Info.Version, true), progress)
	if err != nil {
		return nil, err
	}
	if resource.Info.ArchiveSize != int64(len(archive)) {
		return nil, fmt.Errorf("Hub returned an unexpected Module Archive Size for %s@%s", modulePath, resource.Info.Version)
	}
	if err := VerifyModuleSum(archive, modulePath, resource.Info.Version, resource.Info.Sum); err != nil {
		return nil, err
	}
	resource.ZIP = archive
	return resource, nil
}

func ParseModuleInfo(modulePath string, infoBytes []byte) (*ModuleResource, error) {
	if err := source.ValidateModulePath(modulePath); err != nil {
		return nil, err
	}
	var info ModuleInfo
	if err := json.Unmarshal(infoBytes, &info); err != nil {
		return nil, &ProtocolError{Err: fmt.Errorf("decode Module Info: %w", err)}
	}
	if info.SchemaVersion != 1 {
		return nil, &ProtocolError{Err: fmt.Errorf("Hub returned unsupported Module Info schema %d for %s", info.SchemaVersion, modulePath), Incompatible: true}
	}
	if info.Kind != protocolapi.KindModule || info.ModulePath != modulePath ||
		info.Version == "" || info.Time.IsZero() ||
		!protocolartifact.ValidSum(info.Sum) || info.ArchiveSize <= 0 || len(info.Skills) == 0 {
		return nil, fmt.Errorf("Hub returned incomplete Module Info for %s", modulePath)
	}
	if err := source.ValidateVersion(info.Version); err != nil {
		return nil, fmt.Errorf("Hub returned invalid Module Version for %s: %w", modulePath, err)
	}
	resource := &ModuleResource{Info: info, InfoBytes: append([]byte(nil), infoBytes...), Members: make([]VersionSkill, 0, len(info.Skills))}
	seenPaths := map[string]bool{}
	for _, member := range info.Skills {
		validPath := member.Path == "." || protocolartifact.ValidRelativePath(member.Path)
		if !protocolskillmanifest.ValidName(member.Name) || !validPath || seenPaths[member.Path] {
			return nil, fmt.Errorf("Module Info contains inconsistent Skill %q", member.Name)
		}
		seenPaths[member.Path] = true
		resource.Members = append(resource.Members, VersionSkill{Info: member})
	}
	return resource, nil
}

func (c *Client) ModuleVersionSkill(ctx context.Context, modulePath, version, skillPath string) (protocolapi.ModuleVersionSkill, error) {
	var result protocolapi.ModuleVersionSkill
	endpoint := c.versionEndpoint(modulePath, version, false) + "/skills?" + url.Values{"path": []string{skillPath}}.Encode()
	if err := c.getJSON(ctx, endpoint, &result); err != nil {
		return result, err
	}
	if result.ModulePath != modulePath || !protocolversion.IsImmutable(result.Version) || result.Name == "" || result.Path != skillPath || result.Time.IsZero() || result.ArchiveSize <= 0 {
		return result, &ProtocolError{Err: fmt.Errorf("Hub returned invalid Module Version Skill for %s@%s:%s", modulePath, version, skillPath)}
	}
	return result, nil
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

func (c *Client) Discover(ctx context.Context, collection, search string, page, perPage int) (json.RawMessage, error) {
	return c.DiscoverLocalized(ctx, collection, search, "", page, perPage)
}

func (c *Client) DiscoverLocalized(ctx context.Context, collection, search, locale string, page, perPage int) (json.RawMessage, error) {
	query := url.Values{"page": {fmt.Sprint(page)}, "perPage": {fmt.Sprint(perPage)}}
	if strings.TrimSpace(locale) != "" {
		query.Set("locale", strings.TrimSpace(locale))
	}
	path := "/api/v1/skills"
	if collection == "search" {
		path = "/api/v1/skills/find"
		query.Set("q", search)
	} else {
		query.Set("sort", collection)
	}
	return c.readProductJSON(ctx, path, query)
}

func (c *Client) FindLocalized(ctx context.Context, search, modulePath, locale string, exactName bool, page, perPage int) (json.RawMessage, error) {
	query := url.Values{"q": {search}, "page": {fmt.Sprint(page)}, "perPage": {fmt.Sprint(perPage)}}
	if strings.TrimSpace(modulePath) != "" {
		query.Set("modulePath", strings.TrimSpace(modulePath))
	}
	if strings.TrimSpace(locale) != "" {
		query.Set("locale", strings.TrimSpace(locale))
	}
	if exactName {
		query.Set("exactName", "true")
	}
	return c.readProductJSON(ctx, "/api/v1/skills/find", query)
}

func (c *Client) FindBatch(ctx context.Context, request protocolapi.FindCandidatesRequest) (json.RawMessage, error) {
	body, err := json.Marshal(request)
	if err != nil {
		return nil, err
	}
	httpRequest, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/api/v1/skills/find-candidates", bytes.NewReader(body))
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

func (c *Client) Detail(ctx context.Context, modulePath, version, skillPath string) (json.RawMessage, error) {
	return c.DetailLocalized(ctx, modulePath, version, skillPath, "")
}

func (c *Client) DetailLocalized(ctx context.Context, modulePath, version, skillPath, _ string) (json.RawMessage, error) {
	result, err := c.ModuleVersionSkill(ctx, modulePath, version, skillPath)
	if err != nil {
		return nil, err
	}
	return json.Marshal(result)
}

func (c *Client) BatchSkills(ctx context.Context, skills []SkillCoordinate) (json.RawMessage, error) {
	if len(skills) == 0 || len(skills) > 100 {
		return nil, fmt.Errorf("Skill batch must contain 1 to 100 coordinates")
	}
	for _, coordinate := range skills {
		if err := source.ValidateModulePath(coordinate.ModulePath); err != nil || !protocolskillmanifest.ValidName(coordinate.Name) {
			return nil, fmt.Errorf("invalid Skill coordinate %q:%q", coordinate.ModulePath, coordinate.Name)
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
	request, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/api/v1/skills/check-update", bytes.NewReader(requestBody))
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
	if json.Unmarshal(body, &decoded) != nil || len(decoded.Items) != len(skills) {
		return nil, &ProtocolError{Err: fmt.Errorf("Hub returned an invalid Catalog update response")}
	}
	for index, item := range decoded.Items {
		if item.ModulePath != skills[index].ModulePath || item.Name != skills[index].Name || (item.Status != "available" && item.Status != "unsupported") ||
			(item.Status == "available" && item.LatestVersion == "") ||
			(item.LatestVersion != "" && !protocolversion.IsImmutable(item.LatestVersion)) {
			return nil, &ProtocolError{Err: fmt.Errorf("Hub returned an invalid Catalog update item")}
		}
	}
	return decoded.Items, nil
}

func (c *Client) versionEndpoint(modulePath, revision string, archive bool) string {
	escapedID, err := modmodule.EscapePath(strings.Trim(modulePath, "/"))
	if err != nil {
		// Canonical IDs have already crossed the source parser boundary. Keep
		// this helper total while allowing the Router to reject impossible IDs.
		escapedID = strings.Trim(modulePath, "/")
	}
	escapedVersion, escapeErr := modmodule.EscapeVersion(revision)
	if escapeErr == nil {
		revision = escapedVersion
	} else {
		revision = url.PathEscape(revision)
	}
	suffix := ""
	if archive {
		suffix = ".zip"
	}
	return c.baseURL + "/api/v1/" + escapedID + "/versions/" + revision + suffix
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
