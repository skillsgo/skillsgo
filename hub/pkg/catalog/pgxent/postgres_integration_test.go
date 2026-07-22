/*
 * [INPUT]: Uses generated Catalog Ent builders through the pgx adapter against opt-in Testcontainers PostgreSQL.
 * [OUTPUT]: Specifies native pgx transaction commit, rollback, Skill/Repository CRUD, relation traversal, dynamic projection, and atomic River visibility.
 * [POS]: Serves as real-PostgreSQL conformance coverage for the Ent pgx transaction adapter.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package pgxent_test

import (
	"context"
	"errors"
	"os"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	catalogent "github.com/skillsgo/skillsgo/hub/pkg/catalog/ent"
	"github.com/skillsgo/skillsgo/hub/pkg/catalog/ent/repository"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/skillsgo/skillsgo/hub/pkg/taskqueue"
	"github.com/stretchr/testify/require"
	"github.com/testcontainers/testcontainers-go/modules/postgres"
)

type verifyRepositoryArgs struct {
	RepositoryID string `json:"repository_id" river:"unique"`
}

func (verifyRepositoryArgs) Kind() string { return "verify_repository" }

func TestNativePgxTransactionEntClient(t *testing.T) {
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
	metadata, err := catalog.Open(ctx, config.DatabaseConfig{
		Type: "postgres", DSN: dsn, MaxOpenConns: 5, MaxIdleConns: 2,
	})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, metadata.Close()) })

	require.NoError(t, metadata.WithPostgresTx(ctx, func(client *catalogent.Client, _ pgx.Tx) error {
		now := time.Now().UTC().Truncate(time.Microsecond)
		repo, err := client.Repository.Create().
			SetSourceHost("github.com").
			SetRepositoryPath("skillsgo/pgxent").
			SetRepositoryID("github.com/skillsgo/pgxent").
			SetDescription("before").
			SetSourceMetadataCheckedAt(now).
			Save(ctx)
		if err != nil {
			return err
		}
		if _, err := client.Repository.UpdateOne(repo).SetDescription("after").Save(ctx); err != nil {
			return err
		}
		description, err := client.Repository.Query().
			Where(repository.IDEQ(repo.ID)).
			Select(repository.FieldDescription).
			String(ctx)
		if err != nil {
			return err
		}
		require.Equal(t, "after", description)
		skill, err := client.Skill.Create().
			SetSkillID("github.com/skillsgo/pgxent/-/example").
			SetRepositoryID(repo.ID).
			SetName("example").
			SetDescription("adapter test").
			SetSourceHost("github.com").
			SetRepository("skillsgo/pgxent").
			SetSkillPath("example").
			SetLatestVersion("v1.0.0").
			SetVerified(true).
			Save(ctx)
		if err != nil {
			return err
		}
		owner, err := skill.QuerySourceRepository().Only(ctx)
		if err != nil {
			return err
		}
		require.Equal(t, repo.ID, owner.ID)
		return nil
	}))

	var committed int
	require.NoError(t, metadata.PostgresPool().QueryRow(ctx,
		`SELECT count(*) FROM repositories WHERE repository_id = $1`,
		"github.com/skillsgo/pgxent",
	).Scan(&committed))
	require.Equal(t, 1, committed)

	rollbackCause := errors.New("force rollback")
	err = metadata.WithPostgresTx(ctx, func(client *catalogent.Client, _ pgx.Tx) error {
		_, createErr := client.Repository.Create().
			SetSourceHost("github.com").
			SetRepositoryPath("skillsgo/rollback").
			SetRepositoryID("github.com/skillsgo/rollback").
			Save(ctx)
		if createErr != nil {
			return createErr
		}
		return rollbackCause
	})
	require.ErrorIs(t, err, rollbackCause)
	var rolledBack int
	require.NoError(t, metadata.PostgresPool().QueryRow(ctx,
		`SELECT count(*) FROM repositories WHERE repository_id = $1`,
		"github.com/skillsgo/rollback",
	).Scan(&rolledBack))
	require.Zero(t, rolledBack)

	executed := make(chan string, 2)
	tasks, err := taskqueue.NewRiver(ctx, metadata.PostgresPool(), 2)
	require.NoError(t, err)
	require.NoError(t, taskqueue.Register(tasks, func(handlerCtx context.Context, args verifyRepositoryArgs) error {
		var count int
		if err := metadata.PostgresPool().QueryRow(handlerCtx,
			`SELECT count(*) FROM repositories WHERE repository_id = $1`, args.RepositoryID,
		).Scan(&count); err != nil {
			return err
		}
		if count != 1 {
			return errors.New("task observed missing transactional repository")
		}
		executed <- args.RepositoryID
		return nil
	}))
	require.NoError(t, tasks.Start(ctx))
	t.Cleanup(func() {
		stopCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		require.NoError(t, tasks.Stop(stopCtx))
	})

	const committedTaskRepository = "github.com/skillsgo/atomic-task"
	require.NoError(t, metadata.WithPostgresTx(ctx, func(client *catalogent.Client, tx pgx.Tx) error {
		_, err := client.Repository.Create().
			SetSourceHost("github.com").
			SetRepositoryPath("skillsgo/atomic-task").
			SetRepositoryID(committedTaskRepository).
			Save(ctx)
		if err != nil {
			return err
		}
		if err := tasks.EnqueueTx(ctx, tx, verifyRepositoryArgs{RepositoryID: committedTaskRepository}, taskqueue.InsertOptions{}); err != nil {
			return err
		}
		select {
		case <-executed:
			return errors.New("River executed a job before its transaction committed")
		case <-time.After(250 * time.Millisecond):
			return nil
		}
	}))
	select {
	case repositoryID := <-executed:
		require.Equal(t, committedTaskRepository, repositoryID)
	case <-time.After(10 * time.Second):
		t.Fatal("River did not execute the transactionally committed task")
	}

	const rolledBackTaskRepository = "github.com/skillsgo/rolled-back-task"
	err = metadata.WithPostgresTx(ctx, func(client *catalogent.Client, tx pgx.Tx) error {
		_, err := client.Repository.Create().
			SetSourceHost("github.com").
			SetRepositoryPath("skillsgo/rolled-back-task").
			SetRepositoryID(rolledBackTaskRepository).
			Save(ctx)
		if err != nil {
			return err
		}
		if err := tasks.EnqueueTx(ctx, tx, verifyRepositoryArgs{RepositoryID: rolledBackTaskRepository}, taskqueue.InsertOptions{}); err != nil {
			return err
		}
		return rollbackCause
	})
	require.ErrorIs(t, err, rollbackCause)
	select {
	case repositoryID := <-executed:
		t.Fatalf("River executed rolled-back task for %s", repositoryID)
	case <-time.After(time.Second):
	}
}
