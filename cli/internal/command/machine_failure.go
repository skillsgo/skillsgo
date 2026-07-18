/*
 * [INPUT]: Depends on recognized CLI output arguments plus wrapped context, network, and Hub HTTP failures.
 * [OUTPUT]: Provides the versioned machine failure document and minimal stable failure classification used by command.Execute.
 * [POS]: Serves as the CLI process-contract translator between internal Go errors and public JSON or NDJSON failure output.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"strings"

	"github.com/skillsgo/skillsgo/cli/internal/hub"
)

const machineFailureSchemaVersion = 1

type machineFailureDocument struct {
	SchemaVersion int            `json:"schemaVersion"`
	Phase         string         `json:"phase"`
	Error         machineFailure `json:"error"`
}

type machineFailure struct {
	Code       string         `json:"code"`
	Retryable  bool           `json:"retryable"`
	Details    map[string]any `json:"details,omitempty"`
	RequestID  string         `json:"requestId,omitempty"`
	Diagnostic string         `json:"diagnostic,omitempty"`
}

type machineOutputWriter struct {
	io.Writer
	output []byte
}

func (w *machineOutputWriter) Write(data []byte) (int, error) {
	count, err := w.Writer.Write(data)
	w.output = append(w.output, data[:count]...)
	return count, err
}

func (w *machineOutputWriter) HasCompletedResult(mode string) bool {
	trimmed := strings.TrimSpace(string(w.output))
	if trimmed == "" {
		return false
	}
	if mode == "json" {
		return true
	}
	lines := strings.Split(trimmed, "\n")
	var document struct {
		Phase string `json:"phase"`
	}
	if json.Unmarshal([]byte(lines[len(lines)-1]), &document) != nil {
		return false
	}
	return document.Phase == "error" ||
		document.Phase == "execution" ||
		strings.HasSuffix(document.Phase, "-execution")
}

func machineOutputMode(args []string) string {
	for index, argument := range args {
		if strings.HasPrefix(argument, "--output=") {
			value := strings.TrimPrefix(argument, "--output=")
			if value == "json" || value == "ndjson" {
				return value
			}
		}
		if argument == "--output" && index+1 < len(args) {
			value := args[index+1]
			if value == "json" || value == "ndjson" {
				return value
			}
		}
	}
	return ""
}

func writeMachineFailure(writer io.Writer, err error) error {
	return json.NewEncoder(writer).Encode(machineFailureDocument{
		SchemaVersion: machineFailureSchemaVersion,
		Phase:         "error",
		Error:         classifyMachineFailure(err),
	})
}

func classifyMachineFailure(err error) machineFailure {
	failure := machineFailure{Code: "internal.unexpected", Diagnostic: err.Error()}
	if errors.Is(err, context.DeadlineExceeded) {
		failure.Code = "hub.timeout"
		failure.Retryable = true
		return failure
	}
	var networkError net.Error
	if errors.As(err, &networkError) {
		failure.Code = "hub.unavailable"
		failure.Retryable = true
		if networkError.Timeout() {
			failure.Code = "hub.timeout"
		}
		return failure
	}
	var responseError *hub.HTTPError
	if errors.As(err, &responseError) {
		failure.Diagnostic = fmt.Sprintf("Hub returned HTTP %d", responseError.StatusCode)
		failure.RequestID = responseError.RequestID
		failure.Retryable = true
		switch responseError.StatusCode {
		case http.StatusRequestTimeout, http.StatusGatewayTimeout:
			failure.Code = "hub.timeout"
		case http.StatusTooManyRequests:
			failure.Code = "hub.rate_limited"
		default:
			if responseError.StatusCode >= http.StatusInternalServerError {
				failure.Code = "hub.unavailable"
			} else {
				failure.Code = "input.invalid"
				failure.Retryable = false
			}
		}
		return failure
	}
	var protocolError *hub.ProtocolError
	if errors.As(err, &protocolError) {
		if protocolError.Incompatible {
			failure.Code = "protocol.incompatible"
		} else {
			failure.Code = "protocol.invalid_response"
			failure.Retryable = true
		}
		return failure
	}
	return failure
}
