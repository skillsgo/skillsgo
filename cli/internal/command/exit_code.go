/*
 * [INPUT]: Depends on wrapped network, context timeout, and Hub HTTP errors returned by command execution.
 * [OUTPUT]: Provides stable process exit codes for unavailable Hub and temporary timeout failures.
 * [POS]: Serves as the machine-readable failure classification seam consumed by the desktop App without parsing localized stderr.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"context"
	"errors"
	"net"
	"net/http"

	"github.com/skillsgo/skillsgo/cli/internal/hub"
)

const (
	ExitFailure     = 1
	ExitUnavailable = 69
	ExitTemporary   = 75
)

func ExitCode(err error) int {
	if err == nil {
		return 0
	}
	if errors.Is(err, context.DeadlineExceeded) {
		return ExitTemporary
	}
	var networkError net.Error
	if errors.As(err, &networkError) {
		if networkError.Timeout() {
			return ExitTemporary
		}
		return ExitUnavailable
	}
	var responseError *hub.HTTPError
	if errors.As(err, &responseError) {
		switch responseError.StatusCode {
		case http.StatusRequestTimeout, http.StatusTooManyRequests, http.StatusGatewayTimeout:
			return ExitTemporary
		case http.StatusBadGateway, http.StatusServiceUnavailable:
			return ExitUnavailable
		}
	}
	return ExitFailure
}
