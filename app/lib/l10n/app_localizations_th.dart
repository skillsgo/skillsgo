// ignore_for_file: text_direction_code_point_in_literal, text_direction_code_point_in_comment

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Thai (`th`).
class AppLocalizationsTh extends AppLocalizations {
  AppLocalizationsTh([String locale = 'th']) : super(locale);

  @override
  String get discover => 'ค้นพบ';

  @override
  String get discoverSkills =>
      'เป็นเรื่องดีที่ได้ทราบข้อมูลเพิ่มเติมอีกเล็กน้อย';

  @override
  String get library => 'ห้องสมุด';

  @override
  String get settings => 'การตั้งค่า';

  @override
  String get openSettings => 'เปิดการตั้งค่า';

  @override
  String get cliNeedsAttention =>
      'คอมโพเนนต์ SkillsGo ที่จำเป็นจำเป็นต้องได้รับการดูแล';

  @override
  String get cliMissingBundled =>
      'ส่วนประกอบ SkillsGo ที่จำเป็นหายไปหรือไม่สามารถเริ่มต้นได้ ติดตั้ง SkillsGo อีกครั้งเพื่อกู้คืน';

  @override
  String get cliDamagedBundled =>
      'ส่วนประกอบ SkillsGo ที่จำเป็นเสียหาย ติดตั้ง SkillsGo อีกครั้งเพื่อกู้คืน';

  @override
  String get cliIncompatibleBundled =>
      'คอมโพเนนต์ SkillsGo ที่จำเป็นไม่ตรงกับเวอร์ชันแอปนี้ อัปเดตหรือติดตั้ง SkillsGo ใหม่';

  @override
  String get officialIndex => 'SkillsGo Hub';

  @override
  String get discoverTitle => 'ค้นหาทักษะสำหรับการเคลื่อนไหวครั้งต่อไปของคุณ';

  @override
  String get skillsLeaderboard =>
      'เป็นเรื่องดีที่ได้ทราบข้อมูลเพิ่มเติมอีกเล็กน้อย';

  @override
  String searchResultsFor(String query) {
    return 'ผลลัพธ์สำหรับ “$query”';
  }

  @override
  String get searchSkills => 'ค้นหาทักษะหรือวางลิงก์ Git...';

  @override
  String get search => 'ค้นหา';

  @override
  String get ranking => 'การจัดอันดับ';

  @override
  String get trending => 'กำลังมาแรง';

  @override
  String get hot => 'ร้อน';

  @override
  String get discoverNavigation => 'ค้นพบการนำทาง';

  @override
  String get allTimeRanking => 'อันดับตลอดกาล';

  @override
  String get trendingNow => 'กำลังมาแรงใน 24 ชั่วโมงที่ผ่านมา';

  @override
  String get hotNow => 'ร้อนแรงตอนนี้';

  @override
  String get allTimeDescription =>
      'ทักษะสาธารณะได้รับคำสั่งจากการติดตั้งที่ยอมรับตลอดเวลา';

  @override
  String get trendingDescription =>
      'ทักษะสาธารณะเรียงลำดับตามการติดตั้งที่ยอมรับในช่วงกรอบเวลา 24 ชั่วโมงล่าสุด';

  @override
  String get hotDescription =>
      'ทักษะสาธารณะได้รับคำสั่งจากความเร็วและการเปลี่ยนแปลงการติดตั้งระยะสั้น';

  @override
  String get offlineTitle => 'ไม่สามารถเชื่อมต่อกับ SkillsGo';

  @override
  String get offlineMessage =>
      'ตรวจสอบการเชื่อมต่ออินเทอร์เน็ตของคุณแล้วลองอีกครั้ง หากคุณใช้พร็อกซีหรือที่อยู่บริการที่กำหนดเอง ให้ตรวจสอบในการตั้งค่า';

  @override
  String get searchFailedTitle => 'การค้นหาสะดุด';

  @override
  String get validationTitle => 'ตรวจสอบสิ่งที่คุณป้อน';

  @override
  String get validationMessage =>
      'SkillsGo ไม่สามารถใช้คำขอนี้ได้ ตรวจสอบสิ่งที่คุณป้อนแล้วลองอีกครั้ง';

  @override
  String get serverTitle => 'ไม่สามารถให้บริการได้ชั่วคราว';

  @override
  String get serverMessage =>
      'SkillsGo ไม่สามารถดำเนินการตามคำขอนี้ได้ในขณะนี้ โปรดลองอีกครั้งในอีกสักครู่';

  @override
  String get timeoutTitle => 'การดำเนินการนี้ใช้เวลานานเกินไป';

  @override
  String get timeoutMessage =>
      'บริการไม่ตอบสนองทันเวลา ตรวจสอบการเชื่อมต่อของคุณหรือลองอีกครั้ง';

  @override
  String get invalidResponseTitle => 'SkillsGo ต้องการการอัปเดต';

  @override
  String get invalidResponseMessage =>
      'SkillsGo เวอร์ชันของคุณไม่สามารถอ่านคำตอบนี้ได้ อัปเดตแอปแล้วลองอีกครั้ง';

  @override
  String get invalidLocalDataTitle => 'ไม่สามารถอ่านทักษะที่ติดตั้งไว้ได้';

  @override
  String get invalidLocalDataMessage =>
      'ข้อมูลการติดตั้งในเครื่องบางส่วนเสียหายหรือเข้ากันไม่ได้ อัปเดตหรือติดตั้ง SkillsGo ใหม่ แล้วลองอีกครั้ง';

  @override
  String get tryAgain => 'ลองอีกครั้ง';

  @override
  String get searchEmptyTitle => 'ค้นหา ไม่ต้องเลื่อน';

  @override
  String get searchEmptyMessage =>
      'ป้อนความสามารถ แหล่งที่มา หรืองานเพื่อค้นหาทักษะสาธารณะ';

  @override
  String get noSkillsTitle => 'ไม่พบทักษะ';

  @override
  String get noSkillsMessage => 'ลองใช้วลีที่กว้างขึ้นหรือตรวจสอบการสะกด';

  @override
  String get focusSearch => 'มุ่งเน้นการค้นหา';

  @override
  String get skillsFromLink => 'ความสามารถจากลิงค์นี้ครับ';

