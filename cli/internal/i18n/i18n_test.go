/*
 * [INPUT]: Depends on the i18n package imports and contracts declared in this file.
 * [OUTPUT]: Specifies the i18n package behavior covered by i18n_test.go.
 * [POS]: Serves as test coverage for the i18n package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package i18n

import (
	"github.com/stretchr/testify/require"
	"testing"
)

func TestLanguageSelectionAndFallback(t *testing.T) {
	Configure("zh-CN")
	require.Equal(t, "已更新 2 个目标，失败 1 个\n", F("update.execution.summary", 2, 1))
	require.Equal(t, "已处理 3 个目标，失败 1 个\n", F("management.execution.summary", 3, 1))
	require.Equal(t, "Hub 服务地址", T("flag.hub"))
	Configure("en-US")
	require.Equal(t, "Hub service URL", T("flag.hub"))
	Configure("fr-FR")
	require.Equal(t, "Hub service URL", T("flag.hub"))
}

func TestEnvironmentOverride(t *testing.T) {
	t.Setenv("SKILLSGO_LANG", "zh-CN")
	Configure("")
	require.Equal(t, "跳过确认", T("flag.yes"))
}
