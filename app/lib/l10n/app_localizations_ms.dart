// ignore_for_file: text_direction_code_point_in_literal, text_direction_code_point_in_comment

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Malay (`ms`).
class AppLocalizationsMs extends AppLocalizations {
  AppLocalizationsMs([String locale = 'ms']) : super(locale);

  @override
  String get discover => 'Temui';

  @override
  String get discoverSkills => 'Ia bagus untuk mengetahui sedikit lagi.';

  @override
  String get library => 'Perpustakaan';

  @override
  String get settings => 'tetapan';

  @override
  String get openSettings => 'Buka Tetapan';

  @override
  String get cliNeedsAttention =>
      'Komponen SkillsGo yang diperlukan memerlukan perhatian.';

  @override
  String get cliMissingBundled =>
      'Komponen SkillsGo yang diperlukan tiada atau tidak boleh dimulakan. Pasang semula SkillsGo untuk memulihkannya.';

  @override
  String get cliDamagedBundled =>
      'Komponen SkillsGo yang diperlukan telah rosak. Pasang semula SkillsGo untuk memulihkannya.';

  @override
  String get cliIncompatibleBundled =>
      'Komponen SkillsGo yang diperlukan tidak sepadan dengan versi apl ini. Kemas kini atau pasang semula SkillsGo.';

  @override
  String get officialIndex => 'Hab SkillsGo';

  @override
  String get discoverTitle => 'Cari kemahiran untuk langkah seterusnya.';

  @override
  String get skillsLeaderboard => 'Ia bagus untuk mengetahui sedikit lagi.';

  @override
  String searchResultsFor(String query) {
    return 'Keputusan untuk “$query”';
  }

  @override
  String get searchSkills => 'Kemahiran carian atau tampal pautan Git…';

  @override
  String get search => 'Cari';

  @override
  String get ranking => 'Kedudukan';

  @override
  String get trending => 'Trending';

  @override
  String get hot => 'panas';

  @override
  String get discoverNavigation => 'Temui navigasi';

  @override
  String get allTimeRanking => 'Kedudukan sepanjang masa';

  @override
  String get trendingNow => 'Sohor kini dalam 24 jam yang lalu';

  @override
  String get hotNow => 'Panas sekarang';

  @override
  String get allTimeDescription =>
      'Kemahiran Awam dipesan mengikut pemasangan yang diterima sepanjang masa.';

  @override
  String get trendingDescription =>
      'Kemahiran Awam dipesan mengikut pemasangan yang diterima semasa tetingkap 24 jam terkini.';

  @override
  String get hotDescription =>
      'Kemahiran Awam dipesan mengikut halaju dan perubahan pemasangan jangka pendek.';

  @override
  String get offlineTitle => 'Tidak dapat menyambung ke SkillsGo';

  @override
  String get offlineMessage =>
      'Semak sambungan internet anda dan cuba lagi. Jika anda menggunakan proksi atau alamat perkhidmatan tersuai, semaknya dalam Tetapan.';

  @override
  String get searchFailedTitle => 'Carian mengalami masalah';

  @override
  String get validationTitle => 'Semak apa yang anda masukkan';

  @override
  String get validationMessage =>
      'SkillsGo tidak dapat menggunakan permintaan ini. Semak perkara yang anda masukkan dan cuba lagi.';

  @override
  String get serverTitle => 'Perkhidmatan tidak tersedia buat sementara waktu';

  @override
  String get serverMessage =>
      'SkillsGo tidak dapat melengkapkan permintaan ini sekarang. Cuba lagi sebentar lagi.';

  @override
  String get timeoutTitle => 'Ini mengambil masa terlalu lama';

  @override
  String get timeoutMessage =>
      'Perkhidmatan tidak bertindak balas dalam masa. Semak sambungan anda atau cuba lagi.';

  @override
  String get invalidResponseTitle => 'SkillsGo memerlukan kemas kini';

  @override
  String get invalidResponseMessage =>
      'Respons ini tidak boleh dibaca oleh versi SkillsGo anda. Kemas kini apl, kemudian cuba lagi.';

  @override
  String get invalidLocalDataTitle =>
      'Tidak dapat membaca kemahiran yang dipasang';

  @override
  String get invalidLocalDataMessage =>
      'Sesetengah maklumat pemasangan tempatan rosak atau tidak serasi. Kemas kini atau pasang semula SkillsGo, kemudian cuba lagi.';

  @override
  String get tryAgain => 'Cuba lagi';

  @override
  String get searchEmptyTitle => 'Cari, jangan tatal.';

  @override
  String get searchEmptyMessage =>
      'Masukkan keupayaan, sumber atau tugasan untuk mencari kemahiran awam.';

  @override
  String get noSkillsTitle => 'Tiada kemahiran ditemui';

  @override
  String get noSkillsMessage => 'Cuba frasa yang lebih luas atau semak ejaan.';

  @override
  String get focusSearch => 'Fokus carian';

  @override
  String get skillsFromLink => 'Kemahiran dari pautan ini';

