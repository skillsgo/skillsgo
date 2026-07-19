/*
 * [INPUT]: Depends on declaration-derived Installation records and live filesystem bindings.
 * [OUTPUT]: Provides declaration-derived Installation identity/state records plus safe exact-target removal with shared-binding, parent-alias, and Local Modification protection.
 * [POS]: Serves as the managed Installation record and filesystem-removal boundary used by declaration-driven mutations.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package install

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/skillsgo/skillsgo/cli/internal/store"
	"github.com/skillsgo/skillsgo/cli/internal/trash"
)

type Installation struct {
	Name          string           `json:"name"`
	SkillID       string           `json:"skillId"`
	DependencyID  string           `json:"-"`
	SourceRef     string           `json:"-"`
	Version       string           `json:"version"`
	StoreRoot     string           `json:"storeRoot"`
	Artifact      string           `json:"artifact"`
	Target        Target           `json:"target"`
	SHA256        string           `json:"-"`
	ContentDigest string           `json:"-"`
	TargetState   string           `json:"-"`
	Provenance    store.Provenance `json:"-"`
}

func RemoveDeclaredInstallations(selected, all []Installation) error {
	selectedTargets := map[string]bool{}
	for _, installation := range selected {
		selectedTargets[installation.Target.Agent+"\x00"+filepath.Clean(installation.Target.Path)] = true
	}
	removePass := func(canonicalPass bool) error {
		removedPaths := map[string]bool{}
		for _, installation := range selected {
			path := filepath.Clean(installation.Target.Path)
			isCanonical := false
			if installation.Target.CanonicalPath != "" {
				if info, err := os.Lstat(path); err == nil && info.Mode()&os.ModeSymlink == 0 {
					isCanonical = samePath(path, installation.Target.CanonicalPath)
				}
			}
			ownsPhysicalContent := installation.Target.Mode == ModeCopy || isCanonical
			if isCanonical != canonicalPass {
				continue
			}
			if removedPaths[path] {
				continue
			}
			usedByUnselected := false
			for _, candidate := range all {
				candidatePath := filepath.Clean(candidate.Target.Path)
				candidateKey := candidate.Target.Agent + "\x00" + candidatePath
				samePhysicalTarget := candidatePath == path
				if ownsPhysicalContent && candidate.Target.CanonicalPath != "" {
					samePhysicalTarget = samePhysicalTarget || samePath(candidate.Target.CanonicalPath, path)
				}
				if samePhysicalTarget && !selectedTargets[candidateKey] {
					usedByUnselected = true
					break
				}
			}
			if usedByUnselected {
				continue
			}
			if err := validateTargetRemoval(installation); err != nil {
				return err
			}
			if err := removeTargetSafely(installation); err != nil {
				return err
			}
			removedPaths[path] = true
		}
		return nil
	}
	if err := removePass(false); err != nil {
		return err
	}
	return removePass(true)
}

func validateTargetRemoval(installation Installation) error {
	info, err := os.Lstat(installation.Target.Path)
	if os.IsNotExist(err) {
		return nil
	}
	if err != nil {
		return err
	}
	if installation.Target.Mode == ModeSymlink {
		if installation.Target.CanonicalPath != "" && filepath.Clean(installation.Target.Path) == filepath.Clean(installation.Target.CanonicalPath) {
			if !info.IsDir() || info.Mode()&os.ModeSymlink != 0 {
				return fmt.Errorf("refusing to remove replaced canonical target %s", installation.Target.Path)
			}
			matches, err := CopyMatchesArtifact(installation.Target.Path, installation.Artifact)
			if err != nil || !matches {
				return fmt.Errorf("refusing to remove modified canonical target %s", installation.Target.Path)
			}
			return nil
		}
		if info.Mode()&os.ModeSymlink == 0 && installation.Target.CanonicalPath != "" && samePath(installation.Target.Path, installation.Target.CanonicalPath) {
			return nil
		}
		if info.Mode()&os.ModeSymlink == 0 {
			return fmt.Errorf("refusing to remove replaced target %s", installation.Target.Path)
		}
		link, err := os.Readlink(installation.Target.Path)
		if err != nil {
			return err
		}
		if !filepath.IsAbs(link) {
			link = filepath.Join(filepath.Dir(installation.Target.Path), link)
		}
		expected := installation.Artifact
		if installation.Target.CanonicalPath != "" {
			expected = installation.Target.CanonicalPath
		}
		if !samePath(link, expected) {
			return fmt.Errorf("refusing to remove redirected symlink %s", installation.Target.Path)
		}
		return nil
	}
	if !info.IsDir() {
		return fmt.Errorf("refusing to remove non-directory copy target %s", installation.Target.Path)
	}
	matches := false
	if installation.TargetState != "" {
		actual, err := DirectoryDigest(installation.Target.Path)
		if err != nil {
			return err
		}
		matches = actual == installation.TargetState
	} else {
		var err error
		matches, err = CopyMatchesArtifact(installation.Target.Path, installation.Artifact)
		if err != nil {
			return err
		}
	}
	if !matches {
		return fmt.Errorf("refusing to remove Local Modification at %s", installation.Target.Path)
	}
	return nil
}

func removeTargetSafely(installation Installation) error {
	if err := validateTargetRemoval(installation); err != nil {
		return err
	}
	info, err := os.Lstat(installation.Target.Path)
	if os.IsNotExist(err) {
		return nil
	}
	if err != nil {
		return err
	}
	if installation.Target.Mode == ModeSymlink {
		if installation.Target.CanonicalPath != "" && filepath.Clean(installation.Target.Path) == filepath.Clean(installation.Target.CanonicalPath) {
			return trash.Move(installation.Target.Path)
		}
		if info.Mode()&os.ModeSymlink == 0 && installation.Target.CanonicalPath != "" && samePath(installation.Target.Path, installation.Target.CanonicalPath) {
			return nil
		}
		return trash.Move(installation.Target.Path)
	}
	_ = info
	return trash.Move(installation.Target.Path)
}
