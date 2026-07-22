// ignore_for_file: text_direction_code_point_in_literal, text_direction_code_point_in_comment

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
  String get batchTakeoverStoryTitle => '把散落的技能，整理成一个清晰的 Library';

  @override
  String batchTakeoverStoryDescription(int count) {
    return 'SkillsGo 在当前位置发现 $count 个可以纳入管理的现有技能。';
  }

  @override
  String get batchTakeoverBeforeSemantics =>
      '纳入管理前，现有技能装在哪里、是不是最新、损坏后如何恢复，以及不同项目间的版本是否一致，都缺少清晰状态。';

  @override
  String get batchTakeoverPainLocation => '不知道装在哪';

  @override
  String get batchTakeoverPainFreshness => '不知道是不是最新';

  @override
  String get batchTakeoverPainRecovery => '坏了无法恢复';

  @override
  String get batchTakeoverPainVersionDrift => '多个项目版本不一致';

  @override
  String get batchTakeoverFolderTitle => '现有 Skills';

  @override
  String get batchTakeoverFolderSubtitle => '状态不清晰';

  @override
  String get batchTakeoverAfterLabel => '纳入后';

  @override
  String get batchTakeoverAfterTitle => '一个清晰的 Library';

  @override
  String get batchTakeoverLibraryTitle => 'SkillsGo Library';

  @override
  String get batchTakeoverBenefitLocation => '位置清晰';

  @override
  String get batchTakeoverBenefitFreshness => '更新可见';

  @override
  String get batchTakeoverBenefitRecovery => '随时恢复';

  @override
  String get batchTakeoverBenefitVersions => '版本明确';

  @override
  String get batchTakeoverManagedSection => 'SkillsGo 管理中';

  @override
  String get batchTakeoverPendingSection => '待纳入';

  @override
  String batchTakeoverItemManaged(String name) {
    return '$name 已纳入 SkillsGo 管理';
  }

  @override
  String batchTakeoverItemSkipped(String name) {
    return '$name 未能纳入管理';
  }

  @override
  String batchTakeoverItemPending(String name) {
    return '$name 等待纳入管理';
  }

  @override
  String batchTakeoverAfterSemantics(int count) {
    return '纳入管理后，$count 个技能会整理到同一个 Library 中，并显示清晰的管理状态。';
  }

  @override
  String batchTakeoverMoreSkills(int count) {
    return '另外 $count 个';
  }

  @override
  String get batchTakeoverTransitionSemantics => '将这些现有技能纳入 SkillsGo 管理。';

  @override
  String get batchTakeoverTransitionLabel => '整理';

  @override
  String get batchTakeoverStatusTitle => '纳入状态';

  @override
  String get batchTakeoverStatusManaged => '已纳入';

  @override
  String get batchTakeoverStatusProgress => '正在整理';

  @override
  String get batchTakeoverStatusSkipped => '已跳过';

  @override
  String get batchTakeoverStatusFilesStay => '技能文件保留在原来的位置';

  @override
  String get batchTakeoverBoardSemantics =>
      '技能会排列成完整的行并由 SkillsGo 建立管理记录，原文件不会移动。';

  @override
  String get batchTakeoverBoardComplete => '全部整理';

  @override
  String get batchTakeoverBoardPartial => '整理完成';

  @override
  String get batchTakeoverStatusTotal => '总计';

  @override
  String get batchTakeoverQueueComplete => '没有待纳入的技能';

  @override
  String get batchTakeoverQueueWaiting => '验证完成后，技能会从这里开始整理';

  @override
  String get batchTakeoverNextLabel => 'NEXT';

  @override
  String batchTakeoverFillerCount(int count) {
    return '使用 $count 个 SkillsGo 整理块补全最后几行';
  }

  @override
  String get batchTakeoverPreservation =>
      '原文件、原路径和现有用法全部保留。SkillsGo 只会补全本地管理记录。';

  @override
  String get batchTakeoverLaterHint => '暂时跳过后，仍可随时在 Library 点击「纳入管理」。';

  @override
  String get batchTakeoverSkip => '暂时跳过';

  @override
  String get batchTakeoverConfirm => '纳入管理';

  @override
  String get batchTakeoverExecutionRetry => '重试纳入';

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
  String get libraryRefreshSettingsTitle => '刷新本地技能库';

  @override
  String get libraryRefreshSettingsDescription =>
      '重新扫描已安装 Skills、已添加项目、智能体，以及可纳入管理的外部 Skills。此操作不会安装、更新或移除任何内容。';

  @override
  String get libraryRefreshSettingsAction => '刷新技能库';

  @override
  String get libraryRefreshSettingsPending => '正在刷新技能库…';

  @override
  String get libraryRefreshSettingsSuccess => '本地技能库已刷新。';

  @override
  String get libraryRefreshSettingsFailed => 'SkillsGo 无法刷新本地技能库。';

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

/// The translations for Chinese, as used in Hong Kong, using the Han script (`zh_Hant_HK`).
class AppLocalizationsZhHantHk extends AppLocalizationsZh {
  AppLocalizationsZhHantHk() : super('zh_Hant_HK');

  @override
  String get discover => '發現';

  @override
  String get discoverSkills => '多會一點，總是好的。';

  @override
  String get library => '已安裝';

  @override
  String get settings => '設置';

  @override
  String get openSettings => '打開設置';

  @override
  String get cliNeedsAttention => 'SkillsGo 的必要組件需要處理。';

  @override
  String get cliMissingBundled =>
      'SkillsGo 的必要組件缺失或無法啓動。請重新安裝 SkillsGo 以恢復該組件。';

  @override
  String get cliDamagedBundled => 'SkillsGo 的必要組件已損壞。請重新安裝 SkillsGo 以恢復該組件。';

  @override
  String get cliIncompatibleBundled => '必要組件與目前的應用程式版本不相容。請更新或重新安裝 SkillsGo。';

  @override
  String get officialIndex => 'SkillsGo Hub';

  @override
  String get discoverTitle => '找到下一步所需的技能。';

  @override
  String get skillsLeaderboard => '多會一點，總是好的。';

  @override
  String searchResultsFor(String query) {
    return '“$query”的搜索結果';
  }

  @override
  String get searchSkills => '搜索技能或粘貼 Git 鏈接…';

  @override
  String get search => '搜索';

  @override
  String get ranking => '排行';

  @override
  String get trending => '趨勢';

  @override
  String get hot => '熱門';

  @override
  String get discoverNavigation => '發現導航';

  @override
  String get allTimeRanking => '歷史排行';

  @override
  String get trendingNow => '最近 24 小時趨勢';

  @override
  String get hotNow => '當前熱門';

  @override
  String get allTimeDescription => '按歷史累計有效安裝量排列公開 Skill。';

  @override
  String get trendingDescription => '按最近 24 小時內的有效安裝量排列公開 Skill。';

  @override
  String get hotDescription => '按短期安裝速度及其變化排列公開 Skill。';

  @override
  String get offlineTitle => '無法連接到 SkillsGo';

  @override
  String get offlineMessage => '請檢查網絡連接後重試。如果你使用了代理或自定義服務地址，請前往設置檢查。';

  @override
  String get searchFailedTitle => '搜索遇到問題';

  @override
  String get validationTitle => '請檢查輸入內容';

  @override
  String get validationMessage => 'SkillsGo 無法處理這項請求。請檢查輸入內容後重試。';

  @override
  String get serverTitle => '服務暫時不可用';

  @override
  String get serverMessage => 'SkillsGo 暫時無法完成這項請求，請稍後重試。';

  @override
  String get timeoutTitle => '等待時間過長';

  @override
  String get timeoutMessage => '服務未能及時響應。請檢查網絡連接或重試。';

  @override
  String get invalidResponseTitle => 'SkillsGo 需要更新';

  @override
  String get invalidResponseMessage => '當前版本的 SkillsGo 無法讀取服務返回的內容。請更新應用後重試。';

  @override
  String get invalidLocalDataTitle => '無法讀取已安裝的技能';

  @override
  String get invalidLocalDataMessage =>
      '部分本地安裝信息已損壞或不兼容。請更新或重新安裝 SkillsGo 後重試。';

  @override
  String get tryAgain => '重試';

  @override
  String get searchEmptyTitle => '搜索，而不是漫無目的地瀏覽。';

  @override
  String get searchEmptyMessage => '請輸入能力、來源或任務，搜索公開技能。';

  @override
  String get noSkillsTitle => '沒有找到技能';

  @override
  String get noSkillsMessage => '請嘗試更寬泛的關鍵詞或檢查拼寫。';

  @override
  String get focusSearch => '回到搜索框';

  @override
  String get skillsFromLink => '這個鏈接中的技能';

  @override
  String skillCount(int count) {
    return '$count 個技能';
  }

  @override
  String sourceResultsSummary(String source, int count) {
    return '來自 $source 的 $count 個技能';
  }

  @override
  String get sourceSearchEmptyTitle => '可以查看這個鏈接';

  @override
  String sourceSearchEmptyMessage(String source) {
    return '當前搜索結果中沒有 $source。下一步 SkillsGo 可以直接查看這個鏈接中的技能。';
  }

  @override
  String get inspectSource => '查看鏈接中的技能';

  @override
  String get collectionEmptyTitle => '該集合中暫無 Skill';

  @override
  String get collectionEmptyMessage => '這裏暫時沒有內容。產生更多安裝活動後可以重試。';

  @override
  String get loadMore => '載入更多';

  @override
  String get install => '安裝';

  @override
  String get installAll => '安裝所有技能';

  @override
  String get latestCommit => '最新提交';

  @override
  String get installToMoreTargets => '安裝到更多位置';

  @override
  String localTargets(int count) {
    return '$count 個本地目標';
  }

  @override
  String allTimeMetric(String count) {
    return '歷史安裝 $count 次';
  }

  @override
  String trendingMetric(String count) {
    return '24 小時安裝 $count 次';
  }

  @override
  String hotMetric(String value, String change) {
    return '本小時 $value · 變化 $change';
  }

  @override
  String get trustUnverified => '未驗證';

  @override
  String get trustCommunityVerified => '社區驗證';

  @override
  String get trustPublisherVerified => '發佈者驗證';

  @override
  String get trustOfficial => '官方';

  @override
  String get trustWarned => '已警告';

  @override
  String get trustDelisted => '已下架';

  @override
  String get riskUnknown => '風險未知';

  @override
  String get riskLow => '低風險';

  @override
  String get riskMedium => '中風險';

  @override
  String get riskHigh => '高風險';

  @override
  String get riskCritical => '嚴重風險';

  @override
  String openSkill(String name) {
    return '打開 $name';
  }

  @override
  String installs(String count) {
    return '$count 次安裝';
  }

  @override
  String get detailFailedTitle => '無法載入此技能';

  @override
  String get detailLoading => '正在載入可審計的技能詳情';

  @override
  String get artifactUnavailableTitle => '製品暫不可用';

  @override
  String get artifactUnavailableMessage => '當前無法獲取這個版本。你可以重試或選擇其他版本。';

  @override
  String get detailInvalidTitle => '不支持該製品元數據';

  @override
  String get detailInvalidMessage => '這個技能的部分信息不完整或無法讀取。請更新 SkillsGo 後重試。';

  @override
  String get instructionsTab => '技能指令';

  @override
  String get manifestTab => 'Manifest';

