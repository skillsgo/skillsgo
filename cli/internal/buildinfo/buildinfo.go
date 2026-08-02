/*
 * [INPUT]: Depends on Go linker -X values supplied by repository and downstream distribution builds.
 * [OUTPUT]: Provides normalized CLI product, bundle, distribution, source, and build-time identity.
 * [POS]: Serves as the single build metadata boundary shared by commands and release automation.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package buildinfo

import "strings"

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
	return Info{
		Version:       normalized(version, "dev"),
		BundleVersion: strings.TrimSpace(bundleVersion),
		Distribution:  normalized(distribution, "unknown"),
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
