/*
 * [INPUT]: Depends on Repository Catalog cache state, GitHub's conditional REST resource, the Hub task runtime, an optional bearer-token pool, and bounded HTTP requests.
 * [OUTPUT]: Provides publication-triggered and periodic background Repository descriptions and Stars refresh with durable retry, TTL, ETag, token failover, and rate-limit backoff.
 * [POS]: Serves as the asynchronous source-metadata maintenance service and River task handlers; public read requests never access this component.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"slices"
	"strconv"
	"strings"
	"sync/atomic"
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	"github.com/skillsgo/skillsgo/hub/pkg/taskqueue"
	"golang.org/x/sync/singleflight"
)

const (
	maxGitHubErrorBodyBytes  = 32 << 10
	sourceMetadataTTL        = 18 * time.Hour
	sourceMetadataSweepEvery = time.Hour
	sourceMetadataSweepBatch = 500
)

type repositoryMetadata struct {
	Description string
	Stars       int64
	ETag        string
	NotModified bool
}

type repositoryMetadataSource interface {
	Host() string
	Read(context.Context, string, string, string) (repositoryMetadata, error)
}

type repositoryMetadataRefresher struct {
	catalog *catalog.Catalog
	sources map[string]repositoryMetadataSource
	ttl     time.Duration
	now     func() time.Time
	refresh singleflight.Group
	tasks   *taskqueue.Runtime
}

type githubRepositoryMetadataReader struct {
	client *http.Client
	tokens []string
	active atomic.Uint64
}

type githubMetadataHTTPError struct {
	statusCode     int
	status         string
	message        string
	documentation  string
	requestID      string
	rateLimit      string
	rateRemaining  string
	rateReset      string
	retryAfter     string
	authConfigured bool
	duration       time.Duration
}

func (e *githubMetadataHTTPError) Error() string {
	if e.message != "" {
		return fmt.Sprintf("github repository metadata returned %s: %s", e.status, e.message)
	}
	return fmt.Sprintf("github repository metadata returned %s", e.status)
}

func (e *githubMetadataHTTPError) LogFields() map[string]any {
	return map[string]any{
		"auth_configured":           e.authConfigured,
		"dependency":                "github_api",
		"duration_ms":               e.duration.Milliseconds(),
		"documentation_url":         e.documentation,
		"github_request_id":         e.requestID,
		"rate_limit":                e.rateLimit,
		"rate_limit_remaining":      e.rateRemaining,
		"rate_limit_reset_at":       githubRateResetTime(e.rateReset),
		"retry_after":               e.retryAfter,
		"upstream_error_kind":       githubHTTPErrorKind(e.statusCode, e.rateRemaining),
		"upstream_response_message": e.message,
		"upstream_status":           e.statusCode,
	}
}

func newGitHubRepositoryMetadataReader(tokens []string) repositoryMetadataSource {
	return &githubRepositoryMetadataReader{
		client: &http.Client{Timeout: 4 * time.Second},
		tokens: normalizedGitHubTokens(tokens),
	}
}

func normalizedGitHubTokens(candidates []string) []string {
	seen := make(map[string]struct{}, len(candidates))
	tokens := make([]string, 0, len(candidates))
	for _, candidate := range candidates {
		token := strings.TrimSpace(candidate)
		if token == "" {
			continue
		}
		if _, exists := seen[token]; exists {
			continue
		}
		seen[token] = struct{}{}
		tokens = append(tokens, token)
	}
	return tokens
}

func (r *githubRepositoryMetadataReader) tokenAt(start, offset uint64) string {
	if len(r.tokens) == 0 {
		return ""
	}
	return r.tokens[(start+offset)%uint64(len(r.tokens))]
}

func (r *githubRepositoryMetadataReader) Host() string { return "github.com" }

func newQueuedRepositoryMetadataRefresher(metadata *catalog.Catalog, tasks *taskqueue.Runtime, sources ...repositoryMetadataSource) *repositoryMetadataRefresher {
	return newRepositoryMetadataRefresherWithRuntime(metadata, tasks, sources...)
}

func newRepositoryMetadataRefresherWithRuntime(metadata *catalog.Catalog, tasks *taskqueue.Runtime, sources ...repositoryMetadataSource) *repositoryMetadataRefresher {
	byHost := make(map[string]repositoryMetadataSource, len(sources))
	for _, source := range sources {
		byHost[strings.ToLower(strings.TrimSpace(source.Host()))] = source
	}
	return &repositoryMetadataRefresher{catalog: metadata, sources: byHost, ttl: sourceMetadataTTL, now: time.Now, tasks: tasks}
}

func (c *repositoryMetadataRefresher) RegisterTasks() error {
	if c.tasks == nil {
		return fmt.Errorf("repository metadata task runtime is required")
	}
	if err := taskqueue.Register(c.tasks, func(ctx context.Context, args repositorySourceMetadataRefreshArgs) error {
		parts := strings.SplitN(args.PackagePath, "/", 2)
		if len(parts) != 2 || parts[0] == "" || parts[1] == "" {
			return fmt.Errorf("invalid repository id %q", args.PackagePath)
		}
		stored, err := c.catalog.Package(ctx, args.PackagePath)
		if err != nil {
			return err
		}
		_, err = c.refreshNow(ctx, parts[0], parts[1], args.PackagePath, stored)
		return err
	}); err != nil {
		return err
	}
	if err := taskqueue.Register(c.tasks, func(ctx context.Context, _ repositorySourceMetadataSweepArgs) error {
		return c.enqueueDue(ctx)
	}); err != nil {
		return err
	}
	return c.tasks.Every(repositorySourceMetadataSweepArgs{}, taskqueue.InsertOptions{Unique: true, MaxAttempts: 3, Queue: taskqueue.QueueMaintenance}, sourceMetadataSweepEvery, false)
}

// RefreshInitial only submits durable work after a Package becomes visible.
// Publication never performs provider I/O.
func (c *repositoryMetadataRefresher) RefreshInitial(ctx context.Context, packagePath string) {
	if err := c.tasks.EnqueueAsync(ctx, repositorySourceMetadataRefreshArgs{PackagePath: packagePath}, taskqueue.InsertOptions{Unique: true, MaxAttempts: 8, Queue: taskqueue.QueueMaintenance}); err != nil {
		log.EntryFromContext(ctx).WithFields(map[string]any{
			"error": err.Error(), "package_path": packagePath,
		}).Warnf("initial repository metadata refresh submission failed")
	}
}

func (c *repositoryMetadataRefresher) enqueueDue(ctx context.Context) error {
	hosts := make([]string, 0, len(c.sources))
	for host := range c.sources {
		hosts = append(hosts, host)
	}
	slices.Sort(hosts)
	now := c.now().UTC()
	var afterID int64
	for {
		packages, err := c.catalog.PackagesDueForSourceMetadataRefresh(ctx, hosts, now.Add(-c.ttl), now, afterID, sourceMetadataSweepBatch)
		if err != nil {
			return err
		}
		for _, item := range packages {
			if err := c.tasks.Enqueue(ctx, repositorySourceMetadataRefreshArgs{PackagePath: item.Path}, taskqueue.InsertOptions{Unique: true, MaxAttempts: 8, Queue: taskqueue.QueueMaintenance}); err != nil {
				return err
			}
		}
		if len(packages) < sourceMetadataSweepBatch {
			return nil
		}
		afterID = packages[len(packages)-1].ID
	}
}

func (c *repositoryMetadataRefresher) refreshNow(ctx context.Context, normalizedHost, repository, packagePath string, stored *catalog.Package) (repositoryMetadata, error) {
	upstream, supported := c.sources[normalizedHost]
	if !supported {
		return repositoryMetadata{Description: stored.Description, Stars: stored.Stars, ETag: stored.SourceETag}, nil
	}
	value, err, _ := c.refresh.Do(packagePath, func() (any, error) {
		current, readErr := c.catalog.Package(ctx, packagePath)
		if readErr != nil {
			return nil, readErr
		}
		now := c.now().UTC()
		if repositoryMetadataFresh(current, now, c.ttl) || repositoryMetadataRetryBlocked(current, now) {
			logSourceMetadataCache(ctx, packagePath, "singleflight_hit")
			return repositoryMetadata{Description: current.Description, Stars: current.Stars, ETag: current.SourceETag}, nil
		}
		etag := current.SourceETag
		if current.Description == "" {
			etag = ""
		}
		result, upstreamErr := upstream.Read(ctx, normalizedHost, repository, etag)
		if upstreamErr != nil {
			if retryAt := githubMetadataRetryAt(upstreamErr, now); retryAt != nil {
				if updateErr := c.catalog.UpdatePackageSourceMetadata(ctx, packagePath, current.Description, current.Stars, current.SourceETag, current.SourceCheckedAt, retryAt); updateErr != nil {
					return nil, fmt.Errorf("persist github metadata retry window: %w", updateErr)
				}
			}
			return nil, upstreamErr
		}
		description, stars, etag := result.Description, result.Stars, result.ETag
		if result.NotModified {
			description, stars, etag = current.Description, current.Stars, current.SourceETag
		}
		if err := c.catalog.UpdatePackageSourceMetadata(ctx, packagePath, description, stars, etag, &now, nil); err != nil {
			return nil, err
		}
		cacheResult := "refreshed"
		if result.NotModified {
			cacheResult = "revalidated"
		}
		logSourceMetadataCache(ctx, packagePath, cacheResult)
		return repositoryMetadata{Description: description, Stars: stars, ETag: etag}, nil
	})
	if err != nil {
		return repositoryMetadata{Description: stored.Description, Stars: stored.Stars, ETag: stored.SourceETag}, err
	}
	return value.(repositoryMetadata), nil
}

func logSourceMetadataCache(ctx context.Context, packagePath, result string) {
	log.EntryFromContext(ctx).WithFields(map[string]any{
		"cache_resource": "repository_source_metadata",
		"cache_result":   result,
		"package_path":   packagePath,
	}).Debugf("repository source metadata cache lookup")
}

func repositoryMetadataFresh(repository *catalog.Package, now time.Time, ttl time.Duration) bool {
	return repository.SourceCheckedAt != nil && now.Before(repository.SourceCheckedAt.Add(ttl))
}

func repositoryMetadataRetryBlocked(repository *catalog.Package, now time.Time) bool {
	return repository.SourceRetryAt != nil && now.Before(*repository.SourceRetryAt)
}

func (r *githubRepositoryMetadataReader) Read(
	ctx context.Context,
	sourceHost string,
	repository string,
	etag string,
) (repositoryMetadata, error) {
	if !strings.EqualFold(sourceHost, "github.com") {
		return repositoryMetadata{}, fmt.Errorf("unsupported repository host %q", sourceHost)
	}
	attempts := len(r.tokens)
	if attempts == 0 {
		attempts = 1
	}
	var result repositoryMetadata
	var err error
	start := r.active.Load()
	for offset := range attempts {
		token := r.tokenAt(start, uint64(offset))
		result, err = r.readWithToken(ctx, sourceHost, repository, etag, token)
		if err == nil {
			if offset > 0 {
				r.active.CompareAndSwap(start, start+uint64(offset))
			}
			return result, nil
		}
		var upstream *githubMetadataHTTPError
		if !errors.As(err, &upstream) || !githubTokenFailoverStatus(upstream.statusCode) {
			return repositoryMetadata{}, err
		}
	}
	return repositoryMetadata{}, err
}

func (r *githubRepositoryMetadataReader) readWithToken(
	ctx context.Context,
	sourceHost string,
	repository string,
	etag string,
	token string,
) (repositoryMetadata, error) {
	endpoint := "https://api.github.com/repos/" + strings.TrimPrefix(repository, "/")
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return repositoryMetadata{}, err
	}
	request.Header.Set("Accept", "application/vnd.github+json")
	request.Header.Set("X-GitHub-Api-Version", "2022-11-28")
	request.Header.Set("User-Agent", "SkillsGo-Hub")
	if token != "" {
		request.Header.Set("Authorization", "Bearer "+token)
	}
	if etag != "" {
		request.Header.Set("If-None-Match", etag)
	}
	started := time.Now()
	response, err := r.client.Do(request)
	if err != nil {
		log.EntryFromContext(ctx).WithFields(map[string]any{
			"conditional_request": etag != "",
			"dependency":          "github_api",
			"duration_ms":         time.Since(started).Milliseconds(),
			"error":               err.Error(),
			"package_path":        strings.TrimSuffix(sourceHost, "/") + "/" + strings.Trim(repository, "/"),
			"upstream_operation":  "get_repository_metadata",
		}).Warnf("github api transport failed")
		return repositoryMetadata{}, err
	}
	defer response.Body.Close()
	duration := time.Since(started)
	log.EntryFromContext(ctx).WithFields(map[string]any{
		"conditional_request":  etag != "",
		"dependency":           "github_api",
		"duration_ms":          duration.Milliseconds(),
		"github_request_id":    response.Header.Get("X-GitHub-Request-Id"),
		"rate_limit_remaining": response.Header.Get("X-RateLimit-Remaining"),
		"package_path":         strings.TrimSuffix(sourceHost, "/") + "/" + strings.Trim(repository, "/"),
		"upstream_operation":   "get_repository_metadata",
		"upstream_status":      response.StatusCode,
	}).Debugf("github api request completed")
	if response.StatusCode == http.StatusNotModified {
		return repositoryMetadata{ETag: etag, NotModified: true}, nil
	}
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		return repositoryMetadata{}, newGitHubMetadataHTTPError(response, token != "", duration)
	}
	var payload struct {
		Description string `json:"description"`
		Stars       int64  `json:"stargazers_count"`
		URL         string `json:"html_url"`
	}
	if err := json.NewDecoder(response.Body).Decode(&payload); err != nil {
		return repositoryMetadata{}, err
	}
	if payload.Stars < 0 {
		return repositoryMetadata{}, fmt.Errorf("github repository metadata returned negative stars")
	}
	if parsed, err := url.Parse(payload.URL); err != nil || parsed.Host != "github.com" {
		return repositoryMetadata{}, fmt.Errorf("github repository metadata returned an invalid repository URL")
	}
	return repositoryMetadata{Description: strings.TrimSpace(payload.Description), Stars: payload.Stars, ETag: response.Header.Get("ETag")}, nil
}

func githubTokenFailoverStatus(statusCode int) bool {
	return statusCode == http.StatusUnauthorized || statusCode == http.StatusForbidden || statusCode == http.StatusTooManyRequests
}

func githubMetadataRetryAt(err error, now time.Time) *time.Time {
	var upstream *githubMetadataHTTPError
	if !errors.As(err, &upstream) || githubHTTPErrorKind(upstream.statusCode, upstream.rateRemaining) != "rate_limited" {
		return nil
	}
	if seconds, parseErr := strconv.ParseInt(upstream.retryAfter, 10, 64); parseErr == nil && seconds > 0 {
		retryAt := now.Add(time.Duration(seconds) * time.Second)
		return &retryAt
	}
	if seconds, parseErr := strconv.ParseInt(upstream.rateReset, 10, 64); parseErr == nil && seconds > 0 {
		retryAt := time.Unix(seconds, 0).UTC()
		return &retryAt
	}
	retryAt := now.Add(time.Minute)
	return &retryAt
}

func newGitHubMetadataHTTPError(response *http.Response, authConfigured bool, duration time.Duration) error {
	var payload struct {
		Message       string `json:"message"`
		Documentation string `json:"documentation_url"`
	}
	_ = json.NewDecoder(io.LimitReader(response.Body, maxGitHubErrorBodyBytes)).Decode(&payload)
	return &githubMetadataHTTPError{
		statusCode:     response.StatusCode,
		status:         response.Status,
		message:        strings.TrimSpace(payload.Message),
		documentation:  strings.TrimSpace(payload.Documentation),
		requestID:      response.Header.Get("X-GitHub-Request-Id"),
		rateLimit:      response.Header.Get("X-RateLimit-Limit"),
		rateRemaining:  response.Header.Get("X-RateLimit-Remaining"),
		rateReset:      response.Header.Get("X-RateLimit-Reset"),
		retryAfter:     response.Header.Get("Retry-After"),
		authConfigured: authConfigured,
		duration:       duration,
	}
}

func githubHTTPErrorKind(statusCode int, remaining string) string {
	switch {
	case statusCode == http.StatusTooManyRequests:
		return "rate_limited"
	case statusCode == http.StatusForbidden && remaining == "0":
		return "rate_limited"
	case statusCode == http.StatusUnauthorized:
		return "authentication_failed"
	case statusCode == http.StatusForbidden:
		return "forbidden"
	case statusCode == http.StatusNotFound:
		return "not_found"
	case statusCode >= http.StatusInternalServerError:
		return "upstream_failure"
	default:
		return "unexpected_response"
	}
}

func githubRateResetTime(value string) string {
	seconds, err := strconv.ParseInt(value, 10, 64)
	if err != nil || seconds <= 0 {
		return ""
	}
	return time.Unix(seconds, 0).UTC().Format(time.RFC3339)
}