  @override
  String immutableVersionLabel(String version) {
    return '不可變版本 $version';
  }

  @override
  String commitIdentity(String sha) {
    return 'Commit $sha';
  }

  @override
  String treeIdentity(String sha) {
    return '目錄樹 $sha';
  }

  @override
  String contentIdentity(String digest) {
    return '內容 $digest';
  }

  @override
  String get trustDoesNotProveSafety =>
      '發佈者可信度只驗證所有權或維護關係，並不證明製品安全。風險會針對該不可變版本單獨評估。';

  @override
  String get knownInstallationTargets => '已知安裝目標';

  @override
  String get installationRange => '已安裝範圍';

  @override
  String get targetDetails => '查看目標詳情';

  @override
  String get hideTargetDetails => '收起目標詳情';

  @override
  String installedVersionLabel(String version) {
    return '版本 $version';
  }

  @override
  String targetSummary(String scope, String agent, String version) {
    return '$scope / $agent · $version';
  }

  @override
  String get projectScope => '項目';

  @override
  String get fileContentUnavailable => '二進制文件或無法預覽';

  @override
  String get fileContentTruncated => 'Hub 已按安全大小限制截斷預覽。';

  @override
  String get retry => '重試';

  @override
  String get backToSearch => '返回搜索';

  @override
  String get installForCodex => '安裝到 Codex';

  @override
  String get cliNotDetected => 'skills（未檢測到）';

  @override
  String get snapshotFiles => '快照文件';

  @override
  String get globalCodex => '全局 · Codex';

  @override
  String get yourLibrary => '已經會的，都在這裏。';

  @override
  String get libraryNavigation => '已安裝技能導航';

  @override
  String get all => '所有';

  @override
  String get allSkills => '全部 Skills';

  @override
  String get updatesOnly => '有更新';

  @override
  String get allAgents => '所有智能體';

  @override
  String get allProjects => '所有項目';

  @override
  String get specificProject => '指定項目';

  @override
  String get userScope => '全局安裝';

  @override
  String get addProject => '添加項目';

  @override
  String get relocateProject => '重新定位';

  @override
  String get removeFromList => '從列表移除';

  @override
  String removeProjectTitle(String name) {
    return '從 SkillsGo 移除 $name？';
  }

  @override
  String get removeProjectDescription =>
      '只會移除 App 中的引用。SkillsGo 不會修改或刪除該目錄中的任何文件。';

  @override
  String projectRailUnavailable(String name) {
    return '$name — 不可用';
  }

  @override
  String get emptyProjectTitle => '還沒有技能';

  @override
  String get browseSkills => '瀏覽技能';

  @override
  String get projectMissingTitle => '項目目錄不存在';

  @override
  String get projectMissingMessage => '目錄可能已移動，或所在磁盤暫時離線。你可以重新定位，或僅移除 App 引用。';

  @override
  String get projectPermissionTitle => '需要項目目錄權限';

  @override
  String get projectPermissionMessage =>
      'SkillsGo 無法檢查這個已選擇的根目錄。請通過目錄選擇器重新定位並授予訪問權限。';

  @override
  String get projectInaccessibleTitle => '項目目錄無法訪問';

  @override
  String get projectInaccessibleMessage => 'SkillsGo 已保留該項目引用。請檢查路徑或磁盤，然後重新定位。';

  @override
  String get checking => '正在檢查…';

  @override
  String get checkUpdates => '檢查更新';

  @override
  String get refresh => '刷新';

  @override
  String get libraryUnavailable => '已安裝技能暫不可用';

  @override
  String get libraryEmpty => '還沒有安裝技能';

  @override
  String get libraryEmptyMessage => '從“發現”安裝技能後，它會顯示在這裏。';

  @override
  String get searchLibrary => '搜索已安裝技能';

  @override
  String get libraryNoMatches => '沒有匹配的技能';

  @override
  String get libraryNoMatchesMessage => '嘗試其他名稱、來源、智能體、項目或版本。';

  @override
  String agentsSummary(int count) {
    return '$count 個智能體';
  }

  @override
  String projectsSummary(int count) {
    return '$count 個項目';
  }

  @override
  String versionsSummary(int count) {
    return '$count 個版本';
  }

  @override
  String get hubManaged => 'Hub 託管';

  @override
  String get localManaged => '本地託管';

  @override
  String get externalInstallation => '外部安裝';

  @override
  String get readOnly => '只讀';

  @override
  String get unversioned => '無版本信息';

  @override
  String get supportingFiles => '支持文件';

  @override
  String get versionDivergence => '多版本並存';

  @override
  String get healthHealthy => '狀態正常';

  @override
  String get healthMissing => '目標已缺失';

  @override
  String get healthReplaced => '目標已被替換';

  @override
  String get healthLocalModification => '存在本地修改';

  @override
  String get healthUnreadable => '目標不可讀取';

  @override
  String get healthUndeclared => '未在項目中聲明';

  @override
  String get healthWorkspaceUnreadable => '項目聲明不可讀取';

  @override
  String get healthLockMismatch => '鎖文件不匹配';

  @override
  String get healthUnexpectedPath => '目標路徑異常';

  @override
  String get modeSymlink => '軟鏈接';

  @override
  String get modeCopy => '複製';

  @override
  String get modeExternal => '外部';

  @override
  String get notLinked => '未連接';

  @override
  String get update => '更新';

  @override
  String get backToLibrary => '返回已安裝技能';

  @override
  String get remove => '移除';

  @override
  String get manageTargets => '管理範圍';

  @override
  String skillsSelected(int count) {
    return '已選擇 $count 項';
  }

  @override
  String get clearSelection => '清除選擇';

  @override
  String get selectCurrentResults => '選擇當前結果';

  @override
  String get clearCurrentResultSelection => '清除當前結果選擇';

  @override
  String get manageTargetsTitle => '管理安裝目標';

  @override
  String get manageTargetsDescription => '為每個目標選擇精確操作；未選擇的目標不會改變。';

  @override
  String targetActionsSelected(int selected, int total) {
    return '已選擇 $selected/$total 個目標';
  }

  @override
  String get repairTarget => '修復';

  @override
  String get confirmRemoveTarget => '確認移除';

  @override
  String get applyTargetActions => '執行所選操作';

  @override
  String get managementProgressTitle => '正在執行目標操作';

  @override
  String get managementResultsTitle => '目標操作結果';

  @override
  String managementResultSummary(int succeeded, int failed) {
    return '$succeeded 個成功，$failed 個失敗';
  }

  @override
  String get workspaceOwnershipChanges =>
      '所選項目操作將更新 skillsgo.mod 和 skillsgo.sum。';

  @override
  String get targetContentPreserved => '目標當前內容會被保留。';

  @override
  String get localReadFailed => '無法讀取此技能';

  @override
  String get localReadFailedMessage =>
      'SkillsGo 無法讀取這個已安裝的技能。請確認其文件夾存在且可以訪問，然後重試。';

  @override
  String get localConfiguration => 'SKILLSGO 設置';

  @override
  String get settingsNavigation => '設置導航';

  @override
  String get general => '個性化';

  @override
  String get agents => '智能體';

  @override
  String get hub => 'Hub';

  @override
  String get installationPolicy => '安裝策略';

  @override
  String get storage => '存儲';

  @override
  String get colorScheme => '顏色預覽';

  @override
  String get about => '關於';

  @override
  String get colorSchemeInspectorTitle => 'Material 生成色彩角色';

  @override
  String get skillsColorTokensTitle => 'SkillsGo 語義顏色';

  @override
  String get skillsColorTokensDescription =>
      '由 Radix Sand 色階構建、採用 Primer 語義組織的產品顏色；Folder 是獨立的空間層級。';

  @override
  String get colorSchemeInspectorDescription =>
      '展示當前種子色生成的所有非廢棄 ColorScheme Token。點擊色塊即可複製 HEX。';

  @override
  String get colorSchemePairPreview => '語義顏色組合';

  @override
  String get colorSchemePairPreviewDescription =>
      '將前景色和背景色放在一起渲染，直接檢查對比度與信息層級。';

  @override
  String get colorSchemeComponentPreview => '組件實景';

  @override
  String get colorSchemeComponentPreviewDescription =>
      '使用當前預覽 Scheme 渲染典型 Material 控件。';

  @override
  String get colorSchemeSampleTitle => '技能卡片標題';

  @override
  String get colorSchemeSampleBody => '輔助説明使用 onSurfaceVariant。';

  @override
  String get colorSchemeCopied => '已複製';

  @override
  String get colorSchemeSampleGlyphs => '字 Aa 123';

  @override
  String get colorSchemeGroupPrimary => '主色';

  @override
  String get colorSchemeGroupPrimaryDescription => '主要強調、容器與固定主色角色。';

  @override
  String get colorSchemeGroupSecondary => '輔色';

  @override
  String get colorSchemeGroupSecondaryDescription => '輔助強調與固定輔色角色。';

  @override
  String get colorSchemeGroupTertiary => '第三色';

  @override
  String get colorSchemeGroupTertiaryDescription => '與主色、輔色形成對比的補充強調色。';

  @override
  String get colorSchemeGroupSurface => '表面';

  @override
  String get colorSchemeGroupSurfaceDescription => '頁面、容器、層級與前景內容的顏色體系。';

  @override
  String get colorSchemeGroupUtility => '輪廓與輔助';

  @override
  String get colorSchemeGroupUtilityDescription => '邊界、陰影、遮罩和反色表面角色。';

  @override
  String get colorSchemeGroupError => '錯誤';

  @override
  String get colorSchemeGroupErrorDescription => '錯誤操作、消息和容器角色。';

  @override
  String get colorSchemeUsagePrimary => '主要操作、焦點和高強調裝飾。';

  @override
  String get colorSchemeUsageSecondary => '輔助操作和中等強調裝飾。';

  @override
  String get colorSchemeUsageTertiary => '補充主色與輔色的對比強調色。';

  @override
  String colorSchemeUsageContentOn(String token) {
    return '顯示在 $token 上的文字和圖標。';
  }

  @override
  String colorSchemeUsageContainer(String family) {
    return '用於選中態與強調的低強調 $family 容器。';
  }

  @override
  String colorSchemeUsageFixed(String family) {
    return '不隨明暗模式變化的固定 $family 容器。';
  }

  @override
  String colorSchemeUsageFixedDim(String family) {
    return '較暗的固定 $family 容器，不隨明暗模式變化。';
  }

  @override
  String colorSchemeUsageFixedContent(String family) {
    return '固定 $family 容器上的高強調內容。';
  }

  @override
  String colorSchemeUsageFixedVariantContent(String family) {
    return '固定 $family 容器上的低強調內容。';
  }

  @override
  String get colorSchemeUsageSurface => '頁面和大型區域的基礎表面。';

  @override
  String get colorSchemeUsageSurfaceDim => '表面色階中較暗的基礎表面。';

  @override
  String get colorSchemeUsageSurfaceBright => '表面色階中較亮的基礎表面。';

  @override
  String colorSchemeUsageSurfaceElevation(String level) {
    return '$level 層級的表面容器。';
  }

  @override
  String get colorSchemeElevationLowest => '最低';

  @override
  String get colorSchemeElevationLow => '較低';

  @override
  String get colorSchemeElevationDefault => '默認';

  @override
  String get colorSchemeElevationHigh => '較高';

