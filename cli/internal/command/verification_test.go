/*
 * [INPUT]: Uses command.Execute with a fixture Hub artifact, isolated user scope, and a modified copy-mode target.
 * [OUTPUT]: Specifies direct `why` retention evidence plus healthy and failing `verify` machine reports.
 * [POS]: Serves as command-level coverage for read-only local verification and explanation behavior.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestWhyAndVerifyReconciledUserInstallation(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	skillID, version := "github.com/example/skills/-/demo", "v1.2.3"
	archive := commandTestZIP(t, skillID+"@"+version+"/", map[string]string{
		"SKILL.md": "---\nname: demo\ndescription: Demo.\n---\n",
	})
	sum := commandTestSum(t, archive, skillID, version)
	repositoryID := strings.SplitN(skillID, "/-/", 2)[0]
	memberInfo := fmt.Sprintf(`{"SchemaVersion":1,"Kind":"Skill","ID":%q,"Name":"demo","Description":"Demo.","Version":%q,"Time":"2026-01-01T00:00:00Z","Risk":"low","Sum":%q,"ArchiveSize":%d,"VCS":"git","URL":"https://github.com/example/skills","Subdir":"demo","Ref":"refs/tags/v1.2.3","CommitSHA":"abc","TreeSHA":"def"}`, skillID, version, sum, len(archive))
	repositoryInfo := fmt.Sprintf(`{"SchemaVersion":1,"Kind":"Repository","ID":%q,"Version":%q,"Ref":"refs/tags/v1.2.3","CommitSHA":"abc","Skills":[%s]}`, repositoryID, version, memberInfo)
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		switch request.URL.Path {
		case "/mod/" + repositoryID + "/@v/" + version + ".info":
			_, _ = writer.Write([]byte(repositoryInfo))
		case "/mod/" + skillID + "/@v/" + version + ".zip":
			_, _ = writer.Write(archive)
		default:
			http.NotFound(writer, request)
		}
	}))
	defer server.Close()

	require.NoError(t, Execute([]string{"add", skillID + "@" + version, "--agent", "codex", "--global", "--copy", "--yes", "--hub", server.URL, "--output", "json"}, &bytes.Buffer{}, &bytes.Buffer{}))

	var whyOutput bytes.Buffer
	require.NoError(t, Execute([]string{"why", skillID, "--user", "--output", "json"}, &whyOutput, &bytes.Buffer{}))
	var why whyReport
	require.NoError(t, json.Unmarshal(whyOutput.Bytes(), &why))
	require.Len(t, why.Entries, 1)
	require.Equal(t, skillID, why.Entries[0].SkillID)
	require.Len(t, why.Entries[0].Targets, 1)

	var healthyOutput bytes.Buffer
	require.NoError(t, Execute([]string{"verify", "--user", "--output", "json"}, &healthyOutput, &bytes.Buffer{}))
	var healthy verificationReport
	require.NoError(t, json.Unmarshal(healthyOutput.Bytes(), &healthy))
	require.True(t, healthy.Healthy)

	target := filepath.Join(home, ".codex", "skills", "demo", "SKILL.md")
	require.NoError(t, os.WriteFile(target, []byte("modified"), 0o644))
	var unhealthyOutput bytes.Buffer
	require.Error(t, Execute([]string{"verify", "--user", "--output", "json"}, &unhealthyOutput, &bytes.Buffer{}))
	var unhealthy verificationReport
	require.NoError(t, json.Unmarshal(unhealthyOutput.Bytes(), &unhealthy))
	require.False(t, unhealthy.Healthy)
}
