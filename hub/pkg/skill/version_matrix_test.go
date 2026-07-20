/*
 * [INPUT]: Depends on deterministic local Git Repository timelines, movable and immutable revision resolution, and the injected-clock tag catalog.
 * [OUTPUT]: Specifies the 12-row Repository version-selection matrix and 6-row cache/freshness matrix using C1, C2, F1, F2, and V1 semantics.
 * [POS]: Serves as the table-driven executable version-query matrix for the Hub Skill source module.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skill

import (
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
	"golang.org/x/mod/module"
)

type repositoryTimeline string

const (
	timelineNoTagsC1     repositoryTimeline = "no tags at C1"
	timelineNoTagsC2     repositoryTimeline = "no tags at C2"
	timelineTaggedC1     repositoryTimeline = "V1 tags C1"
	timelineTransitionC2 repositoryTimeline = "no tags becomes V1 at C1 then advances to C2"
)

type matrixVersion string

const (
	matrixF1 matrixVersion = "F1"
	matrixF2 matrixVersion = "F2"
	matrixV1 matrixVersion = "V1"
)

type timelineState struct {
	fixture *localRepositoryFixture
	c1      string
	c2      string
	f1      string
}

func prepareTimeline(t *testing.T, timeline repositoryTimeline) timelineState {
	t.Helper()
	f := newLocalRepositoryFixture(t)
	state := timelineState{
		fixture: f,
		c1:      strings.TrimSpace(runGit(t, f.work, "rev-parse", "HEAD")),
	}

	if timeline == timelineNoTagsC1 || timeline == timelineNoTagsC2 || timeline == timelineTransitionC2 {
		runGit(t, f.work, "tag", "-d", "v1.0.0")
		runGit(t, f.work, "push", "origin", ":refs/tags/v1.0.0")
		resolved, err := f.fetcher.Resolve(t.Context(), f.skillID, "main")
		require.NoError(t, err)
		state.f1 = resolved.Version
		require.True(t, strings.HasPrefix(state.f1, "v0.0.0-"), state.f1)
	}

	if timeline == timelineTransitionC2 {
		runGit(t, f.work, "tag", "v1.0.0", state.c1)
		runGit(t, f.work, "push", "origin", "v1.0.0")
	}
	if timeline == timelineNoTagsC2 || timeline == timelineTransitionC2 {
		f.writeSkill(t, ".", "repo", "C2")
		f.commit(t, "C2")
		runGit(t, f.work, "push", "origin", "HEAD")
		state.c2 = strings.TrimSpace(runGit(t, f.work, "rev-parse", "HEAD"))
	}
	return state
}

func matrixSelector(state timelineState, query matrixVersion) string {
	switch query {
	case matrixF1:
		return state.f1
	case matrixV1:
		return "v1.0.0"
	default:
		panic("matrixSelector requires an immutable matrix version")
	}
}

func TestRepositoryVersionSelectionMatrix(t *testing.T) {
	tests := []struct {
		name     string
		timeline repositoryTimeline
		selector string
		want     matrixVersion
	}{
		{name: "no tags C1 latest selects F1", timeline: timelineNoTagsC1, selector: "latest", want: matrixF1},
		{name: "no tags C1 main selects F1", timeline: timelineNoTagsC1, selector: "main", want: matrixF1},
		{name: "no tags C1 exact F1 remains F1", timeline: timelineNoTagsC1, selector: "F1", want: matrixF1},
		{name: "no tags C2 latest selects F2", timeline: timelineNoTagsC2, selector: "latest", want: matrixF2},
		{name: "no tags C2 main selects F2", timeline: timelineNoTagsC2, selector: "main", want: matrixF2},
		{name: "no tags C2 exact F1 remains F1", timeline: timelineNoTagsC2, selector: "F1", want: matrixF1},
		{name: "tagged C1 latest selects V1", timeline: timelineTaggedC1, selector: "latest", want: matrixV1},
		{name: "tagged C1 main canonicalizes to V1", timeline: timelineTaggedC1, selector: "main", want: matrixV1},
		{name: "tagged C1 exact V1 remains V1", timeline: timelineTaggedC1, selector: "V1", want: matrixV1},
		{name: "transitioned C2 latest stays V1", timeline: timelineTransitionC2, selector: "latest", want: matrixV1},
		{name: "transitioned C2 main selects F2 based on V1", timeline: timelineTransitionC2, selector: "main", want: matrixF2},
		{name: "transitioned C2 exact old F1 remains F1", timeline: timelineTransitionC2, selector: "F1", want: matrixF1},
	}

	require.Len(t, tests, 12, "version-selection matrix row count")
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			state := prepareTimeline(t, tc.timeline)
			selector := tc.selector
			if selector == "F1" {
				selector = matrixSelector(state, matrixF1)
			} else if selector == "V1" {
				selector = matrixSelector(state, matrixV1)
			}

			resolved, err := state.fixture.fetcher.Resolve(t.Context(), state.fixture.skillID, selector)
			require.NoError(t, err)
			switch tc.want {
			case matrixF1:
				require.Equal(t, state.c1, resolved.CommitSHA)
				require.Equal(t, state.f1, resolved.Version)
			case matrixF2:
				require.Equal(t, state.c2, resolved.CommitSHA)
				require.True(t, module.IsPseudoVersion(resolved.Version), resolved.Version)
				if tc.timeline == timelineTransitionC2 {
					require.True(t, strings.HasPrefix(resolved.Version, "v1.0.1-0."), resolved.Version)
				} else {
					require.True(t, strings.HasPrefix(resolved.Version, "v0.0.0-"), resolved.Version)
				}
			case matrixV1:
				require.Equal(t, state.c1, resolved.CommitSHA)
				require.Equal(t, "v1.0.0", resolved.Version)
			}
		})
	}
}

func TestRepositoryCacheAndFreshnessMatrix(t *testing.T) {
	tests := []struct {
		name string
		run  func(*testing.T)
	}{
		{name: "first movable lookup resolves C1", run: func(t *testing.T) {
			f := newLocalRepositoryFixture(t)
			c1 := strings.TrimSpace(runGit(t, f.work, "rev-parse", "HEAD"))
			runGit(t, f.work, "tag", "-d", "v1.0.0")
			runGit(t, f.work, "push", "origin", ":refs/tags/v1.0.0")
			resolved, err := f.fetcher.Resolve(t.Context(), f.skillID, "main")
			require.NoError(t, err)
			require.Equal(t, c1, resolved.CommitSHA)
		}},
		{name: "repeated movable lookup observes C2", run: func(t *testing.T) {
			state := prepareTimeline(t, timelineNoTagsC1)
			state.fixture.writeSkill(t, ".", "repo", "C2")
			state.fixture.commit(t, "C2")
			runGit(t, state.fixture.work, "push", "origin", "HEAD")
			c2 := strings.TrimSpace(runGit(t, state.fixture.work, "rev-parse", "HEAD"))
			resolved, err := state.fixture.fetcher.Resolve(t.Context(), state.fixture.skillID, "main")
			require.NoError(t, err)
			require.Equal(t, c2, resolved.CommitSHA)
		}},
		{name: "immutable F1 remains C1 after C2", run: func(t *testing.T) {
			state := prepareTimeline(t, timelineNoTagsC2)
			resolved, err := state.fixture.fetcher.Resolve(t.Context(), state.fixture.skillID, state.f1)
			require.NoError(t, err)
			require.Equal(t, state.c1, resolved.CommitSHA)
		}},
		{name: "tag catalog first lookup returns V1", run: func(t *testing.T) {
			versions := tagCatalogAt(t, 0, false)
			require.Equal(t, []string{"v1.0.0"}, versions)
		}},
		{name: "fresh tag catalog hides newly pushed V2", run: func(t *testing.T) {
			versions := tagCatalogAt(t, 0, true)
			require.Equal(t, []string{"v1.0.0"}, versions)
		}},
		{name: "expired tag catalog observes newly pushed V2", run: func(t *testing.T) {
			versions := tagCatalogAt(t, time.Minute+time.Nanosecond, true)
			require.Equal(t, []string{"v1.0.0", "v2.0.0"}, versions)
		}},
	}

	require.Len(t, tests, 6, "cache/freshness matrix row count")
	for _, tc := range tests {
		t.Run(tc.name, tc.run)
	}
}

func tagCatalogAt(t *testing.T, elapsed time.Duration, pushV2 bool) []string {
	t.Helper()
	f := newLocalRepositoryFixture(t)
	now := time.Date(2026, 7, 18, 12, 0, 0, 0, time.UTC)
	lister := &vcsLister{
		repositories: f.fetcher,
		timeout:      time.Minute,
		ttl:          time.Minute,
		now:          func() time.Time { return now },
		catalogs:     map[string]tagCatalog{},
	}
	_, versions, err := lister.List(t.Context(), f.skillID)
	require.NoError(t, err)
	if !pushV2 {
		return versions
	}
	runGit(t, f.work, "tag", "v2.0.0")
	runGit(t, f.work, "push", "origin", "v2.0.0")
	now = now.Add(elapsed)
	_, versions, err = lister.List(t.Context(), f.skillID)
	require.NoError(t, err)
	return versions
}
