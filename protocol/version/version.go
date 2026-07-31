/*
 * [INPUT]: Depends on canonical Go semantic versions and pseudo-version recognition.
 * [OUTPUT]: Provides immutable-version recognition, stable/prerelease/pseudo priority comparison and ordering, and stable-first selection of the highest canonical published semantic version.
 * [POS]: Serves as the shared immutable-version selection rule used by protocol producers and compatibility consumers.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package version

import (
	"sort"

	"golang.org/x/mod/module"
	"golang.org/x/mod/semver"
)

func IsImmutable(version string) bool {
	return semver.IsValid(version) && semver.Canonical(version) == version
}

// HasHigherPriority reports whether candidate should replace current as the
// default Package Version. Stable Tags outrank prerelease Tags, which outrank
// pseudo-versions; versions within one class use canonical semantic ordering.
func HasHigherPriority(candidate, current string) bool {
	if !IsImmutable(candidate) {
		return false
	}
	if !IsImmutable(current) {
		return true
	}
	return comparePriority(candidate, current) > 0
}

// HighestPriority returns the stable-first highest canonical immutable Version.
func HighestPriority(versions []string) string {
	highest := ""
	for _, candidate := range versions {
		if HasHigherPriority(candidate, highest) {
			highest = candidate
		}
	}
	return highest
}

// OrderedImmutableVersions returns the unique canonical immutable versions in
// stable, prerelease, then pseudo-version order, newest first within each class.
func OrderedImmutableVersions(versions []string) []string {
	ordered := make([]string, 0, len(versions))
	seen := make(map[string]struct{}, len(versions))
	for _, candidate := range versions {
		if !IsImmutable(candidate) {
			continue
		}
		if _, exists := seen[candidate]; exists {
			continue
		}
		seen[candidate] = struct{}{}
		ordered = append(ordered, candidate)
	}
	sort.Slice(ordered, func(i, j int) bool {
		return comparePriority(ordered[i], ordered[j]) > 0
	})
	return ordered
}

func comparePriority(left, right string) int {
	leftKind := immutableVersionKind(left)
	rightKind := immutableVersionKind(right)
	if leftKind < rightKind {
		return 1
	}
	if leftKind > rightKind {
		return -1
	}
	return semver.Compare(left, right)
}

func immutableVersionKind(version string) int {
	if module.IsPseudoVersion(version) {
		return 2
	}
	if semver.Prerelease(version) != "" {
		return 1
	}
	return 0
}

func LatestPublished(versions []string) string {
	return latest(versions, false)
}

func LatestCanonicalPublished(versions []string) string {
	return latest(versions, true)
}

func latest(versions []string, canonicalOnly bool) string {
	stable, prerelease := "", ""
	for _, candidate := range versions {
		if !semver.IsValid(candidate) || module.IsPseudoVersion(candidate) || (canonicalOnly && semver.Canonical(candidate) != candidate) {
			continue
		}
		if semver.Prerelease(candidate) == "" {
			if stable == "" || semver.Compare(candidate, stable) > 0 {
				stable = candidate
			}
		} else if prerelease == "" || semver.Compare(candidate, prerelease) > 0 {
			prerelease = candidate
		}
	}
	if stable != "" {
		return stable
	}
	return prerelease
}
