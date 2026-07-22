// ignore_for_file: text_direction_code_point_in_literal, text_direction_code_point_in_comment

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get discover => '発見する';

  @override
  String get discoverSkills => 'もう少し詳しく知ることができてよかったです。';

  @override
  String get library => '図書館';

  @override
  String get settings => '設定';

  @override
  String get openSettings => '設定を開く';

  @override
  String get cliNeedsAttention => '必須の SkillsGo コンポーネントには注意が必要です。';

  @override
  String get cliMissingBundled =>
      'SkillsGo の必須コンポーネントが見つからないか、起動できません。復元するには SkillsGo を再インストールしてください。';

  @override
  String get cliDamagedBundled =>
      'SkillsGo の必須コンポーネントが破損しています。復元するには SkillsGo を再インストールしてください。';

  @override
  String get cliIncompatibleBundled =>
      'SkillsGo の必須コンポーネントがこのアプリのバージョンと一致しません。SkillsGo を更新するか、再インストールしてください。';

  @override
  String get officialIndex => 'SkillsGo ハブ';

  @override
  String get discoverTitle => '次の動きのためのスキルを見つけてください。';

  @override
  String get skillsLeaderboard => 'もう少し詳しく知ることができてよかったです。';

  @override
  String searchResultsFor(String query) {
    return '「$query」の結果';
  }

  @override
  String get searchSkills => 'スキルを検索するか、Git リンクを貼り付けます…';

  @override
  String get search => '検索';

  @override
  String get ranking => 'ランキング';

  @override
  String get trending => 'トレンド';

  @override
  String get hot => 'ホット';

  @override
  String get discoverNavigation => 'ナビゲーションを発見する';

  @override
  String get allTimeRanking => '歴代ランキング';

  @override
  String get trendingNow => '過去 24 時間のトレンド';

  @override
  String get hotNow => '今熱いです';

  @override
  String get allTimeDescription => '公開スキルは、全期間にわたって受け入れられたインストール数によって並べられます。';

  @override
  String get trendingDescription =>
      '最新の 24 時間枠内に承認されたインストールによって注文されたパブリック スキル。';

  @override
  String get hotDescription => 'パブリック スキルは、短期的なインストール速度と変化によって並べられます。';

  @override
  String get offlineTitle => 'SkillsGo に接続できません';

  @override
  String get offlineMessage =>
      'インターネット接続を確認して、もう一度試してください。プロキシまたはカスタム サービス アドレスを使用する場合は、[設定] で確認してください。';

  @override
  String get searchFailedTitle => '検索中に問題が発生しました';

  @override
  String get validationTitle => '入力した内容を確認してください';

  @override
  String get validationMessage =>
      'SkillsGo はこのリクエストを使用できませんでした。入力した内容を確認して、再試行してください。';

  @override
  String get serverTitle => 'サービスが一時的に利用できなくなります';

  @override
  String get serverMessage =>
      'SkillsGo は現在このリクエストを完了できません。しばらくしてからもう一度試してください。';

  @override
  String get timeoutTitle => '時間がかかりすぎます';

  @override
  String get timeoutMessage => 'サービスは時間内に応答しませんでした。接続を確認するか、もう一度試してください。';

  @override
  String get invalidResponseTitle => 'SkillsGo にはアップデートが必要です';

  @override
  String get invalidResponseMessage =>
      'この応答は、お使いのバージョンの SkillsGo では読み取ることができません。アプリを更新してから、もう一度お試しください。';

  @override
  String get invalidLocalDataTitle => 'インストールされているスキルを読み取れません';

  @override
  String get invalidLocalDataMessage =>
      '一部のローカル インストール情報が破損しているか、互換性がありません。 SkillsGo を更新または再インストールして、もう一度試してください。';

  @override
  String get tryAgain => 'もう一度試してください';

  @override
  String get searchEmptyTitle => 'スクロールせずに検索してください。';

  @override
  String get searchEmptyMessage => '機能、ソース、またはタスクを入力して公開スキルを検索します。';

  @override
  String get noSkillsTitle => 'スキルが見つかりません';

  @override
  String get noSkillsMessage => 'より幅広いフレーズを試すか、スペルを確認してください。';

  @override
  String get focusSearch => 'フォーカス検索';

  @override
  String get skillsFromLink => 'スキルはこちらのリンクから';

  @override
  String skillCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count スキル',
      one: '1 スキル',
    );
    return '$_temp0';
  }

  @override
  String sourceResultsSummary(String source, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$source のスキル $count 個',
      one: '$source のスキル 1 個',
    );
    return '$_temp0';
  }

  @override
  String get sourceSearchEmptyTitle => 'このリンクは検査する準備ができています';

  @override
  String sourceSearchEmptyMessage(String source) {
    return '$source は現在の検索結果にありません。 SkillsGo は、次のステップでリンクを直接検査できます。';
  }

  @override
  String get inspectSource => 'このリンクでスキルを表示';

  @override
  String get collectionEmptyTitle => 'このコレクションにはスキルがありません';

  @override
  String get collectionEmptyMessage =>
      'ここにはまだ何もありません。さらにインストール作業を行った後、再試行してください。';

  @override
  String get loadMore => 'さらにロードする';

  @override
  String get install => 'インストール';

  @override
  String get installAll => 'すべてのスキルをインストールする';

  @override
  String get latestCommit => '最新のコミット';

  @override
  String get installToMoreTargets => 'より多くの場所に設置';

  @override
  String localTargets(int count) {
    return '$count 個のローカル ターゲット';
  }

  @override
  String allTimeMetric(String count) {
    return '$count 回の常時インストール数';
  }

  @override
  String trendingMetric(String count) {
    return '$count のインストール数 / 24 時間';
  }

  @override
  String hotMetric(String value, String change) {
    return 'この時間 $value · $change';
  }

  @override
  String get trustUnverified => '未検証';

  @override
  String get trustCommunityVerified => 'コミュニティが検証済み';

  @override
  String get trustPublisherVerified => '発行者が確認済み';

  @override
  String get trustOfficial => '公式';

  @override
  String get trustWarned => '警告';

  @override
  String get trustDelisted => '上場廃止';

  @override
  String get riskUnknown => 'リスクは不明';

  @override
  String get riskLow => '低リスク';

  @override
  String get riskMedium => '中リスク';

  @override
  String get riskHigh => '高リスク';

  @override
  String get riskCritical => '重大なリスク';

  @override
  String openSkill(String name) {
    return '$name を開く';
  }

  @override
  String installs(String count) {
    return 'インストール数 $count';
  }

  @override
  String get detailFailedTitle => 'このスキルをロードできませんでした';

  @override
  String get detailLoading => '監査可能なスキルの詳細をロードしています';

  @override
  String get artifactUnavailableTitle => 'アーティファクトが利用不可';

  @override
  String get artifactUnavailableMessage =>
      'このバージョンは現在利用できません。もう一度試すか、別のバージョンを選択してください。';

  @override
  String get detailInvalidTitle => 'アーティファクトメタデータはサポートされていません';

  @override
  String get detailInvalidMessage =>
      'このスキルの詳細の一部が不完全であるか、読み取ることができません。 SkillsGo を更新して、もう一度お試しください。';

  @override
  String get instructionsTab => '指示';

  @override
  String get manifestTab => 'マニフェスト';

  @override
  String immutableVersionLabel(String version) {
    return '不変の $version';
  }

  @override
  String commitIdentity(String sha) {
    return '$shaをコミット';
  }

  @override
  String treeIdentity(String sha) {
    return 'ツリー $sha';
  }

  @override
  String contentIdentity(String digest) {
    return 'コンテンツ $digest';
  }

  @override
  String get trustDoesNotProveSafety =>
      '発行者の信頼により、所有権またはメンテナンスが検証されます。アーティファクトの安全性を保証するものではありません。この不変バージョンのリスクは個別に評価されます。';

  @override
  String get knownInstallationTargets => '既知のインストール対象';

  @override
  String get installationRange => '設置範囲';

  @override
  String get targetDetails => 'ターゲットの詳細を表示';

  @override
  String get hideTargetDetails => 'ターゲットの詳細を非表示にする';

  @override
  String installedVersionLabel(String version) {
    return 'バージョン $version';
  }

  @override
  String targetSummary(String scope, String agent, String version) {
    return '$scope / $agent · $version';
  }

  @override
  String get projectScope => 'プロジェクト';

  @override
  String get fileContentUnavailable => 'バイナリまたは使用できないプレビュー';

  @override
  String get fileContentTruncated => 'プレビューはハブの安全制限によって切り詰められます。';

  @override
  String get retry => '再試行';

  @override
  String get backToSearch => '検索に戻る';

  @override
  String get installForCodex => 'コーデックス用にインストールする';

  @override
  String get cliNotDetected => 'スキル（検出されません）';

  @override
  String get snapshotFiles => 'スナップショットファイル';

  @override
  String get globalCodex => 'グローバル・コーデックス';

  @override
  String get yourLibrary => 'あなたが知っていることはすべてここにあります。';

  @override
  String get libraryNavigation => '図書館のナビゲーション';

  @override
  String get all => 'すべて';

  @override
  String get allSkills => 'すべてのスキル';

  @override
  String get updatesOnly => 'アップデート';

  @override
  String get allAgents => 'すべてのエージェント';

  @override
  String get allProjects => 'すべてのプロジェクト';

  @override
  String get specificProject => 'プロジェクト';

  @override
  String get userScope => 'グローバル';

  @override
  String get addProject => 'プロジェクトの追加';

  @override
  String get relocateProject => '移転する';

  @override
  String get removeFromList => 'リストから削除';

  @override
  String removeProjectTitle(String name) {
    return '$name を SkillsGo から削除しますか?';
  }

  @override
  String get removeProjectDescription =>
      'アプリ参照のみが削除されます。 SkillsGo は、このディレクトリ内のファイルを変更または削除しません。';

  @override
  String projectRailUnavailable(String name) {
    return '$name — 利用不可';
  }

  @override
  String get emptyProjectTitle => 'まだスキルがありません';

  @override
  String get browseSkills => 'スキルを参照する';

  @override
  String get projectMissingTitle => 'プロジェクトディレクトリがありません';

  @override
  String get projectMissingMessage =>
      'ディレクトリが移動したか、そのボリュームがオフラインになっている可能性があります。再配置するか、App 参照のみを削除します。';

  @override
  String get projectPermissionTitle => 'プロジェクトの許可が必要です';

  @override
  String get projectPermissionMessage =>
      'SkillsGo は選択したルートを確認できません。ディレクトリ選択画面でもう一度このフォルダーを選択し、アクセスを許可してください。';

  @override
  String get projectInaccessibleTitle => 'プロジェクトディレクトリにアクセスできません';

  @override
  String get projectInaccessibleMessage =>
      'SkillsGo はこのプロジェクト参照を保管していました。パスまたはボリュームを確認し、再配置してください。';

  @override
  String get checking => '確認中…';

  @override
  String get checkUpdates => 'アップデートを確認する';

  @override
  String get refresh => 'リフレッシュ';

  @override
  String get libraryUnavailable => '図書館は利用できません';

  @override
  String get libraryEmpty => 'まだスキルがインストールされていません';

  @override
  String get libraryEmptyMessage => 'Discover からスキルをインストールすると、ここに表示されます。';

  @override
  String get searchLibrary => 'インストールされているスキルを検索する';

  @override
  String get libraryNoMatches => '一致するスキルがありません';

  @override
  String get libraryNoMatchesMessage =>
      '別の名前、ソース、エージェント、プロジェクト、またはバージョンを試してください。';

  @override
  String agentsSummary(int count) {
    return '$count エージェント';
  }

  @override
  String projectsSummary(int count) {
    return '$count プロジェクト';
  }

  @override
  String versionsSummary(int count) {
    return '$count バージョン';
  }

  @override
  String get hubManaged => 'ハブ管理';

  @override
  String get localManaged => 'ローカル管理';

  @override
  String get externalInstallation => '外部設置';

  @override
  String get readOnly => '読み取り専用';

  @override
  String get unversioned => 'バージョン管理されていない';

  @override
  String get supportingFiles => 'サポートファイル';

  @override
  String get versionDivergence => 'バージョンの相違';

  @override
  String get healthHealthy => '健康';

  @override
  String get healthMissing => 'ターゲットが見つかりません';

  @override
  String get healthReplaced => 'ターゲットが交換されました';

  @override
  String get healthLocalModification => 'ローカルな変更';

  @override
  String get healthUnreadable => 'ターゲットを読み取れません';

  @override
  String get healthUndeclared => '宣言されていない';

  @override
  String get healthWorkspaceUnreadable => 'ワークスペースの状態を読み取ることができません';

  @override
  String get healthLockMismatch => 'ロックの不一致';

  @override
  String get healthUnexpectedPath => '予期しないターゲット パス';

  @override
  String get modeSymlink => 'シンボリックリンク';

  @override
  String get modeCopy => 'コピー';

  @override
  String get modeExternal => '外部';

  @override
  String get notLinked => 'リンクされていません';

  @override
  String get update => 'アップデート';

  @override
  String get backToLibrary => 'ライブラリに戻る';

  @override
  String get remove => '削除';

  @override
  String get manageTargets => 'スコープの管理';

  @override
  String skillsSelected(int count) {
    return '$count が選択されました';
  }

  @override
  String get clearSelection => '選択をクリア';

  @override
  String get selectCurrentResults => '現在の結果を選択してください';

  @override
  String get clearCurrentResultSelection => '現在の結果の選択をクリアします';

  @override
  String get manageTargetsTitle => 'インストールターゲットの管理';

  @override
  String get manageTargetsDescription =>
      'ターゲットごとに正確なアクションを選択してください。選択されていないターゲットは変更されません。';

  @override
  String targetActionsSelected(int selected, int total) {
    return '$total 個中 $selected 個のターゲットが選択されました';
  }

  @override
  String get repairTarget => '修理';

  @override
  String get confirmRemoveTarget => '削除の確認';

  @override
  String get applyTargetActions => '選択したアクションを適用する';

  @override
  String get managementProgressTitle => 'ターゲットアクションの適用';

  @override
  String get managementResultsTitle => '目標行動結果';

  @override
  String managementResultSummary(int succeeded, int failed) {
    return '$succeeded は成功しました、$failed は失敗しました';
  }

  @override
  String get workspaceOwnershipChanges =>
      '選択したプロジェクト アクションにより、skillgo.mod と skillgo.sum が更新されます。';

  @override
  String get targetContentPreserved => '現在のターゲット コンテンツは保持されます。';

  @override
  String get localReadFailed => 'このスキルを読み取れません';

  @override
  String get localReadFailedMessage =>
      'SkillsGo は、このインストールされたスキルを読み取ることができませんでした。そのフォルダーが使用可能でアクセス可能であることを確認してから、再試行してください。';

  @override
  String get localConfiguration => 'スキルゴー設定';

  @override
  String get settingsNavigation => '設定ナビゲーション';

  @override
  String get general => 'パーソナライズ';

  @override
  String get agents => 'エージェント';

  @override
  String get hub => 'ハブ';

  @override
  String get installationPolicy => 'インストールポリシー';

  @override
  String get storage => 'ストレージ';

  @override
  String get colorScheme => 'カラースキーム';

  @override
  String get about => 'について';

  @override
  String get colorSchemeInspectorTitle => '生成されたマテリアルの色の役割';

  @override
  String get skillsColorTokensTitle => 'SkillsGo セマンティック カラー';

  @override
  String get skillsColorTokensDescription =>
      '製品の色は Radix Sand から構築され、専用の空間階層としてのフォルダーを使用して Primer セマンティクスで編成されます。';

  @override
  String get colorSchemeInspectorDescription =>
      '現在のシードから生成された非推奨でない ColorScheme トークンをすべてプレビューします。色をクリックして、その HEX 値をコピーします。';

  @override
  String get colorSchemePairPreview => 'セマンティックペア';

  @override
  String get colorSchemePairPreviewDescription =>
      '前景と背景の役割を一緒にレンダリングして、コントラストと階層を明らかにします。';

  @override
  String get colorSchemeComponentPreview => 'コンポーネントのプレビュー';

  @override
  String get colorSchemeComponentPreviewDescription =>
      'この正確なプレビュー スキームを使用してレンダリングされた代表的なマテリアル コントロール。';

  @override
  String get colorSchemeSampleTitle => 'スキルカードのタイトル';

  @override
  String get colorSchemeSampleBody => 'セカンダリ コピーは onSurfaceVariant を使用します。';

  @override
  String get colorSchemeCopied => 'コピーされました';

  @override
  String get colorSchemeSampleGlyphs => 'ああ123';

  @override
  String get colorSchemeGroupPrimary => 'プライマリー';

  @override
  String get colorSchemeGroupPrimaryDescription => '主な強調、コンテナ、および固定アクセントの役割。';

  @override
  String get colorSchemeGroupSecondary => '二次';

  @override
  String get colorSchemeGroupSecondaryDescription => 'サポートの強調と固定の二次的な役割。';

  @override
  String get colorSchemeGroupTertiary => '三次';

  @override
  String get colorSchemeGroupTertiaryDescription => '対照的なアクセントと固定された三次的な役割。';

  @override
  String get colorSchemeGroupSurface => '表面';

  @override
  String get colorSchemeGroupSurfaceDescription => 'ページ、コンテナ、立面図、および前景階層。';

  @override
  String get colorSchemeGroupUtility => '概要とユーティリティ';

  @override
  String get colorSchemeGroupUtilityDescription => '境界、シャドウ、スクリム、および反転サーフェス。';

  @override
  String get colorSchemeGroupError => 'エラー';

  @override
  String get colorSchemeGroupErrorDescription => 'エラーアクション、メッセージ、コンテナ。';

  @override
  String get colorSchemeUsagePrimary => '主なアクション、焦点、および強調されたアクセント。';

  @override
  String get colorSchemeUsageSecondary => 'サポートアクションと中程度の強調のアクセント。';

  @override
  String get colorSchemeUsageTertiary => 'プライマリとセカンダリを補完する対照的なアクセント。';

  @override
  String colorSchemeUsageContentOn(String token) {
    return '$token に表示されるテキストとアイコン。';
  }

  @override
  String colorSchemeUsageContainer(String family) {
    return '選択範囲とアクセント用の低強調 $family コンテナ。';
  }

  @override
  String colorSchemeUsageFixed(String family) {
    return '明るさに依存しない固定の $family コンテナ。';
  }

  @override
  String colorSchemeUsageFixedDim(String family) {
    return '薄暗くなった明るさに依存しない固定の $family コンテナ。';
  }

  @override
  String colorSchemeUsageFixedContent(String family) {
    return '固定された $family コンテナ上の重点コンテンツ。';
  }

  @override
  String colorSchemeUsageFixedVariantContent(String family) {
    return '固定された $family コンテナーの低強調コンテンツ。';
  }

  @override
  String get colorSchemeUsageSurface => 'ベースページと広い領域の表面。';

  @override
  String get colorSchemeUsageSurfaceDim => '最も暗い表面色調で使用される薄暗いベース表面。';

  @override
  String get colorSchemeUsageSurfaceBright => '最も明るい表面色調で使用される明るいベース表面。';

  @override
  String colorSchemeUsageSurfaceElevation(String level) {
    return '$level サーフェス コンテナの標高。';
  }

  @override
  String get colorSchemeElevationLowest => '最低の';

  @override
  String get colorSchemeElevationLow => '低い';

  @override
  String get colorSchemeElevationDefault => 'デフォルト';

  @override
  String get colorSchemeElevationHigh => '高い';

  @override
  String get colorSchemeElevationHighest => '最高の';

  @override
  String get colorSchemeUsageOnSurface => '表面に表示される主要なテキストとアイコン。';

  @override
  String get colorSchemeUsageOnSurfaceVariant => '表面上の二次的なテキスト、ラベル、控えめなアイコン。';

  @override
  String get colorSchemeUsageSurfaceTint => 'プライマリから派生したマテリアル標高の色合い。';

  @override
  String get colorSchemeUsageOutline => '顕著な境界と焦点を当てたコンポーネントの輪郭。';

  @override
  String get colorSchemeUsageOutlineVariant => '微妙な境界線、区切り線、強調度の低い輪郭。';

  @override
  String get colorSchemeUsageShadow => '盛り上がったサーフェスのドロップ シャドウ カラー。';

  @override
  String get colorSchemeUsageScrim => '背景コンテンツを強調しないようにするために使用されるモーダル オーバーレイ。';

  @override
  String get colorSchemeUsageInverseSurface => '明暗を反転した表面。';

  @override
  String get colorSchemeUsageInversePrimary => '主要なアクセントが裏面に表示されます。';

  @override
  String get colorSchemeUsageError => 'エラーアクション、ステータス、および強調されたフィードバック。';

  @override
  String get save => '保存';

  @override
  String get advancedSettings => '上級者向け';

  @override
  String get remindersSettings => 'リマインダー';

  @override
  String get remindersSettingsTitle => 'リマインダー設定';

  @override
  String get remindersSettingsDescription => '受信するリマインダーを選択します。';

  @override
  String get updateReminderTitle => 'リマインダーを更新する';

  @override
  String get updateReminderDescription => 'ライブラリが開いたら更新を確認してください。';

  @override
  String get securityReminderTitle => '高リスクのアラート';

  @override
  String get securityReminderDescription =>
      'インストールされているスキルの新たな高リスクまたは重大リスクを通知します。';

  @override
  String availableUpdatesReminder(int count) {
    return '$count にインストールされているスキルが更新されました';
  }

  @override
  String get openAvailableUpdates => '利用可能な更新ビューを開いて確認し、更新します。';

  @override
  String securityAdvisoriesReminder(int count) {
    return '$count にインストールされているスキルにはセキュリティレビューが必要です';
  }

  @override
  String get reviewInstalledSkills => '使用または更新する前に、リスク情報を確認してください。';

  @override
  String get generalSettingsTitle => 'スキルを自分のものにする';

  @override
  String get generalSettingsDescription =>
      'インターフェイスは、システム言語、アクセシビリティ、およびモーションの設定に従います。';

  @override
  String get agentsSettingsTitle => 'エージェントのランタイム';

  @override
  String get hubSettingsTitle => 'ハブの原点';

  @override
  String get hubSettingsDescription =>
      '公式ハブ、または同じ SkillsGo プロトコルを実装する HTTP(S) セルフホスト型オリジンを使用します。';

  @override
  String get testConnection => 'テスト接続';

  @override
  String get saveOrigin => '原点の保存';

  @override
  String get resetDefault => 'デフォルトにリセットする';

  @override
  String get connectionReady => '接続準備完了';

  @override
  String get connectionFailed => '接続に失敗しました';

  @override
  String get hubInvalidOrigin =>
      '認証情報、クエリ、またはフラグメントを含まない有効な HTTP(S) オリジンを入力します。';

  @override
  String hubHttpFailure(int status) {
    return 'ハブが HTTP $status を返しました。オリジンとサーバーの構成を確認してください。';
  }

  @override
  String get hubInvalidProtocol => 'サーバーは SkillsGo Hub 検索プロトコルを返しませんでした。';

  @override
  String get hubInvalidJson => 'ハブが無効な JSON を返しました。';

  @override
  String get hubConnectionFailure =>
      'ハブに到達できませんでした。オリジン、ネットワーク、プロキシ、および TLS 構成を確認します。';

  @override
  String get hubConnectionTimeout =>
      'ハブ接続がタイムアウトしました。ネットワークを確認するか、もう一度試してください。';

  @override
  String get riskPolicyTitle => '個人リスクポリシー';

  @override
  String get riskPolicyDescription => 'スキルをインストールまたは更新するときに、安全ルールが適用されます。';

  @override
  String get confirmHighRisk => '高リスクの場合は確認が必要';

  @override
  String get confirmHighRiskDescription =>
      'リスクの高いアーティファクトについては、インストール前に必ず追加の確認が必要です。';

  @override
  String get allowCriticalOverride => 'クリティカルリスクの明示的なオーバーライドを許可する';

  @override
  String get allowCriticalOverrideDescription =>
      'クリティカルリスクのアーティファクトはデフォルトでブロックされたままになります。これを有効にするのは、個別の手動オーバーライドを公開する場合のみです。';

  @override
  String get storageSettingsTitle => 'コンテンツアドレス型ストア';

  @override
  String get storageHealthy => '読みやすい';

  @override
  String get storageNotInitialized => '初期化されていません';

  @override
  String get storageUnavailable => '利用不可';

  @override
  String get storagePathUnavailable => 'CLI 診断が準備できるまで、ストア パスは使用できません。';

  @override
  String get storageHealthyDescription => 'CLI は、内容を変更せずにストアを読み取ることができます。';

  @override
  String get storageNotInitializedDescription =>
      'ストアはまだ存在せず、このチェックによって作成されていません。';

  @override
  String get storageUnavailableDescription =>
      'CLI はストアを読み取ることができません。権限と親ディレクトリを確認してください。';

  @override
  String get storageInvalidResponse => 'バンドルされた CLI がサポートされていない診断応答を返しました。';

  @override
  String get aboutSettingsTitle => '製品の互換性';

  @override
  String get appVersion => 'アプリのバージョン';

  @override
  String get cliVersion => 'バンドルされた CLI バージョン';

  @override
  String get compatible => '互換性のある';

  @override
  String get hubOriginSaved => 'ハブの原点が保存され、適用されました。';

  @override
  String get policySaved => 'インストールポリシーが保存されました。';

  @override
  String get officialCli => 'SkillsGo CLI';

  @override
  String get ready => '準備完了';

  @override
  String get unknown => '不明';

  @override
  String get missing => '行方不明';

  @override
  String get incompatible => '互換性がありません';

  @override
  String get detecting => '検出中…';

  @override
  String get customCliPath => 'カスタム実行可能パス';

  @override
  String get saveAndDetect => '保存と検出';

  @override
  String get detectAgain => '再検出';

  @override
  String get agentInstalled => 'インストール済み';

  @override
  String get agentSupported => 'サポートされています';

  @override
  String agentCatalogSummary(int installed, int supported) {
    return '$installed がインストールされています · $supported がサポートされています';
  }

  @override
  String installedAgentsTitle(int count) {
    return 'インストール済み · $count';
  }

  @override
  String notInstalledAgentsTitle(int count) {
    return 'インストールされていません · $count';
  }

  @override
  String get notInstalledAgentsDescription =>
      'SkillsGo でサポートされていますが、この Mac では検出されません。';

  @override
  String agentDiscoveryRoots(String paths) {
    return 'スキル読み込みパス: $paths';
  }

  @override
  String get agentInspectionFailed => 'エージェント検出データは利用できません。検出を再度実行します。';

  @override
  String get noInstalledAgentsTitle => 'インストールされているエージェントが検出されませんでした';

  @override
  String get noInstalledAgentsMessage =>
      'このスキルを参照し続けることはできますが、インストール対象はまだありません。サポートされているエージェントをインストールしてから、検出を再度実行します。';

  @override
  String get clearCustomPath => 'カスタムパスをクリアする';

  @override
  String get privacyProvenance => 'プライバシーと出所';

  @override
  String get privacySummary => '検索は保存されず、SkillsGo はコマンド ログを保存しません。';

  @override
  String get language => '言語';

  @override
  String get personalizationTheme => 'テーマ';

  @override
  String get folderColorTheme => 'テーマカラー';

  @override
  String get folderColorThemeDescription =>
      '好きな色を選んでください。 SkillsGo は、それを中心に調整されたインターフェイス パレットを構築します。';

  @override
  String get brandNameNeteaseCloudMusic => 'NetEase クラウド ミュージック';

  @override
  String get brandNameRaspberryPi => 'ラズベリーパイ';

  @override
  String get brandNameChinaEasternAirlines => '中国東方航空';

  @override
  String get brandNameNvidia => 'エヌビディア';

  @override
  String get brandNameTaobao => 'タオバオ';

  @override
  String get brandNameBitcoin => 'ビットコイン';

  @override
  String get appearanceMode => 'モード';

  @override
  String get appearanceModeDescription =>
      'システムの外観に従うか、常に明るいテーマまたは暗いテーマを使用してください。';

  @override
  String get followSystem => 'システム';

  @override
  String get lightMode => 'ライト';

  @override
  String get darkMode => '暗い';

  @override
  String get wallpaper => '壁紙';

  @override
  String get wallpaperDescription => '天体の背景を選択します。選択した内容は、「フォルダー」のすぐ後ろに表示されます。';

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
  String get wallpaperJupiter => 'ジュピター';

  @override
  String get wallpaperSaturn => '土星';

  @override
  String get wallpaperUranus => '天王星';

  @override
  String get wallpaperNeptune => 'ネプチューン';

  @override
  String get wallpaperPluto => '冥王星';

  @override
  String get wallpaperMoon => '月';

  @override
  String folderThemeChoice(String theme) {
    return '$theme フォルダーのテーマ';
  }

  @override
  String get privacyAffiliation =>
      '匿名インストール テレメトリは、SkillsGo 設定によって制御されます。 SkillsGo は OpenAI または Codex とは提携していません。';

  @override
  String get commandCompleted => 'コマンドが完了しました';

  @override
  String get commandFailed => 'コマンドが失敗しました';

  @override
  String commandExit(int code) {
    return '$code を終了します · このセッションのログを展開します';
  }

  @override
  String get command => 'コマンド';

  @override
  String get cancel => 'キャンセル';

  @override
  String get updateUnknown => '不明';

  @override
  String get updateChecking => 'チェック中';

  @override
  String get upToDate => '最新の状態';

  @override
  String get updateAvailable => '更新';

  @override
  String get updateUnavailable => '利用不可';

  @override
  String get updateCheckFailed => 'チェックに失敗しました';

  @override
  String get installSkill => 'スキルのインストール';

  @override
  String get installLocationTitle => '設置場所を設定する';

  @override
  String get userLevel => 'ユーザーレベル';

  @override
  String get projectLevel => 'プロジェクトレベル';

  @override
  String get projects => 'プロジェクト';

  @override
  String get loading => '読み込み中…';

  @override
  String get repositoryParsing => 'リポジトリを解析中…';

  @override
  String userInstallSummary(int agents) {
    return 'ユーザーレベルで $agents エージェントが利用可能';
  }

  @override
  String projectInstallSummary(int projects, int agents) {
    return '$projects プロジェクト · $agents エージェント';
  }

  @override
  String get installationResults => '導入実績';

  @override
  String get installationInProgress => 'インストール中です';

  @override
  String get installationSucceeded => 'インストール完了';

  @override
  String get installationSucceededMessage => 'スキルは選択した場所で利用できるようになりました。';

  @override
  String get projectUnavailable => 'プロジェクトが利用できません';

  @override
  String get installedCell => 'インストール済み';

  @override
  String get unsupportedCell => '利用不可';

  @override
  String get confirmInstall => 'インストールの確認';

  @override
  String installAllRepositorySkills(int count) {
    return 'すべてのリポジトリ スキル ($count) をインストールします';
  }

  @override
  String get installAllSkillsTo => 'すべてのスキルをインストールする';

  @override
  String installRepositorySkills(String repository, int count) {
    return 'すべての $repository スキル ($count) をインストールします';
  }

  @override
  String installSkillTo(String skill) {
    return '$skill をインストールする';
  }

  @override
  String get availableInAllProjects => 'すべてのプロジェクト';

  @override
  String get availableInSelectedProjects => '選択されたプロジェクト';

  @override
  String get usedBy => 'エージェント向け';

  @override
  String get backToTargets => 'ターゲットに戻る';

  @override
  String get stayHere => 'ここにいてください';

  @override
  String get viewInLibrary => 'ライブラリで見る';

  @override
  String planCreateCount(int count) {
    return '$count 作成';
  }

  @override
  String planSkipCount(int count) {
    return '$countスキップ';
  }

  @override
  String planReplaceCount(int count) {
    return '$count を置き換えます';
  }

  @override
  String planConflictCount(int count) {
    return '$count の競合';
  }

  @override
  String planRiskCount(int count) {
    return '$count のリスクがブロックされました';
  }

  @override
  String get refreshInstallationPlan => '解決策を適用する';

  @override
  String get replaceVersionConflict => 'このターゲットにインストールされているバージョンを置き換えます';

  @override
  String get replaceSkillIdCollision => 'このターゲットの別のスキル ID を置き換えます';

  @override
  String get replaceLocalModification => 'ローカルの変更を破棄し、このターゲットを置き換えます';

  @override
  String get sharedTargetConflict => 'このパスは他のエージェント ターゲットによって共有されます';

  @override
  String sharedTargetConflictDescription(String agents) {
    return 'ターゲット マトリックスに戻り、置換する前に影響を受けるすべてのエージェントを選択します: $agents';
  }

  @override
  String get replaceConflictingTarget => '競合するターゲットを置き換える';

  @override
  String get confirmHighRiskArtifact => '高リスクアーティファクトの確認';

  @override
  String get confirmCriticalRiskArtifact => 'クリティカルリスクの上書き確認';

  @override
  String get confirmRiskForSelectedTargets =>
      'アーティファクト ファイルを確認し、選択したターゲットについてはこのリスクを受け入れます';

  @override
  String get criticalRiskBlocked => '重大なリスクのあるインストールはブロックされます';

  @override
  String get criticalRiskOverrideDisabled =>
      'このプランを続行する前に、設定で明示的な重大リスクの上書きを有効にしてください。';

  @override
  String get workspaceManifestChanges => 'ワークスペースマニフェストの変更';

  @override
  String get noWorkspaceManifestChanges => 'ワークスペース マニフェスト ファイルは変更されません。';

  @override
  String lockVersionChange(String from, String to) {
    return '$from → $to';
  }

  @override
  String get notPresent => '存在しません';

  @override
  String get planActionCreate => '作成';

  @override
  String get planActionReplace => '交換する';

  @override
  String get planActionSkip => 'スキップ';

  @override
  String get planActionConflict => '紛争';

  @override
  String get planActionBlockedByRisk => 'リスクによりブロックされています';

  @override
  String installationResultSummary(int succeeded, int failed) {
    return '$succeeded ターゲットがインストールされましたが、$failed は失敗しました';
  }

  @override
  String get installationProgressTitle => 'インストール中です';

  @override
  String installationProgressSummary(int finished, int total) {
    return '$total 個中 $finished 個のターゲットが完了しました';
  }

  @override
  String get targetWaiting => '待っています';

  @override
  String get targetRunning => 'インストール中';

  @override
  String retryFailedTargets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '失敗したターゲット $count 件を再試行',
      one: '失敗したターゲット 1 件を再試行',
    );
    return '$_temp0';
  }

  @override
  String get updatePlanTitle => '更新するターゲットを選択してください';

  @override
  String get updatePlanDescription =>
      '正確なインストール ターゲットを選択します。選択されていないエージェントとプロジェクトは変更されません。';

  @override
  String updateTargetsSelected(int selected, int available) {
    return '$available 個の更新可能なターゲットのうち $selected 個が選択されました';
  }

  @override
  String updateVersionChange(String fromVersion, String toVersion) {
    return '$fromVersion → $toVersion';
  }

  @override
  String sourceReference(String reference) {
    return 'ソース参照: $reference';
  }

  @override
  String get fixedVersionTarget => '固定 - 移動可能な参照なし';

  @override
  String get currentVersionTarget => '最新の状態';

  @override
  String get updateCheckTargetFailed => '更新チェックに失敗しました';

  @override
  String get reconcileWorkspaceManifestTarget => 'ワークスペースマニフェストを修復する';

  @override
  String get updateSelectedTargets => '選択したターゲットを更新する';

  @override
  String get updateProgressTitle => 'ターゲットの更新';

  @override
  String get updateResultsTitle => '結果を更新する';

  @override
  String updateProgressSummary(int finished, int total) {
    return '$total 個中 $finished 個のターゲットが完了しました';
  }

  @override
  String retryFailedUpdates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '失敗した更新 $count 件を再試行',
      one: '失敗した更新 1 件を再試行',
    );
    return '$_temp0';
  }

  @override
  String get noUpdateableTargets => '選択したターゲットには利用可能なアップデートがありません。';

  @override
  String get closeUpdatePlan => '閉じる';

  @override
  String get targetSucceeded => 'インストール済み';

  @override
  String get targetSkipped => 'スキップされました';

  @override
  String get targetConflict => '紛争';

  @override
  String get targetFailed => '失敗しました';

  @override
  String get targetFailureRetryable => 'この場所は変更できませんでした。もう一度試すことができます。';

  @override
  String get targetFailureNeedsAttention => '再試行する前に、この場所に注意する必要があります。';

  @override
  String get installationTargetFailureMessage =>
      'この場所では何も変更されませんでした。フォルダーが使用可能であることを確認して、再試行してください。';

  @override
  String get workspacePersistenceFailureMessage =>
      'SkillsGo がプロジェクト設定を保存できなかったため、何も変更されませんでした。プロジェクト フォルダーが書き込み可能であることを確認して、再試行してください。';

  @override
  String get installationStateChangedMessage =>
      'この場所はレビュー中に変更されました。再試行する前に、最新の状態を確認してください。';

  @override
  String get updateTargetFailureMessage =>
      'この場所は更新できませんでした。他の場所は影響を受けなかったので、この場所のみを再試行できます。';

  @override
  String get managementTargetFailureMessage =>
      'このアクションはここでは完了できませんでした。他の場所は影響を受けなかったので、この場所のみを再試行できます。';

  @override
  String get technicalDetails => '技術的な詳細';

  @override
  String get targetPathExists => 'この場所には別のアイテムがすでに存在します。';

  @override
  String get targetBlockedByRisk => '現在の安全設定により、この場所へのインストールがブロックされました。';

  @override
  String get targetInstallFailed => 'スキルをこの場所にインストールできませんでした。';

  @override
  String get targetWorkspaceUpdateFailed =>
      'スキルはインストールされましたが、プロジェクト設定を更新できませんでした。';

  @override
  String get installationPlanFailed => 'インストール計画を続行できませんでした';

  @override
  String get installationFailed => 'インストールを完了できませんでした';

  @override
  String get localSource => '地元の情報源';

  @override
  String get noDescriptionAvailable => '説明がありません';

  @override
  String moreCoverage(int count) {
    return '+$count か所以上の場所';
  }

  @override
  String get batchTakeoverAction => '既存のスキルを管理する';

  @override
  String batchTakeoverActionCount(int count) {
    return '管理 ($count)';
  }

  @override
  String get batchTakeoverChecking => '既存のスキルを確認しています…';

  @override
  String get batchTakeoverRetry => '管理に追加できるスキルを再確認';

  @override
  String batchTakeoverEligibleCount(int count) {
    return '$countは管理可能です';
  }

  @override
  String get batchTakeoverPending => 'マネジメントにスキルを加える…';

  @override
  String get batchTakeoverTitle => 'SkillsGo で既存のスキルを管理しますか?';

  @override
  String get batchTakeoverDescription =>
      'SkillsGo は、スキル ファイルの移動、上書き、アップロードを行わずに、ローカル管理レコードを追加します。サポートされていない項目や変更された項目はスキップされます。';

  @override
  String get batchTakeoverStoryTitle => '分散したスキルを 1 つの明確なライブラリにまとめる';

  @override
  String batchTakeoverStoryDescription(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個の既存スキル',
      one: '1 個の既存スキル',
    );
    return 'SkillsGo は、この場所で管理できる $_temp0 を見つけました。';
  }

  @override
  String get batchTakeoverBeforeSemantics =>
      '管理する前は、既存のスキルがどこにインストールされているか、最新のものであるか、回復方法、プロジェクトが同じバージョンを使用しているかどうかが不明瞭です。';

  @override
  String get batchTakeoverPainLocation => '不明なインストール場所';

  @override
  String get batchTakeoverPainFreshness => '不明なアップデートステータス';

  @override
  String get batchTakeoverPainRecovery => '壊れたら回復しない';

  @override
  String get batchTakeoverPainVersionDrift => 'プロジェクト間で異なるバージョン';

  @override
  String get batchTakeoverFolderTitle => '既存のスキル';

  @override
  String get batchTakeoverFolderSubtitle => '不明なステータス';

  @override
  String get batchTakeoverAfterLabel => '後';

  @override
  String get batchTakeoverAfterTitle => 'クリアライブラリー 1 つ';

  @override
  String get batchTakeoverLibraryTitle => 'SkillsGo ライブラリ';

  @override
  String get batchTakeoverBenefitLocation => '場所をクリアする';

  @override
  String get batchTakeoverBenefitFreshness => '更新が表示されます';

  @override
  String get batchTakeoverBenefitRecovery => '簡単な回復';

  @override
  String get batchTakeoverBenefitVersions => 'バージョンクリア';

  @override
  String get batchTakeoverManagedSection => 'SkillsGo が管理';

  @override
  String get batchTakeoverPendingSection => '保留中';

  @override
  String batchTakeoverItemManaged(String name) {
    return '$name は SkillsGo によって管理されています';
  }

  @override
  String batchTakeoverItemSkipped(String name) {
    return '$name を管理に追加できませんでした';
  }

  @override
  String batchTakeoverItemPending(String name) {
    return '$name は管理を待っています';
  }

  @override
  String batchTakeoverAfterSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count のスキルは',
      one: '1 つのスキルは',
    );
    return '管理後、$_temp0 が 1 つのライブラリに整理され、管理ステータスが明確になります。';
  }

  @override
  String batchTakeoverMoreSkills(int count) {
    return '+$count以上';
  }

  @override
  String get batchTakeoverTransitionSemantics =>
      'これらの既存のスキルを SkillsGo 管理に追加します。';

  @override
  String get batchTakeoverTransitionLabel => '整理する';

  @override
  String get batchTakeoverStatusTitle => '管理状況';

  @override
  String get batchTakeoverStatusManaged => '管理された';

  @override
  String get batchTakeoverStatusProgress => '整理する';

  @override
  String get batchTakeoverStatusSkipped => 'スキップされました';

  @override
  String get batchTakeoverStatusFilesStay => 'スキルファイルは元の場所に残ります';

  @override
  String get batchTakeoverBoardSemantics =>
      'スキルは完全な行に配置され、ファイルを移動せずに SkillsGo によって記録されます。';

  @override
  String get batchTakeoverBoardComplete => 'オールクリア';

  @override
  String get batchTakeoverBoardPartial => '完了';

  @override
  String get batchTakeoverStatusTotal => '合計';

  @override
  String get batchTakeoverQueueComplete => '待っているスキルはありません';

  @override
  String get batchTakeoverQueueWaiting => 'スキルは検証後にここに移動します';

  @override
  String get batchTakeoverNextLabel => '次へ';

  @override
  String batchTakeoverFillerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count SkillsGo オーガナイザー ブロック',
      one: '1 SkillsGo オーガナイザー ブロック',
    );
    return '$_temp0 で最後の行を完成させます';
  }

  @override
  String get batchTakeoverPreservation =>
      'ファイル、パス、および現在のワークフローは、正確な場所に残ります。 SkillsGo はローカル管理記録のみを完了します。';

  @override
  String get batchTakeoverLaterHint =>
      'スキップした場合は、いつでも「ライブラリ」から「既存のスキルの管理」を使用できます。';

  @override
  String get batchTakeoverSkip => '今ではありません';

  @override
  String get batchTakeoverConfirm => '管理に追加';

  @override
  String get batchTakeoverExecutionRetry => '再試行';

  @override
  String get batchTakeoverResultTitle => 'マネジメントにスキルを追加';

  @override
  String batchTakeoverSummary(int takenOver, int skipped) {
    return '$takenOver スキルが管理に追加され、$skipped はスキップされました。';
  }

  @override
  String get batchTakeoverClose => '閉じる';

  @override
  String get installMoreTargets => 'より多くの場所にインストールする';

  @override
  String get exportLocalSkill => 'エクスポート';

  @override
  String get exportLocalSkillDescription =>
      'このローカル スキルをポータブルな ZIP アーカイブとしてエクスポートします。';

  @override
  String get detailRepository => 'リポジトリ';

  @override
  String get detailStars => 'スター';

  @override
  String get detailUpdated => '更新されました';

  @override
  String get detailArchiveSize => '郵便番号サイズ';

  @override
  String get pathLabel => 'プロジェクトパス';

  @override
  String get copyProjectPath => 'プロジェクトパスをコピーする';

  @override
  String get projectPathCopied => 'プロジェクトパスがコピーされました';

  @override
  String get onboardingWelcomeTitle => 'SkillsGo へようこそ';

  @override
  String get onboardingWelcomeDescription =>
      'エージェントとプロジェクト全体でスキルを検出、インストール、管理します。';

  @override
  String get onboardingDetectedAgents => '検出されたエージェント';

  @override
  String get onboardingNoAgents => 'インストールされているエージェントが検出されませんでした。引き続き続行できます。';

  @override
  String get onboardingNext => '次へ';

  @override
  String get onboardingProjectsTitle => 'プロジェクトを追加する';

  @override
  String get onboardingProjectsDescription => 'SkillsGo で管理するプロジェクトを選択します。';

  @override
  String get onboardingAddProject => '今すぐ追加';

  @override
  String get onboardingAddProjectLater => '以降';

  @override
  String get onboardingStartUsing => 'SkillsGo の使用を開始する';

  @override
  String get onboardingBack => '戻る';

  @override
  String get restartOnboardingTitle => 'オンボーディング';

  @override
  String get restartOnboardingDescription =>
      'プロジェクト、設定、またはスキル データを削除せずに、初回起動ガイドを再度表示します。';

  @override
  String get restartOnboardingAction => 'オンボーディングを再開する';

  @override
  String get restartOnboardingFailed => 'SkillsGo はオンボーディングを再開できませんでした。';

  @override
  String get libraryRefreshSettingsTitle => 'ローカルライブラリを更新する';

  @override
  String get libraryRefreshSettingsDescription =>
      'インストールされているスキル、追加されたプロジェクト、エージェント、および管理可能な外部スキルを再スキャンします。これにより、何もインストール、更新、削除されません。';

  @override
  String get libraryRefreshSettingsAction => 'ライブラリを更新する';

  @override
  String get libraryRefreshSettingsPending => 'リフレッシュライブラリ…';

  @override
  String get libraryRefreshSettingsSuccess => 'ローカルライブラリが更新されました。';

  @override
  String get libraryRefreshSettingsFailed => 'SkillsGo はローカル ライブラリを更新できませんでした。';

  @override
  String get onboardingProjectError =>
      'SkillsGo は、このディレクトリからプロジェクトを追加できませんでした。';

  @override
  String get onboardingProjectsLoadError =>
      'SkillsGo は追加されたプロジェクトを読み込むことができませんでした。';

  @override
  String get onboardingStartupError => 'SkillsGo はセットアップをロードできませんでした。';

  @override
  String get onboardingStateError =>
      'SkillsGo はセットアップの進行状況を保存できませんでした。もう一度やり直してください。';

  @override
  String get onboardingCliErrorTitle => 'SkillsGo CLI には注意が必要です';

  @override
  String get onboardingCliErrorDescription =>
      'バンドルされた CLI を修復してから、再試行して続行してください。';
}
