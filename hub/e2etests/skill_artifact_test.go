//go:build e2etests
// +build e2etests

/*
 * [INPUT]: Depends on a running Hub, a SkillsGo-owned multi-Skill Repository fixture, Repository Info, and deterministic ZIP delivery.
 * [OUTPUT]: Specifies end-to-end Repository Info metadata, immutable cache replay, and complete Repository ZIP contents for root and nested members.
 * [POS]: Serves as the external Repository artifact protocol acceptance test.
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
	testRepository             = "github.com/skillsgo/e2e-versioned-skills"
	testSkillVersion           = "v1.3.0"
	testSkillMonorepoCommitSHA = "2a54d098bed5be7f5d095a7f99bf16c894275f6e"
)

type repositoryInfo struct {
	Version   string `json:"Version"`
	CommitSHA string `json:"CommitSHA"`
	Ref       string `json:"Ref"`
	Sum       string `json:"Sum"`
	Skills    []struct {
		Path string `json:"Path"`
		Name string `json:"Name"`
	} `json:"Skills"`
}

// TestRepositoryArtifact verifies one tagged multi-Skill Repository fixture.
func (m *E2eSuite) TestRepositoryArtifact() {
	infoBody := m.getProxyArtifact(testRepository + "/@v/" + testSkillVersion + ".info")
	var info repositoryInfo
	m.Require().NoError(json.Unmarshal(infoBody, &info))
	m.Equal(testSkillVersion, info.Version)
	m.Equal(testSkillMonorepoCommitSHA, info.CommitSHA)
	m.Equal("refs/tags/"+testSkillVersion, info.Ref)
	m.NotEmpty(info.Sum)
	m.Contains(memberPaths(info), "skills/resourceful")
	m.Contains(memberPaths(info), "skills/alpha")

	zipBody := m.getProxyArtifact(testRepository + "/@v/" + testSkillVersion + ".zip")
	zipBodyFromCache := m.getProxyArtifact(testRepository + "/@v/" + testSkillVersion + ".zip")
	m.Equal(zipBody, zipBodyFromCache, "cached Repository zip must be byte-identical")

	reader, err := zip.NewReader(bytes.NewReader(zipBody), int64(len(zipBody)))
	m.Require().NoError(err)

	prefix := testRepository + "@" + testSkillVersion + "/"
	wantFiles := map[string]bool{
		prefix + "skills/resourceful/SKILL.md":            false,
		prefix + "skills/resourceful/references/guide.md": false,
		prefix + "skills/alpha/SKILL.md":                  false,
	}
	for _, file := range reader.File {
		if _, ok := wantFiles[file.Name]; ok {
			wantFiles[file.Name] = true
		}
	}
	for name, found := range wantFiles {
		m.True(found, "Repository zip is missing %s", name)
	}
}

func memberPaths(info repositoryInfo) []string {
	paths := make([]string, 0, len(info.Skills))
	for _, skill := range info.Skills {
		paths = append(paths, skill.Path)
	}
	return paths
}

func (m *E2eSuite) getProxyArtifact(path string) []byte {
	response, err := http.Get(m.hubOrigin + "/" + path)
	m.Require().NoError(err)
	defer response.Body.Close()

	body, err := io.ReadAll(response.Body)
	m.Require().NoError(err)
	m.Require().Equal(http.StatusOK, response.StatusCode, "GET %s: %s", path, body)
	m.Require().NotEmpty(body, fmt.Sprintf("GET %s returned an empty body", path))
	return body
}
