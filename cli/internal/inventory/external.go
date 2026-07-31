/*
 * [INPUT]: Depends on the installed Agent Catalog, explicit project roots, accounted target keys, and bounded read-only filesystem content under known Agent Skill directories.
 * [OUTPUT]: Adds scope-aware content-identified External Installation entries, manifest names/descriptions, and target metadata without creating declarations, mutating content, following nested symlinks, or contacting a Hub.
 * [POS]: Serves as the read-only external-content discovery half of unified inventory reconciliation.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package inventory

import (
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
	"github.com/skillsgo/skillsgo/cli/internal/install"
	"gopkg.in/yaml.v3"
)

const (
	externalManifestReadLimit = 256 * 1024
	externalContentEntryLimit = 5000
	externalContentByteLimit  = 64 << 20
)

func addExternalInstallations(
	entries map[string]*Entry,
	accountedTargets map[string]bool,
	projectRoots []string,
	includeGlobal bool,
	catalog *agent.Catalog,
) {
	definitions := catalog.Installed()
	userDiscoveryRoots := make([]string, 0)
	if includeGlobal {
		for _, definition := range definitions {
			if roots, ok := catalog.SkillRoots(definition.ID, agent.ScopeGlobal, ""); ok {
				for _, root := range roots.DiscoveryRoots {
					userDiscoveryRoots = appendPathIfMissing(userDiscoveryRoots, root)
				}
			}
		}
	}
	for _, definition := range definitions {
		if includeGlobal {
			if roots, ok := catalog.SkillRoots(definition.ID, agent.ScopeGlobal, ""); ok {
				for _, root := range roots.DiscoveryRoots {
					scanExternalDirectory(entries, accountedTargets, definition.ID, install.ScopeGlobal, "", root, userDiscoveryRoots)
				}
			}
		}
		if definition.ProjectDir == "" {
			continue
		}
		for _, projectRoot := range projectRoots {
			if roots, ok := catalog.SkillRoots(definition.ID, agent.ScopeProject, projectRoot); ok {
				allowedRoots := projectScopeDiscoveryRoots(catalog, definitions, projectRoot)
				for _, root := range roots.DiscoveryRoots {
					scanExternalDirectory(entries, accountedTargets, definition.ID, install.ScopeProject, projectRoot, root, allowedRoots)
				}
			}
		}
	}
}

func projectScopeDiscoveryRoots(catalog *agent.Catalog, definitions []agent.Definition, projectRoot string) []string {
	result := make([]string, 0)
	for _, definition := range definitions {
		if roots, ok := catalog.SkillRoots(definition.ID, agent.ScopeProject, projectRoot); ok {
			for _, root := range roots.DiscoveryRoots {
				result = appendPathIfMissing(result, root)
			}
		}
	}
	return result
}

func appendPathIfMissing(paths []string, candidate string) []string {
	for _, existing := range paths {
		if filepath.Clean(existing) == filepath.Clean(candidate) {
			return paths
		}
	}
	return append(paths, candidate)
}

func scanExternalDirectory(
	entries map[string]*Entry,
	accountedTargets map[string]bool,
	agentID string,
	scope install.Scope,
	projectRoot string,
	directory string,
	allowedRoots []string,
) {
	children, err := os.ReadDir(directory)
	if err != nil {
		return
	}
	sort.Slice(children, func(i, j int) bool { return children[i].Name() < children[j].Name() })
	for _, child := range children {
		path := filepath.Join(directory, child.Name())
		if !lexicallyWithin(directory, path) {
			continue
		}
		info, err := os.Stat(path)
		if err != nil || !info.IsDir() {
			continue
		}
		resolvedPath := resolveInventoryPath(path)
		if !withinOneDiscoveryRoot(resolvedPath, allowedRoots) {
			continue
		}
		manifestPath := filepath.Join(path, "SKILL.md")
		if !lexicallyWithin(directory, manifestPath) {
			continue
		}
		manifestInfo, err := os.Stat(manifestPath)
		if err != nil || !manifestInfo.Mode().IsRegular() {
			continue
		}
		if !pathWithin(resolvedPath, resolveInventoryPath(manifestPath)) {
			continue
		}
		key := targetKey(agentID, scope, path)
		if accountedTargets[key] {
			continue
		}
		metadata := readSkillManifestMetadata(manifestPath)
		name := metadata.name
		if name == "" {
			name = child.Name()
		}
		entry := ensureExternalEntry(entries, name, metadata.description, path, scope, projectRoot)
		entry.Targets = append(entry.Targets, Target{
			Scope: scope, ProjectRoot: projectRoot, Agent: agentID,
			Path: filepath.Clean(path), Version: "", Health: HealthHealthy,
		})
		entry.Agents = appendUnique(entry.Agents, agentID)
		if projectRoot != "" {
			entry.Projects = appendUnique(entry.Projects, projectRoot)
		}
		accountedTargets[key] = true
	}
}

func withinOneDiscoveryRoot(path string, roots []string) bool {
	for _, root := range roots {
		if pathWithin(root, path) {
			return true
		}
	}
	return false
}

func lexicallyWithin(root, candidate string) bool {
	relative, err := filepath.Rel(filepath.Clean(root), filepath.Clean(candidate))
	return err == nil && relative != ".." && !strings.HasPrefix(relative, ".."+string(filepath.Separator))
}

func ensureExternalEntry(entries map[string]*Entry, name, description, path string, scope install.Scope, projectRoot string) *Entry {
	inventoryKey := externalInventoryKey(name, path, scope, projectRoot)
	if entry := entries[inventoryKey]; entry != nil {
		return entry
	}
	entry := &Entry{
		InventoryKey: inventoryKey, Name: name, Description: description,
		Provenance: ProvenanceExternal, Health: HealthHealthy,
		Agents: []string{}, Projects: []string{}, Versions: []string{}, Targets: []Target{},
	}
	entries[inventoryKey] = entry
	return entry
}

func externalInventoryKey(name, path string, scope install.Scope, projectRoot string) string {
	resolvedPath := resolveInventoryPath(path)
	digest, err := externalContentDigest(resolvedPath, externalContentEntryLimit, externalContentByteLimit)
	if err == nil {
		entryHash := sha256.New()
		_, _ = io.WriteString(entryHash, "skillsgo-external-entry-v1\x00")
		_ = writeExternalDigestFrame(entryHash, []byte(scope))
		_ = writeExternalDigestFrame(entryHash, []byte(filepath.Clean(projectRoot)))
		_ = writeExternalDigestFrame(entryHash, []byte(name))
		_ = writeExternalDigestFrame(entryHash, []byte(digest))
		return "external:" + hex.EncodeToString(entryHash.Sum(nil))
	}
	fallback := sha256.Sum256([]byte("skillsgo-external-path-v1\x00" + string(scope) + "\x00" + filepath.Clean(projectRoot) + "\x00" + resolvedPath))
	return "external:" + hex.EncodeToString(fallback[:])
}

func externalContentDigest(rootPath string, entryLimit int, byteLimit int64) (string, error) {
	root, err := os.OpenRoot(rootPath)
	if err != nil {
		return "", err
	}
	defer root.Close()

	hash := sha256.New()
	_, _ = io.WriteString(hash, "skillsgo-external-content-v1\x00")
	entries := 0
	var bytesRead int64
	err = fs.WalkDir(root.FS(), ".", func(path string, entry fs.DirEntry, walkErr error) error {
		if walkErr != nil || path == "." {
			return walkErr
		}
		entries++
		if entries > entryLimit {
			return fmt.Errorf("external Skill exceeds %d filesystem entries", entryLimit)
		}
		info, err := entry.Info()
		if err != nil {
			return err
		}
		kind := byte('f')
		switch {
		case entry.IsDir():
			kind = 'd'
		case info.Mode()&os.ModeSymlink != 0:
			kind = 'l'
		case !info.Mode().IsRegular():
			return fmt.Errorf("external Skill contains unsupported file %q", path)
		}
		if _, err := hash.Write([]byte{kind}); err != nil {
			return err
		}
		if err := writeExternalDigestFrame(hash, []byte(path)); err != nil {
			return err
		}
		if entry.IsDir() {
			return nil
		}
		if info.Mode()&os.ModeSymlink != 0 {
			target, err := root.Readlink(filepath.FromSlash(path))
			if err != nil {
				return err
			}
			data := []byte(filepath.ToSlash(target))
			if int64(len(data)) > byteLimit-bytesRead {
				return fmt.Errorf("external Skill exceeds %d content bytes", byteLimit)
			}
			bytesRead += int64(len(data))
			return writeExternalDigestFrame(hash, data)
		}
		if info.Size() < 0 || info.Size() > byteLimit-bytesRead {
			return fmt.Errorf("external Skill exceeds %d content bytes", byteLimit)
		}
		file, err := root.Open(filepath.FromSlash(path))
		if err != nil {
			return err
		}
		openedInfo, statErr := file.Stat()
		if statErr != nil || !openedInfo.Mode().IsRegular() || openedInfo.Size() != info.Size() || !os.SameFile(info, openedInfo) {
			_ = file.Close()
			if statErr != nil {
				return statErr
			}
			return fmt.Errorf("external Skill changed while hashing %q", path)
		}
		if err := binary.Write(hash, binary.BigEndian, uint64(info.Size())); err != nil {
			_ = file.Close()
			return err
		}
		copied, copyErr := io.Copy(hash, io.LimitReader(file, info.Size()+1))
		closeErr := file.Close()
		if copyErr != nil || copied != info.Size() {
			if copyErr != nil {
				return copyErr
			}
			return fmt.Errorf("external Skill changed while hashing %q", path)
		}
		if closeErr != nil {
			return closeErr
		}
		bytesRead += copied
		return nil
	})
	if err != nil {
		return "", err
	}
	return hex.EncodeToString(hash.Sum(nil)), nil
}

func writeExternalDigestFrame(writer io.Writer, data []byte) error {
	if err := binary.Write(writer, binary.BigEndian, uint64(len(data))); err != nil {
		return err
	}
	_, err := writer.Write(data)
	return err
}

type skillManifestMetadata struct {
	name        string
	description string
}

func setEntryDescription(entry *Entry, targetPath string) {
	if entry.Description != "" {
		return
	}
	entry.Description = readSkillManifestMetadata(filepath.Join(targetPath, "SKILL.md")).description
}

func readSkillManifestMetadata(manifestPath string) skillManifestMetadata {
	file, err := os.Open(manifestPath)
	if err != nil {
		return skillManifestMetadata{}
	}
	defer file.Close()
	data, err := io.ReadAll(io.LimitReader(file, externalManifestReadLimit))
	if err != nil {
		return skillManifestMetadata{}
	}
	normalized := strings.ReplaceAll(string(data), "\r\n", "\n")
	if !strings.HasPrefix(normalized, "---\n") {
		return skillManifestMetadata{}
	}
	end := strings.Index(normalized[4:], "\n---\n")
	if end < 0 {
		return skillManifestMetadata{}
	}
	var manifest struct {
		Name        string `yaml:"name"`
		Description string `yaml:"description"`
	}
	if yaml.Unmarshal([]byte(normalized[4:4+end]), &manifest) != nil {
		return skillManifestMetadata{}
	}
	return skillManifestMetadata{
		name:        strings.TrimSpace(manifest.Name),
		description: strings.TrimSpace(manifest.Description),
	}
}
