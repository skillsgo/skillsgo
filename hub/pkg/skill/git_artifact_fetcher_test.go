/*
 * [INPUT]: Depends on the Git-backed Repository fetcher, filesystem fixtures, and injected Git transport outcomes.
 * [OUTPUT]: Specifies Repository cache paths and credential-free controlled Git transport behavior.
 * [POS]: Serves as focused construction and transport coverage for the Hub Repository fetcher.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skill

import (
	"context"
	"path/filepath"
	"testing"
	"time"

	"github.com/spf13/afero"
)

func (s *SkillSuite) TestNewRepositoryFetcher() {
	r := s.Require()
	fetcher, err := NewRepositoryFetcher("", s.fs)
	r.NoError(err)
	_, ok := fetcher.(*gitFetcher)
	r.True(ok)
}

func TestGitTransportStripsAmbientCredentials(t *testing.T) {
	fetcher, err := NewRepositoryFetcher(t.TempDir(), afero.NewOsFs())
	if err != nil {
		t.Fatal(err)
	}
	gitFetcher := fetcher.(*gitFetcher)
	var capturedEnvironment []string
	gitFetcher.runGitCommand = func(_ context.Context, _ string, _ []string, environment []string) ([]byte, error) {
		capturedEnvironment = append([]string(nil), environment...)
		return nil, nil
	}
	t.Setenv("GIT_CONFIG_COUNT", "1")
	t.Setenv("GIT_CONFIG_KEY_0", "http.https://github.com/.extraHeader")
	t.Setenv("GIT_CONFIG_VALUE_0", "Authorization: Basic secret")
	_, err = gitFetcher.runGitTransport(t.Context(), "", "fetch")
	if err != nil {
		t.Fatal(err)
	}
	if environmentValue(capturedEnvironment, "GIT_CONFIG_COUNT") != "" || environmentValue(capturedEnvironment, "GIT_CONFIG_VALUE_0") != "" {
		t.Fatalf("controlled Git environment retained ambient credentials: %v", capturedEnvironment)
	}
}

func environmentValue(environment []string, key string) string {
	prefix := key + "="
	for _, entry := range environment {
		if len(entry) >= len(prefix) && entry[:len(prefix)] == prefix {
			return entry[len(prefix):]
		}
	}
	return ""
}

func (s *SkillSuite) TestVCSListerSharesFetcherRepositoryCache() {
	r := s.Require()
	fetcher, err := NewRepositoryFetcher("", s.fs)
	r.NoError(err)
	lister, err := NewVCSLister(fetcher, time.Minute)
	r.NoError(err)
	r.Same(fetcher, lister.(*vcsLister).repositories)
}

func (s *SkillSuite) TestRepositoryDirIsReadableAndCanonical() {
	r := s.Require()
	fetcher, err := NewRepositoryFetcher("/cache", s.fs)
	r.NoError(err)
	dir, err := fetcher.(*gitFetcher).repositoryDir("github.com/MattPocock/Skills")
	r.NoError(err)
	r.Equal(filepath.Join("/cache", "repositories", "github.com", "ec486835e7090c2af80fe3705ccb0ab885ae215da398e7b733a0ecc044b16416"), dir)
}

func (s *SkillSuite) TestRepositoryDirKeepsCaseSensitiveRepositoriesDistinct() {
	r := s.Require()
	fetcher, err := NewRepositoryFetcher("/cache", s.fs)
	r.NoError(err)
	upper, err := fetcher.(*gitFetcher).repositoryDir("git.example.com/Team/Repo")
	r.NoError(err)
	lower, err := fetcher.(*gitFetcher).repositoryDir("git.example.com/team/repo")
	r.NoError(err)
	r.NotEqual(upper, lower)
}

func (s *SkillSuite) TestRepositoryDirRejectsTraversal() {
	r := s.Require()
	fetcher, err := NewRepositoryFetcher("/cache", s.fs)
	r.NoError(err)
	_, err = fetcher.(*gitFetcher).repositoryDir("github.com/owner/../secret")
	r.EqualError(err, `invalid repository cache path "github.com/owner/../secret": invalid Skill repository "github.com/owner/../secret": path contains non-canonical segment ".."`)
}
