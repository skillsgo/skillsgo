/*
 * [INPUT]: Depends on archive/JSON encoders and CLI Hub Package contract types.
 * [OUTPUT]: Provides compact Package protocol fixtures shared by command tests.
 * [POS]: Serves as test-only infrastructure for Package-oriented command seams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"encoding/json"
	"testing"
	"time"

	"github.com/skillsgo/skillsgo/cli/internal/hub"
)

func commandTestPackageInfo(t *testing.T, packagePath, version, commit string, members ...hub.Info) []byte {
	t.Helper()
	encoded, err := json.Marshal(hub.PackageInfo{
		SchemaVersion: 1,
		Kind:          "Package",
		PackagePath:   packagePath,
		Version:       version,
		Time:          time.Unix(1, 0).UTC(),
		Sum:           "h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
		ArchiveSize:   1,
		Skills:        members,
	})
	if err != nil {
		t.Fatal(err)
	}
	return encoded
}
