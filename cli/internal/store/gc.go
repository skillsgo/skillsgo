/*
 * [INPUT]: Depends on validated coordinate object references, CAS object modification times, explicit dry-run/apply intent, and a non-zero safety grace period.
 * [OUTPUT]: Provides fail-closed reference-aware scanning and bounded removal of orphaned Hub CAS objects while excluding Local and Captured entries.
 * [POS]: Serves as the safe lifecycle boundary for reclaiming unreachable Store object bytes without deleting coordinate metadata or live symlink targets.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package store

import (
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"time"
)

const MinimumGCGrace = time.Minute

type GCOptions struct {
	DryRun      bool
	GracePeriod time.Duration
	Now         time.Time
}

type GCItem struct {
	ObjectKey string    `json:"objectKey"`
	Bytes     int64     `json:"bytes"`
	Modified  time.Time `json:"modified"`
	Removed   bool      `json:"removed"`
}

type GCReport struct {
	DryRun         bool     `json:"dryRun"`
	Referenced     int      `json:"referenced"`
	ObjectsScanned int      `json:"objectsScanned"`
	Eligible       int      `json:"eligible"`
	EligibleBytes  int64    `json:"eligibleBytes"`
	Removed        int      `json:"removed"`
	ReclaimedBytes int64    `json:"reclaimedBytes"`
	Items          []GCItem `json:"items"`
}

// GC removes only CAS objects that have no valid coordinate reference and are
// older than the requested grace period. Coordinate metadata is never removed.
func (s Store) GC(options GCOptions) (GCReport, error) {
	if options.Now.IsZero() {
		options.Now = time.Now()
	}
	if options.GracePeriod < 0 {
		return GCReport{}, fmt.Errorf("Store GC grace period cannot be negative")
	}
	if !options.DryRun && options.GracePeriod < MinimumGCGrace {
		return GCReport{}, fmt.Errorf("Store GC apply requires a grace period of at least %s", MinimumGCGrace)
	}
	references, err := s.coordinateObjectReferences()
	if err != nil {
		return GCReport{}, err
	}
	objects, err := s.listObjects()
	if err != nil {
		return GCReport{}, err
	}
	report := GCReport{DryRun: options.DryRun, Referenced: len(references), ObjectsScanned: len(objects), Items: []GCItem{}}
	for _, object := range objects {
		if references[object.key] || options.Now.Sub(object.modified) < options.GracePeriod {
			continue
		}
		item := GCItem{ObjectKey: object.key, Bytes: object.bytes, Modified: object.modified}
		report.Eligible++
		report.EligibleBytes += object.bytes
		if !options.DryRun {
			unlock, lockErr := acquireEntryLock(object.root)
			if lockErr != nil {
				return GCReport{}, lockErr
			}
			freshReferences, referenceErr := s.coordinateObjectReferences()
			if referenceErr != nil {
				unlock()
				return GCReport{}, referenceErr
			}
			if !freshReferences[object.key] {
				if removeErr := os.RemoveAll(object.root); removeErr != nil {
					unlock()
					return GCReport{}, removeErr
				}
				item.Removed = true
				report.Removed++
				report.ReclaimedBytes += object.bytes
			}
			unlock()
			_ = os.Remove(object.root + ".lock")
		}
		report.Items = append(report.Items, item)
	}
	return report, nil
}

func (s Store) coordinateObjectReferences() (map[string]bool, error) {
	root, err := filepath.Abs(s.Root)
	if err != nil {
		return nil, err
	}
	references := map[string]bool{}
	if _, err := os.Stat(root); os.IsNotExist(err) {
		return references, nil
	} else if err != nil {
		return nil, err
	}
	err = filepath.WalkDir(root, func(current string, entry fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if entry.IsDir() && current == filepath.Join(root, objectDirectory) {
			return filepath.SkipDir
		}
		if entry.IsDir() || entry.Name() != objectReferenceFile {
			return nil
		}
		coordinateRoot := filepath.Dir(current)
		receipt, receiptErr := readReceipt(filepath.Join(coordinateRoot, "receipt.yaml"))
		if receiptErr != nil {
			return fmt.Errorf("invalid Store coordinate beside object reference %s: %w", current, receiptErr)
		}
		expectedRoot, rootErr := s.entryRoot(receipt.SkillID, receipt.Version)
		if rootErr != nil || filepath.Clean(expectedRoot) != filepath.Clean(coordinateRoot) {
			return fmt.Errorf("Store object reference is outside its coordinate root: %s", current)
		}
		reference, referenceErr := readObjectReference(current)
		if referenceErr != nil {
			return referenceErr
		}
		references[reference] = true
		return nil
	})
	return references, err
}

type storedObject struct {
	key      string
	root     string
	bytes    int64
	modified time.Time
}

func (s Store) listObjects() ([]storedObject, error) {
	root, err := filepath.Abs(s.Root)
	if err != nil {
		return nil, err
	}
	h1Root := filepath.Join(root, objectDirectory, "h1")
	sumDirectories, err := os.ReadDir(h1Root)
	if os.IsNotExist(err) {
		return []storedObject{}, nil
	}
	if err != nil {
		return nil, err
	}
	objects := make([]storedObject, 0)
	for _, sumDirectory := range sumDirectories {
		if !sumDirectory.IsDir() || !validHexDigest(sumDirectory.Name()) {
			continue
		}
		stateRoot := filepath.Join(h1Root, sumDirectory.Name())
		stateDirectories, readErr := os.ReadDir(stateRoot)
		if readErr != nil {
			return nil, readErr
		}
		for _, stateDirectory := range stateDirectories {
			if !stateDirectory.IsDir() || !validHexDigest(stateDirectory.Name()) {
				continue
			}
			objectRoot := filepath.Join(stateRoot, stateDirectory.Name())
			info, statErr := stateDirectory.Info()
			if statErr != nil {
				return nil, statErr
			}
			bytes, sizeErr := directorySize(objectRoot)
			if sizeErr != nil {
				return nil, sizeErr
			}
			objects = append(objects, storedObject{
				key:  filepath.ToSlash(filepath.Join("h1", sumDirectory.Name(), stateDirectory.Name())),
				root: objectRoot, bytes: bytes, modified: info.ModTime(),
			})
		}
	}
	sort.Slice(objects, func(i, j int) bool { return objects[i].key < objects[j].key })
	return objects, nil
}

func directorySize(root string) (int64, error) {
	var total int64
	err := filepath.WalkDir(root, func(_ string, entry fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if entry.IsDir() {
			return nil
		}
		info, err := entry.Info()
		if err != nil {
			return err
		}
		if !info.Mode().IsRegular() {
			return fmt.Errorf("Store object contains unsupported file %q", entry.Name())
		}
		if info.Size() > 0 && total > (1<<63-1)-info.Size() {
			return fmt.Errorf("Store object size overflow")
		}
		total += info.Size()
		return nil
	})
	return total, err
}
