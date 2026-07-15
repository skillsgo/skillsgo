package skill

import (
	"encoding/json"
	"io"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/skillsgo/skillsgo/registry/pkg/errors"
	"github.com/skillsgo/skillsgo/registry/pkg/storage"
	"github.com/spf13/afero"
)

func (s *SkillSuite) TestNewFetcher() {
	r := s.Require()
	fetcher, err := NewFetcher("", s.fs)
	r.NoError(err)
	_, ok := fetcher.(*gitFetcher)
	r.True(ok)
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
	var info storage.RevInfo
	r.NoError(json.Unmarshal(ver.Info, &info))
	r.Equal("3652b3c7aa21492717945b6063ae278030101dd8", info.Origin.CommitSHA)
	r.Equal("f17a01bcf457cca0ba9a3432fb7218a064261a14", info.Origin.TreeSHA)

	r.True(len(ver.Manifest) > 0)

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
