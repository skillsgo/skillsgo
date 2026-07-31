/*
 * [INPUT]: Depends on Hub configuration, storage selection, foreground/background Catalog connections, and the synchronous or River task runtime.
 * [OUTPUT]: Provides composition-root runtime resources with creation-time failure rollback and reverse-order idempotent cleanup.
 * [POS]: Serves as the infrastructure ownership boundary beneath App, keeping resource lifetime explicit without a dependency-injection framework.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"context"
	"fmt"
	"net/http"
	"sync"
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	"github.com/skillsgo/skillsgo/hub/pkg/taskqueue"
)

type runtimeResources struct {
	store              storage.Backend
	metadata           *catalog.Catalog
	backgroundMetadata *catalog.Catalog
	tasks              *taskqueue.Runtime
	workerCtx          context.Context

	cleanupOnce sync.Once
	cleanups    []func()
}

func openRuntimeResources(logger *log.Logger, conf *config.Config, client *http.Client) (_ *runtimeResources, err error) {
	resources := &runtimeResources{}
	defer func() {
		if err != nil {
			resources.Close()
		}
	}()

	resources.store, err = GetStorage(conf.StorageType, conf.Storage, conf.TimeoutDuration(), client)
	if err != nil {
		return nil, fmt.Errorf("getting storage configuration: %w", err)
	}
	if conf.Database == nil {
		return nil, fmt.Errorf("database configuration is required")
	}
	resources.metadata, err = catalog.Open(context.Background(), *conf.Database)
	if err != nil {
		return nil, fmt.Errorf("opening metadata catalog: %w", err)
	}
	resources.addCleanup(func() { _ = resources.metadata.Close() })

	resources.backgroundMetadata, err = catalog.Connect(context.Background(), conf.Database.Background())
	if err != nil {
		return nil, fmt.Errorf("opening background metadata catalog: %w", err)
	}
	resources.addCleanup(func() { _ = resources.backgroundMetadata.Close() })

	var resourcesCancel context.CancelFunc
	resources.workerCtx, resourcesCancel = context.WithCancel(context.Background())
	resources.addCleanup(resourcesCancel)
	resources.tasks = taskqueue.NewSynchronous()
	if pool := resources.backgroundMetadata.PostgresPool(); pool != nil {
		resources.tasks, err = taskqueue.NewRiver(resources.workerCtx, pool, conf.TaskQueue.MaxWorkers, taskqueue.RiverOptions{
			FetchPollInterval:    time.Duration(conf.TaskQueue.FetchPollSeconds) * time.Second,
			JobTimeout:           translationJobTimeout,
			RescueStuckJobsAfter: 15 * time.Minute,
			QueueWorkers:         taskqueue.BalancedQueueWorkers(conf.TaskQueue.MaxWorkers),
		})
		if err != nil {
			return nil, fmt.Errorf("creating task runtime: %w", err)
		}
	}

	resources.addCleanup(func() {
		stopCtx, cancelStop := context.WithTimeout(context.Background(), time.Duration(conf.ShutdownTimeout)*time.Second)
		defer cancelStop()
		if stopErr := resources.tasks.Stop(stopCtx); stopErr != nil {
			logger.Infof("task runtime shutdown incomplete: %v", stopErr)
		}
	})
	return resources, nil
}

func (r *runtimeResources) addCleanup(cleanup func()) {
	r.cleanups = append(r.cleanups, cleanup)
}

func (r *runtimeResources) Close() {
	r.cleanupOnce.Do(func() {
		for index := len(r.cleanups) - 1; index >= 0; index-- {
			r.cleanups[index]()
		}
	})
}
