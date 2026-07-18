/*
 * [INPUT]: Depends on the slog-backed Hub logger, output formatters, field handling, and credential redaction.
 * [OUTPUT]: Verifies level filtering, runtime formats, structured fields, and secret-safe log output.
 * [POS]: Serves as the behavioral contract for Hub logging across local and production runtimes.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package log

import (
	"bytes"
	"fmt"
	"log/slog"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
)

type input struct {
	name          string
	cloudProvider string
	format        string
	level         slog.Level
	fields        map[string]any
	logFunc       func(e Entry) time.Time
	output        string
}

var testCases = []input{
	{
		name:          "gcp_debug",
		cloudProvider: "GCP",
		level:         slog.LevelDebug,
		fields:        map[string]any{},
		logFunc: func(e Entry) time.Time {
			t := time.Now()
			e.Infof("info message")
			return t
		},
		output: `{"timestamp":"%v","severity":"INFO","message":"info message"}` + "\n",
	},
	{
		name:          "gcp_error",
		cloudProvider: "GCP",
		level:         slog.LevelDebug,
		fields:        map[string]any{},
		logFunc: func(e Entry) time.Time {
			t := time.Now()
			e.Errorf("err message")
			return t
		},
		output: `{"timestamp":"%v","severity":"ERROR","message":"err message"}` + "\n",
	},
	{
		name:          "gcp_empty",
		cloudProvider: "GCP",
		level:         slog.LevelError,
		fields:        map[string]any{},
		logFunc: func(e Entry) time.Time {
			t := time.Now()
			e.Infof("info message")
			return t
		},
		output: ``,
	},
	{
		name:          "gcp_fields",
		cloudProvider: "GCP",
		level:         slog.LevelDebug,
		fields:        map[string]any{"field1": "value1", "field2": 2},
		logFunc: func(e Entry) time.Time {
			t := time.Now()
			e.Debugf("debug message")
			return t
		},
		output: `{"timestamp":"%v","severity":"DEBUG","message":"debug message","field1":"value1","field2":2}` + "\n",
	},
	{
		name:          "gcp_logs",
		cloudProvider: "GCP",
		level:         slog.LevelDebug,
		fields:        map[string]any{},
		logFunc: func(e Entry) time.Time {
			t := time.Now()
			e.Warnf("warn message")
			return t
		},
		output: `{"timestamp":"%v","severity":"WARNING","message":"warn message"}` + "\n",
	},
	{
		name:          "default plain",
		format:        "plain",
		cloudProvider: "none",
		level:         slog.LevelDebug,
		fields:        map[string]any{"xyz": "abc", "abc": "xyz"},
		logFunc: func(e Entry) time.Time {
			t := time.Now()
			e.Warnf("warn message")
			return t
		},
		output: `WARN[%v]: warn message` + "\t" + `abc=xyz xyz=abc` + " \n",
	},
	{
		name:          "default",
		cloudProvider: "none",
		level:         slog.LevelDebug,
		fields:        map[string]any{"xyz": "abc", "abc": "xyz"},
		logFunc: func(e Entry) time.Time {
			t := time.Now()
			e.Warnf("warn message")
			return t
		},
		output: `WARN[%v]: warn message` + "\t" + `abc=xyz xyz=abc` + " \n",
	},
	{
		name:          "default json",
		format:        "json",
		cloudProvider: "none",
		level:         slog.LevelDebug,
		fields:        map[string]any{"xyz": "abc", "abc": "xyz"},
		logFunc: func(e Entry) time.Time {
			t := time.Now()
			e.Warnf("warn message")
			return t
		},
		output: `{"time":"%v","level":"WARN","msg":"warn message","abc":"xyz","xyz":"abc"}` + "\n",
	},
}

func TestCloudLogger(t *testing.T) {
	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			var buf bytes.Buffer
			lggr := NewWithOutput(&buf, tc.cloudProvider, tc.level, tc.format)
			e := lggr.WithFields(tc.fields)
			entryTime := tc.logFunc(e)
			out := buf.String()
			expected := tc.output
			if strings.Contains(expected, "%v") {
				if tc.format == "plain" || (tc.format == "" && (tc.cloudProvider == "none" || tc.cloudProvider == "")) {
					expected = fmt.Sprintf(expected, entryTime.Format(time.Kitchen))
				} else {
					expected = fmt.Sprintf(expected, entryTime.Format(time.RFC3339))
				}
			}

			require.Equal(t, expected, out, "expected the logged entry to match the testCase output")
		})
	}
}

func TestNoOpLogger(t *testing.T) {
	l := NoOpLogger()
	require.NotPanics(t, func() { l.Infof("test") })
}

func TestLoggerRedactsCredentialsInMessagesAndFields(t *testing.T) {
	var buf bytes.Buffer
	logger := NewWithOutput(&buf, "", slog.LevelDebug, "json")
	logger.WithFields(map[string]any{
		"authorization":  "Bearer field-secret",
		"repository_url": "https://user:password@example.com/org/repo",
	}).Errorf("request failed token=ghp_abcdefghijklmnopqrstuvwxyz password=hunter2 Bearer raw-secret")

	output := buf.String()
	require.NotContains(t, output, "field-secret")
	require.NotContains(t, output, "password@example.com")
	require.NotContains(t, output, "ghp_abcdefghijklmnopqrstuvwxyz")
	require.NotContains(t, output, "hunter2")
	require.NotContains(t, output, "raw-secret")
	require.Contains(t, output, redacted)
}
