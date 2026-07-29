/*
 * [INPUT]: Depends on typed synchronous jobs, workload queue options, sleep-first periodic scheduling, River job-state rows, and deterministic handlers.
 * [OUTPUT]: Specifies type-safe registration, bounded queue allocation, dispatch, periodic execution, cancellation, validation, and due-versus-future work decisions.
 * [POS]: Serves as unit coverage for the Hub task queue infrastructure boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package taskqueue

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
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

type unlimitedArgs struct{}

func (unlimitedArgs) Kind() string              { return "unlimited" }
func (unlimitedArgs) JobTimeout() time.Duration { return -1 }

func TestBalancedQueueWorkersPreservesTotalBudget(t *testing.T) {
	queues := BalancedQueueWorkers(10)
	require.Equal(t, 4, queues[river.QueueDefault])
	require.Equal(t, 5, queues[QueueSource])
	require.Equal(t, 1, queues[QueueMaintenance])
	require.Equal(t, QueueSource, riverInsertOptions(InsertOptions{Queue: QueueSource}).Queue)
}

func TestUniqueInsertOptionsDeduplicateOnlyActiveJobs(t *testing.T) {
	opts := riverInsertOptions(InsertOptions{Unique: true})
	require.True(t, opts.UniqueOpts.ByArgs)
	require.ElementsMatch(t, []rivertype.JobState{
		rivertype.JobStateAvailable,
		rivertype.JobStatePending,
		rivertype.JobStateRetryable,
		rivertype.JobStateRunning,
		rivertype.JobStateScheduled,
	}, opts.UniqueOpts.ByState)
	require.NotContains(t, opts.UniqueOpts.ByState, rivertype.JobStateCompleted)
}

func TestTypedWorkerUsesJobSpecificTimeout(t *testing.T) {
	unlimitedWorker := &typedWorker[unlimitedArgs]{}
	require.Equal(t, time.Duration(-1), unlimitedWorker.Timeout(&river.Job[unlimitedArgs]{Args: unlimitedArgs{}}))

	defaultWorker := &typedWorker[reindexArgs]{}
	require.Zero(t, defaultWorker.Timeout(&river.Job[reindexArgs]{Args: reindexArgs{}}))
}

func TestRiverDefaultRetryPolicyUsesIncreasingExponentialBackoff(t *testing.T) {
	policy := &river.DefaultClientRetryPolicy{}
	now := time.Now().UTC()
	delays := make([]time.Duration, 0, 4)
	for errorsCount := 0; errorsCount < 4; errorsCount++ {
		errors := make([]rivertype.AttemptError, errorsCount)
		next := policy.NextRetry(&rivertype.JobRow{Errors: errors})
		delays = append(delays, next.Sub(now))
	}
	for index := 1; index < len(delays); index++ {
		require.Greater(t, delays[index], delays[index-1]*2, "retry delay must grow exponentially rather than use a fixed interval")
	}
}

func TestWorkScheduleKeepsDueWorkRunningAndArmsFutureWake(t *testing.T) {
	now := time.Date(2026, time.July, 27, 12, 0, 0, 0, time.UTC)
	active, next, err := workSchedule(now, []*rivertype.JobRow{{State: rivertype.JobStateRunning}}, nil)
	require.NoError(t, err)
	require.True(t, active)
	require.Nil(t, next)

	due := now.Add(-time.Second)
	active, next, err = workSchedule(now, nil, []*rivertype.JobRow{{State: rivertype.JobStateRetryable, ScheduledAt: due}})
	require.NoError(t, err)
	require.True(t, active)
	require.Equal(t, due, *next)

	future := now.Add(time.Hour)
	active, next, err = workSchedule(now, nil, []*rivertype.JobRow{{State: rivertype.JobStateScheduled, ScheduledAt: future}})
	require.NoError(t, err)
	require.False(t, active)
	require.Equal(t, future, *next)

	active, next, err = workSchedule(now, nil, nil)
	require.NoError(t, err)
	require.False(t, active)
	require.Nil(t, next)
}

func TestWakeIsNonBlockingAndCoalescesBursts(t *testing.T) {
	runtime := NewSynchronous()
	runtime.river = &river.Client[pgx.Tx]{}
	runtime.Wake()
	runtime.Wake()
	require.Len(t, runtime.wake, 1)
}

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

func TestSynchronousRuntimeRunsPeriodicJobAfterInterval(t *testing.T) {
	executed := make(chan struct{}, 1)
	runtime := NewSynchronous()
	require.NoError(t, Register(runtime, func(context.Context, refreshArgs) error {
		executed <- struct{}{}
		return nil
	}))
	require.NoError(t, runtime.Every(refreshArgs{}, InsertOptions{}, 10*time.Millisecond, false))
	require.NoError(t, runtime.Start(t.Context()))
	t.Cleanup(func() { require.NoError(t, runtime.Stop(context.Background())) })
	select {
	case <-executed:
	case <-time.After(time.Second):
		t.Fatal("periodic job did not execute after its interval")
	}
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
