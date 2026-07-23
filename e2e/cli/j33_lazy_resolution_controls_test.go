/*
 * [INPUT]: Depends on real Hub HTTP concurrency, deterministic slow source fixtures, and anonymous Repository routes.
 * [OUTPUT]: Provides black-box coverage for concurrent same-Repository success, global upstream bounds, fresh tag-catalog stability, and retry after capacity release.
 * [POS]: Serves as the lazy-resolution operational-control journey in the cross-product E2E workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"sync"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
)

func TestJ33LazyResolutionControls(t *testing.T) {
	ctx := context.Background()
	container, _ := startEnvironment(t, ctx)
	base := hubURL(t, ctx, container)
	client := &http.Client{Timeout: 15 * time.Second}

	status := func(url string) (int, error) {
		response, err := client.Get(url)
		if err != nil {
			return 0, err
		}
		_, _ = io.Copy(io.Discard, response.Body)
		if err := response.Body.Close(); err != nil {
			return 0, err
		}
		return response.StatusCode, nil
	}
	requireStatus := func(expected int, url string) {
		code, err := status(url)
		require.NoError(t, err)
		require.Equal(t, expected, code)
	}
	collectionList := base + "/fixtures.test/group/subgroup/collection/@v/list"
	firstList, err := client.Get(collectionList)
	require.NoError(t, err)
	firstListBody, err := io.ReadAll(firstList.Body)
	require.NoError(t, err)
	require.NoError(t, firstList.Body.Close())
	require.Equal(t, http.StatusOK, firstList.StatusCode, string(firstListBody))
	secondList, err := client.Get(collectionList)
	require.NoError(t, err)
	secondListBody, err := io.ReadAll(secondList.Body)
	require.NoError(t, err)
	require.NoError(t, secondList.Body.Close())
	require.Equal(t, firstListBody, secondListBody)
	fixtureRepository(container, "collection").TagMain(t, ctx, "v1.2.0")
	thirdList, err := client.Get(collectionList)
	require.NoError(t, err)
	thirdListBody, err := io.ReadAll(thirdList.Body)
	require.NoError(t, err)
	require.NoError(t, thirdList.Body.Close())
	require.Equal(t, firstListBody, thirdListBody, "fresh mutable catalog may remain unchanged inside its TTL")
	requireStatus(http.StatusOK, base+"/fixtures.test/group/subgroup/collection/@v/v1.2.0.info")
	sharedURL := base + "/fixtures.test/group/subgroup/capacity-1/@v/v1.0.0.info"
	start := make(chan struct{})
	type statusResult struct {
		code int
		err  error
	}
	sharedStatuses := make(chan statusResult, 12)
	var wait sync.WaitGroup
	for range 12 {
		wait.Add(1)
		go func() {
			defer wait.Done()
			<-start
			code, err := status(sharedURL)
			sharedStatuses <- statusResult{code: code, err: err}
		}()
	}
	close(start)
	wait.Wait()
	close(sharedStatuses)
	for result := range sharedStatuses {
		require.NoError(t, result.err)
		require.Equal(t, http.StatusOK, result.code)
	}

	capacityStart := make(chan struct{})
	capacityStatuses := make(chan struct {
		index int
		code  int
		err   error
	}, 9)
	for index := 2; index <= 10; index++ {
		wait.Add(1)
		go func(index int) {
			defer wait.Done()
			<-capacityStart
			url := fmt.Sprintf("%s/fixtures.test/group/subgroup/capacity-%d/@v/v1.0.0.info", base, index)
			code, err := status(url)
			capacityStatuses <- struct {
				index int
				code  int
				err   error
			}{index: index, code: code, err: err}
		}(index)
	}
	close(capacityStart)
	wait.Wait()
	close(capacityStatuses)
	overloaded := 0
	overloadedIndex := 0
	for result := range capacityStatuses {
		require.NoError(t, result.err)
		switch result.code {
		case http.StatusOK:
		case http.StatusTooManyRequests:
			overloaded++
			overloadedIndex = result.index
		default:
			t.Fatalf("capacity request %d returned HTTP %d", result.index, result.code)
		}
	}
	require.GreaterOrEqual(t, overloaded, 1)
	requireStatus(http.StatusOK, fmt.Sprintf("%s/fixtures.test/group/subgroup/capacity-%d/@v/v1.0.0.info", base, overloadedIndex))

	missing := base + "/fixtures.test/group/subgroup/does-not-exist/@v/v1.0.0.info"
	requireStatus(http.StatusNotFound, missing)
}