  @override
  String get colorSchemeElevationHighest => '最高';

  @override
  String get colorSchemeUsageOnSurface => '表面上的主要文字和圖標。';

  @override
  String get colorSchemeUsageOnSurfaceVariant => '表面上的次要文字、標籤和弱化圖標。';

  @override
  String get colorSchemeUsageSurfaceTint => '從主色生成的 Material 層級着色。';

  @override
  String get colorSchemeUsageOutline => '醒目的邊界和獲得焦點的組件輪廓。';

  @override
  String get colorSchemeUsageOutlineVariant => '細微邊界、分隔線和低強調輪廓。';

  @override
  String get colorSchemeUsageShadow => '懸浮表面的投影顏色。';

  @override
  String get colorSchemeUsageScrim => '用於弱化背景內容的模態遮罩。';

  @override
  String get colorSchemeUsageInverseSurface => '明暗強調反轉的表面。';

  @override
  String get colorSchemeUsageInversePrimary => '顯示在反色表面上的主色強調。';

  @override
  String get colorSchemeUsageError => '錯誤操作、狀態與高強調反饋。';

  @override
  String get save => '儲存';

  @override
  String get advancedSettings => '高級';

  @override
  String get remindersSettings => '提醒';

  @override
  String get remindersSettingsTitle => '提醒設置';

  @override
  String get remindersSettingsDescription => '選擇要接收的提醒。';

  @override
  String get updateReminderTitle => '更新提醒';

  @override
  String get updateReminderDescription => '打開“已安裝”時檢查更新。';

  @override
  String get securityReminderTitle => '高風險提醒';

  @override
  String get securityReminderDescription => '發現已安裝技能存在高風險或嚴重風險時提醒。';

  @override
  String availableUpdatesReminder(int count) {
    return '$count 個已安裝技能有可用更新';
  }

  @override
  String get openAvailableUpdates => '打開“有更新”視圖，查看並選擇需要更新的技能。';

  @override
  String securityAdvisoriesReminder(int count) {
    return '$count 個已安裝技能需要安全檢查';
  }

  @override
  String get reviewInstalledSkills => '使用或更新前，請先查看這些技能的風險信息。';

  @override
  String get generalSettingsTitle => '讓 SkillsGo 更適合你';

  @override
  String get generalSettingsDescription => '界面會自動跟隨系統語言、輔助功能和動態效果偏好。';

  @override
  String get agentsSettingsTitle => '智能體運行環境';

  @override
  String get hubSettingsTitle => 'Hub 地址';

  @override
  String get hubSettingsDescription =>
      '使用官方 Hub，或實現相同 SkillsGo 協議的 HTTP(S) 自託管地址。';

  @override
  String get testConnection => '測試連接';

  @override
  String get saveOrigin => '儲存地址';

  @override
  String get resetDefault => '恢復默認';

  @override
  String get connectionReady => '連接正常';

  @override
  String get connectionFailed => '連接失敗';

  @override
  String get hubInvalidOrigin => '請輸入不含賬號密碼、查詢參數或片段的有效 HTTP(S) 地址。';

  @override
  String hubHttpFailure(int status) {
    return 'Hub 傳回 HTTP $status。請檢查 Hub 地址及伺服器設定。';
  }

  @override
  String get hubInvalidProtocol => '伺服器未有傳回 SkillsGo Hub 搜尋協定。';

  @override
  String get hubInvalidJson => 'Hub 返回了無效 JSON。';

  @override
  String get hubConnectionFailure => '無法連接至 Hub。請檢查 Hub 地址、網絡、Proxy 及 TLS 設定。';

  @override
  String get hubConnectionTimeout => 'Hub 連接超時。請檢查網絡或重試。';

  @override
  String get riskPolicyTitle => '個人風險策略';

  @override
  String get riskPolicyDescription => '安全規則會在安裝或更新技能時生效。';

  @override
  String get confirmHighRisk => '高風險必須額外確認';

  @override
  String get confirmHighRiskDescription => '安裝高風險製品前始終要求一次額外確認。';

  @override
  String get allowCriticalOverride => '允許顯式覆蓋嚴重風險阻止';

  @override
  String get allowCriticalOverrideDescription =>
      '嚴重風險製品默認保持阻止。啓用後僅提供單獨的手動覆蓋入口。';

  @override
  String get storageSettingsTitle => '內容尋址 Store';

  @override
  String get storageHealthy => '可讀取';

  @override
  String get storageNotInitialized => '尚未初始化';

  @override
  String get storageUnavailable => '不可用';

  @override
  String get storagePathUnavailable => 'CLI 診斷就緒後才能顯示 Store 路徑。';

  @override
  String get storageHealthyDescription => 'CLI 可以讀取 Store，且本次檢查不會修改其中內容。';

  @override
  String get storageNotInitializedDescription => 'Store 尚不存在，本次檢查沒有創建它。';

  @override
  String get storageUnavailableDescription => 'CLI 無法讀取 Store，請檢查目錄權限及其父目錄。';

  @override
  String get storageInvalidResponse => '內置 CLI 傳回不支援的診斷回應。';

  @override
  String get aboutSettingsTitle => '產品兼容性';

  @override
  String get appVersion => 'App 版本';

  @override
  String get cliVersion => '內置 CLI 版本';

  @override
  String get compatible => '兼容';

  @override
  String get hubOriginSaved => 'Hub 地址已儲存並立即應用。';

  @override
  String get policySaved => '安裝策略已儲存。';

  @override
  String get officialCli => 'SkillsGo CLI';

  @override
  String get ready => '就緒';

  @override
  String get unknown => '未知';

  @override
  String get missing => '缺失';

  @override
  String get incompatible => '版本不兼容';

  @override
  String get detecting => '正在檢測…';

  @override
  String get customCliPath => '自定義可執行文件路徑';

  @override
  String get saveAndDetect => '儲存並檢測';

  @override
  String get detectAgain => '重新檢測';

  @override
  String get agentInstalled => '已安裝';

  @override
  String get agentSupported => '已支持';

  @override
  String agentCatalogSummary(int installed, int supported) {
    return '已安裝 $installed 個 · 支持 $supported 個';
  }

  @override
  String installedAgentsTitle(int count) {
    return '已安裝 · $count';
  }

  @override
  String notInstalledAgentsTitle(int count) {
    return '未安裝 · $count';
  }

  @override
  String get notInstalledAgentsDescription => 'SkillsGo 已支持，但尚未在這台 Mac 上檢測到。';

  @override
  String agentDiscoveryRoots(String paths) {
    return '技能載入路徑：$paths';
  }

  @override
  String get agentInspectionFailed => '智能體檢測數據不可用，請重新檢測。';

  @override
  String get noInstalledAgentsTitle => '未檢測到已安裝的智能體';

  @override
  String get noInstalledAgentsMessage =>
      '你仍可繼續瀏覽該技能，但當前沒有可用安裝目標。請先安裝一個受支持的智能體，然後重新檢測。';

  @override
  String get clearCustomPath => '清除自定義路徑';

  @override
  String get privacyProvenance => '隱私與來源説明';

  @override
  String get privacySummary => '你的搜索記錄不會被儲存，SkillsGo 也不會保留命令日誌。';

  @override
  String get language => '語言';

  @override
  String get personalizationTheme => '主題';

  @override
  String get folderColorTheme => '主題色';

  @override
  String get folderColorThemeDescription => '挑一個喜歡的顏色，SkillsGo 會自動生成協調的界面配色。';

  @override
  String get brandNameNeteaseCloudMusic => '網易雲音樂';

  @override
  String get brandNameRaspberryPi => '樹莓派';

  @override
  String get brandNameChinaEasternAirlines => '中國東方航空';

  @override
  String get brandNameNvidia => '英偉達';

  @override
  String get brandNameTaobao => '淘寶';

  @override
  String get brandNameBitcoin => '比特幣';

  @override
  String get appearanceMode => '模式';

  @override
  String get appearanceModeDescription => '跟隨系統外觀，或始終使用淺色或深色主題。';

  @override
  String get followSystem => '跟隨系統';

  @override
  String get lightMode => '淺色';

  @override
  String get darkMode => '深色';

  @override
  String get wallpaper => '壁紙';

  @override
  String get wallpaperDescription => '選擇一張天體背景，設置後會立即顯示在 Folder 後方。';

