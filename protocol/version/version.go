/*
 * [INPUT]: Depends on canonical Go semantic versions and pseudo-version recognition.
 * [OUTPUT]: Provides immutable-version recognition and stable-first selection of the highest canonical published semantic version.
 * [POS]: Serves as the shared immutable-version selection rule used by protocol producers and compatibility consumers.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package version

import (
	"golang.org/x/mod/module"
	"golang.org/x/mod/semver"
)

func IsImmutable(version string) bool {
	return semver.IsValid(version) && semver.Canonical(version) == version
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
