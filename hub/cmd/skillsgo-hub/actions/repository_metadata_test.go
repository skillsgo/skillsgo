/*
 * [INPUT]: Depends on the Repository metadata cache, GitHub adapter, temporary Catalog, and representative HTTP failure responses.
 * [OUTPUT]: Verifies Repository-scoped stale-while-revalidate submission, About description, Stars, TTL/ETag/rate-limit caching, token failover, and safe diagnostics.
 * [POS]: Serves as the operational diagnostics contract for the best-effort GitHub metadata dependency.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/skillsgo/skillsgo/hub/pkg/taskqueue"
	"github.com/stretchr/testify/require"
)

type metadataSourceResult struct {
	metadata repositoryMetadata
	err      error
}

type roundTripFunc func(*http.Request) (*http.Response, error)

func (f roundTripFunc) RoundTrip(request *http.Request) (*http.Response, error) { return f(request) }

func TestGitHubMetadataReaderUsesConditionalRequest(t *testing.T) {
	reader := &githubRepositoryMetadataReader{
		client: &http.Client{Transport: roundTripFunc(func(request *http.Request) (*http.Response, error) {
			require.Equal(t, `"repo-v1"`, request.Header.Get("If-None-Match"))
			require.Empty(t, request.Header.Get("Authorization"))
			return &http.Response{
				StatusCode: http.StatusNotModified, Status: "304 Not Modified",
				Header: make(http.Header), Body: io.NopCloser(strings.NewReader("")),
			}, nil
		})},
	}
	result, err := reader.Read(t.Context(), "github.com", "acme/skills", `"repo-v1"`)
	require.NoError(t, err)
	require.True(t, result.NotModified)
	require.Equal(t, `"repo-v1"`, result.ETag)
}

func TestGitHubMetadataReaderKeepsSuccessfulToken(t *testing.T) {
	var mu sync.Mutex
	var authorizations []string
	reader := newGitHubRepositoryMetadataReader([]string{"token-a", "token-b", "token-c"}).(*githubRepositoryMetadataReader)
	reader.client = &http.Client{Transport: roundTripFunc(func(request *http.Request) (*http.Response, error) {
		mu.Lock()
		authorizations = append(authorizations, request.Header.Get("Authorization"))
		mu.Unlock()
		return githubMetadataSuccessResponse(), nil
	})}

	for range 3 {
		_, err := reader.Read(t.Context(), "github.com", "acme/skills", "")
		require.NoError(t, err)
	}
	require.Equal(t, []string{"Bearer token-a", "Bearer token-a", "Bearer token-a"}, authorizations)
}

func TestGitHubMetadataReaderFailsOverAndKeepsReplacement(t *testing.T) {
	var authorizations []string
	var mu sync.Mutex
	reader := newGitHubRepositoryMetadataReader([]string{"token-a", "token-b", "token-c"}).(*githubRepositoryMetadataReader)
	reader.client = &http.Client{Transport: roundTripFunc(func(request *http.Request) (*http.Response, error) {
		mu.Lock()
		authorization := request.Header.Get("Authorization")
		authorizations = append(authorizations, authorization)
		mu.Unlock()
		if authorization == "Bearer token-a" {
			return &http.Response{
				StatusCode: http.StatusUnauthorized, Status: "401 Unauthorized",
				Header: make(http.Header), Body: io.NopCloser(strings.NewReader(`{"message":"Bad credentials"}`)),
			}, nil
		}
		return githubMetadataSuccessResponse(), nil
	})}

	for range 2 {
		_, err := reader.Read(t.Context(), "github.com", "acme/skills", "")
		require.NoError(t, err)
	}
	require.Equal(t, []string{"Bearer token-a", "Bearer token-b", "Bearer token-b"}, authorizations)
}

func githubMetadataSuccessResponse() *http.Response {
	return &http.Response{
		StatusCode: http.StatusOK,
		Status:     "200 OK",
		Header:     make(http.Header),
		Body: io.NopCloser(strings.NewReader(
			`{"description":"","stargazers_count":0,"html_url":"https://github.com/acme/skills"}`,
		)),
	}
}

type recordingMetadataSource struct {
	mu      sync.Mutex
	calls   int
	etags   []string
	results []metadataSourceResult
	delay   time.Duration
}

func (*recordingMetadataSource) Host() string { return "github.com" }

func (s *recordingMetadataSource) Read(_ context.Context, _, _, etag string) (repositoryMetadata, error) {
	if s.delay > 0 {
		time.Sleep(s.delay)
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	s.etags = append(s.etags, etag)
	result := s.results[s.calls]
	s.calls++
	return result.metadata, result.err
}

func TestRepositoryMetadataCacheSingleflightCoalescesConcurrentRefresh(t *testing.T) {
	_, metadata := testCatalogAPI(t)
	require.NoError(t, metadata.UpsertSkill(t.Context(), &catalog.Skill{
		SkillID: "github.com/acme/skills/-/demo", Name: "demo", LatestVersion: "v1.0.0",
	}))
	source := &recordingMetadataSource{
		results: []metadataSourceResult{{metadata: repositoryMetadata{Stars: 7, ETag: `"v1"`}}},
		delay:   25 * time.Millisecond,
	}
	cache := newRepositoryMetadataCache(metadata, source)
	var wait sync.WaitGroup
	errors := make(chan error, 16)
	for range 16 {
		wait.Add(1)
		go func() {
			defer wait.Done()
			result, err := cache.Read(t.Context(), "github.com", "acme/skills")
			if err == nil && result.Stars != 7 {
				err = fmt.Errorf("unexpected Stars %d", result.Stars)
			}
			errors <- err
		}()
	}
	wait.Wait()
	close(errors)
	for err := range errors {
		require.NoError(t, err)
	}
	require.Equal(t, 1, source.calls)
}

func TestRepositoryMetadataCacheQueuesRefreshAndPrewarm(t *testing.T) {
	_, metadata := testCatalogAPI(t)
	require.NoError(t, metadata.UpsertSkill(t.Context(), &catalog.Skill{
		SkillID: "github.com/acme/skills/-/demo", Name: "demo", LatestVersion: "v1.0.0",
	}))
	runtime := taskqueue.NewSynchronous()
	prewarmed := make(chan struct{}, 1)
	require.NoError(t, taskqueue.Register(runtime, func(context.Context, repositoryPublicationPrewarmArgs) error {
		prewarmed <- struct{}{}
		return nil
	}))
	source := &recordingMetadataSource{results: []metadataSourceResult{{metadata: repositoryMetadata{
		Description: "Agent Skills from Acme.", Stars: 42, ETag: `"repo-v1"`,
	}}}}
	cache := newQueuedRepositoryMetadataCache(metadata, runtime, source)
	require.NoError(t, cache.RegisterTask())

	stale, err := cache.Read(t.Context(), "github.com", "acme/skills")
	require.NoError(t, err)
	require.Zero(t, stale.Stars)
	stored, err := metadata.Repository(t.Context(), "github.com/acme/skills")
	require.NoError(t, err)
	require.Equal(t, int64(42), stored.Stars)
	select {
	case <-prewarmed:
	default:
		t.Fatal("repository prewarm was not submitted")
	}
}

func TestRepositoryMetadataCacheSharesStarsAndRevalidatesWithETag(t *testing.T) {
	_, metadata := testCatalogAPI(t)
	for _, id := range []string{"github.com/acme/skills/-/skills/a", "github.com/acme/skills/-/skills/b"} {
		require.NoError(t, metadata.UpsertSkill(t.Context(), &catalog.Skill{SkillID: id, Name: id, LatestVersion: "v1.0.0"}))
	}
	source := &recordingMetadataSource{results: []metadataSourceResult{
		{metadata: repositoryMetadata{Description: "Agent Skills from Acme.", Stars: 42, ETag: `"repo-v1"`}},
		{metadata: repositoryMetadata{NotModified: true, ETag: `"repo-v1"`}},
	}}
	cache := newRepositoryMetadataCache(metadata, source).(*repositoryMetadataCache)
	now := time.Date(2026, time.July, 18, 10, 0, 0, 0, time.UTC)
	cache.now = func() time.Time { return now }

	first, err := cache.Read(t.Context(), "github.com", "acme/skills")
	require.NoError(t, err)
	require.Equal(t, int64(42), first.Stars)
	require.Equal(t, "Agent Skills from Acme.", first.Description)
	second, err := cache.Read(t.Context(), "github.com", "acme/skills")
	require.NoError(t, err)
	require.Equal(t, int64(42), second.Stars)
	require.Equal(t, 1, source.calls)

	for _, id := range []string{"github.com/acme/skills/-/skills/a", "github.com/acme/skills/-/skills/b"} {
		skill, skillErr := metadata.Skill(t.Context(), id)
		require.NoError(t, skillErr)
		require.Equal(t, int64(42), skill.Stars)
	}

	now = now.Add(19 * time.Hour)
	revalidated, err := cache.Read(t.Context(), "github.com", "acme/skills")
	require.NoError(t, err)
	require.Equal(t, int64(42), revalidated.Stars)
	require.Equal(t, "Agent Skills from Acme.", revalidated.Description)
	require.Equal(t, 2, source.calls)
	require.Equal(t, []string{"", `"repo-v1"`}, source.etags)
}

func TestRepositoryMetadataCacheBlocksRequestsUntilRateLimitReset(t *testing.T) {
	_, metadata := testCatalogAPI(t)
	require.NoError(t, metadata.UpsertSkill(t.Context(), &catalog.Skill{
		SkillID: "github.com/acme/skills/-/demo", Name: "demo", LatestVersion: "v1.0.0",
	}))
	now := time.Date(2026, time.July, 18, 10, 0, 0, 0, time.UTC)
	reset := now.Add(time.Hour)
	source := &recordingMetadataSource{results: []metadataSourceResult{{err: &githubMetadataHTTPError{
		statusCode: http.StatusForbidden, status: "403 Forbidden", rateRemaining: "0",
		rateReset: strconv.FormatInt(reset.Unix(), 10),
	}}}}
	cache := newRepositoryMetadataCache(metadata, source).(*repositoryMetadataCache)
	cache.now = func() time.Time { return now }

	_, err := cache.Read(t.Context(), "github.com", "acme/skills")
	require.Error(t, err)
	cached, err := cache.Read(t.Context(), "github.com", "acme/skills")
	require.NoError(t, err)
	require.Zero(t, cached.Stars)
	require.Equal(t, 1, source.calls)
	repository, err := metadata.Repository(t.Context(), "github.com/acme/skills")
	require.NoError(t, err)
	require.NotNil(t, repository.SourceMetadataRetryAt)
	require.Equal(t, reset, *repository.SourceMetadataRetryAt)
}

func TestGitHubMetadataHTTPErrorExposesSafeRateLimitDiagnostics(t *testing.T) {
	response := &http.Response{
		StatusCode: http.StatusForbidden,
		Status:     "403 Forbidden",
		Header: http.Header{
			"X-Github-Request-Id":   []string{"ABC1:DEF2"},
			"X-Ratelimit-Limit":     []string{"60"},
			"X-Ratelimit-Remaining": []string{"0"},
			"X-Ratelimit-Reset":     []string{"1784361600"},
		},
		Body: io.NopCloser(strings.NewReader(`{"message":"API rate limit exceeded","documentation_url":"https://docs.github.com/rest/using-the-rest-api/rate-limits-for-the-rest-api"}`)),
	}

	err := newGitHubMetadataHTTPError(response, false, 125*time.Millisecond)
	diagnostic, ok := err.(interface{ LogFields() map[string]any })
	require.True(t, ok)
	fields := diagnostic.LogFields()
	require.Equal(t, "rate_limited", fields["upstream_error_kind"])
	require.Equal(t, 403, fields["upstream_status"])
	require.Equal(t, "ABC1:DEF2", fields["github_request_id"])
	require.Equal(t, "0", fields["rate_limit_remaining"])
	require.Equal(t, false, fields["auth_configured"])
	require.NotEmpty(t, fields["rate_limit_reset_at"])
	require.NotContains(t, err.Error(), "Authorization")
}

func TestGitHubHTTPErrorKindDistinguishesForbiddenFromAuthentication(t *testing.T) {
	require.Equal(t, "authentication_failed", githubHTTPErrorKind(http.StatusUnauthorized, ""))
	require.Equal(t, "forbidden", githubHTTPErrorKind(http.StatusForbidden, "42"))
	require.Equal(t, "rate_limited", githubHTTPErrorKind(http.StatusTooManyRequests, ""))
}