  @override
  String skillCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ทักษะ',
      one: '1 ทักษะ',
    );
    return '$_temp0';
  }

  @override
  String sourceResultsSummary(String source, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ทักษะจาก $source',
      one: '1 ทักษะจาก $source',
    );
    return '$_temp0';
  }

  @override
  String get sourceSearchEmptyTitle => 'ลิงค์นี้พร้อมตรวจสอบแล้ว';

  @override
  String sourceSearchEmptyMessage(String source) {
    return '$source ไม่ได้อยู่ในผลการค้นหาปัจจุบัน SkillsGo สามารถตรวจสอบลิงก์ได้โดยตรงในขั้นตอนถัดไป';
  }

  @override
  String get inspectSource => 'ดูทักษะได้ในลิงค์นี้';

  @override
  String get collectionEmptyTitle => 'ไม่มีทักษะในคอลเลกชันนี้';

  @override
  String get collectionEmptyMessage =>
      'ยังไม่มีอะไรที่นี่ ลองอีกครั้งหลังจากมีกิจกรรมการติดตั้งเพิ่มเติม';

  @override
  String get loadMore => 'โหลดเพิ่ม';

  @override
  String get install => 'ติดตั้ง';

  @override
  String get installAll => 'ติดตั้งทักษะทั้งหมด';

  @override
  String get latestCommit => 'การกระทำล่าสุด';

  @override
  String get installToMoreTargets => 'ติดตั้งในตำแหน่งเพิ่มเติม';

  @override
  String localTargets(int count) {
    return 'เป้าหมายท้องถิ่น $count';
  }

  @override
  String allTimeMetric(String count) {
    return 'การติดตั้ง $count ตลอดเวลา';
  }

  @override
  String trendingMetric(String count) {
    return 'การติดตั้ง $count / 24 ชม';
  }

  @override
  String hotMetric(String value, String change) {
    return '$value ชั่วโมงนี้ · $change';
  }

  @override
  String get trustUnverified => 'ไม่ได้รับการยืนยัน';

  @override
  String get trustCommunityVerified => 'ชุมชนได้รับการตรวจสอบแล้ว';

  @override
  String get trustPublisherVerified => 'ตรวจสอบผู้จัดพิมพ์แล้ว';

  @override
  String get trustOfficial => 'เป็นทางการ';

  @override
  String get trustWarned => 'เตือนแล้ว';

  @override
  String get trustDelisted => 'เพิกถอน';

  @override
  String get riskUnknown => 'ไม่ทราบความเสี่ยง';

  @override
  String get riskLow => 'ความเสี่ยงต่ำ';

  @override
  String get riskMedium => 'ความเสี่ยงปานกลาง';

  @override
  String get riskHigh => 'มีความเสี่ยงสูง';

  @override
  String get riskCritical => 'ความเสี่ยงที่สำคัญ';

  @override
  String openSkill(String name) {
    return 'เปิด $name';
  }

  @override
  String installs(String count) {
    return 'การติดตั้ง $count';
  }

  @override
  String get detailFailedTitle => 'ไม่สามารถโหลดทักษะนี้ได้';

  @override
  String get detailLoading => 'กำลังโหลดรายละเอียดทักษะที่ตรวจสอบได้';

  @override
  String get artifactUnavailableTitle => 'อาร์ติแฟกต์ไม่พร้อมใช้งาน';

  @override
  String get artifactUnavailableMessage =>
      'เวอร์ชันนี้ไม่มีจำหน่ายในขณะนี้ ลองอีกครั้งหรือเลือกเวอร์ชันอื่น';

  @override
  String get detailInvalidTitle => 'ไม่รองรับข้อมูลเมตาของอาร์ติแฟกต์';

  @override
  String get detailInvalidMessage =>
      'รายละเอียดบางอย่างสำหรับทักษะนี้ไม่สมบูรณ์หรือไม่สามารถอ่านได้ อัปเดต SkillsGo แล้วลองอีกครั้ง';

  @override
  String get instructionsTab => 'คำแนะนำ';

  @override
  String get manifestTab => 'ประจักษ์';

  @override
  String immutableVersionLabel(String version) {
    return '$version ไม่เปลี่ยนรูป';
  }

  @override
  String commitIdentity(String sha) {
    return 'คอมมิต $sha';
  }

  @override
  String treeIdentity(String sha) {
    return 'ต้นไม้ $sha';
  }

  @override
  String contentIdentity(String digest) {
    return 'เนื้อหา $digest';
  }

  @override
  String get trustDoesNotProveSafety =>
      'ความน่าเชื่อถือของผู้จัดพิมพ์ยืนยันความเป็นเจ้าของหรือการบำรุงรักษา มันไม่ได้รับรองความปลอดภัยของสิ่งประดิษฐ์ ความเสี่ยงได้รับการประเมินแยกต่างหากสำหรับเวอร์ชันที่ไม่เปลี่ยนรูปแบบนี้';

  @override
  String get knownInstallationTargets => 'เป้าหมายการติดตั้งที่ทราบ';

  @override
  String get installationRange => 'ขอบเขตที่ติดตั้ง';

  @override
  String get targetDetails => 'แสดงรายละเอียดเป้าหมาย';

  @override
  String get hideTargetDetails => 'ซ่อนรายละเอียดเป้าหมาย';

  @override
  String installedVersionLabel(String version) {
    return 'เวอร์ชัน $version';
  }

  @override
  String targetSummary(String scope, String agent, String version) {
    return '$scope / $agent · $version';
  }

  @override
  String get projectScope => 'โครงการ';

  @override
  String get fileContentUnavailable =>
      'การแสดงตัวอย่างแบบไบนารีหรือไม่พร้อมใช้งาน';

  @override
  String get fileContentTruncated =>
      'การแสดงตัวอย่างถูกตัดทอนด้วยขีดจำกัดความปลอดภัยของ Hub';

  @override
  String get retry => 'ลองอีกครั้ง';

  @override
  String get backToSearch => 'กลับไปค้นหา';

  @override
  String get installForCodex => 'ติดตั้งสำหรับ Codex';

  @override
  String get cliNotDetected => 'ทักษะ (ตรวจไม่พบ)';

  @override
  String get snapshotFiles => 'ไฟล์สแนปชอต';

  @override
  String get globalCodex => 'ทั่วโลก · Codex';

  @override
  String get yourLibrary => 'สิ่งที่คุณรู้อยู่ที่นี่ทั้งหมด';

  @override
  String get libraryNavigation => 'การนำทางห้องสมุด';

  @override
  String get all => 'ทั้งหมด';

  @override
  String get allSkills => 'ทักษะทั้งหมด';

  @override
  String get updatesOnly => 'อัพเดท';

  @override
  String get allAgents => 'Agent ทั้งหมด';

  @override
  String get allProjects => 'โครงการทั้งหมด';

  @override
  String get specificProject => 'โครงการ';

  @override
  String get userScope => 'ทั่วโลก';

  @override
  String get addProject => 'เพิ่มโครงการ';

  @override
  String get relocateProject => 'ย้ายที่อยู่';

  @override
  String get removeFromList => 'ลบออกจากรายการ';

  @override
  String removeProjectTitle(String name) {
    return 'ลบ $name ออกจาก SkillsGo หรือไม่';
  }

  @override
  String get removeProjectDescription =>
      'เฉพาะการอ้างอิงแอปเท่านั้นที่จะถูกลบออก SkillsGo จะไม่เปลี่ยนแปลงหรือลบไฟล์ใดๆ ในไดเร็กทอรีนี้';

  @override
  String projectRailUnavailable(String name) {
    return '$name — ไม่พร้อมใช้งาน';
  }

  @override
  String get emptyProjectTitle => 'ยังไม่มีทักษะ.';

  @override
  String get browseSkills => 'เรียกดูทักษะ';

  @override
  String get projectMissingTitle => 'ไดเรกทอรีโครงการหายไป';

  @override
  String get projectMissingMessage =>
      'ไดเร็กทอรีอาจถูกย้ายหรือโวลุ่มของไดเร็กทอรีอาจออฟไลน์ ย้ายตำแหน่งหรือลบเฉพาะการอ้างอิงแอปเท่านั้น';

  @override
  String get projectPermissionTitle => 'ต้องได้รับอนุญาตจากโครงการ';

  @override
  String get projectPermissionMessage =>
      'SkillsGo ไม่สามารถตรวจสอบรูทที่เลือกนี้ได้ ให้สิทธิ์การเข้าถึงโดยการย้ายตำแหน่งผ่านตัวเลือกไดเรกทอรี';

  @override
  String get projectInaccessibleTitle => 'ไม่สามารถเข้าถึงไดเรกทอรีโครงการได้';

  @override
  String get projectInaccessibleMessage =>
      'SkillsGo เก็บการอ้างอิงโครงการนี้ไว้ ตรวจสอบเส้นทางหรือโวลุ่ม แล้วย้ายตำแหน่ง';

  @override
  String get checking => 'กำลังตรวจสอบ...';

  @override
  String get checkUpdates => 'ตรวจสอบการอัปเดต';

  @override
  String get refresh => 'รีเฟรช';

  @override
  String get libraryUnavailable => 'ห้องสมุดไม่พร้อมใช้งาน';

  @override
  String get libraryEmpty => 'ยังไม่มีการติดตั้งทักษะ';

  @override
  String get libraryEmptyMessage =>
      'ติดตั้งทักษะจาก Discover และทักษะจะปรากฏที่นี่';

  @override
  String get searchLibrary => 'ค้นหาทักษะที่ติดตั้ง';

  @override
  String get libraryNoMatches => 'ไม่มีทักษะที่ตรงกัน';

  @override
  String get libraryNoMatchesMessage =>
      'ลองใช้ชื่อ แหล่งที่มา Agent โปรเจ็กต์ หรือเวอร์ชันอื่น';

  @override
  String agentsSummary(int count) {
    return 'Agent $count รายการ';
  }

  @override
  String projectsSummary(int count) {
    return '$count โปรเจ็กต์';
  }

  @override
  String versionsSummary(int count) {
    return 'เวอร์ชัน $count';
  }

  @override
  String get hubManaged => 'ฮับได้รับการจัดการ';

  @override
  String get localManaged => 'มีการจัดการในท้องถิ่น';

  @override
  String get externalInstallation => 'การติดตั้งภายนอก';

  @override
  String get readOnly => 'อ่านอย่างเดียว';

  @override
  String get unversioned => 'ไม่เปลี่ยนแปลง';

  @override
  String get supportingFiles => 'รองรับไฟล์';

  @override
  String get versionDivergence => 'ความแตกต่างของเวอร์ชัน';

  @override
  String get healthHealthy => 'ดีต่อสุขภาพ';

  @override
  String get healthMissing => 'เป้าหมายหายไป';

  @override
  String get healthReplaced => 'เป้าหมายถูกแทนที่';

  @override
  String get healthLocalModification => 'การปรับเปลี่ยนท้องถิ่น';

  @override
  String get healthUnreadable => 'เป้าหมายไม่สามารถอ่านได้';

  @override
  String get healthUndeclared => 'ไม่ได้ประกาศ';

  @override
  String get healthWorkspaceUnreadable => 'สถานะพื้นที่ทำงานไม่สามารถอ่านได้';

  @override
  String get healthLockMismatch => 'ล็อคไม่ตรงกัน';

  @override
  String get healthUnexpectedPath => 'เส้นทางเป้าหมายที่ไม่คาดคิด';

  @override
  String get modeExternal => 'ภายนอก';

  @override
  String get notLinked => 'ไม่ได้เชื่อมโยง';

  @override
  String get update => 'อัปเดต';

  @override
  String get backToLibrary => 'กลับไปที่ห้องสมุด';

  @override
  String get remove => 'ลบ';

  @override
  String get manageTargets => 'จัดการขอบเขต';

  @override
  String skillsSelected(int count) {
    return 'เลือก $count แล้ว';
  }

  @override
  String get clearSelection => 'ล้างการเลือก';

  @override
  String get selectCurrentResults => 'เลือกผลลัพธ์ปัจจุบัน';

  @override
  String get clearCurrentResultSelection => 'ล้างการเลือกผลลัพธ์ปัจจุบัน';

  @override
  String get manageTargetsTitle => 'จัดการเป้าหมายการติดตั้ง';

  @override
  String get manageTargetsDescription =>
      'เลือกการดำเนินการที่แน่นอนสำหรับแต่ละเป้าหมาย เป้าหมายที่ไม่ได้เลือกจะไม่เปลี่ยนแปลง';

  @override
  String targetActionsSelected(int selected, int total) {
    return 'เลือก $selected จาก $total เป้าหมายแล้ว';
  }

  @override
  String get confirmRemoveTarget => 'ยืนยันการลบ';

  @override
  String get applyTargetActions => 'ใช้การกระทำที่เลือก';

  @override
  String get managementProgressTitle => 'การใช้การดำเนินการตามเป้าหมาย';

  @override
  String get managementResultsTitle => 'ผลลัพธ์การกระทำตามเป้าหมาย';

  @override
  String managementResultSummary(int succeeded, int failed) {
    return '$succeeded สำเร็จ $failed ล้มเหลว';
  }

  @override
  String get workspaceOwnershipChanges =>
      'การดำเนินการของโปรเจ็กต์ที่เลือกจะอัปเดต skillsgo.yaml และ skillsgo-lock.yaml';

  @override
  String get targetContentPreserved =>
      'เนื้อหาเป้าหมายปัจจุบันจะถูกเก็บรักษาไว้';

  @override
  String get localReadFailed => 'ไม่สามารถอ่านทักษะนี้ได้';

  @override
  String get localReadFailedMessage =>
      'SkillsGo ไม่สามารถอ่านทักษะที่ติดตั้งนี้ได้ ตรวจสอบว่าโฟลเดอร์พร้อมใช้งานและเข้าถึงได้ จากนั้นลองอีกครั้ง';

  @override
  String get localConfiguration => 'การตั้งค่าทักษะ GO';

  @override
  String get settingsNavigation => 'การนำทางการตั้งค่า';

  @override
  String get general => 'ปรับแต่ง';

  @override
  String get agents => 'Agent';

  @override
  String get hub => 'ฮับ';

  @override
  String get installationPolicy => 'นโยบายการติดตั้ง';

  @override
  String get storage => 'ที่เก็บของ';

  @override
  String get colorScheme => 'โครงร่างสี';

  @override
  String get about => 'เกี่ยวกับ';

  @override
  String get colorSchemeInspectorTitle => 'บทบาทสีวัสดุที่สร้างขึ้น';

  @override
  String get skillsColorTokensTitle => 'SkillsGo ความหมายสี';

  @override
  String get skillsColorTokensDescription =>
      'สีของผลิตภัณฑ์ที่สร้างจาก Radix Sand และจัดระเบียบด้วยความหมายของ Primer โดยมีโฟลเดอร์เป็นลำดับชั้นเชิงพื้นที่โดยเฉพาะ';

  @override
  String get colorSchemeInspectorDescription =>
      'ดูตัวอย่างโทเค็น ColorScheme ที่ไม่สนับสนุนทุกอันที่สร้างจากข้อมูลเริ่มต้นปัจจุบัน คลิกสีเพื่อคัดลอกค่า HEX';

  @override
  String get colorSchemePairPreview => 'คู่ความหมาย';

  @override
  String get colorSchemePairPreviewDescription =>
      'บทบาทเบื้องหน้าและเบื้องหลังถูกแสดงผลร่วมกันเพื่อแสดงความแตกต่างและลำดับชั้น';

  @override
  String get colorSchemeComponentPreview => 'การแสดงตัวอย่างส่วนประกอบ';

  @override
  String get colorSchemeComponentPreviewDescription =>
      'การควบคุมวัสดุที่เป็นAgentแสดงผลด้วยรูปแบบการแสดงตัวอย่างที่แน่นอนนี้';

  @override
  String get colorSchemeSampleTitle => 'ชื่อการ์ดทักษะ';

  @override
  String get colorSchemeSampleBody => 'สำเนารองใช้ onSurfaceVariant';

  @override
  String get colorSchemeCopied => 'คัดลอกแล้ว';

  @override
  String get colorSchemeSampleGlyphs => 'อ๊า 123';

  @override
  String get colorSchemeGroupPrimary => 'ประถมศึกษา';

  @override
  String get colorSchemeGroupPrimaryDescription =>
      'การเน้นหลัก คอนเทนเนอร์ และบทบาทการเน้นเสียงคงที่';

  @override
  String get colorSchemeGroupSecondary => 'รอง';

  @override
  String get colorSchemeGroupSecondaryDescription =>
      'สนับสนุนการเน้นย้ำและกำหนดบทบาทรอง';

  @override
  String get colorSchemeGroupTertiary => 'ระดับอุดมศึกษา';

  @override
  String get colorSchemeGroupTertiaryDescription =>
      'สำเนียงที่ตัดกันและบทบาทระดับอุดมศึกษาคงที่';

  @override
  String get colorSchemeGroupSurface => 'พื้นผิว';

  @override
  String get colorSchemeGroupSurfaceDescription =>
      'หน้า คอนเทนเนอร์ ระดับความสูง และลำดับชั้นเบื้องหน้า';

  @override
  String get colorSchemeGroupUtility => 'โครงร่างและยูทิลิตี้';

  @override
  String get colorSchemeGroupUtilityDescription =>
      'ขอบเขต เงา รอยขีด และพื้นผิวผกผัน';

  @override
  String get colorSchemeGroupError => 'เกิดข้อผิดพลาด';

  @override
  String get colorSchemeGroupErrorDescription =>
      'การดำเนินการที่มีข้อผิดพลาด ข้อความ และคอนเทนเนอร์';

  @override
  String get colorSchemeUsagePrimary =>
      'การกระทำหลัก การเน้น และการเน้นเสียงเน้นสูง';

  @override
  String get colorSchemeUsageSecondary => 'การกระทำสนับสนุนและการเน้นเสียงกลาง';

  @override
  String get colorSchemeUsageTertiary => 'สำเนียงที่ตัดกันซึ่งเสริมหลักและรอง';

  @override
  String colorSchemeUsageContentOn(String token) {
    return 'ข้อความและไอคอนที่แสดงบน $token';
  }

  @override
  String colorSchemeUsageContainer(String family) {
    return 'คอนเทนเนอร์เน้นล่าง $family สำหรับการเลือกและการเน้นเสียง';
  }

  @override
  String colorSchemeUsageFixed(String family) {
    return 'คอนเทนเนอร์ $family คงที่ที่ไม่ขึ้นกับความสว่าง';
  }

  @override
  String colorSchemeUsageFixedDim(String family) {
    return 'คอนเทนเนอร์ $family แบบคงที่ที่ไม่ขึ้นกับความสว่างแบบหรี่แสง';
  }

  @override
  String colorSchemeUsageFixedContent(String family) {
    return 'เนื้อหาที่มีการเน้นย้ำสูงในคอนเทนเนอร์ $family แบบคงที่';
  }

  @override
  String colorSchemeUsageFixedVariantContent(String family) {
    return 'เนื้อหาที่เน้นล่างในคอนเทนเนอร์ $family แบบคงที่';
  }

  @override
  String get colorSchemeUsageSurface => 'หน้าฐานและพื้นผิวบริเวณขนาดใหญ่';

  @override
  String get colorSchemeUsageSurfaceDim =>
      'พื้นผิวฐานแบบหรี่แสงจะใช้ในโทนสีพื้นผิวที่มืดที่สุด';

  @override
  String get colorSchemeUsageSurfaceBright =>
      'พื้นผิวฐานสว่างใช้โทนสีพื้นผิวที่เบาที่สุด';

  @override
  String colorSchemeUsageSurfaceElevation(String level) {
    return '$level ระดับความสูงของพื้นผิวคอนเทนเนอร์';
  }

  @override
  String get colorSchemeElevationLowest => 'ต่ำสุด';

  @override
  String get colorSchemeElevationLow => 'ต่ำ';

  @override
  String get colorSchemeElevationDefault => 'ค่าเริ่มต้น';

  @override
  String get colorSchemeElevationHigh => 'สูง';

  @override
  String get colorSchemeElevationHighest => 'สูงสุด';

  @override
  String get colorSchemeUsageOnSurface => 'ข้อความหลักและไอคอนที่แสดงบนพื้นผิว';

  @override
  String get colorSchemeUsageOnSurfaceVariant =>
      'ข้อความรอง ป้ายกำกับ และไอคอนที่ถูกลดทอนลงบนพื้นผิว';

  @override
  String get colorSchemeUsageSurfaceTint =>
      'สีระดับความสูงของวัสดุที่ได้มาจากสีหลัก';

  @override
  String get colorSchemeUsageOutline =>
      'ขอบเขตที่โดดเด่นและโครงร่างองค์ประกอบที่เน้น';

  @override
  String get colorSchemeUsageOutlineVariant =>
      'ขอบเขตที่ละเอียดอ่อน ตัวคั่น และโครงร่างที่เน้นต่ำ';

  @override
  String get colorSchemeUsageShadow => 'สีหยดเงาสำหรับพื้นผิวยกระดับ';

  @override
  String get colorSchemeUsageScrim =>
      'การซ้อนทับแบบโมดอลใช้เพื่อยกเลิกการเน้นเนื้อหาพื้นหลัง';

  @override
  String get colorSchemeUsageInverseSurface =>
      'พื้นผิวที่มีการเน้นแสงกลับด้านและเน้นความมืด';

  @override
  String get colorSchemeUsageInversePrimary =>
      'สำเนียงหลักที่แสดงบนพื้นผิวผกผัน';

  @override
  String get colorSchemeUsageError =>
      'การดำเนินการที่มีข้อผิดพลาด สถานะ และการตอบรับที่มีการเน้นย้ำสูง';

  @override
  String get save => 'บันทึก';

  @override
  String get advancedSettings => 'ขั้นสูง';

  @override
  String get remindersSettings => 'การแจ้งเตือน';

  @override
  String get remindersSettingsTitle => 'การตั้งค่าการเตือนความจำ';

  @override
  String get remindersSettingsDescription => 'เลือกการแจ้งเตือนที่ต้องการรับ';

  @override
  String get updateReminderTitle => 'อัปเดตการแจ้งเตือน';

  @override
  String get updateReminderDescription =>
      'ตรวจสอบการอัปเดตเมื่อ Library เปิดขึ้น';

  @override
  String get securityReminderTitle => 'การแจ้งเตือนที่มีความเสี่ยงสูง';

  @override
  String get securityReminderDescription =>
      'แจ้งให้คุณทราบถึงความเสี่ยงสูงหรือวิกฤตใหม่ในทักษะที่ติดตั้ง';

  @override
  String availableUpdatesReminder(int count) {
    return 'ทักษะที่ติดตั้ง $count มีการอัปเดต';
  }

  @override
  String get openAvailableUpdates =>
      'เปิดมุมมองการอัปเดตที่มีอยู่เพื่อตรวจสอบและอัปเดต';

  @override
  String securityAdvisoriesReminder(int count) {
    return 'ทักษะที่ติดตั้ง $count จำเป็นต้องมีการตรวจสอบความปลอดภัย';
  }

  @override
  String get reviewInstalledSkills =>
      'ตรวจสอบข้อมูลความเสี่ยงก่อนที่จะใช้หรืออัปเดต';

  @override
  String get generalSettingsTitle => 'ทำให้ทักษะเป็นของคุณ';

  @override
  String get generalSettingsDescription =>
      'อินเทอร์เฟซเป็นไปตามภาษาของระบบ การเข้าถึง และการตั้งค่าการเคลื่อนไหวของคุณ';

  @override
  String get agentsSettingsTitle => 'สภาพแวดล้อมรันไทม์ของ Agent';

  @override
  String get hubSettingsTitle => 'แหล่งกำเนิดฮับ';

  @override
  String get hubSettingsDescription =>
      'ใช้ฮับอย่างเป็นทางการหรือต้นทาง HTTP(S) ที่โฮสต์เองซึ่งใช้โปรโตคอล SkillsGo เดียวกัน';

  @override
  String get testConnection => 'ทดสอบการเชื่อมต่อ';

  @override
  String get saveOrigin => 'บันทึกแหล่งกำเนิดสินค้า';

  @override
  String get resetDefault => 'รีเซ็ตเป็นค่าเริ่มต้น';

  @override
  String get connectionReady => 'การเชื่อมต่อพร้อมแล้ว';

  @override
  String get connectionFailed => 'การเชื่อมต่อล้มเหลว';

  @override
  String get hubInvalidOrigin =>
      'ป้อนต้นทาง HTTP(S) ที่ถูกต้องโดยไม่มีข้อมูลรับรอง คำค้นหา หรือส่วนย่อย';

  @override
  String hubHttpFailure(int status) {
    return 'ฮับส่งคืน HTTP $status ตรวจสอบการกำหนดค่า Origin และเซิร์ฟเวอร์';
  }

  @override
  String get hubInvalidProtocol =>
      'เซิร์ฟเวอร์ไม่ได้ส่งคืนโปรโตคอลการค้นหา SkillsGo Hub';

  @override
  String get hubInvalidJson => 'Hub ส่งคืน JSON ที่ไม่ถูกต้อง';

  @override
  String get hubConnectionFailure =>
      'ไม่สามารถเข้าถึงฮับได้ ตรวจสอบการกำหนดค่า Origin, เครือข่าย, พร็อกซี และ TLS';

  @override
  String get hubConnectionTimeout =>
      'การเชื่อมต่อฮับหมดเวลา ตรวจสอบเครือข่ายหรือลองอีกครั้ง';

  @override
  String get riskPolicyTitle => 'นโยบายความเสี่ยงส่วนบุคคล';

  @override
  String get riskPolicyDescription =>
      'กฎความปลอดภัยจะมีผลเมื่อคุณติดตั้งหรืออัปเดตทักษะ';

  @override
  String get confirmHighRisk => 'ต้องมีการยืนยันความเสี่ยงสูง';

  @override
  String get confirmHighRiskDescription =>
      'อาร์ติแฟกต์ที่มีความเสี่ยงสูงจำเป็นต้องได้รับการยืนยันเพิ่มเติมก่อนการติดตั้งเสมอ';

  @override
  String get allowCriticalOverride =>
      'อนุญาตให้แทนที่ความเสี่ยงที่สำคัญอย่างชัดเจน';

  @override
  String get allowCriticalOverrideDescription =>
      'อาร์ติแฟกต์ที่มีความเสี่ยงวิกฤตยังคงถูกบล็อกโดยค่าเริ่มต้น เปิดใช้งานสิ่งนี้เพื่อแสดงการแทนที่ด้วยตนเองแยกต่างหากเท่านั้น';

  @override
  String get storageHealthy => 'อ่านได้';

  @override
  String get storageNotInitialized => 'ไม่ได้เตรียมใช้งาน';

  @override
  String get storageUnavailable => 'ไม่พร้อมใช้งาน';

  @override
  String get storageInvalidResponse =>
      'CLI ที่ให้มาส่งคืนการตอบสนองการวินิจฉัยที่ไม่รองรับ';

  @override
  String get aboutSettingsTitle => 'ความเข้ากันได้ของผลิตภัณฑ์';

  @override
  String get appVersion => 'เวอร์ชันแอป';

  @override
  String get cliVersion => 'เวอร์ชัน CLI ที่แถมมา';

  @override
  String get compatible => 'เข้ากันได้';

  @override
  String get hubOriginSaved => 'Hub Origin บันทึกและนำไปใช้แล้ว';

  @override
  String get policySaved => 'บันทึกนโยบายการติดตั้งแล้ว';

  @override
  String get officialCli => 'SkillsGo CLI';

  @override
  String get ready => 'พร้อม';

  @override
  String get unknown => 'ไม่ทราบ';

  @override
  String get missing => 'หายไป';

  @override
  String get incompatible => 'เข้ากันไม่ได้';

  @override
  String get detecting => 'กำลังตรวจจับ...';

  @override
  String get customCliPath => 'เส้นทางปฏิบัติการแบบกำหนดเอง';

  @override
  String get saveAndDetect => 'บันทึกและตรวจจับ';

  @override
  String get detectAgain => 'ตรวจพบอีกครั้ง';

  @override
  String get agentInstalled => 'ติดตั้งแล้ว';

  @override
  String get agentSupported => 'รองรับ';

  @override
  String agentCatalogSummary(int installed, int supported) {
    return 'ติดตั้ง $installed แล้ว · รองรับ $supported แล้ว';
  }

  @override
  String installedAgentsTitle(int count) {
    return 'ติดตั้งแล้ว · $count';
  }

  @override
  String notInstalledAgentsTitle(int count) {
    return 'ไม่ได้ติดตั้ง · $count';
  }

  @override
  String get notInstalledAgentsDescription =>
      'รองรับโดย SkillsGo แต่ตรวจไม่พบบน Mac เครื่องนี้';

  @override
  String agentDiscoveryRoots(String paths) {
    return 'เส้นทางการโหลดทักษะ: $paths';
  }

  @override
  String get agentInspectionFailed =>
      'ข้อมูลการตรวจจับAgentไม่พร้อมใช้งาน เรียกใช้การตรวจจับอีกครั้ง';

  @override
  String get noInstalledAgentsTitle => 'ไม่พบ Agent ที่ติดตั้งไว้';

  @override
  String get noInstalledAgentsMessage =>
      'คุณสามารถเรียกดูทักษะนี้ต่อไปได้ แต่ยังไม่มีเป้าหมายการติดตั้ง ติดตั้ง Agent ที่รองรับ จากนั้นเรียกใช้การตรวจจับอีกครั้ง';

  @override
  String get clearCustomPath => 'ล้างเส้นทางที่กำหนดเอง';

  @override
  String get privacyProvenance => 'ความเป็นส่วนตัวและที่มา';

  @override
  String get privacySummary =>
      'การค้นหาของคุณไม่ได้รับการบันทึก และ SkillsGo จะไม่เก็บบันทึกคำสั่ง';

  @override
  String get language => 'ภาษา';

  @override
  String get personalizationTheme => 'ธีม';

  @override
  String get folderColorTheme => 'สีของธีม';

  @override
  String get folderColorThemeDescription =>
      'เลือกสีที่คุณชอบ SkillsGo จะสร้างจานสีอินเทอร์เฟซที่มีการประสานงานรอบๆ';

  @override
  String get brandNameNeteaseCloudMusic => 'NetEase คลาวด์มิวสิค';

  @override
  String get brandNameRaspberryPi => 'ราสเบอร์รี่ปี่';

  @override
  String get brandNameChinaEasternAirlines => 'ไชนาอีสเทิร์นแอร์ไลน์';

  @override
  String get brandNameNvidia => 'NVIDIA';

  @override
  String get brandNameTaobao => 'เถาเป่า';

  @override
  String get brandNameBitcoin => 'บิทคอยน์';

  @override
  String get appearanceMode => 'โหมด';

  @override
  String get appearanceModeDescription =>
      'ปฏิบัติตามลักษณะที่ปรากฏของระบบของคุณ หรือใช้ธีมสีอ่อนหรือสีเข้มเสมอ';

  @override
  String get followSystem => 'ระบบ';

  @override
  String get lightMode => 'เบา';

  @override
  String get darkMode => 'มืด';

  @override
  String get wallpaper => 'วอลล์เปเปอร์';

  @override
  String get wallpaperDescription =>
      'เลือกพื้นหลังท้องฟ้า การเลือกของคุณจะปรากฏด้านหลังโฟลเดอร์ทันที';

  @override
  String get wallpaperSun => 'อาทิตย์';

  @override
  String get wallpaperMercury => 'สารปรอท';

  @override
  String get wallpaperVenus => 'ดาวศุกร์';

  @override
  String get wallpaperEarth => 'โลก';

  @override
  String get wallpaperMars => 'ดาวอังคาร';

  @override
  String get wallpaperJupiter => 'ดาวพฤหัสบดี';

  @override
  String get wallpaperSaturn => 'ดาวเสาร์';

  @override
  String get wallpaperUranus => 'ดาวยูเรนัส';

  @override
  String get wallpaperNeptune => 'ดาวเนปจูน';

  @override
  String get wallpaperPluto => 'ดาวพลูโต';

  @override
  String get wallpaperMoon => 'ดวงจันทร์';

  @override
  String folderThemeChoice(String theme) {
    return '$theme ธีมโฟลเดอร์';
  }

  @override
  String get privacyAffiliation =>
      'การวัดและส่งข้อมูลทางไกลสำหรับการติดตั้งแบบไม่ระบุชื่อจะถูกควบคุมโดยการตั้งค่า SkillsGo SkillsGo ไม่มีส่วนเกี่ยวข้องกับ OpenAI หรือ Codex';

  @override
  String get commandCompleted => 'คำสั่งเสร็จสิ้น';

  @override
  String get commandFailed => 'คำสั่งล้มเหลว';

  @override
  String commandExit(int code) {
    return 'ออกจาก $code · ขยายบันทึกของเซสชันนี้';
  }

  @override
  String get command => 'คำสั่ง';

  @override
  String get cancel => 'ยกเลิก';

  @override
  String get updateUnknown => 'ไม่ทราบ';

  @override
  String get updateChecking => 'กำลังตรวจสอบ';

  @override
  String get upToDate => 'ถึงวันที่';

  @override
  String get updateAvailable => 'อัปเดต';

  @override
  String get updateUnavailable => 'ไม่สามารถใช้ได้';

  @override
  String get updateCheckFailed => 'การตรวจสอบล้มเหลว';

  @override
  String get installSkill => 'ติดตั้งทักษะ';

  @override
  String get installLocationTitle => 'กำหนดตำแหน่งการติดตั้ง';

  @override
  String get userLevel => 'ระดับผู้ใช้';

  @override
  String get projectLevel => 'ระดับโครงการ';

  @override
  String get projects => 'โครงการ';

  @override
  String get loading => 'กำลังโหลด...';

  @override
  String get repositoryParsing => 'กำลังแยกวิเคราะห์ที่เก็บ...';

  @override
  String userInstallSummary(int agents) {
    return 'ใช้ได้กับAgent $agents ในระดับผู้ใช้';
  }

  @override
  String projectInstallSummary(int projects, int agents) {
    return 'โปรเจ็กต์ $projects · Agent $agents';
  }

  @override
  String get installationResults => 'ผลการติดตั้ง';

  @override
  String get installationInProgress => 'อยู่ระหว่างดำเนินการติดตั้ง';

  @override
  String get installationSucceeded => 'การติดตั้งเสร็จสมบูรณ์';

  @override
  String get installationSucceededMessage =>
      'ขณะนี้ทักษะพร้อมใช้งานแล้วในสถานที่ที่เลือก';

  @override
  String get projectUnavailable => 'โครงการไม่พร้อมใช้งาน';

  @override
  String get installedCell => 'ติดตั้งแล้ว';

  @override
  String get unsupportedCell => 'ไม่พร้อมใช้งาน';

  @override
  String get confirmInstall => 'ยืนยันการติดตั้ง';

  @override
  String installAllRepositorySkills(int count) {
    return 'ติดตั้งทักษะพื้นที่เก็บข้อมูลทั้งหมด ($count)';
  }

  @override
  String get installAllSkillsTo => 'ติดตั้งทักษะทั้งหมดเพื่อ';

  @override
  String installRepositorySkills(String repository, int count) {
    return 'ติดตั้งทักษะ $repository ทั้งหมด ($count)';
  }

  @override
  String installSkillTo(String skill) {
    return 'ติดตั้ง $skill ไปที่';
  }

  @override
  String get availableInAllProjects => 'ทุกโครงการ';

  @override
  String get availableInSelectedProjects => 'โครงการที่เลือก';

  @override
  String get usedBy => 'สำหรับAgent';

  @override
  String get backToTargets => 'กลับสู่เป้าหมาย';

  @override
  String get stayHere => 'อยู่ที่นี่';

  @override
  String get viewInLibrary => 'ดูในห้องสมุด';

  @override
  String planCreateCount(int count) {
    return '$count สร้าง';
  }

  @override
  String planSkipCount(int count) {
    return '$count ข้ามไป';
  }

  @override
  String planReplaceCount(int count) {
    return 'แทนที่ $count';
  }

  @override
  String planConflictCount(int count) {
    return '$count ขัดแย้งกัน';
  }

  @override
  String planRiskCount(int count) {
    return 'ความเสี่ยง $count ถูกบล็อก';
  }

  @override
  String get refreshInstallationPlan => 'ใช้มติ';

  @override
  String get replaceVersionConflict =>
      'แทนที่เวอร์ชันที่ติดตั้งไว้ที่เป้าหมายนี้';

  @override
  String get replaceSkillIdCollision => 'แทนที่ ID ทักษะอื่นที่เป้าหมายนี้';

  @override
  String get replaceLocalModification =>
      'ละทิ้งการปรับเปลี่ยนในเครื่องและแทนที่เป้าหมายนี้';

  @override
  String get sharedTargetConflict =>
      'เส้นทางนี้ถูกใช้ร่วมกันโดยเป้าหมายAgentอื่นๆ';

  @override
  String sharedTargetConflictDescription(String agents) {
    return 'กลับไปที่เมทริกซ์เป้าหมายและเลือกเอเจนต์ที่ได้รับผลกระทบทั้งหมดก่อนที่จะเปลี่ยน: $agents';
  }

  @override
  String get replaceConflictingTarget => 'แทนที่เป้าหมายที่ขัดแย้งกัน';

  @override
  String get confirmHighRiskArtifact =>
      'การยืนยันสิ่งประดิษฐ์ที่มีความเสี่ยงสูง';

  @override
  String get confirmCriticalRiskArtifact =>
      'การยืนยันการแทนที่ความเสี่ยงที่สำคัญ';

  @override
  String get confirmRiskForSelectedTargets =>
      'ฉันตรวจสอบไฟล์อาร์ติแฟกต์แล้วและยอมรับความเสี่ยงนี้สำหรับเป้าหมายที่เลือก';

  @override
  String get criticalRiskBlocked => 'การติดตั้งที่มีความเสี่ยงร้ายแรงถูกบล็อก';

  @override
  String get criticalRiskOverrideDisabled =>
      'เปิดใช้การแทนที่ความเสี่ยงร้ายแรงอย่างชัดเจนในการตั้งค่าก่อนที่แผนนี้จะดำเนินการต่อได้';

  @override
  String get workspaceManifestChanges => 'การเปลี่ยนแปลงรายการพื้นที่ทำงาน';

  @override
  String get noWorkspaceManifestChanges =>
      'ไฟล์ Workspace Manifest จะไม่มีการเปลี่ยนแปลง';

  @override
  String lockVersionChange(String from, String to) {
    return '$from → $to';
  }

  @override
  String get notPresent => 'ไม่อยู่';

  @override
  String get planActionCreate => 'สร้าง';

  @override
  String get planActionReplace => 'แทนที่';

  @override
  String get planActionSkip => 'ข้าม';

  @override
  String get planActionConflict => 'ความขัดแย้ง';

  @override
  String get planActionBlockedByRisk => 'ถูกปิดกั้นด้วยความเสี่ยง';

  @override
  String installationResultSummary(int succeeded, int failed) {
    return 'ติดตั้งเป้าหมาย $succeeded แล้ว $failed ล้มเหลว';
  }

  @override
  String get installationProgressTitle => 'อยู่ระหว่างดำเนินการติดตั้ง';

  @override
  String installationProgressSummary(int finished, int total) {
    return 'เป้าหมาย $finished จาก $total เสร็จสิ้นแล้ว';
  }

  @override
  String get targetWaiting => 'กำลังรอ';

  @override
  String get targetRunning => 'กำลังติดตั้ง';

  @override
  String retryFailedTargets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ลองอีกครั้งสำหรับเป้าหมายที่ล้มเหลว $count รายการ',
      one: 'ลองอีกครั้งสำหรับเป้าหมายที่ล้มเหลว 1 รายการ',
    );
    return '$_temp0';
  }

  @override
  String get updatePlanTitle => 'เลือกเป้าหมายที่จะอัปเดต';

  @override
  String get updatePlanDescription =>
      'เลือกเป้าหมายการติดตั้งที่แน่นอน Agentและโปรเจ็กต์ที่ไม่ได้เลือกยังคงไม่เปลี่ยนแปลง';

  @override
  String updateTargetsSelected(int selected, int available) {
    return 'เลือกเป้าหมายที่อัปเดตได้ $selected จาก $available รายการ';
  }

  @override
  String updateVersionChange(String fromVersion, String toVersion) {
    return '$fromVersion → $toVersion';
  }

  @override
  String sourceReference(String reference) {
    return 'การอ้างอิงแหล่งที่มา: $reference';
  }

  @override
  String get fixedVersionTarget =>
      'ปักหมุด — ไม่มีการอ้างอิงที่สามารถเคลื่อนย้ายได้';

  @override
  String get currentVersionTarget => 'ถึงวันที่';

  @override
  String get updateCheckTargetFailed => 'การตรวจสอบการอัปเดตล้มเหลว';

  @override
  String get reconcileWorkspaceManifestTarget => 'รายการซ่อมแซมพื้นที่ทำงาน';

  @override
  String get updateSelectedTargets => 'อัปเดตเป้าหมายที่เลือก';

  @override
  String get updateProgressTitle => 'กำลังอัปเดตเป้าหมาย';

  @override
  String get updateResultsTitle => 'อัพเดทผลลัพธ์';

  @override
  String updateProgressSummary(int finished, int total) {
    return 'เป้าหมาย $finished จาก $total เสร็จสิ้นแล้ว';
  }

  @override
  String retryFailedUpdates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ลองอีกครั้งสำหรับการอัปเดตที่ล้มเหลว $count รายการ',
      one: 'ลองอีกครั้งสำหรับการอัปเดตที่ล้มเหลว 1 รายการ',
    );
    return '$_temp0';
  }

  @override
  String get noUpdateableTargets =>
      'ไม่มีเป้าหมายที่เลือกมีการอัปเดตที่พร้อมใช้งาน';

  @override
  String get closeUpdatePlan => 'ปิด';

  @override
  String get targetSucceeded => 'ติดตั้งแล้ว';

  @override
  String get targetSkipped => 'ข้ามไป';

  @override
  String get targetConflict => 'ความขัดแย้ง';

  @override
  String get targetFailed => 'ล้มเหลว';

  @override
  String get targetFailureRetryable =>
      'ไม่สามารถเปลี่ยนสถานที่นี้ได้ คุณสามารถลองอีกครั้ง';

  @override
  String get targetFailureNeedsAttention =>
      'ตำแหน่งนี้ต้องการความสนใจของคุณก่อนที่จะลองอีกครั้ง';

  @override
  String get installationTargetFailureMessage =>
      'ไม่มีอะไรเปลี่ยนแปลง ณ ตำแหน่งนี้ ตรวจสอบว่าโฟลเดอร์พร้อมใช้งานแล้วลองอีกครั้ง';

  @override
  String get workspacePersistenceFailureMessage =>
      'ไม่มีการเปลี่ยนแปลงเนื่องจาก SkillsGo ไม่สามารถบันทึกการตั้งค่าโครงการได้ ตรวจสอบว่าโฟลเดอร์โปรเจ็กต์สามารถเขียนได้แล้วลองอีกครั้ง';

  @override
  String get installationStateChangedMessage =>
      'สถานที่นี้มีการเปลี่ยนแปลงในขณะที่คุณกำลังตรวจสอบ ตรวจสอบสถานะล่าสุดก่อนที่จะลองอีกครั้ง';

  @override
  String get updateTargetFailureMessage =>
      'ไม่สามารถอัปเดตตำแหน่งนี้ได้ ตำแหน่งอื่นๆ ไม่ได้รับผลกระทบ ดังนั้นคุณจึงลองใหม่ได้เฉพาะตำแหน่งนี้เท่านั้น';

  @override
  String get managementTargetFailureMessage =>
      'ไม่สามารถดำเนินการนี้ให้เสร็จสิ้นได้ที่นี่ ตำแหน่งอื่นๆ ไม่ได้รับผลกระทบ ดังนั้นคุณจึงลองใหม่ได้เฉพาะตำแหน่งนี้เท่านั้น';

  @override
  String get technicalDetails => 'รายละเอียดทางเทคนิค';

  @override
  String get targetPathExists => 'มีรายการอื่นอยู่แล้วที่ตำแหน่งนี้';

  @override
  String get targetBlockedByRisk =>
      'การตั้งค่าความปลอดภัยปัจจุบันของคุณบล็อกการติดตั้งที่ตำแหน่งนี้';

  @override
  String get targetInstallFailed => 'ไม่สามารถติดตั้งทักษะได้ที่ตำแหน่งนี้';

  @override
  String get targetWorkspaceUpdateFailed =>
      'ติดตั้งทักษะแล้ว แต่ไม่สามารถอัปเดตการตั้งค่าโครงการได้';

  @override
  String get installationPlanFailed => 'แผนการติดตั้งไม่สามารถดำเนินการต่อได้';

  @override
  String get installationFailed => 'ไม่สามารถติดตั้งให้เสร็จสิ้นได้';

  @override
  String get localSource => 'แหล่งที่มาในท้องถิ่น';

  @override
  String get noDescriptionAvailable => 'ไม่มีคำอธิบาย';

  @override
  String moreCoverage(int count) {
    return 'อีก +$count ตำแหน่ง';
  }

  @override
  String get batchTakeoverAction => 'จัดการทักษะที่มีอยู่';

  @override
  String batchTakeoverActionCount(int count) {
    return 'จัดการ ($count)';
  }

  @override
  String get batchTakeoverChecking => 'กำลังตรวจสอบทักษะที่มีอยู่...';

  @override
  String get batchTakeoverRetry =>
      'ตรวจสอบ Skill ที่สามารถนำมาจัดการได้อีกครั้ง';

  @override
  String batchTakeoverEligibleCount(int count) {
    return 'สามารถจัดการ $count ได้';
  }

  @override
  String get batchTakeoverPending => 'เพิ่มทักษะการบริหารจัดการ...';

  @override
  String get batchTakeoverTitle => 'จัดการทักษะที่มีอยู่ด้วย SkillsGo?';

  @override
  String get batchTakeoverDescription =>
      'SkillsGo จะเพิ่มบันทึกการจัดการในพื้นที่โดยไม่ต้องย้าย เขียนทับ หรืออัปโหลดไฟล์ทักษะ รายการที่ไม่รองรับหรือเปลี่ยนแปลงจะถูกข้ามไป';

  @override
  String get batchTakeoverStoryTitle =>
      'เปลี่ยนทักษะที่กระจัดกระจายให้เป็นห้องสมุดที่ชัดเจน';

  @override
  String batchTakeoverStoryDescription(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ทักษะที่มีอยู่',
      one: '1 ทักษะที่มีอยู่',
    );
    return 'SkillsGo พบ $_temp0 ที่สามารถจัดการได้ในตำแหน่งนี้';
  }

  @override
  String get batchTakeoverBeforeSemantics =>
      'ก่อนการจัดการ ยังไม่ชัดเจนว่าทักษะที่มีอยู่ถูกติดตั้งไว้ที่ใด ไม่ว่าจะเป็นทักษะปัจจุบัน วิธีการกู้คืน หรือว่าโครงการใช้เวอร์ชันเดียวกันหรือไม่';

  @override
  String get batchTakeoverPainLocation => 'ตำแหน่งการติดตั้งที่ไม่รู้จัก';

  @override
  String get batchTakeoverPainFreshness => 'สถานะการอัปเดตที่ไม่รู้จัก';

  @override
  String get batchTakeoverPainRecovery => 'กู้คืนไม่ได้เมื่อเกิดความเสียหาย';

  @override
  String get batchTakeoverPainVersionDrift => 'เวอร์ชันต่างๆ ทั่วทั้งโครงการ';

  @override
  String get batchTakeoverFolderTitle => 'ทักษะที่มีอยู่';

  @override
  String get batchTakeoverFolderSubtitle => 'สถานะไม่ชัดเจน';

  @override
  String get batchTakeoverAfterLabel => 'หลังจากนั้น';

  @override
  String get batchTakeoverAfterTitle => 'ห้องสมุดที่ชัดเจนแห่งหนึ่ง';

  @override
  String get batchTakeoverLibraryTitle => 'ห้องสมุด SkillsGo';

  @override
  String get batchTakeoverBenefitLocation => 'เคลียร์สถานที่';

  @override
  String get batchTakeoverBenefitFreshness => 'การอัปเดตที่มองเห็นได้';

  @override
  String get batchTakeoverBenefitRecovery => 'ฟื้นตัวได้ง่าย';

  @override
  String get batchTakeoverBenefitVersions => 'เวอร์ชันที่ชัดเจน';

  @override
  String get batchTakeoverManagedSection => 'จัดการดูแลโดย SkillsGo';

  @override
  String get batchTakeoverPendingSection => 'รอดำเนินการ';

  @override
  String batchTakeoverItemManaged(String name) {
    return '$name จัดการโดย SkillsGo';
  }

  @override
  String batchTakeoverItemSkipped(String name) {
    return 'ไม่สามารถเพิ่ม $name ในการจัดการได้';
  }

  @override
  String batchTakeoverItemPending(String name) {
    return '$name กำลังรอการจัดการ';
  }

  @override
  String batchTakeoverAfterSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ทักษะเป็น',
      one: '1 ทักษะคือ',
    );
    return 'หลังจากการจัดการ $_temp0 ได้รับการจัดระเบียบในไลบรารีเดียวโดยมีสถานะการจัดการที่ชัดเจน';
  }

  @override
  String batchTakeoverMoreSkills(int count) {
    return 'อีก +$count';
  }

  @override
  String get batchTakeoverTransitionSemantics =>
      'เพิ่มทักษะที่มีอยู่เหล่านี้ให้กับการจัดการ SkillsGo';

  @override
  String get batchTakeoverTransitionLabel => 'จัดระเบียบ';

  @override
  String get batchTakeoverStatusTitle => 'สถานะการจัดการ';

  @override
  String get batchTakeoverStatusManaged => 'จัดการ';

  @override
  String get batchTakeoverStatusProgress => 'การจัดระเบียบ';

  @override
  String get batchTakeoverStatusSkipped => 'ข้ามไป';

  @override
  String get batchTakeoverStatusFilesStay =>
      'ไฟล์ทักษะจะยังคงอยู่ในตำแหน่งเดิม';

  @override
  String get batchTakeoverBoardSemantics =>
      'ทักษะจะถูกจัดเรียงเป็นแถวที่สมบูรณ์และบันทึกโดย SkillsGo โดยไม่ต้องย้ายไฟล์';

  @override
  String get batchTakeoverBoardComplete => 'ชัดเจนทั้งหมด';

  @override
  String get batchTakeoverBoardPartial => 'เสร็จสมบูรณ์';

  @override
  String get batchTakeoverStatusTotal => 'รวม';

  @override
  String get batchTakeoverQueueComplete => 'ไม่มีทักษะใดรออยู่';

  @override
  String get batchTakeoverQueueWaiting =>
      'ทักษะจะย้ายมาที่นี่หลังจากการตรวจสอบแล้ว';

  @override
  String get batchTakeoverNextLabel => 'ถัดไป';

  @override
  String batchTakeoverFillerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count บล็อกตัวจัดการ SkillsGo',
      one: '1 บล็อกตัวจัดการ SkillsGo',
    );
    return '$_temp0 กรอกแถวสุดท้าย';
  }

  @override
  String get batchTakeoverPreservation =>
      'ไฟล์ เส้นทาง และเวิร์กโฟลว์ปัจจุบันของคุณจะยังคงอยู่ในตำแหน่งเดิม SkillsGo จัดทำบันทึกการจัดการในพื้นที่ให้เสร็จสิ้นเท่านั้น';

  @override
  String get batchTakeoverLaterHint =>
      'หากคุณข้าม คุณสามารถใช้จัดการทักษะที่มีอยู่จากห้องสมุดได้ตลอดเวลา';

  @override
  String get batchTakeoverSkip => 'ไม่ใช่ตอนนี้';

  @override
  String get batchTakeoverConfirm => 'เพิ่มไปยังการจัดการ';

  @override
  String get batchTakeoverExecutionRetry => 'ลองอีกครั้ง';

  @override
  String get batchTakeoverResultTitle => 'เพิ่มทักษะในการบริหารจัดการ';

  @override
  String batchTakeoverSummary(int takenOver, int skipped) {
    return 'เพิ่มทักษะ $takenOver ในการจัดการแล้ว, $skipped ข้ามไป';
  }

  @override
  String get batchTakeoverClose => 'ปิด';

  @override
  String get installMoreTargets => 'ติดตั้งในสถานที่เพิ่มเติม';

  @override
  String get detailRepository => 'พื้นที่เก็บข้อมูล';

  @override
  String get detailStars => 'ดาว';

  @override
  String get detailUpdated => 'อัปเดตแล้ว';

  @override
  String get detailArchiveSize => 'ขนาดไปรษณีย์';

  @override
  String get pathLabel => 'เส้นทางโครงการ';

  @override
  String get copyProjectPath => 'คัดลอกเส้นทางโครงการ';

  @override
  String get projectPathCopied => 'คัดลอกเส้นทางโครงการแล้ว';

  @override
  String get onboardingWelcomeTitle => 'ยินดีต้อนรับสู่ SkillsGo';

  @override
  String get onboardingWelcomeDescription =>
      'ค้นหา ติดตั้ง และจัดการทักษะทั่วทั้งAgentและโปรเจ็กต์ของคุณ';

  @override
  String get onboardingDetectedAgents => 'Agent ที่ตรวจพบ';

  @override
  String get onboardingNoAgents =>
      'ไม่พบ Agent ที่ติดตั้งไว้ คุณยังสามารถดำเนินการต่อได้';

  @override
  String get onboardingNext => 'ถัดไป';

  @override
  String get onboardingProjectsTitle => 'เพิ่มโครงการของคุณ';

  @override
  String get onboardingProjectsDescription =>
      'เลือกโปรเจ็กต์ที่คุณต้องการให้ SkillsGo จัดการ';

  @override
  String get onboardingAddProject => 'เพิ่มตอนนี้';

  @override
  String get onboardingAddProjectLater => 'หรือหลังจากนั้น';

  @override
  String get onboardingStartUsing => 'เริ่มใช้ SkillsGo';

  @override
  String get onboardingBack => 'กลับ';

  @override
  String get restartOnboardingTitle => 'การเริ่มต้นใช้งาน';

  @override
  String get restartOnboardingDescription =>
      'ดูคู่มือการเปิดตัวครั้งแรกอีกครั้งโดยไม่ต้องลบโปรเจ็กต์ การตั้งค่า หรือข้อมูลทักษะ';

  @override
  String get restartOnboardingAction => 'รีสตาร์ทการเริ่มต้นใช้งาน';

  @override
  String get restartOnboardingFailed =>
      'SkillsGo ไม่สามารถเริ่มต้นการเริ่มต้นใช้งานใหม่ได้';

  @override
  String get libraryRefreshSettingsTitle => 'รีเฟรชห้องสมุดท้องถิ่น';

  @override
  String get libraryRefreshSettingsDescription =>
      'สแกนทักษะที่ติดตั้ง โปรเจ็กต์ที่เพิ่มเข้ามา Agent และทักษะภายนอกที่สามารถจัดการได้อีกครั้ง การดำเนินการนี้ไม่ได้ติดตั้ง อัปเดต หรือลบสิ่งใดๆ';

  @override
  String get libraryRefreshSettingsAction => 'รีเฟรชไลบรารี';

  @override
  String get libraryRefreshSettingsPending => 'กำลังรีเฟรชห้องสมุด…';

  @override
  String get libraryRefreshSettingsSuccess => 'รีเฟรชห้องสมุดท้องถิ่นแล้ว';

  @override
  String get libraryRefreshSettingsFailed =>
      'SkillsGo ไม่สามารถรีเฟรชห้องสมุดท้องถิ่นได้';

  @override
  String get onboardingProjectError =>
      'SkillsGo ไม่สามารถเพิ่มโครงการจากไดเรกทอรีนี้ได้';

  @override
  String get onboardingProjectsLoadError =>
      'SkillsGo ไม่สามารถโหลดโครงการที่เพิ่มของคุณ';

  @override
  String get onboardingStartupError => 'SkillsGo ไม่สามารถโหลดการตั้งค่าได้';

  @override
  String get onboardingStateError =>
      'SkillsGo ไม่สามารถบันทึกความคืบหน้าในการตั้งค่าของคุณได้ ลองอีกครั้ง';

  @override
  String get onboardingCliErrorTitle => 'SkillsGo CLI ต้องการความสนใจ';

  @override
  String get onboardingCliErrorDescription =>
      'ซ่อมแซม CLI ที่ให้มา จากนั้นลองดำเนินการต่ออีกครั้ง';
}
