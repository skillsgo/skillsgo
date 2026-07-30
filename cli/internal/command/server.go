/*
 * [INPUT]: Depends on versioned NDJSON requests, command.ExecuteWithInput, and stable command exit-code classification.
 * [OUTPUT]: Provides a sequential long-lived CLI Server that returns one isolated machine response per request and remains available after request failures.
 * [POS]: Serves as the reusable App process boundary above ordinary CLI command execution.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"strings"
)

const (
	serverSchemaVersion         = 1
	serverProtocolErrorExitCode = 64
	serverMaxRequestBytes       = 16 * 1024 * 1024
)

type serverRequest struct {
	SchemaVersion int      `json:"schemaVersion"`
	ID            string   `json:"id"`
	Arguments     []string `json:"arguments"`
	Stdin         string   `json:"stdin,omitempty"`
	StreamStdout  bool     `json:"streamStdout,omitempty"`
}

type serverResponse struct {
	SchemaVersion int    `json:"schemaVersion"`
	ID            string `json:"id,omitempty"`
	Type          string `json:"type"`
	ExitCode      int    `json:"exitCode"`
	Stdout        string `json:"stdout"`
	Stderr        string `json:"stderr"`
}

func Serve(input io.Reader, output io.Writer) error {
	scanner := bufio.NewScanner(input)
	scanner.Buffer(make([]byte, 64*1024), serverMaxRequestBytes)
	encoder := json.NewEncoder(output)
	for scanner.Scan() {
		response := executeServerRequest(scanner.Bytes(), encoder)
		if err := encoder.Encode(response); err != nil {
			return fmt.Errorf("encode CLI Server response: %w", err)
		}
	}
	if err := scanner.Err(); err != nil {
		return fmt.Errorf("read CLI Server request: %w", err)
	}
	return nil
}

func executeServerRequest(document []byte, encoder *json.Encoder) serverResponse {
	response := serverResponse{SchemaVersion: serverSchemaVersion, Type: "result"}
	var request serverRequest
	if err := json.Unmarshal(document, &request); err != nil {
		response.ExitCode = serverProtocolErrorExitCode
		response.Stderr = "invalid CLI Server request: malformed JSON"
		return response
	}
	response.ID = request.ID
	if request.SchemaVersion != serverSchemaVersion || strings.TrimSpace(request.ID) == "" || len(request.Arguments) == 0 {
		response.ExitCode = serverProtocolErrorExitCode
		response.Stderr = "invalid CLI Server request: unsupported or incomplete document"
		return response
	}
	var stderr bytes.Buffer
	stdout := &serverStdoutWriter{id: request.ID, stream: request.StreamStdout, encoder: encoder}
	err := ExecuteWithInput(request.Arguments, strings.NewReader(request.Stdin), stdout, &stderr)
	if flushErr := stdout.Flush(); err == nil && flushErr != nil {
		err = flushErr
	}
	if err != nil {
		if stderr.Len() > 0 && !strings.HasSuffix(stderr.String(), "\n") {
			stderr.WriteByte('\n')
		}
		fmt.Fprintln(&stderr, err)
		response.ExitCode = ExitCode(err)
	}
	response.Stdout = stdout.String()
	response.Stderr = stderr.String()
	return response
}

type serverStdoutWriter struct {
	id      string
	stream  bool
	encoder *json.Encoder
	all     bytes.Buffer
	pending bytes.Buffer
	err     error
}

func (w *serverStdoutWriter) Write(value []byte) (int, error) {
	w.all.Write(value)
	if !w.stream || w.err != nil {
		return len(value), w.err
	}
	w.pending.Write(value)
	for {
		line, readErr := w.pending.ReadString('\n')
		if readErr != nil {
			w.pending.WriteString(line)
			break
		}
		w.emit(strings.TrimSuffix(line, "\n"))
	}
	return len(value), w.err
}

func (w *serverStdoutWriter) Flush() error {
	if w.stream && w.pending.Len() > 0 {
		w.emit(w.pending.String())
		w.pending.Reset()
	}
	return w.err
}

func (w *serverStdoutWriter) String() string { return w.all.String() }

func (w *serverStdoutWriter) emit(line string) {
	if w.err != nil {
		return
	}
	w.err = w.encoder.Encode(struct {
		SchemaVersion int    `json:"schemaVersion"`
		ID            string `json:"id"`
		Type          string `json:"type"`
		Line          string `json:"line"`
	}{serverSchemaVersion, w.id, "stdout", line})
}
