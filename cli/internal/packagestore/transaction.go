/*
 * [INPUT]: Depends on one verified immutable Package Artifact, canonical member paths, explicit per-Agent selections, destination roots supplied by Agent Adapters, and an optional caller-owned authorization to replace conflicting Package paths.
 * [OUTPUT]: Prepares, commits, finalizes, and rolls back complete Scope Package Stores plus direct canonical-name Agent Skill links, safely restoring Package-contained symlinks, migrating baseline-proven legacy coordinate projections, transactionally replacing authorized conflicts, and allowing callers to choose post-commit disposal for exact replaced targets.
 * [POS]: Serves as the filesystem transaction membrane between Package downloads and portable dependency-state persistence.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package packagestore

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"

	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
	protocolpackage "github.com/skillsgo/skillsgo/protocol/packageidentity"
	protocolversion "github.com/skillsgo/skillsgo/protocol/version"
)

type Projection struct {
	Agent            string
	Root             string
	Selected         []string
	PreviousSelected []string
	PreviousVersion  string
	LegacyOnly       bool
}

type Options struct {
	PackagesRoot       string
	PackagePath        string
	Version            string
	Entries            []protocolartifact.Entry
	Sum                string
	Members            []string
	SkillNames         map[string]string
	PreviousSkillNames map[string]string
	Projections        []Projection
	RemovedProjections []Projection
	RemovePackage      bool
	ReplaceConflicts   bool
}

type preparedPath struct {
	temporary string
	target    string
	backup    string
	action    pathAction
	applied   bool
	dispose   func(string) error
}

type pathAction uint8

const (
	pathCreate pathAction = iota
	pathUnchanged
	pathReplace
	pathDelete
)

type Transaction struct {
	paths     []preparedPath
	committed bool
	finalized bool
}

func CoordinatePath(root, packagePath, version string) string {
	return filepath.Join(root, filepath.FromSlash(packagePath)+"@"+version)
}

func Prepare(options Options) (*Transaction, error) {
	if options.PackagesRoot == "" || (len(options.Projections)+len(options.RemovedProjections) == 0 && !options.RemovePackage) {
		return nil, fmt.Errorf("Package Store root and at least one desired or removed Package Projection are required")
	}
	parsed, err := protocolpackage.ParsePath(options.PackagePath)
	if err != nil || parsed.String() != options.PackagePath || !protocolversion.IsImmutable(options.Version) {
		return nil, fmt.Errorf("invalid immutable Package coordinate %s@%s", options.PackagePath, options.Version)
	}
	entries := options.Entries
	actual, err := protocolartifact.PackageEntriesSum(entries, options.PackagePath, options.Version)
	if err != nil {
		return nil, err
	}
	if actual != options.Sum {
		return nil, fmt.Errorf("Package Sum mismatch for %s@%s", options.PackagePath, options.Version)
	}
	members, err := validateMembers(options.Members)
	if err != nil {
		return nil, err
	}
	previousSkillNames := options.PreviousSkillNames
	if len(previousSkillNames) == 0 {
		previousSkillNames = options.SkillNames
	}
	transaction := &Transaction{paths: make([]preparedPath, 0, len(options.Projections)+len(options.RemovedProjections)+1)}
	fail := func(cause error) (*Transaction, error) {
		_ = transaction.Rollback()
		return nil, cause
	}
	moduleTarget := CoordinatePath(options.PackagesRoot, options.PackagePath, options.Version)
	moduleTemporary, err := materialize(entries, moduleTarget, nil)
	if err != nil {
		return fail(err)
	}
	var packageStorePath preparedPath
	if options.RemovePackage {
		packageStorePath, err = reconcileRemoval(moduleTemporary, moduleTarget, options.ReplaceConflicts)
	} else {
		packageStorePath, err = reconcilePreparedPath(moduleTemporary, moduleTarget, options.ReplaceConflicts)
	}
	if err != nil {
		_ = os.RemoveAll(moduleTemporary)
		return fail(fmt.Errorf("Scope Package Store Local Modification: %w", err))
	}
	transaction.paths = append(transaction.paths, packageStorePath)

	seenAgents, seenTargets := map[string]bool{}, map[string]bool{}
	for _, projection := range options.Projections {
		if projection.Agent == "" || projection.Root == "" || seenAgents[projection.Agent] {
			return fail(fmt.Errorf("invalid or duplicate Package Projection Agent %q", projection.Agent))
		}
		seenAgents[projection.Agent] = true
		selected, err := validateSelection(projection.Selected, members)
		if err != nil {
			return fail(fmt.Errorf("Agent %s: %w", projection.Agent, err))
		}
		previous := map[string]bool{}
		if projection.PreviousSelected != nil {
			previousMembers := members
			if projection.PreviousVersion != "" && projection.PreviousVersion != options.Version {
				previousMembers = memberKeys(previousSkillNames)
			}
			previous, err = validateSelection(projection.PreviousSelected, previousMembers)
			if err != nil {
				return fail(fmt.Errorf("Agent %s previous selection: %w", projection.Agent, err))
			}
		}
		for path := range selected {
			name, nameErr := projectionSkillName(options.SkillNames, path)
			if nameErr != nil {
				return fail(nameErr)
			}
			target := filepath.Join(projection.Root, name)
			if seenTargets[filepath.Clean(target)] {
				return fail(fmt.Errorf("duplicate Package Projection target %s", target))
			}
			seenTargets[filepath.Clean(target)] = true
			desiredStore := memberStorePath(moduleTarget, path)
			baselineStore := ""
			for previousPath := range previous {
				previousName, nameErr := projectionSkillName(previousSkillNames, previousPath)
				if nameErr == nil && previousName == name {
					previousVersion := projection.PreviousVersion
					if previousVersion == "" {
						previousVersion = options.Version
					}
					baselineStore = memberStorePath(CoordinatePath(options.PackagesRoot, options.PackagePath, previousVersion), previousPath)
					break
				}
			}
			prepared, prepareErr := reconcileProjectionLink(target, desiredStore, baselineStore, options.ReplaceConflicts)
			if prepareErr != nil {
				return fail(fmt.Errorf("Package Projection Local Modification for Agent %s: %w", projection.Agent, prepareErr))
			}
			transaction.paths = append(transaction.paths, prepared)
		}
		for previousPath := range previous {
			previousName, nameErr := projectionSkillName(previousSkillNames, previousPath)
			if nameErr != nil {
				return fail(nameErr)
			}
			if selectedNameExists(selected, options.SkillNames, previousName) {
				continue
			}
			target := filepath.Join(projection.Root, previousName)
			previousVersion := projection.PreviousVersion
			if previousVersion == "" {
				previousVersion = options.Version
			}
			baselineStore := memberStorePath(CoordinatePath(options.PackagesRoot, options.PackagePath, previousVersion), previousPath)
			prepared, prepareErr := reconcileProjectionLinkRemoval(target, baselineStore, options.ReplaceConflicts)
			if prepareErr != nil {
				return fail(fmt.Errorf("Package Projection Local Modification for Agent %s: %w", projection.Agent, prepareErr))
			}
			transaction.paths = append(transaction.paths, prepared)
		}
		legacy := CoordinatePath(projection.Root, options.PackagePath, options.Version)
		if _, statErr := os.Lstat(legacy); statErr == nil {
			baseline, materializeErr := materialize(entries, legacy, func(path string) bool {
				member, isManifest := memberForManifest(path, members)
				return !isManifest || (member != "" && selected[member])
			})
			if materializeErr != nil {
				return fail(materializeErr)
			}
			prepared, removalErr := reconcileRemoval(baseline, legacy, options.ReplaceConflicts)
			if removalErr != nil {
				return fail(fmt.Errorf("legacy Package Projection Local Modification for Agent %s: %w", projection.Agent, removalErr))
			}
			transaction.paths = append(transaction.paths, prepared)
		} else if !os.IsNotExist(statErr) {
			return fail(statErr)
		}
	}
	for _, projection := range options.RemovedProjections {
		if projection.Agent == "" || projection.Root == "" || seenAgents[projection.Agent] || projection.PreviousSelected == nil {
			return fail(fmt.Errorf("invalid or duplicate removed Package Projection Agent %q", projection.Agent))
		}
		seenAgents[projection.Agent] = true
		previous, err := validateSelection(projection.PreviousSelected, members)
		if err != nil {
			return fail(fmt.Errorf("Agent %s previous selection: %w", projection.Agent, err))
		}
		if !projection.LegacyOnly {
			for path := range previous {
				name, nameErr := projectionSkillName(previousSkillNames, path)
				if nameErr != nil {
					return fail(nameErr)
				}
				target := filepath.Join(projection.Root, name)
				if seenTargets[filepath.Clean(target)] {
					return fail(fmt.Errorf("duplicate Package Projection target %s", target))
				}
				seenTargets[filepath.Clean(target)] = true
				baselineStore := memberStorePath(moduleTarget, path)
				prepared, prepareErr := reconcileProjectionLinkRemoval(target, baselineStore, options.ReplaceConflicts)
				if prepareErr != nil {
					return fail(fmt.Errorf("Package Projection Local Modification for Agent %s: %w", projection.Agent, prepareErr))
				}
				transaction.paths = append(transaction.paths, prepared)
			}
		}
		legacy := CoordinatePath(projection.Root, options.PackagePath, options.Version)
		if _, statErr := os.Lstat(legacy); statErr == nil {
			baseline, materializeErr := materialize(entries, legacy, func(path string) bool {
				member, isManifest := memberForManifest(path, members)
				return !isManifest || (member != "" && previous[member])
			})
			if materializeErr != nil {
				return fail(materializeErr)
			}
			prepared, removalErr := reconcileRemoval(baseline, legacy, options.ReplaceConflicts)
			if removalErr != nil {
				return fail(fmt.Errorf("legacy Package Projection Local Modification for Agent %s: %w", projection.Agent, removalErr))
			}
			transaction.paths = append(transaction.paths, prepared)
		} else if !os.IsNotExist(statErr) {
			return fail(statErr)
		}
	}
	return transaction, nil
}

func memberForManifest(path string, members map[string]string) (string, bool) {
	if path == "SKILL.md" {
		return members["."], true
	}
	if !strings.HasSuffix(path, "/SKILL.md") {
		return "", false
	}
	candidate := strings.TrimSuffix(path, "/SKILL.md")
	key, err := protocolartifact.PortablePathKey(candidate)
	if err != nil {
		return "", true
	}
	return members[key], true
}

func (transaction *Transaction) Commit() error {
	if transaction == nil || transaction.committed {
		return fmt.Errorf("Package transaction is unavailable or already committed")
	}
	for index := range transaction.paths {
		path := &transaction.paths[index]
		if path.action == pathUnchanged {
			continue
		}
		if err := os.MkdirAll(filepath.Dir(path.target), 0o755); err != nil {
			_ = transaction.Rollback()
			return err
		}
		switch path.action {
		case pathCreate:
			if _, err := os.Lstat(path.target); err == nil {
				_ = transaction.Rollback()
				return fmt.Errorf("Package transaction target appeared concurrently: %s", path.target)
			} else if !os.IsNotExist(err) {
				_ = transaction.Rollback()
				return err
			}
		case pathReplace:
			if err := os.Rename(path.target, path.backup); err != nil {
				_ = transaction.Rollback()
				return fmt.Errorf("backup Package Projection %s: %w", path.target, err)
			}
		case pathDelete:
			if err := os.Rename(path.target, path.backup); err != nil {
				_ = transaction.Rollback()
				return fmt.Errorf("backup removed Package Projection %s: %w", path.target, err)
			}
			path.applied = true
			continue
		default:
			_ = transaction.Rollback()
			return fmt.Errorf("invalid Package transaction action")
		}
		if err := os.Rename(path.temporary, path.target); err != nil {
			if path.action == pathReplace {
				_ = os.Rename(path.backup, path.target)
			}
			_ = transaction.Rollback()
			return err
		}
		path.temporary = ""
		path.applied = true
	}
	transaction.committed = true
	return nil
}

func (transaction *Transaction) Finalize() error {
	if transaction == nil || !transaction.committed || transaction.finalized {
		return fmt.Errorf("Package transaction is not committed or is already finalized")
	}
	var failures []string
	for index := range transaction.paths {
		path := &transaction.paths[index]
		if path.backup != "" {
			var err error
			if path.dispose != nil {
				err = path.dispose(path.backup)
			} else {
				err = os.RemoveAll(path.backup)
			}
			if err != nil {
				failures = append(failures, err.Error())
				continue
			}
			path.backup = ""
		}
	}
	if len(failures) > 0 {
		return fmt.Errorf("finalize Package transaction: %s", strings.Join(failures, "; "))
	}
	transaction.finalized = true
	return nil
}

// SetReplacedPathDisposer assigns post-commit disposal to exact replacement
// targets and returns the targets owned by this transaction.
func (transaction *Transaction) SetReplacedPathDisposer(targets []string, dispose func(string) error) map[string]bool {
	owned := make(map[string]bool)
	wanted := make(map[string]bool, len(targets))
	for _, target := range targets {
		wanted[transactionPathIdentity(target)] = true
	}
	for index := range transaction.paths {
		path := &transaction.paths[index]
		clean := transactionPathIdentity(path.target)
		if wanted[clean] && path.action == pathReplace {
			path.dispose = dispose
			owned[clean] = true
		}
	}
	return owned
}

func transactionPathIdentity(path string) string {
	parent := filepath.Dir(filepath.Clean(path))
	if resolved, err := filepath.EvalSymlinks(parent); err == nil {
		parent = resolved
	}
	return filepath.Join(parent, filepath.Base(path))
}

func (transaction *Transaction) Rollback() error {
	if transaction == nil {
		return nil
	}
	if transaction.finalized {
		return fmt.Errorf("Package transaction is already finalized")
	}
	var failures []string
	for index := len(transaction.paths) - 1; index >= 0; index-- {
		path := &transaction.paths[index]
		if !path.applied || path.action == pathUnchanged {
			continue
		}
		if path.action != pathDelete {
			if err := os.RemoveAll(path.target); err != nil {
				failures = append(failures, err.Error())
				continue
			}
		}
		if (path.action == pathReplace || path.action == pathDelete) && path.backup != "" {
			if err := os.Rename(path.backup, path.target); err != nil {
				failures = append(failures, err.Error())
			}
		}
		path.applied = false
	}
	for _, path := range transaction.paths {
		if path.temporary != "" {
			if err := os.RemoveAll(path.temporary); err != nil {
				failures = append(failures, err.Error())
			}
		}
	}
	if len(failures) > 0 {
		return fmt.Errorf("rollback Package transaction: %s", strings.Join(failures, "; "))
	}
	return nil
}

func reconcileRemoval(baseline, target string, replaceConflict bool) (preparedPath, error) {
	if _, err := os.Lstat(target); os.IsNotExist(err) {
		_ = os.RemoveAll(baseline)
		return preparedPath{target: target, action: pathUnchanged}, nil
	} else if err != nil {
		return preparedPath{}, err
	}
	baselineDigest, err := treeDigest(baseline)
	if err != nil {
		return preparedPath{}, err
	}
	actualDigest, err := treeDigest(target)
	if err != nil {
		return preparedPath{}, err
	}
	if err := os.RemoveAll(baseline); err != nil {
		return preparedPath{}, err
	}
	if actualDigest != baselineDigest && !replaceConflict {
		return preparedPath{}, fmt.Errorf("existing path %s differs from prior declared content", target)
	}
	placeholder, err := os.MkdirTemp(filepath.Dir(target), ".skillsgo-removal-")
	if err != nil {
		return preparedPath{}, err
	}
	if err := os.Remove(placeholder); err != nil {
		return preparedPath{}, err
	}
	return preparedPath{target: target, backup: placeholder, action: pathDelete}, nil
}

func materialize(source []protocolartifact.Entry, target string, keep func(string) bool) (string, error) {
	parent := filepath.Dir(target)
	if err := os.MkdirAll(parent, 0o755); err != nil {
		return "", err
	}
	temporary, err := os.MkdirTemp(parent, ".skillsgo-Package-")
	if err != nil {
		return "", err
	}
	valid := false
	defer func() {
		if !valid {
			_ = os.RemoveAll(temporary)
		}
	}()
	validated, err := protocolartifact.ValidateEntries(source)
	if err != nil {
		return "", err
	}
	entries := make([]protocolartifact.Entry, 0, len(validated))
	for _, entry := range validated {
		if entry.Directory || (keep != nil && !keep(entry.Path)) {
			continue
		}
		entries = append(entries, entry)
	}
	for _, entry := range entries {
		if entry.IsSymlink() {
			continue
		}
		destination := filepath.Join(temporary, filepath.FromSlash(entry.Path))
		relative, err := filepath.Rel(temporary, destination)
		if err != nil || relative == ".." || strings.HasPrefix(relative, ".."+string(filepath.Separator)) {
			return "", fmt.Errorf("Package file escapes destination: %s", entry.Path)
		}
		if err := os.MkdirAll(filepath.Dir(destination), 0o755); err != nil {
			return "", err
		}
		mode := os.FileMode(0o644)
		if entry.Mode.Perm()&0o111 != 0 {
			mode = 0o755
		}
		if err := os.WriteFile(destination, entry.Contents, mode); err != nil {
			return "", err
		}
	}
	for _, entry := range entries {
		if !entry.IsSymlink() {
			continue
		}
		destination := filepath.Join(temporary, filepath.FromSlash(entry.Path))
		if err := os.MkdirAll(filepath.Dir(destination), 0o755); err != nil {
			return "", err
		}
		if err := os.Symlink(filepath.FromSlash(string(entry.Contents)), destination); err != nil {
			return "", err
		}
	}
	canonicalTemporary, err := filepath.EvalSymlinks(temporary)
	if err != nil {
		return "", err
	}
	for _, entry := range entries {
		if !entry.IsSymlink() {
			continue
		}
		resolved, err := filepath.EvalSymlinks(filepath.Join(temporary, filepath.FromSlash(entry.Path)))
		if err != nil {
			_ = os.Remove(filepath.Join(temporary, filepath.FromSlash(entry.Path)))
			continue
		}
		relative, err := filepath.Rel(canonicalTemporary, resolved)
		if err != nil || relative == ".." || strings.HasPrefix(relative, ".."+string(filepath.Separator)) {
			return "", fmt.Errorf("Package symlink escapes destination: %s", entry.Path)
		}
	}
	valid = true
	return temporary, nil
}

func reconcilePreparedPath(temporary, target string, replaceConflict bool) (preparedPath, error) {
	if _, err := os.Lstat(target); os.IsNotExist(err) {
		return preparedPath{temporary: temporary, target: target, action: pathCreate}, nil
	} else if err != nil {
		return preparedPath{}, err
	}
	expected, err := treeDigest(temporary)
	if err != nil {
		return preparedPath{}, err
	}
	actual, err := treeDigest(target)
	if err != nil {
		return preparedPath{}, err
	}
	if actual != expected && !replaceConflict {
		return preparedPath{}, fmt.Errorf("existing path %s differs from deterministic content", target)
	}
	if actual != expected {
		return preparedPath{temporary: temporary, target: target, backup: temporary + ".backup", action: pathReplace}, nil
	}
	if replaceConflict {
		return preparedPath{temporary: temporary, target: target, backup: temporary + ".backup", action: pathReplace}, nil
	}
	if err := os.RemoveAll(temporary); err != nil {
		return preparedPath{}, err
	}
	return preparedPath{target: target, action: pathUnchanged}, nil
}

func projectionSkillName(names map[string]string, path string) (string, error) {
	name := strings.TrimSpace(names[path])
	if name == "" && len(names) == 0 {
		name = filepath.Base(filepath.FromSlash(path))
		if path == "." {
			name = "root-skill"
		}
	}
	if name == "" || name == "." || filepath.Base(name) != name || strings.ContainsAny(name, `/\\`) {
		return "", fmt.Errorf("Package member %q requires a safe canonical Skill name", path)
	}
	return name, nil
}

func memberKeys(names map[string]string) map[string]string {
	result := make(map[string]string, len(names))
	for path := range names {
		key := "."
		if path != "." {
			portable, err := protocolartifact.PortablePathKey(path)
			if err != nil {
				continue
			}
			key = portable
		}
		result[key] = path
	}
	return result
}

func memberStorePath(packageRoot, memberPath string) string {
	if memberPath == "." {
		return packageRoot
	}
	return filepath.Join(packageRoot, filepath.FromSlash(memberPath))
}

func selectedNameExists(selected map[string]bool, names map[string]string, expected string) bool {
	for path := range selected {
		if names[path] == expected {
			return true
		}
	}
	return false
}

func existingProjectionLinkMatches(target, storeTarget string) (bool, error) {
	info, err := os.Lstat(target)
	if err != nil {
		return false, err
	}
	if info.Mode()&os.ModeSymlink == 0 {
		return false, nil
	}
	link, err := os.Readlink(target)
	if err != nil {
		return false, err
	}
	actual := link
	if !filepath.IsAbs(actual) {
		actual = filepath.Join(filepath.Dir(target), actual)
	}
	if resolved, resolveErr := filepath.EvalSymlinks(target); resolveErr == nil {
		actual = resolved
	}
	if resolved, resolveErr := filepath.EvalSymlinks(storeTarget); resolveErr == nil {
		storeTarget = resolved
	}
	return filepath.Clean(actual) == filepath.Clean(storeTarget), nil
}

func temporaryProjectionLink(target, storeTarget string) (string, error) {
	if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
		return "", err
	}
	temporary, err := os.CreateTemp(filepath.Dir(target), ".skillsgo-projection-")
	if err != nil {
		return "", err
	}
	temporaryPath := temporary.Name()
	if err := temporary.Close(); err != nil {
		_ = os.Remove(temporaryPath)
		return "", err
	}
	if err := os.Remove(temporaryPath); err != nil {
		return "", err
	}
	destination, err := filepath.Rel(filepath.Dir(target), storeTarget)
	if err != nil {
		return "", err
	}
	if err := os.Symlink(destination, temporaryPath); err != nil {
		return "", fmt.Errorf("create Agent Skill projection link: %w", err)
	}
	return temporaryPath, nil
}

func reconcileProjectionLink(target, desiredStore, baselineStore string, replaceConflict bool) (preparedPath, error) {
	if matches, err := existingProjectionLinkMatches(target, desiredStore); err == nil && matches {
		if replaceConflict {
			temporary, createErr := temporaryProjectionLink(target, desiredStore)
			if createErr != nil {
				return preparedPath{}, createErr
			}
			return preparedPath{temporary: temporary, target: target, backup: temporary + ".backup", action: pathReplace}, nil
		}
		return preparedPath{target: target, action: pathUnchanged}, nil
	} else if os.IsNotExist(err) {
		temporary, createErr := temporaryProjectionLink(target, desiredStore)
		if createErr != nil {
			return preparedPath{}, createErr
		}
		return preparedPath{temporary: temporary, target: target, action: pathCreate}, nil
	} else if err != nil {
		return preparedPath{}, err
	}
	baselineMatches := false
	if baselineStore != "" {
		baselineMatches, _ = existingProjectionLinkMatches(target, baselineStore)
	}
	if !baselineMatches && !replaceConflict {
		return preparedPath{}, fmt.Errorf("existing path %s differs from prior declared content", target)
	}
	temporary, err := temporaryProjectionLink(target, desiredStore)
	if err != nil {
		return preparedPath{}, err
	}
	return preparedPath{temporary: temporary, target: target, backup: temporary + ".backup", action: pathReplace}, nil
}

func reconcileProjectionLinkRemoval(target, baselineStore string, replaceConflict bool) (preparedPath, error) {
	if _, err := os.Lstat(target); os.IsNotExist(err) {
		return preparedPath{target: target, action: pathUnchanged}, nil
	} else if err != nil {
		return preparedPath{}, err
	}
	matches, err := existingProjectionLinkMatches(target, baselineStore)
	if err != nil {
		return preparedPath{}, err
	}
	if !matches && !replaceConflict {
		return preparedPath{}, fmt.Errorf("existing path %s differs from prior declared content", target)
	}
	placeholder, err := os.CreateTemp(filepath.Dir(target), ".skillsgo-removal-")
	if err != nil {
		return preparedPath{}, err
	}
	backup := placeholder.Name()
	if err := placeholder.Close(); err != nil {
		_ = os.Remove(backup)
		return preparedPath{}, err
	}
	if err := os.Remove(backup); err != nil {
		return preparedPath{}, err
	}
	return preparedPath{target: target, backup: backup, action: pathDelete}, nil
}

func reconcileProjection(desired, baseline, target string, replaceConflict bool) (preparedPath, error) {
	if _, err := os.Lstat(target); os.IsNotExist(err) {
		if baseline != "" {
			_ = os.RemoveAll(baseline)
		}
		return preparedPath{temporary: desired, target: target, action: pathCreate}, nil
	} else if err != nil {
		return preparedPath{}, err
	}
	desiredDigest, err := treeDigest(desired)
	if err != nil {
		return preparedPath{}, err
	}
	actualDigest, err := treeDigest(target)
	if err != nil {
		return preparedPath{}, err
	}
	if actualDigest == desiredDigest {
		_ = os.RemoveAll(desired)
		if baseline != "" {
			_ = os.RemoveAll(baseline)
		}
		return preparedPath{target: target, action: pathUnchanged}, nil
	}
	if baseline == "" {
		if replaceConflict {
			return preparedPath{temporary: desired, target: target, backup: desired + ".backup", action: pathReplace}, nil
		}
		return preparedPath{}, fmt.Errorf("existing path %s differs from deterministic content", target)
	}
	baselineDigest, err := treeDigest(baseline)
	if err != nil {
		return preparedPath{}, err
	}
	if err := os.RemoveAll(baseline); err != nil {
		return preparedPath{}, err
	}
	if actualDigest != baselineDigest && !replaceConflict {
		return preparedPath{}, fmt.Errorf("existing path %s differs from prior declared content", target)
	}
	return preparedPath{temporary: desired, target: target, backup: desired + ".backup", action: pathReplace}, nil
}

func validateMembers(values []string) (map[string]string, error) {
	if len(values) == 0 {
		return nil, fmt.Errorf("Package membership must not be empty")
	}
	members := make(map[string]string, len(values))
	for _, value := range values {
		key := "."
		if value != "." {
			portable, err := protocolartifact.PortablePathKey(value)
			if err != nil {
				return nil, fmt.Errorf("invalid Package member path %q", value)
			}
			key = portable
		}
		if _, exists := members[key]; exists {
			return nil, fmt.Errorf("duplicate Package member path %q", value)
		}
		members[key] = value
	}
	return members, nil
}

func validateSelection(values []string, members map[string]string) (map[string]bool, error) {
	if len(values) == 0 {
		return nil, fmt.Errorf("selected Skills must not be empty")
	}
	selected := make(map[string]bool, len(values))
	for _, value := range values {
		key := "."
		if value != "." {
			portable, err := protocolartifact.PortablePathKey(value)
			if err != nil {
				return nil, fmt.Errorf("invalid selected Skill path %q", value)
			}
			key = portable
		}
		canonical, exists := members[key]
		if !exists || selected[canonical] {
			return nil, fmt.Errorf("selected Skill %q is absent or duplicated", value)
		}
		selected[canonical] = true
	}
	return selected, nil
}

func treeDigest(root string) (string, error) {
	info, err := os.Lstat(root)
	if err != nil || !info.IsDir() {
		return "", fmt.Errorf("Package path %s is not a directory", root)
	}
	paths := make([]string, 0)
	err = filepath.WalkDir(root, func(path string, entry os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if path == root {
			return nil
		}
		relative, err := filepath.Rel(root, path)
		if err != nil {
			return err
		}
		paths = append(paths, filepath.ToSlash(relative))
		return nil
	})
	if err != nil {
		return "", err
	}
	sort.Strings(paths)
	hash := sha256.New()
	for _, relative := range paths {
		path := filepath.Join(root, filepath.FromSlash(relative))
		info, err := os.Lstat(path)
		if err != nil {
			return "", err
		}
		if !info.Mode().IsRegular() && !info.IsDir() && info.Mode()&os.ModeSymlink == 0 {
			return "", fmt.Errorf("Package path contains unsupported file %s", relative)
		}
		kind := "d"
		if info.Mode().IsRegular() {
			kind = "f"
		} else if info.Mode()&os.ModeSymlink != 0 {
			kind = "l"
		}
		_, _ = fmt.Fprintf(hash, "%s %04o %s\n", kind, info.Mode().Perm(), relative)
		if info.Mode().IsRegular() {
			file, err := os.Open(path)
			if err != nil {
				return "", err
			}
			_, copyErr := io.Copy(hash, file)
			closeErr := file.Close()
			if copyErr != nil {
				return "", copyErr
			}
			if closeErr != nil {
				return "", closeErr
			}
		} else if info.Mode()&os.ModeSymlink != 0 {
			target, err := os.Readlink(path)
			if err != nil {
				return "", err
			}
			_, _ = io.WriteString(hash, filepath.ToSlash(target))
		}
	}
	return hex.EncodeToString(hash.Sum(nil)), nil
}

func projectionDigestFromDirectory(root string, keep func(string) bool) (string, error) {
	info, err := os.Lstat(root)
	if err != nil || !info.IsDir() {
		return "", fmt.Errorf("Package path %s is not a directory", root)
	}
	leaves := map[string]bool{}
	paths := map[string]bool{}
	err = filepath.WalkDir(root, func(path string, entry os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if path == root || entry.IsDir() {
			return nil
		}
		relative, err := filepath.Rel(root, path)
		if err != nil {
			return err
		}
		relative = filepath.ToSlash(relative)
		if keep != nil && !keep(relative) {
			return nil
		}
		leaves[relative] = true
		paths[relative] = true
		for parent := filepath.ToSlash(filepath.Dir(filepath.FromSlash(relative))); parent != "."; parent = filepath.ToSlash(filepath.Dir(filepath.FromSlash(parent))) {
			paths[parent] = true
		}
		return nil
	})
	if err != nil {
		return "", err
	}
	ordered := make([]string, 0, len(paths))
	for relative := range paths {
		ordered = append(ordered, relative)
	}
	sort.Strings(ordered)
	hash := sha256.New()
	for _, relative := range ordered {
		if !leaves[relative] {
			_, _ = fmt.Fprintf(hash, "d %04o %s\n", os.FileMode(0o755), relative)
			continue
		}
		path := filepath.Join(root, filepath.FromSlash(relative))
		info, err := os.Lstat(path)
		if err != nil {
			return "", err
		}
		if info.Mode().IsRegular() {
			mode := os.FileMode(0o644)
			if info.Mode().Perm()&0o111 != 0 {
				mode = 0o755
			}
			_, _ = fmt.Fprintf(hash, "f %04o %s\n", mode, relative)
			file, err := os.Open(path)
			if err != nil {
				return "", err
			}
			_, copyErr := io.Copy(hash, file)
			closeErr := file.Close()
			if copyErr != nil {
				return "", copyErr
			}
			if closeErr != nil {
				return "", closeErr
			}
			continue
		}
		if info.Mode()&os.ModeSymlink != 0 {
			_, _ = fmt.Fprintf(hash, "l %04o %s\n", info.Mode().Perm(), relative)
			target, err := os.Readlink(path)
			if err != nil {
				return "", err
			}
			_, _ = io.WriteString(hash, filepath.ToSlash(target))
			continue
		}
		return "", fmt.Errorf("Package path contains unsupported file %s", relative)
	}
	return hex.EncodeToString(hash.Sum(nil)), nil
}
