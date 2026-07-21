/*
 * [INPUT]: Depends on operator-supplied skills.sh bridge endpoint, shared token, and synchronization timing limits.
 * [OUTPUT]: Provides optional, validated skills.sh synchronization configuration for the Hub worker.
 * [POS]: Serves as the configuration boundary for external skills.sh counter ingestion.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package config

// SkillsSHConfig enables synchronization when URL and Token are both present.
type SkillsSHConfig struct {
	URL            string `envconfig:"SKILLSGO_HUB_SKILLSSH_URL" validate:"omitempty,url"`
	Token          string `envconfig:"SKILLSGO_BRIDGE_TOKEN"`
	Interval       int    `envconfig:"SKILLSGO_HUB_SKILLSSH_INTERVAL" validate:"min=60"`
	LeaseSeconds   int    `envconfig:"SKILLSGO_HUB_SKILLSSH_LEASE_SECONDS" validate:"min=30"`
	PageCount      int    `envconfig:"SKILLSGO_HUB_SKILLSSH_PAGE_COUNT" validate:"min=1,max=10"`
	PerPage        int    `envconfig:"SKILLSGO_HUB_SKILLSSH_PER_PAGE" validate:"min=1,max=500"`
	RequestTimeout int    `envconfig:"SKILLSGO_HUB_SKILLSSH_REQUEST_TIMEOUT" validate:"min=5"`
}

func (c *SkillsSHConfig) Enabled() bool { return c != nil && c.URL != "" && c.Token != "" }
