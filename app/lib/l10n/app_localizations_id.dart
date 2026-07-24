// ignore_for_file: text_direction_code_point_in_literal, text_direction_code_point_in_comment

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get discover => 'Temukan';

  @override
  String get discoverSkills => 'Senang rasanya mengetahui lebih banyak.';

  @override
  String get library => 'Perpustakaan';

  @override
  String get settings => 'Pengaturan';

  @override
  String get openSettings => 'Buka Pengaturan';

  @override
  String get cliNeedsAttention =>
      'Komponen SkillsGo yang diperlukan memerlukan perhatian.';

  @override
  String get cliMissingBundled =>
      'Komponen SkillsGo yang diperlukan tidak ada atau tidak dapat dimulai. Instal ulang SkillsGo untuk memulihkannya.';

  @override
  String get cliDamagedBundled =>
      'Komponen SkillsGo yang diperlukan rusak. Instal ulang SkillsGo untuk memulihkannya.';

  @override
  String get cliIncompatibleBundled =>
      'Komponen SkillsGo yang diperlukan tidak cocok dengan versi aplikasi ini. Perbarui atau instal ulang SkillsGo.';

  @override
  String get officialIndex => 'SkillsGo Hub';

  @override
  String get discoverTitle =>
      'Temukan keterampilan untuk langkah Anda selanjutnya.';

  @override
  String get skillsLeaderboard => 'Senang rasanya mengetahui lebih banyak.';

  @override
  String searchResultsFor(String query) {
    return 'Hasil untuk “$query”';
  }

  @override
  String get searchSkills => 'Cari keterampilan atau tempel tautan Git…';

  @override
  String get search => 'Cari';

  @override
  String get ranking => 'Peringkat';

  @override
  String get trending => 'Sedang tren';

  @override
  String get hot => 'Panas';

  @override
  String get discoverNavigation => 'Temukan navigasi';

  @override
  String get allTimeRanking => 'Peringkat sepanjang masa';

  @override
  String get trendingNow => 'Trending dalam 24 jam terakhir';

  @override
  String get hotNow => 'Panas saat ini';

  @override
  String get allTimeDescription =>
      'Keterampilan Publik diurutkan berdasarkan pemasangan yang diterima sepanjang waktu.';

  @override
  String get trendingDescription =>
      'Keterampilan Publik diurutkan berdasarkan pemasangan yang diterima selama jangka waktu 24 jam terakhir.';

  @override
  String get hotDescription =>
      'Keterampilan Publik diurutkan berdasarkan kecepatan dan perubahan instalasi jangka pendek.';

  @override
  String get offlineTitle => 'Tidak dapat terhubung ke SkillsGo';

  @override
  String get offlineMessage =>
      'Periksa koneksi internet Anda dan coba lagi. Jika Anda menggunakan proxy atau alamat layanan khusus, tinjau di Pengaturan.';

  @override
  String get searchFailedTitle => 'Pencarian mengalami masalah';

  @override
  String get validationTitle => 'Periksa apa yang Anda masukkan';

  @override
  String get validationMessage =>
      'SkillsGo tidak dapat menggunakan permintaan ini. Tinjau apa yang Anda masukkan dan coba lagi.';

  @override
  String get serverTitle => 'Layanan untuk sementara tidak tersedia';

  @override
  String get serverMessage =>
      'SkillsGo tidak dapat menyelesaikan permintaan ini saat ini. Coba lagi sebentar lagi.';

  @override
  String get timeoutTitle => 'Ini memakan waktu terlalu lama';

  @override
  String get timeoutMessage =>
      'Layanan tidak merespons tepat waktu. Periksa koneksi Anda atau coba lagi.';

  @override
  String get invalidResponseTitle => 'SkillsGo memerlukan pembaruan';

  @override
  String get invalidResponseMessage =>
      'Respons ini tidak dapat dibaca oleh versi SkillsGo Anda. Perbarui aplikasi, lalu coba lagi.';

  @override
  String get invalidLocalDataTitle =>
      'Tidak dapat membaca keterampilan yang terpasang';

  @override
  String get invalidLocalDataMessage =>
      'Beberapa informasi instalasi lokal rusak atau tidak kompatibel. Perbarui atau instal ulang SkillsGo, lalu coba lagi.';

  @override
  String get tryAgain => 'Coba lagi';

  @override
  String get searchEmptyTitle => 'Cari, jangan gulir.';

  @override
  String get searchEmptyMessage =>
      'Masukkan kemampuan, sumber, atau tugas untuk mencari keterampilan umum.';

  @override
  String get noSkillsTitle => 'Tidak ada keterampilan yang ditemukan';

  @override
  String get noSkillsMessage =>
      'Cobalah frasa yang lebih luas atau periksa ejaannya.';

  @override
  String get focusSearch => 'Pencarian fokus';

  @override
  String get skillsFromLink => 'Keterampilan dari tautan ini';

  @override
  String skillCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count keterampilan',
      one: '1 keterampilan',
    );
    return '$_temp0';
  }

  @override
  String sourceResultsSummary(String source, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count keterampilan dari $source',
      one: '1 keterampilan dari $source',
    );
    return '$_temp0';
  }

  @override
  String get sourceSearchEmptyTitle => 'Tautan ini siap untuk diperiksa';

  @override
  String sourceSearchEmptyMessage(String source) {
    return '$source tidak ada dalam hasil penelusuran saat ini. SkillsGo dapat memeriksa tautan secara langsung pada langkah berikutnya.';
  }

  @override
  String get inspectSource => 'Lihat keterampilan di tautan ini';

  @override
  String get collectionEmptyTitle => 'Tidak Ada Keterampilan dalam koleksi ini';

  @override
  String get collectionEmptyMessage =>
      'Belum ada apa pun di sini. Coba lagi setelah aktivitas instalasi lebih lanjut.';

  @override
  String get loadMore => 'Muat lebih banyak';

  @override
  String get install => 'Instal';

  @override
  String get installAll => 'Instal semua keterampilan';

  @override
  String get latestCommit => 'Komit terbaru';

  @override
  String get installToMoreTargets => 'Instal di Lebih Banyak Lokasi';

  @override
  String localTargets(int count) {
    return '$count target lokal';
  }

  @override
  String allTimeMetric(String count) {
    return '$count pemasangan sepanjang masa';
  }

  @override
  String trendingMetric(String count) {
    return '$count pemasangan / 24 jam';
  }

  @override
  String hotMetric(String value, String change) {
    return '$value jam ini · $change';
  }

  @override
  String get trustUnverified => 'Belum terverifikasi';

  @override
  String get trustCommunityVerified => 'Terverifikasi komunitas';

  @override
  String get trustPublisherVerified => 'Penerbit terverifikasi';

  @override
  String get trustOfficial => 'Resmi';

  @override
  String get trustWarned => 'Diperingatkan';

  @override
  String get trustDelisted => 'Dihapuskan';

  @override
  String get riskUnknown => 'Risiko tidak diketahui';

  @override
  String get riskLow => 'Risiko rendah';

  @override
  String get riskMedium => 'Risiko sedang';

  @override
  String get riskHigh => 'Risiko tinggi';

  @override
  String get riskCritical => 'Risiko kritis';

  @override
  String openSkill(String name) {
    return 'Buka $name';
  }

  @override
  String installs(String count) {
    return '$count pemasangan';
  }

  @override
  String get detailFailedTitle => 'Tidak dapat memuat Keterampilan ini';

  @override
  String get detailLoading => 'Memuat detail Keterampilan yang dapat diaudit';

  @override
  String get artifactUnavailableTitle => 'Artefak tidak tersedia';

  @override
  String get artifactUnavailableMessage =>
      'Versi ini tidak tersedia saat ini. Coba lagi atau pilih versi lain.';

  @override
  String get detailInvalidTitle => 'Metadata artefak tidak didukung';

  @override
  String get detailInvalidMessage =>
      'Beberapa detail untuk skill ini tidak lengkap atau tidak dapat dibaca. Perbarui SkillsGo, lalu coba lagi.';

  @override
  String get instructionsTab => 'instruksi';

  @override
  String get manifestTab => 'nyata';

  @override
  String immutableVersionLabel(String version) {
    return 'Tidak dapat diubah $version';
  }

  @override
  String commitIdentity(String sha) {
    return 'Lakukan $sha';
  }

  @override
  String treeIdentity(String sha) {
    return 'Pohon $sha';
  }

  @override
  String contentIdentity(String digest) {
    return 'Konten $digest';
  }

  @override
  String get trustDoesNotProveSafety =>
      'Kepercayaan penerbit memverifikasi kepemilikan atau pemeliharaan; itu tidak menyatakan keamanan artefak. Risiko dinilai secara terpisah untuk versi yang tidak dapat diubah ini.';

  @override
  String get knownInstallationTargets => 'Target instalasi yang diketahui';

  @override
  String get installationRange => 'Lingkup terpasang';

  @override
  String get targetDetails => 'Tampilkan detail target';

  @override
  String get hideTargetDetails => 'Sembunyikan detail target';

  @override
  String installedVersionLabel(String version) {
    return 'Versi $version';
  }

  @override
  String targetSummary(String scope, String agent, String version) {
    return '$scope / $agent · $version';
  }

  @override
  String get projectScope => 'Proyek';

  @override
  String get fileContentUnavailable => 'Pratinjau biner atau tidak tersedia';

  @override
  String get fileContentTruncated =>
      'Pratinjau terpotong oleh batas keamanan Hub.';

  @override
  String get retry => 'Coba lagi';

  @override
  String get backToSearch => 'Kembali ke pencarian';

  @override
  String get installForCodex => 'Instal untuk Codex';

  @override
  String get cliNotDetected => 'keterampilan (tidak terdeteksi)';

  @override
  String get snapshotFiles => 'File cuplikan';

  @override
  String get globalCodex => 'Global · Kodeks';

  @override
  String get yourLibrary => 'Yang Anda tahu semuanya ada di sini.';

  @override
  String get libraryNavigation => 'Navigasi perpustakaan';

  @override
  String get all => 'Semua';

  @override
  String get allSkills => 'Semua Keterampilan';

  @override
  String get updatesOnly => 'Pembaruan';

  @override
  String get allAgents => 'Semua Agen';

  @override
  String get allProjects => 'Semua Proyek';

  @override
  String get specificProject => 'Proyek';

  @override
  String get userScope => 'Global';

  @override
  String get addProject => 'Tambahkan Proyek';

  @override
  String get relocateProject => 'Pindah';

  @override
  String get removeFromList => 'Hapus dari Daftar';

  @override
  String removeProjectTitle(String name) {
    return 'Hapus $name dari SkillsGo?';
  }

  @override
  String get removeProjectDescription =>
      'Hanya referensi Aplikasi yang akan dihapus. SkillsGo tidak akan mengubah atau menghapus file apa pun di direktori ini.';

  @override
  String projectRailUnavailable(String name) {
    return '$name — tidak tersedia';
  }

  @override
  String get emptyProjectTitle => 'Belum ada Keterampilan';

  @override
  String get browseSkills => 'Jelajahi Keterampilan';

  @override
  String get projectMissingTitle => 'Direktori proyek tidak ada';

  @override
  String get projectMissingMessage =>
      'Direktori mungkin telah berpindah atau volumenya mungkin offline. Pindahkan atau hapus hanya referensi Aplikasinya.';

  @override
  String get projectPermissionTitle => 'Izin proyek diperlukan';

  @override
  String get projectPermissionMessage =>
      'SkillsGo tidak dapat memeriksa akar yang dipilih ini. Berikan akses dengan memindahkannya melalui pemilih direktori.';

  @override
  String get projectInaccessibleTitle => 'Direktori proyek tidak dapat diakses';

  @override
  String get projectInaccessibleMessage =>
      'SkillsGo menyimpan referensi proyek ini. Periksa jalur atau volume, lalu pindahkan lokasinya.';

  @override
  String get checking => 'Memeriksa…';

  @override
  String get checkUpdates => 'Periksa pembaruan';

  @override
  String get refresh => 'Segarkan';

  @override
  String get libraryUnavailable => 'Perpustakaan tidak tersedia';

  @override
  String get libraryEmpty => 'Belum ada keterampilan yang dipasang';

  @override
  String get libraryEmptyMessage =>
      'Instal Skill dari Discover dan itu akan muncul di sini.';

  @override
  String get searchLibrary => 'Cari keterampilan yang terpasang';

  @override
  String get libraryNoMatches => 'Tidak ada Keterampilan yang cocok';

  @override
  String get libraryNoMatchesMessage =>
      'Coba nama, sumber, Agen, proyek, atau versi lain.';

  @override
  String agentsSummary(int count) {
    return '$count Agen';
  }

  @override
  String projectsSummary(int count) {
    return 'proyek $count';
  }

  @override
  String versionsSummary(int count) {
    return 'versi $count';
  }

  @override
  String get hubManaged => 'Hub dikelola';

  @override
  String get localManaged => 'Dikelola secara lokal';

  @override
  String get externalInstallation => 'Instalasi eksternal';

  @override
  String get readOnly => 'Hanya baca';

  @override
  String get unversioned => 'Tidak berversi';

  @override
  String get supportingFiles => 'File pendukung';

  @override
  String get versionDivergence => 'Perbedaan versi';

  @override
  String get healthHealthy => 'Sehat';

  @override
  String get healthMissing => 'Sasarannya hilang';

  @override
  String get healthReplaced => 'Sasaran diganti';

  @override
  String get healthLocalModification => 'Modifikasi Lokal';

  @override
  String get healthUnreadable => 'Target tidak terbaca';

  @override
  String get healthUndeclared => 'Tidak diumumkan';

  @override
  String get healthWorkspaceUnreadable =>
      'Status ruang kerja tidak dapat dibaca';

  @override
  String get healthLockMismatch => 'Kunci ketidakcocokan';

  @override
  String get healthUnexpectedPath => 'Jalur target yang tidak terduga';

  @override
  String get modeExternal => 'Eksternal';

  @override
  String get notLinked => 'TIDAK TERKAIT';

  @override
  String get update => 'Pembaruan';

  @override
  String get backToLibrary => 'Kembali ke Perpustakaan';

  @override
  String get remove => 'Hapus';

  @override
  String get manageTargets => 'Kelola cakupan';

  @override
  String skillsSelected(int count) {
    return '$count dipilih';
  }

  @override
  String get clearSelection => 'Hapus pilihan';

  @override
  String get selectCurrentResults => 'Pilih hasil saat ini';

  @override
  String get clearCurrentResultSelection => 'Hapus pilihan hasil saat ini';

  @override
  String get manageTargetsTitle => 'Kelola target instalasi';

  @override
  String get manageTargetsDescription =>
      'Pilih tindakan yang tepat untuk setiap target. Target yang tidak dipilih tidak akan berubah.';

  @override
  String targetActionsSelected(int selected, int total) {
    return '$selected dari $total target dipilih';
  }

  @override
  String get confirmRemoveTarget => 'Konfirmasikan penghapusan';

  @override
  String get applyTargetActions => 'Terapkan tindakan yang dipilih';

  @override
  String get managementProgressTitle => 'Menerapkan tindakan yang ditargetkan';

  @override
  String get managementResultsTitle => 'Hasil tindakan yang ditargetkan';

  @override
  String managementResultSummary(int succeeded, int failed) {
    return '$succeeded berhasil, $failed gagal';
  }

  @override
  String get workspaceOwnershipChanges =>
      'Tindakan proyek yang dipilih akan memperbarui skillsgo.yaml dan skillsgo-lock.yaml.';

  @override
  String get targetContentPreserved =>
      'Konten target saat ini akan dipertahankan.';

  @override
  String get localReadFailed => 'Tidak dapat membaca Skill ini';

  @override
  String get localReadFailedMessage =>
      'SkillsGo tidak dapat membaca skill yang terpasang ini. Periksa apakah foldernya tersedia dan dapat diakses, lalu coba lagi.';

  @override
  String get localConfiguration => 'PENGATURAN KETERAMPILAN';

  @override
  String get settingsNavigation => 'Navigasi pengaturan';

  @override
  String get general => 'Personalisasi';

  @override
  String get agents => 'Agen';

  @override
  String get hub => 'Pusat';

  @override
  String get installationPolicy => 'Kebijakan Instalasi';

  @override
  String get storage => 'Penyimpanan';

  @override
  String get colorScheme => 'Skema Warna';

  @override
  String get about => 'Tentang';

  @override
  String get colorSchemeInspectorTitle =>
      'Peran warna Material yang dihasilkan';

  @override
  String get skillsColorTokensTitle => 'Warna semantik SkillsGo';

  @override
  String get skillsColorTokensDescription =>
      'Warna produk dibuat dari Radix Sand dan diatur dengan semantik Primer, dengan Folder sebagai hierarki spasial khusus.';

  @override
  String get colorSchemeInspectorDescription =>
      'Pratinjau setiap token ColorScheme yang tidak digunakan lagi yang dihasilkan dari benih saat ini. Klik warna untuk menyalin nilai HEX-nya.';

  @override
  String get colorSchemePairPreview => 'Pasangan semantik';

  @override
  String get colorSchemePairPreviewDescription =>
      'Peran latar depan dan latar belakang dirender bersama untuk memperlihatkan kontras dan hierarki.';

  @override
  String get colorSchemeComponentPreview => 'Pratinjau komponen';

  @override
  String get colorSchemeComponentPreviewDescription =>
      'Kontrol Material Representatif diberikan dengan skema pratinjau yang tepat ini.';

  @override
  String get colorSchemeSampleTitle => 'Judul kartu keterampilan';

  @override
  String get colorSchemeSampleBody =>
      'Salinan sekunder menggunakan onSurfaceVariant.';

  @override
  String get colorSchemeCopied => 'Disalin';

  @override
  String get colorSchemeSampleGlyphs => 'Aa 123';

  @override
  String get colorSchemeGroupPrimary => 'Utama';

  @override
  String get colorSchemeGroupPrimaryDescription =>
      'Penekanan primer, wadah, dan peran aksen tetap.';

  @override
  String get colorSchemeGroupSecondary => 'Sekunder';

  @override
  String get colorSchemeGroupSecondaryDescription =>
      'Mendukung penekanan dan memperbaiki peran sekunder.';

  @override
  String get colorSchemeGroupTertiary => 'Tersier';

  @override
  String get colorSchemeGroupTertiaryDescription =>
      'Aksen yang kontras dan peran tersier yang tetap.';

  @override
  String get colorSchemeGroupSurface => 'Permukaan';

  @override
  String get colorSchemeGroupSurfaceDescription =>
      'Hierarki halaman, wadah, ketinggian, dan latar depan.';

  @override
  String get colorSchemeGroupUtility => 'Garis Besar & Utilitas';

  @override
  String get colorSchemeGroupUtilityDescription =>
      'Batas, bayangan, samaran, dan permukaan terbalik.';

  @override
  String get colorSchemeGroupError => 'Kesalahan';

  @override
  String get colorSchemeGroupErrorDescription =>
      'Tindakan kesalahan, pesan, dan kontainer.';

  @override
  String get colorSchemeUsagePrimary =>
      'Tindakan utama, fokus, dan aksen penekanan tinggi.';

  @override
  String get colorSchemeUsageSecondary =>
      'Tindakan pendukung dan aksen penekanan sedang.';

  @override
  String get colorSchemeUsageTertiary =>
      'Aksen kontras yang melengkapi primer dan sekunder.';

  @override
  String colorSchemeUsageContentOn(String token) {
    return 'Teks dan ikon ditampilkan di $token.';
  }

  @override
  String colorSchemeUsageContainer(String family) {
    return 'Wadah $family dengan penekanan lebih rendah untuk pilihan dan aksen.';
  }

  @override
  String colorSchemeUsageFixed(String family) {
    return 'Kontainer $family tetap yang tidak bergantung pada kecerahan.';
  }

  @override
  String colorSchemeUsageFixedDim(String family) {
    return 'Kontainer tetap $family yang tidak tergantung kecerahan dan redup.';
  }

  @override
  String colorSchemeUsageFixedContent(String family) {
    return 'Konten dengan penekanan tinggi pada penampung $family tetap.';
  }

  @override
  String colorSchemeUsageFixedVariantContent(String family) {
    return 'Konten dengan penekanan lebih rendah pada penampung $family tetap.';
  }

  @override
  String get colorSchemeUsageSurface =>
      'Halaman dasar dan permukaan wilayah luas.';

  @override
  String get colorSchemeUsageSurfaceDim =>
      'Permukaan dasar yang diredupkan digunakan pada warna permukaan yang paling gelap.';

  @override
  String get colorSchemeUsageSurfaceBright =>
      'Permukaan dasar cerah digunakan dengan warna permukaan paling ringan.';

  @override
  String colorSchemeUsageSurfaceElevation(String level) {
    return 'Ketinggian wadah permukaan $level.';
  }

  @override
  String get colorSchemeElevationLowest => 'terendah';

  @override
  String get colorSchemeElevationLow => 'rendah';

  @override
  String get colorSchemeElevationDefault => 'bawaan';

  @override
  String get colorSchemeElevationHigh => 'tinggi';

  @override
  String get colorSchemeElevationHighest => 'tertinggi';

  @override
  String get colorSchemeUsageOnSurface =>
      'Teks dan ikon utama ditampilkan di permukaan.';

  @override
  String get colorSchemeUsageOnSurfaceVariant =>
      'Teks sekunder, label, dan ikon redup di permukaan.';

  @override
  String get colorSchemeUsageSurfaceTint =>
      'Warna elevasi material berasal dari warna primer.';

  @override
  String get colorSchemeUsageOutline =>
      'Batasan yang menonjol dan garis besar komponen yang terfokus.';

  @override
  String get colorSchemeUsageOutlineVariant =>
      'Batasan halus, pemisah, dan garis besar dengan penekanan rendah.';

  @override
  String get colorSchemeUsageShadow =>
      'Warna drop-shadow untuk permukaan yang ditinggikan.';

  @override
  String get colorSchemeUsageScrim =>
      'Modal overlay digunakan untuk menghilangkan penekanan pada konten latar belakang.';

  @override
  String get colorSchemeUsageInverseSurface =>
      'Permukaan dengan penekanan terang dan gelap terbalik.';

  @override
  String get colorSchemeUsageInversePrimary =>
      'Aksen primer ditampilkan pada permukaan terbalik.';

  @override
  String get colorSchemeUsageError =>
      'Tindakan kesalahan, status, dan umpan balik yang sangat ditekankan.';

  @override
  String get save => 'Simpan';

  @override
  String get advancedSettings => 'Lanjutan';

  @override
  String get remindersSettings => 'Pengingat';

  @override
  String get remindersSettingsTitle => 'Pengaturan pengingat';

  @override
  String get remindersSettingsDescription =>
      'Pilih pengingat mana yang akan diterima.';

  @override
  String get updateReminderTitle => 'Perbarui pengingat';

  @override
  String get updateReminderDescription =>
      'Periksa pembaruan saat Perpustakaan terbuka.';

  @override
  String get securityReminderTitle => 'Peringatan berisiko tinggi';

  @override
  String get securityReminderDescription =>
      'Memberi tahu Anda tentang risiko Tinggi atau Kritis baru dalam keterampilan yang dipasang.';

  @override
  String availableUpdatesReminder(int count) {
    return 'Keterampilan yang dipasang $count memiliki pembaruan';
  }

  @override
  String get openAvailableUpdates =>
      'Buka tampilan pembaruan yang tersedia untuk meninjau dan memperbaruinya.';

  @override
  String securityAdvisoriesReminder(int count) {
    return 'Keterampilan terpasang $count memerlukan tinjauan keamanan';
  }

  @override
  String get reviewInstalledSkills =>
      'Tinjau informasi risikonya sebelum menggunakan atau memperbaruinya.';

  @override
  String get generalSettingsTitle => 'Jadikan SkillsGo milik Anda';

  @override
  String get generalSettingsDescription =>
      'Antarmuka mengikuti bahasa sistem, aksesibilitas, dan preferensi gerakan Anda.';

  @override
  String get agentsSettingsTitle => 'Waktu proses agen';

  @override
  String get hubSettingsTitle => 'Asal Hub';

  @override
  String get hubSettingsDescription =>
      'Gunakan Hub resmi atau HTTP(S) asal yang dihosting sendiri yang mengimplementasikan protokol SkillsGo yang sama.';

  @override
  String get testConnection => 'Uji koneksi';

  @override
  String get saveOrigin => 'Simpan Asal';

  @override
  String get resetDefault => 'Atur ulang ke default';

  @override
  String get connectionReady => 'Koneksi siap';

  @override
  String get connectionFailed => 'Koneksi gagal';

  @override
  String get hubInvalidOrigin =>
      'Masukkan Asal HTTP(S) yang valid tanpa kredensial, kueri, atau fragmen.';

  @override
  String hubHttpFailure(int status) {
    return 'Hub mengembalikan HTTP $status. Periksa Asal dan konfigurasi server.';
  }

  @override
  String get hubInvalidProtocol =>
      'Server tidak mengembalikan protokol pencarian SkillsGo Hub.';

  @override
  String get hubInvalidJson => 'Hub mengembalikan JSON yang tidak valid.';

  @override
  String get hubConnectionFailure =>
      'Tidak dapat mencapai Hub. Periksa konfigurasi Asal, jaringan, proksi, dan TLS.';

  @override
  String get hubConnectionTimeout =>
      'Waktu koneksi Hub habis. Periksa jaringan atau coba lagi.';

  @override
  String get riskPolicyTitle => 'Kebijakan risiko pribadi';

  @override
  String get riskPolicyDescription =>
      'Aturan keselamatan berlaku saat Anda menginstal atau memperbarui keterampilan.';

  @override
  String get confirmHighRisk => 'Memerlukan konfirmasi untuk Risiko tinggi';

  @override
  String get confirmHighRiskDescription =>
      'Artefak berisiko tinggi selalu memerlukan konfirmasi tambahan sebelum pemasangan.';

  @override
  String get allowCriticalOverride =>
      'Izinkan penggantian risiko Kritis secara eksplisit';

  @override
  String get allowCriticalOverrideDescription =>
      'Artefak berisiko kritis tetap diblokir secara default. Aktifkan ini hanya untuk mengekspos penggantian manual yang terpisah.';

  @override
  String get storageHealthy => 'Dapat dibaca';

  @override
  String get storageNotInitialized => 'Tidak diinisialisasi';

  @override
  String get storageUnavailable => 'Tidak tersedia';

  @override
  String get storageInvalidResponse =>
      'CLI yang dibundel mengembalikan respons diagnostik yang tidak didukung.';

  @override
  String get aboutSettingsTitle => 'Kompatibilitas produk';

  @override
  String get appVersion => 'Versi aplikasi';

  @override
  String get cliVersion => 'Versi CLI yang dibundel';

  @override
  String get compatible => 'Kompatibel';

  @override
  String get hubOriginSaved => 'Hub Asal disimpan dan diterapkan.';

  @override
  String get policySaved => 'Kebijakan instalasi disimpan.';

  @override
  String get officialCli => 'SkillsGo CLI';

  @override
  String get ready => 'SIAP';

  @override
  String get unknown => 'TIDAK DIKETAHUI';

  @override
  String get missing => 'HILANG';

  @override
  String get incompatible => 'TIDAK SESUAI';

  @override
  String get detecting => 'Mendeteksi…';

  @override
  String get customCliPath => 'Jalur khusus yang dapat dieksekusi';

  @override
  String get saveAndDetect => 'Simpan & deteksi';

  @override
  String get detectAgain => 'Deteksi lagi';

  @override
  String get agentInstalled => 'Dipasang';

  @override
  String get agentSupported => 'Didukung';

  @override
  String agentCatalogSummary(int installed, int supported) {
    return '$installed terpasang · $supported didukung';
  }

  @override
  String installedAgentsTitle(int count) {
    return 'Terpasang · $count';
  }

  @override
  String notInstalledAgentsTitle(int count) {
    return 'Tidak terpasang · $count';
  }

  @override
  String get notInstalledAgentsDescription =>
      'Didukung oleh SkillsGo, tetapi tidak terdeteksi di Mac ini.';

  @override
  String agentDiscoveryRoots(String paths) {
    return 'Jalur pemuatan keterampilan: $paths';
  }

  @override
  String get agentInspectionFailed =>
      'Data deteksi agen tidak tersedia. Jalankan deteksi lagi.';

  @override
  String get noInstalledAgentsTitle =>
      'Tidak ada Agen terinstal yang terdeteksi';

  @override
  String get noInstalledAgentsMessage =>
      'Anda tetap dapat menelusuri Skill ini, tetapi belum ada target pemasangan. Instal Agent yang didukung, lalu jalankan deteksi lagi.';

  @override
  String get clearCustomPath => 'Hapus jalur khusus';

  @override
  String get privacyProvenance => 'Privasi & asal';

  @override
  String get privacySummary =>
      'Pencarian Anda tidak disimpan, dan SkillsGo tidak menyimpan log perintah.';

  @override
  String get language => 'Bahasa';

  @override
  String get personalizationTheme => 'Tema';

  @override
  String get folderColorTheme => 'Warna tema';

  @override
  String get folderColorThemeDescription =>
      'Pilih warna yang Anda suka. SkillsGo akan membangun palet antarmuka terkoordinasi di sekitarnya.';

  @override
  String get brandNameNeteaseCloudMusic => 'Musik Cloud NetEase';

  @override
  String get brandNameRaspberryPi => 'Raspberry Pi';

  @override
  String get brandNameChinaEasternAirlines => 'Maskapai China Timur';

  @override
  String get brandNameNvidia => 'NVIDIA';

  @override
  String get brandNameTaobao => 'Taobao';

  @override
  String get brandNameBitcoin => 'Bitcoin';

  @override
  String get appearanceMode => 'Modus';

  @override
  String get appearanceModeDescription =>
      'Ikuti tampilan sistem Anda, atau selalu gunakan tema terang atau gelap.';

  @override
  String get followSystem => 'Sistem';

  @override
  String get lightMode => 'Ringan';

  @override
  String get darkMode => 'Gelap';

  @override
  String get wallpaper => 'kertas dinding';

  @override
  String get wallpaperDescription =>
      'Pilih latar belakang langit. Pilihan Anda muncul tepat di belakang Folder.';

  @override
  String get wallpaperSun => 'Matahari';

  @override
  String get wallpaperMercury => 'Merkuri';

  @override
  String get wallpaperVenus => 'Venus';

  @override
  String get wallpaperEarth => 'Bumi';

  @override
  String get wallpaperMars => 'Mars';

  @override
  String get wallpaperJupiter => 'Yupiter';

  @override
  String get wallpaperSaturn => 'Saturnus';

  @override
  String get wallpaperUranus => 'Uranus';

  @override
  String get wallpaperNeptune => 'Neptunus';

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
      'Telemetri instalasi anonim dikontrol oleh pengaturan SkillsGo. SkillsGo tidak berafiliasi dengan OpenAI atau Codex.';

  @override
  String get commandCompleted => 'Perintah selesai';

  @override
  String get commandFailed => 'Perintah gagal';

  @override
  String commandExit(int code) {
    return 'Keluar dari $code · perluas log sesi ini';
  }

  @override
  String get command => 'Perintah';

  @override
  String get cancel => 'Batalkan';

  @override
  String get updateUnknown => 'TIDAK DIKETAHUI';

  @override
  String get updateChecking => 'MEMERIKSA';

  @override
  String get upToDate => 'TERBARU';

  @override
  String get updateAvailable => 'PEMBARUAN';

  @override
  String get updateUnavailable => 'TIDAK TERSEDIA';

  @override
  String get updateCheckFailed => 'PERIKSA GAGAL';

  @override
  String get installSkill => 'Instal Keterampilan';

  @override
  String get installLocationTitle => 'Tetapkan lokasi pemasangan';

  @override
  String get userLevel => 'Tingkat Pengguna';

  @override
  String get projectLevel => 'Tingkat Proyek';

  @override
  String get projects => 'Proyek';

  @override
  String get loading => 'Memuat…';

  @override
  String get repositoryParsing => 'Mengurai Repositori…';

  @override
  String userInstallSummary(int agents) {
    return 'Tersedia untuk Agen $agents di tingkat pengguna';
  }

  @override
  String projectInstallSummary(int projects, int agents) {
    return '$projects proyek · $agents Agen';
  }

  @override
  String get installationResults => 'Hasil instalasi';

  @override
  String get installationInProgress => 'Instalasi sedang berlangsung';

  @override
  String get installationSucceeded => 'Instalasi selesai';

  @override
  String get installationSucceededMessage =>
      'Keterampilan sekarang tersedia di lokasi yang dipilih.';

  @override
  String get projectUnavailable => 'Proyek tidak tersedia';

  @override
  String get installedCell => 'Dipasang';

  @override
  String get unsupportedCell => 'Tidak tersedia';

  @override
  String get confirmInstall => 'Konfirmasi Instalasi';

  @override
  String installAllRepositorySkills(int count) {
    return 'Instal semua keterampilan repositori ($count)';
  }

  @override
  String get installAllSkillsTo => 'Instal semua keterampilan untuk';

  @override
  String installRepositorySkills(String repository, int count) {
    return 'Instal semua keterampilan $repository ($count)';
  }

  @override
  String installSkillTo(String skill) {
    return 'Instal $skill ke';
  }

  @override
  String get availableInAllProjects => 'Semua proyek';

  @override
  String get availableInSelectedProjects => 'Proyek terpilih';

  @override
  String get usedBy => 'Untuk Agen';

  @override
  String get backToTargets => 'Kembali ke Target';

  @override
  String get stayHere => 'Tetap di sini';

  @override
  String get viewInLibrary => 'Lihat di Perpustakaan';

  @override
  String planCreateCount(int count) {
    return '$count buat';
  }

  @override
  String planSkipCount(int count) {
    return '$count lewati';
  }

  @override
  String planReplaceCount(int count) {
    return '$count ganti';
  }

  @override
  String planConflictCount(int count) {
    return 'konflik $count';
  }

  @override
  String planRiskCount(int count) {
    return 'Risiko $count diblokir';
  }

  @override
  String get refreshInstallationPlan => 'Terapkan Resolusi';

  @override
  String get replaceVersionConflict =>
      'Ganti versi yang diinstal pada target ini';

  @override
  String get replaceSkillIdCollision =>
      'Ganti ID Keterampilan yang berbeda pada target ini';

  @override
  String get replaceLocalModification =>
      'Buang Modifikasi Lokal dan ganti target ini';

  @override
  String get sharedTargetConflict =>
      'Jalur ini digunakan bersama oleh target Agen lainnya';

  @override
  String sharedTargetConflictDescription(String agents) {
    return 'Kembali ke matriks target dan pilih setiap Agen yang terpengaruh sebelum mengganti: $agents';
  }

  @override
  String get replaceConflictingTarget => 'Ganti target yang bertentangan';

  @override
  String get confirmHighRiskArtifact => 'Konfirmasi artefak berisiko tinggi';

  @override
  String get confirmCriticalRiskArtifact =>
      'Konfirmasi penggantian risiko kritis';

  @override
  String get confirmRiskForSelectedTargets =>
      'Saya meninjau file artefak dan menerima risiko ini untuk target yang dipilih';

  @override
  String get criticalRiskBlocked => 'Instalasi berisiko kritis diblokir';

  @override
  String get criticalRiskOverrideDisabled =>
      'Aktifkan penggantian risiko Kritis secara eksplisit di Pengaturan sebelum rencana ini dapat dilanjutkan.';

  @override
  String get workspaceManifestChanges => 'Perubahan Manifes Ruang Kerja';

  @override
  String get noWorkspaceManifestChanges =>
      'Tidak ada file Manifes Ruang Kerja yang akan berubah.';

  @override
  String lockVersionChange(String from, String to) {
    return '$from → $to';
  }

  @override
  String get notPresent => 'tidak hadir';

  @override
  String get planActionCreate => 'Buat';

  @override
  String get planActionReplace => 'Ganti';

  @override
  String get planActionSkip => 'Lewati';

  @override
  String get planActionConflict => 'Konflik';

  @override
  String get planActionBlockedByRisk => 'Diblokir oleh risiko';

  @override
  String installationResultSummary(int succeeded, int failed) {
    return '$succeeded target terpasang, $failed gagal';
  }

  @override
  String get installationProgressTitle => 'Instalasi sedang berlangsung';

  @override
  String installationProgressSummary(int finished, int total) {
    return '$finished dari $total target selesai';
  }

  @override
  String get targetWaiting => 'Menunggu';

  @override
  String get targetRunning => 'Menginstal';

  @override
  String retryFailedTargets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Coba lagi $count target yang gagal',
      one: 'Coba lagi 1 target yang gagal',
    );
    return '$_temp0';
  }

  @override
  String get updatePlanTitle => 'Pilih target untuk diperbarui';

  @override
  String get updatePlanDescription =>
      'Pilih Target Instalasi yang tepat. Agen dan proyek yang tidak dipilih tetap tidak berubah.';

  @override
  String updateTargetsSelected(int selected, int available) {
    return '$selected dari $available target yang dapat diperbarui dipilih';
  }

  @override
  String updateVersionChange(String fromVersion, String toVersion) {
    return '$fromVersion → $toVersion';
  }

  @override
  String sourceReference(String reference) {
    return 'Referensi sumber: $reference';
  }

  @override
  String get fixedVersionTarget =>
      'Disematkan — tidak ada referensi yang dapat dipindahkan';

  @override
  String get currentVersionTarget => 'Terkini';

  @override
  String get updateCheckTargetFailed => 'Pemeriksaan pembaruan gagal';

  @override
  String get reconcileWorkspaceManifestTarget => 'Perbaiki manifes ruang kerja';

  @override
  String get updateSelectedTargets => 'Perbarui target yang dipilih';

  @override
  String get updateProgressTitle => 'Memperbarui target';

  @override
  String get updateResultsTitle => 'Perbarui hasil';

  @override
  String updateProgressSummary(int finished, int total) {
    return '$finished dari $total target selesai';
  }

  @override
  String retryFailedUpdates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Coba lagi $count pembaruan yang gagal',
      one: 'Coba lagi 1 pembaruan yang gagal',
    );
    return '$_temp0';
  }

  @override
  String get noUpdateableTargets =>
      'Tidak ada target terpilih yang memiliki pembaruan tersedia.';

  @override
  String get closeUpdatePlan => 'Tutup';

  @override
  String get targetSucceeded => 'Dipasang';

  @override
  String get targetSkipped => 'Dilewati';

  @override
  String get targetConflict => 'Konflik';

  @override
  String get targetFailed => 'Gagal';

  @override
  String get targetFailureRetryable =>
      'Lokasi ini tidak dapat diubah. Anda dapat mencoba lagi.';

  @override
  String get targetFailureNeedsAttention =>
      'Lokasi ini memerlukan perhatian Anda sebelum Anda mencoba lagi.';

  @override
  String get installationTargetFailureMessage =>
      'Tidak ada yang berubah di lokasi ini. Periksa apakah folder tersebut tersedia dan coba lagi.';

  @override
  String get workspacePersistenceFailureMessage =>
      'Tidak ada yang berubah karena SkillsGo tidak dapat menyimpan pengaturan proyek. Periksa apakah folder proyek dapat ditulis dan coba lagi.';

  @override
  String get installationStateChangedMessage =>
      'Lokasi ini berubah saat Anda meninjaunya. Tinjau status terkini sebelum mencoba lagi.';

  @override
  String get updateTargetFailureMessage =>
      'Lokasi ini tidak dapat diperbarui. Lokasi lain tidak terpengaruh, jadi Anda hanya dapat mencoba ulang lokasi ini.';

  @override
  String get managementTargetFailureMessage =>
      'Tindakan ini tidak dapat diselesaikan di sini. Lokasi lain tidak terpengaruh, jadi Anda hanya dapat mencoba ulang lokasi ini.';

  @override
  String get technicalDetails => 'Detail teknis';

  @override
  String get targetPathExists => 'Item lain sudah ada di lokasi ini.';

  @override
  String get targetBlockedByRisk =>
      'Setelan keamanan Anda saat ini memblokir pemasangan di lokasi ini.';

  @override
  String get targetInstallFailed => 'Skill tidak dapat dipasang di lokasi ini.';

  @override
  String get targetWorkspaceUpdateFailed =>
      'Keterampilan telah diinstal, tetapi pengaturan proyek tidak dapat diperbarui.';

  @override
  String get installationPlanFailed =>
      'Rencana instalasi tidak dapat dilanjutkan';

  @override
  String get installationFailed => 'Instalasi tidak dapat diselesaikan';

  @override
  String get localSource => 'Sumber lokal';

  @override
  String get noDescriptionAvailable => 'Tidak ada deskripsi yang tersedia';

  @override
  String moreCoverage(int count) {
    return '+$count lokasi lainnya';
  }

  @override
  String get batchTakeoverAction => 'Kelola keterampilan yang ada';

  @override
  String handExternalSkillsToSkillsGoManagementCount(int count) {
    return 'Let SkillsGo manage $count external skills';
  }

  @override
  String confirmSkillsGoManagementCount(int count) {
    return 'Confirm SkillsGo management ($count)';
  }

  @override
  String get skillColumnLabel => 'Skill';

  @override
  String get repositorySourceColumnLabel => 'Source';

  @override
  String get versionColumnLabel => 'Version';

  @override
  String get repositoryMatching => 'Matching sources…';

  @override
  String get sourceMatchUnavailable => 'Source matching unavailable';

  @override
  String get noSourceMatches => 'No matching source';

  @override
  String sourceMatchPercent(int percent) {
    return '$percent% match';
  }

  @override
  String get versionPendingSelection => 'Pending Source';

  @override
  String batchTakeoverActionCount(int count) {
    return 'Kelola ($count)';
  }

  @override
  String get batchTakeoverChecking => 'Memeriksa keterampilan yang ada…';

  @override
  String get batchTakeoverRetry =>
      'Periksa kembali keterampilan yang dapat dikelola';

  @override
  String batchTakeoverEligibleCount(int count) {
    return '$count dapat dikelola';
  }

  @override
  String get batchTakeoverPending => 'Menambah keterampilan pada manajemen…';

  @override
  String get batchTakeoverTitle =>
      'Kelola keterampilan yang ada dengan SkillsGo?';

  @override
  String get batchTakeoverDescription =>
      'SkillsGo akan menambahkan catatan manajemen lokal tanpa memindahkan, menimpa, atau mengunggah file keterampilan. Item yang tidak didukung atau diubah akan dilewati.';

  @override
  String get batchTakeoverStoryTitle =>
      'Ubah keterampilan yang tersebar menjadi satu Perpustakaan yang jelas';

  @override
  String batchTakeoverStoryDescription(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count keterampilan yang ada',
      one: '1 keterampilan yang ada',
    );
    return 'SkillsGo menemukan $_temp0 yang dapat dikelola di lokasi ini.';
  }

  @override
  String get batchTakeoverBeforeSemantics =>
      'Sebelum dikelola, tidak jelas di mana keterampilan yang ada diterapkan, apakah keterampilan tersebut terkini, bagaimana cara memulihkannya, atau apakah proyek menggunakan versi yang sama.';

  @override
  String get batchTakeoverPainLocation => 'Lokasi pemasangan tidak diketahui';

  @override
  String get batchTakeoverPainFreshness => 'Status pembaruan tidak diketahui';

  @override
  String get batchTakeoverPainRecovery => 'Tidak ada pemulihan saat rusak';

  @override
  String get batchTakeoverPainVersionDrift => 'Versi berbeda di seluruh proyek';

  @override
  String get batchTakeoverFolderTitle => 'Keterampilan yang Ada';

  @override
  String get batchTakeoverFolderSubtitle => 'Statusnya tidak jelas';

  @override
  String get batchTakeoverAfterLabel => 'SETELAH';

  @override
  String get batchTakeoverAfterTitle => 'Satu Perpustakaan yang jelas';

  @override
  String get batchTakeoverLibraryTitle => 'Pustaka SkillsGo';

  @override
  String get batchTakeoverBenefitLocation => 'Hapus lokasi';

  @override
  String get batchTakeoverBenefitFreshness => 'Pembaruan terlihat';

  @override
  String get batchTakeoverBenefitRecovery => 'Pemulihan mudah';

  @override
  String get batchTakeoverBenefitVersions => 'Versi jelas';

  @override
  String get batchTakeoverManagedSection => 'Dikelola oleh SkillsGo';

  @override
  String get batchTakeoverPendingSection => 'Tertunda';

  @override
  String batchTakeoverItemManaged(String name) {
    return '$name dikelola oleh SkillsGo';
  }

  @override
  String batchTakeoverItemSkipped(String name) {
    return '$name tidak dapat ditambahkan ke pengelolaan';
  }

  @override
  String batchTakeoverItemPending(String name) {
    return '$name menunggu untuk dikelola';
  }

  @override
  String batchTakeoverAfterSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count keterampilan adalah',
      one: '1 keterampilan adalah',
    );
    return 'Setelah pengelolaan, $_temp0 diatur dalam satu Perpustakaan dengan status terkelola yang jelas.';
  }

  @override
  String batchTakeoverMoreSkills(int count) {
    return '+$count lagi';
  }

  @override
  String get batchTakeoverTransitionSemantics =>
      'Tambahkan keterampilan yang ada ini ke manajemen SkillsGo.';

  @override
  String get batchTakeoverTransitionLabel => 'ORGANISASI';

  @override
  String get batchTakeoverStatusTitle => 'Status manajemen';

  @override
  String get batchTakeoverStatusManaged => 'Dikelola';

  @override
  String get batchTakeoverStatusProgress => 'Pengorganisasian';

  @override
  String get batchTakeoverStatusSkipped => 'Dilewati';

  @override
  String get batchTakeoverStatusFilesStay =>
      'File keterampilan tetap berada di lokasi aslinya';

  @override
  String get batchTakeoverBoardSemantics =>
      'Keterampilan disusun menjadi baris lengkap dan dicatat oleh SkillsGo tanpa memindahkan filenya.';

  @override
  String get batchTakeoverBoardComplete => 'SEMUA JELAS';

  @override
  String get batchTakeoverBoardPartial => 'LENGKAP';

  @override
  String get batchTakeoverStatusTotal => 'Jumlah';

  @override
  String get batchTakeoverQueueComplete =>
      'Tidak ada keterampilan yang menunggu';

  @override
  String get batchTakeoverQueueWaiting =>
      'Keterampilan akan dipindahkan ke sini setelah verifikasi';

  @override
  String get batchTakeoverNextLabel => 'BERIKUTNYA';

  @override
  String batchTakeoverFillerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count blok penyelenggara SkillsGo',
      one: '1 blok penyelenggara SkillsGo',
    );
    return '$_temp0 selesaikan baris terakhir';
  }

  @override
  String get batchTakeoverPreservation =>
      'File, jalur, dan alur kerja Anda saat ini tetap berada di tempatnya. SkillsGo hanya melengkapi catatan manajemen lokalnya.';

  @override
  String get batchTakeoverLaterHint =>
      'Jika Anda melewatkannya, Anda dapat menggunakan Kelola keterampilan yang ada dari Perpustakaan kapan saja.';

  @override
  String get batchTakeoverSkip => 'Tidak sekarang';

  @override
  String get batchTakeoverConfirm => 'Tambahkan ke manajemen';

  @override
  String get batchTakeoverExecutionRetry => 'Coba lagi';

  @override
  String get batchTakeoverResultTitle =>
      'Keterampilan ditambahkan ke manajemen';

  @override
  String batchTakeoverSummary(int takenOver, int skipped) {
    return 'Keterampilan $takenOver ditambahkan ke manajemen, $skipped dilewati.';
  }

  @override
  String get batchTakeoverClose => 'Tutup';

  @override
  String get installMoreTargets => 'Instal di lebih banyak lokasi';

  @override
  String get detailRepository => 'Gudang';

  @override
  String get detailStars => 'Bintang';

  @override
  String get detailUpdated => 'Diperbarui';

  @override
  String get detailArchiveSize => 'Ukuran ZIP';

  @override
  String get pathLabel => 'Jalur proyek';

  @override
  String get copyProjectPath => 'Salin jalur proyek';

  @override
  String get projectPathCopied => 'Jalur proyek disalin';

  @override
  String get onboardingWelcomeTitle => 'Selamat datang di SkillsGo';

  @override
  String get onboardingWelcomeDescription =>
      'Temukan, instal, dan kelola Keterampilan di seluruh Agen dan proyek Anda.';

  @override
  String get onboardingDetectedAgents => 'Agen Terdeteksi';

  @override
  String get onboardingNoAgents =>
      'Tidak ada Agen terinstal yang terdeteksi. Anda masih bisa melanjutkan.';

  @override
  String get onboardingNext => 'Selanjutnya';

  @override
  String get onboardingProjectsTitle => 'Tambahkan proyek Anda';

  @override
  String get onboardingProjectsDescription =>
      'Pilih proyek yang Anda ingin agar SkillsGo kelola.';

  @override
  String get onboardingAddProject => 'Tambahkan sekarang';

  @override
  String get onboardingAddProjectLater => 'atau lebih baru';

  @override
  String get onboardingStartUsing => 'Mulai Menggunakan SkillsGo';

  @override
  String get onboardingBack => 'Kembali';

  @override
  String get restartOnboardingTitle => 'Orientasi';

  @override
  String get restartOnboardingDescription =>
      'Lihat kembali panduan peluncuran pertama tanpa menghapus proyek, pengaturan, atau data Keterampilan.';

  @override
  String get restartOnboardingAction => 'Mulai ulang Orientasi';

  @override
  String get restartOnboardingFailed =>
      'SkillsGo tidak dapat memulai ulang Orientasi.';

  @override
  String get libraryRefreshSettingsTitle => 'Segarkan Perpustakaan lokal';

  @override
  String get libraryRefreshSettingsDescription =>
      'Pindai ulang Keterampilan yang diinstal, Proyek Tambahan, Agen, dan Keterampilan eksternal yang dapat dikelola. Ini tidak menginstal, memperbarui, atau menghapus apa pun.';

  @override
  String get libraryRefreshSettingsAction => 'Segarkan Perpustakaan';

  @override
  String get libraryRefreshSettingsPending => 'Perpustakaan yang Menyegarkan…';

  @override
  String get libraryRefreshSettingsSuccess => 'Perpustakaan Lokal disegarkan.';

  @override
  String get libraryRefreshSettingsFailed =>
      'SkillsGo tidak dapat menyegarkan Perpustakaan lokal.';

  @override
  String get onboardingProjectError =>
      'SkillsGo tidak dapat menambahkan proyek dari direktori ini.';

  @override
  String get onboardingProjectsLoadError =>
      'SkillsGo tidak dapat memuat proyek tambahan Anda.';

  @override
  String get onboardingStartupError =>
      'SkillsGo tidak dapat memuat pengaturan.';

  @override
  String get onboardingStateError =>
      'SkillsGo tidak dapat menyimpan kemajuan pengaturan Anda. Coba lagi.';

  @override
  String get onboardingCliErrorTitle => 'SkillsGo CLI memerlukan perhatian';

  @override
  String get onboardingCliErrorDescription =>
      'Perbaiki CLI yang dibundel, lalu coba lagi untuk melanjutkan.';
}
