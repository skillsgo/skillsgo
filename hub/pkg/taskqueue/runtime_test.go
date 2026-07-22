/*
 * [INPUT]: Depends on typed synchronous jobs, periodic scheduling, and deterministic handlers.
 * [OUTPUT]: Specifies type-safe registration, dispatch, periodic execution, cancellation, validation, and lifecycle behavior.
 * [POS]: Serves as unit coverage for the Hub task queue infrastructure boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package taskqueue

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/riverqueue/river"
	"github.com/riverqueue/river/rivertype"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type reindexArgs struct {
	ID string `json:"id" river:"unique"`
}

func (reindexArgs) Kind() string { return "reindex" }

type refreshArgs struct{}

func (refreshArgs) Kind() string { return "refresh" }

type blockingArgs struct{}

func (blockingArgs) Kind() string { return "blocking" }

type missingArgs struct{}

func (missingArgs) Kind() string { return "missing" }

func TestSynchronousRuntimeDispatchesTypedJob(t *testing.T) {
	var received reindexArgs
	runtime := NewSynchronous()
	require.NoError(t, Register(runtime, func(_ context.Context, args reindexArgs) error {
		received = args
		return nil
	}))

	require.NoError(t, runtime.Start(t.Context()))
	require.NoError(t, runtime.Enqueue(t.Context(), reindexArgs{ID: "skill-1"}, InsertOptions{}))
	assert.Equal(t, "skill-1", received.ID)
	require.NoError(t, runtime.Stop(t.Context()))
	require.NoError(t, runtime.Stop(t.Context()))
}

func TestSynchronousRuntimeRejectsUnknownJob(t *testing.T) {
	err := NewSynchronous().Enqueue(t.Context(), missingArgs{}, InsertOptions{})
	require.EqualError(t, err, `job handler "missing" is not registered`)
}

func TestTypedWorkerFinalizesTerminalFailure(t *testing.T) {
	runtime := NewSynchronous()
	finalized := make(chan reindexArgs, 1)
	handler := Handler[reindexArgs](func(context.Context, reindexArgs) error { return errors.New("failed") })
	require.NoError(t, Register(runtime, handler))
	require.NoError(t, RegisterFailureHandler(runtime, func(_ context.Context, args reindexArgs, _ error) error {
		finalized <- args
		return nil
	}))
	worker := &typedWorker[reindexArgs]{handler: handler, runtime: runtime, kind: reindexArgs{}.Kind()}
	err := worker.Work(t.Context(), &river.Job[reindexArgs]{JobRow: &rivertype.JobRow{Attempt: 2, MaxAttempts: 2}, Args: reindexArgs{ID: "skill-1"}})
	require.EqualError(t, err, "failed")
	require.Equal(t, "skill-1", (<-finalized).ID)
}

func TestSynchronousRuntimeRegistersPeriodicJobsBeforeStart(t *testing.T) {
	executed := make(chan struct{}, 1)
	runtime := NewSynchronous()
	require.NoError(t, Register(runtime, func(context.Context, refreshArgs) error {
		executed <- struct{}{}
		return nil
	}))
	require.NoError(t, runtime.Every(refreshArgs{}, InsertOptions{}, time.Hour, true))
	require.NoError(t, runtime.Start(t.Context()))
	select {
	case <-executed:
	case <-time.After(time.Second):
		t.Fatal("periodic job did not run on start")
	}
	require.EqualError(t, Register(runtime, func(context.Context, missingArgs) error { return nil }), "cannot register job handler after runtime start")
	require.NoError(t, runtime.Stop(t.Context()))
}

func TestSynchronousRuntimeStopCancelsRunningPeriodicHandler(t *testing.T) {
	started := make(chan struct{})
	finished := make(chan struct{})
	runtime := NewSynchronous()
	require.NoError(t, Register(runtime, func(ctx context.Context, _ blockingArgs) error {
		close(started)
		<-ctx.Done()
		close(finished)
		return ctx.Err()
	}))
	require.NoError(t, runtime.Every(blockingArgs{}, InsertOptions{}, time.Hour, true))
	require.NoError(t, runtime.Start(t.Context()))
	select {
	case <-started:
	case <-time.After(time.Second):
		t.Fatal("periodic handler did not start")
	}
	require.NoError(t, runtime.Stop(t.Context()))
	select {
	case <-finished:
	default:
		t.Fatal("Stop returned before the periodic handler observed cancellation")
	}
}
