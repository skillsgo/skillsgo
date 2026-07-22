/*
 * [INPUT]: Depends on environment and TOML decoding for task worker capacity.
 * [OUTPUT]: Provides a validated total Hub task worker budget large enough for source/default/maintenance isolation.
 * [POS]: Serves as configuration for River and its synchronous local substitute.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package config

// TaskQueueConfig controls background task execution capacity.
type TaskQueueConfig struct {
	MaxWorkers int `envconfig:"SKILLSGO_HUB_TASK_QUEUE_MAX_WORKERS" validate:"min=3"`
}
