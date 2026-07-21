//go:build e2etests
// +build e2etests

/*
 * [INPUT]: Depends on a running Hub, SkillsGo-owned public nested Skill fixtures, enriched Info, and deterministic ZIP delivery.
 * [OUTPUT]: Specifies end-to-end exact Info metadata, immutable cache replay, and complete single-file/resourceful Skill ZIP contents.
 * [POS]: Serves as the external protocol acceptance test after independent Manifest resource contraction.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2etests

import (
	"archive/zip"
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
)

const (
	testSkillModule            = "github.com/skillsgo/e2e-versioned-skills/-/skills/resourceful"
	testSkillVersion           = "v1.3.0"
	testSkillTreeSHA           = "68351e08c3cb9105a93e80fc539f0df97f954fb8"
	testSkillMonorepoCommitSHA = "2a54d098bed5be7f5d095a7f99bf16c894275f6e"
	testNestedSkillModule      = "github.com/skillsgo/e2e-versioned-skills/-/skills/alpha"
	testNestedSkillVersion     = "v1.3.0"
	testNestedSkillTreeSHA     = "92f6e13b356461714cf86e17bf5e30454affe663"
)

type skillModuleInfo struct {
	Version   string `json:"Version"`
	Name      string `json:"Name"`
	CommitSHA string `json:"CommitSHA"`
	TreeSHA   string `json:"TreeSHA"`
	Ref       string `json:"Ref"`
}

// TestSkillArtifact verifies a tagged multi-file Skill from a SkillsGo-owned fixture.
func (m *E2eSuite) TestSkillArtifact() {
	infoBody := m.getProxyArtifact(testSkillModule + "/@v/" + testSkillVersion + ".info")
	var info skillModuleInfo
	m.Require().NoError(json.Unmarshal(infoBody, &info))
	m.Equal(testSkillVersion, info.Version)
	m.Equal(testSkillMonorepoCommitSHA, info.CommitSHA)
	m.Equal(testSkillTreeSHA, info.TreeSHA)
	m.Equal("refs/tags/"+testSkillVersion, info.Ref)

	m.Equal("resourceful", info.Name)

	zipBody := m.getProxyArtifact(testSkillModule + "/@v/" + testSkillVersion + ".zip")
	zipBodyFromCache := m.getProxyArtifact(testSkillModule + "/@v/" + testSkillVersion + ".zip")
	m.Equal(zipBody, zipBodyFromCache, "cached Skill zip must be byte-identical")

	reader, err := zip.NewReader(bytes.NewReader(zipBody), int64(len(zipBody)))
	m.Require().NoError(err)

	prefix := testSkillModule + "@" + testSkillVersion + "/"
	wantFiles := map[string]bool{
		prefix + "SKILL.md":            false,
		prefix + "references/guide.md": false,
	}
	for _, file := range reader.File {
		if _, ok := wantFiles[file.Name]; ok {
			wantFiles[file.Name] = true
		}
	}
	for name, found := range wantFiles {
		m.True(found, "Skill zip is missing %s", name)
	}
}

func (m *E2eSuite) TestNestedSkillArtifact() {
	infoBody := m.getProxyArtifact(testNestedSkillModule + "/@v/" + testNestedSkillVersion + ".info")
	var info skillModuleInfo
	m.Require().NoError(json.Unmarshal(infoBody, &info))
	m.Equal(testNestedSkillVersion, info.Version)
	m.Equal(testSkillMonorepoCommitSHA, info.CommitSHA)
	m.Equal(testNestedSkillTreeSHA, info.TreeSHA)

	m.Equal("alpha", info.Name)

	zipBody := m.getProxyArtifact(testNestedSkillModule + "/@v/" + testNestedSkillVersion + ".zip")
	reader, err := zip.NewReader(bytes.NewReader(zipBody), int64(len(zipBody)))
	m.Require().NoError(err)

	prefix := testNestedSkillModule + "@" + testNestedSkillVersion + "/"
	wantFiles := map[string]bool{
		prefix + "SKILL.md": false,
	}
	for _, file := range reader.File {
		if _, ok := wantFiles[file.Name]; ok {
			wantFiles[file.Name] = true
		}
	}
	for name, found := range wantFiles {
		m.True(found, "Skill zip is missing %s", name)
	}
}

func (m *E2eSuite) getProxyArtifact(path string) []byte {
	response, err := http.Get(m.hubOrigin + "/mod/" + path)
	m.Require().NoError(err)
	defer response.Body.Close()

	body, err := io.ReadAll(response.Body)
	m.Require().NoError(err)
	m.Require().Equal(http.StatusOK, response.StatusCode, "GET %s: %s", path, body)
	m.Require().NotEmpty(body, fmt.Sprintf("GET %s returned an empty body", path))
	return body
}
