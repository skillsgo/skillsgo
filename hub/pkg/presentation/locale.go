/*
 * [INPUT]: Depends on an operator, CLI, or HTTP-supplied language/script/region tag.
 * [OUTPUT]: Provides canonical BCP 47 casing and separators for presentation locale identity.
 * [POS]: Serves as the shared Hub normalization boundary for translation configuration and API lookup.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package presentation

import protocollocale "github.com/skillsgo/skillsgo/protocol/locale"

func CanonicalLocale(value string) (string, error) {
	return protocollocale.Canonical(value)
}
