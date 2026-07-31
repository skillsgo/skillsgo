// ignore_for_file: text_direction_code_point_in_literal, text_direction_code_point_in_comment

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get discover => '발견하다';

  @override
  String get discoverSkills => '조금 더 알아가는 것이 좋습니다.';

  @override
  String get library => '도서관';

  @override
  String get settings => '설정';

  @override
  String get openSettings => '설정 열기';

  @override
  String get cliNeedsAttention => '필수 SkillsGo 구성요소에 주의가 필요합니다.';

  @override
  String get cliMissingBundled =>
      '필수 SkillsGo 구성 요소가 없거나 시작할 수 없습니다. 복원하려면 SkillsGo를 다시 설치하세요.';

  @override
  String get cliDamagedBundled =>
      '필수 SkillsGo 구성 요소가 손상되었습니다. 복원하려면 SkillsGo를 다시 설치하세요.';

  @override
  String get cliIncompatibleBundled =>
      '필수 SkillsGo 구성 요소가 이 앱 버전과 일치하지 않습니다. SkillsGo를 업데이트하거나 다시 설치하세요.';

  @override
  String get officialIndex => 'SkillsGo 허브';

  @override
  String get discoverTitle => '다음 행동에 필요한 기술을 찾아보세요.';

  @override
  String get skillsLeaderboard => '조금 더 알아가는 것이 좋습니다.';

  @override
  String searchResultsFor(String query) {
    return '“$query”에 대한 결과';
  }

  @override
  String get searchSkills => '스킬을 검색하거나 Git 링크를 붙여넣으세요…';

  @override
  String get search => '검색';

  @override
  String get ranking => '순위';

  @override
  String get trending => '인기 급상승';

  @override
  String get hot => '뜨거운';

  @override
  String get discoverNavigation => '탐색 탐색';

  @override
  String get allTimeRanking => '역대 순위';

  @override
  String get trendingNow => '지난 24시간 동안의 추세';

  @override
  String get hotNow => '지금 핫해요';

  @override
  String get allTimeDescription => '퍼블릭 스킬은 항상 승인된 설치 순으로 정렬됩니다.';

  @override
  String get trendingDescription =>
      '최근 24시간 동안 집계된 유효 설치 수를 기준으로 공개 스킬을 정렬합니다.';

  @override
  String get hotDescription => '단기 설치 증가 속도와 변화량을 기준으로 공개 스킬을 정렬합니다.';

  @override
  String get offlineTitle => 'SkillsGo에 연결할 수 없습니다';

  @override
  String get offlineMessage =>
      '인터넷 연결을 확인하고 다시 시도하세요. 프록시 또는 맞춤 서비스 주소를 사용하는 경우 설정에서 검토하세요.';

  @override
  String get searchFailedTitle => '검색이 중단되었습니다.';

  @override
  String get validationTitle => '입력한 내용을 확인하세요.';

  @override
  String get validationMessage =>
      'SkillsGo는 이 요청을 사용할 수 없습니다. 입력한 내용을 검토하고 다시 시도하세요.';

  @override
  String get serverTitle => '일시적으로 서비스를 이용할 수 없습니다';

  @override
  String get serverMessage =>
      'SkillsGo는 현재 이 요청을 완료할 수 없습니다. 잠시 후에 다시 시도해 보세요.';

  @override
  String get timeoutTitle => '너무 오래 걸리네요';

  @override
  String get timeoutMessage => '서비스가 제 시간에 응답하지 않았습니다. 연결을 확인하거나 다시 시도하세요.';

  @override
  String get invalidResponseTitle => 'SkillsGo에 업데이트가 필요합니다';

  @override
  String get invalidResponseMessage =>
      '현재 SkillsGo 버전에서는 이 응답을 읽을 수 없습니다. 앱을 업데이트한 후 다시 시도해 보세요.';

  @override
  String get invalidLocalDataTitle => '설치된 스킬을 읽을 수 없습니다';

  @override
  String get invalidLocalDataMessage =>
      '일부 로컬 설치 정보가 손상되었거나 호환되지 않습니다. SkillsGo를 업데이트하거나 다시 설치한 후 다시 시도하세요.';

  @override
  String get tryAgain => '다시 시도하세요';

  @override
  String get searchEmptyTitle => '검색하세요. 스크롤하지 마세요.';

  @override
  String get searchEmptyMessage => '공개 스킬을 검색하려면 기능, 소스 또는 태스크를 입력하세요.';

  @override
  String get noSkillsTitle => '기술을 찾을 수 없습니다.';

  @override
  String get noSkillsMessage => '더 폭넓은 문구를 사용하거나 철자를 확인하세요.';

  @override
  String get focusSearch => '집중검색';

  @override
  String get skillsFromLink => '이 링크의 스킬';

  @override
  String skillCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 스킬',
      one: '1 스킬',
    );
    return '$_temp0';
  }

  @override
  String sourceResultsSummary(String source, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$source의 스킬 $count개',
      one: '$source의 스킬 1개',
    );
    return '$_temp0';
  }

  @override
  String get sourceSearchEmptyTitle => '이 링크를 검사할 준비가 되었습니다.';

  @override
  String sourceSearchEmptyMessage(String source) {
    return '$source은(는) 현재 검색결과에 없습니다. SkillsGo는 다음 단계에서 링크를 직접 검사할 수 있습니다.';
  }

  @override
  String get inspectSource => '이 링크에서 스킬 보기';

  @override
  String get collectionEmptyTitle => '이 컬렉션에는 기술이 없습니다';

  @override
  String get collectionEmptyMessage =>
      '아직 아무것도 없습니다. 추가 설치 작업을 수행한 후 다시 시도하십시오.';

  @override
  String get loadMore => '더 로드하기';

  @override
  String get install => '설치';

  @override
  String get upgrade => '치받이';

  @override
  String get downgrade => '다운그레이드';

  @override
  String get packageSkillsSwitchTogether => '이 패키지의 스킬은 버전을 함께 전환합니다.';

  @override
  String get switchVersion => '버전 전환';

  @override
  String upgradeToVersion(String version) {
    return '$version(으)로 업그레이드';
  }

  @override
  String downgradeToVersion(String version) {
    return '$version(으)로 다운그레이드';
  }

  @override
  String get installAll => '모든 스킬을 설치하세요';

  @override
  String get latestCommit => '최신 커밋';

  @override
  String get installToMoreTargets => '더 많은 위치에 설치';

  @override
  String localTargets(int count) {
    return '$count 로컬 대상';
  }

  @override
  String allTimeMetric(String count) {
    return '$count 전체 설치 수';
  }

  @override
  String trendingMetric(String count) {
    return '$count 설치/24시간';
  }

  @override
  String hotMetric(String value, String change) {
    return '이번 시간에는 $value · $change';
  }

  @override
  String get trustUnverified => '확인되지 않음';

  @override
  String get trustCommunityVerified => '커뮤니티 인증됨';

  @override
  String get trustPublisherVerified => '게시자 확인됨';

  @override
  String get trustOfficial => '공식';

  @override
  String get trustWarned => '경고함';

  @override
  String get trustDelisted => '상장폐지';

  @override
  String get riskUnknown => '알 수 없는 위험';

  @override
  String get riskLow => '낮은 위험';

  @override
  String get riskMedium => '중간 위험';

  @override
  String get riskHigh => '고위험';

  @override
  String get riskCritical => '심각한 위험';

  @override
  String openSkill(String name) {
    return '$name 열기';
  }

  @override
  String installs(String count) {
    return '$count 설치';
  }

  @override
  String get detailFailedTitle => '이 스킬을 로드할 수 없습니다.';

  @override
  String get detailLoading => '감사 가능한 기술 세부정보 로드 중';

  @override
  String get artifactUnavailableTitle => '유물을 사용할 수 없습니다';

  @override
  String get artifactUnavailableMessage =>
      '이 버전은 현재 사용할 수 없습니다. 다시 시도하거나 다른 버전을 선택하세요.';

  @override
  String get detailInvalidTitle => '아티팩트 메타데이터가 지원되지 않습니다.';

  @override
  String get detailInvalidMessage =>
      '이 기술에 대한 일부 세부 정보가 불완전하거나 읽을 수 없습니다. SkillsGo를 업데이트한 후 다시 시도하세요.';

  @override
  String get instructionsTab => '지침';

  @override
  String get manifestTab => '매니페스트';

  @override
  String immutableVersionLabel(String version) {
    return '불변 $version';
  }

  @override
  String commitIdentity(String sha) {
    return '$sha 커밋';
  }

  @override
  String treeIdentity(String sha) {
    return '나무 $sha';
  }

  @override
  String contentIdentity(String digest) {
    return '콘텐츠 $digest';
  }

  @override
  String get trustDoesNotProveSafety =>
      '게시자 신뢰는 소유권 또는 유지 관리를 확인합니다. 아티팩트 안전성을 인증하지는 않습니다. 이 변경 불가능한 버전에 대해서는 위험이 별도로 평가됩니다.';

  @override
  String get knownInstallationTargets => '알려진 설치 대상';

  @override
  String get installationRange => '설치된 범위';

  @override
  String get targetDetails => '대상 세부정보 표시';

  @override
  String get hideTargetDetails => '대상 세부정보 숨기기';

  @override
  String installedVersionLabel(String version) {
    return '버전 $version';
  }

  @override
  String targetSummary(String scope, String agent, String version) {
    return '$scope / $agent · $version';
  }

  @override
  String get projectScope => '프로젝트';

  @override
  String get fileContentUnavailable => '바이너리 또는 사용할 수 없는 미리보기';

  @override
  String get fileContentTruncated => '허브 안전 한도에 따라 미리보기가 잘렸습니다.';

  @override
  String get retry => '재시도';

  @override
  String get backToSearch => '검색으로 돌아가기';

  @override
  String get installForCodex => 'Codex용으로 설치';

  @override
  String get cliNotDetected => '기술(감지되지 않음)';

  @override
  String get snapshotFiles => '스냅샷 파일';

  @override
  String get globalCodex => '글로벌 · 코덱스';

  @override
  String get yourLibrary => '당신이 아는 모든 것이 여기에 있습니다.';

  @override
  String get libraryNavigation => '도서관 탐색';

  @override
  String get all => '모두';

  @override
  String get allSkills => '모든 기술';

  @override
  String get updatesOnly => '업데이트';

  @override
  String get allAgents => '모든 에이전트';

  @override
  String get allProjects => '모든 프로젝트';

  @override
  String get specificProject => '프로젝트';

  @override
  String get libraryGlobalScope => '글로벌 스킬';

  @override
  String get libraryExternalScope => 'External Skills';

  @override
  String get libraryEmptyAddProject => 'Go to Add Project';

  @override
  String get globalScope => '글로벌';

  @override
  String get globalSkills => '글로벌 스킬';

  @override
  String get addProject => '프로젝트 추가';

  @override
  String get removeFromList => '목록에서 제거';

  @override
  String removeProjectTitle(String name) {
    return 'SkillsGo에서 $name을(를) 제거하시겠습니까?';
  }

  @override
  String get removeProjectDescription =>
      '앱 참조만 제거됩니다. SkillsGo는 이 디렉터리의 어떤 파일도 변경하거나 삭제하지 않습니다.';

  @override
  String projectRailUnavailable(String name) {
    return '$name — 사용할 수 없음';
  }

  @override
  String get emptyProjectTitle => '아직 기술이 없습니다';

  @override
  String get browseSkills => '기술 찾아보기';

  @override
  String get projectMissingTitle => '프로젝트 디렉터리가 누락되었습니다.';

  @override
  String get projectMissingMessage =>
      '디렉터리가 이동되었거나 해당 볼륨이 오프라인 상태일 수 있습니다. 경로를 확인하거나 해당 앱 참조를 제거하세요.';

  @override
  String get projectPermissionTitle => '프로젝트 권한이 필요합니다';

  @override
  String get projectPermissionMessage =>
      'SkillsGo에서는 이 프로젝트 루트를 검사할 수 없습니다. 파일 시스템 권한을 확인하거나 앱 참조를 제거하세요.';

  @override
  String get projectInaccessibleTitle => '프로젝트 디렉터리에 액세스할 수 없습니다.';

  @override
  String get projectInaccessibleMessage =>
      'SkillsGo이 이 프로젝트 참조를 보관했습니다. 경로나 볼륨을 확인하거나 해당 앱 참조를 제거하세요.';

  @override
  String get checking => '확인 중…';

  @override
  String get checkUpdates => '업데이트 확인';

  @override
  String get refresh => '새로고침';

  @override
  String get libraryUnavailable => '도서관을 이용할 수 없습니다';

  @override
  String get libraryEmpty => '아직 설치된 스킬이 없습니다.';

  @override
  String get libraryEmptyMessage => 'Discover에서 스킬을 설치하면 여기에 표시됩니다.';

  @override
  String get searchLibrary => '설치된 스킬 검색';

  @override
  String get libraryNoMatches => '일치하는 기술이 없습니다.';

  @override
  String get libraryNoMatchesMessage => '다른 이름, 소스, 에이전트, 프로젝트 또는 버전을 사용해 보세요.';

  @override
  String agentsSummary(int count) {
    return '$count 에이전트';
  }

  @override
  String projectsSummary(int count) {
    return '$count 프로젝트';
  }

  @override
  String versionsSummary(int count) {
    return '$count 버전';
  }

  @override
  String get hubManaged => '허브 관리';

  @override
  String get localManaged => '로컬 관리';

  @override
  String get externalInstallation => '외부 설치';

  @override
  String get readOnly => '읽기 전용';

  @override
  String get unversioned => '버전이 지정되지 않음';

  @override
  String get supportingFiles => '지원 파일';

  @override
  String get versionDivergence => '버전 차이';

  @override
  String get healthHealthy => '건강한';

  @override
  String get healthMissing => '타겟 누락';

  @override
  String get healthReplaced => '대상이 교체됨';

  @override
  String get healthLocalModification => '로컬 수정';

  @override
  String get healthUnreadable => '대상을 읽을 수 없음';

  @override
  String get healthUndeclared => '선언되지 않음';

  @override
  String get healthWorkspaceUnreadable => '작업공간 상태를 읽을 수 없음';

  @override
  String get healthLockMismatch => '잠금 불일치';

  @override
  String get healthUnexpectedPath => '예상치 못한 대상 경로';

  @override
  String get modeExternal => '외부';

  @override
  String get notLinked => '연결되지 않음';

  @override
  String get update => '업데이트';

  @override
  String get backToLibrary => '도서관으로 돌아가기';

  @override
  String get remove => '제거';

  @override
  String skillsSelected(int count) {
    return '$count 선택됨';
  }

  @override
  String get clearSelection => '선택 취소';

  @override
  String get selectCurrentResults => '현재 결과 선택';

  @override
  String get clearCurrentResultSelection => '현재 결과 선택 지우기';

  @override
  String targetActionsSelected(int selected, int total) {
    return '$total개 타겟 중 $selected개 선택됨';
  }

  @override
  String get confirmRemoveTarget => '제거 확인';

  @override
  String get managementProgressTitle => '타겟 액션 적용';

  @override
  String get managementResultsTitle => '목표 조치 결과';

  @override
  String managementResultSummary(int succeeded, int failed) {
    return '$succeeded 성공, $failed 실패';
  }

  @override
  String get targetContentPreserved => '현재 대상 콘텐츠는 보존됩니다.';

  @override
  String get localReadFailed => '이 스킬을 읽을 수 없습니다';

  @override
  String get localReadFailedMessage =>
      'SkillsGo가 설치된 이 스킬을 읽을 수 없습니다. 해당 폴더가 사용 가능하고 액세스 가능한지 확인한 후 다시 시도하세요.';

  @override
  String get localConfiguration => '기술이동 설정';

  @override
  String get settingsNavigation => '설정 탐색';

  @override
  String get general => '개인화';

  @override
  String get agents => '에이전트';

  @override
  String get hub => '허브';

  @override
  String get installationPolicy => '설치 정책';

  @override
  String get storage => '저장';

  @override
  String get colorScheme => '색 구성표';

  @override
  String get about => '소개';

  @override
  String get colorSchemeInspectorTitle => '생성된 머티리얼 색상 역할';

  @override
  String get skillsColorTokensTitle => 'SkillsGo 의미 색상';

  @override
  String get skillsColorTokensDescription =>
      'Radix Sand로 구축된 제품 색상은 Primer 의미 체계로 구성되었으며 폴더는 전용 공간 계층 구조입니다.';

  @override
  String get colorSchemeInspectorDescription =>
      '현재 시드에서 생성된 더 이상 사용되지 않는 모든 ColorScheme 토큰을 미리 봅니다. 색상을 클릭하면 HEX 값이 복사됩니다.';

  @override
  String get colorSchemePairPreview => '의미 쌍';

  @override
  String get colorSchemePairPreviewDescription =>
      '대비와 계층 구조를 노출하기 위해 함께 렌더링되는 전경 및 배경 역할입니다.';

  @override
  String get colorSchemeComponentPreview => '구성요소 미리보기';

  @override
  String get colorSchemeComponentPreviewDescription =>
      '이 정확한 미리보기 구성표로 렌더링된 대표적인 머티리얼 컨트롤입니다.';

  @override
  String get colorSchemeSampleTitle => '스킬 카드 제목';

  @override
  String get colorSchemeSampleBody => '보조 복사본은 onSurfaceVariant를 사용합니다.';

  @override
  String get colorSchemeCopied => '복사됨';

  @override
  String get colorSchemeSampleGlyphs => '아아 123';

  @override
  String get colorSchemeGroupPrimary => '기본';

  @override
  String get colorSchemeGroupPrimaryDescription => '기본 강조, 컨테이너 및 고정 악센트 역할.';

  @override
  String get colorSchemeGroupSecondary => '보조';

  @override
  String get colorSchemeGroupSecondaryDescription => '강조 및 고정된 보조 역할을 지원합니다.';

  @override
  String get colorSchemeGroupTertiary => '3차';

  @override
  String get colorSchemeGroupTertiaryDescription => '대조되는 악센트와 고정된 3차 역할.';

  @override
  String get colorSchemeGroupSurface => '표면';

  @override
  String get colorSchemeGroupSurfaceDescription => '페이지, 컨테이너, 고도 및 전경 계층 구조.';

  @override
  String get colorSchemeGroupUtility => '개요 및 유틸리티';

  @override
  String get colorSchemeGroupUtilityDescription => '경계, 그림자, 스크림 및 반전 표면.';

  @override
  String get colorSchemeGroupError => '오류';

  @override
  String get colorSchemeGroupErrorDescription => '오류 작업, 메시지 및 컨테이너.';

  @override
  String get colorSchemeUsagePrimary => '기본 동작, 초점 및 강조된 악센트입니다.';

  @override
  String get colorSchemeUsageSecondary => '지원 작업 및 중간 강조 악센트.';

  @override
  String get colorSchemeUsageTertiary => '기본 및 보조를 보완하는 대조 액센트.';

  @override
  String colorSchemeUsageContentOn(String token) {
    return '$token에 표시된 텍스트 및 아이콘.';
  }

  @override
  String colorSchemeUsageContainer(String family) {
    return '선택 및 악센트에 대한 낮은 강조 $family 컨테이너입니다.';
  }

  @override
  String colorSchemeUsageFixed(String family) {
    return '밝기에 독립적인 고정 $family 컨테이너.';
  }

  @override
  String colorSchemeUsageFixedDim(String family) {
    return '어두워진 밝기와 무관한 고정 $family 컨테이너.';
  }

  @override
  String colorSchemeUsageFixedContent(String family) {
    return '고정된 $family 컨테이너의 높은 강조 콘텐츠입니다.';
  }

  @override
  String colorSchemeUsageFixedVariantContent(String family) {
    return '고정된 $family 컨테이너의 낮은 강조 콘텐츠입니다.';
  }

  @override
  String get colorSchemeUsageSurface => '기본 페이지 및 넓은 영역 표면.';

  @override
  String get colorSchemeUsageSurfaceDim => '가장 어두운 표면 톤에 사용되는 희미한 기본 표면.';

  @override
  String get colorSchemeUsageSurfaceBright => '가장 밝은 표면 톤에 사용되는 밝은 베이스 표면입니다.';

  @override
  String colorSchemeUsageSurfaceElevation(String level) {
    return '$level 표면 컨테이너 표고입니다.';
  }

  @override
  String get colorSchemeElevationLowest => '가장 낮은';

  @override
  String get colorSchemeElevationLow => '낮음';

  @override
  String get colorSchemeElevationDefault => '기본값';

  @override
  String get colorSchemeElevationHigh => '높다';

  @override
  String get colorSchemeElevationHighest => '최고';

  @override
  String get colorSchemeUsageOnSurface => '표면에 표시되는 기본 텍스트 및 아이콘.';

  @override
  String get colorSchemeUsageOnSurfaceVariant => '표면의 보조 텍스트, 라벨 및 부드러운 아이콘.';

  @override
  String get colorSchemeUsageSurfaceTint => '기본에서 파생된 머티리얼 고도 색조입니다.';

  @override
  String get colorSchemeUsageOutline => '눈에 띄는 경계와 집중된 구성 요소 개요.';

  @override
  String get colorSchemeUsageOutlineVariant => '미묘한 경계, 구분 기호 및 낮은 강조 윤곽선.';

  @override
  String get colorSchemeUsageShadow => '높은 표면에 대한 그림자 색상입니다.';

  @override
  String get colorSchemeUsageScrim => '배경 콘텐츠의 강조를 줄이는 데 사용되는 모달 오버레이입니다.';

  @override
  String get colorSchemeUsageInverseSurface => '밝은 부분과 어두운 부분이 반전된 표면입니다.';

  @override
  String get colorSchemeUsageInversePrimary => '반대 표면에 기본 악센트가 표시됩니다.';

  @override
  String get colorSchemeUsageError => '오류 작업, 상태 및 강조된 피드백.';

  @override
  String get save => '저장';

  @override
  String get advancedSettings => '고급';

  @override
  String get remindersSettings => '알림';

  @override
  String get remindersSettingsTitle => '알림 설정';

  @override
  String get remindersSettingsDescription => '어떤 알림을 받을지 선택하세요.';

  @override
  String get updateReminderTitle => '알림 업데이트';

  @override
  String get updateReminderDescription => '라이브러리가 열리면 업데이트를 확인하세요.';

  @override
  String get securityReminderTitle => '고위험 경고';

  @override
  String get securityReminderDescription =>
      '설치된 기술에 새로운 높음 또는 심각 위험이 있음을 알려줍니다.';

  @override
  String availableUpdatesReminder(int count) {
    return '$count 설치된 스킬이 업데이트되었습니다.';
  }

  @override
  String get openAvailableUpdates => '사용 가능한 업데이트 보기를 열어 검토하고 업데이트하세요.';

  @override
  String securityAdvisoriesReminder(int count) {
    return '$count 설치된 기술에는 보안 검토가 필요합니다.';
  }

  @override
  String get reviewInstalledSkills => '사용하거나 업데이트하기 전에 위험 정보를 검토하십시오.';

  @override
  String get generalSettingsTitle => '기술을 당신의 것으로 만드세요';

  @override
  String get generalSettingsDescription =>
      '인터페이스는 시스템 언어, 접근성 및 동작 기본 설정을 따릅니다.';

  @override
  String get agentsSettingsTitle => '에이전트 런타임';

  @override
  String get hubSettingsTitle => '허브 원산지';

  @override
  String get hubSettingsDescription =>
      '동일한 SkillsGo 프로토콜을 구현하는 공식 허브 또는 HTTP(S) 자체 호스팅 원본을 사용하세요.';

  @override
  String get testConnection => '테스트 연결';

  @override
  String get saveOrigin => '원산지 저장';

  @override
  String get resetDefault => '기본값으로 재설정';

  @override
  String get connectionReady => '연결 준비됨';

  @override
  String get connectionFailed => '연결 실패';

  @override
  String get hubInvalidOrigin =>
      '사용자 인증 정보, 쿼리 또는 조각 없이 유효한 HTTP(S) 원본을 입력하세요.';

  @override
  String hubHttpFailure(int status) {
    return '허브가 HTTP $status를 반환했습니다. 원본 및 서버 구성을 확인하세요.';
  }

  @override
  String get hubInvalidProtocol => '서버가 SkillsGo Hub 검색 프로토콜을 반환하지 않았습니다.';

  @override
  String get hubInvalidJson => '허브가 잘못된 JSON을 반환했습니다.';

  @override
  String get hubConnectionFailure =>
      '허브에 연결할 수 없습니다. 원본, 네트워크, 프록시, TLS 구성을 확인하세요.';

  @override
  String get hubConnectionTimeout => '허브 연결 시간이 초과되었습니다. 네트워크를 확인하거나 다시 시도하세요.';

  @override
  String cloudHttpFailure(int status) {
    return '클라우드는 HTTP $status을(를) 반환했습니다. 오리진 및 서비스 구성을 확인하세요.';
  }

  @override
  String get cloudInvalidProtocol => '서버가 SkillsGo 클라우드 순위 프로토콜을 반환하지 않았습니다.';

  @override
  String get cloudInvalidJson => '클라우드가 잘못된 JSON을(를) 반환했습니다.';

  @override
  String get cloudConnectionFailure =>
      '클라우드에 연결할 수 없습니다. 원본, 네트워크, 프록시 및 TLS 구성을 확인하세요.';

  @override
  String get cloudConnectionTimeout =>
      '클라우드 연결 시간이 초과되었습니다. 네트워크를 확인하거나 다시 시도하세요.';

  @override
  String get riskPolicyTitle => '개인 위험 정책';

  @override
  String get riskPolicyDescription => '스킬을 설치하거나 업데이트할 때 안전 규칙이 적용됩니다.';

  @override
  String get confirmHighRisk => '고위험에 대한 확인 필요';

  @override
  String get confirmHighRiskDescription => '고위험 아티팩트는 설치 전 항상 추가 확인이 필요합니다.';

  @override
  String get allowCriticalOverride => '명시적인 위험 위험 재정의 허용';

  @override
  String get allowCriticalOverrideDescription =>
      '심각한 위험 아티팩트는 기본적으로 차단된 상태로 유지됩니다. 별도의 수동 재정의를 노출하려는 경우에만 이 옵션을 활성화하세요.';

  @override
  String get storageHealthy => '읽을 수 있음';

  @override
  String get storageNotInitialized => '초기화되지 않음';

  @override
  String get storageUnavailable => '이용 불가';

  @override
  String get storageInvalidResponse => '번들 CLI가 지원되지 않는 진단 응답을 반환했습니다.';

  @override
  String get aboutSettingsTitle => '제품 호환성';

  @override
  String get appVersion => '앱 버전';

  @override
  String get cliVersion => '번들 CLI 버전';

  @override
  String get compatible => '호환 가능';

  @override
  String get hubOriginSaved => 'Hub Origin이 저장되고 적용되었습니다.';

  @override
  String get policySaved => '설치 정책이 저장되었습니다.';

  @override
  String get officialCli => 'SkillsGo CLI';

  @override
  String get ready => '준비';

  @override
  String get unknown => '알 수 없음';

  @override
  String get missing => '누락';

  @override
  String get incompatible => '호환되지 않음';

  @override
  String get detecting => '감지 중…';

  @override
  String get customCliPath => '사용자 정의 실행 파일 경로';

  @override
  String get saveAndDetect => '저장 및 감지';

  @override
  String get detectAgain => '다시 감지';

  @override
  String get agentInstalled => '설치됨';

  @override
  String get agentSupported => '지원됨';

  @override
  String agentCatalogSummary(int installed, int supported) {
    return '$installed 설치됨 · $supported 지원됨';
  }

  @override
  String installedAgentsTitle(int count) {
    return '설치됨 · $count';
  }

  @override
  String notInstalledAgentsTitle(int count) {
    return '설치되지 않음 · $count';
  }

  @override
  String get notInstalledAgentsDescription =>
      'SkillsGo에서 지원되지만 이 Mac에서는 감지되지 않습니다.';

  @override
  String agentDiscoveryRoots(String paths) {
    return '스킬 로딩 경로: $paths';
  }

  @override
  String get agentInspectionFailed => '에이전트 감지 데이터를 사용할 수 없습니다. 감지를 다시 실행하십시오.';

  @override
  String get noInstalledAgentsTitle => '설치된 에이전트가 감지되지 않았습니다.';

  @override
  String get noInstalledAgentsMessage =>
      '이 스킬을 계속 탐색할 수 있지만 아직 설치 대상이 없습니다. 지원되는 에이전트를 설치한 후 검색을 다시 실행하세요.';

  @override
  String get clearCustomPath => '맞춤 경로 지우기';

  @override
  String get privacyProvenance => '개인정보 보호 및 출처';

  @override
  String get privacySummary =>
      '검색 텍스트와 스킬 콘텐츠는 기록되지 않습니다. 삭제된 로컬 진단은 최대 7일 동안 보관되며 자동으로 업로드되지 않습니다.';

  @override
  String get diagnosticLogsTitle => '진단 로그';

  @override
  String diagnosticLogsDescription(String size) {
    return '로컬 앱 및 CLI 진단은 $size을 사용합니다. 로그는 자동으로 순환되고 최대 7일 동안 보관되며 자동으로 업로드되지 않습니다.';
  }

  @override
  String get openLogFolder => '폴더 열기';

  @override
  String get viewLiveLogs => '실시간 보기';

  @override
  String get exportLogs => '로그 내보내기';

  @override
  String get clearLogs => '로그 지우기';

  @override
  String get logsExported => '진단 로그를 내보냈습니다.';

  @override
  String get logsCleared => '진단 로그가 지워졌습니다.';

  @override
  String get logActionFailed => '진단 로그 작업을 완료할 수 없습니다.';

  @override
  String get logViewerLive => '살다';

  @override
  String get logViewerPaused => '일시중지됨';

  @override
  String get searchLogs => '로그 검색';

  @override
  String get allLogLevels => '모두';

  @override
  String get warningLogs => '경고';

  @override
  String get errorLogs => '오류';

  @override
  String get pauseLogFollow => '정지시키다';

  @override
  String get resumeLogFollow => '재개하다';

  @override
  String get clearViewer => '선명한 시야';

  @override
  String get noDiagnosticLogs => '아직 일치하는 로그가 없습니다.';

  @override
  String get backToLatestLog => '최신';

  @override
  String get language => '언어';

  @override
  String get originalContent => '원래의';

  @override
  String get translatedContent => '번역됨';

  @override
  String translatedFrom(String language) {
    return '$language에서 번역됨';
  }

  @override
  String sourceLanguageName(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'en': '영어',
      'zhHans': '중국어(간체)',
      'zhHant': '중국어(번체)',
      'ja': '일본어',
      'ko': '한국어',
      'fr': '프랑스어',
      'de': '독일어',
      'it': '이탈리아어',
      'es': '스페인어',
      'pt': '포르투갈어',
      'ru': '러시아어',
      'ar': '아랍어',
      'hi': '힌디어',
      'id': '인도네시아어',
      'tr': '튀르키예어',
      'nl': '네덜란드어',
      'pl': '폴란드어',
      'th': '태국어',
      'vi': '베트남어',
      'ms': '말레이어',
      'sv': '스웨덴어',
      'uk': '우크라이나어',
      'other': '$code',
    });
    return '$_temp0';
  }

  @override
  String get showOriginalContent => '원문 보기';

  @override
  String get showTranslation => '번역 보기';

  @override
  String get personalizationTheme => '테마';

  @override
  String get folderColorTheme => '테마 색상';

  @override
  String get folderColorThemeDescription =>
      '좋아하는 색상을 선택하세요. SkillsGo는 이를 중심으로 조정된 인터페이스 팔레트를 구축합니다.';

  @override
  String get brandNameNeteaseCloudMusic => 'NetEase 클라우드 음악';

  @override
  String get brandNameRaspberryPi => '라즈베리 파이';

  @override
  String get brandNameChinaEasternAirlines => '중국동방항공';

  @override
  String get brandNameNvidia => '엔비디아';

  @override
  String get brandNameTaobao => '타오바오';

  @override
  String get brandNameBitcoin => '비트코인';

  @override
  String get appearanceMode => '모드';

  @override
  String get appearanceModeDescription => '시스템 모양을 따르거나 항상 밝거나 어두운 테마를 사용하십시오.';

  @override
  String get followSystem => '시스템';

  @override
  String get lightMode => '빛';

  @override
  String get darkMode => '어둠';

  @override
  String get wallpaper => '바탕화면';

  @override
  String get wallpaperDescription => '천체 배경을 선택하세요. 선택 항목은 폴더 바로 뒤에 나타납니다.';

  @override
  String get wallpaperSun => '태양';

  @override
  String get wallpaperMercury => '수성';

  @override
  String get wallpaperVenus => '비너스';

  @override
  String get wallpaperEarth => '지구';

  @override
  String get wallpaperMars => '화성';

  @override
  String get wallpaperJupiter => '목성';

  @override
  String get wallpaperSaturn => '토성';

  @override
  String get wallpaperUranus => '천왕성';

  @override
  String get wallpaperNeptune => '해왕성';

  @override
  String get wallpaperPluto => '명왕성';

  @override
  String get wallpaperMoon => '달';

  @override
  String folderThemeChoice(String theme) {
    return '$theme 폴더 테마';
  }

  @override
  String get privacyAffiliation =>
      '익명 설치 원격 측정은 SkillsGo 설정에 의해 제어됩니다. SkillsGo는 OpenAI 또는 Codex와 제휴하지 않습니다.';

  @override
  String get commandCompleted => '명령 완료';

  @override
  String get commandFailed => '명령이 실패했습니다.';

  @override
  String commandExit(int code) {
    return '$code 종료 · 이 세션의 로그를 보려면 확장하세요.';
  }

  @override
  String get command => '명령';

  @override
  String get cancel => '취소';

  @override
  String get updateUnknown => '알 수 없음';

  @override
  String get updateChecking => '확인 중';

  @override
  String get upToDate => '최신';

  @override
  String get updateAvailable => '업데이트';

  @override
  String get updateUnavailable => '이용할 수 없음';

  @override
  String get updateCheckFailed => '확인 실패';

  @override
  String get installSkill => '스킬 설치';

  @override
  String get installLocationTitle => '설치 위치 설정';

  @override
  String get globalLevel => 'Global';

  @override
  String get projectLevel => '프로젝트 수준';

  @override
  String get projects => '프로젝트';

  @override
  String get loading => '로드 중…';

  @override
  String get repositoryParsing => '파싱 저장소…';

  @override
  String globalInstallSummary(int agents) {
    return 'Available globally to $agents Agents';
  }

  @override
  String projectInstallSummary(int projects, int agents) {
    return '$projects 프로젝트 · $agents 에이전트';
  }

  @override
  String get installationResults => '설치 결과';

  @override
  String get installationInProgress => '설치 진행 중';

  @override
  String get installationSucceeded => '설치 완료';

  @override
  String get installationSucceededMessage => '이제 선택한 위치에서 스킬을 사용할 수 있습니다.';

  @override
  String get projectUnavailable => '프로젝트를 사용할 수 없음';

  @override
  String get installedCell => '설치됨';

  @override
  String get unsupportedCell => '이용 불가';

  @override
  String get confirmInstall => '설치 확인';

  @override
  String installAllPackageSkills(int count) {
    return '모든 저장소 기술 설치($count)';
  }

  @override
  String get installAllSkillsTo => '모든 스킬을 설치하세요.';

  @override
  String installPackageSkills(String packagePath, int count) {
    return '모든 $packagePath 스킬 설치 ($count)';
  }

  @override
  String installSkillTo(String skill) {
    return '다음에 $skill를 설치합니다.';
  }

  @override
  String get availableInAllProjects => '모든 프로젝트';

  @override
  String get availableInSelectedProjects => '선정된 프로젝트';

  @override
  String get usedBy => '에이전트의 경우';

  @override
  String get backToTargets => '대상으로 돌아가기';

  @override
  String get stayHere => '여기에 머물러 라.';

  @override
  String get viewInLibrary => '라이브러리에서 보기';

  @override
  String planCreateCount(int count) {
    return '$count 생성';
  }

  @override
  String planSkipCount(int count) {
    return '$count 건너뛰기';
  }

  @override
  String planReplaceCount(int count) {
    return '$count 교체';
  }

  @override
  String planConflictCount(int count) {
    return '$count 충돌';
  }

  @override
  String planRiskCount(int count) {
    return '$count 위험이 차단되었습니다.';
  }

  @override
  String get refreshInstallationPlan => '결의안 적용';

  @override
  String get replaceVersionConflict => '이 대상에 설치된 버전을 교체하세요.';

  @override
  String get replaceSkillIdCollision => '이 대상에서 다른 스킬 ID를 교체하세요.';

  @override
  String get replaceLocalModification => '로컬 수정 사항을 삭제하고 이 대상을 교체합니다.';

  @override
  String get sharedTargetConflict => '이 경로는 다른 Agent 대상과 공유됩니다.';

  @override
  String sharedTargetConflictDescription(String agents) {
    return '교체하기 전에 대상 매트릭스로 돌아가서 영향을 받는 모든 에이전트를 선택하세요: $agents';
  }

  @override
  String get replaceConflictingTarget => '충돌하는 대상 교체';

  @override
  String get confirmHighRiskArtifact => '고위험 유물 확인';

  @override
  String get confirmCriticalRiskArtifact => '심각한 위험 재정의 확인';

  @override
  String get confirmRiskForSelectedTargets =>
      '아티팩트 파일을 검토하고 선택한 대상에 대해 이 위험을 수락했습니다.';

  @override
  String get criticalRiskBlocked => '심각한 위험이 있는 설치가 차단되었습니다.';

  @override
  String get criticalRiskOverrideDisabled =>
      '이 계획을 계속하려면 설정에서 명시적인 위험-위험 재정의를 활성화하세요.';

  @override
  String get workspaceManifestChanges => '작업공간 매니페스트 변경';

  @override
  String get noWorkspaceManifestChanges => '작업공간 매니페스트 파일은 변경되지 않습니다.';

  @override
  String lockVersionChange(String from, String to) {
    return '$from → $to';
  }

  @override
  String get notPresent => '존재하지 않음';

  @override
  String get planActionCreate => '만들기';

  @override
  String get planActionReplace => '바꾸기';

  @override
  String get planActionSkip => '건너뛰기';

  @override
  String get planActionConflict => '갈등';

  @override
  String get planActionBlockedByRisk => '위험으로 인해 차단됨';

  @override
  String installationResultSummary(int succeeded, int failed) {
    return '$succeeded 대상이 설치되었지만 $failed이(가) 실패했습니다.';
  }

  @override
  String get installationProgressTitle => '설치 진행 중';

  @override
  String installationProgressSummary(int finished, int total) {
    return '$total개 목표 중 $finished개 완료됨';
  }

  @override
  String get targetWaiting => '대기 중';

  @override
  String get targetRunning => '설치 중';

  @override
  String retryFailedTargets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '실패한 대상 $count개 다시 시도',
      one: '실패한 대상 1개 다시 시도',
    );
    return '$_temp0';
  }

  @override
  String get updatePlanTitle => '업데이트할 대상 선택';

  @override
  String get updatePlanDescription =>
      '정확한 설치 대상을 선택하세요. 선택하지 않은 에이전트 및 프로젝트는 변경되지 않은 상태로 유지됩니다.';

  @override
  String updateTargetsSelected(int selected, int available) {
    return '업데이트 가능한 대상 $available개 중 $selected개가 선택됨';
  }

  @override
  String updateVersionChange(String fromVersion, String toVersion) {
    return '$fromVersion → $toVersion';
  }

  @override
  String sourceReference(String reference) {
    return '소스 참조: $reference';
  }

  @override
  String get fixedVersionTarget => '고정됨 - 이동 가능한 참조 없음';

  @override
  String get currentVersionTarget => '최신';

  @override
  String get updateCheckTargetFailed => '업데이트 확인 실패';

  @override
  String get reconcileWorkspaceManifestTarget => '작업공간 매니페스트 복구';

  @override
  String get updateSelectedTargets => '선택한 대상 업데이트';

  @override
  String get updateProgressTitle => '대상 업데이트 중';

  @override
  String get updateResultsTitle => '결과 업데이트';

  @override
  String updateProgressSummary(int finished, int total) {
    return '$total개 목표 중 $finished개 완료됨';
  }

  @override
  String retryFailedUpdates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '실패한 업데이트 $count개 다시 시도',
      one: '실패한 업데이트 1개 다시 시도',
    );
    return '$_temp0';
  }

  @override
  String get noUpdateableTargets => '선택한 대상에 사용 가능한 업데이트가 없습니다.';

  @override
  String get closeUpdatePlan => '닫기';

  @override
  String get targetSucceeded => '설치됨';

  @override
  String get targetSkipped => '건너뛰었습니다.';

  @override
  String get targetConflict => '갈등';

  @override
  String get targetFailed => '실패';

  @override
  String get targetFailureRetryable => '이 위치는 변경할 수 없습니다. 다시 시도해 보세요.';

  @override
  String get targetFailureNeedsAttention => '다시 시도하기 전에 이 위치에 주의가 필요합니다.';

  @override
  String get installationTargetFailureMessage =>
      '이 위치에서는 아무것도 변경되지 않았습니다. 폴더가 사용 가능한지 확인하고 다시 시도하십시오.';

  @override
  String get workspacePersistenceFailureMessage =>
      'SkillsGo가 프로젝트 설정을 저장할 수 없기 때문에 변경된 사항이 없습니다. 프로젝트 폴더에 쓰기 가능한지 확인하고 다시 시도하세요.';

  @override
  String get installationStateChangedMessage =>
      '검토하는 동안 위치가 변경되었습니다. 다시 시도하기 전에 최신 상태를 검토하세요.';

  @override
  String get updateTargetFailureMessage =>
      '이 위치를 업데이트할 수 없습니다. 다른 위치는 영향을 받지 않았으므로 이 위치만 다시 시도할 수 있습니다.';

  @override
  String get managementTargetFailureMessage =>
      '여기서는 이 작업을 완료할 수 없습니다. 다른 위치는 영향을 받지 않았으므로 이 위치만 다시 시도할 수 있습니다.';

  @override
  String get technicalDetails => '기술적인 세부사항';

  @override
  String get targetPathExists => '이 위치에 다른 항목이 이미 존재합니다.';

  @override
  String get targetBlockedByRisk => '현재 안전 설정으로 인해 이 위치에 설치가 차단되었습니다.';

  @override
  String get targetInstallFailed => '이 위치에는 스킬을 설치할 수 없습니다.';

  @override
  String get targetWorkspaceUpdateFailed => '스킬이 설치되었지만 프로젝트 설정을 업데이트할 수 없습니다.';

  @override
  String get installationPlanFailed => '설치 계획을 계속할 수 없습니다.';

  @override
  String get installationFailed => '설치를 완료할 수 없습니다.';

  @override
  String get localSource => '로컬 소스';

  @override
  String get noDescriptionAvailable => '설명이 없습니다.';

  @override
  String moreCoverage(int count) {
    return '+$count개 위치 더보기';
  }

  @override
  String get batchAdoptionAction => '기존 기술 관리';

  @override
  String handExternalSkillsToSkillsGoManagementCount(int count) {
    return 'SkillsGo이(가) $count 외부 기술을 관리하도록 허용';
  }

  @override
  String confirmSkillsGoManagementCount(int selected, int total) {
    return 'SkillsGo 관리 확인($selected/$total)';
  }

  @override
  String get skillColumnLabel => '기능';

  @override
  String get packageSourceColumnLabel => '원천';

  @override
  String get versionColumnLabel => '버전';

  @override
  String get packageMatching => '소스 일치…';

  @override
  String get sourceMatchUnavailable => '소스 매칭 불가';

  @override
  String get noSourceMatches => '일치하는 소스가 없습니다.';

  @override
  String sourceMatchPercent(int percent) {
    return '$percent% 일치';
  }

  @override
  String get versionPendingSelection => '먼저 소스를 선택하세요.';

  @override
  String batchAdoptionActionCount(int count) {
    return '관리하다($count)';
  }

  @override
  String get batchAdoptionChecking => '기존 스킬 확인 중…';

  @override
  String get batchAdoptionRetry => '관리할 수 있는 스킬 다시 확인';

  @override
  String batchAdoptionEligibleCount(int count) {
    return '$count을(를) 관리할 수 있습니다';
  }

  @override
  String get batchAdoptionPending => '경영에 기술을 더하다…';

  @override
  String get batchAdoptionTitle => '기존 스킬을 SkillsGo에서 관리하시겠습니까?';

  @override
  String get batchAdoptionDescription =>
      'SkillsGo는 스킬 파일을 이동하거나 덮어쓰거나 업로드하지 않고 로컬 관리 기록을 추가합니다. 지원되지 않거나 변경된 항목은 건너뜁니다.';

  @override
  String get batchAdoptionStoryTitle => '흩어져 있는 스킬을 하나의 명확한 라이브러리로 전환';

  @override
  String batchAdoptionStoryDescription(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개의 기존 기술',
      one: '1개의 기존 기술',
    );
    return 'SkillsGo가 이 위치에서 관리할 수 있는 $_temp0을 찾았습니다.';
  }

  @override
  String get batchAdoptionBeforeSemantics =>
      '관리하기 전에는 기존 기술이 어디에 설치되어 있는지, 현재 기술인지, 복구 방법 또는 프로젝트가 동일한 버전을 사용하는지 여부가 불분명합니다.';

  @override
  String get batchAdoptionPainLocation => '알 수 없는 설치 위치';

  @override
  String get batchAdoptionPainFreshness => '알 수 없는 업데이트 상태';

  @override
  String get batchAdoptionPainRecovery => '파손시 복구불가';

  @override
  String get batchAdoptionPainVersionDrift => '프로젝트 전반에 걸쳐 다양한 버전';

  @override
  String get batchAdoptionFolderTitle => '기존 스킬';

  @override
  String get batchAdoptionFolderSubtitle => '불분명한 상태';

  @override
  String get batchAdoptionAfterLabel => '이후';

  @override
  String get batchAdoptionAfterTitle => '하나의 명확한 라이브러리';

  @override
  String get batchAdoptionLibraryTitle => 'SkillsGo 라이브러리';

  @override
  String get batchAdoptionBenefitLocation => '위치 지우기';

  @override
  String get batchAdoptionBenefitFreshness => '업데이트 표시';

  @override
  String get batchAdoptionBenefitRecovery => '쉬운 복구';

  @override
  String get batchAdoptionBenefitVersions => '버전이 지워졌습니다.';

  @override
  String get batchAdoptionManagedSection => 'SkillsGo에서 관리함';

  @override
  String get batchAdoptionPendingSection => '보류 중';

  @override
  String batchAdoptionItemManaged(String name) {
    return '$name은 SkillsGo에서 관리합니다.';
  }

  @override
  String batchAdoptionItemSkipped(String name) {
    return '$name을(를) 관리에 추가할 수 없습니다.';
  }

  @override
  String batchAdoptionItemPending(String name) {
    return '$name이(가) 관리 대기 중입니다.';
  }

  @override
  String batchAdoptionAfterSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 스킬은',
      one: '1개의 스킬은',
    );
    return '관리 후, $_temp0 명확한 관리 상태로 하나의 라이브러리에 정리됩니다.';
  }

  @override
  String batchAdoptionMoreSkills(int count) {
    return '+$count개 더보기';
  }

  @override
  String get batchAdoptionTransitionSemantics =>
      'SkillsGo 관리에 이러한 기존 기술을 추가합니다.';

  @override
  String get batchAdoptionTransitionLabel => '정리';

  @override
  String get batchAdoptionStatusTitle => '관리현황';

  @override
  String get batchAdoptionStatusManaged => '관리됨';

  @override
  String get batchAdoptionStatusProgress => '정리';

  @override
  String get batchAdoptionStatusSkipped => '건너뛰었습니다.';

  @override
  String get batchAdoptionStatusFilesStay => '기술 파일은 원래 위치에 유지됩니다.';

  @override
  String get batchAdoptionBoardSemantics =>
      '스킬은 파일을 이동하지 않고도 완전한 행으로 정렬되고 SkillsGo에 의해 기록됩니다.';

  @override
  String get batchAdoptionBoardComplete => '올 클리어';

  @override
  String get batchAdoptionBoardPartial => '완료';

  @override
  String get batchAdoptionStatusTotal => '합계';

  @override
  String get batchAdoptionQueueComplete => '어떤 기술도 기다리고 있지 않습니다';

  @override
  String get batchAdoptionQueueWaiting => '스킬은 검증 후 여기로 이동됩니다.';

  @override
  String get batchAdoptionNextLabel => '다음';

  @override
  String batchAdoptionFillerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count SkillsGo 오거나이저 블록',
      one: '1 SkillsGo 오거나이저 블록',
    );
    return '$_temp0 마지막 행 완성';
  }

  @override
  String get batchAdoptionPreservation =>
      '파일, 경로 및 현재 워크플로는 현재 위치에 그대로 유지됩니다. SkillsGo는 로컬 관리 기록만 완료합니다.';

  @override
  String get batchAdoptionLaterHint =>
      '건너뛰면 언제든지 라이브러리에서 기존 스킬 관리를 사용할 수 있습니다.';

  @override
  String get batchAdoptionSkip => '지금은 아님';

  @override
  String get batchAdoptionConfirm => '관리에 추가';

  @override
  String get batchAdoptionExecutionRetry => '재시도';

  @override
  String get batchAdoptionResultTitle => '관리에 추가된 기술';

  @override
  String batchAdoptionSummary(int adopted, int skipped) {
    return '관리에 $adopted 기술이 추가되었으며, $skipped이(가) 건너뛰었습니다.';
  }

  @override
  String batchAdoptionFailureSummary(int adopted, int failed) {
    return '$adopted 기술이 관리에 추가되었으며 $failed이(가) 실패했습니다.';
  }

  @override
  String get batchAdoptionStatusFailed => '실패한';

  @override
  String batchAdoptionItemFailed(String name) {
    return '$name 실패';
  }

  @override
  String get batchAdoptionClose => '닫기';

  @override
  String get installMoreTargets => '더 많은 위치에 설치';

  @override
  String get detailPackageSource => '패키지 출처';

  @override
  String get detailStars => '별';

  @override
  String get detailUpdated => '업데이트됨';

  @override
  String get detailPackageSize => '패키지 크기';

  @override
  String get pathLabel => '프로젝트 경로';

  @override
  String get copyProjectPath => '프로젝트 경로 복사';

  @override
  String get projectPathCopied => '프로젝트 경로가 복사되었습니다.';

  @override
  String get onboardingWelcomeTitle => 'SkillsGo에 오신 것을 환영합니다';

  @override
  String get onboardingWelcomeDescription =>
      '에이전트와 프로젝트 전체에서 스킬을 검색, 설치 및 관리하세요.';

  @override
  String get onboardingDetectedAgents => '탐지된 에이전트';

  @override
  String get onboardingNoAgents => '설치된 에이전트가 감지되지 않았습니다. 계속할 수 있습니다.';

  @override
  String get onboardingNext => '다음';

  @override
  String get onboardingProjectsTitle => '프로젝트 추가';

  @override
  String get onboardingProjectsDescription => 'SkillsGo에서 관리할 프로젝트를 선택하세요.';

  @override
  String get onboardingAddProject => '지금 추가';

  @override
  String get onboardingAddProjectLater => '또는 나중에';

  @override
  String get onboardingStartUsing => 'SkillsGo 사용 시작';

  @override
  String get onboardingBack => '뒤로';

  @override
  String get restartOnboardingTitle => '온보딩';

  @override
  String get restartOnboardingDescription =>
      '프로젝트, 설정 또는 기술 데이터를 제거하지 않고 첫 실행 가이드를 다시 확인하세요.';

  @override
  String get restartOnboardingAction => '온보딩 다시 시작';

  @override
  String get restartOnboardingFailed => 'SkillsGo가 온보딩을 다시 시작할 수 없습니다.';

  @override
  String get libraryRefreshSettingsTitle => '로컬 라이브러리 새로 고침';

  @override
  String get libraryRefreshSettingsDescription =>
      '설치된 스킬, 추가된 프로젝트, 에이전트 및 관리할 수 있는 외부 스킬을 다시 검색합니다. 이는 아무것도 설치, 업데이트 또는 제거하지 않습니다.';

  @override
  String get libraryRefreshSettingsAction => '라이브러리 새로 고침';

  @override
  String get libraryRefreshSettingsPending => '상쾌한 도서관…';

  @override
  String get libraryRefreshSettingsSuccess => '로컬 라이브러리가 새로 고쳐졌습니다.';

  @override
  String get libraryRefreshSettingsFailed =>
      'SkillsGo가 로컬 라이브러리를 새로 고칠 수 없습니다.';

  @override
  String get onboardingProjectError => 'SkillsGo가 이 디렉터리에서 프로젝트를 추가할 수 없습니다.';

  @override
  String get onboardingProjectsLoadError => 'SkillsGo가 추가된 프로젝트를 로드할 수 없습니다.';

  @override
  String get onboardingStartupError => 'SkillsGo가 설정을 로드할 수 없습니다.';

  @override
  String get onboardingStateError =>
      'SkillsGo가 설정 진행 상황을 저장할 수 없습니다. 다시 시도해 보세요.';

  @override
  String get onboardingCliErrorTitle => 'SkillsGo CLI에 주의가 필요합니다';

  @override
  String get onboardingCliErrorDescription => '번들 CLI를 복구한 후 다시 시도하여 계속하십시오.';

  @override
  String get removeSkillsDescription => '다음 스킬이 삭제됩니다.';

  @override
  String confirmRemoveSkillsInline(int count) {
    return '$count 기술을 제거하시겠습니까?';
  }

  @override
  String removingSkillsProgress(int finished, int total) {
    return '$finished/$total 삭제';
  }

  @override
  String get confirmRemoveSkillsAction => '지금 삭제';

  @override
  String get viewRemovalDetails => '세부정보 보기';

  @override
  String get hideRemovalDetails => '세부정보 숨기기';
}
