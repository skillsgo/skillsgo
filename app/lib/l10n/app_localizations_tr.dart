// ignore_for_file: text_direction_code_point_in_literal, text_direction_code_point_in_comment

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get discover => 'Keşfet';

  @override
  String get discoverSkills => 'Biraz daha fazlasını bilmek güzel.';

  @override
  String get library => 'Kütüphane';

  @override
  String get settings => 'Ayarlar';

  @override
  String get appUpdateTitle => 'App updates';

  @override
  String get appUpdateDescription =>
      'Check the signed release feed for a newer version of SkillsGo.';

  @override
  String get appUpdateNotConfigured =>
      'App updates are unavailable in this build.';

  @override
  String get appUpdateReady =>
      'Check when you’re ready. SkillsGo will not install an update without your action.';

  @override
  String get appUpdateChecking => 'Checking for an App update…';

  @override
  String get appUpdateApplying =>
      'Downloading the update. SkillsGo will restart when it is ready.';

  @override
  String get appUpdateCheckFailed =>
      'SkillsGo could not check for an App update. Check your connection and try again.';

  @override
  String appUpdateAvailable(String version) {
    return 'SkillsGo $version is available.';
  }

  @override
  String appUpdateCurrent(String version) {
    return 'SkillsGo $version is up to date.';
  }

  @override
  String get appUpdateCheckAction => 'Check for App updates';

  @override
  String get appUpdateApplyAction => 'Update and restart';

  @override
  String get openSettings => 'Ayarları Aç';

  @override
  String get cliNeedsAttention =>
      'Gerekli bir SkillsGo bileşeniyle ilgilenilmesi gerekiyor.';

  @override
  String get cliMissingBundled =>
      'Gerekli bir SkillsGo bileşeni eksik veya başlatılamıyor. Geri yüklemek için SkillsGo\'yi yeniden yükleyin.';

  @override
  String get cliDamagedBundled =>
      'Gerekli bir SkillsGo bileşeni hasarlı. Geri yüklemek için SkillsGo\'yi yeniden yükleyin.';

  @override
  String get cliIncompatibleBundled =>
      'Gerekli bir SkillsGo bileşeni bu uygulama sürümüyle eşleşmiyor. SkillsGo\'yi güncelleyin veya yeniden yükleyin.';

  @override
  String get officialIndex => 'SkillsGo Hub';

  @override
  String get discoverTitle => 'Bir sonraki hamleniz için bir beceri bulun.';

  @override
  String get skillsLeaderboard => 'Biraz daha fazlasını bilmek güzel.';

  @override
  String searchResultsFor(String query) {
    return '“$query” için sonuçlar';
  }

  @override
  String get searchSkills =>
      'Becerileri arayın veya bir Git bağlantısını yapıştırın…';

  @override
  String get search => 'Ara';

  @override
  String get ranking => 'Sıralama';

  @override
  String get trending => 'Trend olan';

  @override
  String get hot => 'Sıcak';

  @override
  String get discoverNavigation => 'Navigasyonu keşfedin';

  @override
  String get allTimeRanking => 'Tüm zamanların sıralaması';

  @override
  String get trendingNow => 'Son 24 saatte trend';

  @override
  String get hotNow => 'Şu anda sıcak';

  @override
  String get allTimeDescription =>
      'Tüm zamanlardaki kabul edilen yüklemelere göre sıralanan genel Skills.';

  @override
  String get trendingDescription =>
      'Genel Skills, son 24 saatlik zaman aralığında kabul edilen yüklemelere göre sıralanmıştır.';

  @override
  String get hotDescription =>
      'Kısa süreli kurulum hızı ve değişimine göre sıralanan genel Skills.';

  @override
  String get offlineTitle => 'SkillsGo\'ye bağlanılamıyor';

  @override
  String get offlineMessage =>
      'İnternet bağlantınızı kontrol edip tekrar deneyin. Proxy veya özel hizmet adresi kullanıyorsanız bunu Ayarlar\'da inceleyin.';

  @override
  String get searchFailedTitle => 'Arama tökezledi';

  @override
  String get validationTitle => 'Ne girdiğinizi kontrol edin';

  @override
  String get validationMessage =>
      'SkillsGo bu isteği kullanamadı. Girdiğiniz bilgileri gözden geçirin ve tekrar deneyin.';

  @override
  String get serverTitle => 'Hizmet geçici olarak kullanılamıyor';

  @override
  String get serverMessage =>
      'SkillsGo bu isteği şu anda tamamlayamıyor. Birazdan tekrar deneyin.';

  @override
  String get timeoutTitle => 'Bu çok uzun sürüyor';

  @override
  String get timeoutMessage =>
      'Hizmet zamanında yanıt vermedi. Bağlantınızı kontrol edin veya tekrar deneyin.';

  @override
  String get invalidResponseTitle => 'SkillsGo\'nin güncellenmesi gerekiyor';

  @override
  String get invalidResponseMessage =>
      'Bu yanıt SkillsGo sürümünüz tarafından okunamıyor. Uygulamayı güncelleyin ve tekrar deneyin.';

  @override
  String get invalidLocalDataTitle => 'Yüklü bir beceri okunamıyor';

  @override
  String get invalidLocalDataMessage =>
      'Bazı yerel kurulum bilgileri hasarlı veya uyumsuz. SkillsGo\'yi güncelleyin veya yeniden yükleyin, ardından tekrar deneyin.';

  @override
  String get tryAgain => 'Tekrar dene';

  @override
  String get searchEmptyTitle => 'Arayın, kaydırmayın.';

  @override
  String get searchEmptyMessage =>
      'Genel becerileri aramak için bir yetenek, kaynak veya görev girin.';

  @override
  String get noSkillsTitle => 'Hiçbir beceri bulunamadı';

  @override
  String get noSkillsMessage =>
      'Daha geniş bir ifade deneyin veya yazımı kontrol edin.';

  @override
  String get focusSearch => 'Aramaya odaklan';

  @override
  String get skillsFromLink => 'Bu bağlantıdan Skills';

  @override
  String skillCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Skills',
      one: '1 Skill',
    );
    return '$_temp0';
  }

  @override
  String sourceResultsSummary(String source, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$source kaynağından $count Skills',
      one: '$source kaynağından 1 Skill',
    );
    return '$_temp0';
  }

  @override
  String get sourceSearchEmptyTitle => 'Bu bağlantı incelemeye hazır';

  @override
  String sourceSearchEmptyMessage(String source) {
    return '$source mevcut arama sonuçlarında yok. SkillsGo bir sonraki adımda bağlantıyı doğrudan inceleyebilir.';
  }

  @override
  String get inspectSource => 'Bu bağlantıdaki becerileri görüntüleyin';

  @override
  String get collectionEmptyTitle => 'Bu koleksiyonda Skills yok';

  @override
  String get collectionEmptyMessage =>
      'Burada henüz hiçbir şey yok. Daha fazla kurulum etkinliğinden sonra tekrar deneyin.';

  @override
  String get loadMore => 'Daha fazlasını yükle';

  @override
  String get install => 'Yükle';

  @override
  String get upgrade => 'Upgrade';

  @override
  String get downgrade => 'Downgrade';

  @override
  String get packageSkillsSwitchTogether =>
      'Skills from this package will switch version together.';

  @override
  String get switchVersion => 'Switch version';

  @override
  String upgradeToVersion(String version) {
    return 'Upgrade to $version';
  }

  @override
  String downgradeToVersion(String version) {
    return 'Downgrade to $version';
  }

  @override
  String get installAll => 'Tüm becerileri yükle';

  @override
  String get latestCommit => 'En son taahhüt';

  @override
  String get installToMoreTargets => 'Daha Fazla Konumda Kurulum';

  @override
  String localTargets(int count) {
    return '$count yerel hedefler';
  }

  @override
  String allTimeMetric(String count) {
    return '$count tüm zamanların yüklemeleri';
  }

  @override
  String trendingMetric(String count) {
    return '$count yükleme / 24 saat';
  }

  @override
  String hotMetric(String value, String change) {
    return '$value bu saat · $change';
  }

  @override
  String get trustUnverified => 'Doğrulanmamış';

  @override
  String get trustCommunityVerified => 'Topluluk doğrulandı';

  @override
  String get trustPublisherVerified => 'Yayıncı doğrulandı';

  @override
  String get trustOfficial => 'Resmi';

  @override
  String get trustWarned => 'Uyarıldı';

  @override
  String get trustDelisted => 'Listeden kaldırıldı';

  @override
  String get riskUnknown => 'Bilinmeyen risk';

  @override
  String get riskLow => 'Düşük risk';

  @override
  String get riskMedium => 'Orta risk';

  @override
  String get riskHigh => 'Yüksek risk';

  @override
  String get riskCritical => 'Kritik risk';

  @override
  String openSkill(String name) {
    return '$name\'yi açın';
  }

  @override
  String installs(String count) {
    return '$count yüklemeleri';
  }

  @override
  String get detailFailedTitle => 'Bu Skill yüklenemedi';

  @override
  String get detailLoading => 'Denetlenebilir Skill ayrıntısı yükleniyor';

  @override
  String get artifactUnavailableTitle => 'Artifact kullanılamıyor';

  @override
  String get artifactUnavailableMessage =>
      'Bu sürüm şu anda mevcut değil. Tekrar deneyin veya başka bir sürüm seçin.';

  @override
  String get detailInvalidTitle => 'Artifact meta verileri desteklenmiyor';

  @override
  String get detailInvalidMessage =>
      'Bu beceriye ilişkin bazı ayrıntılar eksik veya okunamıyor. SkillsGo\'yi güncelleyin ve tekrar deneyin.';

  @override
  String get instructionsTab => 'Talimatlar';

  @override
  String get manifestTab => 'manifest';

  @override
  String immutableVersionLabel(String version) {
    return 'Değişmez $version';
  }

  @override
  String commitIdentity(String sha) {
    return '$sha\'yi taahhüt et';
  }

  @override
  String treeIdentity(String sha) {
    return 'Ağaç $sha';
  }

  @override
  String contentIdentity(String digest) {
    return 'İçerik $digest';
  }

  @override
  String get trustDoesNotProveSafety =>
      'Yayıncı güveni, sahipliği veya bakımı doğrular; eser güvenliğini onaylamaz. Bu değişmez versiyon için risk ayrı ayrı değerlendirilir.';

  @override
  String get knownInstallationTargets => 'Bilinen kurulum hedefleri';

  @override
  String get installationRange => 'Yüklü kapsam';

  @override
  String get targetDetails => 'Hedef ayrıntılarını göster';

  @override
  String get hideTargetDetails => 'Hedef ayrıntılarını gizle';

  @override
  String installedVersionLabel(String version) {
    return 'Sürüm $version';
  }

  @override
  String targetSummary(String scope, String agent, String version) {
    return '$scope / $agent · $version';
  }

  @override
  String get projectScope => 'Proje';

  @override
  String get fileContentUnavailable => 'İkili veya kullanılamayan önizleme';

  @override
  String get fileContentTruncated =>
      'Önizleme Hub güvenlik sınırı nedeniyle kesildi.';

  @override
  String get retry => 'Yeniden dene';

  @override
  String get backToSearch => 'Aramaya geri dön';

  @override
  String get installForCodex => 'Codex için yükleyin';

  @override
  String get cliNotDetected => 'beceriler (algılanmadı)';

  @override
  String get snapshotFiles => 'Anlık görüntü dosyaları';

  @override
  String get globalCodex => 'Küresel · Codex';

  @override
  String get yourLibrary => 'Bildiklerinin hepsi burada.';

  @override
  String get libraryNavigation => 'Kütüphanede gezinme';

  @override
  String get all => 'Hepsi';

  @override
  String get allSkills => 'Hepsi Skills';

  @override
  String get updatesOnly => 'Güncellemeler';

  @override
  String get allAgents => 'Hepsi Agents';

  @override
  String get allProjects => 'Tüm Projeler';

  @override
  String get specificProject => 'Proje';

  @override
  String get libraryGlobalScope => 'Global Skills';

  @override
  String get globalScope => 'Küresel';

  @override
  String get globalSkills => 'Global Skills';

  @override
  String get addProject => 'Proje Ekle';

  @override
  String get removeFromList => 'Listeden Kaldır';

  @override
  String removeProjectTitle(String name) {
    return '$name, SkillsGo\'den kaldırılsın mı?';
  }

  @override
  String get removeProjectDescription =>
      'Yalnızca Uygulama referansı kaldırılacaktır. SkillsGo bu dizindeki hiçbir dosyayı değiştirmez veya silmez.';

  @override
  String projectRailUnavailable(String name) {
    return '$name — kullanılamıyor';
  }

  @override
  String get emptyProjectTitle => 'Henüz Skills yok';

  @override
  String get browseSkills => 'Skills\'ye göz atın';

  @override
  String get projectMissingTitle => 'Proje dizini eksik';

  @override
  String get projectMissingMessage =>
      'The directory may have moved or its volume may be offline. Check the path or remove its App reference.';

  @override
  String get projectPermissionTitle => 'Proje izni gerekli';

  @override
  String get projectPermissionMessage =>
      'SkillsGo cannot inspect this project root. Check its filesystem permissions or remove its App reference.';

  @override
  String get projectInaccessibleTitle => 'Proje dizinine erişilemiyor';

  @override
  String get projectInaccessibleMessage =>
      'SkillsGo kept this project reference. Check the path or volume, or remove its App reference.';

  @override
  String get checking => 'Kontrol ediliyor…';

  @override
  String get checkUpdates => 'Güncellemeleri kontrol edin';

  @override
  String get refresh => 'Yenile';

  @override
  String get libraryUnavailable => 'Kütüphane kullanılamıyor';

  @override
  String get libraryEmpty => 'Henüz hiçbir beceri yüklenmedi';

  @override
  String get libraryEmptyMessage =>
      'Discover\'dan bir Skill yükleyin, burada görünecektir.';

  @override
  String get searchLibrary => 'Yüklü becerileri arayın';

  @override
  String get libraryNoMatches => 'Eşleşen yok Skills';

  @override
  String get libraryNoMatchesMessage =>
      'Farklı bir ad, kaynak, Agent, proje veya sürüm deneyin.';

  @override
  String agentsSummary(int count) {
    return '$count Agents';
  }

  @override
  String projectsSummary(int count) {
    return '$count projeleri';
  }

  @override
  String versionsSummary(int count) {
    return '$count versiyonları';
  }

  @override
  String get hubManaged => 'Hub yönetildi';

  @override
  String get localManaged => 'Yerel olarak yönetilen';

  @override
  String get externalInstallation => 'Harici kurulum';

  @override
  String get readOnly => 'Salt okunur';

  @override
  String get unversioned => 'Sürümü değiştirilmemiş';

  @override
  String get supportingFiles => 'Destekleyici dosyalar';

  @override
  String get versionDivergence => 'Sürüm farklılığı';

  @override
  String get healthHealthy => 'Sağlıklı';

  @override
  String get healthMissing => 'Hedef eksik';

  @override
  String get healthReplaced => 'Hedef değiştirildi';

  @override
  String get healthLocalModification => 'Yerel Değişiklik';

  @override
  String get healthUnreadable => 'Hedef okunamıyor';

  @override
  String get healthUndeclared => 'Beyan edilmedi';

  @override
  String get healthWorkspaceUnreadable => 'Çalışma alanı durumu okunamıyor';

  @override
  String get healthLockMismatch => 'Kilit uyuşmazlığı';

  @override
  String get healthUnexpectedPath => 'Beklenmeyen hedef yolu';

  @override
  String get modeExternal => 'Harici';

  @override
  String get notLinked => 'BAĞLANTILI DEĞİL';

  @override
  String get update => 'Güncelleme';

  @override
  String get backToLibrary => 'Kütüphaneye Geri Dön';

  @override
  String get remove => 'Kaldır';

  @override
  String skillsSelected(int count) {
    return '$count seçildi';
  }

  @override
  String get clearSelection => 'Seçimi temizle';

  @override
  String get selectCurrentResults => 'Mevcut sonuçları seç';

  @override
  String get clearCurrentResultSelection => 'Geçerli sonuç seçimini temizle';

  @override
  String targetActionsSelected(int selected, int total) {
    return '$total hedeflerinden $selected seçildi';
  }

  @override
  String get confirmRemoveTarget => 'Kaldırmayı onayla';

  @override
  String get managementProgressTitle => 'Hedef eylemleri uygulama';

  @override
  String get managementResultsTitle => 'Hedef eylem sonuçları';

  @override
  String managementResultSummary(int succeeded, int failed) {
    return '$succeeded başarılı oldu, $failed başarısız oldu';
  }

  @override
  String get targetContentPreserved => 'Mevcut hedef içerik korunacaktır.';

  @override
  String get localReadFailed => 'Bu Skill okunamıyor';

  @override
  String get localReadFailedMessage =>
      'SkillsGo bu yüklü beceriyi okuyamadı. Klasörünün kullanılabilir ve erişilebilir olduğundan emin olun ve tekrar deneyin.';

  @override
  String get localConfiguration => 'SKILLSGO AYARLARI';

  @override
  String get settingsNavigation => 'Ayarlarda gezinme';

  @override
  String get general => 'Kişiselleştir';

  @override
  String get agents => 'Agents';

  @override
  String get hub => 'Hub';

  @override
  String get installationPolicy => 'Kurulum Politikası';

  @override
  String get storage => 'Depolama';

  @override
  String get colorScheme => 'Renk Şeması';

  @override
  String get about => 'Hakkında';

  @override
  String get colorSchemeInspectorTitle => 'Oluşturulan Material renk rolleri';

  @override
  String get skillsColorTokensTitle => 'SkillsGo anlamsal renkler';

  @override
  String get skillsColorTokensDescription =>
      'Radix Sand\'den oluşturulan ve Primer anlambilimiyle düzenlenen ve özel bir uzamsal hiyerarşi olarak Folder ile düzenlenen ürün renkleri.';

  @override
  String get colorSchemeInspectorDescription =>
      'Geçerli tohumdan oluşturulan, kullanımdan kaldırılmamış her ColorScheme belirtecinin ön izlemesini yapın. HEX değerini kopyalamak için bir renge tıklayın.';

  @override
  String get colorSchemePairPreview => 'Anlamsal çiftler';

  @override
  String get colorSchemePairPreviewDescription =>
      'Karşıtlık ve hiyerarşiyi ortaya çıkarmak için ön plan ve arka plan rolleri bir araya getirildi.';

  @override
  String get colorSchemeComponentPreview => 'Bileşen önizlemesi';

  @override
  String get colorSchemeComponentPreviewDescription =>
      'Tam olarak bu önizleme şemasıyla oluşturulan temsili Material kontrolleri.';

  @override
  String get colorSchemeSampleTitle => 'Skill kart başlığı';

  @override
  String get colorSchemeSampleBody =>
      'İkincil kopya onSurfaceVariant\'yi kullanır.';

  @override
  String get colorSchemeCopied => 'Kopyalandı';

  @override
  String get colorSchemeSampleGlyphs => 'Aa 123';

  @override
  String get colorSchemeGroupPrimary => 'Birincil';

  @override
  String get colorSchemeGroupPrimaryDescription =>
      'Birincil vurgu, kapsayıcılar ve sabit vurgu rolleri.';

  @override
  String get colorSchemeGroupSecondary => 'İkincil';

  @override
  String get colorSchemeGroupSecondaryDescription =>
      'Destekleyici vurgu ve sabit ikincil roller.';

  @override
  String get colorSchemeGroupTertiary => 'Üçüncül';

  @override
  String get colorSchemeGroupTertiaryDescription =>
      'Zıt vurgular ve sabit üçüncül roller.';

  @override
  String get colorSchemeGroupSurface => 'Yüzey';

  @override
  String get colorSchemeGroupSurfaceDescription =>
      'Sayfa, kapsayıcı, yükseklik ve ön plan hiyerarşisi.';

  @override
  String get colorSchemeGroupUtility => 'Taslak ve Yardımcı Program';

  @override
  String get colorSchemeGroupUtilityDescription =>
      'Sınırlar, gölgeler, ince kumaşlar ve ters yüzeyler.';

  @override
  String get colorSchemeGroupError => 'Hata';

  @override
  String get colorSchemeGroupErrorDescription =>
      'Hata eylemleri, mesajlar ve kapsayıcılar.';

  @override
  String get colorSchemeUsagePrimary =>
      'Birincil eylemler, odak ve yüksek vurgulu vurgular.';

  @override
  String get colorSchemeUsageSecondary =>
      'Destekleyici eylemler ve orta vurgulu vurgular.';

  @override
  String get colorSchemeUsageTertiary =>
      'Birincil ve ikincilleri tamamlayan zıt vurgular.';

  @override
  String colorSchemeUsageContentOn(String token) {
    return '$token\'de görüntülenen metin ve simgeler.';
  }

  @override
  String colorSchemeUsageContainer(String family) {
    return 'Seçimler ve vurgular için daha az vurgulu $family kapsayıcı.';
  }

  @override
  String colorSchemeUsageFixed(String family) {
    return 'Parlaklıktan bağımsız sabit $family konteyner.';
  }

  @override
  String colorSchemeUsageFixedDim(String family) {
    return 'Kısılmış parlaklıktan bağımsız sabit $family kabı.';
  }

  @override
  String colorSchemeUsageFixedContent(String family) {
    return 'Sabit $family kapsayıcısında yüksek vurgulu içerik.';
  }

  @override
  String colorSchemeUsageFixedVariantContent(String family) {
    return 'Sabit $family kapsayıcısında daha az vurgulanan içerik.';
  }

  @override
  String get colorSchemeUsageSurface => 'Temel sayfa ve geniş bölge yüzeyi.';

  @override
  String get colorSchemeUsageSurfaceDim =>
      'En koyu yüzey tonunda kullanılan dimlenmiş taban yüzeyi.';

  @override
  String get colorSchemeUsageSurfaceBright =>
      'En açık yüzey tonunda kullanılan parlak taban yüzeyi.';

  @override
  String colorSchemeUsageSurfaceElevation(String level) {
    return '$level yüzey konteyneri yüksekliği.';
  }

  @override
  String get colorSchemeElevationLowest => 'en düşük';

  @override
  String get colorSchemeElevationLow => 'düşük';

  @override
  String get colorSchemeElevationDefault => 'varsayılan';

  @override
  String get colorSchemeElevationHigh => 'yüksek';

  @override
  String get colorSchemeElevationHighest => 'en yüksek';

  @override
  String get colorSchemeUsageOnSurface =>
      'Yüzeylerde görüntülenen birincil metin ve simgeler.';

  @override
  String get colorSchemeUsageOnSurfaceVariant =>
      'Yüzeylerde ikincil metin, etiketler ve bastırılmış simgeler.';

  @override
  String get colorSchemeUsageSurfaceTint =>
      'Birincilden türetilen Material yükseklik tonu.';

  @override
  String get colorSchemeUsageOutline =>
      'Belirgin sınırlar ve odaklanmış bileşen ana hatları.';

  @override
  String get colorSchemeUsageOutlineVariant =>
      'İnce sınırlar, ayırıcılar ve az vurgulu ana hatlar.';

  @override
  String get colorSchemeUsageShadow =>
      'Yükseltilmiş yüzeyler için alt gölge rengi.';

  @override
  String get colorSchemeUsageScrim =>
      'Arka plan içeriğinin vurgusunu kaldırmak için kullanılan modal yer paylaşımı.';

  @override
  String get colorSchemeUsageInverseSurface =>
      'Ters açık ve koyu vurgulu yüzey.';

  @override
  String get colorSchemeUsageInversePrimary =>
      'Ters bir yüzeyde görüntülenen birincil vurgu.';

  @override
  String get colorSchemeUsageError =>
      'Hata eylemleri, durum ve yüksek vurgulu geri bildirim.';

  @override
  String get save => 'Kaydet';

  @override
  String get advancedSettings => 'Gelişmiş';

  @override
  String get remindersSettings => 'Hatırlatıcılar';

  @override
  String get remindersSettingsTitle => 'Hatırlatıcı ayarları';

  @override
  String get remindersSettingsDescription =>
      'Hangi hatırlatıcıların alınacağını seçin.';

  @override
  String get updateReminderTitle => 'Hatırlatıcıları güncelle';

  @override
  String get updateReminderDescription =>
      'Kütüphane açıldığında güncellemeleri kontrol edin.';

  @override
  String get securityReminderTitle => 'Yüksek risk uyarıları';

  @override
  String get securityReminderDescription =>
      'Kurulu becerilerdeki yeni Yüksek veya Kritik riskleri size bildirir.';

  @override
  String availableUpdatesReminder(int count) {
    return '$count yüklü becerilerin güncellemeleri var';
  }

  @override
  String get openAvailableUpdates =>
      'Bunları incelemek ve güncellemek için mevcut güncellemeler görünümünü açın.';

  @override
  String securityAdvisoriesReminder(int count) {
    return '$count yüklü becerilerin güvenlik incelemesine ihtiyacı var';
  }

  @override
  String get reviewInstalledSkills =>
      'Kullanmadan veya güncellemeden önce risk bilgilerini gözden geçirin.';

  @override
  String get generalSettingsTitle => 'SkillsGo\'yi kendinize ait yapın';

  @override
  String get generalSettingsDescription =>
      'Arayüz sistem dilinizi, erişilebilirliğinizi ve hareket tercihlerinizi takip eder.';

  @override
  String get agentsSettingsTitle => 'Agent çalışma zamanı';

  @override
  String get hubSettingsTitle => 'Hub Menşei';

  @override
  String get hubSettingsDescription =>
      'Aynı SkillsGo protokolünü uygulayan resmi Hub veya şirket içinde barındırılan HTTP(S) kaynağını kullanın.';

  @override
  String get testConnection => 'Bağlantıyı test edin';

  @override
  String get saveOrigin => 'Menşei Kaydet';

  @override
  String get resetDefault => 'Varsayılana sıfırla';

  @override
  String get connectionReady => 'Bağlantı hazır';

  @override
  String get connectionFailed => 'Bağlantı başarısız oldu';

  @override
  String get hubInvalidOrigin =>
      'Kimlik bilgileri, sorgu veya parça olmadan geçerli bir HTTP(S) Kaynağı girin.';

  @override
  String hubHttpFailure(int status) {
    return 'Hub, HTTP $status\'yi döndürdü. Origin ve sunucu yapılandırmasını kontrol edin.';
  }

  @override
  String get hubInvalidProtocol =>
      'Sunucu SkillsGo Hub arama protokolünü döndürmedi.';

  @override
  String get hubInvalidJson => 'Hub geçersiz JSON döndürdü.';

  @override
  String get hubConnectionFailure =>
      'Hub\'ye ulaşılamadı. Kaynak, ağ, proxy ve TLS yapılandırmasını kontrol edin.';

  @override
  String get hubConnectionTimeout =>
      'Hub bağlantısı zaman aşımına uğradı. Ağı kontrol edin veya tekrar deneyin.';

  @override
  String cloudHttpFailure(int status) {
    return 'Cloud returned HTTP $status. Check the Origin and service configuration.';
  }

  @override
  String get cloudInvalidProtocol =>
      'The server did not return the SkillsGo Cloud ranking protocol.';

  @override
  String get cloudInvalidJson => 'Cloud returned invalid JSON.';

  @override
  String get cloudConnectionFailure =>
      'Could not reach Cloud. Check the Origin, network, proxy, and TLS configuration.';

  @override
  String get cloudConnectionTimeout =>
      'The Cloud connection timed out. Check the network or try again.';

  @override
  String get riskPolicyTitle => 'Kişisel risk politikası';

  @override
  String get riskPolicyDescription =>
      'Bir beceriyi yüklediğinizde veya güncellediğinizde güvenlik kuralları geçerlidir.';

  @override
  String get confirmHighRisk => 'Yüksek risk için onay gerektir';

  @override
  String get confirmHighRiskDescription =>
      'Yüksek riskli eserler, kurulumdan önce her zaman ek bir onay gerektirir.';

  @override
  String get allowCriticalOverride =>
      'Açık bir Kritik risk geçersiz kılmaya izin ver';

  @override
  String get allowCriticalOverrideDescription =>
      'Kritik risk yapıları varsayılan olarak engellenmiş durumda kalır. Bunu yalnızca ayrı bir manuel geçersiz kılmayı ortaya çıkarmak için etkinleştirin.';

  @override
  String get storageHealthy => 'Okunabilir';

  @override
  String get storageNotInitialized => 'Başlatılmadı';

  @override
  String get storageUnavailable => 'Kullanılamıyor';

  @override
  String get storageInvalidResponse =>
      'Birlikte verilen CLI, desteklenmeyen bir tanılama yanıtı döndürdü.';

  @override
  String get aboutSettingsTitle => 'Ürün uyumluluğu';

  @override
  String get appVersion => 'Uygulama sürümü';

  @override
  String get cliVersion => 'Birlikte verilen CLI sürümü';

  @override
  String get compatible => 'Uyumlu';

  @override
  String get hubOriginSaved => 'Hub Kaynak kaydedildi ve uygulandı.';

  @override
  String get policySaved => 'Kurulum politikası kaydedildi.';

  @override
  String get officialCli => 'SkillsGo CLI';

  @override
  String get ready => 'HAZIR';

  @override
  String get unknown => 'BİLİNMİYOR';

  @override
  String get missing => 'KAYIP';

  @override
  String get incompatible => 'UYUMSUZ';

  @override
  String get detecting => 'Algılanıyor…';

  @override
  String get customCliPath => 'Özel yürütülebilir yol';

  @override
  String get saveAndDetect => 'Kaydet ve algıla';

  @override
  String get detectAgain => 'Tekrar tespit et';

  @override
  String get agentInstalled => 'Yüklendi';

  @override
  String get agentSupported => 'Destekleniyor';

  @override
  String agentCatalogSummary(int installed, int supported) {
    return '$installed yüklü · $supported destekleniyor';
  }

  @override
  String installedAgentsTitle(int count) {
    return 'Yüklendi · $count';
  }

  @override
  String notInstalledAgentsTitle(int count) {
    return 'Kurulu değil · $count';
  }

  @override
  String get notInstalledAgentsDescription =>
      'SkillsGo tarafından destekleniyor ancak bu Mac\'te algılanmıyor.';

  @override
  String agentDiscoveryRoots(String paths) {
    return 'Skill yükleme yolları: $paths';
  }

  @override
  String get agentInspectionFailed =>
      'Agent algılama verileri mevcut değil. Algılamayı yeniden çalıştırın.';

  @override
  String get noInstalledAgentsTitle => 'Yüklü Agents algılanmadı';

  @override
  String get noInstalledAgentsMessage =>
      'Bu Skill\'ye göz atmaya devam edebilirsiniz ancak henüz bir kurulum hedefi yok. Desteklenen bir Agent yükleyin, ardından algılamayı yeniden çalıştırın.';

  @override
  String get clearCustomPath => 'Özel yolu temizle';

  @override
  String get privacyProvenance => 'Gizlilik ve menşe';

  @override
  String get privacySummary =>
      'Search text and Skill content aren’t logged. Sanitized local diagnostics are retained for up to 7 days and never uploaded automatically.';

  @override
  String get diagnosticLogsTitle => 'Diagnostic logs';

  @override
  String diagnosticLogsDescription(String size) {
    return 'Local App and CLI diagnostics use $size. Logs rotate automatically, are retained for up to 7 days, and are never uploaded automatically.';
  }

  @override
  String get openLogFolder => 'Open folder';

  @override
  String get viewLiveLogs => 'View live';

  @override
  String get exportLogs => 'Export logs';

  @override
  String get clearLogs => 'Clear logs';

  @override
  String get logsExported => 'Diagnostic logs exported.';

  @override
  String get logsCleared => 'Diagnostic logs cleared.';

  @override
  String get logActionFailed =>
      'The diagnostic log action could not be completed.';

  @override
  String get logViewerLive => 'Live';

  @override
  String get logViewerPaused => 'Paused';

  @override
  String get searchLogs => 'Search logs';

  @override
  String get allLogLevels => 'All';

  @override
  String get warningLogs => 'Warnings';

  @override
  String get errorLogs => 'Errors';

  @override
  String get pauseLogFollow => 'Pause';

  @override
  String get resumeLogFollow => 'Resume';

  @override
  String get clearViewer => 'Clear view';

  @override
  String get noDiagnosticLogs => 'No matching logs yet.';

  @override
  String get backToLatestLog => 'Latest';

  @override
  String get language => 'Dil';

  @override
  String get originalContent => 'Original';

  @override
  String get translatedContent => 'Çevrildi';

  @override
  String translatedFrom(String language) {
    return '$language dilinden çevrildi';
  }

  @override
  String sourceLanguageName(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'en': 'İngilizce',
      'zhHans': 'Basitleştirilmiş Çince',
      'zhHant': 'Geleneksel Çince',
      'ja': 'Japonca',
      'ko': 'Korece',
      'fr': 'Fransızca',
      'de': 'Almanca',
      'it': 'İtalyanca',
      'es': 'İspanyolca',
      'pt': 'Portekizce',
      'ru': 'Rusça',
      'ar': 'Arapça',
      'hi': 'Hintçe',
      'id': 'Endonezce',
      'tr': 'Türkçe',
      'nl': 'Felemenkçe',
      'pl': 'Lehçe',
      'th': 'Tayca',
      'vi': 'Vietnamca',
      'ms': 'Malayca',
      'sv': 'İsveççe',
      'uk': 'Ukraynaca',
      'other': '$code',
    });
    return '$_temp0';
  }

  @override
  String get showOriginalContent => 'Orijinali göster';

  @override
  String get showTranslation => 'Çeviriyi göster';

  @override
  String get personalizationTheme => 'Tema';

  @override
  String get folderColorTheme => 'Tema rengi';

  @override
  String get folderColorThemeDescription =>
      'Beğendiğiniz bir rengi seçin. SkillsGo bunun etrafında koordineli bir arayüz paleti oluşturacaktır.';

  @override
  String get brandNameNeteaseCloudMusic => 'NetEase Cloud Music';

  @override
  String get brandNameRaspberryPi => 'Raspberry Pi';

  @override
  String get brandNameChinaEasternAirlines => 'China Eastern Airlines';

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
      'Sisteminizin görünümünü takip edin veya her zaman açık veya koyu bir tema kullanın.';

  @override
  String get followSystem => 'Sistem';

  @override
  String get lightMode => 'Işık';

  @override
  String get darkMode => 'Karanlık';

  @override
  String get wallpaper => 'Duvar kağıdı';

  @override
  String get wallpaperDescription =>
      'Göksel bir arka plan seçin. Seçiminiz Folder\'nin hemen arkasında görünür.';

  @override
  String get wallpaperSun => 'Güneş';

  @override
  String get wallpaperMercury => 'Merkür';

  @override
  String get wallpaperVenus => 'Venüs';

  @override
  String get wallpaperEarth => 'Dünya';

  @override
  String get wallpaperMars => 'Mars';

  @override
  String get wallpaperJupiter => 'Jüpiter';

  @override
  String get wallpaperSaturn => 'Satürn';

  @override
  String get wallpaperUranus => 'Uranüs';

  @override
  String get wallpaperNeptune => 'Neptün';

  @override
  String get wallpaperPluto => 'Plüton';

  @override
  String get wallpaperMoon => 'Ay';

  @override
  String folderThemeChoice(String theme) {
    return '$theme Folder teması';
  }

  @override
  String get privacyAffiliation =>
      'Anonim kurulum telemetrisi SkillsGo ayarlarıyla kontrol edilir. SkillsGo, OpenAI veya Codex\'ye bağlı değildir.';

  @override
  String get commandCompleted => 'Komut tamamlandı';

  @override
  String get commandFailed => 'Komut başarısız oldu';

  @override
  String commandExit(int code) {
    return '$code\'den çıkın · bu oturumun günlüğünü genişletin';
  }

  @override
  String get command => 'Komut';

  @override
  String get cancel => 'İptal';

  @override
  String get updateUnknown => 'BİLİNMİYOR';

  @override
  String get updateChecking => 'KONTROL EDİLİYOR';

  @override
  String get upToDate => 'GÜNCEL';

  @override
  String get updateAvailable => 'GÜNCELLEME';

  @override
  String get updateUnavailable => 'MEVCUT DEĞİL';

  @override
  String get updateCheckFailed => 'KONTROL BAŞARISIZ';

  @override
  String get installSkill => 'Skill\'yi yükleyin';

  @override
  String get installLocationTitle => 'Kurulum konumunu ayarlayın';

  @override
  String get globalLevel => 'Global';

  @override
  String get projectLevel => 'Proje Düzeyi';

  @override
  String get projects => 'Projeler';

  @override
  String get loading => 'Yükleniyor…';

  @override
  String get repositoryParsing => 'Depo ayrıştırılıyor…';

  @override
  String globalInstallSummary(int agents) {
    return 'Available globally to $agents Agents';
  }

  @override
  String projectInstallSummary(int projects, int agents) {
    return '$projects projeleri · $agents Agents';
  }

  @override
  String get installationResults => 'Kurulum sonuçları';

  @override
  String get installationInProgress => 'Kurulum devam ediyor';

  @override
  String get installationSucceeded => 'Kurulum tamamlandı';

  @override
  String get installationSucceededMessage =>
      'Skill artık seçilen konumlarda mevcuttur.';

  @override
  String get projectUnavailable => 'Proje kullanılamıyor';

  @override
  String get installedCell => 'Yüklendi';

  @override
  String get unsupportedCell => 'Kullanılamıyor';

  @override
  String get confirmInstall => 'Kurulumu Onaylayın';

  @override
  String installAllPackageSkills(int count) {
    return 'Tüm depo becerilerini yükleyin ($count)';
  }

  @override
  String get installAllSkillsTo => 'Tüm becerileri yükleyin';

  @override
  String installPackageSkills(String packagePath, int count) {
    return 'Tüm $packagePath becerilerini yükleyin ($count)';
  }

  @override
  String installSkillTo(String skill) {
    return '$skill\'yi şuraya yükleyin:';
  }

  @override
  String get availableInAllProjects => 'Tüm projeler';

  @override
  String get availableInSelectedProjects => 'Seçilen projeler';

  @override
  String get usedBy => 'Agents için';

  @override
  String get backToTargets => 'Hedeflere Geri Dön';

  @override
  String get stayHere => 'Burada kal';

  @override
  String get viewInLibrary => 'Kütüphanede Görüntüle';

  @override
  String planCreateCount(int count) {
    return '$count oluştur';
  }

  @override
  String planSkipCount(int count) {
    return '$count atla';
  }

  @override
  String planReplaceCount(int count) {
    return '$count değiştirin';
  }

  @override
  String planConflictCount(int count) {
    return '$count çakışması';
  }

  @override
  String planRiskCount(int count) {
    return '$count riski engellendi';
  }

  @override
  String get refreshInstallationPlan => 'Çözümleri Uygula';

  @override
  String get replaceVersionConflict => 'Bu hedefte yüklü sürümü değiştirin';

  @override
  String get replaceSkillIdCollision =>
      'Bu hedefteki farklı Skill kimliğini değiştirin';

  @override
  String get replaceLocalModification =>
      'Yerel Değişiklikleri atın ve bu hedefi değiştirin';

  @override
  String get sharedTargetConflict =>
      'Bu yol diğer Agent hedefleri tarafından paylaşılıyor';

  @override
  String sharedTargetConflictDescription(String agents) {
    return 'Hedef matrise dönün ve değiştirmeden önce etkilenen her Agent\'yi seçin: $agents';
  }

  @override
  String get replaceConflictingTarget => 'Çakışan hedefi değiştirin';

  @override
  String get confirmHighRiskArtifact => 'Yüksek riskli artefakt onayı';

  @override
  String get confirmCriticalRiskArtifact => 'Kritik riski geçersiz kılma onayı';

  @override
  String get confirmRiskForSelectedTargets =>
      'Yapıt dosyalarını inceledim ve seçilen hedefler için bu riski kabul ettim';

  @override
  String get criticalRiskBlocked => 'Kritik riskli kurulum engellendi';

  @override
  String get criticalRiskOverrideDisabled =>
      'Bu planın devam edebilmesi için Ayarlar\'da açık Kritik risk geçersiz kılma özelliğini etkinleştirin.';

  @override
  String get workspaceManifestChanges => 'Workspace Manifest değişiklikleri';

  @override
  String get noWorkspaceManifestChanges =>
      'Hiçbir Workspace Manifest dosyası değişmeyecek.';

  @override
  String lockVersionChange(String from, String to) {
    return '$from → $to';
  }

  @override
  String get notPresent => 'mevcut değil';

  @override
  String get planActionCreate => 'Oluştur';

  @override
  String get planActionReplace => 'Değiştir';

  @override
  String get planActionSkip => 'Atla';

  @override
  String get planActionConflict => 'Çatışma';

  @override
  String get planActionBlockedByRisk => 'Risk nedeniyle engellendi';

  @override
  String installationResultSummary(int succeeded, int failed) {
    return '$succeeded hedefleri kuruldu, $failed başarısız oldu';
  }

  @override
  String get installationProgressTitle => 'Kurulum devam ediyor';

  @override
  String installationProgressSummary(int finished, int total) {
    return '$total hedeflerinden $finished tamamlandı';
  }

  @override
  String get targetWaiting => 'Bekliyor';

  @override
  String get targetRunning => 'Kurulum';

  @override
  String retryFailedTargets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Başarısız $count hedefi yeniden dene',
      one: 'Başarısız 1 hedefi yeniden dene',
    );
    return '$_temp0';
  }

  @override
  String get updatePlanTitle => 'Güncellenecek hedefleri seçin';

  @override
  String get updatePlanDescription =>
      'Kesin Kurulum Hedeflerini seçin. Seçili olmayan Agents ve projeler değişmeden kalır.';

  @override
  String updateTargetsSelected(int selected, int available) {
    return '$available güncellenebilir hedeflerinden $selected seçildi';
  }

  @override
  String updateVersionChange(String fromVersion, String toVersion) {
    return '$fromVersion → $toVersion';
  }

  @override
  String sourceReference(String reference) {
    return 'Kaynak referansı: $reference';
  }

  @override
  String get fixedVersionTarget => 'Sabitlendi — taşınabilir referans yok';

  @override
  String get currentVersionTarget => 'güncel';

  @override
  String get updateCheckTargetFailed => 'Güncelleme kontrolü başarısız oldu';

  @override
  String get reconcileWorkspaceManifestTarget =>
      'Çalışma alanı bildirimini onar';

  @override
  String get updateSelectedTargets => 'Seçilen hedefleri güncelle';

  @override
  String get updateProgressTitle => 'Hedefler güncelleniyor';

  @override
  String get updateResultsTitle => 'Sonuçları güncelle';

  @override
  String updateProgressSummary(int finished, int total) {
    return '$total hedeflerinden $finished tamamlandı';
  }

  @override
  String retryFailedUpdates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Başarısız $count güncellemeyi yeniden dene',
      one: 'Başarısız 1 güncellemeyi yeniden dene',
    );
    return '$_temp0';
  }

  @override
  String get noUpdateableTargets =>
      'Seçilen hiçbir hedefin kullanılabilir bir güncellemesi yok.';

  @override
  String get closeUpdatePlan => 'Kapat';

  @override
  String get targetSucceeded => 'Yüklendi';

  @override
  String get targetSkipped => 'Atlandı';

  @override
  String get targetConflict => 'Çatışma';

  @override
  String get targetFailed => 'Başarısız';

  @override
  String get targetFailureRetryable =>
      'Bu konum değiştirilemedi. Tekrar deneyebilirsiniz.';

  @override
  String get targetFailureNeedsAttention =>
      'Tekrar denemeden önce bu konumla ilgilenmeniz gerekiyor.';

  @override
  String get installationTargetFailureMessage =>
      'Bu konumda hiçbir şey değişmedi. Klasörün mevcut olup olmadığını kontrol edin ve tekrar deneyin.';

  @override
  String get workspacePersistenceFailureMessage =>
      'SkillsGo proje ayarlarını kaydedemediğinden hiçbir şey değişmedi. Proje klasörünün yazılabilir olup olmadığını kontrol edin ve tekrar deneyin.';

  @override
  String get installationStateChangedMessage =>
      'Siz incelerken bu konum değişti. Tekrar denemeden önce son durumu inceleyin.';

  @override
  String get updateTargetFailureMessage =>
      'Bu konum güncellenemedi. Diğer konumlar etkilenmediğinden yalnızca bunu yeniden deneyebilirsiniz.';

  @override
  String get managementTargetFailureMessage =>
      'Bu işlem burada tamamlanamadı. Diğer konumlar etkilenmediğinden yalnızca bunu yeniden deneyebilirsiniz.';

  @override
  String get technicalDetails => 'Teknik detaylar';

  @override
  String get targetPathExists => 'Bu konumda başka bir öğe zaten mevcut.';

  @override
  String get targetBlockedByRisk =>
      'Mevcut güvenlik ayarlarınız bu konuma kurulumu engelledi.';

  @override
  String get targetInstallFailed => 'Beceri bu konuma yüklenemedi.';

  @override
  String get targetWorkspaceUpdateFailed =>
      'Beceri yüklendi ancak proje ayarları güncellenemedi.';

  @override
  String get installationPlanFailed => 'Kurulum planı devam edemedi';

  @override
  String get installationFailed => 'Kurulum tamamlanamadı';

  @override
  String get localSource => 'Yerel kaynak';

  @override
  String get noDescriptionAvailable => 'Açıklama mevcut değil';

  @override
  String moreCoverage(int count) {
    return '+$count daha fazla konum';
  }

  @override
  String get batchAdoptionAction => 'Mevcut becerileri yönetin';

  @override
  String handExternalSkillsToSkillsGoManagementCount(int count) {
    return 'Let SkillsGo manage $count external skills';
  }

  @override
  String confirmSkillsGoManagementCount(int selected, int total) {
    return 'Confirm SkillsGo management ($selected/$total)';
  }

  @override
  String get skillColumnLabel => 'Skill';

  @override
  String get packageSourceColumnLabel => 'Source';

  @override
  String get versionColumnLabel => 'Version';

  @override
  String get packageMatching => 'Matching sources…';

  @override
  String get sourceMatchUnavailable => 'Source matching unavailable';

  @override
  String get noSourceMatches => 'No matching source';

  @override
  String sourceMatchPercent(int percent) {
    return '$percent% match';
  }

  @override
  String get versionPendingSelection => 'Select a source first';

  @override
  String batchAdoptionActionCount(int count) {
    return 'Yönet ($count)';
  }

  @override
  String get batchAdoptionChecking => 'Mevcut beceriler kontrol ediliyor…';

  @override
  String get batchAdoptionRetry =>
      'Yönetilebilir becerileri tekrar kontrol edin';

  @override
  String batchAdoptionEligibleCount(int count) {
    return '$count yönetilebilir';
  }

  @override
  String get batchAdoptionPending => 'Yönetime beceriler katmak…';

  @override
  String get batchAdoptionTitle =>
      'SkillsGo ile mevcut becerilerinizi yönetin mi?';

  @override
  String get batchAdoptionDescription =>
      'SkillsGo, beceri dosyalarını taşımadan, üzerine yazmadan veya yüklemeden yerel yönetim kayıtlarını ekleyecektir. Desteklenmeyen veya değiştirilen öğeler atlanacaktır.';

  @override
  String get batchAdoptionStoryTitle =>
      'Dağınık becerileri tek bir temiz Kitaplığa dönüştürün';

  @override
  String batchAdoptionStoryDescription(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mevcut Skills',
      one: '1 mevcut Skill',
    );
    return 'SkillsGo bu konumda yönetebileceği $_temp0 buldu.';
  }

  @override
  String get batchAdoptionBeforeSemantics =>
      'Yönetimden önce mevcut becerilerin nereye yüklendiği, güncel olup olmadığı, nasıl kurtarılacağı veya projelerin aynı sürümü kullanıp kullanmadığı belirsizdir.';

  @override
  String get batchAdoptionPainLocation => 'Bilinmeyen yükleme konumu';

  @override
  String get batchAdoptionPainFreshness => 'Bilinmeyen güncelleme durumu';

  @override
  String get batchAdoptionPainRecovery => 'Kırıldığında iyileşme yok';

  @override
  String get batchAdoptionPainVersionDrift =>
      'Projeler arasında farklı versiyonlar';

  @override
  String get batchAdoptionFolderTitle => 'Mevcut Skills';

  @override
  String get batchAdoptionFolderSubtitle => 'Belirsiz durum';

  @override
  String get batchAdoptionAfterLabel => 'SONRA';

  @override
  String get batchAdoptionAfterTitle => 'Temiz bir Kütüphane';

  @override
  String get batchAdoptionLibraryTitle => 'SkillsGo Kütüphanesi';

  @override
  String get batchAdoptionBenefitLocation => 'Konumları temizle';

  @override
  String get batchAdoptionBenefitFreshness => 'Güncellemeler görünüyor';

  @override
  String get batchAdoptionBenefitRecovery => 'Kolay kurtarma';

  @override
  String get batchAdoptionBenefitVersions => 'Sürümler temiz';

  @override
  String get batchAdoptionManagedSection =>
      'SkillsGo tarafından yönetilmektedir';

  @override
  String get batchAdoptionPendingSection => 'Beklemede';

  @override
  String batchAdoptionItemManaged(String name) {
    return '$name, SkillsGo tarafından yönetilmektedir';
  }

  @override
  String batchAdoptionItemSkipped(String name) {
    return '$name yönetime eklenemedi';
  }

  @override
  String batchAdoptionItemPending(String name) {
    return '$name yönetilmeyi bekliyor';
  }

  @override
  String batchAdoptionAfterSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Skills',
      one: '1 Skill',
    );
    return 'Yönetimden sonra $_temp0, yönetim durumu açıkça görülen tek bir Library içinde düzenlenir.';
  }

  @override
  String batchAdoptionMoreSkills(int count) {
    return '+$count daha fazla';
  }

  @override
  String get batchAdoptionTransitionSemantics =>
      'Bu mevcut becerileri SkillsGo yönetimine ekleyin.';

  @override
  String get batchAdoptionTransitionLabel => 'ORGANİZE EDİN';

  @override
  String get batchAdoptionStatusTitle => 'Yönetim durumu';

  @override
  String get batchAdoptionStatusManaged => 'Yönetilen';

  @override
  String get batchAdoptionStatusProgress => 'Düzenleme';

  @override
  String get batchAdoptionStatusSkipped => 'Atlandı';

  @override
  String get batchAdoptionStatusFilesStay =>
      'Skill dosyaları orijinal konumlarında kalır';

  @override
  String get batchAdoptionBoardSemantics =>
      'Skills, tam satırlar halinde düzenlenir ve dosyaları taşınmadan SkillsGo tarafından kaydedilir.';

  @override
  String get batchAdoptionBoardComplete => 'HEPSİ TEMİZ';

  @override
  String get batchAdoptionBoardPartial => 'TAMAMLANDI';

  @override
  String get batchAdoptionStatusTotal => 'Toplam';

  @override
  String get batchAdoptionQueueComplete => 'Hiçbir beceri beklemiyor';

  @override
  String get batchAdoptionQueueWaiting =>
      'Doğrulamadan sonra Skill’ler burada görünecek';

  @override
  String get batchAdoptionNextLabel => 'SONRAKİ';

  @override
  String batchAdoptionFillerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count SkillsGo düzenleyici bloğu',
      one: '1 SkillsGo düzenleyici bloğu',
    );
    return '$_temp0 son satırları tamamlar.';
  }

  @override
  String get batchAdoptionPreservation =>
      'Dosyalarınız, yollarınız ve mevcut iş akışlarınız tam olarak oldukları yerde kalır. SkillsGo yalnızca yerel yönetim kayıtlarını tamamlar.';

  @override
  String get batchAdoptionLaterHint =>
      'Atlarsanız istediğiniz zaman Kitaplık\'taki Mevcut becerileri yönet seçeneğini kullanabilirsiniz.';

  @override
  String get batchAdoptionSkip => 'Şimdi değil';

  @override
  String get batchAdoptionConfirm => 'Yönetime ekle';

  @override
  String get batchAdoptionExecutionRetry => 'Yeniden dene';

  @override
  String get batchAdoptionResultTitle => 'Skill’ler yönetime eklendi';

  @override
  String batchAdoptionSummary(int adopted, int skipped) {
    return 'Yönetime $adopted becerileri eklendi, $skipped atlandı.';
  }

  @override
  String batchAdoptionFailureSummary(int adopted, int failed) {
    return '$adopted skills added to management, $failed failed.';
  }

  @override
  String get batchAdoptionStatusFailed => 'Failed';

  @override
  String batchAdoptionItemFailed(String name) {
    return '$name failed';
  }

  @override
  String get batchAdoptionClose => 'Kapat';

  @override
  String get installMoreTargets => 'Daha fazla konuma yükleyin';

  @override
  String get detailPackageSource => 'Paket kaynağı';

  @override
  String get detailStars => 'Yıldızlar';

  @override
  String get detailUpdated => 'Güncellendi';

  @override
  String get detailArchiveSize => 'Paket boyutu';

  @override
  String get pathLabel => 'Proje yolu';

  @override
  String get copyProjectPath => 'Proje yolunu kopyala';

  @override
  String get projectPathCopied => 'Proje yolu kopyalandı';

  @override
  String get onboardingWelcomeTitle => 'SkillsGo\'ye hoş geldiniz';

  @override
  String get onboardingWelcomeDescription =>
      'Agent’larınız ve projeleriniz genelinde Skill’leri keşfedin, yükleyin ve yönetin.';

  @override
  String get onboardingDetectedAgents => 'Algılanan Agents';

  @override
  String get onboardingNoAgents =>
      'Yüklü bir Agent algılanmadı. Yine de devam edebilirsiniz.';

  @override
  String get onboardingNext => 'Sonraki';

  @override
  String get onboardingProjectsTitle => 'Projelerinizi ekleyin';

  @override
  String get onboardingProjectsDescription =>
      'SkillsGo\'nin yönetmesini istediğiniz projeleri seçin.';

  @override
  String get onboardingAddProject => 'Şimdi ekle';

  @override
  String get onboardingAddProjectLater => 'veya daha sonra';

  @override
  String get onboardingStartUsing => 'SkillsGo\'yi Kullanmaya Başlayın';

  @override
  String get onboardingBack => 'Geri';

  @override
  String get restartOnboardingTitle => 'İlk katılım';

  @override
  String get restartOnboardingDescription =>
      'Projeleri, ayarları veya Skills verilerini kaldırmadan ilk lansman kılavuzunu yeniden görüntüleyin.';

  @override
  String get restartOnboardingAction => 'İlk Katılımı Yeniden Başlatın';

  @override
  String get restartOnboardingFailed =>
      'SkillsGo ilk kurulumu yeniden başlatamadı.';

  @override
  String get libraryRefreshSettingsTitle => 'Yerel Kitaplığı yenile';

  @override
  String get libraryRefreshSettingsDescription =>
      'Yüklü Skills, Eklenen Projeler, Agents ve yönetilebilen harici Skills\'yi yeniden tarayın. Bu hiçbir şeyi yüklemez, güncellemez veya kaldırmaz.';

  @override
  String get libraryRefreshSettingsAction => 'Kitaplığı Yenile';

  @override
  String get libraryRefreshSettingsPending => 'Kütüphane yenileniyor…';

  @override
  String get libraryRefreshSettingsSuccess => 'Yerel Kütüphane yenilendi.';

  @override
  String get libraryRefreshSettingsFailed =>
      'SkillsGo yerel Kitaplığı yenileyemedi.';

  @override
  String get onboardingProjectError => 'SkillsGo bu dizinden proje ekleyemedi.';

  @override
  String get onboardingProjectsLoadError =>
      'SkillsGo eklediğiniz projelerinizi yükleyemedi.';

  @override
  String get onboardingStartupError => 'SkillsGo kurulumu yükleyemedi.';

  @override
  String get onboardingStateError =>
      'SkillsGo kurulum ilerlemenizi kaydedemedi. Tekrar deneyin.';

  @override
  String get onboardingCliErrorTitle =>
      'SkillsGo CLI\'nin ilgilenilmesi gerekiyor';

  @override
  String get onboardingCliErrorDescription =>
      'Birlikte verilen CLI\'yi onarın ve devam etmeyi yeniden deneyin.';

  @override
  String get removeSkillsDescription => 'The following Skills will be removed';

  @override
  String confirmRemoveSkillsInline(int count) {
    return 'Remove $count Skills?';
  }

  @override
  String removingSkillsProgress(int finished, int total) {
    return 'Removing $finished/$total';
  }

  @override
  String get confirmRemoveSkillsAction => 'Remove now';

  @override
  String get viewRemovalDetails => 'View details';

  @override
  String get hideRemovalDetails => 'Hide details';
}
