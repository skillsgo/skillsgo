/*
 * [INPUT]: Depends on Claude Code and Codex local session metadata, bounded file-head reads, filesystem activity times, and canonical Workspace persistence owned by config.Store.
 * [OUTPUT]: Provides recent Agent Workspace discovery ordered by activity without reading prompts or session bodies.
 * [POS]: Serves as the read-only local evidence adapter behind one-time project bootstrap at the public command seam.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"encoding/json"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"
)

const (
	projectDiscoveryWindow = 30 * 24 * time.Hour
	projectDiscoveryLimit  = 12
)

var cwdPattern = regexp.MustCompile(`"cwd"\s*:\s*("(?:[^"\\]|\\.)*")`)

type observedProject struct {
	root       string
	lastActive time.Time
}

func discoverRecentAgentProjects(home string, now time.Time) []string {
	cutoff := now.Add(-projectDiscoveryWindow)
	observed := map[string]time.Time{}
	observe := func(root string, active time.Time) {
		if root == "" || root == home || active.Before(cutoff) {
			return
		}
		if previous, ok := observed[root]; !ok || active.After(previous) {
			observed[root] = active
		}
	}
	discoverClaudeProjects(filepath.Join(home, ".claude", "projects"), cutoff, observe)
	discoverCodexProjects(filepath.Join(home, ".codex", "sessions"), cutoff, observe)

	projects := make([]observedProject, 0, len(observed))
	for root, lastActive := range observed {
		projects = append(projects, observedProject{root: root, lastActive: lastActive})
	}
	sort.Slice(projects, func(i, j int) bool { return projects[i].lastActive.After(projects[j].lastActive) })
	if len(projects) > projectDiscoveryLimit {
		projects = projects[:projectDiscoveryLimit]
	}
	roots := make([]string, 0, len(projects))
	for _, project := range projects {
		roots = append(roots, project.root)
	}
	return roots
}

func discoverClaudeProjects(root string, cutoff time.Time, observe func(string, time.Time)) {
	directories, err := os.ReadDir(root)
	if err != nil {
		return
	}
	for _, directory := range directories {
		if !directory.IsDir() {
			continue
		}
		entries, readErr := os.ReadDir(filepath.Join(root, directory.Name()))
		if readErr != nil {
			continue
		}
		var newest fs.FileInfo
		var newestPath string
		for _, entry := range entries {
			if entry.IsDir() || filepath.Ext(entry.Name()) != ".jsonl" {
				continue
			}
			info, infoErr := entry.Info()
			if infoErr == nil && (newest == nil || info.ModTime().After(newest.ModTime())) {
				newest, newestPath = info, filepath.Join(root, directory.Name(), entry.Name())
			}
		}
		if newest == nil || newest.ModTime().Before(cutoff) {
			continue
		}
		observe(readSessionCWD(newestPath, 64*1024), newest.ModTime())
	}
}

func discoverCodexProjects(root string, cutoff time.Time, observe func(string, time.Time)) {
	files := []observedProject{}
	_ = filepath.WalkDir(root, func(path string, entry fs.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		if entry.IsDir() {
			if path != root {
				relative, relErr := filepath.Rel(root, path)
				if relErr == nil && strings.Count(filepath.Clean(relative), string(filepath.Separator)) >= 3 {
					return filepath.SkipDir
				}
			}
			return nil
		}
		if filepath.Ext(entry.Name()) != ".jsonl" {
			return nil
		}
		info, infoErr := entry.Info()
		if infoErr == nil && !info.ModTime().Before(cutoff) {
			files = append(files, observedProject{root: path, lastActive: info.ModTime()})
		}
		return nil
	})
	sort.Slice(files, func(i, j int) bool { return files[i].lastActive.After(files[j].lastActive) })
	if len(files) > 40 {
		files = files[:40]
	}
	for _, file := range files {
		observe(readSessionCWD(file.root, 16*1024), file.lastActive)
	}
}

func readSessionCWD(path string, limit int64) string {
	file, err := os.Open(path)
	if err != nil {
		return ""
	}
	defer file.Close()
	data, err := io.ReadAll(io.LimitReader(file, limit))
	if err != nil {
		return ""
	}
	match := cwdPattern.FindSubmatch(data)
	if len(match) != 2 {
		return ""
	}
	var cwd string
	if json.Unmarshal(match[1], &cwd) != nil {
		return ""
	}
	return cwd
}
