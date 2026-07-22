/*
 * [INPUT]: Uses the River runtime against an opt-in Testcontainers PostgreSQL service.
 * [OUTPUT]: Specifies durable River migration, registration, periodic scheduling, submission, retry exhaustion, and worker execution through a shared pgx pool.
 * [POS]: Serves as real-PostgreSQL integration coverage for the Hub task queue boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package taskqueue

import (
	"context"
	"errors"
	"os"
	"sync/atomic"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/riverqueue/river"
	"github.com/riverqueue/river/rivertype"
	"github.com/stretchr/testify/require"
	"github.com/testcontainers/testcontainers-go/modules/postgres"
)

type periodicIntegrationArgs struct{}

func (periodicIntegrationArgs) Kind() string { return "periodic_integration" }

type uniqueIntegrationArgs struct {
	ID string `json:"id" river:"unique"`
}

func (uniqueIntegrationArgs) Kind() string { return "unique_integration" }

type retryIntegrationArgs struct{}

func (retryIntegrationArgs) Kind() string { return "retry_integration" }

type exhaustedIntegrationArgs struct{}

func (exhaustedIntegrationArgs) Kind() string { return "exhausted_integration" }

func TestRiverRuntime(t *testing.T) {
	if os.Getenv("SKILLSGO_TEST_POSTGRES") != "1" {
		t.Skip("set SKILLSGO_TEST_POSTGRES=1 to run the PostgreSQL integration test")
	}
	ctx := t.Context()
	container, err := postgres.Run(ctx, "postgres:17-alpine",
		postgres.WithDatabase("skillsgo"),
		postgres.WithUsername("skillsgo"),
		postgres.WithPassword("skillsgo"),
		postgres.BasicWaitStrategies(),
	)
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, container.Terminate(context.Background())) })

	dsn, err := container.ConnectionString(ctx, "sslmode=disable")
	require.NoError(t, err)
	pool, err := pgxpool.New(ctx, dsn)
	require.NoError(t, err)
	t.Cleanup(pool.Close)

	executed := make(chan string, 1)
	periodicExecuted := make(chan struct{}, 1)
	uniqueExecuted := make(chan struct{}, 2)
	retrySucceeded := make(chan struct{}, 1)
	var uniqueCalls atomic.Int32
	var retryCalls atomic.Int32
	var exhaustedCalls atomic.Int32
	runtime, err := NewRiver(ctx, pool, 2)
	require.NoError(t, err)
	secondRuntime, err := NewRiver(ctx, pool, 2)
	require.NoError(t, err)
	registerHandlers := func(runtime *Runtime) {
		require.NoError(t, Register(runtime, func(_ context.Context, args reindexArgs) error {
			executed <- args.ID
			return nil
		}))
		require.NoError(t, Register(runtime, func(context.Context, periodicIntegrationArgs) error {
			periodicExecuted <- struct{}{}
			return nil
		}))
		require.NoError(t, Register(runtime, func(context.Context, uniqueIntegrationArgs) error {
			uniqueCalls.Add(1)
			uniqueExecuted <- struct{}{}
			return nil
		}))
		require.NoError(t, Register(runtime, func(context.Context, retryIntegrationArgs) error {
			if retryCalls.Add(1) == 1 {
				return errors.New("transient failure")
			}
			retrySucceeded <- struct{}{}
			return nil
		}))
		require.NoError(t, Register(runtime, func(context.Context, exhaustedIntegrationArgs) error {
			exhaustedCalls.Add(1)
			return errors.New("permanent failure")
		}))
	}
	registerHandlers(runtime)
	registerHandlers(secondRuntime)
	require.NoError(t, runtime.Every(periodicIntegrationArgs{}, InsertOptions{Unique: true, MaxAttempts: 3}, time.Hour, true))
	require.NoError(t, runtime.Enqueue(ctx, uniqueIntegrationArgs{ID: "same"}, InsertOptions{Unique: true, MaxAttempts: 3}))
	active, err := HasActiveJob(ctx, runtime, uniqueIntegrationArgs{ID: "same"})
	require.NoError(t, err)
	require.True(t, active)
	active, err = HasActiveJob(ctx, runtime, uniqueIntegrationArgs{ID: "missing"})
	require.NoError(t, err)
	require.False(t, active)
	require.NoError(t, secondRuntime.Enqueue(ctx, uniqueIntegrationArgs{ID: "same"}, InsertOptions{Unique: true, MaxAttempts: 3}))
	require.NoError(t, runtime.Enqueue(ctx, retryIntegrationArgs{}, InsertOptions{Unique: true, MaxAttempts: 3}))
	require.NoError(t, runtime.Enqueue(ctx, exhaustedIntegrationArgs{}, InsertOptions{Unique: true, MaxAttempts: 2}))
	require.NoError(t, runtime.Start(ctx))
	require.NoError(t, secondRuntime.Start(ctx))
	t.Cleanup(func() {
		stopCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		require.NoError(t, secondRuntime.Stop(stopCtx))
		require.NoError(t, runtime.Stop(stopCtx))
	})
	select {
	case <-periodicExecuted:
	case <-time.After(10 * time.Second):
		t.Fatal("River periodic task was not executed on start")
	}
	select {
	case <-uniqueExecuted:
	case <-time.After(10 * time.Second):
		t.Fatal("unique River task was not executed")
	}
	time.Sleep(500 * time.Millisecond)
	require.Equal(t, int32(1), uniqueCalls.Load(), "two clients must not execute duplicate active jobs")
	select {
	case <-retrySucceeded:
	case <-time.After(10 * time.Second):
		t.Fatal("River task did not succeed after a transient failure")
	}
	require.Equal(t, int32(2), retryCalls.Load())
	exhaustedJob := waitForJobState(t, runtime.river, exhaustedIntegrationArgs{}.Kind(), rivertype.JobStateDiscarded, 10*time.Second)
	require.Equal(t, int32(2), exhaustedCalls.Load())
	require.Equal(t, 2, exhaustedJob.Attempt)
	require.Len(t, exhaustedJob.Errors, 2)
	require.Contains(t, exhaustedJob.Errors[1].Error, "permanent failure")

	require.NoError(t, runtime.Enqueue(ctx, reindexArgs{ID: "skill-1"}, InsertOptions{}))
	select {
	case id := <-executed:
		require.Equal(t, "skill-1", id)
	case <-time.After(10 * time.Second):
		t.Fatal("River task was not executed")
	}
}

func waitForJobState(t *testing.T, client *river.Client[pgx.Tx], kind string, state rivertype.JobState, timeout time.Duration) *rivertype.JobRow {
	t.Helper()
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		result, err := client.JobList(t.Context(), river.NewJobListParams().Kinds(kind).States(state))
		require.NoError(t, err)
		if len(result.Jobs) == 1 {
			return result.Jobs[0]
		}
		time.Sleep(50 * time.Millisecond)
	}
	t.Fatalf("job %q did not reach state %q", kind, state)
	return nil
}
