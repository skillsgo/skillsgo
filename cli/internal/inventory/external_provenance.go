/*
 * [INPUT]: Depends on External inventory targets, bounded skills.sh and ClawHub JSON records, Skill-root Git origin configuration, and canonical source parsing.
 * [OUTPUT]: Provides offline External source resolutions with confirmed, import-only, conflict, or unknown status plus deterministic evidence records.
 * [POS]: Serves as the read-only local provenance composition pass after External discovery and before App-facing inventory serialization.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package inventory

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/url"
	"os"
	"path/filepath"
	"sort"
	"strings"

	gitconfig "github.com/go-git/go-git/v6/config"
	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/source"
)

const (
	externalLockReadLimit   = 1 << 20
	externalOriginReadLimit = 64 << 10
	externalGitReadLimit    = 256 << 10
)

type ExternalSourceStatus string
type ExternalSourceConfidence string
type ExternalSourceEvidenceKind string

const (
	ExternalSourceConfirmed  ExternalSourceStatus = "confirmed"
	ExternalSourceImportOnly ExternalSourceStatus = "import-only"
	ExternalSourceConflict   ExternalSourceStatus = "conflict"
	ExternalSourceUnknown    ExternalSourceStatus = "unknown"

	ExternalSourceConfidenceHigh   ExternalSourceConfidence = "high"
	ExternalSourceConfidenceMedium ExternalSourceConfidence = "medium"
	ExternalSourceConfidenceNone   ExternalSourceConfidence = "none"

	ExternalEvidenceSkillsShLock  ExternalSourceEvidenceKind = "skills-sh-lock"
	ExternalEvidenceClawHubOrigin ExternalSourceEvidenceKind = "clawhub-origin"
	ExternalEvidenceGitOrigin     ExternalSourceEvidenceKind = "git-origin"
)

type ExternalSourceResolution struct {
	Status     ExternalSourceStatus     `json:"status"`
	Confidence ExternalSourceConfidence `json:"confidence"`
	Coordinate string                   `json:"coordinate,omitempty"`
	URL        string                   `json:"url,omitempty"`
	Channel    string                   `json:"channel,omitempty"`
	Reference  string                   `json:"reference,omitempty"`
	Evidence   []ExternalSourceEvidence `json:"evidence"`
}

type ExternalSourceEvidence struct {
	Kind       ExternalSourceEvidenceKind `json:"kind"`
	Confidence ExternalSourceConfidence   `json:"confidence"`
	Location   string                     `json:"location"`
	Coordinate string                     `json:"coordinate,omitempty"`
	URL        string                     `json:"url,omitempty"`
	Channel    string                     `json:"channel,omitempty"`
	Reference  string                     `json:"reference,omitempty"`
}

type externalSourceResolver struct {
	home  string
	locks map[string]externalSkillLock
}

type externalSkillLock struct {
	Version int                                `json:"version"`
	Skills  map[string]externalSkillLockRecord `json:"skills"`
}

type externalSkillLockRecord struct {
	Source     string `json:"source"`
	SourceType string `json:"sourceType"`
	SourceURL  string `json:"sourceUrl"`
}

type clawHubOrigin struct {
	Version          int    `json:"version"`
	Registry         string `json:"registry"`
	Slug             string `json:"slug"`
	InstalledVersion string `json:"installedVersion"`
	SourceRepository string `json:"sourceRepository"`
	SourceURL        string `json:"sourceUrl"`
	Origin           string `json:"origin"`
}

func addExternalSourceEvidence(entries map[string]*Entry, home string) {
	resolver := externalSourceResolver{home: home, locks: map[string]externalSkillLock{}}
	for _, entry := range entries {
		if entry.Provenance != ProvenanceExternal {
			continue
		}
		evidence := make([]ExternalSourceEvidence, 0)
		seenTargets := map[string]bool{}
		for _, target := range entry.Targets {
			resolved := resolveInventoryPath(target.Path)
			if seenTargets[resolved] {
				continue
			}
			seenTargets[resolved] = true
			if item, ok := resolver.skillsShEvidence(*entry, target); ok {
				evidence = append(evidence, item)
			}
			if item, ok := clawHubEvidence(resolved); ok {
				evidence = append(evidence, item)
			}
			evidence = append(evidence, gitOriginEvidence(resolved)...)
		}
		entry.ExternalSource = resolveExternalSource(evidence)
	}
}

func (resolver *externalSourceResolver) skillsShEvidence(entry Entry, target Target) (ExternalSourceEvidence, bool) {
	lockRoot, lockPath, location, minimumVersion := resolver.skillsShLockPath(target)
	if lockRoot == "" || lockPath == "" {
		return ExternalSourceEvidence{}, false
	}
	lockKey := lockRoot + "\x00" + lockPath
	lock, ok := resolver.locks[lockKey]
	if !ok {
		lock = readExternalSkillLock(lockRoot, lockPath, minimumVersion)
		resolver.locks[lockKey] = lock
	}
	record, ok := lock.Skills[entry.Name]
	if !ok {
		record, ok = lock.Skills[filepath.Base(target.Path)]
	}
	reference := safeExternalReference(record.SourceType)
	if !ok || reference == "" {
		return ExternalSourceEvidence{}, false
	}
	evidence := ExternalSourceEvidence{
		Kind: ExternalEvidenceSkillsShLock, Confidence: ExternalSourceConfidenceHigh,
		Location: location, Channel: "skills.sh", Reference: reference,
	}
	candidates := []string{}
	switch evidence.Reference {
	case "github":
		candidates = []string{record.SourceURL, record.Source}
	case "git", "gitlab":
		candidates = []string{record.SourceURL}
	}
	for _, raw := range candidates {
		if coordinate, sourceURL, ok := canonicalRepository(raw); ok {
			evidence.Coordinate = coordinate
			evidence.URL = sourceURL
			break
		}
	}
	return evidence, true
}

func (resolver *externalSourceResolver) skillsShLockPath(target Target) (string, string, string, int) {
	if target.Scope == install.ScopeProject {
		if target.ProjectRoot == "" {
			return "", "", "", 0
		}
		return target.ProjectRoot, "skills-lock.json", "skills-lock.json", 1
	}
	if stateHome := strings.TrimSpace(os.Getenv("XDG_STATE_HOME")); stateHome != "" {
		return stateHome, filepath.FromSlash("skills/.skill-lock.json"), "$XDG_STATE_HOME/skills/.skill-lock.json", 3
	}
	return resolver.home, filepath.FromSlash(".agents/.skill-lock.json"), ".agents/.skill-lock.json", 3
}

func readExternalSkillLock(root, path string, minimumVersion int) externalSkillLock {
	var lock externalSkillLock
	if readBoundedRootJSON(root, path, externalLockReadLimit, &lock) != nil || lock.Version < minimumVersion || lock.Skills == nil {
		return externalSkillLock{Skills: map[string]externalSkillLockRecord{}}
	}
	return lock
}

func clawHubEvidence(root string) (ExternalSourceEvidence, bool) {
	for _, relative := range []string{".clawhub/origin.json", ".clawdhub/origin.json"} {
		var origin clawHubOrigin
		if readBoundedRootJSON(root, filepath.FromSlash(relative), externalOriginReadLimit, &origin) != nil {
			continue
		}
		evidence := ExternalSourceEvidence{
			Kind: ExternalEvidenceClawHubOrigin, Confidence: ExternalSourceConfidenceHigh,
			Location: relative, Channel: "clawhub", Reference: safeExternalReference(origin.Slug),
		}
		if registry, ok := canonicalRegistryURL(origin.Registry); ok {
			evidence.URL = registry
		}
		for _, raw := range []string{origin.SourceURL, origin.Origin, origin.SourceRepository} {
			if coordinate, sourceURL, ok := canonicalRepository(raw); ok {
				evidence.Coordinate = coordinate
				evidence.URL = sourceURL
				break
			}
		}
		if evidence.Coordinate != "" || (origin.Version == 1 && origin.InstalledVersion != "" && evidence.URL != "" && evidence.Reference != "") {
			return evidence, true
		}
	}
	return ExternalSourceEvidence{}, false
}

func gitOriginEvidence(root string) []ExternalSourceEvidence {
	rootFS, err := os.OpenRoot(root)
	if err != nil {
		return nil
	}
	defer rootFS.Close()
	file, err := rootFS.Open(filepath.FromSlash(".git/config"))
	if err != nil {
		return nil
	}
	defer file.Close()
	info, err := file.Stat()
	if err != nil || info.Size() > externalGitReadLimit {
		return nil
	}
	configuration, err := gitconfig.ReadConfig(io.LimitReader(file, externalGitReadLimit+1))
	if err != nil {
		return nil
	}
	remote := configuration.Remotes["origin"]
	if remote == nil {
		return nil
	}
	result := make([]ExternalSourceEvidence, 0, len(remote.URLs))
	for _, raw := range remote.URLs {
		coordinate, sourceURL, ok := canonicalRepository(raw)
		if !ok {
			continue
		}
		result = append(result, ExternalSourceEvidence{
			Kind: ExternalEvidenceGitOrigin, Confidence: ExternalSourceConfidenceMedium,
			Location: ".git/config", Coordinate: coordinate, URL: sourceURL,
		})
	}
	return result
}

func canonicalRepository(raw string) (string, string, bool) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return "", "", false
	}
	if filepath.IsAbs(raw) ||
		strings.HasPrefix(raw, "./") ||
		strings.HasPrefix(raw, "../") ||
		strings.HasPrefix(raw, "~/") ||
		strings.Contains(raw, `\`) ||
		(len(raw) >= 3 && raw[1] == ':' && (raw[2] == '/' || raw[2] == '\\')) {
		return "", "", false
	}
	if strings.Contains(raw, "://") {
		parsed, err := url.Parse(raw)
		if err != nil || parsed.Host == "" || parsed.RawQuery != "" || parsed.Fragment != "" {
			return "", "", false
		}
		parsed.User = nil
		switch strings.ToLower(parsed.Scheme) {
		case "http", "https", "git", "ssh":
			raw = strings.ToLower(parsed.Host) + "/" + strings.TrimPrefix(parsed.Path, "/")
		default:
			return "", "", false
		}
	} else if colon := strings.Index(raw, ":"); colon > 0 && strings.Contains(raw[:colon], "@") {
		authority := raw[:colon]
		host := authority[strings.LastIndex(authority, "@")+1:]
		raw = host + "/" + strings.TrimPrefix(raw[colon+1:], "/")
	}
	reference, err := source.Parse(raw)
	if err != nil {
		return "", "", false
	}
	return reference.PackagePath, "https://" + reference.PackagePath, true
}

func canonicalRegistryURL(raw string) (string, bool) {
	parsed, err := url.Parse(strings.TrimSpace(raw))
	if err != nil || (parsed.Scheme != "https" && parsed.Scheme != "http") || parsed.Host == "" || parsed.User != nil || parsed.RawQuery != "" || parsed.Fragment != "" {
		return "", false
	}
	parsed.Path = strings.TrimRight(parsed.Path, "/")
	return parsed.String(), true
}

func safeExternalReference(raw string) string {
	value := strings.ToLower(strings.TrimSpace(raw))
	if value == "" || len(value) > 128 {
		return ""
	}
	for _, character := range value {
		if (character >= 'a' && character <= 'z') ||
			(character >= '0' && character <= '9') ||
			character == '.' || character == '-' || character == '_' {
			continue
		}
		return ""
	}
	return value
}

func resolveExternalSource(raw []ExternalSourceEvidence) *ExternalSourceResolution {
	evidence := deduplicateExternalEvidence(raw)
	resolution := &ExternalSourceResolution{
		Status: ExternalSourceUnknown, Confidence: ExternalSourceConfidenceNone,
		Evidence: evidence,
	}
	coordinates := map[string]string{}
	imports := map[string]ExternalSourceEvidence{}
	for _, item := range evidence {
		if item.Coordinate != "" {
			coordinates[item.Coordinate] = item.URL
		}
		if item.Channel != "" {
			imports[item.Channel+"\x00"+item.Reference] = item
		}
	}
	if len(coordinates) > 1 || (len(coordinates) == 0 && len(imports) > 1) {
		resolution.Status = ExternalSourceConflict
		return resolution
	}
	if len(coordinates) == 1 {
		resolution.Status = ExternalSourceConfirmed
		resolution.Confidence = ExternalSourceConfidenceMedium
		for coordinate, sourceURL := range coordinates {
			resolution.Coordinate = coordinate
			resolution.URL = sourceURL
		}
		for _, item := range evidence {
			if item.Coordinate == resolution.Coordinate && item.Confidence == ExternalSourceConfidenceHigh {
				resolution.Confidence = ExternalSourceConfidenceHigh
			}
		}
		return resolution
	}
	if len(imports) == 1 {
		resolution.Status = ExternalSourceImportOnly
		for _, item := range imports {
			resolution.Confidence = item.Confidence
			resolution.URL = item.URL
			resolution.Channel = item.Channel
			resolution.Reference = item.Reference
		}
	}
	return resolution
}

func deduplicateExternalEvidence(values []ExternalSourceEvidence) []ExternalSourceEvidence {
	seen := map[string]bool{}
	result := make([]ExternalSourceEvidence, 0, len(values))
	for _, value := range values {
		key := externalEvidenceKey(value)
		if seen[key] {
			continue
		}
		seen[key] = true
		result = append(result, value)
	}
	sort.Slice(result, func(i, j int) bool {
		return externalEvidenceKey(result[i]) < externalEvidenceKey(result[j])
	})
	return result
}

func externalEvidenceKey(value ExternalSourceEvidence) string {
	return fmt.Sprintf("%s\x00%s\x00%s\x00%s\x00%s\x00%s\x00%s", value.Kind, value.Confidence, value.Location, value.Coordinate, value.URL, value.Channel, value.Reference)
}

func readBoundedRootJSON(root, path string, limit int64, target any) error {
	rootFS, err := os.OpenRoot(root)
	if err != nil {
		return err
	}
	defer rootFS.Close()
	file, err := rootFS.Open(path)
	if err != nil {
		return err
	}
	defer file.Close()
	info, err := file.Stat()
	if err != nil {
		return err
	}
	if info.Size() > limit {
		return fmt.Errorf("local source record exceeds %d bytes", limit)
	}
	return decodeBoundedJSON(file, limit, target)
}

func decodeBoundedJSON(reader io.Reader, limit int64, target any) error {
	decoder := json.NewDecoder(io.LimitReader(reader, limit+1))
	if err := decoder.Decode(target); err != nil {
		return err
	}
	var trailing any
	if err := decoder.Decode(&trailing); !errors.Is(err, io.EOF) {
		if err == nil {
			return errors.New("local source record contains trailing JSON")
		}
		return err
	}
	return nil
}
