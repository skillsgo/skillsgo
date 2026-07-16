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
	"strings"
	"sync"

	systemlocale "github.com/Xuanwo/go-locale"
	goi18n "github.com/nicksnyder/go-i18n/v2/i18n"
	"golang.org/x/text/language"
)

var (
	mu        sync.RWMutex
	localizer *goi18n.Localizer
)

var messages = map[string][2]string{
	"root.short":                            {"Open package manager for the Agent Skills ecosystem", "面向开放 Agent Skills 生态的包管理器"},
	"version.short":                         {"Show CLI version and App compatibility", "显示 CLI 版本与 App 兼容性"},
	"diagnostics.short":                     {"Inspect local SkillsGo health without changing it", "只读检查本地 SkillsGo 健康状态"},
	"diagnostics.store":                     {"Store: %s (%s)\n", "Store：%s（%s）\n"},
	"diagnostics.state.ready":               {"readable", "可读取"},
	"diagnostics.state.not_initialized":     {"not initialized", "尚未初始化"},
	"diagnostics.state.unreadable":          {"unreadable", "不可读取"},
	"agents.short":                          {"Inspect supported and installed Agents", "检查支持和已安装的 Agent"},
	"agents.state.installed":                {"installed", "已安装"},
	"agents.state.supported":                {"supported", "支持"},
	"inventory.short":                       {"Inspect managed Skills for explicit Library locations", "检查显式技能库位置中的已管理 Skill"},
	"inventory.flag.user":                   {"Include User Scope", "包含用户范围"},
	"inventory.flag.project":                {"Include one explicit project root", "包含一个显式项目根目录"},
	"inventory.error.location":              {"inventory requires --user or at least one --project", "inventory 需要 --user 或至少一个 --project"},
	"inventory.error.output":                {"unsupported output format %q", "不支持的输出格式 %q"},
	"inventory.error.empty_project":         {"project root must not be empty", "项目根目录不能为空"},
	"inventory.row":                         {"%s  %d targets  %s\n", "%s  %d 个目标  %s\n"},
	"adopt.short":                           {"Bring one exact External Installation under management", "将一个精确的外部安装纳入管理"},
	"export.short":                          {"Export one private Local Skill", "导出一个私有本地 Skill"},
	"inventory.health.healthy":              {"healthy", "状态正常"},
	"inventory.health.missing":              {"target missing", "目标已缺失"},
	"inventory.health.replaced":             {"target replaced", "目标已被替换"},
	"inventory.health.local_modification":   {"Local Modification", "存在本地修改"},
	"inventory.health.unreadable":           {"target unreadable", "目标不可读取"},
	"inventory.health.undeclared":           {"not declared", "未在项目中声明"},
	"inventory.health.workspace_unreadable": {"Workspace state unreadable", "项目声明不可读取"},
	"inventory.health.lock_mismatch":        {"Lock mismatch", "锁文件不匹配"},
	"inventory.health.unexpected_path":      {"unexpected target path", "目标路径异常"},
	"inventory.health.receipt_missing":      {"receipt missing", "回执缺失"},
	"install.short":                         {"Restore project Skills from skillsgo-lock.yaml", "按照 skillsgo-lock.yaml 恢复项目 Skill"},
	"update.short":                          {"Update project Skills and atomically switch targets", "更新项目 Skill 并原子切换安装目标"},
	"flag.hub":                              {"Hub service URL", "Hub 服务地址"},
	"flag.output":                           {"Output format: human, json, or execution ndjson", "输出格式：human、json 或执行阶段 ndjson"},
	"flag.lang":                             {"Interface language (for example: en or zh-CN)", "界面语言（例如 en 或 zh-CN）"},
	"flag.global.add":                       {"Install in the user-level directory", "安装到用户级目录"},
	"flag.agent.add":                        {"Target Agent (repeatable; '*' means all)", "目标 Agent（可指定多个，'*' 表示全部）"},
	"flag.skill":                            {"Skill name (repeatable; '*' means all)", "Skill 名称（可指定多个，'*' 表示全部）"},
	"flag.list":                             {"List available Skills only", "只列出可用 Skill"},
	"flag.yes":                              {"Skip confirmation", "跳过确认"},
	"flag.copy":                             {"Copy files instead of creating symlinks", "复制文件而不是创建符号链接"},
	"flag.replace":                          {"Explicitly replace the source and all Agent bindings of a same-name Skill", "显式替换同名 Skill 的来源和全部 Agent 绑定"},
	"flag.target":                           {"Exact Installation Target as JSON (repeatable)", "精确安装目标 JSON（可重复指定）"},
	"flag.preflight":                        {"Preview exact target actions without installing", "预览精确目标操作但不执行安装"},
	"flag.artifact_version":                 {"Exact immutable artifact version for an Installation Plan", "安装计划使用的精确不可变制品版本"},
	"flag.confirm_risk":                     {"Explicitly confirm this artifact risk for the plan", "显式确认当前计划的制品风险"},
	"flag.allow_critical":                   {"Apply the configured Critical-risk override", "应用已配置的严重风险覆盖策略"},
	"flag.metadata":                         {"Attach JSON metadata", "附加 JSON 元数据"},
	"flag.subagent":                         {"Eve subagent", "Eve 子 Agent"},
	"flag.all":                              {"Equivalent to --skill '*' --agent '*' -y", "等价于 --skill '*' --agent '*' -y"},
	"flag.full_depth":                       {"Search all subdirectories", "搜索所有子目录"},
	"flag.adoption_target":                  {"Exact External Installation target as JSON", "精确的外部安装目标 JSON"},
	"flag.adoption_preflight":               {"Review content matches without changing files", "只审阅内容匹配而不修改文件"},
	"flag.export_coordinate":                {"Private Local Skill coordinate", "私有本地 Skill 坐标"},
	"flag.export_version":                   {"Immutable Local Skill version", "不可变的本地 Skill 版本"},
	"flag.export_destination":               {"Destination ZIP path", "目标 ZIP 路径"},
	"error.skill_required":                  {"the first implementation slice requires --skill", "首个实现切片要求显式指定 --skill"},
	"error.no_agent":                        {"no Agent detected; specify one with --agent, or use -y to select all Agents", "没有检测到 Agent，请使用 --agent 指定目标；-y 将选择全部 Agent"},
	"add.success":                           {"Installed %s@%s to %d Agent target(s) (%s)\n", "已安装 %s@%s 到 %d 个 Agent 目标（%s）\n"},
	"plan.preflight.success":                {"Planned %d target(s): %d create, %d skip\n", "已规划 %d 个目标：%d 个创建，%d 个跳过\n"},
	"plan.execution.success":                {"Installed %d target(s), skipped %d, failed %d\n", "已安装 %d 个目标，跳过 %d 个，失败 %d 个\n"},
	"install.success":                       {"Restored %d Skill(s) from the lockfile\n", "已按照锁文件恢复 %d 个 Skill\n"},
	"list.empty":                            {"No installed Skills found", "未找到已安装的 Skill"},
	"remove.success":                        {"Removed %d Agent installation binding(s)\n", "已移除 %d 个 Agent 安装绑定\n"},
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
	mu.Unlock()
}

func detect() string {
	if value := strings.TrimSpace(os.Getenv("SKILLSGO_LANG")); value != "" {
		return value
	}
	for _, key := range []string{"LC_ALL", "LC_MESSAGES", "LANG"} {
		if value := strings.TrimSpace(os.Getenv(key)); value != "" {
			return strings.Split(value, ".")[0]
		}
	}
	if tag, err := systemlocale.Detect(); err == nil {
		return tag.String()
	}
	return language.English.String()
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
