/*
 * [INPUT]: Depends on Go module path/version escaping rules and encoded Hub artifact coordinates.
 * [OUTPUT]: Provides canonical module-compatible path and version decoding without a copied cmd/go decoder.
 * [POS]: Serves as the shared decoding boundary for Hub and external-storage protocol paths.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package paths

import (
	"fmt"

	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"golang.org/x/mod/module"
)

// DecodePath returns the module path of the given safe encoding.
// It fails if the encoding is invalid or encodes an invalid path.
func DecodePath(encoding string) (path string, err error) {
	const op errors.Op = "paths.DecodePath"
	path, err = module.UnescapePath(encoding)
	if err != nil {
		return "", errors.E(op, fmt.Sprintf("invalid module path encoding %q: %v", encoding, err))
	}

	return path, nil
}

func DecodeVersion(encoding string) (string, error) {
	const op errors.Op = "paths.DecodeVersion"
	version, err := module.UnescapeVersion(encoding)
	if err != nil {
		return "", errors.E(op, fmt.Sprintf("invalid module version encoding %q: %v", encoding, err))
	}
	return version, nil
}
