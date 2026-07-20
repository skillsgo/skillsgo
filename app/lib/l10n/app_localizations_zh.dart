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
  String get discoverSkills => '多会一点，总是好的。';

  @override
  String get library => '已安装';

  @override
  String get settings => '设置';

  @override
  String get openSettings => '打开设置';

  @override
  String get cliNeedsAttention => 'SkillsGo 的必要组件需要处理。';

  @override
  String get cliMissingBundled =>
      'SkillsGo 的必要组件缺失或无法启动。请重新安装 SkillsGo 以恢复该组件。';

  @override
  String get cliDamagedBundled => 'SkillsGo 的必要组件已损坏。请重新安装 SkillsGo 以恢复该组件。';

  @override
  String get cliIncompatibleBundled =>
      'SkillsGo 的必要组件与当前应用版本不匹配。请更新或重新安装 SkillsGo。';

  @override
  String get officialIndex => 'SkillsGo Hub';

  @override
  String get discoverTitle => '找到下一步所需的技能。';

  @override
  String get skillsLeaderboard => '多会一点，总是好的。';

  @override
  String searchResultsFor(String query) {
    return '“$query”的搜索结果';
  }

  @override
  String get searchSkills => '搜索技能或粘贴 Git 链接…';

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
  String get offlineTitle => '无法连接到 SkillsGo';

  @override
  String get offlineMessage => '请检查网络连接后重试。如果你使用了代理或自定义服务地址，请前往设置检查。';

  @override
  String get searchFailedTitle => '搜索遇到问题';

  @override
  String get validationTitle => '请检查输入内容';

  @override
  String get validationMessage => 'SkillsGo 无法处理这项请求。请检查输入内容后重试。';

  @override
  String get serverTitle => '服务暂时不可用';

  @override
  String get serverMessage => 'SkillsGo 暂时无法完成这项请求，请稍后重试。';

  @override
  String get timeoutTitle => '等待时间过长';

  @override
  String get timeoutMessage => '服务未能及时响应。请检查网络连接或重试。';

  @override
  String get invalidResponseTitle => 'SkillsGo 需要更新';

  @override
  String get invalidResponseMessage => '当前版本的 SkillsGo 无法读取服务返回的内容。请更新应用后重试。';

  @override
  String get invalidLocalDataTitle => '无法读取已安装的技能';

  @override
  String get invalidLocalDataMessage =>
      '部分本地安装信息已损坏或不兼容。请更新或重新安装 SkillsGo 后重试。';

  @override
  String get tryAgain => '重试';

  @override
  String get searchEmptyTitle => '搜索，而不是漫无目的地浏览。';

  @override
  String get searchEmptyMessage => '请输入能力、来源或任务，搜索公开技能。';

  @override
  String get noSkillsTitle => '没有找到技能';

  @override
  String get noSkillsMessage => '请尝试更宽泛的关键词或检查拼写。';

  @override
  String get focusSearch => '回到搜索框';

  @override
  String get skillsFromLink => '这个链接中的技能';

  @override
  String skillCount(int count) {
    return '$count 个技能';
  }

  @override
  String sourceResultsSummary(String source, int count) {
    return '来自 $source 的 $count 个技能';
  }

  @override
  String get sourceSearchEmptyTitle => '可以查看这个链接';

  @override
  String sourceSearchEmptyMessage(String source) {
    return '当前搜索结果中没有 $source。下一步 SkillsGo 可以直接查看这个链接中的技能。';
  }

  @override
  String get inspectSource => '查看链接中的技能';

  @override
  String get collectionEmptyTitle => '该集合中暂无 Skill';

  @override
  String get collectionEmptyMessage => '这里暂时没有内容。产生更多安装活动后可以重试。';

  @override
  String get loadMore => '加载更多';

  @override
  String get install => '安装';

  @override
  String get installAll => '安装所有技能';

  @override
  String get latestCommit => '最新提交';

  @override
  String get installToMoreTargets => '安装到更多位置';

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
  String get artifactUnavailableMessage => '当前无法获取这个版本。你可以重试或选择其他版本。';

  @override
  String get detailInvalidTitle => '不支持该制品元数据';

  @override
  String get detailInvalidMessage => '这个技能的部分信息不完整或无法读取。请更新 SkillsGo 后重试。';

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
  String get installationRange => '已安装范围';

  @override
  String get targetDetails => '查看目标详情';

  @override
  String get hideTargetDetails => '收起目标详情';

  @override
  String installedVersionLabel(String version) {
    return '版本 $version';
  }

  @override
  String targetSummary(String scope, String agent, String version) {
    return '$scope / $agent · $version';
  }

  @override
  String get projectScope => '项目';

  @override
  String get fileContentUnavailable => '二进制文件或无法预览';

  @override
  String get fileContentTruncated => 'Hub 已按安全大小限制截断预览。';

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
  String get globalCodex => '全局 · Codex';

  @override
  String get yourLibrary => '已经会的，都在这里。';

  @override
  String get libraryNavigation => '已安装技能导航';

  @override
  String get all => '所有';

  @override
  String get allSkills => '全部 Skills';

  @override
  String get updatesOnly => '有更新';

  @override
  String get allAgents => '所有智能体';

  @override
  String get allProjects => '所有项目';

  @override
  String get specificProject => '指定项目';

  @override
  String get userScope => '全局安装';

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
  String get emptyProjectTitle => '还没有技能';

  @override
  String get browseSkills => '浏览技能';

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
  String get libraryUnavailable => '已安装技能暂不可用';

  @override
  String get libraryEmpty => '还没有安装技能';

  @override
  String get libraryEmptyMessage => '从“发现”安装技能后，它会显示在这里。';

  @override
  String get searchLibrary => '搜索已安装技能';

  @override
  String get libraryNoMatches => '没有匹配的技能';

  @override
  String get libraryNoMatchesMessage => '尝试其他名称、来源、智能体、项目或版本。';

  @override
  String agentsSummary(int count) {
    return '$count 个智能体';
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
  String get hubManaged => 'Hub 托管';

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
  String get modeSymlink => '软链接';

  @override
  String get modeCopy => '复制';

  @override
  String get modeExternal => '外部';

  @override
  String get notLinked => '未连接';

  @override
  String get update => '更新';

  @override
  String get backToLibrary => '返回已安装技能';

  @override
  String get remove => '移除';

  @override
  String get manageTargets => '管理范围';

  @override
  String skillsSelected(int count) {
    return '已选择 $count 项';
  }

  @override
  String get clearSelection => '清除选择';

  @override
  String get selectCurrentResults => '选择当前结果';

  @override
  String get clearCurrentResultSelection => '清除当前结果选择';

  @override
  String get manageTargetsTitle => '管理安装目标';

  @override
  String get manageTargetsDescription => '为每个目标选择精确操作；未选择的目标不会改变。';

  @override
  String targetActionsSelected(int selected, int total) {
    return '已选择 $selected/$total 个目标';
  }

  @override
  String get repairTarget => '修复';

  @override
  String get confirmRemoveTarget => '确认移除';

  @override
  String get applyTargetActions => '执行所选操作';

  @override
  String get managementProgressTitle => '正在执行目标操作';

  @override
  String get managementResultsTitle => '目标操作结果';

  @override
  String managementResultSummary(int succeeded, int failed) {
    return '$succeeded 个成功，$failed 个失败';
  }

  @override
  String get workspaceOwnershipChanges =>
      '所选项目操作将更新 skillsgo.mod 和 skillsgo.sum。';

  @override
  String get targetContentPreserved => '目标当前内容会被保留。';

  @override
  String get localReadFailed => '无法读取此技能';

  @override
  String get localReadFailedMessage =>
      'SkillsGo 无法读取这个已安装的技能。请确认其文件夹存在且可以访问，然后重试。';

  @override
  String get localConfiguration => 'SKILLSGO 设置';

  @override
  String get settingsNavigation => '设置导航';

  @override
  String get general => '个性化';

  @override
  String get agents => '智能体';

  @override
  String get hub => 'Hub';

  @override
  String get installationPolicy => '安装策略';

  @override
  String get storage => '存储';

  @override
  String get colorScheme => '颜色预览';

  @override
  String get about => '关于';

  @override
  String get colorSchemeInspectorTitle => 'Material 生成色彩角色';

  @override
  String get skillsColorTokensTitle => 'SkillsGo 语义颜色';

  @override
  String get skillsColorTokensDescription =>
      '由 Radix Sand 色阶构建、采用 Primer 语义组织的产品颜色；Folder 是独立的空间层级。';

  @override
  String get colorSchemeInspectorDescription =>
      '展示当前种子色生成的所有非废弃 ColorScheme Token。点击色块即可复制 HEX。';

  @override
  String get colorSchemePairPreview => '语义颜色组合';

  @override
  String get colorSchemePairPreviewDescription =>
      '将前景色和背景色放在一起渲染，直接检查对比度与信息层级。';

  @override
  String get colorSchemeComponentPreview => '组件实景';

  @override
  String get colorSchemeComponentPreviewDescription =>
      '使用当前预览 Scheme 渲染典型 Material 控件。';

  @override
  String get colorSchemeSampleTitle => '技能卡片标题';

  @override
  String get colorSchemeSampleBody => '辅助说明使用 onSurfaceVariant。';

  @override
  String get colorSchemeCopied => '已复制';

  @override
  String get colorSchemeSampleGlyphs => '字 Aa 123';

  @override
  String get colorSchemeGroupPrimary => '主色';

  @override
  String get colorSchemeGroupPrimaryDescription => '主要强调、容器与固定主色角色。';

  @override
  String get colorSchemeGroupSecondary => '辅色';

  @override
  String get colorSchemeGroupSecondaryDescription => '辅助强调与固定辅色角色。';

  @override
  String get colorSchemeGroupTertiary => '第三色';

  @override
  String get colorSchemeGroupTertiaryDescription => '与主色、辅色形成对比的补充强调色。';

  @override
  String get colorSchemeGroupSurface => '表面';

  @override
  String get colorSchemeGroupSurfaceDescription => '页面、容器、层级与前景内容的颜色体系。';

  @override
  String get colorSchemeGroupUtility => '轮廓与辅助';

  @override
  String get colorSchemeGroupUtilityDescription => '边界、阴影、遮罩和反色表面角色。';

  @override
  String get colorSchemeGroupError => '错误';

  @override
  String get colorSchemeGroupErrorDescription => '错误操作、消息和容器角色。';

  @override
  String get colorSchemeUsagePrimary => '主要操作、焦点和高强调装饰。';

  @override
  String get colorSchemeUsageSecondary => '辅助操作和中等强调装饰。';

  @override
  String get colorSchemeUsageTertiary => '补充主色与辅色的对比强调色。';

  @override
  String colorSchemeUsageContentOn(String token) {
    return '显示在 $token 上的文字和图标。';
  }

  @override
  String colorSchemeUsageContainer(String family) {
    return '用于选中态与强调的低强调 $family 容器。';
  }

  @override
  String colorSchemeUsageFixed(String family) {
    return '不随明暗模式变化的固定 $family 容器。';
  }

  @override
  String colorSchemeUsageFixedDim(String family) {
    return '较暗的固定 $family 容器，不随明暗模式变化。';
  }

  @override
  String colorSchemeUsageFixedContent(String family) {
    return '固定 $family 容器上的高强调内容。';
  }

  @override
  String colorSchemeUsageFixedVariantContent(String family) {
    return '固定 $family 容器上的低强调内容。';
  }

  @override
  String get colorSchemeUsageSurface => '页面和大型区域的基础表面。';

  @override
  String get colorSchemeUsageSurfaceDim => '表面色阶中较暗的基础表面。';

  @override
  String get colorSchemeUsageSurfaceBright => '表面色阶中较亮的基础表面。';

  @override
  String colorSchemeUsageSurfaceElevation(String level) {
    return '$level 层级的表面容器。';
  }

  @override
  String get colorSchemeElevationLowest => '最低';

  @override
  String get colorSchemeElevationLow => '较低';

  @override
  String get colorSchemeElevationDefault => '默认';

  @override
  String get colorSchemeElevationHigh => '较高';

  @override
  String get colorSchemeElevationHighest => '最高';

  @override
  String get colorSchemeUsageOnSurface => '表面上的主要文字和图标。';

  @override
  String get colorSchemeUsageOnSurfaceVariant => '表面上的次要文字、标签和弱化图标。';

  @override
  String get colorSchemeUsageSurfaceTint => '从主色生成的 Material 层级着色。';

  @override
  String get colorSchemeUsageOutline => '醒目的边界和获得焦点的组件轮廓。';

  @override
  String get colorSchemeUsageOutlineVariant => '细微边界、分隔线和低强调轮廓。';

  @override
  String get colorSchemeUsageShadow => '悬浮表面的投影颜色。';

  @override
  String get colorSchemeUsageScrim => '用于弱化背景内容的模态遮罩。';

  @override
  String get colorSchemeUsageInverseSurface => '明暗强调反转的表面。';

  @override
  String get colorSchemeUsageInversePrimary => '显示在反色表面上的主色强调。';

  @override
  String get colorSchemeUsageError => '错误操作、状态与高强调反馈。';

  @override
  String get save => '保存';

  @override
  String get advancedSettings => '高级';

  @override
  String get remindersSettings => '提醒';

  @override
  String get remindersSettingsTitle => '提醒设置';

  @override
  String get remindersSettingsDescription => '选择要接收的提醒。';

  @override
  String get updateReminderTitle => '更新提醒';

  @override
  String get updateReminderDescription => '打开“已安装”时检查更新。';

  @override
  String get securityReminderTitle => '高风险提醒';

  @override
  String get securityReminderDescription => '发现已安装技能存在高风险或严重风险时提醒。';

  @override
  String availableUpdatesReminder(int count) {
    return '$count 个已安装技能有可用更新';
  }

  @override
  String get openAvailableUpdates => '打开“有更新”视图，查看并选择需要更新的技能。';

  @override
  String securityAdvisoriesReminder(int count) {
    return '$count 个已安装技能需要安全检查';
  }

  @override
  String get reviewInstalledSkills => '使用或更新前，请先查看这些技能的风险信息。';

  @override
  String get generalSettingsTitle => '让 SkillsGo 更适合你';

  @override
  String get generalSettingsDescription => '界面会自动跟随系统语言、辅助功能和动态效果偏好。';

  @override
  String get agentsSettingsTitle => '智能体运行环境';

  @override
  String get hubSettingsTitle => 'Hub 地址';

  @override
  String get hubSettingsDescription =>
      '使用官方 Hub，或实现相同 SkillsGo 协议的 HTTP(S) 自托管地址。';

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
  String get hubInvalidOrigin => '请输入不含账号密码、查询参数或片段的有效 HTTP(S) 地址。';

  @override
  String hubHttpFailure(int status) {
    return 'Hub 返回了 HTTP $status。请检查地址与服务端配置。';
  }

  @override
  String get hubInvalidProtocol => '服务端没有返回 SkillsGo Hub 搜索协议。';

  @override
  String get hubInvalidJson => 'Hub 返回了无效 JSON。';

  @override
  String get hubConnectionFailure => '无法连接 Hub。请检查地址、网络、代理和 TLS 配置。';

  @override
  String get hubConnectionTimeout => 'Hub 连接超时。请检查网络或重试。';

  @override
  String get riskPolicyTitle => '个人风险策略';

  @override
  String get riskPolicyDescription => '安全规则会在安装或更新技能时生效。';

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
  String get hubOriginSaved => 'Hub 地址已保存并立即应用。';

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
  String installedAgentsTitle(int count) {
    return '已安装 · $count';
  }

  @override
  String notInstalledAgentsTitle(int count) {
    return '未安装 · $count';
  }

  @override
  String get notInstalledAgentsDescription => 'SkillsGo 已支持，但尚未在这台 Mac 上检测到。';

  @override
  String agentDiscoveryRoots(String paths) {
    return '技能加载路径：$paths';
  }

  @override
  String get agentInspectionFailed => '智能体检测数据不可用，请重新检测。';

  @override
  String get noInstalledAgentsTitle => '未检测到已安装的智能体';

  @override
  String get noInstalledAgentsMessage =>
      '你仍可继续浏览该技能，但当前没有可用安装目标。请先安装一个受支持的智能体，然后重新检测。';

  @override
  String get clearCustomPath => '清除自定义路径';

  @override
  String get privacyProvenance => '隐私与来源说明';

  @override
  String get privacySummary => '你的搜索记录不会被保存，SkillsGo 也不会保留命令日志。';

  @override
  String get language => '语言';

  @override
  String get personalizationTheme => '主题';

  @override
  String get folderColorTheme => '主题色';

  @override
  String get folderColorThemeDescription => '挑一个喜欢的颜色，SkillsGo 会自动生成协调的界面配色。';

  @override
  String get brandNameNeteaseCloudMusic => '网易云音乐';

  @override
  String get brandNameRaspberryPi => '树莓派';

  @override
  String get brandNameChinaEasternAirlines => '中国东方航空';

  @override
  String get brandNameNvidia => '英伟达';

  @override
  String get brandNameTaobao => '淘宝';

  @override
  String get brandNameBitcoin => '比特币';

  @override
  String get appearanceMode => '模式';

  @override
  String get appearanceModeDescription => '跟随系统外观，或始终使用浅色或深色主题。';

  @override
  String get followSystem => '跟随系统';

  @override
  String get lightMode => '浅色';

  @override
  String get darkMode => '深色';

  @override
  String get wallpaper => '壁纸';

  @override
  String get wallpaperDescription => '选择一张天体背景，设置后会立即显示在 Folder 后方。';

  @override
  String get wallpaperSun => '太阳';

  @override
  String get wallpaperMercury => '水星';

  @override
  String get wallpaperVenus => '金星';

  @override
  String get wallpaperEarth => '地球';

  @override
  String get wallpaperMars => '火星';

  @override
  String get wallpaperJupiter => '木星';

  @override
  String get wallpaperSaturn => '土星';

  @override
  String get wallpaperUranus => '天王星';

  @override
  String get wallpaperNeptune => '海王星';

  @override
  String get wallpaperPluto => '冥王星';

  @override
  String get wallpaperMoon => '月球';

  @override
  String folderThemeChoice(String theme) {
    return '$theme Folder 主题';
  }

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
  String get installLocationTitle => '设置技能安装位置';

  @override
  String get userLevel => '用户级别';

  @override
  String get projectLevel => '项目级别';

  @override
  String get projects => '项目';

  @override
  String get loading => '正在加载…';

  @override
  String get repositoryParsing => '正在解析 Repository…';

  @override
  String userInstallSummary(int agents) {
    return '将在用户级别供 $agents 个智能体使用';
  }

  @override
  String projectInstallSummary(int projects, int agents) {
    return '$projects 个项目 · $agents 个智能体';
  }

  @override
  String get installationResults => '安装结果';

  @override
  String get installationInProgress => '正在安装';

  @override
  String get installationSucceeded => '安装完成';

  @override
  String get installationSucceededMessage => '技能现在可在所选位置使用。';

  @override
  String get projectUnavailable => '项目不可用';

  @override
  String get installedCell => '已安装';

  @override
  String get unsupportedCell => '不可用';

  @override
  String get confirmInstall => '确认安装';

  @override
  String installAllRepositorySkills(int count) {
    return '安装仓库所有技能（$count）';
  }

  @override
  String get installAllSkillsTo => '安装所有技能到';

  @override
  String installRepositorySkills(String repository, int count) {
    return '安装 $repository 全部技能（$count）';
  }

  @override
  String installSkillTo(String skill) {
    return '安装 $skill 到';
  }

  @override
  String get availableInAllProjects => '所有项目';

  @override
  String get availableInSelectedProjects => '指定项目';

  @override
  String get usedBy => '用于智能体';

  @override
  String get backToTargets => '返回目标选择';

  @override
  String get stayHere => '留在这里';

  @override
  String get viewInLibrary => '查看已安装技能';

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
  String get replaceSkillIdCollision => '替换这个目标中的不同 Skill ID';

  @override
  String get replaceLocalModification => '放弃本地修改并替换这个目标';

  @override
  String get sharedTargetConflict => '此路径由其他智能体目标共享';

  @override
  String sharedTargetConflictDescription(String agents) {
    return '返回目标矩阵并选择所有受影响的智能体后再替换：$agents';
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
  String get workspaceManifestChanges => 'Workspace Manifest 变更';

  @override
  String get noWorkspaceManifestChanges => '不会修改 Workspace Manifest 文件。';

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
  String get updatePlanTitle => '选择要更新的目标';

  @override
  String get updatePlanDescription => '请选择明确的安装目标；未选择的智能体和项目不会改变。';

  @override
  String updateTargetsSelected(int selected, int available) {
    return '已选择 $selected/$available 个可更新目标';
  }

  @override
  String updateVersionChange(String fromVersion, String toVersion) {
    return '$fromVersion → $toVersion';
  }

  @override
  String sourceReference(String reference) {
    return '来源引用：$reference';
  }

  @override
  String get fixedVersionTarget => '已固定——没有可移动引用';

  @override
  String get currentVersionTarget => '已是最新版本';

  @override
  String get updateCheckTargetFailed => '更新检查失败';

  @override
  String get reconcileWorkspaceManifestTarget => '修复工作区清单';

  @override
  String get updateSelectedTargets => '更新所选目标';

  @override
  String get updateProgressTitle => '正在更新目标';

  @override
  String get updateResultsTitle => '更新结果';

  @override
  String updateProgressSummary(int finished, int total) {
    return '已完成 $finished/$total 个目标';
  }

  @override
  String retryFailedUpdates(int count) {
    return '重试 $count 个失败更新';
  }

  @override
  String get noUpdateableTargets => '所选目标没有可用更新。';

  @override
  String get closeUpdatePlan => '关闭';

  @override
  String get targetSucceeded => '已安装';

  @override
  String get targetSkipped => '已跳过';

  @override
  String get targetConflict => '冲突';

  @override
  String get targetFailed => '失败';

  @override
  String get targetFailureRetryable => '无法更改此位置，你可以重试。';

  @override
  String get targetFailureNeedsAttention => '请先处理此位置的问题，然后重试。';

  @override
  String get installationTargetFailureMessage => '此位置没有发生更改。请确认文件夹可用后重试。';

  @override
  String get workspacePersistenceFailureMessage =>
      'SkillsGo 无法保存项目设置，因此没有更改此位置。请确认项目文件夹可写后重试。';

  @override
  String get installationStateChangedMessage => '此位置在你确认期间发生了变化。请查看最新状态后重试。';

  @override
  String get updateTargetFailureMessage => '无法更新此位置，其他位置不受影响。你可以只重试这一项。';

  @override
  String get managementTargetFailureMessage => '无法在此位置完成操作，其他位置不受影响。你可以只重试这一项。';

  @override
  String get technicalDetails => '技术详情';

  @override
  String get targetPathExists => '此位置已有其他内容。';

  @override
  String get targetBlockedByRisk => '当前安全设置阻止了在此位置安装。';

  @override
  String get targetInstallFailed => '无法在此位置安装技能。';

  @override
  String get targetWorkspaceUpdateFailed => '技能已经安装，但无法更新项目设置。';

  @override
  String get installationPlanFailed => '安装计划无法继续';

  @override
  String get installationFailed => '安装未能完成';

  @override
  String get localSource => '本地来源';

  @override
  String get noDescriptionAvailable => '暂无描述';

  @override
  String moreCoverage(int count) {
    return '另外 $count 个安装位置';
  }

  @override
  String get batchTakeoverAction => '纳入 SkillsGo 管理';

  @override
  String batchTakeoverActionCount(int count) {
    return '纳入管理（$count）';
  }

  @override
  String get batchTakeoverChecking => '正在检查可纳入的技能…';

  @override
  String get batchTakeoverRetry => '重新检查可纳入技能';

  @override
  String batchTakeoverEligibleCount(int count) {
    return '$count 个可纳入管理';
  }

  @override
  String get batchTakeoverPending => '正在纳入管理…';

  @override
  String get batchTakeoverTitle => '将现有技能纳入 SkillsGo 管理？';

  @override
  String get batchTakeoverDescription =>
      'SkillsGo 只会创建本地管理记录，不会移动、覆盖或上传技能文件；不支持或确认后发生变化的项目将被跳过。';

  @override
  String get batchTakeoverConfirm => '纳入管理';

  @override
  String get batchTakeoverResultTitle => '已纳入管理';

  @override
  String batchTakeoverSummary(int takenOver, int skipped) {
    return '已纳入管理 $takenOver 个技能，跳过 $skipped 个。';
  }

  @override
  String get batchTakeoverClose => '关闭';

  @override
  String get installMoreTargets => '安装到更多位置';

  @override
  String get exportLocalSkill => '导出';

  @override
  String get exportLocalSkillDescription => '将这个本地技能导出为可移植的 ZIP 归档。';

  @override
  String get detailInstalls => '安装量';

  @override
  String get detailRepository => '仓库';

  @override
  String get detailStars => '星标';

  @override
  String get detailUpdated => '最近更新';

  @override
  String get detailArchiveSize => 'ZIP 大小';

  @override
  String get pathLabel => '项目路径';

  @override
  String get copyProjectPath => '复制项目路径';

  @override
  String get projectPathCopied => '项目路径已复制';

  @override
  String get onboardingWelcomeTitle => '欢迎使用 SkillsGo';

  @override
  String get onboardingWelcomeDescription => '发现、安装和管理所有智能体与项目中的 Skills。';

  @override
  String get onboardingDetectedAgents => '已检测到的智能体';

  @override
  String get onboardingNoAgents => '未检测到已安装的智能体，你仍然可以继续。';

  @override
  String get onboardingNext => '下一步';

  @override
  String get onboardingProjectsTitle => '添加你的项目';

  @override
  String get onboardingProjectsDescription => '选择你希望 SkillsGo 管理的项目。';

  @override
  String get onboardingAddProject => '现在添加';

  @override
  String get onboardingAddProjectLater => '或者稍后';

  @override
  String get onboardingStartUsing => '开始使用';

  @override
  String get onboardingBack => '返回';

  @override
  String get restartOnboardingTitle => '启动引导';

  @override
  String get restartOnboardingDescription => '重新查看首次启动引导，不会删除项目、设置或 Skills 数据。';

  @override
  String get restartOnboardingAction => '重新开始引导';

  @override
  String get restartOnboardingFailed => '无法重新开始启动引导。';

  @override
  String get onboardingProjectError => 'SkillsGo 无法从这个目录添加项目。';

  @override
  String get onboardingProjectsLoadError => 'SkillsGo 无法加载已添加的项目。';

  @override
  String get onboardingStartupError => 'SkillsGo 无法加载初始设置。';

  @override
  String get onboardingStateError => 'SkillsGo 无法保存设置进度，请重试。';

  @override
  String get onboardingCliErrorTitle => 'SkillsGo CLI 需要处理';

  @override
  String get onboardingCliErrorDescription => '修复内置 CLI 后重试，即可继续。';
}
