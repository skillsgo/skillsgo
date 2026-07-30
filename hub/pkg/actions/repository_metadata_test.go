/*
 * [INPUT]: Depends on the asynchronous Repository metadata refresher, GitHub adapter, temporary Catalog, synchronous task substitute, and representative HTTP failure responses.
 * [OUTPUT]: Verifies publication-triggered refresh submission, background refresh behavior, About description, Stars, TTL/ETag/rate-limit state, singleflight, token failover, and safe diagnostics.
 * [POS]: Serves as the background maintenance and operational diagnostics contract for the best-effort GitHub metadata dependency.
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

func TestRepositoryMetadataRefresherSingleflightCoalescesConcurrentRefresh(t *testing.T) {
	_, metadata := testCatalogAPI(t)
	require.NoError(t, upsertActionTestSkill(t.Context(), metadata, &catalog.Skill{
		PackagePath: "github.com/acme/skills", Path: "demo", Name: "demo", LatestVersion: "v1.0.0",
	}))
	source := &recordingMetadataSource{
		results: []metadataSourceResult{{metadata: repositoryMetadata{Stars: 7, ETag: `"v1"`}}},
		delay:   25 * time.Millisecond,
	}
	refresher := newRepositoryMetadataRefresherWithRuntime(metadata, nil, source)
	var wait sync.WaitGroup
	errors := make(chan error, 16)
	for range 16 {
		wait.Add(1)
		go func() {
			defer wait.Done()
			stored, loadErr := metadata.Package(t.Context(), "github.com/acme/skills")
			if loadErr != nil {
				errors <- loadErr
				return
			}
			result, err := refresher.refreshNow(t.Context(), "github.com", "acme/skills", "github.com/acme/skills", stored)
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

func TestRepositoryMetadataRefresherRefreshInitialPersistsDescriptionDigestAndStars(t *testing.T) {
	_, metadata := testCatalogAPI(t)
	require.NoError(t, upsertActionTestSkill(t.Context(), metadata, &catalog.Skill{
		PackagePath: "github.com/acme/skills", Path: "demo", Name: "demo", LatestVersion: "v1.0.0",
	}))
	source := &recordingMetadataSource{results: []metadataSourceResult{{metadata: repositoryMetadata{
		Description: "Agent Skills from Acme.", Stars: 42, ETag: `"repo-v1"`,
	}}}}
	runtime := taskqueue.NewSynchronous()
	refresher := newQueuedRepositoryMetadataRefresher(metadata, runtime, source)
	require.NoError(t, refresher.RegisterTasks())
	require.NoError(t, runtime.Start(t.Context()))
	t.Cleanup(func() { require.NoError(t, runtime.Stop(context.Background())) })

	refresher.RefreshInitial(t.Context(), "github.com/acme/skills")

	require.Eventually(t, func() bool {
		stored, err := metadata.Package(t.Context(), "github.com/acme/skills")
		return err == nil && stored.Description == "Agent Skills from Acme." && stored.Stars == 42 && stored.SourceETag == `"repo-v1"` && stored.SourceCheckedAt != nil
	}, time.Second, 10*time.Millisecond)
}

func TestRepositoryMetadataRefresherRefreshInitialNeverRunsProviderInline(t *testing.T) {
	_, metadata := testCatalogAPI(t)
	require.NoError(t, upsertActionTestSkill(t.Context(), metadata, &catalog.Skill{
		PackagePath: "github.com/acme/skills", Path: "demo", Name: "demo", LatestVersion: "v1.0.0",
	}))
	runtime := taskqueue.NewSynchronous()
	source := &recordingMetadataSource{
		results: []metadataSourceResult{{metadata: repositoryMetadata{Stars: 7}}},
		delay:   250 * time.Millisecond,
	}
	refresher := newQueuedRepositoryMetadataRefresher(metadata, runtime, source)
	require.NoError(t, refresher.RegisterTasks())
	require.NoError(t, runtime.Start(t.Context()))
	t.Cleanup(func() { require.NoError(t, runtime.Stop(context.Background())) })

	started := time.Now()
	refresher.RefreshInitial(t.Context(), "github.com/acme/skills")
	require.Less(t, time.Since(started), 50*time.Millisecond)
	require.Eventually(t, func() bool {
		stored, err := metadata.Package(t.Context(), "github.com/acme/skills")
		return err == nil && stored.Stars == 7
	}, time.Second, 10*time.Millisecond)
}

func TestRepositoryMetadataRefresherRefreshInitialFailureDoesNotChangePublication(t *testing.T) {
	_, metadata := testCatalogAPI(t)
	require.NoError(t, upsertActionTestSkill(t.Context(), metadata, &catalog.Skill{
		PackagePath: "github.com/acme/skills", Path: "demo", Name: "demo", LatestVersion: "v1.0.0",
	}))
	runtime := taskqueue.NewSynchronous()
	source := &recordingMetadataSource{results: []metadataSourceResult{
		{err: fmt.Errorf("temporary GitHub failure")},
		{metadata: repositoryMetadata{Description: "Recovered metadata.", Stars: 7, ETag: `"repo-v2"`}},
	}}
	refresher := newQueuedRepositoryMetadataRefresher(metadata, runtime, source)
	require.NoError(t, refresher.RegisterTasks())
	require.NoError(t, runtime.Start(t.Context()))
	t.Cleanup(func() { require.NoError(t, runtime.Stop(context.Background())) })

	refresher.RefreshInitial(t.Context(), "github.com/acme/skills")

	stored, err := metadata.Package(t.Context(), "github.com/acme/skills")
	require.NoError(t, err)
	require.Empty(t, stored.Description)
	require.Zero(t, stored.Stars)
	require.Eventually(t, func() bool {
		source.mu.Lock()
		defer source.mu.Unlock()
		return source.calls == 1
	}, time.Second, 10*time.Millisecond)
}

func TestRepositoryMetadataRefresherQueuesInitialRefresh(t *testing.T) {
	_, metadata := testCatalogAPI(t)
	require.NoError(t, upsertActionTestSkill(t.Context(), metadata, &catalog.Skill{
		PackagePath: "github.com/acme/skills", Path: "demo", Name: "demo", LatestVersion: "v1.0.0",
	}))
	runtime := taskqueue.NewSynchronous()
	source := &recordingMetadataSource{results: []metadataSourceResult{{metadata: repositoryMetadata{
		Description: "Agent Skills from Acme.", Stars: 42, ETag: `"repo-v1"`,
	}}}}
	refresher := newQueuedRepositoryMetadataRefresher(metadata, runtime, source)
	require.NoError(t, refresher.RegisterTasks())
	require.NoError(t, runtime.Start(t.Context()))
	t.Cleanup(func() { require.NoError(t, runtime.Stop(context.Background())) })

	refresher.RefreshInitial(t.Context(), "github.com/acme/skills")
	require.Eventually(t, func() bool {
		stored, err := metadata.Package(t.Context(), "github.com/acme/skills")
		return err == nil && stored.Stars == 42
	}, time.Second, 10*time.Millisecond)
}

func TestRepositoryMetadataRefresherSharesStarsAndRevalidatesWithETag(t *testing.T) {
	_, metadata := testCatalogAPI(t)
	require.NoError(t, publishActionTestSkills(t.Context(), metadata,
		&catalog.Skill{PackagePath: "github.com/acme/skills", Path: "skills/a", Name: "a", LatestVersion: "v1.0.0"},
		&catalog.Skill{PackagePath: "github.com/acme/skills", Path: "skills/b", Name: "b", LatestVersion: "v1.0.0"},
	))
	source := &recordingMetadataSource{results: []metadataSourceResult{
		{metadata: repositoryMetadata{Description: "Agent Skills from Acme.", Stars: 42, ETag: `"repo-v1"`}},
		{metadata: repositoryMetadata{NotModified: true, ETag: `"repo-v1"`}},
	}}
	refresher := newRepositoryMetadataRefresherWithRuntime(metadata, nil, source)
	now := time.Date(2026, time.July, 18, 10, 0, 0, 0, time.UTC)
	refresher.now = func() time.Time { return now }

	stored, err := metadata.Package(t.Context(), "github.com/acme/skills")
	require.NoError(t, err)
	first, err := refresher.refreshNow(t.Context(), "github.com", "acme/skills", "github.com/acme/skills", stored)
	require.NoError(t, err)
	require.Equal(t, int64(42), first.Stars)
	require.Equal(t, "Agent Skills from Acme.", first.Description)
	stored, err = metadata.Package(t.Context(), "github.com/acme/skills")
	require.NoError(t, err)
	second, err := refresher.refreshNow(t.Context(), "github.com", "acme/skills", "github.com/acme/skills", stored)
	require.NoError(t, err)
	require.Equal(t, int64(42), second.Stars)
	require.Equal(t, 1, source.calls)

	for _, name := range []string{"a", "b"} {
		skill, skillErr := metadata.SkillByCoordinate(t.Context(), "github.com/acme/skills", name)
		require.NoError(t, skillErr)
		require.Equal(t, int64(42), skill.Stars)
	}

	now = now.Add(19 * time.Hour)
	stored, err = metadata.Package(t.Context(), "github.com/acme/skills")
	require.NoError(t, err)
	revalidated, err := refresher.refreshNow(t.Context(), "github.com", "acme/skills", "github.com/acme/skills", stored)
	require.NoError(t, err)
	require.Equal(t, int64(42), revalidated.Stars)
	require.Equal(t, "Agent Skills from Acme.", revalidated.Description)
	require.Equal(t, 2, source.calls)
	require.Equal(t, []string{"", `"repo-v1"`}, source.etags)
}

func TestRepositoryMetadataRefresherHonorsRateLimitReset(t *testing.T) {
	_, metadata := testCatalogAPI(t)
	require.NoError(t, upsertActionTestSkill(t.Context(), metadata, &catalog.Skill{
		PackagePath: "github.com/acme/skills", Path: "demo", Name: "demo", LatestVersion: "v1.0.0",
	}))
	now := time.Date(2026, time.July, 18, 10, 0, 0, 0, time.UTC)
	reset := now.Add(time.Hour)
	source := &recordingMetadataSource{results: []metadataSourceResult{{err: &githubMetadataHTTPError{
		statusCode: http.StatusForbidden, status: "403 Forbidden", rateRemaining: "0",
		rateReset: strconv.FormatInt(reset.Unix(), 10),
	}}}}
	refresher := newRepositoryMetadataRefresherWithRuntime(metadata, nil, source)
	refresher.now = func() time.Time { return now }

	stored, err := metadata.Package(t.Context(), "github.com/acme/skills")
	require.NoError(t, err)
	_, err = refresher.refreshNow(t.Context(), "github.com", "acme/skills", "github.com/acme/skills", stored)
	require.Error(t, err)
	stored, err = metadata.Package(t.Context(), "github.com/acme/skills")
	require.NoError(t, err)
	cached, err := refresher.refreshNow(t.Context(), "github.com", "acme/skills", "github.com/acme/skills", stored)
	require.NoError(t, err)
	require.Zero(t, cached.Stars)
	require.Equal(t, 1, source.calls)
	repository, err := metadata.Package(t.Context(), "github.com/acme/skills")
	require.NoError(t, err)
	require.NotNil(t, repository.SourceRetryAt)
	require.Equal(t, reset, *repository.SourceRetryAt)
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
