/*
 * [INPUT]: Depends on JSON object inputs, a caller-owned diagnostic label, and optional domain validation.
 * [OUTPUT]: Provides generic strict multi-object decoding that rejects unknown fields and trailing JSON values.
 * [POS]: Serves as the shared machine-input decoding primitive used by CLI Plan boundaries.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package strictjson

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"strings"
)

// DecodeMany decodes exactly one strict JSON object from each value and runs
// caller-owned domain validation without coupling Plan packages together.
func DecodeMany[T any](values []string, label string, validate func(T) error) ([]T, error) {
	decoded := make([]T, 0, len(values))
	for index, value := range values {
		decoder := json.NewDecoder(strings.NewReader(value))
		decoder.DisallowUnknownFields()
		var item T
		if err := decoder.Decode(&item); err != nil {
			return nil, fmt.Errorf("%s %d: %w", label, index+1, err)
		}
		if err := decoder.Decode(&struct{}{}); !errors.Is(err, io.EOF) {
			return nil, fmt.Errorf("%s %d: expected one JSON object", label, index+1)
		}
		if validate != nil {
			if err := validate(item); err != nil {
				return nil, fmt.Errorf("%s %d: %w", label, index+1, err)
			}
		}
		decoded = append(decoded, item)
	}
	return decoded, nil
}
