//go:build e2etests
// +build e2etests

/*
 * [INPUT]: Depends on the e2etests package imports and contracts declared in this file.
 * [OUTPUT]: Provides the e2etests package behavior implemented by run_athens.go.
 * [POS]: Serves as maintained source in the e2etests package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */

package e2etests

import (
	"context"
	"fmt"
	"net/http"
	"os/exec"
	"path"
	"path/filepath"
	"time"
)

func buildAthens(goBin, destPath string, env []string) (string, error) {
	target := path.Join(destPath, "skillsgo-hub")
	binFolder, err := filepath.Abs("../cmd/skillsgo-hub")
	if err != nil {
		return "", fmt.Errorf("Failed to get athens source path %v", err)
	}

	cmd := exec.Command(goBin, "build", "-o", target, binFolder)
	cmd.Env = env
	output, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("Failed to build athens: %v - %s", err, string(output))
	}
	return target, nil
}

func stopAthens() error {
	cmd := exec.Command("pkill", "skillsgo-hub")
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("Failed to stop athens: %v - %s", err, string(output))
	}
	return err
}

func runAthensAndWait(ctx context.Context, athensBin string, env []string) error {
	cmd := exec.CommandContext(ctx, athensBin)
	cmd.Env = env

	if err := cmd.Start(); err != nil {
		return fmt.Errorf("Failed to start athens: %w", err)
	}

	ticker := time.NewTicker(time.Second)
	timeout := time.After(20 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			resp, err := http.Get("http://localhost:3000/readyz")
			if err == nil && resp.StatusCode == http.StatusOK {
				resp.Body.Close()
				return nil
			}
			if resp != nil {
				resp.Body.Close()
			}
		case <-timeout:
			return fmt.Errorf("Failed to run athens")
		}
	}
}
