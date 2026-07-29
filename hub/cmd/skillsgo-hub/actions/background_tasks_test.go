/*
 * [INPUT]: Depends on metadata-refresh, translation-dispatch, and single-localization business job arguments.
 * [OUTPUT]: Specifies stable business-task kinds plus short dispatch and five-minute single-item timeouts.
 * [POS]: Serves as contract coverage for the actions-to-taskqueue composition boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"testing"
	"time"

	"github.com/stretchr/testify/require"
)

func TestBusinessJobKindsAreStableAndDescriptive(t *testing.T) {
	tests := []struct {
		name string
		kind string
	}{
		{"Repository source metadata refresh", repositorySourceMetadataRefreshArgs{}.Kind()},
		{"description translation dispatch", descriptionTranslationDispatchArgs{}.Kind()},
		{"description translation", descriptionTranslationArgs{}.Kind()},
		{"document translation dispatch", documentTranslationDispatchArgs{}.Kind()},
		{"document translation", documentTranslationArgs{}.Kind()},
	}
	require.Equal(t, []string{
		"repository_source_metadata_refresh",
		"description_translation_dispatch",
		"description_translation",
		"document_translation_dispatch",
		"document_translation_item",
	}, []string{tests[0].kind, tests[1].kind, tests[2].kind, tests[3].kind, tests[4].kind})
}

func TestTranslationJobsUseScopeAppropriateTimeouts(t *testing.T) {
	require.Equal(t, 30*time.Second, descriptionTranslationDispatchArgs{}.JobTimeout())
	require.Equal(t, 30*time.Second, documentTranslationDispatchArgs{}.JobTimeout())
	require.Equal(t, 5*time.Minute, descriptionTranslationArgs{}.JobTimeout())
	require.Equal(t, 5*time.Minute, documentTranslationArgs{}.JobTimeout())
}
