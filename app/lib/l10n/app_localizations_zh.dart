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
  String get relocateProject => '重新定位';

  @override
  String get removeFromList => '从列表移除';

  @override
  String removeProjectTitle(String name) {
    return '从 SkillsGo 移除 $name？';
  }

  @override
  String get removeProjectDescription =>
      '只会移除 App 中的引用。SkillsGo 不会修改或删除该目录中的任何文件。';

  @override
  String projectRailUnavailable(String name) {
    return '$name — 不可用';
  }

  @override
  String emptyProjectTitle(String name) {
    return '$name 中没有发现技能';
  }

  @override
  String get emptyProjectMessage =>
      '项目不需要是 Git 仓库，也不需要预先存在 SkillsGo 文件。准备好后可安装第一个技能。';

  @override
  String get projectMissingTitle => '项目目录不存在';

  @override
  String get projectMissingMessage => '目录可能已移动，或所在磁盘暂时离线。你可以重新定位，或仅移除 App 引用。';

  @override
  String get projectPermissionTitle => '需要项目目录权限';

  @override
  String get projectPermissionMessage =>
      'SkillsGo 无法检查这个已选择的根目录。请通过目录选择器重新定位并授予访问权限。';

  @override
  String get projectInaccessibleTitle => '项目目录无法访问';

  @override
  String get projectInaccessibleMessage => 'SkillsGo 已保留该项目引用。请检查路径或磁盘，然后重新定位。';

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
  String get searchLibrary => '搜索当前技能库视图';

  @override
  String get libraryNoMatches => '没有匹配的技能';

  @override
  String get libraryNoMatchesMessage => '尝试其他名称、来源、Agent、项目或版本。';

  @override
  String agentsSummary(int count) {
    return '$count 个 Agent';
  }

  @override
  String projectsSummary(int count) {
    return '$count 个项目';
  }

  @override
  String versionsSummary(int count) {
    return '$count 个版本';
  }

  @override
  String get registryManaged => 'Registry 托管';

  @override
  String get localManaged => '本地托管';

  @override
  String get externalInstallation => '外部安装';

  @override
  String get readOnly => '只读';

  @override
  String get unversioned => '无版本信息';

  @override
  String get supportingFiles => '支持文件';

  @override
  String get versionDivergence => '多版本并存';

  @override
  String get healthHealthy => '状态正常';

  @override
  String get healthMissing => '目标已缺失';

  @override
  String get healthReplaced => '目标已被替换';

  @override
  String get healthLocalModification => '存在本地修改';

  @override
  String get healthUnreadable => '目标不可读取';

  @override
  String get healthUndeclared => '未在项目中声明';

  @override
  String get healthWorkspaceUnreadable => '项目声明不可读取';

  @override
  String get healthLockMismatch => '锁文件不匹配';

  @override
  String get healthUnexpectedPath => '目标路径异常';

  @override
  String get healthReceiptMissing => '安装回执缺失';

  @override
  String get modeSymlink => '软链接';

  @override
  String get modeCopy => '复制';

  @override
  String get modeExternal => '外部';

  @override
  String get receiptPresent => '回执存在';

  @override
  String get receiptMissing => '回执缺失';

  @override
  String get receiptInvalid => '回执无效';

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
  String get localReadFailedMessage =>
      'SkillsGo 无法读取这个本地安装。请检查目标健康状态和文件访问权限后重试。';

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

  @override
  String get installSkill => '安装技能';

  @override
  String get installationPlanTitle => '选择安装目标';

  @override
  String get closeInstallationPlan => '关闭安装计划';

  @override
  String get installationPlanDescription =>
      '请选择明确的位置与 Agent 单元格；行列控件只是批量选择这些明确目标的快捷方式。';

  @override
  String get reviewInstallationPlan => '检查安装计划';

  @override
  String get reviewInstallationPlanDescription =>
      '在修改文件前，检查每个目标操作和 Workspace Lock 变更。';

  @override
  String get installationResults => '安装结果';

  @override
  String get installationResultsDescription =>
      '每个目标独立完成。你可以留在这里，或前往技能库查看已安装技能。';

  @override
  String get installationInProgress => '正在安装';

  @override
  String get locationAgentMatrix => '位置 × Agent';

  @override
  String targetsSelected(int count) {
    return '已选择 $count 个目标';
  }

  @override
  String get location => '位置';

  @override
  String get select => '选择';

  @override
  String selectTarget(String location, String agent) {
    return '为 $agent 选择 $location';
  }

  @override
  String selectLocationTargets(String location) {
    return '选择 $location 中所有可用目标';
  }

  @override
  String selectAgentTargets(String agent) {
    return '选择 $agent 的所有可用目标';
  }

  @override
  String get projectUnavailable => '项目不可用';

  @override
  String get installedCell => '已安装';

  @override
  String get unsupportedCell => '不可用';

  @override
  String reviewTargets(int count) {
    return '检查 $count 个目标';
  }

  @override
  String installSelectedTargets(int count) {
    return '安装 $count 个目标';
  }

  @override
  String get backToTargets => '返回目标选择';

  @override
  String get stayHere => '留在这里';

  @override
  String get viewInLibrary => '在技能库中查看';

  @override
  String planCreateCount(int count) {
    return '创建 $count 个';
  }

  @override
  String planSkipCount(int count) {
    return '跳过 $count 个';
  }

  @override
  String planReplaceCount(int count) {
    return '替换 $count 个';
  }

  @override
  String planConflictCount(int count) {
    return '冲突 $count 个';
  }

  @override
  String planRiskCount(int count) {
    return '风险阻止 $count 个';
  }

  @override
  String get refreshInstallationPlan => '应用解决方案';

  @override
  String get replaceVersionConflict => '替换这个目标中已安装的版本';

  @override
  String get replaceIdentityCollision => '替换这个目标中的不同技能身份';

  @override
  String get replaceLocalModification => '放弃本地修改并替换这个目标';

  @override
  String get sharedTargetConflict => '此路径由其他 Agent 目标共享';

  @override
  String sharedTargetConflictDescription(String agents) {
    return '返回目标矩阵并选择所有受影响的 Agent 后再替换：$agents';
  }

  @override
  String get replaceConflictingTarget => '替换冲突目标';

  @override
  String get confirmHighRiskArtifact => '确认高风险制品';

  @override
  String get confirmCriticalRiskArtifact => '确认覆盖严重风险';

  @override
  String get confirmRiskForSelectedTargets => '我已检查制品文件，并接受在所选目标中安装此风险制品';

  @override
  String get criticalRiskBlocked => '严重风险安装已被阻止';

  @override
  String get criticalRiskOverrideDisabled => '请先在设置中启用显式的严重风险覆盖策略，才能继续此计划。';

  @override
  String get workspaceLockChanges => 'Workspace Lock 变更';

  @override
  String get noWorkspaceLockChanges => '不会修改 Workspace Lock 文件。';

  @override
  String lockVersionChange(String from, String to) {
    return '$from → $to';
  }

  @override
  String get notPresent => '尚不存在';

  @override
  String get planActionCreate => '创建';

  @override
  String get planActionReplace => '替换';

  @override
  String get planActionSkip => '跳过';

  @override
  String get planActionConflict => '冲突';

  @override
  String get planActionBlockedByRisk => '因风险阻止';

  @override
  String installationResultSummary(int succeeded, int failed) {
    return '已安装 $succeeded 个目标，$failed 个失败';
  }

  @override
  String get installationProgressTitle => '正在安装';

  @override
  String installationProgressSummary(int finished, int total) {
    return '已完成 $finished/$total 个目标';
  }

  @override
  String get targetWaiting => '等待中';

  @override
  String get targetRunning => '正在安装';

  @override
  String retryFailedTargets(int count) {
    return '重试 $count 个失败目标';
  }

  @override
  String get targetSucceeded => '已安装';

  @override
  String get targetSkipped => '已跳过';

  @override
  String get targetConflict => '冲突';

  @override
  String get targetFailed => '失败';

  @override
  String get targetPathExists => '目标路径已有其他内容。';

  @override
  String get targetBlockedByRisk => '当前风险策略已阻止这个目标。';

  @override
  String get targetInstallFailed => '无法将技能写入这个目标。';

  @override
  String get targetWorkspaceUpdateFailed => '技能已写入，但无法更新对应的 Workspace 文件。';

  @override
  String get installationPlanFailed => '安装计划无法继续';
}
