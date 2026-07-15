//go:build e2etests
// +build e2etests

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
	testSkillModule            = "github.com/op7418/guizang-ppt-skill"
	testSkillVersion           = "v1.1.0"
	testSkillTreeSHA           = "f17a01bcf457cca0ba9a3432fb7218a064261a14"
	testSkillMonorepoCommitSHA = "66898f60e8c744e269f8ce06c2b2b99ce7660d5f"
	testNestedSkillModule      = "github.com/mattpocock/skills/-/skills/engineering/ask-matt"
	testNestedSkillVersion     = "v0.0.0-20260713133601-66898f60e8c7"
	testNestedSkillTreeSHA     = "c7d57789b230d6f88d26ca81ab9d03bad160171f"
)

type skillModuleInfo struct {
	Version string `json:"Version"`
	Origin  struct {
		CommitSHA string `json:"CommitSHA"`
		TreeSHA   string `json:"TreeSHA"`
		Ref       string `json:"Ref"`
	} `json:"Origin"`
}

// TestSkillArtifact verifies a tagged repository with a root SKILL.md.
func (m *E2eSuite) TestSkillArtifact() {
	infoBody := m.getProxyArtifact(testSkillModule + "/@v/" + testSkillVersion + ".info")
	var info skillModuleInfo
	m.Require().NoError(json.Unmarshal(infoBody, &info))
	m.Equal(testSkillVersion, info.Version)
	m.Equal("3652b3c7aa21492717945b6063ae278030101dd8", info.Origin.CommitSHA)
	m.Equal(testSkillTreeSHA, info.Origin.TreeSHA)
	m.Equal("refs/tags/"+testSkillVersion, info.Origin.Ref)

	modBody := m.getProxyArtifact(testSkillModule + "/@v/" + testSkillVersion + ".manifest")
	m.Contains(string(modBody), "name: guizang-ppt-skill\n")
	m.Contains(string(modBody), "description: ")
	m.NotContains(string(modBody), "---")

	zipBody := m.getProxyArtifact(testSkillModule + "/@v/" + testSkillVersion + ".zip")
	zipBodyFromCache := m.getProxyArtifact(testSkillModule + "/@v/" + testSkillVersion + ".zip")
	m.Equal(zipBody, zipBodyFromCache, "cached Skill zip must be byte-identical")

	reader, err := zip.NewReader(bytes.NewReader(zipBody), int64(len(zipBody)))
	m.Require().NoError(err)

	prefix := testSkillModule + "@" + testSkillVersion + "/"
	wantFiles := map[string]bool{
		prefix + "SKILL.md":                        false,
		prefix + "assets/motion.min.js":            false,
		prefix + "references/checklist.md":         false,
		prefix + "scripts/validate-swiss-deck.mjs": false,
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
	infoBody := m.getProxyArtifact(testNestedSkillModule + "/@v/main.info")
	var info skillModuleInfo
	m.Require().NoError(json.Unmarshal(infoBody, &info))
	m.Equal(testNestedSkillVersion, info.Version)
	m.Equal(testSkillMonorepoCommitSHA, info.Origin.CommitSHA)
	m.Equal(testNestedSkillTreeSHA, info.Origin.TreeSHA)

	modBody := m.getProxyArtifact(testNestedSkillModule + "/@v/main.manifest")
	m.Equal("name: ask-matt\ndescription: Ask which skill or flow fits your situation. A router over the skills in this repo.\ndisable-model-invocation: true\n", string(modBody))

	zipBody := m.getProxyArtifact(testNestedSkillModule + "/@v/main.zip")
	reader, err := zip.NewReader(bytes.NewReader(zipBody), int64(len(zipBody)))
	m.Require().NoError(err)

	prefix := testNestedSkillModule + "@" + testNestedSkillVersion + "/"
	wantFiles := map[string]bool{
		prefix + "SKILL.md":           false,
		prefix + "agents/openai.yaml": false,
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
	response, err := http.Get("http://localhost:3000/" + path)
	m.Require().NoError(err)
	defer response.Body.Close()

	body, err := io.ReadAll(response.Body)
	m.Require().NoError(err)
	m.Require().Equal(http.StatusOK, response.StatusCode, "GET %s: %s", path, body)
	m.Require().NotEmpty(body, fmt.Sprintf("GET %s returned an empty body", path))
	return body
}
