package i18n

import (
	"github.com/stretchr/testify/require"
	"testing"
)

func TestLanguageSelectionAndFallback(t *testing.T) {
	Configure("zh-CN")
	require.Equal(t, "Registry 服务地址", T("flag.registry"))
	Configure("en-US")
	require.Equal(t, "Registry service URL", T("flag.registry"))
	Configure("fr-FR")
	require.Equal(t, "Registry service URL", T("flag.registry"))
}

func TestEnvironmentOverride(t *testing.T) {
	t.Setenv("SKILLSGO_LANG", "zh-CN")
	Configure("")
	require.Equal(t, "跳过确认", T("flag.yes"))
}
