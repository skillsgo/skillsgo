package main

import (
	"fmt"
	"os"

	"github.com/skillsgo/skillsgo/cli/internal/command"
)

func main() {
	if err := command.Execute(os.Args[1:], os.Stdout, os.Stderr); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
