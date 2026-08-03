/*
 * [INPUT]: Depends on operating-system locale signals and go-i18n language matching.
 * [OUTPUT]: Provides deterministic English and Chinese CLI message lookup and formatting.
 * [POS]: Serves as the human-output localization boundary; machine contracts remain language independent.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package i18n

import (
	"fmt"
	"os"
	"os/exec"
	"runtime"
	"strings"
	"sync"

	systemlocale "github.com/Xuanwo/go-locale"
	goi18n "github.com/nicksnyder/go-i18n/v2/i18n"
	"golang.org/x/text/language"
)

var (
	mu        sync.RWMutex
	localizer *goi18n.Localizer
	chinese   bool
)

var messages = map[string][2]string{
	"root.short":                        {"Open package manager for the Agent Skills ecosystem", "面向开放 Agent Skills 生态的包管理器"},
	"version.short":                     {"Show CLI version and App compatibility", "显示 CLI 版本与 App 兼容性"},
	"diagnostics.short":                 {"Inspect local SkillsGo health without changing it", "只读检查本地 SkillsGo 健康状态"},
	"diagnostics.title":                 {"SkillsGo Diagnostics", "SkillsGo 诊断"},
	"diagnostics.section.storage":       {"Storage", "存储"},
	"diagnostics.state.ready":           {"readable", "可读取"},
	"diagnostics.state.not_initialized": {"not initialized", "尚未初始化"},
	"diagnostics.state.unreadable":      {"unreadable", "不可读取"},
	"verify.short":                      {"Verify reconciled local Skill installations", "校验本地 Skill 安装的协调状态"},
	"verify.title":                      {"Skill Verification", "Skill 校验"},
	"verify.error.unhealthy":            {"one or more Skill installations failed verification", "一个或多个 Skill 安装未通过校验"},
	"why.short":                         {"Explain which declarations and targets retain a Skill", "解释哪些声明与目标保留了某个 Skill"},
	"why.title":                         {"Why %s is retained", "保留 %s 的原因"},
	"why.error.missing":                 {"no declaration or target retains %s", "没有声明或目标保留 %s"},
	"agents.short":                      {"Inspect supported and installed Agents", "检查支持和已安装的 Agent"},
	"agents.title":                      {"Agents", "Agent"},
	"agents.section.installed":          {"Detected", "已检测"},
	"agents.section.supported":          {"Available", "可用"},
	"agents.state.installed":            {"installed", "已安装"},
	"agents.state.supported":            {"supported", "支持"},
	"list.short":                        {"List installed Skills across Global and Workspace locations", "列出全局和工作区位置中已安装的 Skill"},
	"adoption.short":                    {"Adopt reviewed External Skills as managed Package dependencies", "将已确认的外部技能纳入 Package 管理"},
	"list.title":                        {"Installed Skills", "已安装的 Skill"},
	"list.empty":                        {"No installed Skills found", "未找到已安装的 Skill"},
	"list.flag.global":                  {"Include Global Scope", "包含全局安装范围"},
	"list.flag.usage":                   {"Include local Skill usage evidence", "包含本地技能使用记录"},
	"list.flag.project":                 {"Include one explicit Workspace root", "包含一个显式工作区根目录"},
	"list.error.location":               {"list requires --global or at least one --project", "list 需要 --global 或至少一个 --project"},
	"list.error.output":                 {"unsupported output format %q", "不支持的输出格式 %q"},
	"list.error.empty_project":          {"Workspace root must not be empty", "工作区根目录不能为空"},
	"list.row":                          {"%s  %d targets  %s\n", "%s  %d 个目标  %s\n"},
	"show.short":                        {"Show one Package or Skill", "显示一个 Package 或 Skill"},
	"show.error.output":                 {"--output must be human or json", "--output 必须是 human 或 json"},
	"info.error.missing_skill":          {"Repository %s has no Skill %s", "仓库 %s 中没有 Skill %s"},
	"list.health.healthy":               {"healthy", "状态正常"},
	"list.health.missing":               {"target missing", "目标已缺失"},
	"list.health.replaced":              {"target replaced", "目标已被替换"},
	"list.health.local_modification":    {"Local Modification", "存在本地修改"},
	"list.health.unreadable":            {"target unreadable", "目标不可读取"},
	"list.health.undeclared":            {"not declared", "未在项目中声明"},
	"list.health.workspace_unreadable":  {"Workspace state unreadable", "项目声明不可读取"},
	"list.health.lock_mismatch":         {"Lock mismatch", "锁文件不匹配"},
	"list.health.unexpected_path":       {"unexpected target path", "目标路径异常"},
	"install.short":                     {"Restore Repository dependencies from skills.yaml", "按照 skills.yaml 恢复 Repository 依赖"},
	"update.short":                      {"Update project Skills and atomically switch targets", "更新项目 Skill 并原子切换安装目标"},
	"remove.error.confirm":              {"Repository removal requires explicit --yes confirmation", "Repository 移除需要使用 --yes 明确确认"},
	"remove.flag.confirm":               {"Confirm Repository removal", "确认移除 Repository Skill"},
	"flag.hub":                          {"Hub service URL", "Hub 服务地址"},
	"flag.output":                       {"Output format: human, json, or execution ndjson", "输出格式：human、json 或执行阶段 ndjson"},
	"flag.lang":                         {"Interface language (for example: en or zh-CN)", "界面语言（例如 en 或 zh-CN）"},
	"flag.ui":                           {"Human terminal UI: auto, interactive, or plain", "人类终端界面：auto、interactive 或 plain"},
	"flag.color":                        {"Human output color: auto, always, or never", "人类输出颜色：auto、always 或 never"},
	"flag.global.add":                   {"Install in Global Scope", "安装到全局范围"},
	"flag.agent.add":                    {"Target Agent (repeatable; '*' means all)", "目标 Agent（可指定多个，'*' 表示全部）"},
	"flag.skill":                        {"Skill name (repeatable; '*' means all)", "Skill 名称（可指定多个，'*' 表示全部）"},
	"flag.yes":                          {"Confirm without prompting", "无需提示并确认执行"},
	"flag.replace":                      {"Explicitly replace the source and all Agent bindings of a same-name Skill", "显式替换同名 Skill 的来源和全部 Agent 绑定"},
	"flag.target":                       {"Exact Installation Target as JSON (repeatable)", "精确安装目标 JSON（可重复指定）"},
	"flag.artifact_version":             {"Exact immutable artifact version for an Installation Plan", "安装计划使用的精确不可变制品版本"},
	"flag.confirm_risk":                 {"Explicitly confirm this artifact risk for the plan", "显式确认当前计划的制品风险"},
	"flag.allow_critical":               {"Apply the configured Critical-risk override", "应用已配置的严重风险覆盖策略"},
	"flag.metadata":                     {"Attach JSON metadata", "附加 JSON 元数据"},
	"flag.subagent":                     {"Eve subagent", "Eve 子 Agent"},
	"flag.full_depth":                   {"Search all subdirectories", "搜索所有子目录"},
	"error.skill_required":              {"the first implementation slice requires --skill", "首个实现切片要求显式指定 --skill"},
	"error.no_agent":                    {"no Agent detected; specify one with --agent, or use -y to select all Agents", "没有检测到 Agent，请使用 --agent 指定目标；-y 将选择全部 Agent"},
	"add.success":                       {"Installed %s@%s to %d Agent target(s) (%s)\n", "已安装 %s@%s 到 %d 个 Agent 目标（%s）\n"},
	"plan.preflight.success":            {"Planned %d target(s): %d create, %d skip\n", "已规划 %d 个目标：%d 个创建，%d 个跳过\n"},
	"plan.execution.success":            {"Installed %d target(s), skipped %d, failed %d\n", "已安装 %d 个目标，跳过 %d 个，失败 %d 个\n"},
	"update.execution.summary":          {"Updated %d target(s), failed %d\n", "已更新 %d 个目标，失败 %d 个\n"},
	"management.execution.summary":      {"Managed %d target(s), failed %d\n", "已处理 %d 个目标，失败 %d 个\n"},
	"operation.install":                 {"Installing Skill", "正在安装 Skill"},
	"operation.download":                {"Download artifact", "下载制品"},
	"operation.verify":                  {"Verify content and risk", "校验内容与风险"},
	"operation.targets":                 {"Install Agent targets", "安装 Agent 目标"},
	"operation.declaration":             {"Update declarations", "更新声明"},
	"operation.update":                  {"Updating Skill targets", "正在更新 Skill 目标"},
	"operation.manage":                  {"Managing Skill targets", "正在管理 Skill 目标"},
	"result.update":                     {"Update Results", "更新结果"},
	"result.remove":                     {"Removal Complete", "移除完成"},
	"install.success":                   {"Restored %d Skill(s) from the Workspace Manifest\n", "已按照工作区清单恢复 %d 个 Skill\n"},
	"remove.success":                    {"Removed %d Agent installation binding(s)\n", "已移除 %d 个 Agent 安装绑定\n"},
}

func Configure(tag string) {
	if strings.TrimSpace(tag) == "" {
		tag = detect()
	}
	bundle := goi18n.NewBundle(language.English)
	for id, text := range messages {
		bundle.MustAddMessages(language.English, &goi18n.Message{ID: id, Other: text[0]})
		bundle.MustAddMessages(language.Chinese, &goi18n.Message{ID: id, Other: text[1]})
	}
	mu.Lock()
	localizer = goi18n.NewLocalizer(bundle, tag)
	matched, _, _ := language.NewMatcher([]language.Tag{language.English, language.Chinese}).Match(language.Make(tag))
	base, _ := matched.Base()
	chineseBase, _ := language.Chinese.Base()
	chinese = base == chineseBase
	mu.Unlock()
}

func detect() string {
	if value := strings.TrimSpace(os.Getenv("SKILLSGO_LANG")); value != "" {
		return value
	}
	// On macOS, AppleLanguages is the authoritative interface-language
	// preference. Terminal LANG/LC_* often describe region or encoding and may
	// remain English even when the user's interface language is Chinese.
	if runtime.GOOS == "darwin" {
		if tag, err := detectAppleLanguage(); err == nil {
			return tag.String()
		}
	}
	for _, key := range []string{"LC_ALL", "LC_MESSAGES", "LANG"} {
		if value := strings.TrimSpace(os.Getenv(key)); value != "" {
			if !neutralLocale(value) {
				return strings.Split(value, ".")[0]
			}
		}
	}
	if tag, err := detectSystemLanguage(); err == nil {
		return tag.String()
	}
	return language.English.String()
}

func detectSystemLanguage() (language.Tag, error) {
	if runtime.GOOS == "darwin" {
		return detectAppleLanguage()
	}
	return systemlocale.Detect()
}

func detectAppleLanguage() (language.Tag, error) {
	output, err := exec.Command("defaults", "read", "-g", "AppleLanguages").Output()
	if err != nil {
		return language.Und, err
	}
	value := firstAppleLanguage(string(output))
	if value == "" {
		return language.Und, fmt.Errorf("AppleLanguages is empty")
	}
	return language.Make(value), nil
}

func firstAppleLanguage(output string) string {
	for _, line := range strings.Split(output, "\n") {
		value := strings.Trim(strings.TrimSpace(line), "\",(); ")
		value = strings.TrimSuffix(value, ",")
		value = strings.Trim(value, "\"")
		if value != "" {
			return value
		}
	}
	return ""
}

func neutralLocale(value string) bool {
	normalized := strings.ToUpper(strings.TrimSpace(value))
	normalized = strings.Split(normalized, ".")[0]
	return normalized == "C" || normalized == "POSIX"
}

func Pick(english, chineseText string) string {
	mu.RLock()
	useChinese := chinese
	mu.RUnlock()
	if useChinese {
		return chineseText
	}
	return english
}

func IsChinese() bool {
	mu.RLock()
	defer mu.RUnlock()
	return chinese
}

func T(id string) string {
	mu.RLock()
	current := localizer
	mu.RUnlock()
	if current == nil {
		Configure("")
		mu.RLock()
		current = localizer
		mu.RUnlock()
	}
	text, err := current.Localize(&goi18n.LocalizeConfig{MessageID: id})
	if err != nil {
		return id
	}
	return text
}

func F(id string, args ...any) string { return fmt.Sprintf(T(id), args...) }
