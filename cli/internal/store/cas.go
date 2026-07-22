/*
 * [INPUT]: Depends on verified h1 content sums, extracted artifact trees, envelope modes/directories, and confined Store roots.
 * [OUTPUT]: Provides cross-coordinate Hub object keys, atomic read-only object publication, bounded reference resolution, and envelope-state hashing.
 * [POS]: Serves as the true content-addressed object layer beneath coordinate metadata in the Store module.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package store

import (
	"crypto/sha256"
	"encoding/base64"
	"encoding/binary"
	"encoding/hex"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path"
	"path/filepath"
	"strings"

	"github.com/skillsgo/skillsgo/cli/internal/hub"
)

const (
	objectDirectory      = ".objects"
	objectReferenceFile  = "object"
	maxObjectReference   = 256
	storeObjectDigestTag = "skillsgo-store-object-v1\x00"
)

func (s Store) publishHubObject(extractedRoot, sum string) (artifactRoot, objectKey string, err error) {
	if err := makeArtifactReadOnly(extractedRoot); err != nil {
		return "", "", err
	}
	stateDigest, err := directoryEnvelopeDigest(extractedRoot, storeObjectDigestTag)
	if err != nil {
		return "", "", err
	}
	objectKey, err = objectKeyFor(sum, stateDigest)
	if err != nil {
		return "", "", err
	}
	artifactRoot, err = s.objectRoot(objectKey)
	if err != nil {
		return "", "", err
	}
	if err := os.MkdirAll(filepath.Dir(artifactRoot), 0o700); err != nil {
		return "", "", err
	}
	unlock, err := acquireEntryLock(artifactRoot)
	if err != nil {
		return "", "", err
	}
	defer unlock()

	if info, statErr := os.Stat(artifactRoot); statErr == nil {
		if !info.IsDir() {
			return "", "", fmt.Errorf("Store object %q is not a directory", objectKey)
		}
		if err := verifyObject(artifactRoot, sum, stateDigest); err != nil {
			return "", "", err
		}
		return artifactRoot, objectKey, nil
	} else if !os.IsNotExist(statErr) {
		return "", "", statErr
	}
	if err := os.Rename(extractedRoot, artifactRoot); err != nil {
		return "", "", err
	}
	return artifactRoot, objectKey, nil
}

func verifyObject(root, sum, stateDigest string) error {
	if err := hub.VerifyDirectorySum(root, sum); err != nil {
		return fmt.Errorf("Store object content verification failed: %w", err)
	}
	actualState, err := directoryEnvelopeDigest(root, storeObjectDigestTag)
	if err != nil {
		return err
	}
	if actualState != stateDigest {
		return fmt.Errorf("Store object envelope digest changed: %s != %s", actualState, stateDigest)
	}
	return nil
}

func objectKeyFor(sum, stateDigest string) (string, error) {
	if !hub.ValidSum(sum) {
		return "", fmt.Errorf("invalid Store object Sum %q", sum)
	}
	digest, err := base64.StdEncoding.DecodeString(strings.TrimPrefix(sum, "h1:"))
	if err != nil || len(digest) != sha256.Size {
		return "", fmt.Errorf("invalid Store object Sum %q", sum)
	}
	if !validHexDigest(stateDigest) {
		return "", fmt.Errorf("invalid Store object envelope digest %q", stateDigest)
	}
	return path.Join("h1", hex.EncodeToString(digest), stateDigest), nil
}

func (s Store) referencedArtifactRoot(entryRoot string) (string, error) {
	reference, err := readObjectReference(filepath.Join(entryRoot, objectReferenceFile))
	if os.IsNotExist(err) {
		return filepath.Join(entryRoot, "artifact"), nil
	}
	if err != nil {
		return "", err
	}
	return s.objectRoot(reference)
}

func readObjectReference(referencePath string) (string, error) {
	file, err := os.Open(referencePath)
	if err != nil {
		return "", err
	}
	defer file.Close()
	data, err := io.ReadAll(io.LimitReader(file, maxObjectReference+1))
	if err != nil {
		return "", err
	}
	if len(data) == 0 || len(data) > maxObjectReference {
		return "", fmt.Errorf("invalid Store object reference size")
	}
	reference := strings.TrimSpace(string(data))
	parts := strings.Split(reference, "/")
	if len(parts) != 3 || parts[0] != "h1" || !validHexDigest(parts[1]) || !validHexDigest(parts[2]) {
		return "", fmt.Errorf("invalid Store object reference %q", reference)
	}
	return reference, nil
}

func validHexDigest(value string) bool {
	if len(value) != sha256.Size*2 || strings.ToLower(value) != value {
		return false
	}
	decoded, err := hex.DecodeString(value)
	return err == nil && len(decoded) == sha256.Size
}

func (s Store) objectRoot(objectKey string) (string, error) {
	root, err := filepath.Abs(s.Root)
	if err != nil {
		return "", err
	}
	objectsRoot := filepath.Join(root, objectDirectory)
	candidate := filepath.Join(objectsRoot, filepath.FromSlash(objectKey))
	relative, err := filepath.Rel(objectsRoot, candidate)
	if err != nil || relative == ".." || strings.HasPrefix(relative, ".."+string(filepath.Separator)) {
		return "", fmt.Errorf("Store object escapes configured root")
	}
	return candidate, nil
}

func directoryEnvelopeDigest(root, domain string) (string, error) {
	hash := sha256.New()
	_, _ = hash.Write([]byte(domain))
	err := filepath.WalkDir(root, func(current string, entry fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if current == root {
			return nil
		}
		relative, err := filepath.Rel(root, current)
		if err != nil {
			return err
		}
		info, err := entry.Info()
		if err != nil {
			return err
		}
		kind := byte('f')
		if entry.IsDir() {
			kind = 'd'
		} else if !info.Mode().IsRegular() {
			return fmt.Errorf("artifact contains unsupported file %q", current)
		}
		relative = filepath.ToSlash(relative)
		_, _ = hash.Write([]byte{kind})
		if err := binary.Write(hash, binary.BigEndian, uint64(len(relative))); err != nil {
			return err
		}
		_, _ = io.WriteString(hash, relative)
		if err := binary.Write(hash, binary.BigEndian, uint32(info.Mode().Perm())); err != nil {
			return err
		}
		if entry.IsDir() {
			return nil
		}
		if err := binary.Write(hash, binary.BigEndian, uint64(info.Size())); err != nil {
			return err
		}
		file, err := os.Open(current)
		if err != nil {
			return err
		}
		_, copyErr := io.Copy(hash, file)
		closeErr := file.Close()
		if copyErr != nil {
			return copyErr
		}
		return closeErr
	})
	if err != nil {
		return "", err
	}
	return hex.EncodeToString(hash.Sum(nil)), nil
}
