/*
 * [INPUT]: Depends on operator-provided netrc or hgrc files and the current user's home directory.
 * [OUTPUT]: Provides secure installation and platform-correct naming of explicit Git and Mercurial authentication files.
 * [POS]: Serves as the external authentication-file bootstrap helper for Hub startup; configured GitHub tokens bypass process-wide netrc files.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"

	"github.com/mitchellh/go-homedir"
)

// initializeAuthFile checks if provided auth file is at a pre-configured path
// and moves to home directory -- note that this will override whatever
// .netrc/.hgrc file you have in your home directory.
func initializeAuthFile(path string) error {
	if path == "" {
		return nil
	}

	fileBts, err := os.ReadFile(filepath.Clean(path))
	if err != nil {
		return fmt.Errorf("reading %s: %w", path, err)
	}

	hdir, err := homedir.Dir()
	if err != nil {
		return fmt.Errorf("getting home dir: %w", err)
	}

	fileName := transformAuthFileName(filepath.Base(path))
	rcp := filepath.Join(hdir, fileName)
	if err := os.WriteFile(rcp, fileBts, 0o600); err != nil {
		return fmt.Errorf("writing to auth file: %w", err)
	}

	return nil
}

func transformAuthFileName(authFileName string) string {
	if root := strings.TrimLeft(authFileName, "._"); root == "netrc" {
		return getNETRCFilename()
	}
	return authFileName
}

func getNETRCFilename() string {
	if runtime.GOOS == "windows" {
		return "_netrc"
	}
	return ".netrc"
}
