/*
 * [INPUT]: Depends on caller-provided Documents and the resolved terminal mode and color policy.
 * [OUTPUT]: Renders grouped, width-safe Human results with Lip Gloss styling or stable plain-text fallback.
 * [POS]: Serves as the static result renderer inside the terminal UI module.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package terminalui

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/lipgloss"
)

type Document struct {
	Title    string
	Sections []Section
}

type Section struct {
	Title string
	Rows  []Row
}

type Row struct {
	State     string
	Primary   string
	Secondary string
	Meta      []string
}

func (ui *UI) Render(document Document) error {
	if !ui.color {
		_, err := fmt.Fprint(ui.output, renderPlain(document))
		return err
	}
	_, err := fmt.Fprint(ui.output, renderStyled(document))
	return err
}

func renderPlain(document Document) string {
	var output strings.Builder
	if document.Title != "" {
		output.WriteString(document.Title)
		output.WriteString("\n")
	}
	for sectionIndex, section := range document.Sections {
		if sectionIndex > 0 || document.Title != "" {
			output.WriteString("\n")
		}
		if section.Title != "" {
			output.WriteString(section.Title)
			output.WriteString("\n")
		}
		for _, row := range section.Rows {
			if row.State != "" {
				output.WriteString("  ")
				output.WriteString(row.State)
				output.WriteString(" ")
			} else {
				output.WriteString("  ")
			}
			output.WriteString(row.Primary)
			if row.Secondary != "" {
				output.WriteString("  ")
				output.WriteString(row.Secondary)
			}
			if len(row.Meta) > 0 {
				output.WriteString("  ")
				output.WriteString(strings.Join(row.Meta, ", "))
			}
			output.WriteString("\n")
		}
	}
	return output.String()
}

func renderStyled(document Document) string {
	title := lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("12"))
	sectionTitle := lipgloss.NewStyle().Bold(true)
	secondary := lipgloss.NewStyle().Foreground(lipgloss.Color("8"))
	meta := lipgloss.NewStyle().Foreground(lipgloss.Color("6"))
	var output strings.Builder
	if document.Title != "" {
		output.WriteString(title.Render(document.Title))
		output.WriteString("\n")
	}
	for sectionIndex, section := range document.Sections {
		if sectionIndex > 0 || document.Title != "" {
			output.WriteString("\n")
		}
		if section.Title != "" {
			output.WriteString(sectionTitle.Render(section.Title))
			output.WriteString("\n")
		}
		for _, row := range section.Rows {
			output.WriteString("  ")
			if row.State != "" {
				output.WriteString(row.State)
				output.WriteString(" ")
			}
			output.WriteString(row.Primary)
			if row.Secondary != "" {
				output.WriteString("  ")
				output.WriteString(secondary.Render(row.Secondary))
			}
			if len(row.Meta) > 0 {
				output.WriteString("  ")
				output.WriteString(meta.Render(strings.Join(row.Meta, ", ")))
			}
			output.WriteString("\n")
		}
	}
	return output.String()
}
