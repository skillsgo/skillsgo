/*
 * [INPUT]: Depends on public host-qualified Repository coordinates.
 * [OUTPUT]: Provides canonical Repository ID parsing, formatting, and source URLs without member syntax.
 * [POS]: Serves as the public Repository ID value boundary for Hub source resolution and Catalog indexing.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skill

import (
	"fmt"
	"strings"

	protocolrepositoryid "github.com/skillsgo/skillsgo/protocol/repositoryid"
)

type RepositoryID = protocolrepositoryid.ID

func ParseRepositoryID(value string) (RepositoryID, error) {
	return protocolrepositoryid.Parse(value)
}

func parseGitHubRepositoryID(value string) (RepositoryID, error) {
	repositoryID, err := ParseRepositoryID(value)
	if err != nil {
		return RepositoryID{}, err
	}
	parts := strings.Split(repositoryID.Repository, "/")
	if len(parts) != 3 || parts[0] != "github.com" {
		return RepositoryID{}, fmt.Errorf("unsupported Repository %q", repositoryID.Repository)
	}
	return repositoryID, nil
}
