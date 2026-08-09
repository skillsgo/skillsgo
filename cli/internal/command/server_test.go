/*
 * [INPUT]: Uses command.Serve plus NDJSON request and response documents over in-memory streams.
 * [OUTPUT]: Specifies reusable CLI Server execution, stdin forwarding, command-failure isolation, and malformed-request recovery.
 * [POS]: Serves as the long-lived App-to-CLI session contract suite at the command boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
)

func TestServeExecutesMultipleRequestsInOneSession(t *testing.T) {
	input := strings.NewReader(strings.Join([]string{
		`{"schemaVersion":1,"id":"first","arguments":["version","--output","json"]}`,
		`{"schemaVersion":1,"id":"second","arguments":["version","--output","json"]}`,
	}, "\n") + "\n")
	var output bytes.Buffer

	require.NoError(t, Serve(input, &output))

	responses := decodeServerResponses(t, output.String())
	require.Len(t, responses, 2)
	byID := indexServerResponses(responses)
	require.Zero(t, byID["first"].ExitCode)
	require.Contains(t, byID["first"].Stdout, `"product":"skillsgo"`)
	require.Zero(t, byID["second"].ExitCode)
}

func TestServeForwardsStdinAndSurvivesCommandFailure(t *testing.T) {
	input := strings.NewReader(strings.Join([]string{
		`{"schemaVersion":1,"id":"failed","arguments":["adopt","--output","json"],"stdin":"not-json"}`,
		`{"schemaVersion":1,"id":"healthy","arguments":["version","--output","json"]}`,
	}, "\n") + "\n")
	var output bytes.Buffer

	require.NoError(t, Serve(input, &output))

	responses := decodeServerResponses(t, output.String())
	require.Len(t, responses, 2)
	byID := indexServerResponses(responses)
	require.NotZero(t, byID["failed"].ExitCode)
	require.NotEmpty(t, byID["failed"].Stderr)
	require.Zero(t, byID["healthy"].ExitCode)
}

func TestServeRejectsMalformedRequestWithoutStopping(t *testing.T) {
	input := strings.NewReader("not-json\n" +
		`{"schemaVersion":1,"id":"healthy","arguments":["version","--output","json"]}` + "\n")
	var output bytes.Buffer

	require.NoError(t, Serve(input, &output))

	responses := decodeServerResponses(t, output.String())
	require.Len(t, responses, 2)
	byID := indexServerResponses(responses)
	require.Equal(t, serverProtocolErrorExitCode, byID[""].ExitCode)
	require.Contains(t, byID[""].Stderr, "invalid CLI Server request")
	require.Zero(t, byID["healthy"].ExitCode)
}

func TestServeRunsReadRequestsConcurrently(t *testing.T) {
	input := strings.NewReader(strings.Join([]string{
		`{"schemaVersion":1,"id":"first","arguments":["show","one"]}`,
		`{"schemaVersion":1,"id":"second","arguments":["find","two"]}`,
	}, "\n") + "\n")
	started := make(chan struct{}, 2)
	release := make(chan struct{})
	var active atomic.Int32
	var maximum atomic.Int32
	execute := func(_ []string, _ io.Reader, _, _ io.Writer) error {
		current := active.Add(1)
		for {
			previous := maximum.Load()
			if current <= previous || maximum.CompareAndSwap(previous, current) {
				break
			}
		}
		started <- struct{}{}
		<-release
		active.Add(-1)
		return nil
	}
	var output bytes.Buffer
	done := make(chan error, 1)
	go func() { done <- serveWithExecutor(input, &output, execute) }()
	<-started
	select {
	case <-started:
	case <-time.After(time.Second):
		t.Fatal("second read request did not start concurrently")
	}
	close(release)
	require.NoError(t, <-done)
	require.Equal(t, int32(2), maximum.Load())
}

func TestServeBoundsConcurrentReads(t *testing.T) {
	lines := make([]string, 0, serverMaxConcurrentReads+1)
	for index := 0; index <= serverMaxConcurrentReads; index++ {
		lines = append(lines, fmt.Sprintf(
			`{"schemaVersion":1,"id":"read-%d","arguments":["show","skill-%d"]}`,
			index, index,
		))
	}
	started := make(chan struct{}, serverMaxConcurrentReads+1)
	release := make(chan struct{})
	execute := func(_ []string, _ io.Reader, _, _ io.Writer) error {
		started <- struct{}{}
		<-release
		return nil
	}
	var output bytes.Buffer
	done := make(chan error, 1)
	go func() {
		done <- serveWithExecutor(strings.NewReader(strings.Join(lines, "\n")+"\n"), &output, execute)
	}()
	for range serverMaxConcurrentReads {
		<-started
	}
	select {
	case <-started:
		t.Fatal("read concurrency exceeded the configured bound")
	case <-time.After(30 * time.Millisecond):
	}
	close(release)
	require.NoError(t, <-done)
}

func TestServeStopsBeforeQueuedMutationWhenResponseChannelFails(t *testing.T) {
	input := strings.NewReader(strings.Join([]string{
		`{"schemaVersion":1,"id":"read","arguments":["show","skill"],"streamStdout":true}`,
		`{"schemaVersion":1,"id":"write","arguments":["install"]}`,
	}, "\n") + "\n")
	var mutations atomic.Int32
	execute := func(arguments []string, _ io.Reader, stdout, _ io.Writer) error {
		if arguments[0] == "install" {
			mutations.Add(1)
			return nil
		}
		_, err := io.WriteString(stdout, "progress\n")
		return err
	}
	err := serveWithExecutor(input, failingServerWriter{}, execute)
	require.ErrorContains(t, err, "encode CLI Server response")
	require.Zero(t, mutations.Load())
}

type failingServerWriter struct{}

func (failingServerWriter) Write([]byte) (int, error) {
	return 0, errors.New("response channel closed")
}

func TestServerSchedulerGivesWaitingWriterPriority(t *testing.T) {
	scheduler := newServerScheduler()
	firstReadStarted := make(chan struct{})
	releaseFirstRead := make(chan struct{})
	writerFinished := make(chan struct{})
	secondReadStarted := make(chan struct{})
	go scheduler.run([]string{"list"}, func() {
		close(firstReadStarted)
		<-releaseFirstRead
	})
	<-firstReadStarted
	go scheduler.run([]string{"install"}, func() { close(writerFinished) })
	time.Sleep(10 * time.Millisecond)
	go scheduler.run([]string{"show", "skill"}, func() { close(secondReadStarted) })
	select {
	case <-secondReadStarted:
		t.Fatal("new read bypassed a waiting writer")
	case <-time.After(30 * time.Millisecond):
	}
	close(releaseFirstRead)
	select {
	case <-writerFinished:
	case <-time.After(time.Second):
		t.Fatal("writer did not acquire exclusive access")
	}
	select {
	case <-secondReadStarted:
	case <-time.After(time.Second):
		t.Fatal("read did not resume after writer")
	}
}

func TestServerSchedulerDoesNotMixRequestLanguages(t *testing.T) {
	scheduler := newServerScheduler()
	zhStarted := make(chan struct{})
	releaseZH := make(chan struct{})
	enStarted := make(chan struct{})
	go scheduler.run([]string{"--lang", "zh", "find", "one"}, func() {
		close(zhStarted)
		<-releaseZH
	})
	<-zhStarted
	go scheduler.run([]string{"--lang=en", "find", "two"}, func() {
		close(enStarted)
	})
	select {
	case <-enStarted:
		t.Fatal("a different request language overlapped the active request")
	case <-time.After(30 * time.Millisecond):
	}
	close(releaseZH)
	select {
	case <-enStarted:
	case <-time.After(time.Second):
		t.Fatal("request did not resume after the language boundary was released")
	}
}

func TestServerRequestAccessClassificationDefaultsToExclusive(t *testing.T) {
	for _, arguments := range [][]string{
		{"list"}, {"--lang", "zh", "show", "skill"}, {"project", "list"}, {"recovery", "list"},
	} {
		require.True(t, serverRequestIsReadOnly(arguments), arguments)
	}
	for _, arguments := range [][]string{
		{"add", "owner/package"}, {"install"}, {"remove"}, {"update"}, {"adopt"},
		{"project", "add"}, {"recovery", "restore"}, {"unknown"}, nil,
	} {
		require.False(t, serverRequestIsReadOnly(arguments), arguments)
	}
}

func TestServeStreamsStdoutBeforeTheFinalResult(t *testing.T) {
	input := strings.NewReader(`{"schemaVersion":1,"id":"stream","arguments":["version","--output","json"],"streamStdout":true}` + "\n")
	var output bytes.Buffer

	require.NoError(t, Serve(input, &output))

	lines := strings.Split(strings.TrimSpace(output.String()), "\n")
	require.Len(t, lines, 2)
	var event struct {
		Type string `json:"type"`
		Line string `json:"line"`
	}
	require.NoError(t, json.Unmarshal([]byte(lines[0]), &event))
	require.Equal(t, "stdout", event.Type)
	require.Contains(t, event.Line, `"product":"skillsgo"`)
	var result serverResponse
	require.NoError(t, json.Unmarshal([]byte(lines[1]), &result))
	require.Equal(t, "result", result.Type)
	require.Zero(t, result.ExitCode)
}

func decodeServerResponses(t *testing.T, value string) []serverResponse {
	t.Helper()
	lines := strings.Split(strings.TrimSpace(value), "\n")
	responses := make([]serverResponse, 0, len(lines))
	for _, line := range lines {
		var response serverResponse
		require.NoError(t, json.Unmarshal([]byte(line), &response))
		responses = append(responses, response)
	}
	return responses
}

func indexServerResponses(responses []serverResponse) map[string]serverResponse {
	result := make(map[string]serverResponse, len(responses))
	for _, response := range responses {
		result[response.ID] = response
	}
	return result
}
