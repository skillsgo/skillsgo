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
  String get cliMissingBundled => '内置的 SkillsGo CLI 缺失或无法运行。请重新安装 SkillsGo。';

  @override
  String get cliDamagedBundled => '内置的 SkillsGo CLI 返回了无效的启动响应。请重新安装 SkillsGo。';

  @override
  String get cliIncompatibleBundled =>
      '内置的 SkillsGo CLI 与当前 SkillsGo 版本不兼容。请更新或重新安装应用。';

  @override
  String get officialIndex => 'SkillsGo Registry';

  @override
  String get discoverTitle => '找到下一步所需的技能。';

  @override
  String get searchSkills => '搜索技能…';

  @override
  String get search => '搜索';

  @override
  String get ranking => '排行';

  @override
  String get trending => '趋势';

  @override
  String get hot => '热门';

  @override
  String get discoverNavigation => '发现导航';

  @override
  String get allTimeRanking => '历史排行';

  @override
  String get trendingNow => '最近 24 小时趋势';

  @override
  String get hotNow => '当前热门';

  @override
  String get allTimeDescription => '按历史累计有效安装量排列公开 Skill。';

  @override
  String get trendingDescription => '按最近 24 小时内的有效安装量排列公开 Skill。';

  @override
  String get hotDescription => '按短期安装速度及其变化排列公开 Skill。';

  @override
  String get offlineTitle => '当前处于离线状态';

  @override
  String get offlineMessage => 'SkillsGo 无法连接 Registry。请检查网络、代理或 Registry 地址。';

  @override
  String get searchFailedTitle => '搜索遇到问题';

  @override
  String get validationTitle => '请检查请求';

  @override
  String get validationMessage => 'Registry 拒绝了该请求，请检查查询内容后重试。';

  @override
  String get serverTitle => 'Registry 暂不可用';

  @override
  String get serverMessage => 'Registry 无法完成该请求，请稍后重试。';

  @override
  String get timeoutTitle => 'Registry 响应超时';

  @override
  String get timeoutMessage => 'Registry 响应时间过长，请检查连接或重试。';

  @override
  String get invalidResponseTitle => 'Registry 响应不受支持';

  @override
  String get invalidResponseMessage =>
      '该 Registry 返回了 SkillsGo 无法读取的响应，请检查其版本与协议兼容性。';

  @override
  String get tryAgain => '重试';

  @override
  String get searchEmptyTitle => '搜索，而不是漫无目的地浏览。';

  @override
  String get searchEmptyMessage => '请输入能力、来源或任务，搜索公开 Registry。';

  @override
  String get noSkillsTitle => '没有找到技能';

  @override
  String get noSkillsMessage => '请尝试更宽泛的关键词或检查拼写。';

  @override
  String get focusSearch => '回到搜索框';

  @override
  String get collectionEmptyTitle => '该集合中暂无 Skill';

  @override
  String get collectionEmptyMessage => 'Registry 返回了空集合，可在产生新的安装活动后重试。';

  @override
  String get loadMore => '加载更多';

  @override
  String get install => '安装';

  @override
  String get installToMoreTargets => '安装到更多目标';

  @override
  String localTargets(int count) {
    return '$count 个本地目标';
  }

  @override
  String allTimeMetric(String count) {
    return '历史安装 $count 次';
  }

  @override
  String trendingMetric(String count) {
    return '24 小时安装 $count 次';
  }

  @override
  String hotMetric(String value, String change) {
    return '本小时 $value · 变化 $change';
  }

  @override
  String get trustUnverified => '未验证';

  @override
  String get trustCommunityVerified => '社区验证';

  @override
  String get trustPublisherVerified => '发布者验证';

  @override
  String get trustOfficial => '官方';

  @override
  String get trustWarned => '已警告';

  @override
  String get trustDelisted => '已下架';

  @override
  String get riskUnknown => '风险未知';

  @override
  String get riskLow => '低风险';

  @override
  String get riskMedium => '中风险';

  @override
  String get riskHigh => '高风险';

  @override
  String get riskCritical => '严重风险';

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
  String get detailLoading => '正在加载可审计的技能详情';

  @override
  String get artifactUnavailableTitle => '制品暂不可用';

  @override
  String get artifactUnavailableMessage => 'Registry 无法提供该不可变制品。你可以重试，或检查其他版本。';

  @override
  String get detailInvalidTitle => '不支持该制品元数据';

  @override
  String get detailInvalidMessage => 'Registry 返回的审计元数据不完整或格式错误。请检查兼容性后重试。';

  @override
  String get instructionsTab => '技能指令';

  @override
  String get manifestTab => 'Manifest';

  @override
  String immutableVersionLabel(String version) {
    return '不可变版本 $version';
  }

  @override
  String commitIdentity(String sha) {
    return 'Commit $sha';
  }

  @override
  String treeIdentity(String sha) {
    return '目录树 $sha';
  }

  @override
  String contentIdentity(String digest) {
    return '内容 $digest';
  }

  @override
  String get trustDoesNotProveSafety =>
      '发布者可信度只验证所有权或维护关系，并不证明制品安全。风险会针对该不可变版本单独评估。';

  @override
  String get knownInstallationTargets => '已知安装目标';

  @override
  String targetSummary(String scope, String agent, String version) {
    return '$scope / $agent · $version';
  }

  @override
  String get userScope => '用户范围';

  @override
  String get projectScope => '项目';

  @override
  String get fileContentUnavailable => '二进制文件或无法预览';

  @override
  String get fileContentTruncated => 'Registry 已按安全大小限制截断预览。';

  @override
  String riskEvidence(String paths) {
    return '可执行内容证据：$paths';
  }

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
  String get executableRisk => '此快照包含脚本或可执行内容。请在安装前检查文件；SkillsGo 不会对其进行安全审计。';

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
  String get libraryNavigation => '技能库导航';

  @override
  String get all => '所有';

  @override
  String get addProject => '添加项目';

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
  String get settingsNavigation => '设置导航';

  @override
  String get general => '通用';

  @override
  String get agents => 'Agents';

  @override
  String get registry => 'Registry';

  @override
  String get installationPolicy => '安装策略';

  @override
  String get storage => '存储';

  @override
  String get about => '关于';

  @override
  String get generalSettingsTitle => '桌面偏好设置';

  @override
  String get generalSettingsDescription => 'SkillsGo 跟随系统语言与辅助功能偏好，包括减少动态效果。';

  @override
  String get agentsSettingsTitle => 'Agent 运行环境';

  @override
  String get registrySettingsTitle => 'Registry 地址';

  @override
  String get registrySettingsDescription =>
      '使用官方 Registry，或实现相同 SkillsGo 协议的 HTTP(S) 自托管地址。';

  @override
  String get testConnection => '测试连接';

  @override
  String get saveOrigin => '保存地址';

  @override
  String get resetDefault => '恢复默认';

  @override
  String get connectionReady => '连接正常';

  @override
  String get connectionFailed => '连接失败';

  @override
  String get registryInvalidOrigin => '请输入不含账号密码、查询参数或片段的有效 HTTP(S) 地址。';

  @override
  String registryHttpFailure(int status) {
    return 'Registry 返回了 HTTP $status。请检查地址与服务端配置。';
  }

  @override
  String get registryInvalidProtocol => '服务端没有返回 SkillsGo Registry 搜索协议。';

  @override
  String get registryInvalidJson => 'Registry 返回了无效 JSON。';

  @override
  String get registryConnectionFailure => '无法连接 Registry。请检查地址、网络、代理和 TLS 配置。';

  @override
  String get registryConnectionTimeout => 'Registry 连接超时。请检查网络或重试。';

  @override
  String get riskPolicyTitle => '个人风险策略';

  @override
  String get confirmHighRisk => '高风险必须额外确认';

  @override
  String get confirmHighRiskDescription => '安装高风险制品前始终要求一次额外确认。';

  @override
  String get allowCriticalOverride => '允许显式覆盖严重风险阻止';

  @override
  String get allowCriticalOverrideDescription =>
      '严重风险制品默认保持阻止。启用后仅提供单独的手动覆盖入口。';

  @override
  String get storageSettingsTitle => '内容寻址 Store';

  @override
  String get storageHealthy => '可读取';

  @override
  String get storageNotInitialized => '尚未初始化';

  @override
  String get storageUnavailable => '不可用';

  @override
  String get storagePathUnavailable => 'CLI 诊断就绪后才能显示 Store 路径。';

  @override
  String get storageHealthyDescription => 'CLI 可以读取 Store，且本次检查不会修改其中内容。';

  @override
  String get storageNotInitializedDescription => 'Store 尚不存在，本次检查没有创建它。';

  @override
  String get storageUnavailableDescription => 'CLI 无法读取 Store，请检查目录权限及其父目录。';

  @override
  String get storageInvalidResponse => '内置 CLI 返回了不支持的诊断响应。';

  @override
  String get aboutSettingsTitle => '产品兼容性';

  @override
  String get appVersion => 'App 版本';

  @override
  String get cliVersion => '内置 CLI 版本';

  @override
  String get compatible => '兼容';

  @override
  String get registryOriginSaved => 'Registry 地址已保存并立即应用。';

  @override
  String get policySaved => '安装策略已保存。';

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
  String get agentInstalled => '已安装';

  @override
  String get agentSupported => '已支持';

  @override
  String agentCatalogSummary(int installed, int supported) {
    return '已安装 $installed 个 · 支持 $supported 个';
  }

  @override
  String get agentDetectedDescription => '已检测到 Agent，可在其支持的范围内安装技能。';

  @override
  String get agentSupportedDescription =>
      'SkillsGo 已支持，但尚未检测到安装。请先安装该 Agent，或使用项目级目标。';

  @override
  String agentUserTarget(String path) {
    return '用户级目标：$path';
  }

  @override
  String get agentInspectionFailed => 'Agent 检测数据不可用，请重新检测。';

  @override
  String get noInstalledAgentsTitle => '未检测到已安装的 Agent';

  @override
  String get noInstalledAgentsMessage =>
      '你仍可继续浏览该技能，但当前没有可用安装目标。请先安装一个受支持的 Agent，然后重新检测。';

  @override
  String get clearCustomPath => '清除自定义路径';

  @override
  String get privacyProvenance => '隐私与来源说明';

  @override
  String get privacySummary =>
      'SkillsGo 不保存搜索记录或持久化命令日志。内置 CLI 始终保留在 App 内，不会安装到系统 PATH。';

  @override
  String get privacyAffiliation =>
      '匿名安装遥测由 SkillsGo 设置控制。SkillsGo 与 OpenAI 或 Codex 不存在官方隶属关系。';

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
