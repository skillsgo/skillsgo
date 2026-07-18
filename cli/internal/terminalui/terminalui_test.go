/*
 * [INPUT]: Uses deterministic streams, environment values, and terminal capability overrides against the terminal UI interface.
 * [OUTPUT]: Specifies automatic Interactive/Plain selection, CI and NO_COLOR fallback, static documents, and append-only operation events.
 * [POS]: Serves as the interface-level behavior suite for the terminal UI deep module.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package terminalui

import (
	"bytes"
	"context"
	"errors"
	"strings"
	"testing"
)

func TestAutomaticModeSelection(t *testing.T) {
	terminal := true
	ui, err := New(Options{Terminal: &terminal, Environment: []string{"TERM=xterm-256color"}})
	if err != nil {
		t.Fatal(err)
	}
	if ui.Mode() != ModeInteractive {
		t.Fatalf("expected interactive mode, got %s", ui.Mode())
	}
	for _, environment := range [][]string{{"CI=true"}, {"TERM=dumb"}} {
		ui, err = New(Options{Terminal: &terminal, Environment: environment})
		if err != nil {
			t.Fatal(err)
		}
		if ui.Mode() != ModePlain {
			t.Fatalf("expected plain mode for %v, got %s", environment, ui.Mode())
		}
	}
}

func TestPlainDocumentAndOperationAreAppendOnly(t *testing.T) {
	var output, progress bytes.Buffer
	ui, err := New(Options{Output: &output, Progress: &progress, Mode: ModePlain})
	if err != nil {
		t.Fatal(err)
	}
	err = ui.Render(Document{Title: "Global Skills", Sections: []Section{{
		Title: "External", Rows: []Row{{State: "•", Primary: "demo", Secondary: "~/.agents/skills/demo", Meta: []string{"Codex"}}},
	}}})
	if err != nil {
		t.Fatal(err)
	}
	want := "Global Skills\n\nExternal\n  • demo  ~/.agents/skills/demo  Codex\n"
	if output.String() != want {
		t.Fatalf("unexpected document:\n%s", output.String())
	}
	wantErr := errors.New("download failed")
	err = ui.Run(context.Background(), Operation{Title: "Installing demo", Run: func(_ context.Context, emit func(Event)) error {
		emit(Event{Kind: EventStarted, ID: "download", Label: "Downloading"})
		emit(Event{Kind: EventProgress, ID: "download", Label: "Downloading", Current: 5, Total: 10})
		emit(Event{Kind: EventFailed, ID: "download", Label: "Download", Detail: "failed"})
		return wantErr
	}})
	if !errors.Is(err, wantErr) {
		t.Fatalf("expected operation error, got %v", err)
	}
	if strings.ContainsAny(progress.String(), "\r\x1b") {
		t.Fatalf("plain progress contains terminal control characters: %q", progress.String())
	}
	if !strings.Contains(progress.String(), "[..] Downloading (50%)") {
		t.Fatalf("missing plain progress milestone: %q", progress.String())
	}
}

func TestInteractiveModeRequiresTerminal(t *testing.T) {
	notTerminal := false
	_, err := New(Options{Mode: ModeInteractive, Terminal: &notTerminal})
	if err == nil {
		t.Fatal("expected forced interactive mode to reject non-terminal streams")
	}
}

func TestInteractiveOperationConsumesTheSameEvents(t *testing.T) {
	terminal := true
	var input, progress bytes.Buffer
	ui, err := New(Options{
		Input: &input, Progress: &progress, Mode: ModeInteractive,
		Color: ColorNever, Terminal: &terminal, Environment: []string{"TERM=xterm-256color"},
	})
	if err != nil {
		t.Fatal(err)
	}
	err = ui.Run(context.Background(), Operation{Title: "Installing demo", Run: func(_ context.Context, emit func(Event)) error {
		emit(Event{Kind: EventStarted, ID: "codex", Label: "Codex", Detail: "installing"})
		emit(Event{Kind: EventSucceeded, ID: "codex", Label: "Codex", Detail: "installed"})
		return nil
	}})
	if err != nil {
		t.Fatal(err)
	}
	if strings.Count(progress.String(), "Installing demo") != 1 || strings.Count(progress.String(), "Codex installed") != 1 {
		t.Fatalf("interactive adapter did not render events: %q", progress.String())
	}
	if strings.Contains(progress.String(), "?2026") || strings.Contains(progress.String(), "?2027") {
		t.Fatalf("interactive adapter leaked terminal capability negotiation: %q", progress.String())
	}
}

func TestPlainProgressEmitsTenPercentMilestones(t *testing.T) {
	var progress bytes.Buffer
	ui, err := New(Options{Progress: &progress, Mode: ModePlain})
	if err != nil {
		t.Fatal(err)
	}
	err = ui.Run(context.Background(), Operation{Run: func(_ context.Context, emit func(Event)) error {
		for current := int64(1); current <= 100; current++ {
			emit(Event{Kind: EventProgress, ID: "download", Label: "Downloading", Current: current, Total: 100})
		}
		return nil
	}})
	if err != nil {
		t.Fatal(err)
	}
	if lines := strings.Count(strings.TrimSpace(progress.String()), "\n") + 1; lines != 10 {
		t.Fatalf("expected ten CI progress milestones, got %d:\n%s", lines, progress.String())
	}
	if !strings.Contains(progress.String(), "(10%)") || !strings.Contains(progress.String(), "(100%)") {
		t.Fatalf("missing progress endpoints:\n%s", progress.String())
	}
}