  @override
  String get wallpaperSun => '太陽';

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
    return '$theme Folder 主題';
  }

  @override
  String get privacyAffiliation =>
      '匿名安裝遙測由 SkillsGo 設置控制。SkillsGo 與 OpenAI 或 Codex 不存在官方隸屬關係。';

  @override
  String get commandCompleted => '命令執行完成';

  @override
  String get commandFailed => '命令執行失敗';

  @override
  String commandExit(int code) {
    return '退出碼 $code · 展開查看本次會話日誌';
  }

  @override
  String get command => '命令';

  @override
  String get cancel => '取消';

  @override
  String get updateUnknown => '未知';

  @override
  String get updateChecking => '檢查中';

  @override
  String get upToDate => '已是最新';

  @override
  String get updateAvailable => '可更新';

  @override
  String get updateUnavailable => '無法檢查';

  @override
  String get updateCheckFailed => '檢查失敗';

  @override
  String get installSkill => '安裝技能';

  @override
  String get installLocationTitle => '設置技能安裝位置';

  @override
  String get userLevel => '用户級別';

  @override
  String get projectLevel => '項目級別';

  @override
  String get projects => '項目';

  @override
  String get loading => '正在載入…';

  @override
  String get repositoryParsing => '正在解析 Repository…';

  @override
  String userInstallSummary(int agents) {
    return '將在用户級別供 $agents 個智能體使用';
  }

  @override
  String projectInstallSummary(int projects, int agents) {
    return '$projects 個項目 · $agents 個智能體';
  }

  @override
  String get installationResults => '安裝結果';

  @override
  String get installationInProgress => '正在安裝';

  @override
  String get installationSucceeded => '安裝完成';

  @override
  String get installationSucceededMessage => '技能現在可在所選位置使用。';

  @override
  String get projectUnavailable => '項目不可用';

  @override
  String get installedCell => '已安裝';

  @override
  String get unsupportedCell => '不可用';

  @override
  String get confirmInstall => '確認安裝';

  @override
  String installAllRepositorySkills(int count) {
    return '安裝倉庫所有技能（$count）';
  }

  @override
  String get installAllSkillsTo => '安裝所有技能到';

  @override
  String installRepositorySkills(String repository, int count) {
    return '安裝 $repository 全部技能（$count）';
  }

  @override
  String installSkillTo(String skill) {
    return '安裝 $skill 到';
  }

  @override
  String get availableInAllProjects => '所有項目';

  @override
  String get availableInSelectedProjects => '指定項目';

  @override
  String get usedBy => '用於智能體';

  @override
  String get backToTargets => '返回目標選擇';

  @override
  String get stayHere => '留在這裏';

  @override
  String get viewInLibrary => '查看已安裝技能';

  @override
  String planCreateCount(int count) {
    return '創建 $count 個';
  }

  @override
  String planSkipCount(int count) {
    return '跳過 $count 個';
  }

  @override
  String planReplaceCount(int count) {
    return '替換 $count 個';
  }

  @override
  String planConflictCount(int count) {
    return '衝突 $count 個';
  }

  @override
  String planRiskCount(int count) {
    return '風險阻止 $count 個';
  }

  @override
  String get refreshInstallationPlan => '應用解決方案';

  @override
  String get replaceVersionConflict => '替換這個目標中已安裝的版本';

  @override
  String get replaceSkillIdCollision => '替換這個目標中的不同 Skill ID';

  @override
  String get replaceLocalModification => '放棄本地修改並替換這個目標';

  @override
  String get sharedTargetConflict => '此路徑由其他智能體目標共享';

  @override
  String sharedTargetConflictDescription(String agents) {
    return '返回目標矩陣並選擇所有受影響的智能體後再替換：$agents';
  }

  @override
  String get replaceConflictingTarget => '替換衝突目標';

  @override
  String get confirmHighRiskArtifact => '確認高風險製品';

  @override
  String get confirmCriticalRiskArtifact => '確認覆蓋嚴重風險';

  @override
  String get confirmRiskForSelectedTargets => '我已檢查製品文件，並接受在所選目標中安裝此風險製品';

  @override
  String get criticalRiskBlocked => '嚴重風險安裝已被阻止';

  @override
  String get criticalRiskOverrideDisabled => '請先在設置中啓用顯式的嚴重風險覆蓋策略，才能繼續此計劃。';

  @override
  String get workspaceManifestChanges => 'Workspace Manifest 變更';

  @override
  String get noWorkspaceManifestChanges => '不會修改 Workspace Manifest 文件。';

  @override
  String lockVersionChange(String from, String to) {
    return '$from → $to';
  }

  @override
  String get notPresent => '尚不存在';

  @override
  String get planActionCreate => '創建';

  @override
  String get planActionReplace => '替換';

  @override
  String get planActionSkip => '跳過';

  @override
  String get planActionConflict => '衝突';

  @override
  String get planActionBlockedByRisk => '因風險阻止';

  @override
  String installationResultSummary(int succeeded, int failed) {
    return '已安裝 $succeeded 個目標，$failed 個失敗';
  }

  @override
  String get installationProgressTitle => '正在安裝';

  @override
  String installationProgressSummary(int finished, int total) {
    return '已完成 $finished/$total 個目標';
  }

  @override
  String get targetWaiting => '等待中';

  @override
  String get targetRunning => '正在安裝';

  @override
  String retryFailedTargets(int count) {
    return '重試 $count 個失敗目標';
  }

  @override
  String get updatePlanTitle => '選擇要更新的目標';

  @override
  String get updatePlanDescription => '請選擇明確的安裝目標；未選擇的智能體和項目不會改變。';

  @override
  String updateTargetsSelected(int selected, int available) {
    return '已選擇 $selected/$available 個可更新目標';
  }

  @override
  String updateVersionChange(String fromVersion, String toVersion) {
    return '$fromVersion → $toVersion';
  }

  @override
  String sourceReference(String reference) {
    return '來源引用：$reference';
  }

  @override
  String get fixedVersionTarget => '已固定——沒有可移動引用';

  @override
  String get currentVersionTarget => '已是最新版本';

  @override
  String get updateCheckTargetFailed => '更新檢查失敗';

  @override
  String get reconcileWorkspaceManifestTarget => '修復工作區清單';

  @override
  String get updateSelectedTargets => '更新所選目標';

  @override
  String get updateProgressTitle => '正在更新目標';

  @override
  String get updateResultsTitle => '更新結果';

  @override
  String updateProgressSummary(int finished, int total) {
    return '已完成 $finished/$total 個目標';
  }

  @override
  String retryFailedUpdates(int count) {
    return '重試 $count 個失敗更新';
  }

  @override
  String get noUpdateableTargets => '所選目標沒有可用更新。';

  @override
  String get closeUpdatePlan => '關閉';

  @override
  String get targetSucceeded => '已安裝';

  @override
  String get targetSkipped => '已跳過';

  @override
  String get targetConflict => '衝突';

  @override
  String get targetFailed => '失敗';

  @override
  String get targetFailureRetryable => '無法更改此位置，你可以重試。';

  @override
  String get targetFailureNeedsAttention => '請先處理此位置的問題，然後重試。';

  @override
  String get installationTargetFailureMessage => '此位置沒有發生更改。請確認文件夾可用後重試。';

  @override
  String get workspacePersistenceFailureMessage =>
      'SkillsGo 無法儲存項目設置，因此沒有更改此位置。請確認項目文件夾可寫後重試。';

  @override
  String get installationStateChangedMessage => '此位置在你確認期間發生了變化。請查看最新狀態後重試。';

  @override
  String get updateTargetFailureMessage => '無法更新此位置，其他位置不受影響。你可以只重試這一項。';

  @override
  String get managementTargetFailureMessage => '無法在此位置完成操作，其他位置不受影響。你可以只重試這一項。';

  @override
  String get technicalDetails => '技術詳情';

  @override
  String get targetPathExists => '此位置已有其他內容。';

  @override
  String get targetBlockedByRisk => '當前安全設置阻止了在此位置安裝。';

  @override
  String get targetInstallFailed => '無法在此位置安裝技能。';

  @override
  String get targetWorkspaceUpdateFailed => '技能已經安裝，但無法更新項目設置。';

  @override
  String get installationPlanFailed => '安裝計劃無法繼續';

  @override
  String get installationFailed => '安裝未能完成';

  @override
  String get localSource => '本地來源';

  @override
  String get noDescriptionAvailable => '暫無描述';

  @override
  String moreCoverage(int count) {
    return '另外 $count 個安裝位置';
  }

  @override
  String get batchTakeoverAction => '納入 SkillsGo 管理';

  @override
  String batchTakeoverActionCount(int count) {
    return '納入管理（$count）';
  }

  @override
  String get batchTakeoverChecking => '正在檢查可納入的技能…';

  @override
  String get batchTakeoverRetry => '重新檢查可納入技能';

  @override
  String batchTakeoverEligibleCount(int count) {
    return '$count 個可納入管理';
  }

  @override
  String get batchTakeoverPending => '正在納入管理…';

  @override
  String get batchTakeoverTitle => '將現有技能納入 SkillsGo 管理？';

  @override
  String get batchTakeoverDescription =>
      'SkillsGo 可以為受支援鎖定檔記錄的現有複製安裝建立管理記錄，不會移動或覆寫其檔案。不支援或確認後已變更的項目將會略過。';

  @override
  String get batchTakeoverStoryTitle => '把散落的技能，整理成一個清晰的 Library';

  @override
  String batchTakeoverStoryDescription(int count) {
    return 'SkillsGo 在當前位置發現 $count 個可以納入管理的現有技能。';
  }

  @override
  String get batchTakeoverBeforeSemantics =>
      '納入管理前，現有技能裝在哪裏、是不是最新、損壞後如何恢復，以及不同項目間的版本是否一致，都缺少清晰狀態。';

  @override
  String get batchTakeoverPainLocation => '不知道裝在哪';

  @override
  String get batchTakeoverPainFreshness => '不知道是不是最新';

  @override
  String get batchTakeoverPainRecovery => '壞了無法恢復';

  @override
  String get batchTakeoverPainVersionDrift => '多個項目版本不一致';

  @override
  String get batchTakeoverFolderTitle => '現有 Skills';

  @override
  String get batchTakeoverFolderSubtitle => '狀態不清晰';

  @override
  String get batchTakeoverAfterLabel => '納入後';

  @override
  String get batchTakeoverAfterTitle => '一個清晰的 Library';

  @override
  String get batchTakeoverLibraryTitle => 'SkillsGo Library';

  @override
  String get batchTakeoverBenefitLocation => '位置清晰';

  @override
  String get batchTakeoverBenefitFreshness => '更新可見';

  @override
  String get batchTakeoverBenefitRecovery => '隨時恢復';

  @override
  String get batchTakeoverBenefitVersions => '版本明確';

  @override
  String get batchTakeoverManagedSection => 'SkillsGo 管理中';

  @override
  String get batchTakeoverPendingSection => '待納入';

  @override
  String batchTakeoverItemManaged(String name) {
    return '$name 已納入 SkillsGo 管理';
  }

  @override
  String batchTakeoverItemSkipped(String name) {
    return '$name 未能納入管理';
  }

  @override
  String batchTakeoverItemPending(String name) {
    return '$name 等待納入管理';
  }

  @override
  String batchTakeoverAfterSemantics(int count) {
    return '納入管理後，$count 個技能會整理到同一個 Library 中，並顯示清晰的管理狀態。';
  }

  @override
  String batchTakeoverMoreSkills(int count) {
    return '另外 $count 個';
  }

  @override
  String get batchTakeoverTransitionSemantics => '將這些現有技能納入 SkillsGo 管理。';

  @override
  String get batchTakeoverTransitionLabel => '整理';

  @override
  String get batchTakeoverStatusTitle => '納入狀態';

  @override
  String get batchTakeoverStatusManaged => '已納入';

  @override
  String get batchTakeoverStatusProgress => '正在整理';

  @override
  String get batchTakeoverStatusSkipped => '已跳過';

  @override
  String get batchTakeoverStatusFilesStay => '技能文件保留在原來的位置';

  @override
  String get batchTakeoverBoardSemantics =>
      '技能會排列成完整的行並由 SkillsGo 建立管理記錄，原文件不會移動。';

  @override
  String get batchTakeoverBoardComplete => '全部整理';

  @override
  String get batchTakeoverBoardPartial => '整理完成';

  @override
  String get batchTakeoverStatusTotal => '總計';

  @override
  String get batchTakeoverQueueComplete => '沒有待納入的技能';

  @override
  String get batchTakeoverQueueWaiting => '驗證完成後，技能會從這裏開始整理';

  @override
  String get batchTakeoverNextLabel => 'NEXT';

  @override
  String batchTakeoverFillerCount(int count) {
    return '使用 $count 個 SkillsGo 整理塊補全最後幾行';
  }

  @override
  String get batchTakeoverPreservation =>
      '原文件、原路徑和現有用法全部保留。SkillsGo 只會補全本地管理記錄。';

  @override
  String get batchTakeoverLaterHint => '暫時跳過後，仍可隨時在 Library 點擊「納入管理」。';

  @override
  String get batchTakeoverSkip => '暫時跳過';

  @override
  String get batchTakeoverConfirm => '納入管理';

  @override
  String get batchTakeoverExecutionRetry => '重試納入';

  @override
  String get batchTakeoverResultTitle => '已納入管理';

  @override
  String batchTakeoverSummary(int takenOver, int skipped) {
    return '已納入管理 $takenOver 個技能，跳過 $skipped 個。';
  }

  @override
  String get batchTakeoverClose => '關閉';

  @override
  String get installMoreTargets => '安裝到更多位置';

  @override
  String get exportLocalSkill => '導出';

  @override
  String get exportLocalSkillDescription => '將這個本地技能導出為可移植的 ZIP 歸檔。';

  @override
  String get detailRepository => '倉庫';

  @override
  String get detailStars => '星標';

  @override
  String get detailUpdated => '最近更新';

  @override
  String get detailArchiveSize => 'ZIP 大小';

  @override
  String get pathLabel => '項目路徑';

  @override
  String get copyProjectPath => '複製項目路徑';

  @override
  String get projectPathCopied => '項目路徑已複製';

  @override
  String get onboardingWelcomeTitle => '歡迎使用 SkillsGo';

  @override
  String get onboardingWelcomeDescription => '發現、安裝和管理所有智能體與項目中的 Skills。';

  @override
  String get onboardingDetectedAgents => '已檢測到的智能體';

  @override
  String get onboardingNoAgents => '未檢測到已安裝的智能體，你仍然可以繼續。';

  @override
  String get onboardingNext => '下一步';

  @override
  String get onboardingProjectsTitle => '添加你的項目';

  @override
  String get onboardingProjectsDescription => '選擇你希望 SkillsGo 管理的項目。';

  @override
  String get onboardingAddProject => '現在添加';

  @override
  String get onboardingAddProjectLater => '或者稍後';

  @override
  String get onboardingStartUsing => '開始使用';

  @override
  String get onboardingBack => '返回';

  @override
  String get restartOnboardingTitle => '啓動引導';

  @override
  String get restartOnboardingDescription => '重新查看首次啓動引導，不會刪除項目、設置或 Skills 數據。';

  @override
  String get restartOnboardingAction => '重新開始引導';

  @override
  String get restartOnboardingFailed => '無法重新開始啓動引導。';

  @override
  String get libraryRefreshSettingsTitle => '刷新本地技能庫';

  @override
  String get libraryRefreshSettingsDescription =>
      '重新掃描已安裝 Skills、已添加項目、智能體，以及可納入管理的外部 Skills。此操作不會安裝、更新或移除任何內容。';

  @override
  String get libraryRefreshSettingsAction => '刷新技能庫';

  @override
  String get libraryRefreshSettingsPending => '正在刷新技能庫…';

  @override
  String get libraryRefreshSettingsSuccess => '本地技能庫已刷新。';

  @override
  String get libraryRefreshSettingsFailed => 'SkillsGo 無法刷新本地技能庫。';

  @override
  String get onboardingProjectError => 'SkillsGo 無法從這個目錄添加項目。';

  @override
  String get onboardingProjectsLoadError => 'SkillsGo 無法載入已添加的項目。';

  @override
  String get onboardingStartupError => 'SkillsGo 無法載入初始設置。';

  @override
  String get onboardingStateError => 'SkillsGo 無法儲存設置進度，請重試。';

  @override
  String get onboardingCliErrorTitle => 'SkillsGo CLI 需要處理';

  @override
  String get onboardingCliErrorDescription => '修復內置 CLI 後重試，即可繼續。';
}

