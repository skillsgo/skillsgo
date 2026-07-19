//go:build windows

/*
 * [INPUT]: Depends on Windows PowerShell, Microsoft.VisualBasic FileIO, and an absolute filesystem path passed as an argv value.
 * [OUTPUT]: Provides the Windows implementation of recoverable disposal through the Recycle Bin.
 * [POS]: Serves as the Windows adapter behind the package-level Trash boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package trash

import (
	"fmt"
	"os/exec"
)

func movePlatform(path string) error {
	const script = `$ErrorActionPreference='Stop'; Add-Type -AssemblyName Microsoft.VisualBasic; $p=$args[0]; if ([System.IO.Directory]::Exists($p)) { [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($p,'OnlyErrorDialogs','SendToRecycleBin') } else { [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($p,'OnlyErrorDialogs','SendToRecycleBin') }`
	output, err := exec.Command("powershell.exe", "-NoProfile", "-NonInteractive", "-Command", script, path).CombinedOutput()
	if err != nil {
		return fmt.Errorf("Recycle Bin: %w: %s", err, output)
	}
	return nil
}
