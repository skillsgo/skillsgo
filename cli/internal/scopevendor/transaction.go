/*
 * [INPUT]: Depends on one verified immutable Repository Artifact, canonical member paths, explicit per-Agent selections, and destination roots supplied by Agent Adapters.
 * [OUTPUT]: Prepares, commits, compares, and rolls back complete ordinary-file Scope Vendors and deterministic Repository Projections without overwriting existing paths.
 * [POS]: Serves as the filesystem transaction membrane between Repository downloads and portable dependency-state persistence.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package scopevendor

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
	protocolskillid "github.com/skillsgo/skillsgo/protocol/skillid"
	protocolversion "github.com/skillsgo/skillsgo/protocol/version"
)

type Projection struct {
	Agent    string
	Root     string
	Selected []string
}

type Options struct {
	VendorRoot   string
	RepositoryID string
	Version      string
	Archive      []byte
	Sum          string
	Members      []string
	Projections  []Projection
}

type preparedPath struct {
	temporary string
	target    string
	existing  bool
}

type Transaction struct {
	paths     []preparedPath
	created   []string
	committed bool
}

func CoordinatePath(root, repositoryID, version string) string {
	return filepath.Join(root, filepath.FromSlash(repositoryID)+"@"+version)
}

func Prepare(options Options) (*Transaction, error) {
	if options.VendorRoot == "" || len(options.Projections) == 0 {
		return nil, fmt.Errorf("Vendor root and at least one Repository Projection are required")
	}
	parsed, err := protocolskillid.Parse(options.RepositoryID)
	if err != nil || parsed.String() != options.RepositoryID || parsed.SkillPath != "." || !protocolversion.IsImmutable(options.Version) {
		return nil, fmt.Errorf("invalid immutable Repository coordinate %s@%s", options.RepositoryID, options.Version)
	}
	actual, err := protocolartifact.RepositorySum(options.Archive, options.RepositoryID, options.Version)
	if err != nil {
		return nil, err
	}
	if actual != options.Sum {
		return nil, fmt.Errorf("Repository Sum mismatch for %s@%s", options.RepositoryID, options.Version)
	}
	members, err := validateMembers(options.Members)
	if err != nil {
		return nil, err
	}
	transaction := &Transaction{paths: make([]preparedPath, 0, len(options.Projections)+1)}
	fail := func(cause error) (*Transaction, error) {
		_ = transaction.Rollback()
		return nil, cause
	}
	vendorTarget := CoordinatePath(options.VendorRoot, options.RepositoryID, options.Version)
	vendorTemporary, err := materialize(options.Archive, options.RepositoryID, options.Version, vendorTarget, nil)
	if err != nil {
		return fail(err)
	}
	vendorPath, err := reconcilePreparedPath(vendorTemporary, vendorTarget)
	if err != nil {
		return fail(fmt.Errorf("Scope Vendor Local Modification: %w", err))
	}
	transaction.paths = append(transaction.paths, vendorPath)

	seenAgents := map[string]bool{}
	for _, projection := range options.Projections {
		if projection.Agent == "" || projection.Root == "" || seenAgents[projection.Agent] {
			return fail(fmt.Errorf("invalid or duplicate Repository Projection Agent %q", projection.Agent))
		}
		seenAgents[projection.Agent] = true
		selected, err := validateSelection(projection.Selected, members)
		if err != nil {
			return fail(fmt.Errorf("Agent %s: %w", projection.Agent, err))
		}
		target := CoordinatePath(projection.Root, options.RepositoryID, options.Version)
		temporary, err := materialize(options.Archive, options.RepositoryID, options.Version, target, func(path string) bool {
			member, isManifest := memberForManifest(path, members)
			return !isManifest || member == "" || selected[member]
		})
		if err != nil {
			return fail(err)
		}
		prepared, err := reconcilePreparedPath(temporary, target)
		if err != nil {
			return fail(fmt.Errorf("Repository Projection Local Modification for Agent %s: %w", projection.Agent, err))
		}
		transaction.paths = append(transaction.paths, prepared)
	}
	return transaction, nil
}

func memberForManifest(path string, members map[string]string) (string, bool) {
	if path == "SKILL.md" {
		member, ok := members["."]
		return member, ok
	}
	if !strings.HasSuffix(path, "/SKILL.md") {
		return "", false
	}
	candidate := strings.TrimSuffix(path, "/SKILL.md")
	key, err := protocolartifact.PortablePathKey(candidate)
	if err != nil {
		return "", false
	}
	member, ok := members[key]
	return member, ok
}

func (transaction *Transaction) Commit() error {
	if transaction == nil || transaction.committed {
		return fmt.Errorf("Repository transaction is unavailable or already committed")
	}
	for index := range transaction.paths {
		path := &transaction.paths[index]
		if path.existing {
			continue
		}
		if err := os.MkdirAll(filepath.Dir(path.target), 0o755); err != nil {
			_ = transaction.Rollback()
			return err
		}
		if _, err := os.Lstat(path.target); err == nil {
			_ = transaction.Rollback()
			return fmt.Errorf("Repository transaction target appeared concurrently: %s", path.target)
		} else if !os.IsNotExist(err) {
			_ = transaction.Rollback()
			return err
		}
		if err := os.Rename(path.temporary, path.target); err != nil {
			_ = transaction.Rollback()
			return err
		}
		transaction.created = append(transaction.created, path.target)
		path.temporary = ""
	}
	transaction.committed = true
	return nil
}

func (transaction *Transaction) Rollback() error {
	if transaction == nil {
		return nil
	}
	var failures []string
	for index := len(transaction.created) - 1; index >= 0; index-- {
		if err := os.RemoveAll(transaction.created[index]); err != nil {
			failures = append(failures, err.Error())
		}
	}
	transaction.created = nil
	for _, path := range transaction.paths {
		if path.temporary != "" {
			if err := os.RemoveAll(path.temporary); err != nil {
				failures = append(failures, err.Error())
			}
		}
	}
	if len(failures) > 0 {
		return fmt.Errorf("rollback Repository transaction: %s", strings.Join(failures, "; "))
	}
	return nil
}

func materialize(archive []byte, repositoryID, version, target string, keep func(string) bool) (string, error) {
	parent := filepath.Dir(target)
	if err := os.MkdirAll(parent, 0o755); err != nil {
		return "", err
	}
	temporary, err := os.MkdirTemp(parent, ".skillsgo-repository-")
	if err != nil {
		return "", err
	}
	valid := false
	defer func() {
		if !valid {
			_ = os.RemoveAll(temporary)
		}
	}()
	_, err = protocolartifact.WalkRepository(archive, repositoryID, version, func(entry protocolartifact.Entry) error {
		if entry.Directory || (keep != nil && !keep(entry.Path)) {
			return nil
		}
		destination := filepath.Join(temporary, filepath.FromSlash(entry.Path))
		relative, err := filepath.Rel(temporary, destination)
		if err != nil || relative == ".." || strings.HasPrefix(relative, ".."+string(filepath.Separator)) {
			return fmt.Errorf("Repository file escapes destination: %s", entry.Path)
		}
		if err := os.MkdirAll(filepath.Dir(destination), 0o755); err != nil {
			return err
		}
		mode := os.FileMode(0o644)
		if entry.Mode.Perm()&0o111 != 0 {
			mode = 0o755
		}
		return os.WriteFile(destination, entry.Contents, mode)
	})
	if err != nil {
		return "", err
	}
	valid = true
	return temporary, nil
}

func reconcilePreparedPath(temporary, target string) (preparedPath, error) {
	if _, err := os.Lstat(target); os.IsNotExist(err) {
		return preparedPath{temporary: temporary, target: target}, nil
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
	if actual != expected {
		return preparedPath{}, fmt.Errorf("existing path %s differs from deterministic content", target)
	}
	if err := os.RemoveAll(temporary); err != nil {
		return preparedPath{}, err
	}
	return preparedPath{target: target, existing: true}, nil
}

func validateMembers(values []string) (map[string]string, error) {
	if len(values) == 0 {
		return nil, fmt.Errorf("Repository membership must not be empty")
	}
	members := make(map[string]string, len(values))
	for _, value := range values {
		key := "."
		if value != "." {
			portable, err := protocolartifact.PortablePathKey(value)
			if err != nil {
				return nil, fmt.Errorf("invalid Repository member path %q", value)
			}
			key = portable
		}
		if _, exists := members[key]; exists {
			return nil, fmt.Errorf("duplicate Repository member path %q", value)
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
		return "", fmt.Errorf("Repository path %s is not a directory", root)
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
		if info.Mode()&os.ModeSymlink != 0 || (!info.Mode().IsRegular() && !info.IsDir()) {
			return "", fmt.Errorf("Repository path contains unsupported file %s", relative)
		}
		kind := "d"
		if info.Mode().IsRegular() {
			kind = "f"
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
		}
	}
	return hex.EncodeToString(hash.Sum(nil)), nil
}
