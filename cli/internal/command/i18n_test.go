/*
 * [INPUT]: Uses command.Execute with explicit locale overrides and public help requests.
 * [OUTPUT]: Specifies localized root and command help, headings, flags, and examples at the executable boundary.
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

func TestChineseAddHelpIsFullyLocalized(t *testing.T) {
	var stdout, stderr bytes.Buffer
	require.NoError(t, Execute([]string{"--lang", "zh-CN", "add", "--help"}, &stdout, &stderr))
	help := stdout.String()
	for _, expected := range []string{"用法：", "别名：", "示例：", "参数：", "全局参数：", "将完整 Package 添加到当前工作区", "目标 Agent", "无需提示并确认执行"} {
		require.Contains(t, help, expected)
	}
	require.NotContains(t, help, "# Add the complete Package")
	require.NotContains(t, help, "Usage:")
}
