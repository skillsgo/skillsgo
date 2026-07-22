/*
 * [INPUT]: Depends on the download package imports and contracts declared in this file.
 * [OUTPUT]: Specifies synchronous downloads, strict offline misses, durable asynchronous submission, failure propagation, and cache behavior.
 * [POS]: Serves as test coverage for the download package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package download

import (
	"bytes"
	"context"
	"encoding/json"
	stderrors "errors"
	"io"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/skillsgo/skillsgo/hub/pkg/download/mode"
	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/index/nop"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	"github.com/skillsgo/skillsgo/hub/pkg/skill"
	"github.com/skillsgo/skillsgo/hub/pkg/stash"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	"github.com/skillsgo/skillsgo/hub/pkg/storage/mem"
	"github.com/spf13/afero"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"golang.org/x/sync/errgroup"
)

var testConfigPath = filepath.Join("..", "..", "config.dev.toml")

func getDP(t *testing.T) Protocol {
	t.Helper()
	conf, err := config.GetConf(testConfigPath)
	if err != nil {
		t.Fatalf("Unable to parse config file: %s", err.Error())
	}
	fs := afero.NewOsFs()
	skillFetcher, err := skill.NewFetcher(conf.SkillCacheDir, fs)
	if err != nil {
		t.Fatal(err)
	}
	s, err := mem.NewStorage()
	if err != nil {
		t.Fatal(err)
	}
	st := stash.New(skillFetcher, s, nop.New(), 10*time.Minute)
	return New(&Opts{
		Storage:     s,
		Stasher:     st,
		Lister:      mustVCSLister(t, skillFetcher, conf.TimeoutDuration()),
		NetworkMode: Strict,
	})
}

func mustVCSLister(t *testing.T, fetcher skill.Fetcher, timeout time.Duration) skill.UpstreamLister {
	t.Helper()
	lister, err := skill.NewVCSLister(fetcher, timeout)
	require.NoError(t, err)
	return lister
}

type listTest struct {
	name string
	path string
	tags []string
}

var listTests = []listTest{
	{
		name: "happy tags",
		path: "github.com/athens-artifacts/happy-path",
		tags: []string{"v0.0.1", "v0.0.2", "v0.0.3"},
	},
	{
		name: "no tags",
		path: "github.com/athens-artifacts/no-tags",
		tags: []string{},
	},
}

func TestList(t *testing.T) {
	dp := getDP(t)
	ctx := t.Context()

	for _, tc := range listTests {
		t.Run(tc.name, func(t *testing.T) {
			versions, err := dp.List(ctx, tc.path)
			require.NoError(t, err)
			require.EqualValues(t, tc.tags, versions)
		})
	}
}

type listModeTest struct {
	name         string
	path         string
	storageTags  []string
	upstreamList []string
	upstreamErr  error
	networkmode  string
	wantTags     []string
	wantErr      bool
}

var listModeTests = []listModeTest{
	{
		name:        "strict no tags",
		networkmode: Offline,
		path:        "github.com/athens-artifacts/happy-path",
		wantTags:    []string{},
	},
	{
		name:         "strict tags",
		networkmode:  Strict,
		path:         "github.com/athens-artifacts/happy-path",
		storageTags:  []string{"v0.0.4"},
		upstreamList: []string{"v0.0.1", "v0.0.2", "v0.0.3"},
		wantTags:     []string{"v0.0.1", "v0.0.2", "v0.0.3", "v0.0.4"},
	},
	{
		name:        "offline",
		networkmode: Offline,
		path:        "github.com/athens-artifacts/happy-path",
		storageTags: []string{"v0.0.4"},
		wantTags:    []string{"v0.0.4"},
	},
	{
		name:         "fallback with err",
		networkmode:  Fallback,
		path:         "github.com/athens-artifacts/happy-path",
		storageTags:  []string{"v0.0.4"},
		upstreamList: []string{},
		upstreamErr:  errors.E("test", "unexpected error"),
		wantTags:     []string{"v0.0.4"},
	},
	{
		name:         "fallback upstream not found",
		networkmode:  Fallback,
		path:         "github.com/athens-artifacts/happy-path",
		storageTags:  []string{"v0.0.4"},
		upstreamList: []string{},
		upstreamErr:  errors.E("test", "remote: Repository not found", errors.KindNotFound),
		wantTags:     []string{"v0.0.4"},
	},
	{
		name:         "fallback error with no storage",
		networkmode:  Fallback,
		path:         "github.com/athens-artifacts/happy-path",
		storageTags:  []string{},
		upstreamList: []string{},
		upstreamErr:  errors.E("test", "remote: Repository not found", errors.KindNotFound),
		wantTags:     nil,
		wantErr:      true,
	},
}

func TestListMode(t *testing.T) {
	ctx := t.Context()
	for _, tc := range listModeTests {
		strg, err := mem.NewStorage()
		require.NoError(t, err)
		ml := &mockLister{
			list: tc.upstreamList,
			err:  tc.upstreamErr,
		}
		dp := &protocol{
			storage:     strg,
			lister:      ml,
			networkMode: tc.networkmode,
		}
		for _, tag := range tc.storageTags {
			err := strg.Save(ctx, tc.path, tag, bytes.NewReader([]byte("zip")), nil, []byte("info"))
			require.NoError(t, err)
		}
		t.Run(tc.name, func(t *testing.T) {
			versions, err := dp.List(ctx, tc.path)
			if err != nil && !tc.wantErr {
				t.Fatal(err)
			}
			require.EqualValues(t, tc.wantTags, versions)
			if tc.networkmode == Offline && ml.called {
				t.Fatal("upstream lister must not be called in offline mode")
			}
		})
	}
}

func TestConcurrentLists(t *testing.T) {
	dp := getDP(t)
	ctx := t.Context()

	pkg := "github.com/athens-artifacts/samplelib"
	var pkgErr error

	subPkg := "github.com/athens-artifacts/samplelib/types"
	var subPkgErr error

	var wg sync.WaitGroup
	wg.Add(2)
	go func() {
		_, pkgErr = dp.List(ctx, pkg)
		wg.Done()
	}()
	go func() {
		_, subPkgErr = dp.List(ctx, subPkg)
		wg.Done()
	}()
	wg.Wait()

	if pkgErr != nil {
		t.Fatalf("expected version listing of %v to succeed but got %v", pkg, pkgErr)
	}

	if subPkgErr == nil {
		t.Fatalf("expected version listing of %v to fail because it's a subdirectory", subPkg)
	}
}

type infoTest struct {
	name    string
	path    string
	version string
	info    *storage.RevInfo
}

var infoTests = []infoTest{
	{
		name:    "tagged Skill",
		path:    "github.com/op7418/guizang-ppt-skill",
		version: "v1.1.0",
		info: &storage.RevInfo{
			Version: "v1.1.0",
			Time:    time.Date(2026, 5, 15, 5, 14, 38, 0, time.UTC),
		},
	},
}

func TestInfo(t *testing.T) {
	dp := getDP(t)
	ctx := t.Context()

	for _, tc := range infoTests {
		t.Run(tc.name, func(t *testing.T) {
			bts, err := dp.Info(ctx, tc.path, tc.version)
			require.NoError(t, err)

			var info storage.RevInfo
			dec := json.NewDecoder(bytes.NewReader(bts))
			dec.DisallowUnknownFields()
			err = dec.Decode(&info)
			require.NoError(t, err)

			assert.Equal(t, tc.info.Version, info.Version)
			assert.Equal(t, tc.info.Time, info.Time)
		})
	}
}

type testMod struct {
	mod, ver string
}

var mods = []testMod{
	{"github.com/athens-artifacts/no-tags", "v0.0.2"},
	{"github.com/athens-artifacts/happy-path", "v0.0.0-20180803035119-e4e0177efdb5"},
	{"github.com/athens-artifacts/samplelib", "v1.0.0"},
}

func TestDownloadProtocol(t *testing.T) {
	s, err := mem.NewStorage()
	if err != nil {
		t.Fatal(err)
	}
	mp := &mockFetcher{}
	st := stash.New(mp, s, nop.New(), 10*time.Minute)
	dp := New(&Opts{s, st, nil, nil, Strict, nil})
	ctx := t.Context()

	var eg errgroup.Group
	for i := range mods {
		m := mods[i]
		eg.Go(func() error {
			_, err := dp.Info(ctx, m.mod, m.ver)
			return err
		})
	}

	err = eg.Wait()
	if err != nil {
		t.Fatal(err)
	}

	for _, m := range mods {
		bts, err := dp.Info(ctx, m.mod, m.ver)
		if err != nil {
			t.Fatal(err)
		}
		if !bytes.Equal(bts, []byte(m.mod+"@"+m.ver)) {
			t.Fatalf("unexpected gomod content: %s", bts)
		}
	}
}

type mockFetcher struct{}

func (m *mockFetcher) Fetch(ctx context.Context, mod, ver string) (*storage.Version, error) {
	bts := []byte(mod + "@" + ver)
	return &storage.Version{
		Info: bts,
		Zip:  io.NopCloser(bytes.NewReader(bts)),
	}, nil
}

func TestDownloadProtocolWhenFetchFails(t *testing.T) {
	s, err := mem.NewStorage()
	if err != nil {
		t.Fatal(err)
	}
	fakeMod := testMod{"github.com/athens-artifacts/samplelib", "v1.0.0"}
	bts := []byte(fakeMod.mod + "@" + fakeMod.ver)
	err = s.Save(t.Context(), fakeMod.mod, fakeMod.ver, io.NopCloser(bytes.NewReader(bts)), nil, bts)
	if err != nil {
		t.Fatal(err)
	}
	mp := &notFoundFetcher{}
	st := stash.New(mp, s, nop.New(), 10*time.Minute)
	dp := New(&Opts{s, st, nil, nil, Strict, nil})
	_, err = dp.Info(t.Context(), fakeMod.mod, fakeMod.ver)
	if err != nil {
		t.Errorf("Download protocol should succeed, instead it gave error %s \n", err)
	}
}

func TestAsyncRedirect(t *testing.T) {
	s, err := mem.NewStorage()
	require.NoError(t, err)
	ms := &mockStasher{s, make(chan bool)}
	dp := New(&Opts{
		Stasher: ms,
		Storage: s,
		AsyncStash: func(ctx context.Context, mod, ver string) error {
			go func() { _, _ = ms.Stash(ctx, mod, ver) }()
			return nil
		},
		DownloadFile: &mode.DownloadFile{
			Mode:        mode.Async,
			DownloadURL: "https://gomods.io",
		},
	})
	mod, ver := "github.com/athens-artifacts/happy-path", "v0.0.1"
	_, err = dp.Info(t.Context(), mod, ver)
	if errors.Kind(err) != errors.KindNotFound {
		t.Fatalf("expected async_redirect to enforce a 404 but got %v", errors.Kind(err))
	}
	<-ms.ch
	info, err := dp.Info(t.Context(), mod, ver)
	require.NoError(t, err)
	require.Equal(t, string(info), "info", "expected async fetch to be successful")
}

func TestAsyncDownloadReturnsSubmissionFailure(t *testing.T) {
	s, err := mem.NewStorage()
	require.NoError(t, err)
	wantErr := stderrors.New("task queue unavailable")
	dp := New(&Opts{
		Storage:      s,
		DownloadFile: &mode.DownloadFile{Mode: mode.Async},
		AsyncStash:   func(context.Context, string, string) error { return wantErr },
	})
	_, err = dp.Info(t.Context(), "github.com/acme/skills/-/demo", "v1.0.0")
	require.ErrorIs(t, err, wantErr)
}

func TestOfflineInfoAndZipMissNeverInvokeSourceOrStasher(t *testing.T) {
	s, err := mem.NewStorage()
	require.NoError(t, err)
	called := false
	dp := New(&Opts{
		Storage:      s,
		NetworkMode:  Offline,
		DownloadFile: &mode.DownloadFile{Mode: mode.Sync},
		Stasher: stashFunc(func(context.Context, string, string) (string, error) {
			called = true
			return "", stderrors.New("must not be called")
		}),
	})
	_, infoErr := dp.Info(t.Context(), "github.com/acme/skills", "v1.0.0")
	_, zipErr := dp.Zip(t.Context(), "github.com/acme/skills", "v1.0.0")
	require.Equal(t, errors.KindNotFound, errors.Kind(infoErr))
	require.Equal(t, errors.KindNotFound, errors.Kind(zipErr))
	require.False(t, called)
}

type stashFunc func(context.Context, string, string) (string, error)

func (function stashFunc) Stash(ctx context.Context, module, version string) (string, error) {
	return function(ctx, module, version)
}

type mockStasher struct {
	s  storage.Backend
	ch chan bool
}

func (ms *mockStasher) Stash(ctx context.Context, mod string, ver string) (string, error) {
	err := ms.s.Save(ctx, mod, ver, strings.NewReader("zip"), nil, []byte("info"))
	ms.ch <- true // signal async stashing is done
	return ver, err
}

type notFoundFetcher struct{}

func (m *notFoundFetcher) Fetch(ctx context.Context, mod, ver string) (*storage.Version, error) {
	const op errors.Op = "goGetFetcher.Fetch"
	return nil, errors.E(op, "Fetcher error")
}

type mockLister struct {
	called bool
	list   []string
	err    error
}

func (ml *mockLister) List(ctx context.Context, mod string) (*storage.RevInfo, []string, error) {
	ml.called = true
	return nil, ml.list, ml.err
}

type testEntry struct {
	msg string
}

var _ log.Entry = &testEntry{}

func (e *testEntry) Debugf(format string, args ...any) {
	e.msg = format
}
func (*testEntry) Infof(format string, args ...any)           {}
func (*testEntry) Warnf(format string, args ...any)           {}
func (*testEntry) Errorf(format string, args ...any)          {}
func (*testEntry) WithFields(fields map[string]any) log.Entry { return nil }
func (*testEntry) SystemErr(err error)                        {}

func Test_copyContextWithCustomTimeout(t *testing.T) {
	testEntry := &testEntry{}

	// create a context with a logger entry
	logctx := log.SetEntryInContext(t.Context(), testEntry)

	// check the log work as expected
	log.EntryFromContext(logctx).Debugf("first test")
	require.Equal(t, "first test", testEntry.msg)

	// use copyContextWithCustomTimeout to create a new context with a custom timeout,
	// and the returned context should have the same logger entry
	newCtx, cancel := copyContextWithCustomTimeout(logctx, 10*time.Second)
	defer cancel()

	// check the log work as expected
	log.EntryFromContext(newCtx).Debugf("second test")
	require.Equal(t, "second test", testEntry.msg)
}