/// The translations for Chinese, as used in Taiwan, using the Han script (`zh_Hant_TW`).
class AppLocalizationsZhHantTw extends AppLocalizationsZh {
  AppLocalizationsZhHantTw() : super('zh_Hant_TW');

  @override
  String get discover => '發現';

  @override
  String get discoverSkills => '多會一點，總是好的。';

  @override
  String get library => '已安裝';

  @override
  String get settings => '設定';

  @override
  String get openSettings => '開啟設定';

  @override
  String get cliNeedsAttention => 'SkillsGo 的必要元件需要處理。';

  @override
  String get cliMissingBundled =>
      'SkillsGo 的必要元件缺失或無法啟動。請重新安裝 SkillsGo 以恢復該元件。';

  @override
  String get cliDamagedBundled => 'SkillsGo 的必要元件已損壞。請重新安裝 SkillsGo 以恢復該元件。';

  @override
  String get cliIncompatibleBundled =>
      '必要的 SkillsGo 元件與目前的應用程式版本不相容。請更新或重新安裝 SkillsGo。';

  @override
  String get officialIndex => 'SkillsGo Hub';

  @override
  String get discoverTitle => '找到下一步所需的技能。';

  @override
  String get skillsLeaderboard => '多會一點，總是好的。';

  @override
  String searchResultsFor(String query) {
    return '“$query”的搜尋結果';
  }

  @override
  String get searchSkills => '搜尋技能或貼上 Git 連結…';

  @override
  String get search => '搜尋';

  @override
  String get ranking => '排行';

  @override
  String get trending => '趨勢';

  @override
  String get hot => '熱門';

  @override
  String get discoverNavigation => '發現導航';

  @override
  String get allTimeRanking => '歷史排行';

  @override
  String get trendingNow => '最近 24 小時趨勢';

  @override
  String get hotNow => '當前熱門';

  @override
  String get allTimeDescription => '按歷史累計有效安裝量排列公開 Skill。';

  @override
  String get trendingDescription => '按最近 24 小時內的有效安裝量排列公開 Skill。';

  @override
  String get hotDescription => '按短期安裝速度及其變化排列公開 Skill。';

  @override
  String get offlineTitle => '無法連線到 SkillsGo';

  @override
  String get offlineMessage => '請檢查網路連線後重試。如果你使用了代理或自定義服務地址，請前往設定檢查。';

  @override
  String get searchFailedTitle => '搜尋遇到問題';

  @override
  String get validationTitle => '請檢查輸入內容';

  @override
  String get validationMessage => 'SkillsGo 無法處理這項請求。請檢查輸入內容後重試。';

  @override
  String get serverTitle => '服務暫時不可用';

  @override
  String get serverMessage => 'SkillsGo 暫時無法完成這項請求，請稍後重試。';

  @override
  String get timeoutTitle => '等待時間過長';

  @override
  String get timeoutMessage => '服務未能及時響應。請檢查網路連線或重試。';

  @override
  String get invalidResponseTitle => 'SkillsGo 需要更新';

  @override
  String get invalidResponseMessage => '當前版本的 SkillsGo 無法讀取服務返回的內容。請更新應用後重試。';

  @override
  String get invalidLocalDataTitle => '無法讀取已安裝的技能';

  @override
  String get invalidLocalDataMessage =>
      '部分本地安裝資訊已損壞或不相容。請更新或重新安裝 SkillsGo 後重試。';

  @override
  String get tryAgain => '重試';

  @override
  String get searchEmptyTitle => '搜尋，而不是漫無目的地瀏覽。';

  @override
  String get searchEmptyMessage => '請輸入能力、來源或任務，搜尋公開技能。';

  @override
  String get noSkillsTitle => '沒有找到技能';

  @override
  String get noSkillsMessage => '請嘗試更寬泛的關鍵詞或檢查拼寫。';

  @override
  String get focusSearch => '回到搜尋框';

  @override
  String get skillsFromLink => '這個連結中的技能';

  @override
  String skillCount(int count) {
    return '$count 個技能';
  }

  @override
  String sourceResultsSummary(String source, int count) {
    return '來自 $source 的 $count 個技能';
  }

  @override
  String get sourceSearchEmptyTitle => '可以檢視這個連結';

  @override
  String sourceSearchEmptyMessage(String source) {
    return '當前搜尋結果中沒有 $source。下一步 SkillsGo 可以直接檢視這個連結中的技能。';
  }

  @override
  String get inspectSource => '檢視連結中的技能';

  @override
  String get collectionEmptyTitle => '該集合中暫無 Skill';

  @override
  String get collectionEmptyMessage => '這裡暫時沒有內容。產生更多安裝活動後可以重試。';

  @override
  String get loadMore => '載入更多';

  @override
  String get install => '安裝';

  @override
  String get installAll => '安裝所有技能';

  @override
  String get latestCommit => '最新提交';

  @override
  String get installToMoreTargets => '安裝到更多位置';

  @override
  String localTargets(int count) {
    return '$count 個本地目標';
  }

  @override
  String allTimeMetric(String count) {
    return '歷史安裝 $count 次';
  }

  @override
  String trendingMetric(String count) {
    return '24 小時安裝 $count 次';
  }

  @override
  String hotMetric(String value, String change) {
    return '本小時 $value · 變化 $change';
  }

  @override
  String get trustUnverified => '未驗證';

  @override
  String get trustCommunityVerified => '社群驗證';

  @override
  String get trustPublisherVerified => '釋出者驗證';

  @override
  String get trustOfficial => '官方';

  @override
  String get trustWarned => '已警告';

  @override
  String get trustDelisted => '已下架';

  @override
  String get riskUnknown => '風險未知';

  @override
  String get riskLow => '低風險';

  @override
  String get riskMedium => '中風險';

  @override
  String get riskHigh => '高風險';

  @override
  String get riskCritical => '嚴重風險';

  @override
  String openSkill(String name) {
    return '開啟 $name';
  }

  @override
  String installs(String count) {
    return '$count 次安裝';
  }

  @override
  String get detailFailedTitle => '無法載入此技能';

  @override
  String get detailLoading => '正在載入可審計的技能詳情';

  @override
  String get artifactUnavailableTitle => '製品暫不可用';

  @override
  String get artifactUnavailableMessage => '當前無法獲取這個版本。你可以重試或選擇其他版本。';

  @override
  String get detailInvalidTitle => '不支援該製品後設資料';

  @override
  String get detailInvalidMessage => '這個技能的部分資訊不完整或無法讀取。請更新 SkillsGo 後重試。';

  @override
  String get instructionsTab => '技能指令';

  @override
  String get manifestTab => 'Manifest';

  @override
  String immutableVersionLabel(String version) {
    return '不可變版本 $version';
  }

  @override
  String commitIdentity(String sha) {
    return 'Commit $sha';
  }

  @override
  String treeIdentity(String sha) {
    return '目錄樹 $sha';
  }

  @override
  String contentIdentity(String digest) {
    return '內容 $digest';
  }

  @override
  String get trustDoesNotProveSafety =>
      '釋出者可信度只驗證所有權或維護關係，並不證明製品安全。風險會針對該不可變版本單獨評估。';

  @override
  String get knownInstallationTargets => '已知安裝目標';

  @override
  String get installationRange => '已安裝範圍';

  @override
  String get targetDetails => '檢視目標詳情';

  @override
  String get hideTargetDetails => '收起目標詳情';

  @override
  String installedVersionLabel(String version) {
    return '版本 $version';
  }

  @override
  String targetSummary(String scope, String agent, String version) {
    return '$scope / $agent · $version';
  }

  @override
  String get projectScope => '專案';

  @override
  String get fileContentUnavailable => '二進位制檔案或無法預覽';

  @override
  String get fileContentTruncated => 'Hub 已按安全大小限制截斷預覽。';

  @override
  String get retry => '重試';

  @override
  String get backToSearch => '返回搜尋';

  @override
  String get installForCodex => '安裝到 Codex';

  @override
  String get cliNotDetected => 'skills（未偵測到）';

  @override
  String get snapshotFiles => '快照檔案';

  @override
  String get globalCodex => '全域性 · Codex';

  @override
  String get yourLibrary => '已經會的，都在這裡。';

  @override
  String get libraryNavigation => '已安裝技能導航';

  @override
  String get all => '所有';

  @override
  String get allSkills => '全部 Skills';

  @override
  String get updatesOnly => '有更新';

  @override
  String get allAgents => '所有智慧體';

  @override
  String get allProjects => '所有專案';

  @override
  String get specificProject => '指定專案';

  @override
  String get userScope => '全域性安裝';

  @override
  String get addProject => '新增專案';

  @override
  String get relocateProject => '重新定位';

  @override
  String get removeFromList => '從列表移除';

  @override
  String removeProjectTitle(String name) {
    return '從 SkillsGo 移除 $name？';
  }

  @override
  String get removeProjectDescription =>
      '只會移除 App 中的引用。SkillsGo 不會修改或刪除該目錄中的任何檔案。';

  @override
  String projectRailUnavailable(String name) {
    return '$name — 不可用';
  }

