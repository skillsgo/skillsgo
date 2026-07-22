/*
 * [INPUT]: Depends on verified immutable Sum entries, exact Info bytes, declaration roots, the Workspace Sum boundary, and the user Info Cache.
 * [OUTPUT]: Provides one validate-first persistence operation shared by installation entry points for complete Workspace integrity evidence.
 * [POS]: Serves as the command-layer transaction boundary between Hub resource acquisition and local installation mutation.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"fmt"
	"path/filepath"

	"github.com/skillsgo/skillsgo/cli/internal/infocache"
	"github.com/skillsgo/skillsgo/cli/internal/project"
)

type verifiedInfoResource struct {
	resource string
	version  string
	kind     string
	bytes    []byte
}

type verifiedWorkspaceResources struct {
	sums  []project.SumEntry
	infos []verifiedInfoResource
}

func (resources verifiedWorkspaceResources) persist(home string, declarationRoots []string) error {
	if len(resources.sums) == 0 {
		return nil
	}
	roots := make([]string, 0, len(declarationRoots))
	seenRoots := map[string]bool{}
	for _, root := range declarationRoots {
		root = filepath.Clean(root)
		if root == "." || seenRoots[root] {
			continue
		}
		seenRoots[root] = true
		roots = append(roots, root)
	}
	if len(roots) == 0 {
		return fmt.Errorf("verified Workspace resources require a declaration root")
	}
	for _, root := range roots {
		if err := resources.validate(root); err != nil {
			return err
		}
	}
	if err := resources.cacheInfos(home); err != nil {
		return err
	}
	for _, root := range roots {
		if err := project.MergeVerifiedSums(root, resources.sums); err != nil {
			return err
		}
	}
	return nil
}

func (resources verifiedWorkspaceResources) validate(root string) error {
	return project.ValidateVerifiedSums(root, resources.sums)
}

func (resources verifiedWorkspaceResources) cacheInfos(home string) error {
	cache := infocache.Cache{Root: infocache.DefaultRoot(home)}
	seenInfos := map[string]bool{}
	for _, info := range resources.infos {
		key := info.resource + "\x00" + info.version + "\x00" + info.kind
		if seenInfos[key] {
			continue
		}
		seenInfos[key] = true
		if err := cache.Put(info.resource, info.version, info.kind, info.bytes); err != nil {
			return err
		}
	}
	return nil
}
