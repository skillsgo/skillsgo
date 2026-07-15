/*
 * [INPUT]: Uses wrapped network, deadline, Registry HTTP, and ordinary validation errors.
 * [OUTPUT]: Specifies stable offline/temporary/default CLI process exit classification.
 * [POS]: Serves as executable compatibility coverage for App-visible failure kinds.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"context"
	"fmt"
	"net/url"
	"syscall"
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/registry"
	"github.com/stretchr/testify/require"
)

func TestExitCodeClassifiesRegistryAvailabilityWithoutParsingMessages(t *testing.T) {
	require.Equal(t, 0, ExitCode(nil))
	require.Equal(t, ExitTemporary, ExitCode(fmt.Errorf("wrapped: %w", context.DeadlineExceeded)))
	require.Equal(t, ExitUnavailable, ExitCode(fmt.Errorf("wrapped: %w", &url.Error{Op: "Get", URL: "https://registry.example", Err: syscall.ECONNREFUSED})))
	require.Equal(t, ExitUnavailable, ExitCode(&registry.HTTPError{StatusCode: 503}))
	require.Equal(t, ExitTemporary, ExitCode(&registry.HTTPError{StatusCode: 429}))
	require.Equal(t, ExitFailure, ExitCode(fmt.Errorf("invalid target")))
}
