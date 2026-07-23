/*
 * [INPUT]: Uses deterministic complete Repository Artifacts with root and nested Skill members.
 * [OUTPUT]: Specifies selected-member inspection, Repository Sum binding, executable evidence, and strict member-path validation.
 * [POS]: Serves as focused behavior coverage for Repository Artifact audit projection.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package audit

import (
	"testing"

	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
	"github.com/stretchr/testify/require"
)

func TestAnalyzeRepositoryMemberProjectsOnlySelectedMember(t *testing.T) {
	repositoryID, version := "github.com/acme/skills", "v1.0.0"
	archive, err := protocolartifact.BuildRepository(repositoryID, version, []protocolartifact.Entry{
		{Path: "SKILL.md", Contents: []byte("---\nname: root\ndescription: Root Skill.\n---\nRoot instructions."), Mode: 0o644},
		{Path: "skills/demo/SKILL.md", Contents: []byte("---\nname: demo\ndescription: Demo Skill.\n---\nDemo instructions."), Mode: 0o644},
		{Path: "skills/demo/scripts/run.sh", Contents: []byte("#!/bin/sh\necho demo\n"), Mode: 0o755},
		{Path: "skills/other/SKILL.md", Contents: []byte("---\nname: other\ndescription: Other Skill.\n---\nOther."), Mode: 0o644},
	})
	require.NoError(t, err)

	result, err := AnalyzeRepositoryMember(archive, repositoryID, version, "skills/demo")
	require.NoError(t, err)
	require.Equal(t, "---\nname: demo\ndescription: Demo Skill.\n---\nDemo instructions.", result.Instructions)
	require.Equal(t, []string{"scripts/run.sh"}, result.ExecutableFiles)
	require.True(t, result.HasExecutableContent)
	require.Len(t, result.Files, 2)
	wantSum, err := protocolartifact.RepositorySum(archive, repositoryID, version)
	require.NoError(t, err)
	require.Equal(t, wantSum, result.Sum)
	require.Equal(t, wantSum, result.Risk.ArtifactSum)
}

func TestAnalyzeRepositoryMemberRejectsMissingMemberManifest(t *testing.T) {
	repositoryID, version := "github.com/acme/skills", "v1.0.0"
	archive, err := protocolartifact.BuildRepository(repositoryID, version, []protocolartifact.Entry{
		{Path: "SKILL.md", Contents: []byte("---\nname: root\ndescription: Root Skill.\n---\nRoot."), Mode: 0o644},
	})
	require.NoError(t, err)

	_, err = AnalyzeRepositoryMember(archive, repositoryID, version, "skills/missing")
	require.ErrorContains(t, err, "artifact does not contain SKILL.md")
}
