/*
 * [INPUT]: Depends on Go linker -X values supplied by repository and downstream distribution builds.
 * [OUTPUT]: Provides normalized CLI product, bundle, distribution, source, and build-time identity.
 * [POS]: Serves as the single build metadata boundary shared by commands and release automation.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package buildinfo

import (
	"runtime/debug"
	"strings"

	"golang.org/x/mod/semver"
)

var (
	version       = "dev"
	bundleVersion = ""
	distribution  = "unknown"
	commit        = "unknown"
	buildDate     = "unknown"
)

type Info struct {
	Version       string
	BundleVersion string
	Distribution  string
	Commit        string
	BuildDate     string
}

func Current() Info {
	moduleVersion := ""
	if details, ok := debug.ReadBuildInfo(); ok {
		moduleVersion = details.Main.Version
	}
	return current(moduleVersion)
}

func current(moduleVersion string) Info {
	resolvedVersion := normalized(version, "dev")
	resolvedDistribution := normalized(distribution, "unknown")
	if resolvedVersion == "dev" && semver.IsValid(moduleVersion) {
		resolvedVersion = moduleVersion
		if resolvedDistribution == "unknown" {
			resolvedDistribution = "go-install"
		}
	}
	return Info{
		Version:       resolvedVersion,
		BundleVersion: strings.TrimSpace(bundleVersion),
		Distribution:  resolvedDistribution,
		Commit:        normalized(commit, "unknown"),
		BuildDate:     normalized(buildDate, "unknown"),
	}
}

func normalized(value, fallback string) string {
	value = strings.TrimSpace(value)
	if value == "" {
		return fallback
	}
	return value
}