  @override
  String skillCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kemahiran',
      one: '1 kemahiran',
    );
    return '$_temp0';
  }

  @override
  String sourceResultsSummary(String source, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kemahiran daripada $source',
      one: '1 kemahiran daripada $source',
    );
    return '$_temp0';
  }

  @override
  String get sourceSearchEmptyTitle => 'Pautan ini sedia untuk diperiksa';

  @override
  String sourceSearchEmptyMessage(String source) {
    return '$source tiada dalam hasil carian semasa. SkillsGo boleh memeriksa pautan terus dalam langkah seterusnya.';
  }

  @override
  String get inspectSource => 'Lihat kemahiran dalam pautan ini';

  @override
  String get collectionEmptyTitle => 'Tiada Kemahiran dalam koleksi ini';

  @override
  String get collectionEmptyMessage =>
      'Belum ada apa-apa di sini. Cuba lagi selepas lebih banyak aktiviti pemasangan.';

  @override
  String get loadMore => 'Muatkan lagi';

  @override
  String get install => 'Pasang';

  @override
  String get installAll => 'Pasang semua kemahiran';

  @override
  String get latestCommit => 'Komitmen terkini';

  @override
  String get installToMoreTargets => 'Pasang di Lebih Banyak Lokasi';

  @override
  String localTargets(int count) {
    return '$count sasaran tempatan';
  }

  @override
  String allTimeMetric(String count) {
    return '$count pemasangan sepanjang masa';
  }

  @override
  String trendingMetric(String count) {
    return '$count pemasangan / 24j';
  }

  @override
  String hotMetric(String value, String change) {
    return '$value jam ini · $change';
  }

  @override
  String get trustUnverified => 'Tidak disahkan';

  @override
  String get trustCommunityVerified => 'Komuniti disahkan';

  @override
  String get trustPublisherVerified => 'Penerbit disahkan';

  @override
  String get trustOfficial => 'rasmi';

  @override
  String get trustWarned => 'Diberi amaran';

  @override
  String get trustDelisted => 'dinyahsenarai';

  @override
  String get riskUnknown => 'Risiko tidak diketahui';

  @override
  String get riskLow => 'Risiko rendah';

  @override
  String get riskMedium => 'Risiko sederhana';

  @override
  String get riskHigh => 'berisiko tinggi';

  @override
  String get riskCritical => 'Risiko kritikal';

  @override
  String openSkill(String name) {
    return 'Buka $name';
  }

  @override
  String installs(String count) {
    return '$count pemasangan';
  }

  @override
  String get detailFailedTitle => 'Tidak dapat memuatkan Kemahiran ini';

  @override
  String get detailLoading => 'Memuatkan butiran Kemahiran yang boleh diaudit';

  @override
  String get artifactUnavailableTitle => 'Artifak tidak tersedia';

  @override
  String get artifactUnavailableMessage =>
      'Versi ini tidak tersedia sekarang. Cuba lagi atau pilih versi lain.';

  @override
  String get detailInvalidTitle => 'Metadata artifak tidak disokong';

  @override
  String get detailInvalidMessage =>
      'Beberapa butiran untuk kemahiran ini tidak lengkap atau tidak boleh dibaca. Kemas kini SkillsGo, kemudian cuba lagi.';

  @override
  String get instructionsTab => 'Arahan';

  @override
  String get manifestTab => 'Manifest';

  @override
  String immutableVersionLabel(String version) {
    return 'Tidak boleh ubah $version';
  }

  @override
  String commitIdentity(String sha) {
    return 'Komit $sha';
  }

  @override
  String treeIdentity(String sha) {
    return 'Pokok $sha';
  }

  @override
  String contentIdentity(String digest) {
    return 'Kandungan $digest';
  }

  @override
  String get trustDoesNotProveSafety =>
      'Amanah penerbit mengesahkan pemilikan atau penyelenggaraan; ia tidak memperakui keselamatan artifak. Risiko dinilai secara berasingan untuk versi tidak berubah ini.';

  @override
  String get knownInstallationTargets => 'Sasaran pemasangan yang diketahui';

  @override
  String get installationRange => 'Skop yang dipasang';

  @override
  String get targetDetails => 'Tunjukkan butiran sasaran';

  @override
  String get hideTargetDetails => 'Sembunyikan butiran sasaran';

  @override
  String installedVersionLabel(String version) {
    return 'Versi $version';
  }

  @override
  String targetSummary(String scope, String agent, String version) {
    return '$scope / $agent · $version';
  }

  @override
  String get projectScope => 'Projek';

  @override
  String get fileContentUnavailable => 'Pratonton binari atau tidak tersedia';

  @override
  String get fileContentTruncated =>
      'Pratonton dipenggal oleh had keselamatan Hub.';

  @override
  String get retry => 'Cuba semula';

  @override
  String get backToSearch => 'Kembali ke carian';

  @override
  String get installForCodex => 'Pasang untuk Codex';

  @override
  String get cliNotDetected => 'kemahiran (tidak dikesan)';

  @override
  String get snapshotFiles => 'Fail syot kilat';

  @override
  String get globalCodex => 'Global · Codex';

  @override
  String get yourLibrary => 'Apa yang anda tahu semuanya ada di sini.';

  @override
  String get libraryNavigation => 'Navigasi perpustakaan';

  @override
  String get all => 'Semua';

  @override
  String get allSkills => 'Semua Kemahiran';

  @override
  String get updatesOnly => 'Kemas kini';

  @override
  String get allAgents => 'Semua Agen';

  @override
  String get allProjects => 'Semua Projek';

  @override
  String get specificProject => 'Projek';

  @override
  String get userScope => 'Global';

  @override
  String get addProject => 'Tambah Projek';

  @override
  String get relocateProject => 'Berpindah';

  @override
  String get removeFromList => 'Alih keluar daripada Senarai';

  @override
  String removeProjectTitle(String name) {
    return 'Alih keluar $name daripada SkillsGo?';
  }

  @override
  String get removeProjectDescription =>
      'Hanya rujukan Apl akan dialih keluar. SkillsGo tidak akan menukar atau memadam sebarang fail dalam direktori ini.';

  @override
  String projectRailUnavailable(String name) {
    return '$name — tidak tersedia';
  }

  @override
  String get emptyProjectTitle => 'Belum ada Kemahiran';

  @override
  String get browseSkills => 'Kemahiran Layari';

  @override
  String get projectMissingTitle => 'Direktori projek tiada';

  @override
  String get projectMissingMessage =>
      'Direktori mungkin telah berpindah atau volumnya mungkin di luar talian. Letakkan semula atau alih keluar hanya rujukan Aplnya.';

  @override
  String get projectPermissionTitle => 'Kebenaran projek diperlukan';

  @override
  String get projectPermissionMessage =>
      'SkillsGo tidak boleh memeriksa akar yang dipilih ini. Berikan akses dengan memindahkannya melalui pemilih direktori.';

  @override
  String get projectInaccessibleTitle => 'Direktori projek tidak boleh diakses';

  @override
  String get projectInaccessibleMessage =>
      'SkillsGo menyimpan rujukan projek ini. Semak laluan atau kelantangan, kemudian letakkannya semula.';

  @override
  String get checking => 'Menyemak…';

  @override
  String get checkUpdates => 'Semak kemas kini';

  @override
  String get refresh => 'Segarkan semula';

  @override
  String get libraryUnavailable => 'Perpustakaan tidak tersedia';

  @override
  String get libraryEmpty => 'Tiada kemahiran dipasang lagi';

  @override
  String get libraryEmptyMessage =>
      'Pasang Kemahiran daripada Discover dan ia akan dipaparkan di sini.';

  @override
  String get searchLibrary => 'Cari kemahiran yang dipasang';

  @override
  String get libraryNoMatches => 'Tiada Kemahiran yang sepadan';

  @override
  String get libraryNoMatchesMessage =>
      'Cuba nama, sumber, Ejen, projek atau versi lain.';

  @override
  String agentsSummary(int count) {
    return '$count Ejen';
  }

  @override
  String projectsSummary(int count) {
    return '$count projek';
  }

  @override
  String versionsSummary(int count) {
    return 'Versi $count.';
  }

  @override
  String get hubManaged => 'Hab diuruskan';

  @override
  String get localManaged => 'Diurus tempatan';

  @override
  String get externalInstallation => 'Pemasangan luaran';

  @override
  String get readOnly => 'Baca sahaja';

  @override
  String get unversioned => 'Tidak versi';

  @override
  String get supportingFiles => 'Fail sokongan';

  @override
  String get versionDivergence => 'Perbezaan versi';

  @override
  String get healthHealthy => 'Sihat';

  @override
  String get healthMissing => 'Sasaran hilang';

  @override
  String get healthReplaced => 'Sasaran diganti';

  @override
  String get healthLocalModification => 'Pengubahsuaian Tempatan';

  @override
  String get healthUnreadable => 'Sasaran tidak boleh dibaca';

  @override
  String get healthUndeclared => 'Tidak diisytiharkan';

  @override
  String get healthWorkspaceUnreadable =>
      'Keadaan ruang kerja tidak boleh dibaca';

  @override
  String get healthLockMismatch => 'Kunci tidak sepadan';

  @override
  String get healthUnexpectedPath => 'Laluan sasaran yang tidak dijangka';

  @override
  String get modeSymlink => 'Symlink';

  @override
  String get modeCopy => 'salin';

  @override
  String get modeExternal => 'Luaran';

  @override
  String get notLinked => 'TIDAK BERKAITAN';

  @override
  String get update => 'Kemas kini';

  @override
  String get backToLibrary => 'Kembali ke Perpustakaan';

  @override
  String get remove => 'Alih keluar';

  @override
  String get manageTargets => 'Urus skop';

  @override
  String skillsSelected(int count) {
    return '$count dipilih';
  }

  @override
  String get clearSelection => 'Kosongkan pilihan';

  @override
  String get selectCurrentResults => 'Pilih hasil semasa';

  @override
  String get clearCurrentResultSelection => 'Kosongkan pemilihan hasil semasa';

  @override
  String get manageTargetsTitle => 'Uruskan sasaran pemasangan';

  @override
  String get manageTargetsDescription =>
      'Pilih tindakan yang tepat untuk setiap sasaran. Sasaran yang tidak dipilih tidak akan berubah.';

  @override
  String targetActionsSelected(int selected, int total) {
    return '$selected daripada $total sasaran dipilih';
  }

  @override
  String get repairTarget => 'baiki';

  @override
  String get confirmRemoveTarget => 'Sahkan alih keluar';

  @override
  String get applyTargetActions => 'Gunakan tindakan yang dipilih';

  @override
  String get managementProgressTitle => 'Mengaplikasikan tindakan sasaran';

  @override
  String get managementResultsTitle => 'Hasil tindakan sasaran';

  @override
  String managementResultSummary(int succeeded, int failed) {
    return '$succeeded berjaya, $failed gagal';
  }

  @override
  String get workspaceOwnershipChanges =>
      'Tindakan projek yang dipilih akan mengemas kini SkillsGo.mod dan SkillsGo.sum.';

  @override
  String get targetContentPreserved =>
      'Kandungan sasaran semasa akan dikekalkan.';

  @override
  String get localReadFailed => 'Tidak boleh membaca Kemahiran ini';

  @override
  String get localReadFailedMessage =>
      'SkillsGo tidak dapat membaca kemahiran yang dipasang ini. Semak sama ada foldernya tersedia dan boleh diakses, kemudian cuba lagi.';

  @override
  String get localConfiguration => 'TETAPAN SkillsGo';

  @override
  String get settingsNavigation => 'Navigasi tetapan';

  @override
  String get general => 'Peribadikan';

  @override
  String get agents => 'ejen';

  @override
  String get hub => 'Hab';

  @override
  String get installationPolicy => 'Dasar Pemasangan';

  @override
  String get storage => 'Penyimpanan';

  @override
  String get colorScheme => 'Skim Warna';

  @override
  String get about => 'Tentang';

  @override
  String get colorSchemeInspectorTitle => 'Peranan warna Bahan Dijana';

  @override
  String get skillsColorTokensTitle => 'Warna semantik SkillsGo';

  @override
  String get skillsColorTokensDescription =>
      'Warna produk yang dibina daripada Pasir Radix dan disusun dengan semantik Primer, dengan Folder sebagai hierarki spatial khusus.';

  @override
  String get colorSchemeInspectorDescription =>
      'Pratonton setiap token ColorScheme yang tidak ditamatkan yang dijana daripada benih semasa. Klik warna untuk menyalin nilai HEXnya.';

  @override
  String get colorSchemePairPreview => 'Pasangan semantik';

  @override
  String get colorSchemePairPreviewDescription =>
      'Peranan latar depan dan latar belakang diberikan bersama untuk mendedahkan kontras dan hierarki.';

  @override
  String get colorSchemeComponentPreview => 'Pratonton komponen';

  @override
  String get colorSchemeComponentPreviewDescription =>
      'Kawalan Bahan Perwakilan yang diberikan dengan skema pratonton tepat ini.';

  @override
  String get colorSchemeSampleTitle => 'Tajuk kad kemahiran';

  @override
  String get colorSchemeSampleBody =>
      'Salinan sekunder menggunakan onSurfaceVariant.';

  @override
  String get colorSchemeCopied => 'disalin';

  @override
  String get colorSchemeSampleGlyphs => 'Aa 123';

  @override
  String get colorSchemeGroupPrimary => 'utama';

  @override
  String get colorSchemeGroupPrimaryDescription =>
      'Penekanan utama, bekas dan peranan aksen tetap.';

  @override
  String get colorSchemeGroupSecondary => 'Menengah';

  @override
  String get colorSchemeGroupSecondaryDescription =>
      'Penekanan sokongan dan peranan sekunder tetap.';

  @override
  String get colorSchemeGroupTertiary => 'Tertiari';

  @override
  String get colorSchemeGroupTertiaryDescription =>
      'Aksen kontras dan peranan tertiari tetap.';

  @override
  String get colorSchemeGroupSurface => 'Permukaan';

  @override
  String get colorSchemeGroupSurfaceDescription =>
      'Halaman, bekas, ketinggian dan hierarki latar depan.';

  @override
  String get colorSchemeGroupUtility => 'Rangka & Utiliti';

  @override
  String get colorSchemeGroupUtilityDescription =>
      'Sempadan, bayang-bayang, scrim, dan permukaan songsang.';

  @override
  String get colorSchemeGroupError => 'ralat';

  @override
  String get colorSchemeGroupErrorDescription =>
      'Tindakan ralat, mesej dan bekas.';

  @override
  String get colorSchemeUsagePrimary =>
      'Tindakan utama, fokus dan aksen penekanan tinggi.';

  @override
  String get colorSchemeUsageSecondary =>
      'Tindakan sokongan dan aksen penekanan sederhana.';

  @override
  String get colorSchemeUsageTertiary =>
      'Aksen kontras yang melengkapi primer dan sekunder.';

  @override
  String colorSchemeUsageContentOn(String token) {
    return 'Teks dan ikon dipaparkan pada $token.';
  }

  @override
  String colorSchemeUsageContainer(String family) {
    return 'Bekas penekanan rendah $family untuk pemilihan dan aksen.';
  }

  @override
  String colorSchemeUsageFixed(String family) {
    return 'Bekas tetap $family bebas kecerahan.';
  }

  @override
  String colorSchemeUsageFixedDim(String family) {
    return 'Bekas tetap $family bebas kecerahan malap.';
  }

  @override
  String colorSchemeUsageFixedContent(String family) {
    return 'Kandungan penekanan tinggi pada bekas $family tetap.';
  }

  @override
  String colorSchemeUsageFixedVariantContent(String family) {
    return 'Kandungan penekanan yang lebih rendah pada bekas $family tetap.';
  }

  @override
  String get colorSchemeUsageSurface =>
      'Halaman asas dan permukaan wilayah besar.';

  @override
  String get colorSchemeUsageSurfaceDim =>
      'Permukaan dasar malap digunakan pada ton permukaan paling gelap.';

  @override
  String get colorSchemeUsageSurfaceBright =>
      'Permukaan asas terang digunakan pada ton permukaan paling terang.';

  @override
  String colorSchemeUsageSurfaceElevation(String level) {
    return 'Ketinggian bekas permukaan $level.';
  }

  @override
  String get colorSchemeElevationLowest => 'paling rendah';

  @override
  String get colorSchemeElevationLow => 'rendah';

  @override
  String get colorSchemeElevationDefault => 'lalai';

  @override
  String get colorSchemeElevationHigh => 'tinggi';

  @override
  String get colorSchemeElevationHighest => 'tertinggi';

  @override
  String get colorSchemeUsageOnSurface =>
      'Teks dan ikon utama dipaparkan pada permukaan.';

  @override
  String get colorSchemeUsageOnSurfaceVariant =>
      'Teks sekunder, label dan ikon lemah pada permukaan.';

  @override
  String get colorSchemeUsageSurfaceTint =>
      'Warna ketinggian bahan diperoleh daripada primer.';

  @override
  String get colorSchemeUsageOutline =>
      'Sempadan yang menonjol dan garis besar komponen yang difokuskan.';

  @override
  String get colorSchemeUsageOutlineVariant =>
      'Sempadan halus, pemisah dan garis besar penekanan rendah.';

  @override
  String get colorSchemeUsageShadow =>
      'Warna bayang-bayang jatuh untuk permukaan tinggi.';

  @override
  String get colorSchemeUsageScrim =>
      'Tindanan modal digunakan untuk tidak menekankan kandungan latar belakang.';

  @override
  String get colorSchemeUsageInverseSurface =>
      'Permukaan dengan cahaya terbalik dan penekanan gelap.';

  @override
  String get colorSchemeUsageInversePrimary =>
      'Aksen utama dipaparkan pada permukaan songsang.';

  @override
  String get colorSchemeUsageError =>
      'Tindakan ralat, status dan maklum balas penekanan tinggi.';

  @override
  String get save => 'Jimat';

  @override
  String get advancedSettings => 'Maju';

  @override
  String get remindersSettings => 'Peringatan';

  @override
  String get remindersSettingsTitle => 'Tetapan peringatan';

  @override
  String get remindersSettingsDescription =>
      'Pilih peringatan yang akan diterima.';

  @override
  String get updateReminderTitle => 'Kemas kini peringatan';

  @override
  String get updateReminderDescription =>
      'Semak kemas kini apabila Perpustakaan dibuka.';

  @override
  String get securityReminderTitle => 'Makluman berisiko tinggi';

  @override
  String get securityReminderDescription =>
      'Beritahu anda tentang risiko Tinggi atau Kritikal baharu dalam kemahiran yang dipasang.';

  @override
  String availableUpdatesReminder(int count) {
    return 'Kemahiran yang dipasang $count mempunyai kemas kini';
  }

  @override
  String get openAvailableUpdates =>
      'Buka paparan kemas kini tersedia untuk menyemak dan mengemas kininya.';

  @override
  String securityAdvisoriesReminder(int count) {
    return 'Kemahiran yang dipasang $count memerlukan semakan keselamatan';
  }

  @override
  String get reviewInstalledSkills =>
      'Semak maklumat risiko mereka sebelum menggunakan atau mengemas kininya.';

  @override
  String get generalSettingsTitle => 'Jadikan SkillsGo milik anda';

  @override
  String get generalSettingsDescription =>
      'Antara muka mengikut bahasa sistem anda, kebolehcapaian dan pilihan gerakan.';

  @override
  String get agentsSettingsTitle => 'Masa jalan ejen';

  @override
  String get hubSettingsTitle => 'Asal Hab';

  @override
  String get hubSettingsDescription =>
      'Gunakan Hab rasmi atau asal hos sendiri HTTP(S) yang melaksanakan protokol SkillsGo yang sama.';

  @override
  String get testConnection => 'Uji sambungan';

  @override
  String get saveOrigin => 'Simpan Asal';

  @override
  String get resetDefault => 'Tetapkan semula kepada lalai';

  @override
  String get connectionReady => 'Sambungan sedia';

  @override
  String get connectionFailed => 'Sambungan gagal';

  @override
  String get hubInvalidOrigin =>
      'Masukkan Asal HTTP(S) yang sah tanpa bukti kelayakan, pertanyaan atau serpihan.';

  @override
  String hubHttpFailure(int status) {
    return 'Hab mengembalikan HTTP $status. Semak konfigurasi Asal dan pelayan.';
  }

  @override
  String get hubInvalidProtocol =>
      'Pelayan tidak mengembalikan protokol carian SkillsGo Hub.';

  @override
  String get hubInvalidJson => 'Hab mengembalikan JSON yang tidak sah.';

  @override
  String get hubConnectionFailure =>
      'Tidak dapat sampai ke Hab. Semak konfigurasi Asal, rangkaian, proksi dan TLS.';

  @override
  String get hubConnectionTimeout =>
      'Sambungan Hub tamat masa. Semak rangkaian atau cuba lagi.';

  @override
  String get riskPolicyTitle => 'Polisi risiko peribadi';

  @override
  String get riskPolicyDescription =>
      'Peraturan keselamatan digunakan apabila anda memasang atau mengemas kini kemahiran.';

  @override
  String get confirmHighRisk => 'Memerlukan pengesahan untuk Risiko Tinggi';

  @override
  String get confirmHighRiskDescription =>
      'Artifak berisiko tinggi sentiasa memerlukan pengesahan tambahan sebelum pemasangan.';

  @override
  String get allowCriticalOverride =>
      'Benarkan penggantian risiko Kritikal yang jelas';

  @override
  String get allowCriticalOverrideDescription =>
      'Artifak berisiko kritikal kekal disekat secara lalai. Dayakan ini hanya untuk mendedahkan penggantian manual yang berasingan.';

  @override
  String get storageSettingsTitle => 'Storan beralamat kandungan';

  @override
  String get storageHealthy => 'Boleh dibaca';

  @override
  String get storageNotInitialized => 'Tidak dimulakan';

  @override
  String get storageUnavailable => 'Tidak tersedia';

  @override
  String get storagePathUnavailable =>
      'Laluan storan belum tersedia sehingga diagnostik CLI selesai.';

  @override
  String get storageHealthyDescription =>
      'CLI boleh membaca storan tanpa mengubah kandungannya.';

  @override
  String get storageNotInitializedDescription =>
      'Storan belum wujud lagi dan tidak dicipta oleh semakan ini.';

  @override
  String get storageUnavailableDescription =>
      'CLI tidak boleh membaca storan. Semak kebenaran dan direktori induknya.';

  @override
  String get storageInvalidResponse =>
      'CLI terbina dalam mengembalikan respons diagnostik yang tidak disokong.';

  @override
  String get aboutSettingsTitle => 'Keserasian produk';

  @override
  String get appVersion => 'Versi apl';

  @override
  String get cliVersion => 'Versi CLI terbina dalam';

  @override
  String get compatible => 'serasi';

  @override
  String get hubOriginSaved => 'Hub Origin disimpan dan digunakan.';

  @override
  String get policySaved => 'Dasar pemasangan disimpan.';

  @override
  String get officialCli => 'SkillsGo CLI';

  @override
  String get ready => 'SEDIA';

  @override
  String get unknown => 'TIDAK DIKENALI';

  @override
  String get missing => 'HILANG';

  @override
  String get incompatible => 'TIDAK SESUAI';

  @override
  String get detecting => 'Mengesan…';

  @override
  String get customCliPath => 'Laluan boleh laku tersuai';

  @override
  String get saveAndDetect => 'Simpan & kesan';

  @override
  String get detectAgain => 'Kesan semula';

  @override
  String get agentInstalled => 'Dipasang';

  @override
  String get agentSupported => 'Disokong';

  @override
  String agentCatalogSummary(int installed, int supported) {
    return '$installed dipasang · $supported disokong';
  }

  @override
  String installedAgentsTitle(int count) {
    return 'Dipasang · $count';
  }

  @override
  String notInstalledAgentsTitle(int count) {
    return 'Tidak dipasang · $count';
  }

  @override
  String get notInstalledAgentsDescription =>
      'Disokong oleh SkillsGo, tetapi tidak dikesan pada Mac ini.';

  @override
  String agentDiscoveryRoots(String paths) {
    return 'Laluan pemuatan kemahiran: $paths';
  }

  @override
  String get agentInspectionFailed =>
      'Data pengesanan ejen tidak tersedia. Jalankan pengesanan sekali lagi.';

  @override
  String get noInstalledAgentsTitle => 'Tiada Ejen dipasang dikesan';

  @override
  String get noInstalledAgentsMessage =>
      'Anda boleh terus menyemak imbas Kemahiran ini, tetapi tiada sasaran pemasangan lagi. Pasang Ejen yang disokong, kemudian jalankan pengesanan sekali lagi.';

  @override
  String get clearCustomPath => 'Kosongkan laluan tersuai';

  @override
  String get privacyProvenance => 'Privasi & asal';

  @override
  String get privacySummary =>
      'Carian anda tidak disimpan dan SkillsGo tidak menyimpan log arahan.';

  @override
  String get language => 'Bahasa';

  @override
  String get personalizationTheme => 'Tema';

  @override
  String get folderColorTheme => 'Warna tema';

  @override
  String get folderColorThemeDescription =>
      'Pilih warna yang anda suka. SkillsGo akan membina palet antara muka yang diselaraskan di sekelilingnya.';

  @override
  String get brandNameNeteaseCloudMusic => 'Muzik Awan NetEase';

  @override
  String get brandNameRaspberryPi => 'Raspberry Pi';

  @override
  String get brandNameChinaEasternAirlines =>
      'Syarikat Penerbangan China Eastern';

  @override
  String get brandNameNvidia => 'NVIDIA';

  @override
  String get brandNameTaobao => 'Taobao';

  @override
  String get brandNameBitcoin => 'Bitcoin';

  @override
  String get appearanceMode => 'Mod';

  @override
  String get appearanceModeDescription =>
      'Ikuti penampilan sistem anda atau sentiasa gunakan tema terang atau gelap.';

  @override
  String get followSystem => 'Sistem';

  @override
  String get lightMode => 'Cahaya';

  @override
  String get darkMode => 'Gelap';

  @override
  String get wallpaper => 'Kertas dinding';

  @override
  String get wallpaperDescription =>
      'Pilih latar belakang cakerawala. Pilihan anda muncul serta-merta di belakang Folder.';

  @override
  String get wallpaperSun => 'Matahari';

  @override
  String get wallpaperMercury => 'Merkuri';

  @override
  String get wallpaperVenus => 'Zuhrah';

  @override
  String get wallpaperEarth => 'Bumi';

  @override
  String get wallpaperMars => 'Marikh';

  @override
  String get wallpaperJupiter => 'Musytari';

  @override
  String get wallpaperSaturn => 'Zuhal';

  @override
  String get wallpaperUranus => 'Uranus';

  @override
  String get wallpaperNeptune => 'Neptun';

  @override
  String get wallpaperPluto => 'Pluto';

  @override
  String get wallpaperMoon => 'Bulan';

  @override
  String folderThemeChoice(String theme) {
    return '$theme Tema folder';
  }

  @override
  String get privacyAffiliation =>
      'Telemetri pemasangan tanpa nama dikawal oleh tetapan SkillsGo. SkillsGo tidak bergabung dengan OpenAI atau Codex.';

  @override
  String get commandCompleted => 'Perintah selesai';

  @override
  String get commandFailed => 'Perintah gagal';

  @override
  String commandExit(int code) {
    return 'Keluar $code · kembangkan untuk log sesi ini';
  }

  @override
  String get command => 'Perintah';

  @override
  String get cancel => 'Batal';

  @override
  String get updateUnknown => 'TIDAK DIKENALI';

  @override
  String get updateChecking => 'MENYEMAK';

  @override
  String get upToDate => 'TERKINI';

  @override
  String get updateAvailable => 'KEMASKINI';

  @override
  String get updateUnavailable => 'TIDAK TERSEDIA';

  @override
  String get updateCheckFailed => 'SEMAK GAGAL';

  @override
  String get installSkill => 'Pasang Kemahiran';

  @override
  String get installLocationTitle => 'Tetapkan lokasi pemasangan';

  @override
  String get userLevel => 'Tahap Pengguna';

  @override
  String get projectLevel => 'Tahap Projek';

  @override
  String get projects => 'Projek';

  @override
  String get loading => 'Memuatkan…';

  @override
  String get repositoryParsing => 'Menghuraikan Repositori…';

  @override
  String userInstallSummary(int agents) {
    return 'Tersedia kepada Ejen $agents di peringkat pengguna';
  }

  @override
  String projectInstallSummary(int projects, int agents) {
    return '$projects projek · $agents Ejen';
  }

  @override
  String get installationResults => 'Hasil pemasangan';

  @override
  String get installationInProgress => 'Pemasangan sedang dijalankan';

  @override
  String get installationSucceeded => 'Pemasangan selesai';

  @override
  String get installationSucceededMessage =>
      'Skill kini tersedia di lokasi yang dipilih.';

  @override
  String get projectUnavailable => 'Projek tidak tersedia';

  @override
  String get installedCell => 'Dipasang';

  @override
  String get unsupportedCell => 'Tidak tersedia';

  @override
  String get confirmInstall => 'Sahkan Pemasangan';

  @override
  String installAllRepositorySkills(int count) {
    return 'Pasang semua kemahiran repositori ($count)';
  }

  @override
  String get installAllSkillsTo => 'Pasang semua kemahiran untuk';

  @override
  String installRepositorySkills(String repository, int count) {
    return 'Pasang semua kemahiran $repository ($count)';
  }

  @override
  String installSkillTo(String skill) {
    return 'Pasang $skill ke';
  }

  @override
  String get availableInAllProjects => 'Semua projek';

  @override
  String get availableInSelectedProjects => 'Projek terpilih';

  @override
  String get usedBy => 'Untuk Ejen';

  @override
  String get backToTargets => 'Kembali ke Sasaran';

  @override
  String get stayHere => 'Tinggal Di Sini';

  @override
  String get viewInLibrary => 'Lihat dalam Perpustakaan';

  @override
  String planCreateCount(int count) {
    return '$count buat';
  }

  @override
  String planSkipCount(int count) {
    return '$count langkau';
  }

  @override
  String planReplaceCount(int count) {
    return '$count ganti';
  }

  @override
  String planConflictCount(int count) {
    return '$count konflik';
  }

  @override
  String planRiskCount(int count) {
    return '$count risiko disekat';
  }

  @override
  String get refreshInstallationPlan => 'Gunakan Resolusi';

  @override
  String get replaceVersionConflict =>
      'Gantikan versi yang dipasang pada sasaran ini';

  @override
  String get replaceSkillIdCollision =>
      'Gantikan ID Kemahiran yang berbeza pada sasaran ini';

  @override
  String get replaceLocalModification =>
      'Buang Pengubahsuaian Tempatan dan gantikan sasaran ini';

  @override
  String get sharedTargetConflict =>
      'Laluan ini dikongsi oleh sasaran Ejen lain';

  @override
  String sharedTargetConflictDescription(String agents) {
    return 'Kembali ke matriks sasaran dan pilih setiap Ejen yang terjejas sebelum menggantikan: $agents';
  }

  @override
  String get replaceConflictingTarget => 'Gantikan sasaran yang bercanggah';

  @override
  String get confirmHighRiskArtifact => 'Pengesahan artifak berisiko tinggi';

  @override
  String get confirmCriticalRiskArtifact =>
      'Pengesahan menimpa risiko kritikal';

  @override
  String get confirmRiskForSelectedTargets =>
      'Saya menyemak fail artifak dan menerima risiko ini untuk sasaran yang dipilih';

  @override
  String get criticalRiskBlocked => 'Pemasangan berisiko kritikal disekat';

  @override
  String get criticalRiskOverrideDisabled =>
      'Dayakan penggantian Risiko Kritikal yang eksplisit dalam Tetapan sebelum pelan ini boleh diteruskan.';

  @override
  String get workspaceManifestChanges => 'Perubahan Manifes Ruang Kerja';

  @override
  String get noWorkspaceManifestChanges =>
      'Tiada fail Manifes Ruang Kerja akan berubah.';

  @override
  String lockVersionChange(String from, String to) {
    return '$from → $to';
  }

  @override
  String get notPresent => 'tidak hadir';

  @override
  String get planActionCreate => 'Buat';

  @override
  String get planActionReplace => 'Gantikan';

  @override
  String get planActionSkip => 'Langkau';

  @override
  String get planActionConflict => 'Konflik';

  @override
  String get planActionBlockedByRisk => 'Disekat oleh risiko';

  @override
  String installationResultSummary(int succeeded, int failed) {
    return '$succeeded sasaran dipasang, $failed gagal';
  }

  @override
  String get installationProgressTitle => 'Pemasangan sedang dijalankan';

  @override
  String installationProgressSummary(int finished, int total) {
    return '$finished daripada $total sasaran selesai';
  }

  @override
  String get targetWaiting => 'Menunggu';

  @override
  String get targetRunning => 'Memasang';

  @override
  String retryFailedTargets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cuba semula $count sasaran yang gagal',
      one: 'Cuba semula 1 sasaran yang gagal',
    );
    return '$_temp0';
  }

  @override
  String get updatePlanTitle => 'Pilih sasaran untuk dikemas kini';

  @override
  String get updatePlanDescription =>
      'Pilih Sasaran Pemasangan yang tepat. Ejen dan projek yang tidak dipilih kekal tidak berubah.';

  @override
  String updateTargetsSelected(int selected, int available) {
    return '$selected daripada $available sasaran boleh dikemas kini dipilih';
  }

  @override
  String updateVersionChange(String fromVersion, String toVersion) {
    return '$fromVersion → $toVersion';
  }

  @override
  String sourceReference(String reference) {
    return 'Rujukan sumber: $reference';
  }

  @override
  String get fixedVersionTarget => 'Disemat — tiada rujukan boleh alih';

  @override
  String get currentVersionTarget => 'Terkini';

  @override
  String get updateCheckTargetFailed => 'Semakan kemas kini gagal';

  @override
  String get reconcileWorkspaceManifestTarget => 'Membaiki manifes ruang kerja';

  @override
  String get updateSelectedTargets => 'Kemas kini sasaran yang dipilih';

  @override
  String get updateProgressTitle => 'Mengemas kini sasaran';

  @override
  String get updateResultsTitle => 'Kemas kini keputusan';

  @override
  String updateProgressSummary(int finished, int total) {
    return '$finished daripada $total sasaran selesai';
  }

  @override
  String retryFailedUpdates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cuba semula $count kemas kini yang gagal',
      one: 'Cuba semula 1 kemas kini yang gagal',
    );
    return '$_temp0';
  }

  @override
  String get noUpdateableTargets =>
      'Tiada sasaran yang dipilih mempunyai kemas kini yang tersedia.';

  @override
  String get closeUpdatePlan => 'tutup';

  @override
  String get targetSucceeded => 'Dipasang';

  @override
  String get targetSkipped => 'Dilangkau';

  @override
  String get targetConflict => 'Konflik';

  @override
  String get targetFailed => 'gagal';

  @override
  String get targetFailureRetryable =>
      'Lokasi ini tidak boleh ditukar. Anda boleh mencuba lagi.';

  @override
  String get targetFailureNeedsAttention =>
      'Lokasi ini memerlukan perhatian anda sebelum anda mencuba lagi.';

  @override
  String get installationTargetFailureMessage =>
      'Tiada apa-apa yang diubah di lokasi ini. Semak sama ada folder itu tersedia dan cuba lagi.';

  @override
  String get workspacePersistenceFailureMessage =>
      'Tiada apa-apa yang diubah kerana SkillsGo tidak dapat menyimpan tetapan projek. Semak sama ada folder projek boleh ditulis dan cuba lagi.';

  @override
  String get installationStateChangedMessage =>
      'Lokasi ini berubah semasa anda menyemaknya. Semak keadaan terkini sebelum mencuba lagi.';

  @override
  String get updateTargetFailureMessage =>
      'Lokasi ini tidak dapat dikemas kini. Lokasi lain tidak terjejas, jadi anda boleh mencuba semula yang ini sahaja.';

  @override
  String get managementTargetFailureMessage =>
      'Tindakan ini tidak dapat diselesaikan di sini. Lokasi lain tidak terjejas, jadi anda boleh mencuba semula yang ini sahaja.';

  @override
  String get technicalDetails => 'Butiran teknikal';

  @override
  String get targetPathExists => 'Item lain sudah wujud di lokasi ini.';

  @override
  String get targetBlockedByRisk =>
      'Tetapan keselamatan semasa anda menyekat pemasangan di lokasi ini.';

  @override
  String get targetInstallFailed =>
      'Kemahiran tidak dapat dipasang di lokasi ini.';

  @override
  String get targetWorkspaceUpdateFailed =>
      'Kemahiran telah dipasang, tetapi tetapan projek tidak dapat dikemas kini.';

  @override
  String get installationPlanFailed =>
      'Pelan pemasangan tidak dapat diteruskan';

  @override
  String get installationFailed => 'Pemasangan tidak dapat diselesaikan';

  @override
  String get localSource => 'Sumber tempatan';

  @override
  String get noDescriptionAvailable => 'Tiada penerangan tersedia';

  @override
  String moreCoverage(int count) {
    return '+$count lagi lokasi';
  }

  @override
  String get batchTakeoverAction => 'Mengurus kemahiran sedia ada';

  @override
  String batchTakeoverActionCount(int count) {
    return 'Urus ($count)';
  }

  @override
  String get batchTakeoverChecking => 'Menyemak kemahiran sedia ada…';

  @override
  String get batchTakeoverRetry => 'Semak kemahiran terurus sekali lagi';

  @override
  String batchTakeoverEligibleCount(int count) {
    return '$count boleh diurus';
  }

  @override
  String get batchTakeoverPending => 'Menambah kemahiran kepada pengurusan…';

  @override
  String get batchTakeoverTitle => 'Urus kemahiran sedia ada dengan SkillsGo?';

  @override
  String get batchTakeoverDescription =>
      'SkillsGo akan menambah rekod pengurusan tempatan tanpa mengalihkan, menulis ganti atau memuat naik fail kemahiran. Item yang tidak disokong atau ditukar akan dilangkau.';

  @override
  String get batchTakeoverStoryTitle =>
      'Ubah kemahiran bertaburan menjadi satu Perpustakaan yang jelas';

  @override
  String batchTakeoverStoryDescription(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kemahiran sedia ada',
      one: '1 kemahiran sedia ada',
    );
    return 'SkillsGo menemui $_temp0 ia boleh mengurus di lokasi ini.';
  }

  @override
  String get batchTakeoverBeforeSemantics =>
      'Sebelum pengurusan, tidak jelas di mana kemahiran sedia ada dipasang, sama ada kemahiran semasa, cara memulihkannya atau sama ada projek menggunakan versi yang sama.';

  @override
  String get batchTakeoverPainLocation => 'Lokasi pemasangan tidak diketahui';

  @override
  String get batchTakeoverPainFreshness => 'Status kemas kini tidak diketahui';

  @override
  String get batchTakeoverPainRecovery => 'Tiada pemulihan apabila patah';

  @override
  String get batchTakeoverPainVersionDrift => 'Versi berbeza merentas projek';

  @override
  String get batchTakeoverFolderTitle => 'Kemahiran Sedia Ada';

  @override
  String get batchTakeoverFolderSubtitle => 'Status tidak jelas';

  @override
  String get batchTakeoverAfterLabel => 'SELEPAS';

  @override
  String get batchTakeoverAfterTitle => 'Satu Perpustakaan yang jelas';

  @override
  String get batchTakeoverLibraryTitle => 'Perpustakaan SkillsGo';

  @override
  String get batchTakeoverBenefitLocation => 'Kosongkan lokasi';

  @override
  String get batchTakeoverBenefitFreshness => 'Kemas kini kelihatan';

  @override
  String get batchTakeoverBenefitRecovery => 'Pemulihan yang mudah';

  @override
  String get batchTakeoverBenefitVersions => 'Versi jelas';

  @override
  String get batchTakeoverManagedSection => 'Diuruskan oleh SkillsGo';

  @override
  String get batchTakeoverPendingSection => 'Belum selesai';

  @override
  String batchTakeoverItemManaged(String name) {
    return '$name diurus oleh SkillsGo';
  }

  @override
  String batchTakeoverItemSkipped(String name) {
    return '$name tidak dapat ditambahkan pada pengurusan';
  }

  @override
  String batchTakeoverItemPending(String name) {
    return '$name sedang menunggu untuk diurus';
  }

  @override
  String batchTakeoverAfterSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kemahiran',
      one: '1 kemahiran ialah',
    );
    return 'Selepas pengurusan, $_temp0 disusun dalam satu Perpustakaan dengan status terurus yang jelas.';
  }

  @override
  String batchTakeoverMoreSkills(int count) {
    return '+$count lagi';
  }

  @override
  String get batchTakeoverTransitionSemantics =>
      'Tambahkan kemahiran sedia ada ini pada pengurusan SkillsGo.';

  @override
  String get batchTakeoverTransitionLabel => 'ATURKAN';

  @override
  String get batchTakeoverStatusTitle => 'Status pengurusan';

  @override
  String get batchTakeoverStatusManaged => 'Terurus';

  @override
  String get batchTakeoverStatusProgress => 'Menganjur';

  @override
  String get batchTakeoverStatusSkipped => 'Dilangkau';

  @override
  String get batchTakeoverStatusFilesStay =>
      'Fail kemahiran kekal di lokasi asalnya';

  @override
  String get batchTakeoverBoardSemantics =>
      'Kemahiran disusun ke dalam baris yang lengkap dan direkodkan oleh SkillsGo tanpa mengalihkan failnya.';

  @override
  String get batchTakeoverBoardComplete => 'SEMUA JELAS';

  @override
  String get batchTakeoverBoardPartial => 'LENGKAP';

  @override
  String get batchTakeoverStatusTotal => 'Jumlah';

  @override
  String get batchTakeoverQueueComplete => 'Tiada kemahiran menunggu';

  @override
  String get batchTakeoverQueueWaiting =>
      'Kemahiran akan berpindah ke sini selepas pengesahan';

  @override
  String get batchTakeoverNextLabel => 'SETERUSNYA';

  @override
  String batchTakeoverFillerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count blok penganjur SkillsGo',
      one: '1 blok penganjur SkillsGo',
    );
    return '$_temp0 lengkapkan baris terakhir';
  }

  @override
  String get batchTakeoverPreservation =>
      'Fail, laluan dan aliran kerja semasa anda kekal di tempatnya. SkillsGo hanya melengkapkan rekod pengurusan tempatannya.';

  @override
  String get batchTakeoverLaterHint =>
      'Jika anda melangkau, anda boleh menggunakan Urus kemahiran sedia ada daripada Perpustakaan pada bila-bila masa.';

  @override
  String get batchTakeoverSkip => 'bukan sekarang';

  @override
  String get batchTakeoverConfirm => 'Tambahkan pada pengurusan';

  @override
  String get batchTakeoverExecutionRetry => 'Cuba semula';

  @override
  String get batchTakeoverResultTitle => 'Kemahiran ditambah kepada pengurusan';

  @override
  String batchTakeoverSummary(int takenOver, int skipped) {
    return 'Kemahiran $takenOver ditambahkan pada pengurusan, $skipped dilangkau.';
  }

  @override
  String get batchTakeoverClose => 'tutup';

  @override
  String get installMoreTargets => 'Pasang di lebih banyak lokasi';

  @override
  String get exportLocalSkill => 'Eksport';

  @override
  String get exportLocalSkillDescription =>
      'Eksport Kemahiran Tempatan ini sebagai arkib ZIP mudah alih.';

  @override
  String get detailInstalls => 'Pemasangan';

  @override
  String get detailRepository => 'Repositori';

  @override
  String get detailStars => 'Bintang';

  @override
  String get detailUpdated => 'dikemas kini';

  @override
  String get detailArchiveSize => 'Saiz ZIP';

  @override
  String get pathLabel => 'Laluan projek';

  @override
  String get copyProjectPath => 'Salin laluan projek';

  @override
  String get projectPathCopied => 'Laluan projek disalin';

  @override
  String get onboardingWelcomeTitle => 'Selamat datang ke SkillsGo';

  @override
  String get onboardingWelcomeDescription =>
      'Temui, pasang dan urus Kemahiran merentas Ejen dan projek anda.';

  @override
  String get onboardingDetectedAgents => 'Ejen Dikesan';

  @override
  String get onboardingNoAgents =>
      'Tiada Ejen dipasang dikesan. Anda masih boleh meneruskan.';

  @override
  String get onboardingNext => 'Seterusnya';

  @override
  String get onboardingProjectsTitle => 'Tambah projek anda';

  @override
  String get onboardingProjectsDescription =>
      'Pilih projek yang anda mahu SkillsGo uruskan.';

  @override
  String get onboardingAddProject => 'Tambah sekarang';

  @override
  String get onboardingAddProjectLater => 'atau kemudian';

  @override
  String get onboardingStartUsing => 'Mula Menggunakan SkillsGo';

  @override
  String get onboardingBack => 'belakang';

  @override
  String get restartOnboardingTitle => 'Onboarding';

  @override
  String get restartOnboardingDescription =>
      'Lihat panduan pelancaran pertama sekali lagi tanpa mengalih keluar projek, tetapan atau data Kemahiran.';

  @override
  String get restartOnboardingAction => 'Mulakan semula Onboarding';

  @override
  String get restartOnboardingFailed =>
      'SkillsGo tidak dapat memulakan semula Onboarding.';

  @override
  String get libraryRefreshSettingsTitle => 'Muat semula Perpustakaan tempatan';

  @override
  String get libraryRefreshSettingsDescription =>
      'Imbas semula Kemahiran yang dipasang, Projek Ditambah, Ejen dan Kemahiran luaran yang boleh diurus. Ini tidak memasang, mengemas kini atau mengalih keluar apa-apa.';

  @override
  String get libraryRefreshSettingsAction => 'Muat semula Perpustakaan';

  @override
  String get libraryRefreshSettingsPending => 'Menyegarkan Pustaka…';

  @override
  String get libraryRefreshSettingsSuccess =>
      'Perpustakaan Tempatan disegarkan.';

  @override
  String get libraryRefreshSettingsFailed =>
      'SkillsGo tidak dapat memuat semula Perpustakaan tempatan.';

  @override
  String get onboardingProjectError =>
      'SkillsGo tidak dapat menambah projek daripada direktori ini.';

  @override
  String get onboardingProjectsLoadError =>
      'SkillsGo tidak dapat memuatkan projek tambahan anda.';

  @override
  String get onboardingStartupError =>
      'SkillsGo tidak dapat memuatkan persediaan.';

  @override
  String get onboardingStateError =>
      'SkillsGo tidak dapat menyimpan kemajuan persediaan anda. Cuba lagi.';

  @override
  String get onboardingCliErrorTitle => 'SkillsGo CLI memerlukan perhatian';

  @override
  String get onboardingCliErrorDescription =>
      'Baiki CLI terbina dalam, kemudian cuba semula untuk meneruskan.';
}
