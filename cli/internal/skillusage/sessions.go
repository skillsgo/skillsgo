/*
 * [INPUT]: Depends on normalized Agent Session, Skill, and observation-day identities.
 * [OUTPUT]: Provides latest-observation Session deduplication shared by transcript-backed usage adapters.
 * [POS]: Serves as the shared Session aggregation primitive below Agent-specific evidence parsing.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skillusage

func observeSessionSkill(sessions map[string]map[string]string, sessionID, name, day string) {
	if sessionID == "" || name == "" || day == "" {
		return
	}
	observed := sessions[sessionID]
	if observed == nil {
		observed = map[string]string{}
		sessions[sessionID] = observed
	}
	if previous := observed[name]; previous == "" || day > previous {
		observed[name] = day
	}
}
