/*
 * [INPUT]: Depends on canonical Skill/Repository IDs, immutable resource versions, verified bytes, and filesystem atomicity.
 * [OUTPUT]: Provides Go-shaped Workspace Sum parsing, h1 hashing and verification, historical-entry retention, and shared-transaction-locked deterministic updates.
 * [POS]: Serves as the integrity-only persistence boundary beside the editable Workspace Manifest.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package project

import (
	"bufio"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/skillsgo/skillsgo/cli/internal/source"
)

const (
	workspaceSumName     = "skillsgo.sum"
	workspaceSumLockName = ".skillsgo.sum.lock"
)

var (
	ErrChecksumMissing  = errors.New("Workspace Sum checksum is missing")
	ErrChecksumMismatch = errors.New("Workspace Sum checksum mismatch")
)

// SumEntry binds one immutable resource identity and version to a checksum.
// Repository Info uses a version suffix such as v1.2.3/repository.info.
type SumEntry struct {
	Path     string
	Version  string
	Checksum string
}

type WorkspaceSum struct {
	entries []SumEntry
}

func H1(data []byte) string {
	digest := sha256.Sum256(data)
	return "h1:" + base64.StdEncoding.EncodeToString(digest[:])
}

func ContentH1(contentDigest string) (string, error) {
	encoded, ok := strings.CutPrefix(contentDigest, "sha256:")
	if !ok {
		return "", fmt.Errorf("unsupported content digest %q", contentDigest)
	}
	digest, err := hex.DecodeString(encoded)
	if err != nil || len(digest) != sha256.Size {
		return "", fmt.Errorf("invalid SHA-256 content digest %q", contentDigest)
	}
	return "h1:" + base64.StdEncoding.EncodeToString(digest), nil
}

func LoadWorkspaceSum(root string) (WorkspaceSum, error) {
	return loadWorkspaceSumFile(filepath.Join(root, workspaceSumName))
}

func loadWorkspaceSumFile(path string) (WorkspaceSum, error) {
	file, err := os.Open(path)
	if os.IsNotExist(err) {
		return WorkspaceSum{entries: []SumEntry{}}, nil
	}
	if err != nil {
		return WorkspaceSum{}, err
	}
	defer file.Close()

	result := WorkspaceSum{entries: []SumEntry{}}
	scanner := bufio.NewScanner(file)
	lineNumber := 0
	for scanner.Scan() {
		lineNumber++
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		fields := strings.Fields(line)
		if len(fields) != 3 {
			return WorkspaceSum{}, fmt.Errorf("parse %s line %d: expected exactly three fields", path, lineNumber)
		}
		entry := SumEntry{Path: fields[0], Version: fields[1], Checksum: fields[2]}
		if err := validateSumEntry(entry); err != nil {
			return WorkspaceSum{}, fmt.Errorf("parse %s line %d: %w", path, lineNumber, err)
		}
		if err := result.add(entry); err != nil {
			return WorkspaceSum{}, fmt.Errorf("parse %s line %d: %w", path, lineNumber, err)
		}
	}
	if err := scanner.Err(); err != nil {
		return WorkspaceSum{}, err
	}
	return result, nil
}

func (sum WorkspaceSum) Verify(expected SumEntry) error {
	if err := validateSumEntry(expected); err != nil {
		return err
	}
	algorithm := checksumAlgorithm(expected.Checksum)
	for _, entry := range sum.entries {
		if entry.Path != expected.Path || entry.Version != expected.Version || checksumAlgorithm(entry.Checksum) != algorithm {
			continue
		}
		if entry.Checksum != expected.Checksum {
			return fmt.Errorf("%w for %s %s: have %s, verified %s", ErrChecksumMismatch, expected.Path, expected.Version, entry.Checksum, expected.Checksum)
		}
		return nil
	}
	return fmt.Errorf("%w for %s %s", ErrChecksumMissing, expected.Path, expected.Version)
}

func MergeVerifiedSums(root string, verified []SumEntry) error {
	return withInstallationMetadataLock(root, func() error {
		return mergeVerifiedSumsUnlocked(root, verified)
	})
}

func mergeVerifiedSumsUnlocked(root string, verified []SumEntry) error {
	if len(verified) == 0 {
		return nil
	}
	for _, entry := range verified {
		if err := validateSumEntry(entry); err != nil {
			return err
		}
	}
	if err := os.MkdirAll(root, 0o700); err != nil {
		return err
	}
	unlock, err := acquireFileLock(filepath.Join(root, workspaceSumLockName))
	if err != nil {
		return err
	}
	defer unlock()

	sumPath := filepath.Join(root, workspaceSumName)
	sum, err := loadWorkspaceSumFile(sumPath)
	if err != nil {
		return err
	}
	for _, entry := range verified {
		if err := sum.add(entry); err != nil {
			return err
		}
	}
	sort.Slice(sum.entries, func(i, j int) bool {
		left, right := sum.entries[i], sum.entries[j]
		if left.Path != right.Path {
			return left.Path < right.Path
		}
		if left.Version != right.Version {
			return left.Version < right.Version
		}
		return left.Checksum < right.Checksum
	})
	var contents strings.Builder
	for _, entry := range sum.entries {
		fmt.Fprintf(&contents, "%s %s %s\n", entry.Path, entry.Version, entry.Checksum)
	}
	return writeWorkspaceSumAtomic(sumPath, []byte(contents.String()))
}

func ValidateVerifiedSums(root string, verified []SumEntry) error {
	sum, err := LoadWorkspaceSum(root)
	if err != nil {
		return err
	}
	for _, entry := range verified {
		err := sum.Verify(entry)
		if errors.Is(err, ErrChecksumMissing) {
			continue
		}
		if err != nil {
			return err
		}
	}
	return nil
}

func (sum *WorkspaceSum) add(entry SumEntry) error {
	algorithm := checksumAlgorithm(entry.Checksum)
	for _, existing := range sum.entries {
		if existing.Path != entry.Path || existing.Version != entry.Version || checksumAlgorithm(existing.Checksum) != algorithm {
			continue
		}
		if existing.Checksum != entry.Checksum {
			return fmt.Errorf("%w for %s %s: have %s, verified %s", ErrChecksumMismatch, entry.Path, entry.Version, existing.Checksum, entry.Checksum)
		}
		return nil
	}
	sum.entries = append(sum.entries, entry)
	return nil
}

func validateSumEntry(entry SumEntry) error {
	if err := source.ValidateSkillID(entry.Path); err != nil {
		return fmt.Errorf("invalid Workspace Sum resource path: %w", err)
	}
	version := entry.Version
	if strings.HasSuffix(version, "/repository.info") {
		version = strings.TrimSuffix(version, "/repository.info")
	}
	if err := source.ValidateVersion(version); err != nil {
		return fmt.Errorf("invalid Workspace Sum version: %w", err)
	}
	separator := strings.IndexByte(entry.Checksum, ':')
	if separator <= 0 || separator == len(entry.Checksum)-1 {
		return fmt.Errorf("invalid Workspace Sum checksum %q", entry.Checksum)
	}
	if entry.Checksum[:separator] != "h1" {
		return fmt.Errorf("unsupported Workspace Sum checksum algorithm %q", entry.Checksum[:separator])
	}
	if _, err := base64.StdEncoding.DecodeString(entry.Checksum[separator+1:]); err != nil {
		return fmt.Errorf("invalid Workspace Sum checksum %q", entry.Checksum)
	}
	return nil
}

func checksumAlgorithm(checksum string) string {
	algorithm, _, _ := strings.Cut(checksum, ":")
	return algorithm
}

func writeWorkspaceSumAtomic(path string, data []byte) error {
	temporary, err := os.CreateTemp(filepath.Dir(path), ".skillsgo-sum-")
	if err != nil {
		return err
	}
	temporaryPath := temporary.Name()
	defer os.Remove(temporaryPath)
	if err := temporary.Chmod(0o600); err != nil {
		_ = temporary.Close()
		return err
	}
	if _, err := temporary.Write(data); err != nil {
		_ = temporary.Close()
		return err
	}
	if err := temporary.Sync(); err != nil {
		_ = temporary.Close()
		return err
	}
	if err := temporary.Close(); err != nil {
		return err
	}
	return os.Rename(temporaryPath, path)
}
