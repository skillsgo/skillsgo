// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get discover => '发现';

  @override
  String get library => '技能库';

  @override
  String get settings => '设置';

  @override
  String get openSettings => '打开设置';

  @override
  String get cliNeedsAttention => 'SkillsGo CLI 需要处理后才能使用。';

  @override
  String get cliMissingBundled => '内置的 SkillsGo CLI 缺失或无法运行。请重新安装 SkillsPlay。';

  @override
  String get cliDamagedBundled =>
      '内置的 SkillsGo CLI 返回了无效的启动响应。请重新安装 SkillsPlay。';

  @override
  String get cliIncompatibleBundled =>
      '内置的 SkillsGo CLI 与当前 SkillsPlay 版本不兼容。请更新或重新安装应用。';

  @override
  String get officialIndex => 'SkillsGo Registry';

  @override
  String get discoverTitle => '找到下一步所需的技能。';

  @override
  String get searchSkills => '搜索技能…';

  @override
  String get search => '搜索';

  @override
  String get offlineTitle => '当前处于离线状态';

  @override
  String get searchFailedTitle => '搜索遇到问题';

  @override
  String get tryAgain => '重试';

  @override
  String get searchEmptyTitle => '搜索，而不是漫无目的地浏览。';

  @override
  String get searchEmptyMessage => 'SkillsPlay 不提供信息流或排行榜。请输入你需要的能力。';

  @override
  String get noSkillsTitle => '没有找到技能';

  @override
  String get noSkillsMessage => '请尝试更宽泛的关键词或检查拼写。';

  @override
  String get focusSearch => '回到搜索框';

  @override
  String openSkill(String name) {
    return '打开 $name';
  }

  @override
  String installs(String count) {
    return '$count 次安装';
  }

  @override
  String get detailFailedTitle => '无法加载此技能';

  @override
  String get retry => '重试';

  @override
  String get backToSearch => '返回搜索';

  @override
  String get installForCodex => '安装到 Codex';

  @override
  String get cliNotDetected => 'skills（未检测到）';

  @override
  String get snapshotFiles => '快照文件';

  @override
  String get executableRisk => '此快照包含脚本或可执行内容。请在安装前检查文件；SkillsPlay 不会对其进行安全审计。';

  @override
  String removeTitle(String name) {
    return '移除 $name？';
  }

  @override
  String get removeDescription => 'SkillsGo 将移除此用户级 Skill，Codex 将无法再使用它。';

  @override
  String skillFact(String name) {
    return '技能：$name';
  }

  @override
  String get scopeGlobal => '范围：全局';

  @override
  String get agentImpactCodex => '影响的 Agent：Codex';

  @override
  String get removeSkill => '移除技能';

  @override
  String get globalCodex => '全局 · Codex';

  @override
  String get yourLibrary => '你的技能库';

  @override
  String get checking => '正在检查…';

  @override
  String get checkUpdates => '检查更新';

  @override
  String get refresh => '刷新';

  @override
  String get libraryUnavailable => '技能库暂不可用';

  @override
  String get libraryEmpty => '技能库为空';

  @override
  String get libraryEmptyMessage => '从“发现”安装技能后，它会显示在这里。';

  @override
  String get notLinked => '未连接';

  @override
  String get update => '更新';

  @override
  String removeNamed(String name) {
    return '移除 $name';
  }

  @override
  String get backToLibrary => '返回技能库';

  @override
  String get remove => '移除';

  @override
  String get localReadFailed => '无法读取此技能';

  @override
  String get localConfiguration => '本地配置';

  @override
  String get officialCli => 'SkillsGo CLI';

  @override
  String get ready => '就绪';

  @override
  String get unknown => '未知';

  @override
  String get missing => '缺失';

  @override
  String get incompatible => '版本不兼容';

  @override
  String get detecting => '正在检测…';

  @override
  String get customCliPath => '自定义可执行文件路径';

  @override
  String get saveAndDetect => '保存并检测';

  @override
  String get detectAgain => '重新检测';

  @override
  String get clearCustomPath => '清除自定义路径';

  @override
  String get privacyProvenance => '隐私与来源说明';

  @override
  String get privacySummary =>
      'SkillsPlay 不保存搜索记录或持久化命令日志。内置 CLI 始终保留在 App 内，不会安装到系统 PATH。';

  @override
  String get privacyAffiliation =>
      '匿名安装遥测由 SkillsGo 设置控制。SkillsPlay 与 OpenAI 或 Codex 不存在官方隶属关系。';

  @override
  String get commandCompleted => '命令执行完成';

  @override
  String get commandFailed => '命令执行失败';

  @override
  String commandExit(int code) {
    return '退出码 $code · 展开查看本次会话日志';
  }

  @override
  String get command => '命令';

  @override
  String get cancel => '取消';

  @override
  String get updateUnknown => '未知';

  @override
  String get updateChecking => '检查中';

  @override
  String get upToDate => '已是最新';

  @override
  String get updateAvailable => '可更新';

  @override
  String get updateUnavailable => '无法检查';

  @override
  String get updateCheckFailed => '检查失败';
}