  @override
  String get emptyProjectTitle => '還沒有技能';

  @override
  String get browseSkills => '瀏覽技能';

  @override
  String get projectMissingTitle => '專案目錄不存在';

  @override
  String get projectMissingMessage => '目錄可能已移動，或所在磁碟暫時離線。你可以重新定位，或僅移除 App 引用。';

  @override
  String get projectPermissionTitle => '需要專案資料夾權限';

  @override
  String get projectPermissionMessage =>
      'SkillsGo 無法檢查所選的根目錄。請透過資料夾選擇器重新選取該目錄並授予存取權限。';

  @override
  String get projectInaccessibleTitle => '專案目錄無法訪問';

  @override
  String get projectInaccessibleMessage => 'SkillsGo 已保留該專案引用。請檢查路徑或磁碟，然後重新定位。';

  @override
  String get checking => '正在檢查…';

  @override
  String get checkUpdates => '檢查更新';

  @override
  String get refresh => '重新整理';

  @override
  String get libraryUnavailable => '已安裝技能暫不可用';

  @override
  String get libraryEmpty => '還沒有安裝技能';

  @override
  String get libraryEmptyMessage => '從“發現”安裝技能後，它會顯示在這裡。';

  @override
  String get searchLibrary => '搜尋已安裝技能';

  @override
  String get libraryNoMatches => '沒有匹配的技能';

  @override
  String get libraryNoMatchesMessage => '嘗試其他名稱、來源、智慧體、專案或版本。';

  @override
  String agentsSummary(int count) {
    return '$count 個智慧體';
  }

  @override
  String projectsSummary(int count) {
    return '$count 個專案';
  }

  @override
  String versionsSummary(int count) {
    return '$count 個版本';
  }

  @override
  String get hubManaged => 'Hub 託管';

  @override
  String get localManaged => '本地託管';

  @override
  String get externalInstallation => '外部安裝';

  @override
  String get readOnly => '只讀';

  @override
  String get unversioned => '無版本資訊';

  @override
  String get supportingFiles => '支援檔案';

  @override
  String get versionDivergence => '多版本並存';

  @override
  String get healthHealthy => '狀態正常';

  @override
  String get healthMissing => '目標已缺失';

  @override
  String get healthReplaced => '目標已被替換';

  @override
  String get healthLocalModification => '存在本地修改';

  @override
  String get healthUnreadable => '目標不可讀取';

  @override
  String get healthUndeclared => '未在專案中宣告';

  @override
  String get healthWorkspaceUnreadable => '專案宣告不可讀取';

  @override
  String get healthLockMismatch => '鎖檔案不匹配';

  @override
  String get healthUnexpectedPath => '目標路徑異常';

  @override
  String get modeSymlink => '軟連結';

  @override
  String get modeCopy => '複製';

  @override
  String get modeExternal => '外部';

  @override
  String get notLinked => '未連線';

  @override
  String get update => '更新';

  @override
  String get backToLibrary => '返回已安裝技能';

  @override
  String get remove => '移除';

  @override
  String get manageTargets => '管理範圍';

  @override
  String skillsSelected(int count) {
    return '已選擇 $count 項';
  }

  @override
  String get clearSelection => '清除選擇';

  @override
  String get selectCurrentResults => '選擇當前結果';

  @override
  String get clearCurrentResultSelection => '清除當前結果選擇';

  @override
  String get manageTargetsTitle => '管理安裝目標';

  @override
  String get manageTargetsDescription => '為每個目標選擇精確操作；未選擇的目標不會改變。';

  @override
  String targetActionsSelected(int selected, int total) {
    return '已選擇 $selected/$total 個目標';
  }

  @override
  String get repairTarget => '修復';

  @override
  String get confirmRemoveTarget => '確認移除';

  @override
  String get applyTargetActions => '執行所選操作';

  @override
  String get managementProgressTitle => '正在執行目標操作';

  @override
  String get managementResultsTitle => '目標操作結果';

  @override
  String managementResultSummary(int succeeded, int failed) {
    return '$succeeded 個成功，$failed 個失敗';
  }

  @override
  String get workspaceOwnershipChanges =>
      '所選專案操作將更新 skillsgo.mod 和 skillsgo.sum。';

  @override
  String get targetContentPreserved => '目標當前內容會被保留。';

  @override
  String get localReadFailed => '無法讀取此技能';

  @override
  String get localReadFailedMessage =>
      'SkillsGo 無法讀取這個已安裝的技能。請確認其資料夾存在且可以訪問，然後重試。';

  @override
  String get localConfiguration => 'SKILLSGO 設定';

  @override
  String get settingsNavigation => '設定導航';

  @override
  String get general => '個性化';

  @override
  String get agents => '智慧體';

  @override
  String get hub => 'Hub';

  @override
  String get installationPolicy => '安裝策略';

  @override
  String get storage => '儲存';

  @override
  String get colorScheme => '顏色預覽';

  @override
  String get about => '關於';

  @override
  String get colorSchemeInspectorTitle => 'Material 生成色彩角色';

  @override
  String get skillsColorTokensTitle => 'SkillsGo 語義顏色';

  @override
  String get skillsColorTokensDescription =>
      '由 Radix Sand 色階構建、採用 Primer 語義組織的產品顏色；Folder 是獨立的空間層級。';

  @override
  String get colorSchemeInspectorDescription =>
      '展示當前種子色生成的所有非廢棄 ColorScheme Token。點選色塊即可複製 HEX。';

  @override
  String get colorSchemePairPreview => '語義顏色組合';

  @override
  String get colorSchemePairPreviewDescription =>
      '將前景色和背景色放在一起渲染，直接檢查對比度與資訊層級。';

  @override
  String get colorSchemeComponentPreview => '元件實景';

  @override
  String get colorSchemeComponentPreviewDescription =>
      '使用當前預覽 Scheme 渲染典型 Material 控制元件。';

  @override
  String get colorSchemeSampleTitle => '技能卡片標題';

  @override
  String get colorSchemeSampleBody => '輔助說明使用 onSurfaceVariant。';

  @override
  String get colorSchemeCopied => '已複製';

  @override
  String get colorSchemeSampleGlyphs => '字 Aa 123';

  @override
  String get colorSchemeGroupPrimary => '主色';

  @override
  String get colorSchemeGroupPrimaryDescription => '主要強調、容器與固定主色角色。';

  @override
  String get colorSchemeGroupSecondary => '輔色';

  @override
  String get colorSchemeGroupSecondaryDescription => '輔助強調與固定輔色角色。';

  @override
  String get colorSchemeGroupTertiary => '第三色';

  @override
  String get colorSchemeGroupTertiaryDescription => '與主色、輔色形成對比的補充強調色。';

  @override
  String get colorSchemeGroupSurface => '表面';

  @override
  String get colorSchemeGroupSurfaceDescription => '頁面、容器、層級與前景內容的顏色體系。';

  @override
  String get colorSchemeGroupUtility => '輪廓與輔助';

  @override
  String get colorSchemeGroupUtilityDescription => '邊界、陰影、遮罩和反色表面角色。';

  @override
  String get colorSchemeGroupError => '錯誤';

  @override
  String get colorSchemeGroupErrorDescription => '錯誤操作、訊息和容器角色。';

  @override
  String get colorSchemeUsagePrimary => '主要操作、焦點和高強調裝飾。';

  @override
  String get colorSchemeUsageSecondary => '輔助操作和中等強調裝飾。';

  @override
  String get colorSchemeUsageTertiary => '補充主色與輔色的對比強調色。';

  @override
  String colorSchemeUsageContentOn(String token) {
    return '顯示在 $token 上的文字和圖示。';
  }

  @override
  String colorSchemeUsageContainer(String family) {
    return '用於選中態與強調的低強調 $family 容器。';
  }

  @override
  String colorSchemeUsageFixed(String family) {
    return '不隨明暗模式變化的固定 $family 容器。';
  }

  @override
  String colorSchemeUsageFixedDim(String family) {
    return '較暗的固定 $family 容器，不隨明暗模式變化。';
  }

  @override
  String colorSchemeUsageFixedContent(String family) {
    return '固定 $family 容器上的高強調內容。';
  }

  @override
  String colorSchemeUsageFixedVariantContent(String family) {
    return '固定 $family 容器上的低強調內容。';
  }

  @override
  String get colorSchemeUsageSurface => '頁面和大型區域的基礎表面。';

  @override
  String get colorSchemeUsageSurfaceDim => '表面色階中較暗的基礎表面。';

  @override
  String get colorSchemeUsageSurfaceBright => '表面色階中較亮的基礎表面。';

  @override
  String colorSchemeUsageSurfaceElevation(String level) {
    return '$level 層級的表面容器。';
  }

  @override
  String get colorSchemeElevationLowest => '最低';

  @override
  String get colorSchemeElevationLow => '較低';

  @override
  String get colorSchemeElevationDefault => '預設';

  @override
  String get colorSchemeElevationHigh => '較高';

  @override
  String get colorSchemeElevationHighest => '最高';

  @override
  String get colorSchemeUsageOnSurface => '表面上的主要文字和圖示。';

  @override
  String get colorSchemeUsageOnSurfaceVariant => '表面上的次要文字、標籤和弱化圖示。';

  @override
  String get colorSchemeUsageSurfaceTint => '從主色生成的 Material 層級著色。';

  @override
  String get colorSchemeUsageOutline => '醒目的邊界和獲得焦點的元件輪廓。';

  @override
  String get colorSchemeUsageOutlineVariant => '細微邊界、分隔線和低強調輪廓。';

  @override
  String get colorSchemeUsageShadow => '懸浮表面的投影顏色。';

  @override
  String get colorSchemeUsageScrim => '用於弱化背景內容的模態遮罩。';

  @override
  String get colorSchemeUsageInverseSurface => '明暗強調反轉的表面。';

  @override
  String get colorSchemeUsageInversePrimary => '顯示在反色表面上的主色強調。';

  @override
  String get colorSchemeUsageError => '錯誤操作、狀態與高強調反饋。';

  @override
  String get save => '儲存';

  @override
  String get advancedSettings => '高階';

  @override
  String get remindersSettings => '提醒';

  @override
  String get remindersSettingsTitle => '提醒設定';

  @override
  String get remindersSettingsDescription => '選擇要接收的提醒。';

  @override
  String get updateReminderTitle => '更新提醒';

  @override
  String get updateReminderDescription => '開啟“已安裝”時檢查更新。';

  @override
  String get securityReminderTitle => '高風險提醒';

  @override
  String get securityReminderDescription => '發現已安裝技能存在高風險或嚴重風險時提醒。';

  @override
  String availableUpdatesReminder(int count) {
    return '$count 個已安裝技能有可用更新';
  }

  @override
  String get openAvailableUpdates => '開啟“有更新”檢視，檢視並選擇需要更新的技能。';

  @override
  String securityAdvisoriesReminder(int count) {
    return '$count 個已安裝技能需要安全檢查';
  }

  @override
  String get reviewInstalledSkills => '使用或更新前，請先檢視這些技能的風險資訊。';

  @override
  String get generalSettingsTitle => '讓 SkillsGo 更適合你';

  @override
  String get generalSettingsDescription => '介面會自動跟隨系統語言、輔助功能和動態效果偏好。';

  @override
  String get agentsSettingsTitle => '智慧體執行環境';

