/*
 * [INPUT]: Depends on the config package imports and contracts declared in this file.
 * [OUTPUT]: Provides the config package behavior implemented by timeout.go.
 * [POS]: Serves as maintained source in the config package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package config

import "time"

// TimeoutConf is a common struct for anything with a timeout.
type TimeoutConf struct {
	Timeout int `envconfig:"SKILLSGO_HUB_TIMEOUT" validate:"required"`
}

// TimeoutDuration returns the timeout as time.duration.
func (t *TimeoutConf) TimeoutDuration() time.Duration {
	return GetTimeoutDuration(t.Timeout)
}

// GetTimeoutDuration returns the timeout as time.duration.
func GetTimeoutDuration(timeout int) time.Duration {
	return time.Second * time.Duration(timeout)
}

// StashTimeoutDuration returns the stash timeout as time.Duration.
func (c *Config) StashTimeoutDuration() time.Duration {
	return GetTimeoutDuration(c.StashTimeout)
}
