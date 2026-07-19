/*
 * [INPUT]: Depends on Repository Catalog cache state, GitHub's conditional REST resource, an optional bearer token, and bounded HTTP requests.
 * [OUTPUT]: Provides Repository-scoped provider descriptions and Stars with TTL, ETag revalidation, Singleflight refresh, rate-limit backoff, and safe failure diagnostics.
 * [POS]: Serves as the cached external source-metadata adapter; artifact and discovery requests remain usable when it fails.
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
	"strconv"
	"strings"
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	"golang.org/x/sync/singleflight"
)

const (
	maxGitHubErrorBodyBytes = 32 << 10
	sourceMetadataTTL       = 18 * time.Hour
)

type repositoryMetadata struct {
	Description string
	Stars       int64
	ETag        string
	NotModified bool
}

type repositoryMetadataReader interface {
	Read(context.Context, string, string) (repositoryMetadata, error)
}

type repositoryMetadataSource interface {
	Host() string
	Read(context.Context, string, string, string) (repositoryMetadata, error)
}

type repositoryMetadataCache struct {
	catalog *catalog.Catalog
	sources map[string]repositoryMetadataSource
	ttl     time.Duration
	now     func() time.Time
	refresh singleflight.Group
}

type githubRepositoryMetadataReader struct {
	client *http.Client
	token  string
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

func newGitHubRepositoryMetadataReader(token string) repositoryMetadataSource {
	return &githubRepositoryMetadataReader{
		client: &http.Client{Timeout: 4 * time.Second},
		token:  strings.TrimSpace(token),
	}
}

func (r *githubRepositoryMetadataReader) Host() string { return "github.com" }

func newRepositoryMetadataCache(metadata *catalog.Catalog, sources ...repositoryMetadataSource) repositoryMetadataReader {
	byHost := make(map[string]repositoryMetadataSource, len(sources))
	for _, source := range sources {
		byHost[strings.ToLower(strings.TrimSpace(source.Host()))] = source
	}
	return &repositoryMetadataCache{catalog: metadata, sources: byHost, ttl: sourceMetadataTTL, now: time.Now}
}

func (c *repositoryMetadataCache) Read(ctx context.Context, sourceHost, repository string) (repositoryMetadata, error) {
	normalizedHost := strings.ToLower(strings.Trim(sourceHost, "/"))
	repositoryID := normalizedHost + "/" + strings.Trim(repository, "/")
	stored, err := c.catalog.Repository(ctx, repositoryID)
	if err != nil {
		return repositoryMetadata{}, err
	}
	now := c.now().UTC()
	upstream, supported := c.sources[normalizedHost]
	if !supported {
		logSourceMetadataCache(ctx, repositoryID, "unsupported")
		return repositoryMetadata{Description: stored.Description, Stars: stored.Stars, ETag: stored.SourceMetadataETag}, nil
	}
	if repositoryMetadataFresh(stored, now, c.ttl) {
		logSourceMetadataCache(ctx, repositoryID, "hit")
		return repositoryMetadata{Description: stored.Description, Stars: stored.Stars, ETag: stored.SourceMetadataETag}, nil
	}
	if repositoryMetadataRetryBlocked(stored, now) {
		logSourceMetadataCache(ctx, repositoryID, "retry_blocked")
		return repositoryMetadata{Description: stored.Description, Stars: stored.Stars, ETag: stored.SourceMetadataETag}, nil
	}
	value, err, _ := c.refresh.Do(repositoryID, func() (any, error) {
		current, readErr := c.catalog.Repository(ctx, repositoryID)
		if readErr != nil {
			return nil, readErr
		}
		now = c.now().UTC()
		if repositoryMetadataFresh(current, now, c.ttl) || repositoryMetadataRetryBlocked(current, now) {
			logSourceMetadataCache(ctx, repositoryID, "singleflight_hit")
			return repositoryMetadata{Description: current.Description, Stars: current.Stars, ETag: current.SourceMetadataETag}, nil
		}
		etag := current.SourceMetadataETag
		if current.Description == "" {
			etag = ""
		}
		result, upstreamErr := upstream.Read(ctx, sourceHost, repository, etag)
		if upstreamErr != nil {
			if retryAt := githubMetadataRetryAt(upstreamErr, now); retryAt != nil {
				if updateErr := c.catalog.UpdateRepositorySourceMetadata(ctx, repositoryID, current.Description, current.Stars, current.SourceMetadataETag, current.SourceMetadataCheckedAt, retryAt); updateErr != nil {
					return nil, fmt.Errorf("persist github metadata retry window: %w", updateErr)
				}
			}
			return nil, upstreamErr
		}
		description, stars, etag := result.Description, result.Stars, result.ETag
		if result.NotModified {
			description, stars, etag = current.Description, current.Stars, current.SourceMetadataETag
		}
		if err := c.catalog.UpdateRepositorySourceMetadata(ctx, repositoryID, description, stars, etag, &now, nil); err != nil {
			return nil, err
		}
		cacheResult := "refreshed"
		if result.NotModified {
			cacheResult = "revalidated"
		}
		logSourceMetadataCache(ctx, repositoryID, cacheResult)
		return repositoryMetadata{Description: description, Stars: stars, ETag: etag}, nil
	})
	if err != nil {
		return repositoryMetadata{Description: stored.Description, Stars: stored.Stars, ETag: stored.SourceMetadataETag}, err
	}
	return value.(repositoryMetadata), nil
}

func logSourceMetadataCache(ctx context.Context, repositoryID, result string) {
	log.EntryFromContext(ctx).WithFields(map[string]any{
		"cache_resource": "repository_source_metadata",
		"cache_result":   result,
		"repository_id":  repositoryID,
	}).Debugf("repository source metadata cache lookup")
}

func repositoryMetadataFresh(repository *catalog.Repository, now time.Time, ttl time.Duration) bool {
	return repository.SourceMetadataCheckedAt != nil && now.Before(repository.SourceMetadataCheckedAt.Add(ttl))
}

func repositoryMetadataRetryBlocked(repository *catalog.Repository, now time.Time) bool {
	return repository.SourceMetadataRetryAt != nil && now.Before(*repository.SourceMetadataRetryAt)
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
	endpoint := "https://api.github.com/repos/" + strings.TrimPrefix(repository, "/")
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return repositoryMetadata{}, err
	}
	request.Header.Set("Accept", "application/vnd.github+json")
	request.Header.Set("X-GitHub-Api-Version", "2022-11-28")
	request.Header.Set("User-Agent", "SkillsGo-Hub")
	if r.token != "" {
		request.Header.Set("Authorization", "Bearer "+r.token)
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
			"repository_id":       strings.TrimSuffix(sourceHost, "/") + "/" + strings.Trim(repository, "/"),
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
		"repository_id":        strings.TrimSuffix(sourceHost, "/") + "/" + strings.Trim(repository, "/"),
		"upstream_operation":   "get_repository_metadata",
		"upstream_status":      response.StatusCode,
	}).Debugf("github api request completed")
	if response.StatusCode == http.StatusNotModified {
		return repositoryMetadata{ETag: etag, NotModified: true}, nil
	}
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		return repositoryMetadata{}, newGitHubMetadataHTTPError(response, r.token != "", duration)
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
