/*
 * [INPUT]: Depends on environment and TOML decoding for task worker, notification fallback polling, Repository materializer capacity, and Package latest-sync cadence.
 * [OUTPUT]: Provides validated Hub task worker, River fallback polling, Repository materializer budgets, and automatic Package latest-sync cadence.
 * [POS]: Serves as configuration for River and its synchronous local substitute.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package config

// TaskQueueConfig controls background task execution capacity.
type TaskQueueConfig struct {
	MaxWorkers                       int `envconfig:"SKILLSGO_HUB_TASK_QUEUE_MAX_WORKERS" validate:"min=3"`
	FetchPollSeconds                 int `envconfig:"SKILLSGO_HUB_TASK_QUEUE_FETCH_POLL_SECONDS" validate:"min=1"`
	RepositoryMaterializerCapacity   int `envconfig:"SKILLSGO_HUB_REPOSITORY_MATERIALIZER_CAPACITY" validate:"min=1"`
	PackageLatestSyncIntervalSeconds int `envconfig:"SKILLSGO_HUB_PACKAGE_LATEST_SYNC_INTERVAL_SECONDS" validate:"min=0"`
}
