/*
 * [INPUT]: Depends on archive/JSON encoders and CLI Hub Repository contract types.
 * [OUTPUT]: Provides compact Repository protocol fixtures shared by command tests.
 * [POS]: Serves as test-only infrastructure for Repository-oriented command seams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"encoding/json"
	"testing"
	"time"

	"github.com/skillsgo/skillsgo/cli/internal/hub"
)

func commandTestRepositoryInfo(t *testing.T, repositoryID, version, commit string, members ...hub.Info) []byte {
	t.Helper()
	encoded, err := json.Marshal(hub.RepositoryInfo{
		SchemaVersion: 1,
		Kind:          "Repository",
		ID:            repositoryID,
		Version:       version,
		Time:          time.Unix(1, 0).UTC(),
		Ref:           members[0].Ref,
		CommitSHA:     commit,
		TreeSHA:       "repository-tree",
		Sum:           "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
		ArchiveSize:   1,
		Skills:        members,
	})
	if err != nil {
		t.Fatal(err)
	}
	return encoded
}
