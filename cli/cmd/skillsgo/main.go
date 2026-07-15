/*
 * [INPUT]: Depends on process arguments/streams plus command execution and stable exit-code classification.
 * [OUTPUT]: Runs the SkillsGo CLI and exits with machine-readable availability semantics while retaining human stderr.
 * [POS]: Serves as the operating-system process entry point above the command package.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package main

import (
	"fmt"
	"os"

	"github.com/skillsgo/skillsgo/cli/internal/command"
)

func main() {
	if err := command.Execute(os.Args[1:], os.Stdout, os.Stderr); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(command.ExitCode(err))
	}
}
