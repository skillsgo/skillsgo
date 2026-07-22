/*
 * [INPUT]: Depends on source-authored SKILL.md bytes and the Agent Skills frontmatter schema.
 * [OUTPUT]: Extracts and validates source frontmatter while preserving the complete SKILL.md in the artifact ZIP.
 * [POS]: Serves as source candidate validation inside Repository discovery, not as a Hub transport artifact.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skill

import protocolmanifest "github.com/skillsgo/skillsgo/protocol/skillmanifest"

func extractManifest(skillFile []byte) (manifest, body []byte, err error) {
	return protocolmanifest.Split(skillFile)
}

func validateManifest(manifest, body []byte) error {
	_, err := protocolmanifest.Validate(manifest, body)
	return err
}
