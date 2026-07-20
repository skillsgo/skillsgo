/*
 * [INPUT]: Depends on Git-backed Skill fetching, filesystem fixtures, and injected Git transport outcomes.
 * [OUTPUT]: Specifies artifact fetching, repository cache paths, and sticky GitHub-token failover behavior.
 * [POS]: Serves as test coverage for the skill package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skill

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/spf13/afero"
)

func (s *SkillSuite) TestNewFetcher() {
	r := s.Require()
	fetcher, err := NewFetcher("", s.fs)
	r.NoError(err)
	_, ok := fetcher.(*gitFetcher)
	r.True(ok)
}

func TestGitTransportFailsOverAndKeepsReplacement(t *testing.T) {
	fetcher, err := NewFetcherWithGitHubTokens(t.TempDir(), afero.NewOsFs(), []string{"token-a", "token-b", "token-c"})
	if err != nil {
		t.Fatal(err)
	}
	gitFetcher := fetcher.(*gitFetcher)
	var credentials []string
	gitFetcher.runGitCommand = func(_ context.Context, _ string, _ []string, environment []string) ([]byte, error) {
		credential := environmentValue(environment, "GIT_CONFIG_VALUE_0")
		credentials = append(credentials, credential)
		if credential == gitAuthorization("token-a") {
			return []byte("authentication failed"), fmt.Errorf("exit status 128")
		}
		return nil, nil
	}

	_, err = gitFetcher.runGitTransport(t.Context(), "", true, "fetch")
	if err != nil {
		t.Fatal(err)
	}
	_, err = gitFetcher.runGitTransport(t.Context(), "", true, "fetch")
	if err != nil {
		t.Fatal(err)
	}
	want := []string{gitAuthorization("token-a"), gitAuthorization("token-b"), gitAuthorization("token-b")}
	if fmt.Sprint(credentials) != fmt.Sprint(want) {
		t.Fatalf("credentials = %v, want %v", credentials, want)
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

func gitAuthorization(token string) string {
	credential := base64.StdEncoding.EncodeToString([]byte("x-access-token:" + token))
	return "Authorization: Basic " + credential
}

func (s *SkillSuite) TestVCSListerSharesFetcherRepositoryCache() {
	r := s.Require()
	fetcher, err := NewFetcher("", s.fs)
	r.NoError(err)
	lister, err := NewVCSLister(fetcher, time.Minute)
	r.NoError(err)
	r.Same(fetcher, lister.(*vcsLister).repositories)
}

func (s *SkillSuite) TestRepositoryDirIsReadableAndCanonical() {
	r := s.Require()
	fetcher, err := NewFetcher("/cache", s.fs)
	r.NoError(err)
	dir, err := fetcher.(*gitFetcher).repositoryDir("github.com/MattPocock/Skills")
	r.NoError(err)
	r.Equal(filepath.Join("/cache", "repositories", "github.com", "mattpocock", "skills"), dir)
}

func (s *SkillSuite) TestRepositoryDirRejectsTraversal() {
	r := s.Require()
	fetcher, err := NewFetcher("/cache", s.fs)
	r.NoError(err)
	_, err = fetcher.(*gitFetcher).repositoryDir("github.com/owner/../secret")
	r.EqualError(err, `invalid repository cache path "github.com/owner/../secret": path contains non-canonical segment ".."`)
}

func (s *SkillSuite) TestGitFetcherFetch() {
	r := s.Require()
	// we need to use an OS filesystem because fetch executes vgo on the command line, which
	// always writes to the filesystem
	fetcher, err := NewFetcher("", afero.NewOsFs())
	r.NoError(err)
	ver, err := fetcher.Fetch(s.T().Context(), repoURI, version)
	r.NoError(err)
	defer ver.Zip.Close()

	r.True(len(ver.Info) > 0)
	var info struct {
		CommitSHA string `json:"CommitSHA"`
		TreeSHA   string `json:"TreeSHA"`
	}
	r.NoError(json.Unmarshal(ver.Info, &info))
	r.Equal("3652b3c7aa21492717945b6063ae278030101dd8", info.CommitSHA)
	r.Equal("f17a01bcf457cca0ba9a3432fb7218a064261a14", info.TreeSHA)

	zipBytes, err := io.ReadAll(ver.Zip)
	r.NoError(err)
	r.True(len(zipBytes) > 0)

	// close the version's zip file (which also cleans up the underlying GOPATH) and expect it to fail again
	r.NoError(ver.Zip.Close())
}

func (s *SkillSuite) TestNotFoundFetches() {
	r := s.Require()
	fetcher, err := NewFetcher("", afero.NewOsFs())
	r.NoError(err)
	// when someone buys laks47dfjoijskdvjxuyyd.com, and implements
	// a git server on top of it, this test will fail :)
	_, err = fetcher.Fetch(s.T().Context(), "laks47dfjoijskdvjxuyyd.com/pkg/errors", "v0.8.1")
	if err == nil {
		s.Fail("expected an error but got nil")
	}
	if errors.Kind(err) != errors.KindNotFound {
		s.Failf("incorrect error kind", "expected a not found error but got %v", errors.Kind(err))
	}
}

func (s *SkillSuite) TestFetchErrorsUseSkillVocabulary() {
	r := s.Require()
	fetcher, err := NewFetcher("", afero.NewOsFs())
	r.NoError(err)

	tests := []struct {
		name      string
		skillPath string
		revision  string
		want      string
	}{
		{
			name:      "repository not found",
			skillPath: "github.com/skillsgo-test/repository-that-does-not-exist",
			revision:  "v1.0.0",
			want:      `Skill repository "github.com/skillsgo-test/repository-that-does-not-exist" not found`,
		},
		{
			name:      "revision not found",
			skillPath: repoURI,
			revision:  "v999.0.0",
			want:      `revision "v999.0.0" not found for Skill "github.com/op7418/guizang-ppt-skill"`,
		},
		{
			name:      "SKILL.md not found",
			skillPath: "github.com/athens-artifacts/happy-path",
			revision:  "v0.0.3",
			want:      `SKILL.md not found for Skill "github.com/athens-artifacts/happy-path" at revision "v0.0.3"`,
		},
	}

	for _, tc := range tests {
		s.T().Run(tc.name, func(t *testing.T) {
			_, err := fetcher.Fetch(t.Context(), tc.skillPath, tc.revision)
			r.EqualError(err, tc.want)
			r.Equal(errors.KindNotFound, errors.Kind(err))
		})
	}
}

func (s *SkillSuite) TestSkillCacheDir() {
	r := s.Require()
	t := s.T()
	dir, err := os.MkdirTemp("", "nested")
	r.NoError(err)
	t.Cleanup(func() {
		os.RemoveAll(dir)
	})
	fetcher, err := NewFetcher(dir, afero.NewOsFs())
	r.NoError(err)

	ver, err := fetcher.Fetch(s.T().Context(), repoURI, version)
	r.NoError(err)
	defer ver.Zip.Close()

	dirInfo, err := os.ReadDir(dir)
	r.NoError(err)

	r.NotEmpty(dirInfo)
	repositoryDir := filepath.Join(dir, "repositories", "github.com", "op7418", "guizang-ppt-skill")
	repositoryGitDir, err := os.Stat(filepath.Join(repositoryDir, ".git"))
	r.NoError(err)
	r.True(repositoryGitDir.IsDir())

	metadataBytes, err := os.ReadFile(filepath.Join(repositoryDir, "metadata.json"))
	r.NoError(err)
	var metadata repositoryMetadata
	r.NoError(json.Unmarshal(metadataBytes, &metadata))
	r.Equal(repoURI, metadata.Repository)
	r.Equal("https://github.com/op7418/guizang-ppt-skill", metadata.URL)
	r.False(metadata.UpdatedAt.IsZero())
}
