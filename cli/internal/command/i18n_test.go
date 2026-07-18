/*
 * [INPUT]: Uses command.Execute with explicit locale overrides and public help requests.
 * [OUTPUT]: Specifies localized root and Local export help at the executable boundary.
 * [POS]: Serves as public CLI localization coverage independent of machine-readable contracts.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package command

import (
	"bytes"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestHelpLanguageOverride(t *testing.T) {
	for _, test := range []struct{ lang, want string }{
		{"en", "Open package manager for the Agent Skills ecosystem"},
		{"zh-CN", "面向开放 Agent Skills 生态的包管理器"},
	} {
		t.Run(test.lang, func(t *testing.T) {
			var stdout, stderr bytes.Buffer
			require.NoError(t, Execute([]string{"--lang", test.lang, "--help"}, &stdout, &stderr))
			require.Contains(t, stdout.String(), test.want)
		})
	}
}

func TestExportHelpLanguageOverride(t *testing.T) {
	var stdout, stderr bytes.Buffer
	require.NoError(t, Execute([]string{"--lang", "zh-CN", "export", "--help"}, &stdout, &stderr))
	require.Contains(t, stdout.String(), "导出一个私有本地 Skill")
}
