/*
 * [INPUT]: Depends on metadata-refresh and translation business job arguments.
 * [OUTPUT]: Specifies stable business-task kinds and translation timeout behavior.
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
		{"description translation batch", descriptionTranslationBatchArgs{}.Kind()},
		{"document translation", documentTranslationArgs{}.Kind()},
	}
	require.Equal(t, []string{
		"repository_source_metadata_refresh",
		"description_translation_batch",
		"document_translation",
	}, []string{tests[0].kind, tests[1].kind, tests[2].kind})
}

func TestTranslationBatchesUsePerRequestTimeouts(t *testing.T) {
	require.Equal(t, time.Duration(-1), descriptionTranslationBatchArgs{}.JobTimeout())
	require.Equal(t, time.Duration(-1), documentTranslationArgs{}.JobTimeout())
}
