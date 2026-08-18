/*
 * [INPUT]: Depends on versioned NDJSON requests, command.ExecuteWithInput, stable command exit-code classification, and process-local analytics invalidations.
 * [OUTPUT]: Provides a writer-preferring long-lived CLI Server with bounded concurrent reads, exclusive mutations, serialized response frames, isolated machine responses, and unsolicited versioned analytics invalidations.
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
	"sync"

	"github.com/skillsgo/skillsgo/cli/internal/skillusage"
)

const (
	serverSchemaVersion         = 1
	serverProtocolErrorExitCode = 64
	serverMaxRequestBytes       = 16 * 1024 * 1024
	serverMaxConcurrentReads    = 4
)

type serverExecuteFunc func([]string, io.Reader, io.Writer, io.Writer) error

type serverEncoder struct {
	mu      sync.Mutex
	encoder *json.Encoder
	err     error
	failed  chan struct{}
}

func (e *serverEncoder) Encode(value any) error {
	e.mu.Lock()
	defer e.mu.Unlock()
	if e.err == nil {
		e.err = e.encoder.Encode(value)
		if e.err != nil {
			close(e.failed)
		}
	}
	return e.err
}

func (e *serverEncoder) Failed() <-chan struct{} { return e.failed }

func (e *serverEncoder) Err() error {
	e.mu.Lock()
	defer e.mu.Unlock()
	return e.err
}

type serverScheduler struct {
	access sync.RWMutex
	reads  chan struct{}
	locale sync.RWMutex
	lang   string
}

func newServerScheduler() *serverScheduler {
	return &serverScheduler{
		reads: make(chan struct{}, serverMaxConcurrentReads),
		lang:  serverRequestLanguage(nil),
	}
}

func (s *serverScheduler) run(arguments []string, action func()) {
	release := s.acquire(arguments)
	defer release()
	action()
}

func (s *serverScheduler) acquire(arguments []string) func() {
	language := serverRequestLanguage(arguments)
	s.locale.RLock()
	if s.lang == language {
		return s.acquireAccess(arguments, s.locale.RUnlock)
	}
	s.locale.RUnlock()
	s.locale.Lock()
	s.lang = language
	return s.acquireAccess(arguments, s.locale.Unlock)
}

func (s *serverScheduler) acquireAccess(arguments []string, releaseLocale func()) func() {
	if serverRequestIsReadOnly(arguments) {
		s.reads <- struct{}{}
		s.access.RLock()
		return func() {
			s.access.RUnlock()
			<-s.reads
			releaseLocale()
		}
	}
	s.access.Lock()
	return func() {
		s.access.Unlock()
		releaseLocale()
	}
}

func serverRequestLanguage(arguments []string) string {
	for index, argument := range arguments {
		if strings.HasPrefix(argument, "--lang=") {
			return strings.TrimSpace(strings.TrimPrefix(argument, "--lang="))
		}
		if argument == "--lang" && index+1 < len(arguments) {
			return strings.TrimSpace(arguments[index+1])
		}
	}
	return "__environment_default__"
}

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

type serverAnalyticsInvalidation struct {
	SchemaVersion int    `json:"schemaVersion"`
	Type          string `json:"type"`
	Revision      uint64 `json:"revision"`
}

func Serve(input io.Reader, output io.Writer) error {
	return serveWithExecutor(input, output, ExecuteWithInput)
}

func serveWithExecutor(input io.Reader, output io.Writer, execute serverExecuteFunc) error {
	analyticsEvents, cancelAnalyticsEvents := skillusage.SubscribeAnalyticsInvalidations()
	return serveWithExecutorAndAnalytics(
		input, output, execute, analyticsEvents, cancelAnalyticsEvents,
	)
}

func serveWithExecutorAndAnalytics(
	input io.Reader,
	output io.Writer,
	execute serverExecuteFunc,
	analyticsEvents <-chan skillusage.AnalyticsInvalidation,
	cancelAnalyticsEvents func(),
) error {
	scanner := bufio.NewScanner(input)
	scanner.Buffer(make([]byte, 64*1024), serverMaxRequestBytes)
	encoder := &serverEncoder{encoder: json.NewEncoder(output), failed: make(chan struct{})}
	var notifications sync.WaitGroup
	notifications.Add(1)
	go func() {
		defer notifications.Done()
		for event := range analyticsEvents {
			if encoder.Encode(serverAnalyticsInvalidation{
				SchemaVersion: serverSchemaVersion,
				Type:          "analytics.invalidated",
				Revision:      event.Revision,
			}) != nil {
				return
			}
		}
	}()
	scheduler := newServerScheduler()
	documents := make(chan []byte)
	scanFinished := make(chan error, 1)
	go func() {
		defer close(documents)
		for scanner.Scan() {
			select {
			case documents <- bytes.Clone(scanner.Bytes()):
			case <-encoder.Failed():
				scanFinished <- nil
				return
			}
		}
		scanFinished <- scanner.Err()
	}()
	var requests sync.WaitGroup
	var inputErr error
accepting:
	for {
		var document []byte
		select {
		case <-encoder.Failed():
			break accepting
		case next, ok := <-documents:
			if !ok {
				inputErr = <-scanFinished
				break accepting
			}
			document = next
		}
		var request serverRequest
		_ = json.Unmarshal(document, &request)
		release := scheduler.acquire(request.Arguments)
		if encoder.Err() != nil {
			release()
			break accepting
		}
		requests.Add(1)
		go func() {
			defer requests.Done()
			defer release()
			response := executeServerRequest(document, encoder, execute)
			_ = encoder.Encode(response)
		}()
	}
	requests.Wait()
	cancelAnalyticsEvents()
	notifications.Wait()
	if err := encoder.Err(); err != nil {
		return fmt.Errorf("encode CLI Server response: %w", err)
	}
	if inputErr != nil {
		return fmt.Errorf("read CLI Server request: %w", inputErr)
	}
	return nil
}

func executeServerRequest(document []byte, encoder *serverEncoder, execute serverExecuteFunc) serverResponse {
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
	err := execute(request.Arguments, strings.NewReader(request.Stdin), stdout, &stderr)
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
	encoder *serverEncoder
	all     bytes.Buffer
	pending bytes.Buffer
	err     error
}

func serverRequestIsReadOnly(arguments []string) bool {
	command, child := serverCommandPath(arguments)
	switch command {
	case "version", "agents", "list", "verify", "why", "show", "find", "rankings", "hub", "self-update", "help", "completion":
		return true
	case "project":
		return child == "list"
	case "recovery":
		return child == "list"
	default:
		return false
	}
}

func serverCommandPath(arguments []string) (string, string) {
	values := make([]string, 0, 2)
	for index := 0; index < len(arguments) && len(values) < 2; index++ {
		argument := arguments[index]
		if argument == "--lang" || argument == "--ui" || argument == "--color" {
			index++
			continue
		}
		if strings.HasPrefix(argument, "-") {
			continue
		}
		values = append(values, argument)
	}
	if len(values) == 0 {
		return "", ""
	}
	if len(values) == 1 {
		return values[0], ""
	}
	return values[0], values[1]
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
