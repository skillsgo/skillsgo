/*
 * [INPUT]: Depends on an operator, CLI, or HTTP-supplied language/script/region tag.
 * [OUTPUT]: Provides canonical BCP 47 casing and separators for presentation locale identity.
 * [POS]: Serves as the shared locale-format contract for CLI requests and Hub lookups.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package locale

import (
	"fmt"
	"strings"
)

func Canonical(value string) (string, error) {
	value = strings.ReplaceAll(strings.TrimSpace(value), "_", "-")
	parts := strings.Split(value, "-")
	if value == "" || len(parts) > 3 || len(parts[0]) < 2 || len(parts[0]) > 8 {
		return "", fmt.Errorf("invalid presentation locale %q", value)
	}
	parts[0] = strings.ToLower(parts[0])
	for index := 1; index < len(parts); index++ {
		part := parts[index]
		switch len(part) {
		case 4:
			parts[index] = strings.ToUpper(part[:1]) + strings.ToLower(part[1:])
		case 2, 3:
			parts[index] = strings.ToUpper(part)
		default:
			return "", fmt.Errorf("invalid presentation locale %q", value)
		}
	}
	return strings.Join(parts, "-"), nil
}