  @override
  String get hubSettingsTitle => 'Hub 地址';

  @override
  String get hubSettingsDescription =>
      '使用官方 Hub，或實現相同 SkillsGo 協議的 HTTP(S) 自託管地址。';

  @override
  String get testConnection => '測試連線';

  @override
  String get saveOrigin => '儲存地址';

  @override
  String get resetDefault => '恢復預設';

  @override
  String get connectionReady => '連線正常';

  @override
  String get connectionFailed => '連線失敗';

  @override
  String get hubInvalidOrigin => '請輸入不含賬號密碼、查詢引數或片段的有效 HTTP(S) 地址。';

  @override
  String hubHttpFailure(int status) {
    return 'Hub 傳回 HTTP $status。請檢查 Hub 位址與伺服器設定。';
  }

  @override
  String get hubInvalidProtocol => '伺服器未傳回 SkillsGo Hub 搜尋協定。';

  @override
  String get hubInvalidJson => 'Hub 返回了無效 JSON。';

  @override
  String get hubConnectionFailure => '無法連線至 Hub。請檢查 Hub 位址、網路、Proxy 與 TLS 設定。';

  @override
  String get hubConnectionTimeout => 'Hub 連線超時。請檢查網路或重試。';

  @override
  String get riskPolicyTitle => '個人風險策略';

  @override
  String get riskPolicyDescription => '安全規則會在安裝或更新技能時生效。';

  @override
  String get confirmHighRisk => '高風險必須額外確認';

  @override
  String get confirmHighRiskDescription => '安裝高風險製品前始終要求一次額外確認。';

  @override
  String get allowCriticalOverride => '允許顯式覆蓋嚴重風險阻止';

  @override
  String get allowCriticalOverrideDescription =>
      '嚴重風險製品預設保持阻止。啟用後僅提供單獨的手動覆蓋入口。';

  @override
  String get storageSettingsTitle => '內容定址 Store';

  @override
  String get storageHealthy => '可讀取';

  @override
  String get storageNotInitialized => '尚未初始化';

  @override
  String get storageUnavailable => '不可用';

  @override
  String get storagePathUnavailable => 'CLI 診斷就緒後才能顯示 Store 路徑。';

  @override
  String get storageHealthyDescription => 'CLI 可以讀取 Store，且本次檢查不會修改其中內容。';

  @override
  String get storageNotInitializedDescription => 'Store 尚不存在，本次檢查沒有建立它。';

  @override
  String get storageUnavailableDescription => 'CLI 無法讀取 Store。請檢查目錄權限及其上層目錄。';

  @override
  String get storageInvalidResponse => '內建 CLI 傳回不支援的診斷回應。';

  @override
  String get aboutSettingsTitle => '產品相容性';

  @override
  String get appVersion => 'App 版本';

  @override
  String get cliVersion => '內建 CLI 版本';

  @override
  String get compatible => '相容';

  @override
  String get hubOriginSaved => 'Hub 地址已儲存並立即應用。';

  @override
  String get policySaved => '安裝策略已儲存。';

  @override
  String get officialCli => 'SkillsGo CLI';

  @override
  String get ready => '就緒';

  @override
  String get unknown => '未知';

  @override
  String get missing => '缺失';

  @override
  String get incompatible => '版本不相容';

  @override
  String get detecting => '正在偵測…';

  @override
  String get customCliPath => '自定義可執行檔案路徑';

  @override
  String get saveAndDetect => '儲存並偵測';

  @override
  String get detectAgain => '重新偵測';

  @override
  String get agentInstalled => '已安裝';

  @override
  String get agentSupported => '已支援';

  @override
  String agentCatalogSummary(int installed, int supported) {
    return '已安裝 $installed 個 · 支援 $supported 個';
  }

  @override
  String installedAgentsTitle(int count) {
    return '已安裝 · $count';
  }

  @override
  String notInstalledAgentsTitle(int count) {
    return '未安裝 · $count';
  }

  @override
  String get notInstalledAgentsDescription => 'SkillsGo 已支援，但尚未在這臺 Mac 上偵測到。';

  @override
  String agentDiscoveryRoots(String paths) {
    return '技能載入路徑：$paths';
  }

  @override
  String get agentInspectionFailed => '智慧體偵測資料不可用，請重新偵測。';

  @override
  String get noInstalledAgentsTitle => '未偵測到已安裝的智慧體';

  @override
  String get noInstalledAgentsMessage =>
      '你仍可繼續瀏覽該技能，但當前沒有可用安裝目標。請先安裝一個受支援的智慧體，然後重新偵測。';

  @override
  String get clearCustomPath => '清除自定義路徑';

  @override
  String get privacyProvenance => '隱私與來源說明';

  @override
  String get privacySummary => '你的搜尋記錄不會被儲存，SkillsGo 也不會保留命令日誌。';

  @override
  String get language => '語言';

  @override
  String get personalizationTheme => '主題';

  @override
  String get folderColorTheme => '主題色';

  @override
  String get folderColorThemeDescription => '挑一個喜歡的顏色，SkillsGo 會自動生成協調的介面配色。';

  @override
  String get brandNameNeteaseCloudMusic => '網易雲音樂';

  @override
  String get brandNameRaspberryPi => '樹莓派';

  @override
  String get brandNameChinaEasternAirlines => '中國東方航空';

  @override
  String get brandNameNvidia => '英偉達';

  @override
  String get brandNameTaobao => '淘寶';

  @override
  String get brandNameBitcoin => '比特幣';

  @override
  String get appearanceMode => '模式';

  @override
  String get appearanceModeDescription => '跟隨系統外觀，或始終使用淺色或深色主題。';

  @override
  String get followSystem => '跟隨系統';

  @override
  String get lightMode => '淺色';

  @override
  String get darkMode => '深色';

  @override
  String get wallpaper => '桌布';

  @override
  String get wallpaperDescription => '選擇一張天體背景，設定後會立即顯示在 Folder 後方。';

