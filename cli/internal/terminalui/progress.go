/*
 * [INPUT]: Depends on caller-provided Operations, structured progress Events, Bubble Tea, Bubbles Spinner, and resolved terminal mode.
 * [OUTPUT]: Runs one operation with live interactive rendering or append-only CI-safe progress and returns the operation error unchanged.
 * [POS]: Serves as the dynamic operation renderer inside the terminal UI module.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package terminalui

import (
	"context"
	"fmt"
	"strings"

	"github.com/charmbracelet/bubbles/spinner"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

type EventKind string

const (
	EventStarted   EventKind = "started"
	EventProgress  EventKind = "progress"
	EventSucceeded EventKind = "succeeded"
	EventWarning   EventKind = "warning"
	EventFailed    EventKind = "failed"
)

type Event struct {
	Kind    EventKind
	ID      string
	Label   string
	Detail  string
	Current int64
	Total   int64
}

type Operation struct {
	Title string
	Run   func(context.Context, func(Event)) error
}

func (ui *UI) Run(ctx context.Context, operation Operation) error {
	if operation.Run == nil {
		return fmt.Errorf("terminal operation requires a Run function")
	}
	if ui.mode == ModePlain {
		return ui.runPlain(ctx, operation)
	}
	return ui.runInteractive(ctx, operation)
}

func (ui *UI) runPlain(ctx context.Context, operation Operation) error {
	if operation.Title != "" {
		fmt.Fprintln(ui.progress, operation.Title)
	}
	lastPercent := map[string]int64{}
	err := operation.Run(ctx, func(event Event) {
		prefix := map[EventKind]string{
			EventStarted: "[ ]", EventProgress: "[..]", EventSucceeded: "[ok]",
			EventWarning: "[!]", EventFailed: "[x]",
		}[event.Kind]
		line := strings.TrimSpace(event.Label + " " + event.Detail)
		if event.Total > 0 && event.Kind == EventProgress {
			percent := event.Current * 100 / event.Total
			key := event.ID
			if key == "" {
				key = event.Label
			}
			if percent < 100 && percent < lastPercent[key]+10 {
				return
			}
			lastPercent[key] = percent
			line = fmt.Sprintf("%s (%d%%)", line, percent)
		}
		fmt.Fprintf(ui.progress, "%s %s\n", prefix, line)
	})
	return err
}

type operationMessage Event
type operationDone struct{ err error }

type progressModel struct {
	title   string
	spinner spinner.Model
	events  chan tea.Msg
	rows    map[string]Event
	order   []string
}

func newProgressModel(title string, events chan tea.Msg, color bool) progressModel {
	indicator := spinner.New(spinner.WithSpinner(spinner.Dot))
	if color {
		indicator.Style = lipgloss.NewStyle().Foreground(lipgloss.Color("12"))
	}
	return progressModel{title: title, spinner: indicator, events: events, rows: map[string]Event{}}
}

func (model progressModel) Init() tea.Cmd {
	return tea.Batch(model.spinner.Tick, waitOperationMessage(model.events))
}

func waitOperationMessage(events chan tea.Msg) tea.Cmd {
	return func() tea.Msg { return <-events }
}

func (model progressModel) Update(message tea.Msg) (tea.Model, tea.Cmd) {
	switch message := message.(type) {
	case operationMessage:
		event := Event(message)
		key := event.ID
		if key == "" {
			key = event.Label
		}
		if _, exists := model.rows[key]; !exists {
			model.order = append(model.order, key)
		}
		model.rows[key] = event
		return model, waitOperationMessage(model.events)
	case operationDone:
		return model, tea.Quit
	default:
		var command tea.Cmd
		model.spinner, command = model.spinner.Update(message)
		return model, command
	}
}

func (model progressModel) View() string {
	var output strings.Builder
	output.WriteString(lipgloss.NewStyle().Bold(true).Render(model.title))
	output.WriteString("\n\n")
	for _, key := range model.order {
		event := model.rows[key]
		marker := model.spinner.View()
		switch event.Kind {
		case EventSucceeded:
			marker = "✓"
		case EventWarning:
			marker = "!"
		case EventFailed:
			marker = "✗"
		}
		output.WriteString("  ")
		output.WriteString(marker)
		output.WriteString(" ")
		output.WriteString(strings.TrimSpace(event.Label + " " + event.Detail))
		if event.Total > 0 && event.Kind == EventProgress {
			fmt.Fprintf(&output, "  %d%%", event.Current*100/event.Total)
		}
		output.WriteString("\n")
	}
	return output.String()
}

func (ui *UI) runInteractive(ctx context.Context, operation Operation) error {
	events := make(chan tea.Msg, 32)
	result := make(chan error, 1)
	go func() {
		err := operation.Run(ctx, func(event Event) { events <- operationMessage(event) })
		result <- err
		events <- operationDone{err: err}
	}()
	program := tea.NewProgram(
		newProgressModel(operation.Title, events, ui.color),
		tea.WithInput(ui.input),
		tea.WithOutput(ui.progress),
	)
	_, err := program.Run()
	if err != nil {
		return err
	}
	return <-result
}
