// ignore_for_file: text_direction_code_point_in_literal, text_direction_code_point_in_comment

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get discover => 'Khám phá';

  @override
  String get discoverSkills => 'Thật vui khi biết thêm một chút.';

  @override
  String get library => 'Thư viện';

  @override
  String get settings => 'Cài đặt';

  @override
  String get openSettings => 'Mở cài đặt';

  @override
  String get cliNeedsAttention =>
      'Một thành phần SkillsGo bắt buộc cần được chú ý.';

  @override
  String get cliMissingBundled =>
      'Thành phần SkillsGo bắt buộc bị thiếu hoặc không thể khởi động. Cài đặt lại SkillsGo để khôi phục nó.';

  @override
  String get cliDamagedBundled =>
      'Thành phần SkillsGo bắt buộc bị hỏng. Cài đặt lại SkillsGo để khôi phục nó.';

  @override
  String get cliIncompatibleBundled =>
      'Thành phần SkillsGo bắt buộc không khớp với phiên bản ứng dụng này. Cập nhật hoặc cài đặt lại SkillsGo.';

  @override
  String get officialIndex => 'SkillsGo Hub';

  @override
  String get discoverTitle => 'Tìm một kỹ năng cho bước đi tiếp theo của bạn.';

  @override
  String get skillsLeaderboard => 'Thật vui khi biết thêm một chút.';

  @override
  String searchResultsFor(String query) {
    return 'Kết quả cho “$query”';
  }

  @override
  String get searchSkills => 'Tìm kiếm kỹ năng hoặc dán liên kết Git…';

  @override
  String get search => 'Tìm kiếm';

  @override
  String get ranking => 'Xếp hạng';

  @override
  String get trending => 'Xu hướng';

  @override
  String get hot => 'Nóng';

  @override
  String get discoverNavigation => 'Khám phá điều hướng';

  @override
  String get allTimeRanking => 'Xếp hạng mọi thời đại';

  @override
  String get trendingNow => 'Xu hướng trong 24 giờ qua';

  @override
  String get hotNow => 'Nóng ngay bây giờ';

  @override
  String get allTimeDescription =>
      'Kỹ năng công cộng được sắp xếp theo số lượt cài đặt được chấp nhận mọi lúc.';

  @override
  String get trendingDescription =>
      'Kỹ năng công cộng được sắp xếp theo số lượt cài đặt được chấp nhận trong khoảng thời gian 24 giờ mới nhất.';

  @override
  String get hotDescription =>
      'Kỹ năng công cộng được sắp xếp theo tốc độ cài đặt và thay đổi ngắn hạn.';

  @override
  String get offlineTitle => 'Không thể kết nối với SkillsGo';

  @override
  String get offlineMessage =>
      'Hãy kiểm tra kết nối Internet của bạn và thử lại. Nếu bạn sử dụng địa chỉ proxy hoặc dịch vụ tùy chỉnh, hãy xem lại địa chỉ đó trong Cài đặt.';

  @override
  String get searchFailedTitle => 'Đã xảy ra sự cố khi tìm kiếm';

  @override
  String get validationTitle => 'Kiểm tra những gì bạn đã nhập';

  @override
  String get validationMessage =>
      'SkillsGo không thể sử dụng yêu cầu này. Xem lại những gì bạn đã nhập và thử lại.';

  @override
  String get serverTitle => 'Dịch vụ tạm thời không có';

  @override
  String get serverMessage =>
      'SkillsGo không thể hoàn thành yêu cầu này ngay bây giờ. Hãy thử lại sau giây lát.';

  @override
  String get timeoutTitle => 'Việc này mất quá nhiều thời gian';

  @override
  String get timeoutMessage =>
      'Dịch vụ đã không phản hồi kịp thời. Hãy kiểm tra kết nối của bạn hoặc thử lại.';

  @override
  String get invalidResponseTitle => 'SkillsGo cần cập nhật';

  @override
  String get invalidResponseMessage =>
      'Phiên bản SkillsGo của bạn không thể đọc được phản hồi này. Hãy cập nhật ứng dụng rồi thử lại.';

  @override
  String get invalidLocalDataTitle => 'Không thể đọc kỹ năng đã cài đặt';

  @override
  String get invalidLocalDataMessage =>
      'Một số thông tin cài đặt cục bộ bị hỏng hoặc không tương thích. Hãy cập nhật hoặc cài đặt lại SkillsGo rồi thử lại.';

  @override
  String get tryAgain => 'Thử lại';

  @override
  String get searchEmptyTitle => 'Tìm kiếm, đừng cuộn.';

  @override
  String get searchEmptyMessage =>
      'Nhập khả năng, nguồn hoặc nhiệm vụ để tìm kiếm các kỹ năng công cộng.';

  @override
  String get noSkillsTitle => 'Không tìm thấy kỹ năng nào';

  @override
  String get noSkillsMessage =>
      'Hãy thử một cụm từ rộng hơn hoặc kiểm tra chính tả.';

  @override
  String get focusSearch => 'Tìm kiếm tập trung';

  @override
  String get skillsFromLink => 'Kỹ năng từ liên kết này';

  @override
  String skillCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kỹ năng',
      one: '1 kỹ năng',
    );
    return '$_temp0';
  }

  @override
  String sourceResultsSummary(String source, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kỹ năng từ $source',
      one: '1 kỹ năng từ $source',
    );
    return '$_temp0';
  }

  @override
  String get sourceSearchEmptyTitle => 'Liên kết này đã sẵn sàng để kiểm tra';

  @override
  String sourceSearchEmptyMessage(String source) {
    return '$source không có trong kết quả tìm kiếm hiện tại. SkillsGo có thể kiểm tra liên kết trực tiếp trong bước tiếp theo.';
  }

  @override
  String get inspectSource => 'Xem kỹ năng tại liên kết này';

  @override
  String get collectionEmptyTitle =>
      'Không có kỹ năng nào trong bộ sưu tập này';

  @override
  String get collectionEmptyMessage =>
      'Không có gì ở đây cả. Hãy thử lại sau khi thực hiện thêm hoạt động cài đặt.';

  @override
  String get loadMore => 'Tải thêm';

  @override
  String get install => 'cài đặt';

  @override
  String get installAll => 'Cài đặt tất cả các kỹ năng';

  @override
  String get latestCommit => 'Cam kết mới nhất';

  @override
  String get installToMoreTargets => 'Cài đặt ở nhiều vị trí hơn';

  @override
  String localTargets(int count) {
    return '$count mục tiêu cục bộ';
  }

  @override
  String allTimeMetric(String count) {
    return '$count lượt cài đặt mọi thời đại';
  }

  @override
  String trendingMetric(String count) {
    return '$count lượt cài đặt / 24h';
  }

  @override
  String hotMetric(String value, String change) {
    return '$value giờ này · $change';
  }

  @override
  String get trustUnverified => 'Chưa được xác minh';

  @override
  String get trustCommunityVerified => 'Cộng đồng đã xác minh';

  @override
  String get trustPublisherVerified => 'Đã xác minh nhà xuất bản';

  @override
  String get trustOfficial => 'chính thức';

  @override
  String get trustWarned => 'Đã cảnh báo';

  @override
  String get trustDelisted => 'Đã hủy niêm yết';

  @override
  String get riskUnknown => 'Rủi ro không xác định';

  @override
  String get riskLow => 'Rủi ro thấp';

  @override
  String get riskMedium => 'Rủi ro trung bình';

  @override
  String get riskHigh => 'Rủi ro cao';

  @override
  String get riskCritical => 'Rủi ro nghiêm trọng';

  @override
  String openSkill(String name) {
    return 'Mở $name';
  }

  @override
  String installs(String count) {
    return '$count lượt cài đặt';
  }

  @override
  String get detailFailedTitle => 'Không thể tải Kỹ năng này';

  @override
  String get detailLoading => 'Đang tải chi tiết Kỹ năng có thể kiểm tra';

  @override
  String get artifactUnavailableTitle => 'Hiện vật không có sẵn';

  @override
  String get artifactUnavailableMessage =>
      'Phiên bản này hiện không có sẵn. Hãy thử lại hoặc chọn phiên bản khác.';

  @override
  String get detailInvalidTitle => 'Siêu dữ liệu cấu phần không được hỗ trợ';

  @override
  String get detailInvalidMessage =>
      'Một số chi tiết về kỹ năng này không đầy đủ hoặc không thể đọc được. Hãy cập nhật SkillsGo rồi thử lại.';

  @override
  String get instructionsTab => 'Hướng dẫn';

  @override
  String get manifestTab => 'Bản kê khai';

  @override
  String immutableVersionLabel(String version) {
    return 'Bất biến $version';
  }

  @override
  String commitIdentity(String sha) {
    return 'Cam kết $sha';
  }

  @override
  String treeIdentity(String sha) {
    return 'Cây $sha';
  }

  @override
  String contentIdentity(String digest) {
    return 'Nội dung $digest';
  }

  @override
  String get trustDoesNotProveSafety =>
      'Sự tin cậy của nhà xuất bản xác minh quyền sở hữu hoặc bảo trì; nó không chứng nhận an toàn tạo tác. Rủi ro được đánh giá riêng cho phiên bản bất biến này.';

  @override
  String get knownInstallationTargets => 'Mục tiêu cài đặt đã biết';

  @override
  String get installationRange => 'Phạm vi cài đặt';

  @override
  String get targetDetails => 'Hiển thị chi tiết mục tiêu';

  @override
  String get hideTargetDetails => 'Ẩn chi tiết mục tiêu';

  @override
  String installedVersionLabel(String version) {
    return 'Phiên bản $version';
  }

  @override
  String targetSummary(String scope, String agent, String version) {
    return '$scope / $agent · $version';
  }

  @override
  String get projectScope => 'dự án';

  @override
  String get fileContentUnavailable => 'Xem trước nhị phân hoặc không có sẵn';

  @override
  String get fileContentTruncated =>
      'Bản xem trước bị cắt bớt theo giới hạn an toàn của Hub.';

  @override
  String get retry => 'Thử lại';

  @override
  String get backToSearch => 'Quay lại tìm kiếm';

  @override
  String get installForCodex => 'Cài đặt cho Codex';

  @override
  String get cliNotDetected => 'kỹ năng (không được phát hiện)';

  @override
  String get snapshotFiles => 'Tệp ảnh chụp nhanh';

  @override
  String get globalCodex => 'Toàn cầu · Codex';

  @override
  String get yourLibrary => 'Những gì bạn biết là tất cả ở đây.';

  @override
  String get libraryNavigation => 'Điều hướng thư viện';

  @override
  String get all => 'Tất cả';

  @override
  String get allSkills => 'Tất cả kỹ năng';

  @override
  String get updatesOnly => 'Cập nhật';

  @override
  String get allAgents => 'Tất cả Agent';

  @override
  String get allProjects => 'Tất cả dự án';

  @override
  String get specificProject => 'dự án';

  @override
  String get userScope => 'Toàn cầu';

  @override
  String get addProject => 'Thêm dự án';

  @override
  String get relocateProject => 'di dời';

  @override
  String get removeFromList => 'Xóa khỏi danh sách';

  @override
  String removeProjectTitle(String name) {
    return 'Xóa $name khỏi SkillsGo?';
  }

  @override
  String get removeProjectDescription =>
      'Chỉ có tham chiếu Ứng dụng sẽ bị xóa. SkillsGo sẽ không thay đổi hoặc xóa bất kỳ tệp nào trong thư mục này.';

  @override
  String projectRailUnavailable(String name) {
    return '$name — không có sẵn';
  }

  @override
  String get emptyProjectTitle => 'Chưa có kỹ năng';

  @override
  String get browseSkills => 'Duyệt kỹ năng';

  @override
  String get projectMissingTitle => 'Thư mục dự án bị thiếu';

  @override
  String get projectMissingMessage =>
      'Thư mục có thể đã di chuyển hoặc ổ đĩa của nó có thể ngoại tuyến. Di dời nó hoặc chỉ xóa tham chiếu Ứng dụng của nó.';

  @override
  String get projectPermissionTitle => 'Cần có sự cho phép của dự án';

  @override
  String get projectPermissionMessage =>
      'SkillsGo không thể kiểm tra gốc đã chọn này. Cấp quyền truy cập bằng cách di chuyển nó thông qua bộ chọn thư mục.';

  @override
  String get projectInaccessibleTitle =>
      'Thư mục dự án không thể truy cập được';

  @override
  String get projectInaccessibleMessage =>
      'SkillsGo đã lưu giữ tài liệu tham khảo về dự án này. Kiểm tra đường dẫn hoặc ổ đĩa, sau đó di chuyển nó.';

  @override
  String get checking => 'Đang kiểm tra…';

  @override
  String get checkUpdates => 'Kiểm tra cập nhật';

  @override
  String get refresh => 'Làm mới';

  @override
  String get libraryUnavailable => 'Thư viện không có sẵn';

  @override
  String get libraryEmpty => 'Chưa cài đặt kỹ năng nào';

  @override
  String get libraryEmptyMessage =>
      'Cài đặt Kỹ năng từ Khám phá và nó sẽ xuất hiện ở đây.';

  @override
  String get searchLibrary => 'Tìm kiếm các kỹ năng đã cài đặt';

  @override
  String get libraryNoMatches => 'Không có kỹ năng phù hợp';

  @override
  String get libraryNoMatchesMessage =>
      'Hãy thử tên, nguồn, Agent, dự án hoặc phiên bản khác.';

  @override
  String agentsSummary(int count) {
    return '$count Agent';
  }

  @override
  String projectsSummary(int count) {
    return 'dự án $count';
  }

  @override
  String versionsSummary(int count) {
    return 'Phiên bản $count';
  }

  @override
  String get hubManaged => 'Trung tâm được quản lý';

  @override
  String get localManaged => 'Được quản lý cục bộ';

  @override
  String get externalInstallation => 'Cài đặt bên ngoài';

  @override
  String get readOnly => 'Chỉ đọc';

  @override
  String get unversioned => 'Không phiên bản';

  @override
  String get supportingFiles => 'Các tập tin hỗ trợ';

  @override
  String get versionDivergence => 'Phiên bản phân kỳ';

  @override
  String get healthHealthy => 'khỏe mạnh';

  @override
  String get healthMissing => 'Thiếu mục tiêu';

  @override
  String get healthReplaced => 'Đã thay thế mục tiêu';

  @override
  String get healthLocalModification => 'Sửa đổi cục bộ';

  @override
  String get healthUnreadable => 'Mục tiêu không thể đọc được';

  @override
  String get healthUndeclared => 'Không khai báo';

  @override
  String get healthWorkspaceUnreadable =>
      'Trạng thái không gian làm việc không thể đọc được';

  @override
  String get healthLockMismatch => 'Khóa không khớp';

  @override
  String get healthUnexpectedPath => 'Đường dẫn mục tiêu không mong đợi';

  @override
  String get modeSymlink => 'Liên kết tượng trưng';

  @override
  String get modeCopy => 'Sao chép';

  @override
  String get modeExternal => 'Bên ngoài';

  @override
  String get notLinked => 'KHÔNG LIÊN KẾT';

  @override
  String get update => 'cập nhật';

  @override
  String get backToLibrary => 'Quay lại Thư viện';

  @override
  String get remove => 'Xóa';

  @override
  String get manageTargets => 'Quản lý phạm vi';

  @override
  String skillsSelected(int count) {
    return 'đã chọn $count';
  }

  @override
  String get clearSelection => 'Xóa lựa chọn';

  @override
  String get selectCurrentResults => 'Chọn kết quả hiện tại';

  @override
  String get clearCurrentResultSelection => 'Xóa lựa chọn kết quả hiện tại';

  @override
  String get manageTargetsTitle => 'Quản lý mục tiêu cài đặt';

  @override
  String get manageTargetsDescription =>
      'Chọn một hành động chính xác cho từng mục tiêu. Các mục tiêu không được chọn sẽ không thay đổi.';

  @override
  String targetActionsSelected(int selected, int total) {
    return 'Đã chọn $selected trong số $total mục tiêu';
  }

  @override
  String get repairTarget => 'sửa chữa';

  @override
  String get confirmRemoveTarget => 'Xác nhận xóa';

  @override
  String get applyTargetActions => 'Áp dụng các hành động đã chọn';

  @override
  String get managementProgressTitle => 'Áp dụng các hành động mục tiêu';

  @override
  String get managementResultsTitle => 'Kết quả hành động mục tiêu';

  @override
  String managementResultSummary(int succeeded, int failed) {
    return '$succeeded đã thành công, $failed không thành công';
  }

  @override
  String get workspaceOwnershipChanges =>
      'Các hành động dự án được chọn sẽ cập nhật SkillsGo.mod và SkillsGo.sum.';

  @override
  String get targetContentPreserved =>
      'Nội dung mục tiêu hiện tại sẽ được giữ nguyên.';

  @override
  String get localReadFailed => 'Không thể đọc kỹ năng này';

  @override
  String get localReadFailedMessage =>
      'SkillsGo không thể đọc được kỹ năng đã cài đặt này. Kiểm tra xem thư mục của nó có sẵn và có thể truy cập được không, sau đó thử lại.';

  @override
  String get localConfiguration => 'CÀI ĐẶT KỸ NĂNG GO';

  @override
  String get settingsNavigation => 'Điều hướng cài đặt';

  @override
  String get general => 'Cá nhân hóa';

  @override
  String get agents => 'Agent';

  @override
  String get hub => 'trung tâm';

  @override
  String get installationPolicy => 'Chính sách cài đặt';

  @override
  String get storage => 'Lưu trữ';

  @override
  String get colorScheme => 'Phối màu';

  @override
  String get about => 'Giới thiệu';

  @override
  String get colorSchemeInspectorTitle => 'Vai trò màu Vật liệu đã tạo';

  @override
  String get skillsColorTokensTitle => 'Màu sắc ngữ nghĩa của SkillsGo';

  @override
  String get skillsColorTokensDescription =>
      'Màu sắc sản phẩm được xây dựng từ Radix Sand và được sắp xếp theo ngữ nghĩa Primer, với Thư mục là hệ thống phân cấp không gian chuyên dụng.';

  @override
  String get colorSchemeInspectorDescription =>
      'Xem trước mọi mã thông báo ColorScheme không được dùng nữa được tạo từ hạt giống hiện tại. Bấm vào một màu để sao chép giá trị HEX của nó.';

  @override
  String get colorSchemePairPreview => 'Cặp ngữ nghĩa';

  @override
  String get colorSchemePairPreviewDescription =>
      'Vai trò tiền cảnh và hậu cảnh được hiển thị cùng nhau để thể hiện độ tương phản và phân cấp.';

  @override
  String get colorSchemeComponentPreview => 'Xem trước thành phần';

  @override
  String get colorSchemeComponentPreviewDescription =>
      'Các điều khiển Vật liệu đại diện được hiển thị với sơ đồ xem trước chính xác này.';

  @override
  String get colorSchemeSampleTitle => 'Tiêu đề thẻ kỹ năng';

  @override
  String get colorSchemeSampleBody => 'Bản sao phụ sử dụng onSurfaceVariant.';

  @override
  String get colorSchemeCopied => 'Đã sao chép';

  @override
  String get colorSchemeSampleGlyphs => 'Aa 123';

  @override
  String get colorSchemeGroupPrimary => 'Chính';

  @override
  String get colorSchemeGroupPrimaryDescription =>
      'Điểm nhấn chính, vùng chứa và vai trò giọng cố định.';

  @override
  String get colorSchemeGroupSecondary => 'Trung học';

  @override
  String get colorSchemeGroupSecondaryDescription =>
      'Hỗ trợ nhấn mạnh và cố định vai trò thứ yếu.';

  @override
  String get colorSchemeGroupTertiary => 'cấp ba';

  @override
  String get colorSchemeGroupTertiaryDescription =>
      'Các điểm nhấn tương phản và các vai trò cấp ba cố định.';

  @override
  String get colorSchemeGroupSurface => 'bề mặt';

  @override
  String get colorSchemeGroupSurfaceDescription =>
      'Phân cấp trang, vùng chứa, độ cao và tiền cảnh.';

  @override
  String get colorSchemeGroupUtility => 'Phác thảo & Tiện ích';

  @override
  String get colorSchemeGroupUtilityDescription =>
      'Ranh giới, bóng, đường viền và bề mặt nghịch đảo.';

  @override
  String get colorSchemeGroupError => 'Lỗi';

  @override
  String get colorSchemeGroupErrorDescription =>
      'Hành động lỗi, thông báo và vùng chứa.';

  @override
  String get colorSchemeUsagePrimary =>
      'Hành động chính, trọng tâm và điểm nhấn mạnh.';

  @override
  String get colorSchemeUsageSecondary =>
      'Hành động hỗ trợ và nhấn mạnh vừa phải.';

  @override
  String get colorSchemeUsageTertiary =>
      'Các điểm nhấn tương phản bổ sung cho chính và phụ.';

  @override
  String colorSchemeUsageContentOn(String token) {
    return 'Văn bản và biểu tượng hiển thị trên $token.';
  }

  @override
  String colorSchemeUsageContainer(String family) {
    return 'Vùng chứa $family được nhấn mạnh thấp hơn cho các vùng chọn và dấu.';
  }

  @override
  String colorSchemeUsageFixed(String family) {
    return 'Vùng chứa $family cố định không phụ thuộc vào độ sáng.';
  }

  @override
  String colorSchemeUsageFixedDim(String family) {
    return 'Vùng chứa $family cố định không phụ thuộc vào độ sáng bị mờ.';
  }

  @override
  String colorSchemeUsageFixedContent(String family) {
    return 'Nội dung được nhấn mạnh trên vùng chứa $family cố định.';
  }

  @override
  String colorSchemeUsageFixedVariantContent(String family) {
    return 'Nội dung được nhấn mạnh thấp hơn trên vùng chứa $family cố định.';
  }

  @override
  String get colorSchemeUsageSurface => 'Trang cơ sở và bề mặt vùng lớn.';

  @override
  String get colorSchemeUsageSurfaceDim =>
      'Bề mặt đế mờ được sử dụng ở tông màu bề mặt tối nhất.';

  @override
  String get colorSchemeUsageSurfaceBright =>
      'Bề mặt đế sáng được sử dụng ở tông màu bề mặt nhẹ nhất.';

  @override
  String colorSchemeUsageSurfaceElevation(String level) {
    return 'Độ cao của vùng chứa bề mặt $level.';
  }

  @override
  String get colorSchemeElevationLowest => 'thấp nhất';

  @override
  String get colorSchemeElevationLow => 'thấp';

  @override
  String get colorSchemeElevationDefault => 'mặc định';

  @override
  String get colorSchemeElevationHigh => 'cao';

  @override
  String get colorSchemeElevationHighest => 'cao nhất';

  @override
  String get colorSchemeUsageOnSurface =>
      'Văn bản và biểu tượng chính hiển thị trên bề mặt.';

  @override
  String get colorSchemeUsageOnSurfaceVariant =>
      'Văn bản phụ, nhãn và biểu tượng chìm trên bề mặt.';

  @override
  String get colorSchemeUsageSurfaceTint =>
      'Chất liệu độ cao màu có nguồn gốc từ sơ cấp.';

  @override
  String get colorSchemeUsageOutline =>
      'Ranh giới nổi bật và phác thảo thành phần tập trung.';

  @override
  String get colorSchemeUsageOutlineVariant =>
      'Ranh giới tinh tế, dấu phân cách và đường viền ít nhấn mạnh.';

  @override
  String get colorSchemeUsageShadow => 'Màu bóng đổ cho bề mặt trên cao.';

  @override
  String get colorSchemeUsageScrim =>
      'Lớp phủ phương thức được sử dụng để làm nổi bật nội dung nền.';

  @override
  String get colorSchemeUsageInverseSurface =>
      'Bề mặt với điểm nhấn sáng và tối đảo ngược.';

  @override
  String get colorSchemeUsageInversePrimary =>
      'Giọng chính hiển thị trên một bề mặt nghịch đảo.';

  @override
  String get colorSchemeUsageError =>
      'Hành động lỗi, trạng thái và phản hồi có mức độ nhấn mạnh cao.';

  @override
  String get save => 'Lưu';

  @override
  String get advancedSettings => 'Nâng cao';

  @override
  String get remindersSettings => 'Lời nhắc';

  @override
  String get remindersSettingsTitle => 'Cài đặt lời nhắc';

  @override
  String get remindersSettingsDescription => 'Chọn lời nhắc sẽ nhận.';

  @override
  String get updateReminderTitle => 'Cập nhật lời nhắc';

  @override
  String get updateReminderDescription =>
      'Kiểm tra các bản cập nhật khi Thư viện mở ra.';

  @override
  String get securityReminderTitle => 'Cảnh báo rủi ro cao';

  @override
  String get securityReminderDescription =>
      'Thông báo cho bạn về rủi ro Cao hoặc Nghiêm trọng mới trong các kỹ năng đã cài đặt.';

  @override
  String availableUpdatesReminder(int count) {
    return 'Các kỹ năng đã cài đặt của $count đã có bản cập nhật';
  }

  @override
  String get openAvailableUpdates =>
      'Mở chế độ xem các bản cập nhật có sẵn để xem lại và cập nhật chúng.';

  @override
  String securityAdvisoriesReminder(int count) {
    return 'Các kỹ năng đã cài đặt $count cần được xem xét bảo mật';
  }

  @override
  String get reviewInstalledSkills =>
      'Xem lại thông tin rủi ro của họ trước khi sử dụng hoặc cập nhật chúng.';

  @override
  String get generalSettingsTitle => 'Biến SkillsGo thành của bạn';

  @override
  String get generalSettingsDescription =>
      'Giao diện tuân theo ngôn ngữ hệ thống, khả năng truy cập và tùy chọn chuyển động của bạn.';

  @override
  String get agentsSettingsTitle => 'Môi trường chạy Agent';

  @override
  String get hubSettingsTitle => 'Nguồn gốc trung tâm';

  @override
  String get hubSettingsDescription =>
      'Sử dụng Hub chính thức hoặc nguồn gốc tự lưu trữ HTTP(S) triển khai cùng giao thức SkillsGo.';

  @override
  String get testConnection => 'Kiểm tra kết nối';

  @override
  String get saveOrigin => 'Lưu nguồn gốc';

  @override
  String get resetDefault => 'Đặt lại về mặc định';

  @override
  String get connectionReady => 'Kết nối đã sẵn sàng';

  @override
  String get connectionFailed => 'Kết nối không thành công';

  @override
  String get hubInvalidOrigin =>
      'Nhập Nguồn gốc HTTP(S) hợp lệ mà không có thông tin xác thực, truy vấn hoặc đoạn.';

  @override
  String hubHttpFailure(int status) {
    return 'Hub trả về HTTP $status. Kiểm tra cấu hình Origin và server.';
  }

  @override
  String get hubInvalidProtocol =>
      'Máy chủ không trả về giao thức tìm kiếm SkillsGo Hub.';

  @override
  String get hubInvalidJson => 'Hub trả về JSON không hợp lệ.';

  @override
  String get hubConnectionFailure =>
      'Không thể đến được Hub. Kiểm tra cấu hình Origin, mạng, proxy và TLS.';

  @override
  String get hubConnectionTimeout =>
      'Kết nối Hub đã hết thời gian chờ. Hãy kiểm tra mạng hoặc thử lại.';

  @override
  String get riskPolicyTitle => 'Chính sách rủi ro cá nhân';

  @override
  String get riskPolicyDescription =>
      'Các quy tắc an toàn được áp dụng khi bạn cài đặt hoặc cập nhật một kỹ năng.';

  @override
  String get confirmHighRisk => 'Yêu cầu xác nhận vì rủi ro cao';

  @override
  String get confirmHighRiskDescription =>
      'Các hiện vật có nguy cơ cao luôn yêu cầu xác nhận bổ sung trước khi cài đặt.';

  @override
  String get allowCriticalOverride =>
      'Cho phép ghi đè rủi ro nghiêm trọng rõ ràng';

  @override
  String get allowCriticalOverrideDescription =>
      'Các tạo phẩm có nguy cơ nghiêm trọng vẫn bị chặn theo mặc định. Chỉ bật tính năng này để hiển thị ghi đè thủ công riêng biệt.';

  @override
  String get storageSettingsTitle => 'Kho lưu trữ định địa chỉ theo nội dung';

  @override
  String get storageHealthy => 'Có thể đọc được';

  @override
  String get storageNotInitialized => 'Chưa khởi tạo';

  @override
  String get storageUnavailable => 'Không có sẵn';

  @override
  String get storagePathUnavailable =>
      'Đường dẫn lưu trữ không khả dụng cho đến khi chẩn đoán CLI sẵn sàng.';

  @override
  String get storageHealthyDescription =>
      'CLI có thể đọc Store mà không thay đổi nội dung của nó.';

  @override
  String get storageNotInitializedDescription =>
      'Cửa hàng chưa tồn tại và không được tạo bằng lần kiểm tra này.';

  @override
  String get storageUnavailableDescription =>
      'CLI không thể đọc kho lưu trữ. Hãy kiểm tra quyền truy cập và thư mục cha.';

  @override
  String get storageInvalidResponse =>
      'CLI đi kèm trả về phản hồi chẩn đoán không được hỗ trợ.';

  @override
  String get aboutSettingsTitle => 'Khả năng tương thích của sản phẩm';

  @override
  String get appVersion => 'Phiên bản ứng dụng';

  @override
  String get cliVersion => 'Phiên bản CLI đi kèm';

  @override
  String get compatible => 'Tương thích';

  @override
  String get hubOriginSaved => 'Hub Origin đã được lưu và áp dụng.';

  @override
  String get policySaved => 'Đã lưu chính sách cài đặt.';

  @override
  String get officialCli => 'SkillsGo CLI';

  @override
  String get ready => 'SẴN SÀNG';

  @override
  String get unknown => 'KHÔNG XÁC ĐỊNH';

  @override
  String get missing => 'THIẾU';

  @override
  String get incompatible => 'KHÔNG TƯƠNG THÍCH';

  @override
  String get detecting => 'Đang phát hiện…';

  @override
  String get customCliPath => 'Đường dẫn thực thi tùy chỉnh';

  @override
  String get saveAndDetect => 'Lưu và phát hiện';

  @override
  String get detectAgain => 'Phát hiện lại';

  @override
  String get agentInstalled => 'Đã cài đặt';

  @override
  String get agentSupported => 'Được hỗ trợ';

  @override
  String agentCatalogSummary(int installed, int supported) {
    return 'Đã cài đặt $installed · Đã hỗ trợ $supported';
  }

  @override
  String installedAgentsTitle(int count) {
    return 'Đã cài đặt · $count';
  }

  @override
  String notInstalledAgentsTitle(int count) {
    return 'Chưa được cài đặt · $count';
  }

  @override
  String get notInstalledAgentsDescription =>
      'Được hỗ trợ bởi SkillsGo nhưng không được phát hiện trên máy Mac này.';

  @override
  String agentDiscoveryRoots(String paths) {
    return 'Đường dẫn tải kỹ năng: $paths';
  }

  @override
  String get agentInspectionFailed =>
      'Dữ liệu phát hiện tác nhân không có sẵn. Chạy lại phát hiện.';

  @override
  String get noInstalledAgentsTitle =>
      'Không phát hiện thấy Tác nhân đã cài đặt nào';

  @override
  String get noInstalledAgentsMessage =>
      'Bạn có thể tiếp tục duyệt Kỹ năng này nhưng chưa có mục tiêu cài đặt. Cài đặt Tác nhân được hỗ trợ, sau đó chạy lại tính năng phát hiện.';

  @override
  String get clearCustomPath => 'Xóa đường dẫn tùy chỉnh';

  @override
  String get privacyProvenance => 'Quyền riêng tư và xuất xứ';

  @override
  String get privacySummary =>
      'Các tìm kiếm của bạn không được lưu và SkillsGo không lưu giữ nhật ký lệnh.';

  @override
  String get language => 'Ngôn ngữ';

  @override
  String get personalizationTheme => 'chủ đề';

  @override
  String get folderColorTheme => 'Màu chủ đề';

  @override
  String get folderColorThemeDescription =>
      'Chọn một màu bạn thích. SkillsGo sẽ xây dựng một bảng giao diện phối hợp xung quanh nó.';

  @override
  String get brandNameNeteaseCloudMusic => 'Nhạc đám mây NetEase';

  @override
  String get brandNameRaspberryPi => 'Raspberry Pi';

  @override
  String get brandNameChinaEasternAirlines =>
      'Hãng hàng không Phương Đông Trung Quốc';

  @override
  String get brandNameNvidia => 'NVIDIA';

  @override
  String get brandNameTaobao => 'taobao';

  @override
  String get brandNameBitcoin => 'bitcoin';

  @override
  String get appearanceMode => 'Chế độ';

  @override
  String get appearanceModeDescription =>
      'Theo dõi giao diện hệ thống của bạn hoặc luôn sử dụng chủ đề sáng hoặc tối.';

  @override
  String get followSystem => 'Hệ thống';

  @override
  String get lightMode => 'Ánh sáng';

  @override
  String get darkMode => 'Tối';

  @override
  String get wallpaper => 'Hình nền';

  @override
  String get wallpaperDescription =>
      'Chọn một nền thiên thể. Lựa chọn của bạn xuất hiện ngay sau Thư mục.';

  @override
  String get wallpaperSun => 'mặt trời';

  @override
  String get wallpaperMercury => 'Thủy ngân';

  @override
  String get wallpaperVenus => 'Sao Kim';

  @override
  String get wallpaperEarth => 'trái đất';

  @override
  String get wallpaperMars => 'Sao Hỏa';

  @override
  String get wallpaperJupiter => 'Sao Mộc';

  @override
  String get wallpaperSaturn => 'Sao Thổ';

  @override
  String get wallpaperUranus => 'Sao Thiên Vương';

  @override
  String get wallpaperNeptune => 'Sao Hải Vương';

  @override
  String get wallpaperPluto => 'Sao Diêm Vương';

  @override
  String get wallpaperMoon => 'mặt trăng';

  @override
  String folderThemeChoice(String theme) {
    return 'Chủ đề thư mục $theme';
  }

  @override
  String get privacyAffiliation =>
      'Đo từ xa cài đặt ẩn danh được kiểm soát bởi cài đặt SkillsGo. SkillsGo không liên kết với OpenAI hoặc Codex.';

  @override
  String get commandCompleted => 'Lệnh hoàn thành';

  @override
  String get commandFailed => 'Lệnh không thành công';

  @override
  String commandExit(int code) {
    return 'Thoát $code · mở rộng cho nhật ký của phiên này';
  }

  @override
  String get command => 'Lệnh';

  @override
  String get cancel => 'Hủy bỏ';

  @override
  String get updateUnknown => 'KHÔNG XÁC ĐỊNH';

  @override
  String get updateChecking => 'KIỂM TRA';

  @override
  String get upToDate => 'CẬP NHẬT';

  @override
  String get updateAvailable => 'CẬP NHẬT';

  @override
  String get updateUnavailable => 'KHÔNG CÓ SẴN';

  @override
  String get updateCheckFailed => 'KIỂM TRA THẤT BẠI';

  @override
  String get installSkill => 'Cài đặt kỹ năng';

  @override
  String get installLocationTitle => 'Đặt vị trí cài đặt';

  @override
  String get userLevel => 'Cấp độ người dùng';

  @override
  String get projectLevel => 'Cấp độ dự án';

  @override
  String get projects => 'Dự án';

  @override
  String get loading => 'Đang tải…';

  @override
  String get repositoryParsing => 'Đang phân tích kho lưu trữ…';

  @override
  String userInstallSummary(int agents) {
    return 'Có sẵn cho Agent $agents ở cấp độ người dùng';
  }

  @override
  String projectInstallSummary(int projects, int agents) {
    return 'Dự án $projects · Agent $agents';
  }

  @override
  String get installationResults => 'Kết quả cài đặt';

  @override
  String get installationInProgress => 'Đang tiến hành cài đặt';

  @override
  String get installationSucceeded => 'Cài đặt hoàn tất';

  @override
  String get installationSucceededMessage =>
      'Kỹ năng hiện có sẵn ở các địa điểm đã chọn.';

  @override
  String get projectUnavailable => 'Dự án không có sẵn';

  @override
  String get installedCell => 'Đã cài đặt';

  @override
  String get unsupportedCell => 'Không có sẵn';

  @override
  String get confirmInstall => 'Xác nhận cài đặt';

  @override
  String installAllRepositorySkills(int count) {
    return 'Cài đặt tất cả các kỹ năng kho lưu trữ ($count)';
  }

  @override
  String get installAllSkillsTo => 'Cài đặt tất cả các kỹ năng để';

  @override
  String installRepositorySkills(String repository, int count) {
    return 'Cài đặt tất cả kỹ năng $repository ($count)';
  }

  @override
  String installSkillTo(String skill) {
    return 'Cài đặt $skill vào';
  }

  @override
  String get availableInAllProjects => 'Tất cả dự án';

  @override
  String get availableInSelectedProjects => 'Dự án đã chọn';

  @override
  String get usedBy => 'Dành cho Agent';

  @override
  String get backToTargets => 'Quay lại mục tiêu';

  @override
  String get stayHere => 'Ở lại đây';

  @override
  String get viewInLibrary => 'Xem trong Thư viện';

  @override
  String planCreateCount(int count) {
    return 'tạo $count';
  }

  @override
  String planSkipCount(int count) {
    return 'bỏ qua $count';
  }

  @override
  String planReplaceCount(int count) {
    return '$count thay thế';
  }

  @override
  String planConflictCount(int count) {
    return 'xung đột $count';
  }

  @override
  String planRiskCount(int count) {
    return 'Đã chặn rủi ro $count';
  }

  @override
  String get refreshInstallationPlan => 'Áp dụng Nghị quyết';

  @override
  String get replaceVersionConflict =>
      'Thay thế phiên bản đã cài đặt tại mục tiêu này';

  @override
  String get replaceSkillIdCollision =>
      'Thay thế ID kỹ năng khác tại mục tiêu này';

  @override
  String get replaceLocalModification =>
      'Loại bỏ Sửa đổi cục bộ và thay thế mục tiêu này';

  @override
  String get sharedTargetConflict =>
      'Đường dẫn này được chia sẻ bởi các mục tiêu Agent khác';

  @override
  String sharedTargetConflictDescription(String agents) {
    return 'Quay lại ma trận đích và chọn mọi Tác nhân bị ảnh hưởng trước khi thay thế: $agents';
  }

  @override
  String get replaceConflictingTarget => 'Thay thế mục tiêu xung đột';

  @override
  String get confirmHighRiskArtifact => 'Xác nhận hiện vật có nguy cơ cao';

  @override
  String get confirmCriticalRiskArtifact =>
      'Xác nhận ghi đè rủi ro nghiêm trọng';

  @override
  String get confirmRiskForSelectedTargets =>
      'Tôi đã xem lại các tệp giả tạo và chấp nhận rủi ro này cho các mục tiêu đã chọn';

  @override
  String get criticalRiskBlocked => 'Cài đặt có nguy cơ nghiêm trọng bị chặn';

  @override
  String get criticalRiskOverrideDisabled =>
      'Bật ghi đè rủi ro nghiêm trọng rõ ràng trong Cài đặt trước khi kế hoạch này có thể tiếp tục.';

  @override
  String get workspaceManifestChanges =>
      'Các thay đổi của Bản kê khai vùng làm việc';

  @override
  String get noWorkspaceManifestChanges =>
      'Không có tệp kê khai không gian làm việc nào sẽ thay đổi.';

  @override
  String lockVersionChange(String from, String to) {
    return '$from → $to';
  }

  @override
  String get notPresent => 'không có mặt';

  @override
  String get planActionCreate => 'Tạo';

  @override
  String get planActionReplace => 'Thay thế';

  @override
  String get planActionSkip => 'Bỏ qua';

  @override
  String get planActionConflict => 'Xung đột';

  @override
  String get planActionBlockedByRisk => 'Bị chặn bởi rủi ro';

  @override
  String installationResultSummary(int succeeded, int failed) {
    return 'Đã cài đặt mục tiêu $succeeded, $failed không thành công';
  }

  @override
  String get installationProgressTitle => 'Đang tiến hành cài đặt';

  @override
  String installationProgressSummary(int finished, int total) {
    return 'Đã hoàn thành $finished trong số $total mục tiêu';
  }

  @override
  String get targetWaiting => 'Đang chờ';

  @override
  String get targetRunning => 'Đang cài đặt';

  @override
  String retryFailedTargets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Thử lại $count mục tiêu bị lỗi',
      one: 'Thử lại 1 mục tiêu bị lỗi',
    );
    return '$_temp0';
  }

  @override
  String get updatePlanTitle => 'Chọn mục tiêu để cập nhật';

  @override
  String get updatePlanDescription =>
      'Chọn mục tiêu cài đặt chính xác. Agent và dự án không được chọn vẫn không thay đổi.';

  @override
  String updateTargetsSelected(int selected, int available) {
    return 'Đã chọn $selected trong số $available mục tiêu có thể cập nhật';
  }

  @override
  String updateVersionChange(String fromVersion, String toVersion) {
    return '$fromVersion → $toVersion';
  }

  @override
  String sourceReference(String reference) {
    return 'Nguồn tham khảo: $reference';
  }

  @override
  String get fixedVersionTarget =>
      'Đã ghim - không có tài liệu tham khảo có thể di chuyển';

  @override
  String get currentVersionTarget => 'Cập nhật';

  @override
  String get updateCheckTargetFailed => 'Kiểm tra cập nhật không thành công';

  @override
  String get reconcileWorkspaceManifestTarget =>
      'Sửa chữa bảng kê khai không gian làm việc';

  @override
  String get updateSelectedTargets => 'Cập nhật các mục tiêu đã chọn';

  @override
  String get updateProgressTitle => 'Cập nhật mục tiêu';

  @override
  String get updateResultsTitle => 'Cập nhật kết quả';

  @override
  String updateProgressSummary(int finished, int total) {
    return 'Đã hoàn thành $finished trong số $total mục tiêu';
  }

  @override
  String retryFailedUpdates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Thử lại $count bản cập nhật bị lỗi',
      one: 'Thử lại 1 bản cập nhật bị lỗi',
    );
    return '$_temp0';
  }

  @override
  String get noUpdateableTargets =>
      'Không có mục tiêu được chọn nào có bản cập nhật sẵn có.';

  @override
  String get closeUpdatePlan => 'Đóng';

  @override
  String get targetSucceeded => 'Đã cài đặt';

  @override
  String get targetSkipped => 'Đã bỏ qua';

  @override
  String get targetConflict => 'Xung đột';

  @override
  String get targetFailed => 'thất bại';

  @override
  String get targetFailureRetryable =>
      'Vị trí này không thể thay đổi. Bạn có thể thử lại.';

  @override
  String get targetFailureNeedsAttention =>
      'Vị trí này cần bạn chú ý trước khi thử lại.';

  @override
  String get installationTargetFailureMessage =>
      'Không có gì thay đổi ở vị trí này. Kiểm tra xem thư mục có sẵn không và thử lại.';

  @override
  String get workspacePersistenceFailureMessage =>
      'Không có gì thay đổi vì SkillsGo không thể lưu cài đặt dự án. Kiểm tra xem thư mục dự án có thể ghi được không và thử lại.';

  @override
  String get installationStateChangedMessage =>
      'Vị trí này đã thay đổi trong khi bạn đang xem xét nó. Xem lại trạng thái mới nhất trước khi thử lại.';

  @override
  String get updateTargetFailureMessage =>
      'Không thể cập nhật vị trí này. Các vị trí khác không bị ảnh hưởng nên bạn chỉ có thể thử lại vị trí này.';

  @override
  String get managementTargetFailureMessage =>
      'Hành động này không thể hoàn tất ở đây. Các vị trí khác không bị ảnh hưởng nên bạn chỉ có thể thử lại vị trí này.';

  @override
  String get technicalDetails => 'Chi tiết kỹ thuật';

  @override
  String get targetPathExists => 'Một mặt hàng khác đã tồn tại ở vị trí này.';

  @override
  String get targetBlockedByRisk =>
      'Cài đặt an toàn hiện tại của bạn đã chặn cài đặt tại vị trí này.';

  @override
  String get targetInstallFailed =>
      'Không thể cài đặt kỹ năng này ở vị trí này.';

  @override
  String get targetWorkspaceUpdateFailed =>
      'Kỹ năng đã được cài đặt nhưng không thể cập nhật cài đặt dự án.';

  @override
  String get installationPlanFailed => 'Kế hoạch cài đặt không thể tiếp tục';

  @override
  String get installationFailed => 'Không thể hoàn tất cài đặt';

  @override
  String get localSource => 'Nguồn địa phương';

  @override
  String get noDescriptionAvailable => 'Không có mô tả nào';

  @override
  String moreCoverage(int count) {
    return '+$count địa điểm khác';
  }

  @override
  String get batchTakeoverAction => 'Quản lý các kỹ năng hiện có';

  @override
  String batchTakeoverActionCount(int count) {
    return 'Quản lý ($count)';
  }

  @override
  String get batchTakeoverChecking => 'Kiểm tra các kỹ năng hiện có…';

  @override
  String get batchTakeoverRetry => 'Kiểm tra lại kỹ năng quản lý';

  @override
  String batchTakeoverEligibleCount(int count) {
    return '$count có thể được quản lý';
  }

  @override
  String get batchTakeoverPending => 'Bổ sung kỹ năng quản lý…';

  @override
  String get batchTakeoverTitle => 'Quản lý các kỹ năng hiện có với SkillsGo?';

  @override
  String get batchTakeoverDescription =>
      'SkillsGo sẽ thêm hồ sơ quản lý cục bộ mà không cần di chuyển, ghi đè hoặc tải lên tệp kỹ năng. Các mục không được hỗ trợ hoặc thay đổi sẽ bị bỏ qua.';

  @override
  String get batchTakeoverStoryTitle =>
      'Biến các kỹ năng rải rác thành một Thư viện rõ ràng';

  @override
  String batchTakeoverStoryDescription(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kỹ năng hiện có',
      one: '1 kỹ năng hiện có',
    );
    return 'SkillsGo đã tìm thấy $_temp0 mà nó có thể quản lý ở vị trí này.';
  }

  @override
  String get batchTakeoverBeforeSemantics =>
      'Trước khi quản lý, không rõ các kỹ năng hiện có được cài đặt ở đâu, liệu chúng có hiện hành hay không, cách khôi phục chúng hoặc liệu các dự án có sử dụng cùng một phiên bản hay không.';

  @override
  String get batchTakeoverPainLocation => 'Vị trí cài đặt không xác định';

  @override
  String get batchTakeoverPainFreshness => 'Trạng thái cập nhật không xác định';

  @override
  String get batchTakeoverPainRecovery => 'Không phục hồi được khi bị hỏng';

  @override
  String get batchTakeoverPainVersionDrift =>
      'Các phiên bản khác nhau giữa các dự án';

  @override
  String get batchTakeoverFolderTitle => 'Kỹ năng hiện có';

  @override
  String get batchTakeoverFolderSubtitle => 'Trạng thái không rõ ràng';

  @override
  String get batchTakeoverAfterLabel => 'SAU';

  @override
  String get batchTakeoverAfterTitle => 'Một thư viện rõ ràng';

  @override
  String get batchTakeoverLibraryTitle => 'Thư viện SkillsGo';

  @override
  String get batchTakeoverBenefitLocation => 'Xóa vị trí';

  @override
  String get batchTakeoverBenefitFreshness => 'Cập nhật hiển thị';

  @override
  String get batchTakeoverBenefitRecovery => 'Phục hồi dễ dàng';

  @override
  String get batchTakeoverBenefitVersions => 'Phiên bản rõ ràng';

  @override
  String get batchTakeoverManagedSection => 'Được quản lý bởi SkillsGo';

  @override
  String get batchTakeoverPendingSection => 'Đang chờ xử lý';

  @override
  String batchTakeoverItemManaged(String name) {
    return '$name do SkillsGo quản lý';
  }

  @override
  String batchTakeoverItemSkipped(String name) {
    return 'Không thể thêm $name vào quản lý';
  }

  @override
  String batchTakeoverItemPending(String name) {
    return '$name đang chờ được quản lý';
  }

  @override
  String batchTakeoverAfterSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kỹ năng',
      one: '1 kỹ năng là',
    );
    return 'Sau khi quản lý, $_temp0 được sắp xếp trong một Thư viện với trạng thái được quản lý rõ ràng.';
  }

  @override
  String batchTakeoverMoreSkills(int count) {
    return '+$count khác';
  }

  @override
  String get batchTakeoverTransitionSemantics =>
      'Thêm những kỹ năng hiện có này vào quản lý SkillsGo.';

  @override
  String get batchTakeoverTransitionLabel => 'TỔ CHỨC';

  @override
  String get batchTakeoverStatusTitle => 'Tình trạng quản lý';

  @override
  String get batchTakeoverStatusManaged => 'Được quản lý';

  @override
  String get batchTakeoverStatusProgress => 'Tổ chức';

  @override
  String get batchTakeoverStatusSkipped => 'Đã bỏ qua';

  @override
  String get batchTakeoverStatusFilesStay =>
      'Các tệp kỹ năng vẫn ở vị trí ban đầu';

  @override
  String get batchTakeoverBoardSemantics =>
      'Các kỹ năng được sắp xếp thành các hàng hoàn chỉnh và được SkillsGo ghi lại mà không cần di chuyển tập tin của chúng.';

  @override
  String get batchTakeoverBoardComplete => 'TẤT CẢ RÕ RÀNG';

  @override
  String get batchTakeoverBoardPartial => 'HOÀN THÀNH';

  @override
  String get batchTakeoverStatusTotal => 'Tổng cộng';

  @override
  String get batchTakeoverQueueComplete => 'Không có kỹ năng đang chờ đợi';

  @override
  String get batchTakeoverQueueWaiting =>
      'Kỹ năng sẽ chuyển đến đây sau khi xác minh';

  @override
  String get batchTakeoverNextLabel => 'TIẾP THEO';

  @override
  String batchTakeoverFillerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count khối tổ chức SkillsGo',
      one: '1 khối tổ chức SkillsGo',
    );
    return '$_temp0 hoàn thành các hàng cuối cùng';
  }

  @override
  String get batchTakeoverPreservation =>
      'Các tệp, đường dẫn và quy trình làm việc hiện tại của bạn vẫn giữ nguyên vị trí của chúng. SkillsGo chỉ hoàn thành bản ghi quản lý cục bộ của mình.';

  @override
  String get batchTakeoverLaterHint =>
      'Nếu bỏ qua, bạn có thể sử dụng Quản lý các kỹ năng hiện có từ Thư viện bất cứ lúc nào.';

  @override
  String get batchTakeoverSkip => 'Không phải bây giờ';

  @override
  String get batchTakeoverConfirm => 'Thêm vào quản lý';

  @override
  String get batchTakeoverExecutionRetry => 'Thử lại';

  @override
  String get batchTakeoverResultTitle => 'Kỹ năng bổ sung vào quản lý';

  @override
  String batchTakeoverSummary(int takenOver, int skipped) {
    return 'Đã thêm kỹ năng $takenOver vào quản lý, $skipped bị bỏ qua.';
  }

  @override
  String get batchTakeoverClose => 'Đóng';

  @override
  String get installMoreTargets => 'Cài đặt ở nhiều vị trí hơn';

  @override
  String get exportLocalSkill => 'Xuất khẩu';

  @override
  String get exportLocalSkillDescription =>
      'Xuất Kỹ năng cục bộ này dưới dạng kho lưu trữ ZIP di động.';

  @override
  String get detailInstalls => 'Số lượt cài đặt';

  @override
  String get detailRepository => 'Kho lưu trữ';

  @override
  String get detailStars => 'Ngôi sao';

  @override
  String get detailUpdated => 'Đã cập nhật';

  @override
  String get detailArchiveSize => 'Kích thước ZIP';

  @override
  String get pathLabel => 'Đường dẫn dự án';

  @override
  String get copyProjectPath => 'Sao chép đường dẫn dự án';

  @override
  String get projectPathCopied => 'Đã sao chép đường dẫn dự án';

  @override
  String get onboardingWelcomeTitle => 'Chào mừng đến với SkillsGo';

  @override
  String get onboardingWelcomeDescription =>
      'Khám phá, cài đặt và quản lý Kỹ năng trên các Agent và dự án của bạn.';

  @override
  String get onboardingDetectedAgents => 'Agent đã phát hiện';

  @override
  String get onboardingNoAgents =>
      'Không phát hiện thấy Tác nhân đã cài đặt nào. Bạn vẫn có thể tiếp tục.';

  @override
  String get onboardingNext => 'Tiếp theo';

  @override
  String get onboardingProjectsTitle => 'Thêm dự án của bạn';

  @override
  String get onboardingProjectsDescription =>
      'Chọn các dự án bạn muốn SkillsGo quản lý.';

  @override
  String get onboardingAddProject => 'Thêm ngay bây giờ';

  @override
  String get onboardingAddProjectLater => 'hoặc muộn hơn';

  @override
  String get onboardingStartUsing => 'Bắt đầu sử dụng SkillsGo';

  @override
  String get onboardingBack => 'Quay lại';

  @override
  String get restartOnboardingTitle => 'Giới thiệu';

  @override
  String get restartOnboardingDescription =>
      'Xem lại hướng dẫn khởi chạy lần đầu mà không xóa dữ liệu dự án, cài đặt hoặc Kỹ năng.';

  @override
  String get restartOnboardingAction => 'Khởi động lại quá trình giới thiệu';

  @override
  String get restartOnboardingFailed =>
      'SkillsGo không thể khởi động lại quá trình giới thiệu.';

  @override
  String get libraryRefreshSettingsTitle => 'Làm mới Thư viện cục bộ';

  @override
  String get libraryRefreshSettingsDescription =>
      'Quét lại các Kỹ năng đã cài đặt, Dự án đã thêm, Agent và các Kỹ năng bên ngoài có thể được quản lý. Điều này không cài đặt, cập nhật hoặc xóa bất cứ điều gì.';

  @override
  String get libraryRefreshSettingsAction => 'Làm mới thư viện';

  @override
  String get libraryRefreshSettingsPending => 'Đang làm mới thư viện…';

  @override
  String get libraryRefreshSettingsSuccess => 'Thư viện cục bộ được làm mới.';

  @override
  String get libraryRefreshSettingsFailed =>
      'SkillsGo không thể làm mới Thư viện cục bộ.';

  @override
  String get onboardingProjectError =>
      'SkillsGo không thể thêm dự án từ thư mục này.';

  @override
  String get onboardingProjectsLoadError =>
      'SkillsGo không thể tải các dự án đã thêm của bạn.';

  @override
  String get onboardingStartupError => 'SkillsGo không thể tải thiết lập.';

  @override
  String get onboardingStateError =>
      'SkillsGo không thể lưu tiến trình thiết lập của bạn. Hãy thử lại.';

  @override
  String get onboardingCliErrorTitle => 'SkillsGo CLI cần được quan tâm';

  @override
  String get onboardingCliErrorDescription =>
      'Hãy sửa CLI đi kèm rồi thử lại để tiếp tục.';
}
