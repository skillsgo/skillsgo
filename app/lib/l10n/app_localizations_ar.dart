// ignore_for_file: text_direction_code_point_in_literal, text_direction_code_point_in_comment

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get discover => 'اكتشف';

  @override
  String get discoverSkills => 'من المفيد دائمًا معرفة المزيد.';

  @override
  String get library => 'المكتبة';

  @override
  String get settings => 'الإعدادات';

  @override
  String get openSettings => 'افتح الإعدادات';

  @override
  String get cliNeedsAttention => 'يحتاج مكون SkillsGo المطلوب إلى الاهتمام.';

  @override
  String get cliMissingBundled =>
      'أحد مكونات SkillsGo المطلوبة مفقود أو لا يمكن بدء تشغيله. أعد تثبيت SkillsGo لاستعادته.';

  @override
  String get cliDamagedBundled =>
      'أحد مكونات SkillsGo المطلوبة تالف. أعد تثبيت SkillsGo لاستعادته.';

  @override
  String get cliIncompatibleBundled =>
      'لا يتطابق مكون SkillsGo المطلوب مع إصدار التطبيق هذا. قم بتحديث أو إعادة تثبيت SkillsGo.';

  @override
  String get officialIndex => 'SkillsGo Hub';

  @override
  String get discoverTitle => 'اعثر على Skill لخطوتك التالية.';

  @override
  String get skillsLeaderboard => 'من المفيد دائمًا معرفة المزيد.';

  @override
  String searchResultsFor(String query) {
    return 'نتائج ل “⁨$query⁩”';
  }

  @override
  String get searchSkills => 'ابحث عن Skills أو الصق رابط Git…';

  @override
  String get search => 'بحث';

  @override
  String get ranking => 'الترتيب';

  @override
  String get trending => 'الرائجة';

  @override
  String get hot => 'الأكثر رواجًا';

  @override
  String get discoverNavigation => 'التنقل في قسم الاستكشاف';

  @override
  String get allTimeRanking => 'الترتيب عبر جميع الفترات';

  @override
  String get trendingNow => 'الرائجة خلال آخر 24 ساعة';

  @override
  String get hotNow => 'الأكثر رواجًا الآن';

  @override
  String get allTimeDescription =>
      'Skills عامة مرتبة حسب إجمالي عمليات التثبيت المقبولة.';

  @override
  String get trendingDescription =>
      'Skills عامة مرتبة حسب عمليات التثبيت المقبولة خلال آخر 24 ساعة.';

  @override
  String get hotDescription =>
      'Skills عامة مرتبة حسب سرعة التثبيت الأخيرة ومعدل تغيرها.';

  @override
  String get offlineTitle => 'لا يمكن الاتصال بـ SkillsGo';

  @override
  String get offlineMessage =>
      'تحقق من اتصالك بالإنترنت وحاول مرة أخرى. إذا كنت تستخدم وكيلًا أو عنوان خدمة مخصصًا، فراجعه في الإعدادات.';

  @override
  String get searchFailedTitle => 'تعذر البحث';

  @override
  String get validationTitle => 'تحقق مما قمت بإدخاله';

  @override
  String get validationMessage =>
      'تعذر على SkillsGo استخدام هذا الطلب. راجع ما أدخلته وحاول مرة أخرى.';

  @override
  String get serverTitle => 'الخدمة غير متاحة مؤقتا';

  @override
  String get serverMessage =>
      'لا يستطيع SkillsGo إكمال هذا الطلب الآن. حاول مرة أخرى بعد قليل.';

  @override
  String get timeoutTitle => 'هذا يستغرق وقتا طويلا';

  @override
  String get timeoutMessage =>
      'الخدمة لم تستجب في الوقت المناسب. تحقق من اتصالك أو حاول مرة أخرى.';

  @override
  String get invalidResponseTitle => 'يجب تحديث SkillsGo';

  @override
  String get invalidResponseMessage =>
      'لا يمكن قراءة هذه الاستجابة بواسطة إصدار SkillsGo الخاص بك. قم بتحديث التطبيق، ثم حاول مرة أخرى.';

  @override
  String get invalidLocalDataTitle => 'تعذرت قراءة Skill مثبتة';

  @override
  String get invalidLocalDataMessage =>
      'بعض معلومات التثبيت المحلية تالفة أو غير متوافقة. قم بتحديث SkillsGo أو أعد تثبيته، ثم حاول مرة أخرى.';

  @override
  String get tryAgain => 'حاول مرة أخرى';

  @override
  String get searchEmptyTitle => 'ابحث بدلًا من التمرير.';

  @override
  String get searchEmptyMessage =>
      'أدخل قدرة أو مصدرًا أو مهمة للبحث في Skills العامة.';

  @override
  String get noSkillsTitle => 'لم يتم العثور على Skills';

  @override
  String get noSkillsMessage => 'جرب عبارة أوسع أو تحقق من الإملاء.';

  @override
  String get focusSearch => 'الانتقال إلى البحث';

  @override
  String get skillsFromLink => 'Skills الموجودة في هذا الرابط';

  @override
  String skillCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$count⁩ Skill',
      many: '⁨$count⁩ Skill',
      few: '⁨$count⁩ Skills',
      two: 'Skill اثنتان',
      one: 'Skill واحدة',
      zero: 'لا توجد Skills',
    );
    return '$_temp0';
  }

  @override
  String sourceResultsSummary(String source, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$count⁩ Skill من ⁨$source⁩',
      many: '⁨$count⁩ Skill من ⁨$source⁩',
      few: '⁨$count⁩ Skills من ⁨$source⁩',
      two: 'Skill اثنتان من ⁨$source⁩',
      one: 'Skill واحدة من ⁨$source⁩',
      zero: 'لا توجد Skills من ⁨$source⁩',
    );
    return '$_temp0';
  }

  @override
  String get sourceSearchEmptyTitle => 'هذا الرابط جاهز للفحص';

  @override
  String sourceSearchEmptyMessage(String source) {
    return '⁨$source⁩ غير موجود في نتائج البحث الحالية. يمكن لـ SkillsGo فحص الرابط مباشرة في الخطوة التالية.';
  }

  @override
  String get inspectSource => 'عرض Skills الموجودة في هذا الرابط';

  @override
  String get collectionEmptyTitle => 'لا توجد Skills في هذه المجموعة';

  @override
  String get collectionEmptyMessage =>
      'لا يوجد شيء هنا بعد. حاول مرة أخرى بعد المزيد من أنشطة التثبيت.';

  @override
  String get loadMore => 'تحميل المزيد';

  @override
  String get install => 'تثبيت';

  @override
  String get installAll => 'تثبيت جميع Skills';

  @override
  String get latestCommit => 'أحدث Commit';

  @override
  String get installToMoreTargets => 'التثبيت في مواقع إضافية';

  @override
  String localTargets(int count) {
    return '⁨$count⁩ الأهداف المحلية';
  }

  @override
  String allTimeMetric(String count) {
    return '⁨$count⁩ عملية تثبيت إجمالًا';
  }

  @override
  String trendingMetric(String count) {
    return '⁨$count⁩ عملية تثبيت خلال 24 ساعة';
  }

  @override
  String hotMetric(String value, String change) {
    return '⁨$value⁩ هذه الساعة · ⁨$change⁩';
  }

  @override
  String get trustUnverified => 'غير موثّق';

  @override
  String get trustCommunityVerified => 'موثّق من المجتمع';

  @override
  String get trustPublisherVerified => 'موثّق من الناشر';

  @override
  String get trustOfficial => 'رسمي';

  @override
  String get trustWarned => 'عليه تحذير';

  @override
  String get trustDelisted => 'أزيل من القائمة';

  @override
  String get riskUnknown => 'خطر غير معروف';

  @override
  String get riskLow => 'مخاطر منخفضة';

  @override
  String get riskMedium => 'مخاطر متوسطة';

  @override
  String get riskHigh => 'مخاطر عالية';

  @override
  String get riskCritical => 'مخاطر حرجة';

  @override
  String openSkill(String name) {
    return 'افتح ⁨$name⁩';
  }

  @override
  String installs(String count) {
    return 'تثبيت ⁨$count⁩';
  }

  @override
  String get detailFailedTitle => 'تعذر تحميل هذه Skill';

  @override
  String get detailLoading => 'جارٍ تحميل تفاصيل Skill القابلة للتدقيق';

  @override
  String get artifactUnavailableTitle => 'الـ Artifact غير متاح';

  @override
  String get artifactUnavailableMessage =>
      'هذا الإصدار غير متاح حاليًا. حاول مجددًا أو اختر إصدارًا آخر.';

  @override
  String get detailInvalidTitle => 'بيانات Artifact الوصفية غير مدعومة';

  @override
  String get detailInvalidMessage =>
      'بعض التفاصيل الخاصة بهذه المهارة غير مكتملة أو لا يمكن قراءتها. قم بتحديث SkillsGo، ثم حاول مرة أخرى.';

  @override
  String get instructionsTab => 'تعليمات';

  @override
  String get manifestTab => 'ملف Manifest';

  @override
  String immutableVersionLabel(String version) {
    return 'الإصدار الثابت ⁨$version⁩';
  }

  @override
  String commitIdentity(String sha) {
    return 'Commit ⁨$sha⁩';
  }

  @override
  String treeIdentity(String sha) {
    return 'Tree ⁨$sha⁩';
  }

  @override
  String contentIdentity(String digest) {
    return 'المحتوى ⁨$digest⁩';
  }

  @override
  String get trustDoesNotProveSafety =>
      'توثيق الناشر يثبت الملكية أو الصيانة، لكنه لا يضمن سلامة Artifact. تُقيَّم المخاطر بشكل مستقل لهذا الإصدار الثابت.';

  @override
  String get knownInstallationTargets => 'أهداف التثبيت المعروفة';

  @override
  String get installationRange => 'نطاق التثبيت';

  @override
  String get targetDetails => 'عرض تفاصيل الهدف';

  @override
  String get hideTargetDetails => 'إخفاء تفاصيل الهدف';

  @override
  String installedVersionLabel(String version) {
    return 'الإصدار ⁨$version⁩';
  }

  @override
  String targetSummary(String scope, String agent, String version) {
    return '⁨$scope⁩ / ⁨$agent⁩ · ⁨$version⁩';
  }

  @override
  String get projectScope => 'مشروع';

  @override
  String get fileContentUnavailable => 'معاينة ثنائية أو غير متاحة';

  @override
  String get fileContentTruncated => 'اقتُطعت المعاينة وفق حد الأمان في Hub.';

  @override
  String get retry => 'أعد المحاولة';

  @override
  String get backToSearch => 'العودة إلى البحث';

  @override
  String get installForCodex => 'التثبيت لـ Codex';

  @override
  String get cliNotDetected => 'skills (غير مكتشف)';

  @override
  String get snapshotFiles => 'ملفات اللقطة';

  @override
  String get globalCodex => 'عام · Codex';

  @override
  String get yourLibrary => 'كل ما تديره في مكان واحد.';

  @override
  String get libraryNavigation => 'التنقل في المكتبة';

  @override
  String get all => 'الكل';

  @override
  String get allSkills => 'جميع Skills';

  @override
  String get updatesOnly => 'التحديثات';

  @override
  String get allAgents => 'جميع Agents';

  @override
  String get allProjects => 'جميع المشاريع';

  @override
  String get specificProject => 'مشروع';

  @override
  String get userScope => 'عام';

  @override
  String get addProject => 'أضف المشروع';

  @override
  String get relocateProject => 'تغيير الموقع';

  @override
  String get removeFromList => 'إزالة من القائمة';

  @override
  String removeProjectTitle(String name) {
    return 'إزالة ⁨$name⁩ من SkillsGo؟';
  }

  @override
  String get removeProjectDescription =>
      'ستتم إزالة مرجع التطبيق فقط. لن يقوم SkillsGo بتغيير أو حذف أي ملفات في هذا الدليل.';

  @override
  String projectRailUnavailable(String name) {
    return '⁨$name⁩ — غير متاح';
  }

  @override
  String get emptyProjectTitle => 'لا توجد Skills بعد';

  @override
  String get browseSkills => 'تصفح Skills';

  @override
  String get projectMissingTitle => 'دليل المشروع مفقود';

  @override
  String get projectMissingMessage =>
      'ربما نُقل المجلد أو أصبحت وحدة التخزين غير متصلة. غيّر موقعه أو أزل مرجع التطبيق فقط.';

  @override
  String get projectPermissionTitle => 'يلزم إذن للوصول إلى مجلد المشروع';

  @override
  String get projectPermissionMessage =>
      'يتعذر على SkillsGo فحص هذا المجلد. حدده مجددًا عبر منتقي المجلدات لمنح الإذن.';

  @override
  String get projectInaccessibleTitle => 'دليل المشروع غير قابل للوصول';

  @override
  String get projectInaccessibleMessage =>
      'احتفظ SkillsGo بمرجع المشروع هذا. تحقق من المسار أو وحدة التخزين، ثم قم بنقله.';

  @override
  String get checking => 'جارٍ التحقق…';

  @override
  String get checkUpdates => 'التحقق من التحديثات';

  @override
  String get refresh => 'تحديث';

  @override
  String get libraryUnavailable => 'المكتبة غير متوفرة';

  @override
  String get libraryEmpty => 'لم تُثبَّت أي Skills بعد';

  @override
  String get libraryEmptyMessage => 'ثبّت Skill من قسم الاستكشاف وستظهر هنا.';

  @override
  String get searchLibrary => 'بحث المهارات المثبتة';

  @override
  String get libraryNoMatches => 'لا توجد Skills مطابقة';

  @override
  String get libraryNoMatchesMessage =>
      'جرب اسمًا أو مصدرًا أو Agent أو مشروعًا أو إصدارًا مختلفًا.';

  @override
  String agentsSummary(int count) {
    return '⁨$count⁩ Agents';
  }

  @override
  String projectsSummary(int count) {
    return 'مشاريع ⁨$count⁩';
  }

  @override
  String versionsSummary(int count) {
    return 'إصدارات ⁨$count⁩';
  }

  @override
  String get hubManaged => 'بإدارة Hub';

  @override
  String get localManaged => 'مُدار محليًا';

  @override
  String get externalInstallation => 'التثبيت الخارجي';

  @override
  String get readOnly => 'للقراءة فقط';

  @override
  String get unversioned => 'بلا إصدار';

  @override
  String get supportingFiles => 'الملفات الداعمة';

  @override
  String get versionDivergence => 'اختلاف الإصدار';

  @override
  String get healthHealthy => 'صحي';

  @override
  String get healthMissing => 'الهدف مفقود';

  @override
  String get healthReplaced => 'تم استبدال الهدف';

  @override
  String get healthLocalModification => 'التعديل المحلي';

  @override
  String get healthUnreadable => 'الهدف غير قابل للقراءة';

  @override
  String get healthUndeclared => 'لم يعلن';

  @override
  String get healthWorkspaceUnreadable => 'حالة مساحة العمل غير قابلة للقراءة';

  @override
  String get healthLockMismatch => 'عدم تطابق القفل';

  @override
  String get healthUnexpectedPath => 'مسار هدف غير متوقع';

  @override
  String get modeExternal => 'خارجي';

  @override
  String get notLinked => 'غير مرتبط';

  @override
  String get update => 'تحديث';

  @override
  String get backToLibrary => 'العودة إلى المكتبة';

  @override
  String get remove => 'إزالة';

  @override
  String get manageTargets => 'إدارة النطاق';

  @override
  String skillsSelected(int count) {
    return 'تم تحديد ⁨$count⁩';
  }

  @override
  String get clearSelection => 'مسح التحديد';

  @override
  String get selectCurrentResults => 'حدد النتائج الحالية';

  @override
  String get clearCurrentResultSelection => 'مسح تحديد النتيجة الحالية';

  @override
  String get manageTargetsTitle => 'إدارة أهداف التثبيت';

  @override
  String get manageTargetsDescription =>
      'اختر الإجراء الدقيق لكل هدف. لن تتغير الأهداف غير المحددة.';

  @override
  String targetActionsSelected(int selected, int total) {
    return 'تم تحديد أهداف ⁨$selected⁩ لـ ⁨$total⁩';
  }

  @override
  String get confirmRemoveTarget => 'تأكيد الإزالة';

  @override
  String get applyTargetActions => 'تطبيق الإجراءات المحددة';

  @override
  String get managementProgressTitle => 'تطبيق الإجراءات المستهدفة';

  @override
  String get managementResultsTitle => 'نتائج إجراءات الأهداف';

  @override
  String managementResultSummary(int succeeded, int failed) {
    return 'نجح ⁨$succeeded⁩، وفشل ⁨$failed⁩';
  }

  @override
  String get workspaceOwnershipChanges =>
      'سيتم تحديث إجراءات المشروع المحددة skillsgo.yaml وskillsgo.lock.';

  @override
  String get targetContentPreserved =>
      'سيتم الحفاظ على المحتوى المستهدف الحالي.';

  @override
  String get localReadFailed => 'تعذرت قراءة هذه Skill';

  @override
  String get localReadFailedMessage =>
      'تعذر على SkillsGo قراءة Skill المثبتة. تأكد من وجود مجلدها وإمكانية الوصول إليه، ثم حاول مجددًا.';

  @override
  String get localConfiguration => 'إعدادات SkillsGo';

  @override
  String get settingsNavigation => 'التنقل في الإعدادات';

  @override
  String get general => 'التخصيص';

  @override
  String get agents => 'Agents';

  @override
  String get hub => 'Hub';

  @override
  String get installationPolicy => 'سياسة التثبيت';

  @override
  String get storage => 'التخزين';

  @override
  String get colorScheme => 'معاينة الألوان';

  @override
  String get about => 'حول';

  @override
  String get colorSchemeInspectorTitle => 'أدوار الألوان المُنشأة في Material';

  @override
  String get skillsColorTokensTitle => 'ألوان SkillsGo الدلالية';

  @override
  String get skillsColorTokensDescription =>
      'تم إنشاء ألوان المنتج من Radix Sand وتم تنظيمها باستخدام دلالات Primer، مع Folder كتسلسل هرمي مكاني مخصص.';

  @override
  String get colorSchemeInspectorDescription =>
      'قم بمعاينة كل رمز ColorScheme غير المهمل الذي تم إنشاؤه من البذرة الحالية. انقر فوق لون لنسخ قيمته HEX.';

  @override
  String get colorSchemePairPreview => 'أزواج الألوان الدلالية';

  @override
  String get colorSchemePairPreviewDescription =>
      'يتم عرض الأدوار الأمامية والخلفية معًا لكشف التباين والتسلسل الهرمي.';

  @override
  String get colorSchemeComponentPreview => 'معاينة المكونات';

  @override
  String get colorSchemeComponentPreviewDescription =>
      'تم تقديم عناصر تحكم Material التمثيلية باستخدام نظام المعاينة الدقيق هذا.';

  @override
  String get colorSchemeSampleTitle => 'عنوان بطاقة Skill';

  @override
  String get colorSchemeSampleBody =>
      'تستخدم النسخة الثانوية onSurfaceVariant.';

  @override
  String get colorSchemeCopied => 'تم النسخ';

  @override
  String get colorSchemeSampleGlyphs => 'أأ 123';

  @override
  String get colorSchemeGroupPrimary => 'اللون الأساسي';

  @override
  String get colorSchemeGroupPrimaryDescription =>
      'التركيز الأساسي والحاويات وأدوار اللكنة الثابتة.';

  @override
  String get colorSchemeGroupSecondary => 'اللون الثانوي';

  @override
  String get colorSchemeGroupSecondaryDescription =>
      'دعم التركيز والأدوار الثانوية الثابتة.';

  @override
  String get colorSchemeGroupTertiary => 'اللون الثالثي';

  @override
  String get colorSchemeGroupTertiaryDescription =>
      'درجات لونية متباينة وأدوار ثابتة للون الثالثي.';

  @override
  String get colorSchemeGroupSurface => 'السطح';

  @override
  String get colorSchemeGroupSurfaceDescription =>
      'الصفحة والحاوية والارتفاع والتسلسل الهرمي الأمامي.';

  @override
  String get colorSchemeGroupUtility => 'الحدود والأدوات';

  @override
  String get colorSchemeGroupUtilityDescription =>
      'الحدود والظلال والخدوش والأسطح المعكوسة.';

  @override
  String get colorSchemeGroupError => 'خطأ';

  @override
  String get colorSchemeGroupErrorDescription =>
      'إجراءات الخطأ والرسائل والحاويات.';

  @override
  String get colorSchemeUsagePrimary =>
      'الإجراءات الأساسية والتركيز واللهجات عالية التركيز.';

  @override
  String get colorSchemeUsageSecondary =>
      'الإجراءات الداعمة واللهجات متوسطة التركيز.';

  @override
  String get colorSchemeUsageTertiary =>
      'لهجات متناقضة تكمل الابتدائي والثانوي.';

  @override
  String colorSchemeUsageContentOn(String token) {
    return 'النص والأيقونات المعروضة على ⁨$token⁩.';
  }

  @override
  String colorSchemeUsageContainer(String family) {
    return 'حاوية ⁨$family⁩ ذات التركيز المنخفض للتحديدات واللهجات.';
  }

  @override
  String colorSchemeUsageFixed(String family) {
    return 'حاوية ⁨$family⁩ ثابتة ومستقلة عن السطوع.';
  }

  @override
  String colorSchemeUsageFixedDim(String family) {
    return 'حاوية ⁨$family⁩ ثابتة ومستقلة عن السطوع.';
  }

  @override
  String colorSchemeUsageFixedContent(String family) {
    return 'محتوى عالي التركيز على حاوية ⁨$family⁩ الثابتة.';
  }

  @override
  String colorSchemeUsageFixedVariantContent(String family) {
    return 'محتوى التركيز المنخفض على حاوية ⁨$family⁩ الثابتة.';
  }

  @override
  String get colorSchemeUsageSurface => 'الصفحة الأساسية وسطح المنطقة الكبيرة.';

  @override
  String get colorSchemeUsageSurfaceDim =>
      'سطح قاعدة خافت يستخدم في أحلك درجة لون السطح.';

  @override
  String get colorSchemeUsageSurfaceBright =>
      'سطح قاعدة ساطع يستخدم بأخف درجة لون للسطح.';

  @override
  String colorSchemeUsageSurfaceElevation(String level) {
    return 'ارتفاع الحاوية السطحية ⁨$level⁩.';
  }

  @override
  String get colorSchemeElevationLowest => 'أدنى';

  @override
  String get colorSchemeElevationLow => 'منخفض';

  @override
  String get colorSchemeElevationDefault => 'افتراضي';

  @override
  String get colorSchemeElevationHigh => 'مرتفع';

  @override
  String get colorSchemeElevationHighest => 'الأعلى';

  @override
  String get colorSchemeUsageOnSurface =>
      'النص الأساسي والأيقونات المعروضة على الأسطح.';

  @override
  String get colorSchemeUsageOnSurfaceVariant =>
      'النص الثانوي والتسميات والأيقونات الخافتة على الأسطح.';

  @override
  String get colorSchemeUsageSurfaceTint =>
      'لون الارتفاع Material مشتق من اللون الأساسي.';

  @override
  String get colorSchemeUsageOutline => 'حدود بارزة ومخططات مكونات مركزة.';

  @override
  String get colorSchemeUsageOutlineVariant =>
      'الحدود الدقيقة والفواصل والخطوط العريضة منخفضة التركيز.';

  @override
  String get colorSchemeUsageShadow => 'لون الظل المسقط للأسطح المرتفعة.';

  @override
  String get colorSchemeUsageScrim =>
      'طبقة تعتيم تقلل إبراز محتوى الخلفية عند عرض نافذة مشروطة.';

  @override
  String get colorSchemeUsageInverseSurface =>
      'السطح مع التركيز على الضوء والظلام المعكوس.';

  @override
  String get colorSchemeUsageInversePrimary =>
      'لهجة أساسية معروضة على سطح معكوس.';

  @override
  String get colorSchemeUsageError =>
      'إجراءات الخطأ والحالة والتعليقات عالية التركيز.';

  @override
  String get save => 'حفظ';

  @override
  String get advancedSettings => 'متقدم';

  @override
  String get remindersSettings => 'تذكيرات';

  @override
  String get remindersSettingsTitle => 'إعدادات التذكير';

  @override
  String get remindersSettingsDescription => 'اختر التذكيرات التي تريد تلقيها.';

  @override
  String get updateReminderTitle => 'تحديث التذكيرات';

  @override
  String get updateReminderDescription =>
      'التحقق من وجود تحديثات عند فتح المكتبة.';

  @override
  String get securityReminderTitle => 'تنبيهات عالية المخاطر';

  @override
  String get securityReminderDescription =>
      'إعلامك بالمخاطر العالية أو الحرجة الجديدة في المهارات المثبتة.';

  @override
  String availableUpdatesReminder(int count) {
    return 'المهارات المثبتة ⁨$count⁩ لها تحديثات';
  }

  @override
  String get openAvailableUpdates =>
      'افتح عرض التحديثات المتاحة لمراجعتها وتحديثها.';

  @override
  String securityAdvisoriesReminder(int count) {
    return 'تحتاج مهارات ⁨$count⁩ المثبتة إلى مراجعة أمنية';
  }

  @override
  String get reviewInstalledSkills =>
      'قم بمراجعة معلومات المخاطر الخاصة بهم قبل استخدامها أو تحديثها.';

  @override
  String get generalSettingsTitle => 'خصّص SkillsGo';

  @override
  String get generalSettingsDescription =>
      'تتبع الواجهة لغة النظام وإمكانية الوصول وتفضيلات الحركة.';

  @override
  String get agentsSettingsTitle => 'بيئات تشغيل Agents';

  @override
  String get hubSettingsTitle => 'عنوان Hub';

  @override
  String get hubSettingsDescription =>
      'استخدم Hub الرسمي أو عنوان HTTP(S) مستضافًا ذاتيًا يطبق بروتوكول SkillsGo نفسه.';

  @override
  String get testConnection => 'اختبار الاتصال';

  @override
  String get saveOrigin => 'حفظ العنوان';

  @override
  String get resetDefault => 'إعادة التعيين إلى الوضع الافتراضي';

  @override
  String get connectionReady => 'الاتصال جاهز';

  @override
  String get connectionFailed => 'فشل الاتصال';

  @override
  String get hubInvalidOrigin =>
      'أدخل عنوان HTTP(S) صالحًا من دون بيانات اعتماد أو استعلام أو جزء URL.';

  @override
  String hubHttpFailure(int status) {
    return 'أعاد Hub حالة HTTP ⁨$status⁩. تحقق من العنوان وإعدادات الخادم.';
  }

  @override
  String get hubInvalidProtocol => 'لم يُرجع الخادم بروتوكول بحث SkillsGo Hub.';

  @override
  String get hubInvalidJson => 'أعاد Hub بيانات JSON غير صالحة.';

  @override
  String get hubConnectionFailure =>
      'تعذر الوصول إلى Hub. تحقق من العنوان والشبكة والوكيل وإعدادات TLS.';

  @override
  String get hubConnectionTimeout =>
      'انتهت مهلة اتصال Hub. تحقق من الشبكة أو حاول مرة أخرى.';

  @override
  String get riskPolicyTitle => 'سياسة المخاطر الشخصية';

  @override
  String get riskPolicyDescription =>
      'تنطبق قواعد السلامة عند تثبيت مهارة ما أو تحديثها.';

  @override
  String get confirmHighRisk => 'طلب تأكيد للمخاطر العالية';

  @override
  String get confirmHighRiskDescription =>
      'تتطلب Artifacts عالية المخاطر دائمًا تأكيدًا إضافيًا قبل التثبيت.';

  @override
  String get allowCriticalOverride => 'السماح بتجاوز صريح للمخاطر الحرجة';

  @override
  String get allowCriticalOverrideDescription =>
      'تظل Artifacts ذات المخاطر الحرجة محظورة افتراضيًا. فعّل هذا الخيار فقط لإتاحة تجاوز يدوي منفصل.';

  @override
  String get storageHealthy => 'قابل للقراءة';

  @override
  String get storageNotInitialized => 'لم تتم التهيئة';

  @override
  String get storageUnavailable => 'غير متاح';

  @override
  String get storageInvalidResponse =>
      'أعاد CLI المرفق استجابة تشخيص غير مدعومة.';

  @override
  String get aboutSettingsTitle => 'توافق المكونات';

  @override
  String get appVersion => 'إصدار التطبيق';

  @override
  String get cliVersion => 'إصدار CLI المرفق';

  @override
  String get compatible => 'متوافق';

  @override
  String get hubOriginSaved => 'تم حفظ أصل Hub وتطبيقه.';

  @override
  String get policySaved => 'تم حفظ سياسة التثبيت.';

  @override
  String get officialCli => 'SkillsGo CLI';

  @override
  String get ready => 'جاهز';

  @override
  String get unknown => 'غير معروف';

  @override
  String get missing => 'مفقود';

  @override
  String get incompatible => 'غير متوافق';

  @override
  String get detecting => 'جارٍ الاكتشاف…';

  @override
  String get customCliPath => 'مسار قابل للتنفيذ مخصص';

  @override
  String get saveAndDetect => 'حفظ واكتشاف';

  @override
  String get detectAgain => 'إعادة الاكتشاف';

  @override
  String get agentInstalled => 'تم التثبيت';

  @override
  String get agentSupported => 'مدعوم';

  @override
  String agentCatalogSummary(int installed, int supported) {
    return 'مثبّت: ⁨$installed⁩ · مدعوم: ⁨$supported⁩';
  }

  @override
  String installedAgentsTitle(int count) {
    return 'مثبّت · ⁨$count⁩';
  }

  @override
  String notInstalledAgentsTitle(int count) {
    return 'غير مثبّت · ⁨$count⁩';
  }

  @override
  String get notInstalledAgentsDescription =>
      'يدعمه SkillsGo، لكنه غير مكتشف على هذا الـ Mac.';

  @override
  String agentDiscoveryRoots(String paths) {
    return 'مسارات تحميل Skills: ⁨$paths⁩';
  }

  @override
  String get agentInspectionFailed =>
      'بيانات اكتشاف Agents غير متاحة. شغّل الاكتشاف مجددًا.';

  @override
  String get noInstalledAgentsTitle => 'لم يُكتشف أي Agent مثبّت';

  @override
  String get noInstalledAgentsMessage =>
      'يمكنك الاستمرار في تصفح Skill، ولكن لا يوجد هدف تثبيت حتى الآن. قم بتثبيت Agent المدعوم، ثم قم بتشغيل الكشف مرة أخرى.';

  @override
  String get clearCustomPath => 'مسح المسار المخصص';

  @override
  String get privacyProvenance => 'الخصوصية والمصدر';

  @override
  String get privacySummary =>
      'لا يتم حفظ عمليات البحث التي تجريها، ولا يحتفظ SkillsGo بسجلات الأوامر.';

  @override
  String get language => 'اللغة';

  @override
  String get personalizationTheme => 'السمة';

  @override
  String get folderColorTheme => 'لون السمة';

  @override
  String get folderColorThemeDescription =>
      'اختر اللون الذي تريده. سيقوم SkillsGo ببناء لوحة واجهة منسقة حوله.';

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
  String get appearanceMode => 'الوضع';

  @override
  String get appearanceModeDescription =>
      'اتبع مظهر نظامك، أو استخدم دائمًا سمة فاتحة أو داكنة.';

  @override
  String get followSystem => 'النظام';

  @override
  String get lightMode => 'فاتح';

  @override
  String get darkMode => 'داكن';

  @override
  String get wallpaper => 'الخلفية';

  @override
  String get wallpaperDescription =>
      'اختر خلفية سماوية تظهر مباشرة خلف Folder.';

  @override
  String get wallpaperSun => 'الشمس';

  @override
  String get wallpaperMercury => 'الزئبق';

  @override
  String get wallpaperVenus => 'فينوس';

  @override
  String get wallpaperEarth => 'الأرض';

  @override
  String get wallpaperMars => 'المريخ';

  @override
  String get wallpaperJupiter => 'كوكب المشتري';

  @override
  String get wallpaperSaturn => 'زحل';

  @override
  String get wallpaperUranus => 'أورانوس';

  @override
  String get wallpaperNeptune => 'نبتون';

  @override
  String get wallpaperPluto => 'بلوتو';

  @override
  String get wallpaperMoon => 'القمر';

  @override
  String folderThemeChoice(String theme) {
    return 'سمة Folder: ⁨$theme⁩';
  }

  @override
  String get privacyAffiliation =>
      'يتم التحكم في القياس عن بعد للتثبيت المجهول من خلال إعدادات SkillsGo. SkillsGo لا ينتمي إلى OpenAI أو Codex.';

  @override
  String get commandCompleted => 'اكتمل الأمر';

  @override
  String get commandFailed => 'فشل الأمر';

  @override
  String commandExit(int code) {
    return 'انتهى الأمر بالرمز ⁨$code⁩ · وسّع لعرض سجل هذه الجلسة';
  }

  @override
  String get command => 'الأمر';

  @override
  String get cancel => 'إلغاء';

  @override
  String get updateUnknown => 'غير معروف';

  @override
  String get updateChecking => 'جارٍ التحقق';

  @override
  String get upToDate => 'محدّث';

  @override
  String get updateAvailable => 'يتوفر تحديث';

  @override
  String get updateUnavailable => 'غير متاح';

  @override
  String get updateCheckFailed => 'تعذر التحقق';

  @override
  String get installSkill => 'تثبيت Skill';

  @override
  String get installLocationTitle => 'اختيار موقع التثبيت';

  @override
  String get userLevel => 'نطاق المستخدم';

  @override
  String get projectLevel => 'نطاق المشروع';

  @override
  String get projects => 'المشاريع';

  @override
  String get loading => 'جارٍ التحميل…';

  @override
  String get repositoryParsing => 'جارٍ تحليل المستودع...';

  @override
  String userInstallSummary(int agents) {
    return 'متاح لـ ⁨$agents⁩ Agents في نطاق المستخدم';
  }

  @override
  String projectInstallSummary(int projects, int agents) {
    return 'مشاريع ⁨$projects⁩ · ⁨$agents⁩ Agents';
  }

  @override
  String get installationResults => 'نتائج التثبيت';

  @override
  String get installationInProgress => 'التثبيت قيد التقدم';

  @override
  String get installationSucceeded => 'اكتمل التثبيت';

  @override
  String get installationSucceededMessage =>
      'Skill متوفر الآن في المواقع المحددة.';

  @override
  String get projectUnavailable => 'المشروع غير متاح';

  @override
  String get installedCell => 'تم التثبيت';

  @override
  String get unsupportedCell => 'غير متاح';

  @override
  String get confirmInstall => 'تأكيد التثبيت';

  @override
  String installAllRepositorySkills(int count) {
    return 'تثبيت جميع مهارات المستودع (⁨$count⁩)';
  }

  @override
  String get installAllSkillsTo => 'تثبيت جميع Skills في';

  @override
  String installRepositorySkills(String repository, int count) {
    return 'تثبيت جميع مهارات ⁨$repository⁩ (⁨$count⁩)';
  }

  @override
  String installSkillTo(String skill) {
    return 'تثبيت ⁨$skill⁩ في';
  }

  @override
  String get availableInAllProjects => 'جميع المشاريع';

  @override
  String get availableInSelectedProjects => 'مشاريع مختارة';

  @override
  String get usedBy => 'يستخدمه Agents';

  @override
  String get backToTargets => 'العودة إلى الأهداف';

  @override
  String get stayHere => 'البقاء هنا';

  @override
  String get viewInLibrary => 'عرض في المكتبة';

  @override
  String planCreateCount(int count) {
    return 'إنشاء ⁨$count⁩';
  }

  @override
  String planSkipCount(int count) {
    return 'تخطي ⁨$count⁩';
  }

  @override
  String planReplaceCount(int count) {
    return 'استبدال ⁨$count⁩';
  }

  @override
  String planConflictCount(int count) {
    return 'تعارض: ⁨$count⁩';
  }

  @override
  String planRiskCount(int count) {
    return 'محظور بسبب المخاطر: ⁨$count⁩';
  }

  @override
  String get refreshInstallationPlan => 'تطبيق القرارات';

  @override
  String get replaceVersionConflict => 'استبدل الإصدار المثبت على هذا الهدف';

  @override
  String get replaceSkillIdCollision =>
      'استبدل معرف Skill المختلف عند هذا الهدف';

  @override
  String get replaceLocalModification =>
      'تجاهل التعديلات المحلية واستبدل هذا الهدف';

  @override
  String get sharedTargetConflict =>
      'تتم مشاركة هذا المسار بواسطة أهداف Agent الأخرى';

  @override
  String sharedTargetConflictDescription(String agents) {
    return 'ارجع إلى المصفوفة المستهدفة وحدد كل Agent المتأثر قبل الاستبدال: ⁨$agents⁩';
  }

  @override
  String get replaceConflictingTarget => 'استبدل الهدف المتعارض';

  @override
  String get confirmHighRiskArtifact => 'تأكيد Artifact عالية المخاطر';

  @override
  String get confirmCriticalRiskArtifact => 'تأكيد تجاوز المخاطر الحرجة';

  @override
  String get confirmRiskForSelectedTargets =>
      'لقد قمت بمراجعة ملفات القطع الأثرية وأقبل هذه المخاطرة بالنسبة للأهداف المحددة';

  @override
  String get criticalRiskBlocked => 'تم حظر التثبيت ذو المخاطر الحرجة';

  @override
  String get criticalRiskOverrideDisabled =>
      'قم بتمكين تجاوز المخاطر الحرجة الصريح في الإعدادات قبل أن تتمكن من متابعة هذه الخطة.';

  @override
  String get workspaceManifestChanges => 'تغييرات Workspace Manifest';

  @override
  String get noWorkspaceManifestChanges => 'لن تتغير ملفات Workspace Manifest.';

  @override
  String lockVersionChange(String from, String to) {
    return '⁨$from⁩ → ⁨$to⁩';
  }

  @override
  String get notPresent => 'غير موجود';

  @override
  String get planActionCreate => 'إنشاء';

  @override
  String get planActionReplace => 'استبدال';

  @override
  String get planActionSkip => 'تخطي';

  @override
  String get planActionConflict => 'تعارض';

  @override
  String get planActionBlockedByRisk => 'محظور بسبب المخاطر';

  @override
  String installationResultSummary(int succeeded, int failed) {
    return 'نجح تثبيت ⁨$succeeded⁩ من الأهداف، وفشل ⁨$failed⁩.';
  }

  @override
  String get installationProgressTitle => 'التثبيت قيد التقدم';

  @override
  String installationProgressSummary(int finished, int total) {
    return 'اكتمل ⁨$finished⁩ من ⁨$total⁩ هدفًا';
  }

  @override
  String get targetWaiting => 'في انتظار';

  @override
  String get targetRunning => 'التثبيت';

  @override
  String retryFailedTargets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'إعادة محاولة ⁨$count⁩ هدف فاشل',
      many: 'إعادة محاولة ⁨$count⁩ هدفًا فاشلًا',
      few: 'إعادة محاولة ⁨$count⁩ أهداف فاشلة',
      two: 'إعادة محاولة هدفين فاشلين',
      one: 'إعادة محاولة هدف واحد فاشل',
      zero: 'لا توجد أهداف فاشلة لإعادة المحاولة',
    );
    return '$_temp0';
  }

  @override
  String get updatePlanTitle => 'حدد الأهداف للتحديث';

  @override
  String get updatePlanDescription =>
      'اختر أهداف التثبيت المحددة. ستبقى Agents والمشاريع غير المحددة دون تغيير.';

  @override
  String updateTargetsSelected(int selected, int available) {
    return 'تم تحديد ⁨$selected⁩ من ⁨$available⁩ هدفًا قابلًا للتحديث';
  }

  @override
  String updateVersionChange(String fromVersion, String toVersion) {
    return '⁨$fromVersion⁩ → ⁨$toVersion⁩';
  }

  @override
  String sourceReference(String reference) {
    return 'مرجع المصدر: ⁨$reference⁩';
  }

  @override
  String get fixedVersionTarget => 'مثبّت — لا يوجد مرجع متحرك';

  @override
  String get currentVersionTarget => 'محدّث';

  @override
  String get updateCheckTargetFailed => 'فشل التحقق من التحديث';

  @override
  String get reconcileWorkspaceManifestTarget => 'إصلاح Workspace Manifest';

  @override
  String get updateSelectedTargets => 'تحديث الأهداف المحددة';

  @override
  String get updateProgressTitle => 'تحديث الأهداف';

  @override
  String get updateResultsTitle => 'تحديث النتائج';

  @override
  String updateProgressSummary(int finished, int total) {
    return 'اكتمل ⁨$finished⁩ من ⁨$total⁩ هدفًا';
  }

  @override
  String retryFailedUpdates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'إعادة محاولة ⁨$count⁩ تحديث فاشل',
      many: 'إعادة محاولة ⁨$count⁩ تحديثًا فاشلًا',
      few: 'إعادة محاولة ⁨$count⁩ تحديثات فاشلة',
      two: 'إعادة محاولة تحديثين فاشلين',
      one: 'إعادة محاولة تحديث واحد فاشل',
      zero: 'لا توجد تحديثات فاشلة لإعادة المحاولة',
    );
    return '$_temp0';
  }

  @override
  String get noUpdateableTargets => 'لا يوجد هدف محدد لديه تحديث متاح.';

  @override
  String get closeUpdatePlan => 'إغلاق';

  @override
  String get targetSucceeded => 'تم التثبيت';

  @override
  String get targetSkipped => 'تم تخطيه';

  @override
  String get targetConflict => 'تعارض';

  @override
  String get targetFailed => 'فشل';

  @override
  String get targetFailureRetryable =>
      'لا يمكن تغيير هذا الموقع. يمكنك المحاولة مرة أخرى.';

  @override
  String get targetFailureNeedsAttention =>
      'يحتاج هذا الموقع إلى انتباهك قبل المحاولة مرة أخرى.';

  @override
  String get installationTargetFailureMessage =>
      'لم يتغير شيء في هذا الموقع. تأكد من توفر المجلد ثم حاول مرة أخرى.';

  @override
  String get workspacePersistenceFailureMessage =>
      'لم يتم تغيير أي شيء لأن SkillsGo لم يتمكن من حفظ إعدادات المشروع. تأكد من أن مجلد المشروع قابل للكتابة وحاول مرة أخرى.';

  @override
  String get installationStateChangedMessage =>
      'تم تغيير هذا الموقع أثناء قيامك بمراجعته. قم بمراجعة أحدث حالة قبل المحاولة مرة أخرى.';

  @override
  String get updateTargetFailureMessage =>
      'لا يمكن تحديث هذا الموقع. لم تتأثر المواقع الأخرى، لذا يمكنك إعادة محاولة هذا الموقع فقط.';

  @override
  String get managementTargetFailureMessage =>
      'لا يمكن إكمال هذا الإجراء هنا. لم تتأثر المواقع الأخرى، لذا يمكنك إعادة محاولة هذا الموقع فقط.';

  @override
  String get technicalDetails => 'التفاصيل الفنية';

  @override
  String get targetPathExists => 'يوجد عنصر آخر بالفعل في هذا الموقع.';

  @override
  String get targetBlockedByRisk =>
      'إعدادات الأمان الحالية الخاصة بك منعت التثبيت في هذا الموقع.';

  @override
  String get targetInstallFailed => 'لا يمكن تثبيت المهارة في هذا الموقع.';

  @override
  String get targetWorkspaceUpdateFailed =>
      'تم تثبيت المهارة، لكن تعذر تحديث إعدادات المشروع.';

  @override
  String get installationPlanFailed => 'لا يمكن متابعة خطة التثبيت';

  @override
  String get installationFailed => 'لا يمكن إكمال التثبيت';

  @override
  String get localSource => 'مصدر محلي';

  @override
  String get noDescriptionAvailable => 'لا يوجد وصف متاح';

  @override
  String moreCoverage(int count) {
    return '+⁨$count⁩ المزيد من المواقع';
  }

  @override
  String get batchTakeoverAction => 'إدارة المهارات الموجودة';

  @override
  String batchTakeoverActionCount(int count) {
    return 'إدارة (⁨$count⁩)';
  }

  @override
  String get batchTakeoverChecking => 'التحقق من المهارات الموجودة...';

  @override
  String get batchTakeoverRetry => 'إعادة التحقق من Skills التي يمكن إدارتها';

  @override
  String batchTakeoverEligibleCount(int count) {
    return 'يمكن إدارة ⁨$count⁩';
  }

  @override
  String get batchTakeoverPending => 'إضافة مهارات إلى الإدارة...';

  @override
  String get batchTakeoverTitle => 'إدارة المهارات الموجودة مع SkillsGo؟';

  @override
  String get batchTakeoverDescription =>
      'سيضيف SkillsGo سجلات الإدارة المحلية دون نقل ملفات المهارات أو الكتابة فوقها أو تحميلها. سيتم تخطي العناصر غير المدعومة أو التي تم تغييرها.';

  @override
  String get batchTakeoverStoryTitle =>
      'اجمع Skills المتفرقة في مكتبة واحدة واضحة';

  @override
  String batchTakeoverStoryDescription(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$count⁩ Skill حالية يمكنه إدارتها',
      many: '⁨$count⁩ Skill حالية يمكنه إدارتها',
      few: '⁨$count⁩ Skills حالية يمكنه إدارتها',
      two: 'Skill اثنتين حاليتين يمكنه إدارتهما',
      one: 'Skill واحدة حالية يمكنه إدارتها',
      zero: 'لا Skills حالية',
    );
    return 'عثر SkillsGo في هذا الموقع على $_temp0.';
  }

  @override
  String get batchTakeoverBeforeSemantics =>
      'قبل الإدارة، ليس من الواضح أين يتم تثبيت المهارات الموجودة، وما إذا كانت حديثة، أو كيفية استعادتها، أو ما إذا كانت المشاريع تستخدم نفس الإصدار.';

  @override
  String get batchTakeoverPainLocation => 'موقع التثبيت غير معروف';

  @override
  String get batchTakeoverPainFreshness => 'حالة التحديث غير معروفة';

  @override
  String get batchTakeoverPainRecovery => 'لا توجد استعادة عند حدوث تلف';

  @override
  String get batchTakeoverPainVersionDrift => 'إصدارات مختلفة عبر المشاريع';

  @override
  String get batchTakeoverFolderTitle => 'Skills موجودة';

  @override
  String get batchTakeoverFolderSubtitle => 'الوضع غير واضح';

  @override
  String get batchTakeoverAfterLabel => 'بعد';

  @override
  String get batchTakeoverAfterTitle => 'مكتبة واحدة واضحة';

  @override
  String get batchTakeoverLibraryTitle => 'مكتبة SkillsGo';

  @override
  String get batchTakeoverBenefitLocation => 'مواقع واضحة';

  @override
  String get batchTakeoverBenefitFreshness => 'التحديثات مرئية';

  @override
  String get batchTakeoverBenefitRecovery => 'استعادة سهلة';

  @override
  String get batchTakeoverBenefitVersions => 'الإصدارات واضحة';

  @override
  String get batchTakeoverManagedSection => 'تحت إدارة SkillsGo';

  @override
  String get batchTakeoverPendingSection => 'في انتظار';

  @override
  String batchTakeoverItemManaged(String name) {
    return 'تتم إدارة ⁨$name⁩ بواسطة SkillsGo';
  }

  @override
  String batchTakeoverItemSkipped(String name) {
    return 'لا يمكن إضافة ⁨$name⁩ إلى الإدارة';
  }

  @override
  String batchTakeoverItemPending(String name) {
    return '⁨$name⁩ في انتظار إدارتها';
  }

  @override
  String batchTakeoverAfterSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$count⁩ Skill منظّمة',
      many: '⁨$count⁩ Skill منظّمة',
      few: '⁨$count⁩ Skills منظّمة',
      two: 'Skill اثنتان منظّمتان',
      one: 'Skill واحدة منظّمة',
      zero: 'لا Skills منظّمة',
    );
    return 'بعد إضافتها إلى الإدارة، تصبح $_temp0 في Library واحدة بحالة إدارة واضحة.';
  }

  @override
  String batchTakeoverMoreSkills(int count) {
    return '+⁨$count⁩ المزيد';
  }

  @override
  String get batchTakeoverTransitionSemantics =>
      'أضف هذه المهارات الموجودة إلى إدارة SkillsGo.';

  @override
  String get batchTakeoverTransitionLabel => 'تنظيم';

  @override
  String get batchTakeoverStatusTitle => 'حالة الإدارة';

  @override
  String get batchTakeoverStatusManaged => 'مُدار';

  @override
  String get batchTakeoverStatusProgress => 'جارٍ التنظيم';

  @override
  String get batchTakeoverStatusSkipped => 'تم تخطيه';

  @override
  String get batchTakeoverStatusFilesStay =>
      'تظل ملفات Skill في مواقعها الأصلية';

  @override
  String get batchTakeoverBoardSemantics =>
      'يتم ترتيب Skills في صفوف كاملة ويتم تسجيلها بواسطة SkillsGo دون نقل ملفاتها.';

  @override
  String get batchTakeoverBoardComplete => 'كل شيء واضح';

  @override
  String get batchTakeoverBoardPartial => 'اكتمل جزئيًا';

  @override
  String get batchTakeoverStatusTotal => 'المجموع';

  @override
  String get batchTakeoverQueueComplete => 'لا توجد مهارات في الانتظار';

  @override
  String get batchTakeoverQueueWaiting => 'ستظهر Skills هنا بعد التحقق';

  @override
  String get batchTakeoverNextLabel => 'التالي';

  @override
  String batchTakeoverFillerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$count⁩ كتلة تنظيم من SkillsGo',
      many: '⁨$count⁩ كتلة تنظيم من SkillsGo',
      few: '⁨$count⁩ كتل تنظيم من SkillsGo',
      two: 'كتلتا تنظيم من SkillsGo',
      one: 'كتلة تنظيم واحدة من SkillsGo',
      zero: 'لا كتل تنظيم',
    );
    return 'تُكمل $_temp0 الصفوف الأخيرة.';
  }

  @override
  String get batchTakeoverPreservation =>
      'تظل ملفاتك ومساراتك وسير العمل الحالي في مكانها تمامًا. SkillsGo يكمل فقط سجلات الإدارة المحلية الخاصة به.';

  @override
  String get batchTakeoverLaterHint =>
      'إذا قمت بالتخطي، يمكنك استخدام إدارة المهارات الموجودة من المكتبة في أي وقت.';

  @override
  String get batchTakeoverSkip => 'ليس الآن';

  @override
  String get batchTakeoverConfirm => 'إضافة إلى الإدارة';

  @override
  String get batchTakeoverExecutionRetry => 'أعد المحاولة';

  @override
  String get batchTakeoverResultTitle => 'أُضيفت Skills إلى الإدارة';

  @override
  String batchTakeoverSummary(int takenOver, int skipped) {
    return 'تمت إضافة مهارات ⁨$takenOver⁩ إلى الإدارة، وتم تخطي ⁨$skipped⁩.';
  }

  @override
  String get batchTakeoverClose => 'إغلاق';

  @override
  String get installMoreTargets => 'تثبيت في المزيد من المواقع';

  @override
  String get detailRepository => 'المستودع';

  @override
  String get detailStars => 'النجوم';

  @override
  String get detailUpdated => 'تم التحديث';

  @override
  String get detailArchiveSize => 'حجم ZIP';

  @override
  String get pathLabel => 'مسار المشروع';

  @override
  String get copyProjectPath => 'نسخ مسار المشروع';

  @override
  String get projectPathCopied => 'تم نسخ مسار المشروع';

  @override
  String get onboardingWelcomeTitle => 'مرحبًا بك في SkillsGo';

  @override
  String get onboardingWelcomeDescription =>
      'اكتشف Skills وثبّتها وأدرها عبر Agents ومشاريعك.';

  @override
  String get onboardingDetectedAgents => 'Agents المكتشفة';

  @override
  String get onboardingNoAgents =>
      'لم يتم اكتشاف أي Agent مثبّت. لا يزال بإمكانك المتابعة.';

  @override
  String get onboardingNext => 'التالي';

  @override
  String get onboardingProjectsTitle => 'أضف مشاريعك';

  @override
  String get onboardingProjectsDescription =>
      'اختر المشاريع التي تريد من SkillsGo إدارتها.';

  @override
  String get onboardingAddProject => 'أضف الآن';

  @override
  String get onboardingAddProjectLater => 'أو أضفها لاحقًا';

  @override
  String get onboardingStartUsing => 'ابدأ باستخدام SkillsGo';

  @override
  String get onboardingBack => 'العودة';

  @override
  String get restartOnboardingTitle => 'الإعداد';

  @override
  String get restartOnboardingDescription =>
      'اعرض إعداد بدء التشغيل مجددًا دون إزالة المشاريع أو الإعدادات أو بيانات Skills.';

  @override
  String get restartOnboardingAction => 'إعادة تشغيل الإعداد';

  @override
  String get restartOnboardingFailed =>
      'تعذر على SkillsGo إعادة تشغيل الإعداد الأولي.';

  @override
  String get libraryRefreshSettingsTitle => 'تحديث المكتبة المحلية';

  @override
  String get libraryRefreshSettingsDescription =>
      'أعد فحص تثبيت Skills والمشاريع المضافة وAgents وSkills الخارجية التي يمكن إدارتها. هذا لا يؤدي إلى تثبيت أو تحديث أو إزالة أي شيء.';

  @override
  String get libraryRefreshSettingsAction => 'تحديث المكتبة';

  @override
  String get libraryRefreshSettingsPending => 'جارٍ تحديث المكتبة…';

  @override
  String get libraryRefreshSettingsSuccess => 'تم تحديث المكتبة المحلية.';

  @override
  String get libraryRefreshSettingsFailed =>
      'تعذر على SkillsGo تحديث المكتبة المحلية.';

  @override
  String get onboardingProjectError =>
      'تعذر على SkillsGo إضافة مشاريع من هذا الدليل.';

  @override
  String get onboardingProjectsLoadError =>
      'تعذر على SkillsGo تحميل مشاريعك المضافة.';

  @override
  String get onboardingStartupError =>
      'تعذر على SkillsGo تحميل برنامج الإعداد.';

  @override
  String get onboardingStateError =>
      'تعذر على SkillsGo حفظ تقدم الإعداد. حاول ثانية.';

  @override
  String get onboardingCliErrorTitle => 'SkillsGo CLI يحتاج إلى الاهتمام';

  @override
  String get onboardingCliErrorDescription =>
      'أصلح CLI المرفق، ثم حاول مجددًا للمتابعة.';
}
