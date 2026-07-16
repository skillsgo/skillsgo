/*
 * [INPUT]: Depends on the stash package imports and contracts declared in this file.
 * [OUTPUT]: Specifies the stash package behavior covered by stasher_test.go.
 * [POS]: Serves as test coverage for the stash package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package stash

import (
	"context"
	"io"
	"strings"
	"testing"
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/index/nop"
	"github.com/skillsgo/skillsgo/hub/pkg/skill"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
)

type stashTest struct {
	name             string
	ver              string // the given version
	modVer           string // the version skill.Fetcher returns
	shouldCallExists bool   // whether storage should be checked before saving
	existsResponse   bool   // the response of storage.Exists if it's called
	shouldCallSave   bool   // whether save or not should be called
}

var stashTests = [...]stashTest{
	{
		name:             "non semver",
		ver:              "master",
		modVer:           "v1.2.3",
		shouldCallExists: true,
		existsResponse:   false,
		shouldCallSave:   true,
	},
	{
		name:             "no storage override",
		ver:              "master",
		modVer:           "v1.2.3",
		shouldCallExists: true,
		existsResponse:   true,
		shouldCallSave:   false,
	},
	{
		name:             "equal semver",
		ver:              "v2.0.0",
		modVer:           "v2.0.0",
		shouldCallExists: true,
		existsResponse:   false,
		shouldCallSave:   true,
	},
}

func TestStash(t *testing.T) {
	for _, testCase := range stashTests {
		t.Run(testCase.name, func(t *testing.T) {
			var ms mockStorage
			ms.existsResponse = testCase.existsResponse
			var mf mockFetcher
			mf.ver = testCase.modVer

			s := New(&mf, &ms, nop.New(), 10*time.Minute)
			newVersion, err := s.Stash(t.Context(), "module", testCase.ver)
			if err != nil {
				t.Fatal(err)
			}
			if newVersion != testCase.modVer {
				t.Fatalf("expected Stash to return %v from skill.Fetcher but got %v", testCase.modVer, newVersion)
			}
			if testCase.shouldCallExists != ms.existsCalled {
				t.Fatalf("expected a call to storage.Exists to be %v but got %v", testCase.shouldCallExists, ms.existsCalled)
			}
			if testCase.shouldCallSave {
				if ms.givenVersion != testCase.modVer {
					t.Fatalf("expected storage.Save to be called with version %v but got %v", testCase.modVer, ms.givenVersion)
				}
			} else if ms.saveCalled {
				t.Fatalf("expected save not to be called")
			}
		})
	}
}

type mockStorage struct {
	storage.Backend
	existsCalled   bool
	saveCalled     bool
	givenVersion   string
	existsResponse bool
}

func (ms *mockStorage) Save(ctx context.Context, module, version string, manifest []byte, zip io.Reader, zipMD5 []byte, info []byte) error {
	ms.saveCalled = true
	ms.givenVersion = version
	return nil
}

func (ms *mockStorage) Exists(ctx context.Context, mod, ver string) (bool, error) {
	ms.existsCalled = true
	return ms.existsResponse, nil
}

type mockFetcher struct {
	ver string
}

func (mf *mockFetcher) Fetch(ctx context.Context, mod, ver string) (*storage.Version, error) {
	return &storage.Version{
		Info:     []byte("info"),
		Manifest: []byte("gomod"),
		Zip:      io.NopCloser(strings.NewReader("zipfile")),
		Semver:   mf.ver,
	}, nil
}

func TestResolvedFetcherChecksCanonicalVersionBeforeFetching(t *testing.T) {
	strg := &resolvedCacheStorage{versions: make(map[string]bool)}
	fetcher := &mockResolvedFetcher{
		resolution: skill.Resolution{
			Requested: "main",
			Version:   "v0.0.0-20260715120000-123456789abc",
		},
	}
	stasher := New(fetcher, strg, nop.New(), 10*time.Minute)

	for range 2 {
		version, err := stasher.Stash(t.Context(), "github.com/owner/repo", "main")
		if err != nil {
			t.Fatal(err)
		}
		if version != fetcher.resolution.Version {
			t.Fatalf("expected %s, got %s", fetcher.resolution.Version, version)
		}
	}

	if fetcher.resolveCalls != 2 {
		t.Fatalf("expected main to be resolved twice, got %d", fetcher.resolveCalls)
	}
	if fetcher.fetchResolvedCalls != 1 {
		t.Fatalf("expected artifact to be fetched once, got %d", fetcher.fetchResolvedCalls)
	}
}

func TestResolvedFetcherUsesCachedCanonicalVersionBeforeResolve(t *testing.T) {
	strg := &resolvedCacheStorage{versions: map[string]bool{"v1.2.3": true}}
	fetcher := &mockResolvedFetcher{}
	stasher := New(fetcher, strg, nop.New(), 10*time.Minute)

	version, err := stasher.Stash(t.Context(), "github.com/owner/repo", "v1.2.3")
	if err != nil {
		t.Fatal(err)
	}
	if version != "v1.2.3" {
		t.Fatalf("expected v1.2.3, got %s", version)
	}
	if fetcher.resolveCalls != 0 || fetcher.fetchResolvedCalls != 0 {
		t.Fatal("cached canonical version must not access upstream")
	}
}

type resolvedCacheStorage struct {
	storage.Backend
	versions map[string]bool
}

func (s *resolvedCacheStorage) Exists(_ context.Context, _, version string) (bool, error) {
	return s.versions[version], nil
}

func (s *resolvedCacheStorage) Save(_ context.Context, _, version string, _ []byte, _ io.Reader, _, _ []byte) error {
	s.versions[version] = true
	return nil
}

type mockResolvedFetcher struct {
	resolution         skill.Resolution
	resolveCalls       int
	fetchResolvedCalls int
}

func (f *mockResolvedFetcher) Resolve(_ context.Context, _, _ string) (*skill.Resolution, error) {
	f.resolveCalls++
	resolution := f.resolution
	return &resolution, nil
}

func (f *mockResolvedFetcher) FetchResolved(_ context.Context, _ string, resolution *skill.Resolution) (*storage.Version, error) {
	f.fetchResolvedCalls++
	return &storage.Version{
		Info:     []byte("info"),
		Manifest: []byte("manifest"),
		Zip:      io.NopCloser(strings.NewReader("zipfile")),
		Semver:   resolution.Version,
	}, nil
}

func (f *mockResolvedFetcher) Fetch(context.Context, string, string) (*storage.Version, error) {
	panic("legacy Fetch must not be called for a ResolvedFetcher")
}
