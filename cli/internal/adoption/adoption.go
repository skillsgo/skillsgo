/*
 * [INPUT]: Depends on one exact External Installation, content identity, optional Hub matches, immutable Store ingestion, and explicit user action.
 * [OUTPUT]: Provides state-bound adoption preflight plus content-preserving Hub association or offline Local Skill import.
 * [POS]: Serves as the External-to-managed ownership transition domain between inventory, Hub, Store, install, and project boundaries.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package adoption

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
	"github.com/skillsgo/skillsgo/cli/internal/hub"
	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/inventory"
	"github.com/skillsgo/skillsgo/cli/internal/project"
	"github.com/skillsgo/skillsgo/cli/internal/store"
	"gopkg.in/yaml.v3"
)

const SchemaVersion = 1

type Action string

const (
	ActionAssociateHub Action = "associate-hub"
	ActionImportLocal  Action = "import-local"
)

type Request struct {
	InventoryKey string        `json:"inventoryKey"`
	Name         string        `json:"name"`
	Scope        install.Scope `json:"scope"`
	ProjectRoot  string        `json:"projectRoot,omitempty"`
	Agent        string        `json:"agent"`
	Path         string        `json:"path"`
	Action       Action        `json:"action,omitempty"`
	MatchSkillID string        `json:"matchSkillId,omitempty"`
	MatchVersion string        `json:"matchVersion,omitempty"`
	StateToken   string        `json:"stateToken,omitempty"`
}

type Target struct {
	Scope       install.Scope `json:"scope"`
	ProjectRoot string        `json:"projectRoot,omitempty"`
	Agent       string        `json:"agent"`
	Path        string        `json:"path"`
}

type Preflight struct {
	SchemaVersion  int                `json:"schemaVersion"`
	Phase          string             `json:"phase"`
	InventoryKey   string             `json:"inventoryKey"`
	Name           string             `json:"name"`
	Target         Target             `json:"target"`
	ContentDigest  string             `json:"contentDigest"`
	SourceHint     string             `json:"sourceHint,omitempty"`
	StateToken     string             `json:"stateToken"`
	Matches        []hub.ContentMatch `json:"matches"`
	CanImportLocal bool               `json:"canImportLocal"`
}

type Result struct {
	SchemaVersion int    `json:"schemaVersion"`
	Phase         string `json:"phase"`
	Action        Action `json:"action"`
	Name          string `json:"name"`
	SkillID       string `json:"skillId"`
	Version       string `json:"version"`
	Provenance    string `json:"provenance"`
	ContentDigest string `json:"contentDigest"`
	Target        Target `json:"target"`
}

type Matcher interface {
	MatchContent(context.Context, string, string) ([]hub.ContentMatch, error)
}

func Inspect(catalog *agent.Catalog, request Request) (Preflight, error) {
	if request.InventoryKey == "" || request.Name == "" || request.Agent == "" || request.Path == "" {
		return Preflight{}, fmt.Errorf("inventory key, name, Agent, and path are required")
	}
	if request.Scope != install.ScopeUser && request.Scope != install.ScopeProject {
		return Preflight{}, fmt.Errorf("unsupported adoption scope %q", request.Scope)
	}
	if request.Scope == install.ScopeProject && request.ProjectRoot == "" {
		return Preflight{}, fmt.Errorf("projectRoot is required for project adoption")
	}
	projects := []string{}
	if request.ProjectRoot != "" {
		projects = append(projects, request.ProjectRoot)
	}
	report, err := inventory.Build(inventory.Options{IncludeUser: true, Projects: projects, Catalog: catalog})
	if err != nil {
		return Preflight{}, err
	}
	found := false
	for _, entry := range report.Entries {
		if entry.InventoryKey != request.InventoryKey || entry.Provenance != inventory.ProvenanceExternal || entry.Name != request.Name {
			continue
		}
		for _, target := range entry.Targets {
			if target.Scope == request.Scope && target.ProjectRoot == request.ProjectRoot && target.Agent == request.Agent && samePath(target.Path, request.Path) {
				found = true
			}
		}
	}
	if !found {
		return Preflight{}, fmt.Errorf("exact External Installation not found")
	}
	digest, err := hub.ContentDirectoryDigest(request.Path)
	if err != nil {
		return Preflight{}, err
	}
	state, err := install.TargetStateDigest(request.Path)
	if err != nil {
		return Preflight{}, err
	}
	payload, _ := json.Marshal([]string{request.InventoryKey, request.Name, string(request.Scope), request.ProjectRoot, request.Agent, filepath.Clean(request.Path), digest, state})
	token := sha256.Sum256(payload)
	return Preflight{
		SchemaVersion: SchemaVersion, Phase: "adoption-preflight", InventoryKey: request.InventoryKey,
		Name: request.Name, Target: Target{Scope: request.Scope, ProjectRoot: request.ProjectRoot, Agent: request.Agent, Path: filepath.Clean(request.Path)},
		ContentDigest: digest, SourceHint: sourceHint(request.Path), StateToken: "sha256:" + hex.EncodeToString(token[:]),
		Matches: []hub.ContentMatch{}, CanImportLocal: true,
	}, nil
}

func AddMatches(ctx context.Context, preflight Preflight, matcher Matcher) (Preflight, error) {
	matches, err := matcher.MatchContent(ctx, preflight.ContentDigest, preflight.SourceHint)
	if err != nil {
		return Preflight{}, err
	}
	preflight.Matches = matches
	return preflight, nil
}

func Execute(ctx context.Context, request Request, preflight Preflight, client *hub.Client, storage store.Store) (Result, error) {
	if request.StateToken != preflight.StateToken {
		return Result{}, fmt.Errorf("External Installation changed after review")
	}
	var entry *store.Entry
	var ref string
	var err error
	provenance := ""
	switch request.Action {
	case ActionImportLocal:
		if request.MatchSkillID != "" || request.MatchVersion != "" {
			return Result{}, fmt.Errorf("Local import cannot include a Hub match")
		}
		entry, err = storage.ImportLocal(request.Path, request.Name)
		provenance = "local"
		ref = entryVersion(entry)
	case ActionAssociateHub:
		if client == nil || request.MatchSkillID == "" || request.MatchVersion == "" {
			return Result{}, fmt.Errorf("Hub association requires an exact match")
		}
		matches, matchErr := client.MatchContent(ctx, preflight.ContentDigest, preflight.SourceHint)
		if matchErr != nil {
			return Result{}, matchErr
		}
		matched := false
		for _, candidate := range matches {
			if candidate.SkillID == request.MatchSkillID && candidate.ImmutableVersion == request.MatchVersion {
				matched = true
			}
		}
		if !matched {
			return Result{}, fmt.Errorf("reviewed Hub match is no longer available")
		}
		artifact, fetchErr := client.Fetch(ctx, request.MatchSkillID, request.MatchVersion)
		if fetchErr != nil {
			return Result{}, fetchErr
		}
		if artifact.Info.ContentDigest != preflight.ContentDigest {
			return Result{}, fmt.Errorf("Hub match content changed")
		}
		entry, err = storage.Put(artifact)
		provenance = "hub"
		ref = artifact.Info.Origin.Ref
	default:
		return Result{}, fmt.Errorf("explicit adoption action is required")
	}
	if err != nil {
		return Result{}, err
	}
	target := install.Target{Agent: request.Agent, Scope: request.Scope, Mode: install.ModeCopy, Path: request.Path}
	if err := install.AdoptExisting(entry, target); err != nil {
		return Result{}, err
	}
	if request.Scope == install.ScopeProject {
		if ref == "" {
			ref = entry.Receipt.Version
		}
		if err := project.Upsert(request.ProjectRoot, request.Name, project.SkillRequirement{
			Source: entry.Receipt.SkillID, Ref: ref, Agents: []string{request.Agent}, Mode: install.ModeCopy,
		}, entry.Receipt); err != nil {
			return Result{}, err
		}
	}
	return Result{
		SchemaVersion: SchemaVersion, Phase: "adoption-execution", Action: request.Action,
		Name: request.Name, SkillID: entry.Receipt.SkillID, Version: entry.Receipt.Version,
		Provenance: provenance, ContentDigest: entry.Receipt.ContentDigest, Target: preflight.Target,
	}, nil
}

func entryVersion(entry *store.Entry) string {
	if entry == nil {
		return ""
	}
	return entry.Receipt.Version
}

func sourceHint(root string) string {
	data, err := os.ReadFile(filepath.Join(root, "SKILL.md"))
	if err != nil {
		return ""
	}
	normalized := strings.ReplaceAll(string(data), "\r\n", "\n")
	if !strings.HasPrefix(normalized, "---\n") {
		return ""
	}
	end := strings.Index(normalized[4:], "\n---\n")
	if end < 0 {
		return ""
	}
	var manifest struct {
		Source     string `yaml:"source"`
		Repository string `yaml:"repository"`
		Metadata   struct {
			Source string `yaml:"source"`
		} `yaml:"metadata"`
	}
	if yaml.Unmarshal([]byte(normalized[4:4+end]), &manifest) != nil {
		return ""
	}
	for _, value := range []string{manifest.Source, manifest.Repository, manifest.Metadata.Source} {
		if strings.TrimSpace(value) != "" {
			return strings.TrimSpace(value)
		}
	}
	return ""
}

func samePath(left, right string) bool {
	leftAbs, leftErr := filepath.Abs(left)
	rightAbs, rightErr := filepath.Abs(right)
	return leftErr == nil && rightErr == nil && filepath.Clean(leftAbs) == filepath.Clean(rightAbs)
}
