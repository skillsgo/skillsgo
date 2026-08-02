/*
 * [INPUT]: Depends on exact release assembly arguments and the internal CLI release Manifest assembler.
 * [OUTPUT]: Writes one unsigned Manifest payload and checksums file for subsequent protected-workflow signing.
 * [POS]: Serves as the repository release workflow entry point without exposing signing-key access to product commands.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/skillsgo/skillsgo/cli/internal/releasemanifest"
)

func main() {
	assets := flag.String("assets", "", "directory containing the exact CLI platform archives")
	version := flag.String("version", "", "canonical CLI version")
	commit := flag.String("commit", "", "source commit")
	publishedAt := flag.String("published-at", "", "RFC3339 publication time")
	manifest := flag.String("manifest", "", "output Manifest path")
	checksums := flag.String("checksums", "", "output checksums path")
	flag.Parse()
	if flag.NArg() != 0 || *assets == "" || *version == "" || *commit == "" || *publishedAt == "" || *manifest == "" || *checksums == "" {
		flag.Usage()
		os.Exit(64)
	}
	if err := releasemanifest.Assemble(*assets, *version, *commit, *publishedAt, *manifest, *checksums); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