  @override
  String get wallpaperSun => '太陽';

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
    return '$theme Folder 主題';
  }

  @override
  String get privacyAffiliation =>
      '匿名安裝遙測由 SkillsGo 設定控制。SkillsGo 與 OpenAI 或 Codex 不存在官方隸屬關係。';

  @override
  String get commandCompleted => '命令執行完成';

  @override
  String get commandFailed => '命令執行失敗';

  @override
  String commandExit(int code) {
    return '退出碼 $code · 展開檢視本次會話日誌';
  }

  @override
  String get command => '命令';

  @override
  String get cancel => '取消';

  @override
  String get updateUnknown => '未知';

  @override
  String get updateChecking => '檢查中';

  @override
  String get upToDate => '已是最新';

  @override
  String get updateAvailable => '可更新';

  @override
  String get updateUnavailable => '無法檢查';

  @override
  String get updateCheckFailed => '檢查失敗';

  @override
  String get installSkill => '安裝技能';

  @override
  String get installLocationTitle => '設定技能安裝位置';

  @override
  String get userLevel => '使用者級別';

  @override
  String get projectLevel => '專案級別';

  @override
  String get projects => '專案';

  @override
  String get loading => '正在載入…';

  @override
  String get repositoryParsing => '正在解析 Repository…';

  @override
  String userInstallSummary(int agents) {
    return '將在使用者級別供 $agents 個智慧體使用';
  }

  @override
  String projectInstallSummary(int projects, int agents) {
    return '$projects 個專案 · $agents 個智慧體';
  }

  @override
  String get installationResults => '安裝結果';

  @override
  String get installationInProgress => '正在安裝';

  @override
  String get installationSucceeded => '安裝完成';

  @override
  String get installationSucceededMessage => '技能現在可在所選位置使用。';

  @override
  String get projectUnavailable => '專案不可用';

  @override
  String get installedCell => '已安裝';

  @override
  String get unsupportedCell => '不可用';

  @override
  String get confirmInstall => '確認安裝';

  @override
  String installAllRepositorySkills(int count) {
    return '安裝倉庫所有技能（$count）';
  }

  @override
  String get installAllSkillsTo => '安裝所有技能到';

  @override
  String installRepositorySkills(String repository, int count) {
    return '安裝 $repository 全部技能（$count）';
  }

  @override
  String installSkillTo(String skill) {
    return '安裝 $skill 到';
  }

  @override
  String get availableInAllProjects => '所有專案';

  @override
  String get availableInSelectedProjects => '指定專案';

  @override
  String get usedBy => '用於智慧體';

  @override
  String get backToTargets => '返回目標選擇';

  @override
  String get stayHere => '留在這裡';

  @override
  String get viewInLibrary => '檢視已安裝技能';

  @override
  String planCreateCount(int count) {
    return '建立 $count 個';
  }

  @override
  String planSkipCount(int count) {
    return '跳過 $count 個';
  }

  @override
  String planReplaceCount(int count) {
    return '替換 $count 個';
  }

  @override
  String planConflictCount(int count) {
    return '衝突 $count 個';
  }

  @override
  String planRiskCount(int count) {
    return '風險阻止 $count 個';
  }

  @override
  String get refreshInstallationPlan => '應用解決方案';

  @override
  String get replaceVersionConflict => '替換這個目標中已安裝的版本';

  @override
  String get replaceSkillIdCollision => '替換這個目標中的不同 Skill ID';

  @override
  String get replaceLocalModification => '放棄本地修改並替換這個目標';

  @override
  String get sharedTargetConflict => '此路徑由其他智慧體目標共享';

  @override
  String sharedTargetConflictDescription(String agents) {
    return '返回目標矩陣並選擇所有受影響的智慧體後再替換：$agents';
  }

  @override
  String get replaceConflictingTarget => '替換衝突目標';

  @override
  String get confirmHighRiskArtifact => '確認高風險製品';

  @override
  String get confirmCriticalRiskArtifact => '確認覆蓋嚴重風險';

  @override
  String get confirmRiskForSelectedTargets => '我已檢查製品檔案，並接受在所選目標中安裝此風險製品';

  @override
  String get criticalRiskBlocked => '嚴重風險安裝已被阻止';

  @override
  String get criticalRiskOverrideDisabled => '請先在設定中啟用顯式的嚴重風險覆蓋策略，才能繼續此計劃。';

  @override
  String get workspaceManifestChanges => 'Workspace Manifest 變更';

  @override
  String get noWorkspaceManifestChanges => '不會修改 Workspace Manifest 檔案。';

  @override
  String lockVersionChange(String from, String to) {
    return '$from → $to';
  }

  @override
  String get notPresent => '尚不存在';

  @override
  String get planActionCreate => '建立';

  @override
  String get planActionReplace => '替換';

  @override
  String get planActionSkip => '跳過';

  @override
  String get planActionConflict => '衝突';

  @override
  String get planActionBlockedByRisk => '因風險阻止';

  @override
  String installationResultSummary(int succeeded, int failed) {
    return '已安裝 $succeeded 個目標，$failed 個失敗';
  }

  @override
  String get installationProgressTitle => '正在安裝';

  @override
  String installationProgressSummary(int finished, int total) {
    return '已完成 $finished/$total 個目標';
  }

  @override
  String get targetWaiting => '等待中';

  @override
  String get targetRunning => '正在安裝';

  @override
  String retryFailedTargets(int count) {
    return '重試 $count 個失敗目標';
  }

  @override
  String get updatePlanTitle => '選擇要更新的目標';

  @override
  String get updatePlanDescription => '請選擇明確的安裝目標；未選擇的智慧體和專案不會改變。';

  @override
  String updateTargetsSelected(int selected, int available) {
    return '已選擇 $selected/$available 個可更新目標';
  }

  @override
  String updateVersionChange(String fromVersion, String toVersion) {
    return '$fromVersion → $toVersion';
  }

  @override
  String sourceReference(String reference) {
    return '來源引用：$reference';
  }

  @override
  String get fixedVersionTarget => '已固定——沒有可移動引用';

  @override
  String get currentVersionTarget => '已是最新版本';

  @override
  String get updateCheckTargetFailed => '更新檢查失敗';

  @override
  String get reconcileWorkspaceManifestTarget => '修復工作區清單';

  @override
  String get updateSelectedTargets => '更新所選目標';

  @override
  String get updateProgressTitle => '正在更新目標';

  @override
  String get updateResultsTitle => '更新結果';

  @override
  String updateProgressSummary(int finished, int total) {
    return '已完成 $finished/$total 個目標';
  }

  @override
  String retryFailedUpdates(int count) {
    return '重試 $count 個失敗更新';
  }

  @override
  String get noUpdateableTargets => '所選目標沒有可用更新。';

  @override
  String get closeUpdatePlan => '關閉';

  @override
  String get targetSucceeded => '已安裝';

  @override
  String get targetSkipped => '已跳過';

  @override
  String get targetConflict => '衝突';

  @override
  String get targetFailed => '失敗';

  @override
  String get targetFailureRetryable => '無法更改此位置，你可以重試。';

  @override
  String get targetFailureNeedsAttention => '請先處理此位置的問題，然後重試。';

  @override
  String get installationTargetFailureMessage => '此位置沒有發生更改。請確認資料夾可用後重試。';

  @override
  String get workspacePersistenceFailureMessage =>
      'SkillsGo 無法儲存專案設定，因此沒有更改此位置。請確認專案資料夾可寫後重試。';

  @override
  String get installationStateChangedMessage => '此位置在你確認期間發生了變化。請檢視最新狀態後重試。';

  @override
  String get updateTargetFailureMessage => '無法更新此位置，其他位置不受影響。你可以只重試這一項。';

  @override
  String get managementTargetFailureMessage => '無法在此位置完成操作，其他位置不受影響。你可以只重試這一項。';

  @override
  String get technicalDetails => '技術詳情';

  @override
  String get targetPathExists => '此位置已有其他內容。';

  @override
  String get targetBlockedByRisk => '當前安全設定阻止了在此位置安裝。';

  @override
  String get targetInstallFailed => '無法在此位置安裝技能。';

  @override
  String get targetWorkspaceUpdateFailed => '技能已經安裝，但無法更新專案設定。';

  @override
  String get installationPlanFailed => '安裝計劃無法繼續';

  @override
  String get installationFailed => '安裝未能完成';

  @override
  String get localSource => '本地來源';

  @override
  String get noDescriptionAvailable => '暫無描述';

  @override
  String moreCoverage(int count) {
    return '另外 $count 個安裝位置';
  }

  @override
  String get batchTakeoverAction => '納入 SkillsGo 管理';

  @override
  String batchTakeoverActionCount(int count) {
    return '納入管理（$count）';
  }

  @override
  String get batchTakeoverChecking => '正在檢查可納入的技能…';

  @override
  String get batchTakeoverRetry => '重新檢查可納入技能';

  @override
  String batchTakeoverEligibleCount(int count) {
    return '$count 個可納入管理';
  }

  @override
  String get batchTakeoverPending => '正在納入管理…';

  @override
  String get batchTakeoverTitle => '將現有技能納入 SkillsGo 管理？';

  @override
  String get batchTakeoverDescription =>
      'SkillsGo 可以為受支援鎖定檔記錄的現有複製安裝建立管理記錄，不會移動或覆寫其檔案。不支援或確認後已變更的項目將會略過。';

  @override
  String get batchTakeoverStoryTitle => '把散落的技能，整理成一個清晰的 Library';

  @override
  String batchTakeoverStoryDescription(int count) {
    return 'SkillsGo 在當前位置發現 $count 個可以納入管理的現有技能。';
  }

  @override
  String get batchTakeoverBeforeSemantics =>
      '納入管理前，現有技能裝在哪裡、是不是最新、損壞後如何恢復，以及不同專案間的版本是否一致，都缺少清晰狀態。';

  @override
  String get batchTakeoverPainLocation => '不知道裝在哪';

  @override
  String get batchTakeoverPainFreshness => '不知道是不是最新';

  @override
  String get batchTakeoverPainRecovery => '壞了無法恢復';

  @override
  String get batchTakeoverPainVersionDrift => '多個專案版本不一致';

  @override
  String get batchTakeoverFolderTitle => '現有 Skills';

  @override
  String get batchTakeoverFolderSubtitle => '狀態不清晰';

  @override
  String get batchTakeoverAfterLabel => '納入後';

  @override
  String get batchTakeoverAfterTitle => '一個清晰的 Library';

  @override
  String get batchTakeoverLibraryTitle => 'SkillsGo Library';

  @override
  String get batchTakeoverBenefitLocation => '位置清晰';

  @override
  String get batchTakeoverBenefitFreshness => '更新可見';

  @override
  String get batchTakeoverBenefitRecovery => '隨時恢復';

  @override
  String get batchTakeoverBenefitVersions => '版本明確';

  @override
  String get batchTakeoverManagedSection => 'SkillsGo 管理中';

  @override
  String get batchTakeoverPendingSection => '待納入';

  @override
  String batchTakeoverItemManaged(String name) {
    return '$name 已納入 SkillsGo 管理';
  }

  @override
  String batchTakeoverItemSkipped(String name) {
    return '$name 未能納入管理';
  }

  @override
  String batchTakeoverItemPending(String name) {
    return '$name 等待納入管理';
  }

  @override
  String batchTakeoverAfterSemantics(int count) {
    return '納入管理後，$count 個技能會整理到同一個 Library 中，並顯示清晰的管理狀態。';
  }

  @override
  String batchTakeoverMoreSkills(int count) {
    return '另外 $count 個';
  }

  @override
  String get batchTakeoverTransitionSemantics => '將這些現有技能納入 SkillsGo 管理。';

  @override
  String get batchTakeoverTransitionLabel => '整理';

  @override
  String get batchTakeoverStatusTitle => '納入狀態';

  @override
  String get batchTakeoverStatusManaged => '已納入';

  @override
  String get batchTakeoverStatusProgress => '正在整理';

  @override
  String get batchTakeoverStatusSkipped => '已跳過';

  @override
  String get batchTakeoverStatusFilesStay => '技能檔案保留在原來的位置';

  @override
  String get batchTakeoverBoardSemantics =>
      '技能會排列成完整的行並由 SkillsGo 建立管理記錄，原檔案不會移動。';

  @override
  String get batchTakeoverBoardComplete => '全部整理';

  @override
  String get batchTakeoverBoardPartial => '整理完成';

  @override
  String get batchTakeoverStatusTotal => '總計';

  @override
  String get batchTakeoverQueueComplete => '沒有待納入的技能';

  @override
  String get batchTakeoverQueueWaiting => '驗證完成後，技能會從這裡開始整理';

  @override
  String get batchTakeoverNextLabel => 'NEXT';

  @override
  String batchTakeoverFillerCount(int count) {
    return '使用 $count 個 SkillsGo 整理塊補全最後幾行';
  }

  @override
  String get batchTakeoverPreservation =>
      '原檔案、原路徑和現有用法全部保留。SkillsGo 只會補全本地管理記錄。';

  @override
  String get batchTakeoverLaterHint => '暫時跳過後，仍可隨時在 Library 點選「納入管理」。';

  @override
  String get batchTakeoverSkip => '暫時跳過';

  @override
  String get batchTakeoverConfirm => '納入管理';

  @override
  String get batchTakeoverExecutionRetry => '重試納入';

  @override
  String get batchTakeoverResultTitle => '已納入管理';

  @override
  String batchTakeoverSummary(int takenOver, int skipped) {
    return '已納入管理 $takenOver 個技能，跳過 $skipped 個。';
  }

  @override
  String get batchTakeoverClose => '關閉';

  @override
  String get installMoreTargets => '安裝到更多位置';

  @override
  String get exportLocalSkill => '匯出';

  @override
  String get exportLocalSkillDescription => '將這個本地技能匯出為可移植的 ZIP 歸檔。';

  @override
  String get detailRepository => '倉庫';

  @override
  String get detailStars => '星標';

  @override
  String get detailUpdated => '最近更新';

  @override
  String get detailArchiveSize => 'ZIP 大小';

  @override
  String get pathLabel => '專案路徑';

  @override
  String get copyProjectPath => '複製專案路徑';

  @override
  String get projectPathCopied => '專案路徑已複製';

  @override
  String get onboardingWelcomeTitle => '歡迎使用 SkillsGo';

  @override
  String get onboardingWelcomeDescription => '發現、安裝和管理所有智慧體與專案中的 Skills。';

  @override
  String get onboardingDetectedAgents => '已偵測到的智慧體';

  @override
  String get onboardingNoAgents => '未偵測到已安裝的智慧體，你仍然可以繼續。';

  @override
  String get onboardingNext => '下一步';

  @override
  String get onboardingProjectsTitle => '新增你的專案';

  @override
  String get onboardingProjectsDescription => '選擇你希望 SkillsGo 管理的專案。';

  @override
  String get onboardingAddProject => '現在新增';

  @override
  String get onboardingAddProjectLater => '或者稍後';

  @override
  String get onboardingStartUsing => '開始使用';

  @override
  String get onboardingBack => '返回';

  @override
  String get restartOnboardingTitle => '啟動引導';

  @override
  String get restartOnboardingDescription => '重新檢視首次啟動引導，不會刪除專案、設定或 Skills 資料。';

  @override
  String get restartOnboardingAction => '重新開始引導';

  @override
  String get restartOnboardingFailed => '無法重新開始啟動引導。';

  @override
  String get libraryRefreshSettingsTitle => '重新整理本地技能庫';

  @override
  String get libraryRefreshSettingsDescription =>
      '重新掃描已安裝 Skills、已新增專案、智慧體，以及可納入管理的外部 Skills。此操作不會安裝、更新或移除任何內容。';

  @override
  String get libraryRefreshSettingsAction => '重新整理技能庫';

  @override
  String get libraryRefreshSettingsPending => '正在重新整理技能庫…';

  @override
  String get libraryRefreshSettingsSuccess => '本地技能庫已重新整理。';

  @override
  String get libraryRefreshSettingsFailed => 'SkillsGo 無法重新整理本地技能庫。';

  @override
  String get onboardingProjectError => 'SkillsGo 無法從這個目錄新增專案。';

  @override
  String get onboardingProjectsLoadError => 'SkillsGo 無法載入已新增的專案。';

  @override
  String get onboardingStartupError => 'SkillsGo 無法載入初始設定。';

  @override
  String get onboardingStateError => 'SkillsGo 無法儲存設定進度，請重試。';

  @override
  String get onboardingCliErrorTitle => 'SkillsGo CLI 需要處理';

  @override
  String get onboardingCliErrorDescription => '修復內建 CLI 後重試，即可繼續。';
}
