/*
 * [INPUT]: Uses an opt-in Testcontainers PostgreSQL service and a force-killed copy of the Go test process.
 * [OUTPUT]: Specifies durable recovery and at-least-once re-execution after a worker process dies during a running River job.
 * [POS]: Serves as process-failure integration coverage for the Hub task queue boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package taskqueue

import (
	"bufio"
	"context"
	"fmt"
	"os"
	"os/exec"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/riverqueue/river"
	"github.com/stretchr/testify/require"
	"github.com/testcontainers/testcontainers-go/modules/postgres"
)

const (
	crashHelperEnv = "SKILLSGO_RIVER_CRASH_HELPER"
	crashDSNEnv    = "SKILLSGO_RIVER_CRASH_DSN"
)

type crashRecoveryArgs struct {
	ID string `json:"id" river:"unique"`
}

func (crashRecoveryArgs) Kind() string { return "crash_recovery_integration" }

func TestRiverRecoversRunningJobAfterProcessCrash(t *testing.T) {
	if os.Getenv("SKILLSGO_TEST_POSTGRES") != "1" {
		t.Skip("set SKILLSGO_TEST_POSTGRES=1 to run the PostgreSQL integration test")
	}
	// The deliberately killed helper inherits the parent's environment. Disable
	// Ryuk for this test so closing the helper's inherited descriptors cannot be
	// mistaken for the end of the parent Testcontainers session; cleanup below
	// remains explicit and scoped to this container.
	t.Setenv("TESTCONTAINERS_RYUK_DISABLED", "true")
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

	options := RiverOptions{JobTimeout: 100 * time.Millisecond, RescueStuckJobsAfter: 200 * time.Millisecond}
	submitter, err := NewRiver(ctx, pool, 1, options)
	require.NoError(t, err)
	require.NoError(t, Register(submitter, func(context.Context, crashRecoveryArgs) error { return nil }))
	require.NoError(t, submitter.Enqueue(ctx, crashRecoveryArgs{ID: "job-1"}, InsertOptions{Unique: true, MaxAttempts: 3}))

	command := exec.Command(os.Args[0], "-test.run=^TestRiverCrashHelper$")
	command.Env = append(os.Environ(), crashHelperEnv+"=1", crashDSNEnv+"="+dsn)
	stdout, err := command.StdoutPipe()
	require.NoError(t, err)
	command.Stderr = os.Stderr
	require.NoError(t, command.Start())
	started := make(chan string, 1)
	go func() {
		scanner := bufio.NewScanner(stdout)
		if scanner.Scan() {
			started <- scanner.Text()
		}
	}()
	select {
	case line := <-started:
		require.Equal(t, "CRASH_JOB_STARTED job-1", line)
	case <-time.After(10 * time.Second):
		_ = command.Process.Kill()
		t.Fatal("crash helper did not start the River job")
	}
	require.NoError(t, command.Process.Kill())
	_ = command.Wait()
	time.Sleep(300 * time.Millisecond)

	recovered := make(chan string, 1)
	recoveryRuntime, err := NewRiver(ctx, pool, 1, options)
	require.NoError(t, err)
	require.NoError(t, Register(recoveryRuntime, func(_ context.Context, args crashRecoveryArgs) error {
		recovered <- args.ID
		return nil
	}))
	require.NoError(t, recoveryRuntime.Start(ctx))
	t.Cleanup(func() {
		stopCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		require.NoError(t, recoveryRuntime.Stop(stopCtx))
	})
	select {
	case id := <-recovered:
		require.Equal(t, "job-1", id)
	case <-time.After(25 * time.Second):
		result, listErr := recoveryRuntime.river.JobList(ctx, river.NewJobListParams().Kinds(crashRecoveryArgs{}.Kind()))
		require.NoError(t, listErr)
		for _, job := range result.Jobs {
			t.Logf("unrecovered job state=%s attempt=%d attempted_at=%v scheduled_at=%v errors=%d", job.State, job.Attempt, job.AttemptedAt, job.ScheduledAt, len(job.Errors))
		}
		t.Fatal("a new River process did not recover the running job")
	}
}

func TestRiverCrashHelper(t *testing.T) {
	if os.Getenv(crashHelperEnv) != "1" {
		t.Skip("helper process")
	}
	ctx := context.Background()
	pool, err := pgxpool.New(ctx, os.Getenv(crashDSNEnv))
	require.NoError(t, err)
	defer pool.Close()
	runtime, err := NewRiver(ctx, pool, 1, RiverOptions{JobTimeout: 100 * time.Millisecond, RescueStuckJobsAfter: 200 * time.Millisecond})
	require.NoError(t, err)
	require.NoError(t, Register(runtime, func(_ context.Context, args crashRecoveryArgs) error {
		fmt.Printf("CRASH_JOB_STARTED %s\n", args.ID)
		select {}
	}))
	require.NoError(t, runtime.Start(ctx))
	select {}
}
