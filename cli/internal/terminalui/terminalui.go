/*
 * [INPUT]: Depends on terminal file descriptors, environment policy, and caller-provided Human output streams.
 * [OUTPUT]: Provides automatic Interactive/Plain mode selection and the UI interface for static documents and operation events.
 * [POS]: Serves as the Human terminal presentation seam shared by every CLI command.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package terminalui

import (
	"fmt"
	"io"
	"os"
	"strings"

	"golang.org/x/term"
)

type Mode string

const (
	ModeAuto        Mode = "auto"
	ModeInteractive Mode = "interactive"
	ModePlain       Mode = "plain"
)

type ColorMode string

const (
	ColorAuto   ColorMode = "auto"
	ColorAlways ColorMode = "always"
	ColorNever  ColorMode = "never"
)

type Options struct {
	Input       io.Reader
	Output      io.Writer
	Progress    io.Writer
	Mode        Mode
	Color       ColorMode
	Environment []string
	Terminal    *bool
}

type UI struct {
	input       io.Reader
	output      io.Writer
	progress    io.Writer
	mode        Mode
	color       bool
	environment []string
}

func New(options Options) (*UI, error) {
	if options.Input == nil {
		options.Input = os.Stdin
	}
	if options.Output == nil {
		options.Output = os.Stdout
	}
	if options.Progress == nil {
		options.Progress = os.Stderr
	}
	if len(options.Environment) == 0 {
		options.Environment = os.Environ()
	}
	if options.Mode == "" {
		options.Mode = ModeAuto
	}
	if options.Color == "" {
		options.Color = ColorAuto
	}
	if options.Mode != ModeAuto && options.Mode != ModeInteractive && options.Mode != ModePlain {
		return nil, fmt.Errorf("unsupported terminal UI mode %q", options.Mode)
	}
	if options.Color != ColorAuto && options.Color != ColorAlways && options.Color != ColorNever {
		return nil, fmt.Errorf("unsupported color mode %q", options.Color)
	}
	terminal := isInteractiveTerminal(options.Input, options.Progress)
	if options.Terminal != nil {
		terminal = *options.Terminal
	}
	ci := environmentTruthy(options.Environment, "CI")
	dumb := environmentValue(options.Environment, "TERM") == "dumb"
	resolved := options.Mode
	if resolved == ModeAuto {
		if terminal && !ci && !dumb {
			resolved = ModeInteractive
		} else {
			resolved = ModePlain
		}
	}
	if resolved == ModeInteractive && !terminal {
		return nil, fmt.Errorf("interactive terminal UI requires TTY input and progress output")
	}
	color := options.Color == ColorAlways ||
		(options.Color == ColorAuto && resolved == ModeInteractive && !environmentPresent(options.Environment, "NO_COLOR"))
	return &UI{
		input: options.Input, output: options.Output, progress: options.Progress,
		mode: resolved, color: color, environment: options.Environment,
	}, nil
}

func (ui *UI) Mode() Mode { return ui.mode }

func isInteractiveTerminal(input io.Reader, progress io.Writer) bool {
	in, inOK := input.(*os.File)
	out, outOK := progress.(*os.File)
	return inOK && outOK && term.IsTerminal(int(in.Fd())) && term.IsTerminal(int(out.Fd()))
}

func environmentValue(environment []string, name string) string {
	prefix := name + "="
	for _, item := range environment {
		if strings.HasPrefix(item, prefix) {
			return strings.TrimSpace(strings.TrimPrefix(item, prefix))
		}
	}
	return ""
}

func environmentPresent(environment []string, name string) bool {
	prefix := name + "="
	for _, item := range environment {
		if item == name || strings.HasPrefix(item, prefix) {
			return true
		}
	}
	return false
}

func environmentTruthy(environment []string, name string) bool {
	value := strings.ToLower(environmentValue(environment, name))
	return value != "" && value != "0" && value != "false" && value != "no"
}
