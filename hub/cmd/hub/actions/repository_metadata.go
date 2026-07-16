/*
 * [INPUT]: Depends on GitHub's repository REST resource, an optional bearer token, and bounded HTTP requests.
 * [OUTPUT]: Provides best-effort repository popularity metadata for Catalog enrichment.
 * [POS]: Serves as the external source-metadata adapter; artifact and discovery requests remain usable when it fails.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"
)

type repositoryMetadata struct {
	GitHubStars int64
}

type repositoryMetadataReader interface {
	Read(context.Context, string, string) (repositoryMetadata, error)
}

type githubRepositoryMetadataReader struct {
	client *http.Client
	token  string
}

func newGitHubRepositoryMetadataReader(token string) repositoryMetadataReader {
	return &githubRepositoryMetadataReader{
		client: &http.Client{Timeout: 4 * time.Second},
		token:  strings.TrimSpace(token),
	}
}

func (r *githubRepositoryMetadataReader) Read(
	ctx context.Context,
	sourceHost string,
	repository string,
) (repositoryMetadata, error) {
	if sourceHost != "github.com" {
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
	response, err := r.client.Do(request)
	if err != nil {
		return repositoryMetadata{}, err
	}
	defer response.Body.Close()
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		return repositoryMetadata{}, fmt.Errorf("github repository metadata returned %s", response.Status)
	}
	var payload struct {
		Stars int64  `json:"stargazers_count"`
		URL   string `json:"html_url"`
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
	return repositoryMetadata{GitHubStars: payload.Stars}, nil
}
