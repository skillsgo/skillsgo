/*
 * [INPUT]: Depends on the synchronous task runtime and fake artifact/Repository domain services.
 * [OUTPUT]: Specifies stable business-task payload validation, dispatch, defaulting, and error propagation.
 * [POS]: Serves as contract coverage for the actions-to-taskqueue composition boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"context"
	"errors"
	"testing"

	"github.com/skillsgo/skillsgo/hub/pkg/taskqueue"
	"github.com/stretchr/testify/require"
)

func TestBusinessJobKindsAreStableAndDescriptive(t *testing.T) {
	tests := []struct {
		name string
		kind string
	}{
		{"Repository source metadata refresh", repositorySourceMetadataRefreshArgs{}.Kind()},
		{"Repository publication prewarm", repositoryPublicationPrewarmArgs{}.Kind()},
		{"description translation batch", descriptionTranslationBatchArgs{}.Kind()},
	}
	require.Equal(t, []string{
		"repository_source_metadata_refresh",
		"repository_publication_prewarm",
		"description_translation_batch",
	}, []string{tests[0].kind, tests[1].kind, tests[2].kind})
}

type recordingMaterializer struct {
	repositoryID string
	query        string
	err          error
}

func (m *recordingMaterializer) Materialize(_ context.Context, repositoryID, query string) (string, error) {
	m.repositoryID, m.query = repositoryID, query
	return "v1.0.0", m.err
}

func TestRepositoryPrewarmTaskDefaultsToHeadAndPropagatesFailure(t *testing.T) {
	wantErr := errors.New("clone failed")
	materializer := &recordingMaterializer{err: wantErr}
	runtime := taskqueue.NewSynchronous()
	require.NoError(t, registerRepositoryPrewarmJob(runtime, materializer))

	err := enqueueRepositoryPrewarm(t.Context(), runtime, "github.com/acme/skills", "")
	require.ErrorIs(t, err, wantErr)
	require.Equal(t, "github.com/acme/skills", materializer.repositoryID)
	require.Equal(t, "head", materializer.query)
	require.ErrorContains(t, runtime.Enqueue(t.Context(), repositoryPublicationPrewarmArgs{}, taskqueue.InsertOptions{}), "requires repository_id")
}
