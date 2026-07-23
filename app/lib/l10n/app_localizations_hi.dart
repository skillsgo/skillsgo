// ignore_for_file: text_direction_code_point_in_literal, text_direction_code_point_in_comment

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get discover => 'खोजें';

  @override
  String get discoverSkills => 'थोड़ा और जानना अच्छा है.';

  @override
  String get library => 'पुस्तकालय';

  @override
  String get settings => 'सेटिंग्स';

  @override
  String get openSettings => 'सेटिंग्स खोलें';

  @override
  String get cliNeedsAttention =>
      'एक आवश्यक SkillsGo घटक पर ध्यान देने की आवश्यकता है।';

  @override
  String get cliMissingBundled =>
      'एक आवश्यक SkillsGo घटक गुम है या प्रारंभ नहीं हो सकता है। इसे पुनर्स्थापित करने के लिए SkillsGo को पुनर्स्थापित करें।';

  @override
  String get cliDamagedBundled =>
      'एक आवश्यक SkillsGo घटक क्षतिग्रस्त है। इसे पुनर्स्थापित करने के लिए SkillsGo को पुनर्स्थापित करें।';

  @override
  String get cliIncompatibleBundled =>
      'एक आवश्यक SkillsGo घटक इस ऐप संस्करण से मेल नहीं खाता है। SkillsGo को अद्यतन या पुनः स्थापित करें।';

  @override
  String get officialIndex => 'SkillsGo Hub';

  @override
  String get discoverTitle => 'अपने अगले कदम के लिए एक कौशल खोजें।';

  @override
  String get skillsLeaderboard => 'थोड़ा और जानना अच्छा है.';

  @override
  String searchResultsFor(String query) {
    return '\"$query\" के लिए परिणाम';
  }

  @override
  String get searchSkills => 'कौशल खोजें या Git लिंक पेस्ट करें...';

  @override
  String get search => 'खोजें';

  @override
  String get ranking => 'रैंकिंग';

  @override
  String get trending => 'ट्रेंडिंग';

  @override
  String get hot => 'गरम';

  @override
  String get discoverNavigation => 'नेविगेशन खोजें';

  @override
  String get allTimeRanking => 'सर्वकालिक रैंकिंग';

  @override
  String get trendingNow => 'पिछले 24 घंटों में ट्रेंड कर रहा है';

  @override
  String get hotNow => 'अभी गर्मी है';

  @override
  String get allTimeDescription =>
      'सार्वजनिक Skills को हर समय स्वीकृत इंस्टॉल द्वारा ऑर्डर किया गया।';

  @override
  String get trendingDescription =>
      'सार्वजनिक Skills को नवीनतम 24-घंटे की विंडो के दौरान स्वीकृत इंस्टॉल द्वारा ऑर्डर किया गया।';

  @override
  String get hotDescription =>
      'सार्वजनिक Skills को अल्पकालिक स्थापना वेग और परिवर्तन द्वारा आदेश दिया गया।';

  @override
  String get offlineTitle => 'SkillsGo से कनेक्ट नहीं हो सकता';

  @override
  String get offlineMessage =>
      'अपना इंटरनेट कनेक्शन जांचें और पुनः प्रयास करें। यदि आप प्रॉक्सी या कस्टम सेवा पते का उपयोग करते हैं, तो सेटिंग्स में इसकी समीक्षा करें।';

  @override
  String get searchFailedTitle => 'खोज लड़खड़ा गई';

  @override
  String get validationTitle => 'जांचें कि आपने क्या दर्ज किया है';

  @override
  String get validationMessage =>
      'SkillsGo इस अनुरोध का उपयोग नहीं कर सका। आपने जो दर्ज किया है उसकी समीक्षा करें और पुनः प्रयास करें।';

  @override
  String get serverTitle => 'सेवा अस्थायी रूप से अनुपलब्ध है';

  @override
  String get serverMessage =>
      'SkillsGo अभी इस अनुरोध को पूरा नहीं कर सकता। थोड़ी देर में पुनः प्रयास करें.';

  @override
  String get timeoutTitle => 'इसमें बहुत अधिक समय लग रहा है';

  @override
  String get timeoutMessage =>
      'सेवा ने समय पर प्रतिक्रिया नहीं दी. अपना कनेक्शन जाँचें या पुनः प्रयास करें।';

  @override
  String get invalidResponseTitle => 'SkillsGo को अपडेट की आवश्यकता है';

  @override
  String get invalidResponseMessage =>
      'यह प्रतिक्रिया आपके SkillsGo के संस्करण द्वारा नहीं पढ़ी जा सकती। ऐप को अपडेट करें, फिर पुनः प्रयास करें।';

  @override
  String get invalidLocalDataTitle => 'किसी स्थापित कौशल को नहीं पढ़ सकता';

  @override
  String get invalidLocalDataMessage =>
      'कुछ स्थानीय स्थापना जानकारी क्षतिग्रस्त या असंगत है। SkillsGo को अद्यतन या पुनः स्थापित करें, फिर पुनः प्रयास करें।';

  @override
  String get tryAgain => 'पुनः प्रयास करें';

  @override
  String get searchEmptyTitle => 'खोजें, स्क्रॉल न करें.';

  @override
  String get searchEmptyMessage =>
      'सार्वजनिक कौशल खोजने के लिए कोई क्षमता, स्रोत या कार्य दर्ज करें।';

  @override
  String get noSkillsTitle => 'कोई कौशल नहीं मिला';

  @override
  String get noSkillsMessage => 'एक व्यापक वाक्यांश आज़माएँ या वर्तनी जाँचें।';

  @override
  String get focusSearch => 'फोकस खोज';

  @override
  String get skillsFromLink => 'इस लिंक से Skills';

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
      other: '$source से $count Skills',
      one: '$source से 1 Skill',
    );
    return '$_temp0';
  }

  @override
  String get sourceSearchEmptyTitle => 'यह लिंक निरीक्षण के लिए तैयार है';

  @override
  String sourceSearchEmptyMessage(String source) {
    return '$source वर्तमान खोज परिणामों में नहीं है। SkillsGo सीधे अगले चरण में लिंक का निरीक्षण कर सकता है।';
  }

  @override
  String get inspectSource => 'इस लिंक में कौशल देखें';

  @override
  String get collectionEmptyTitle => 'इस संग्रह में कोई Skills नहीं है';

  @override
  String get collectionEmptyMessage =>
      'यहां अभी तक कुछ भी नहीं है. अधिक इंस्टॉलेशन गतिविधि के बाद पुनः प्रयास करें।';

  @override
  String get loadMore => 'और अधिक लोड करें';

  @override
  String get install => 'स्थापित करें';

  @override
  String get installAll => 'सभी कौशल स्थापित करें';

  @override
  String get latestCommit => 'नवीनतम प्रतिबद्धता';

  @override
  String get installToMoreTargets => 'अधिक स्थानों पर स्थापित करें';

  @override
  String localTargets(int count) {
    return '$count स्थानीय लक्ष्य';
  }

  @override
  String allTimeMetric(String count) {
    return '$count सर्वकालिक इंस्टॉल';
  }

  @override
  String trendingMetric(String count) {
    return '$count इंस्टॉल / 24 घंटे';
  }

  @override
  String hotMetric(String value, String change) {
    return '$value इस घंटे · $change';
  }

  @override
  String get trustUnverified => 'असत्यापित';

  @override
  String get trustCommunityVerified => 'समुदाय सत्यापित';

  @override
  String get trustPublisherVerified => 'प्रकाशक सत्यापित';

  @override
  String get trustOfficial => 'आधिकारिक';

  @override
  String get trustWarned => 'चेतावनी दी';

  @override
  String get trustDelisted => 'असूचीबद्ध';

  @override
  String get riskUnknown => 'जोखिम अज्ञात';

  @override
  String get riskLow => 'कम जोखिम';

  @override
  String get riskMedium => 'मध्यम जोखिम';

  @override
  String get riskHigh => 'उच्च जोखिम';

  @override
  String get riskCritical => 'गंभीर जोखिम';

  @override
  String openSkill(String name) {
    return '$name खोलें';
  }

  @override
  String installs(String count) {
    return '$count स्थापित करता है';
  }

  @override
  String get detailFailedTitle => 'इस Skill को लोड नहीं किया जा सका';

  @override
  String get detailLoading => 'ऑडिट योग्य Skill विवरण लोड हो रहा है';

  @override
  String get artifactUnavailableTitle => 'आर्टिफ़ैक्ट उपलब्ध नहीं है';

  @override
  String get artifactUnavailableMessage =>
      'यह संस्करण अभी उपलब्ध नहीं है. पुनः प्रयास करें या कोई अन्य संस्करण चुनें.';

  @override
  String get detailInvalidTitle => 'आर्टिफ़ैक्ट मेटाडेटा समर्थित नहीं है';

  @override
  String get detailInvalidMessage =>
      'इस कौशल के कुछ विवरण अधूरे हैं या पढ़े नहीं जा सकते। SkillsGo को अपडेट करें, फिर पुनः प्रयास करें।';

  @override
  String get instructionsTab => 'अनुदेश';

  @override
  String get manifestTab => 'मैनिफ़ेस्ट';

  @override
  String immutableVersionLabel(String version) {
    return 'अपरिवर्तनीय $version';
  }

  @override
  String commitIdentity(String sha) {
    return '$sha प्रतिबद्ध करें';
  }

  @override
  String treeIdentity(String sha) {
    return 'पेड़ $sha';
  }

  @override
  String contentIdentity(String digest) {
    return 'सामग्री $digest';
  }

  @override
  String get trustDoesNotProveSafety =>
      'प्रकाशक ट्रस्ट स्वामित्व या रखरखाव की पुष्टि करता है; यह आर्टिफैक्ट सुरक्षा को प्रमाणित नहीं करता है। इस अपरिवर्तनीय संस्करण के लिए जोखिम का मूल्यांकन अलग से किया जाता है।';

  @override
  String get knownInstallationTargets => 'ज्ञात स्थापना लक्ष्य';

  @override
  String get installationRange => 'स्थापित दायरा';

  @override
  String get targetDetails => 'लक्ष्य विवरण दिखाएँ';

  @override
  String get hideTargetDetails => 'लक्ष्य विवरण छिपाएँ';

  @override
  String installedVersionLabel(String version) {
    return 'संस्करण $version';
  }

  @override
  String targetSummary(String scope, String agent, String version) {
    return '$scope / $agent · $version';
  }

  @override
  String get projectScope => 'प्रोजेक्ट';

  @override
  String get fileContentUnavailable => 'बाइनरी या अनुपलब्ध पूर्वावलोकन';

  @override
  String get fileContentTruncated =>
      'पूर्वावलोकन को Hub सुरक्षा सीमा द्वारा छोटा कर दिया गया।';

  @override
  String get retry => 'पुनः प्रयास करें';

  @override
  String get backToSearch => 'खोज पर वापस जाएँ';

  @override
  String get installForCodex => 'Codex के लिए इंस्टॉल करें';

  @override
  String get cliNotDetected => 'कौशल (पता नहीं चला)';

  @override
  String get snapshotFiles => 'स्नैपशॉट फ़ाइलें';

  @override
  String get globalCodex => 'वैश्विक · Codex';

  @override
  String get yourLibrary => 'आप जो जानते हैं वह सब यहाँ है।';

  @override
  String get libraryNavigation => 'लाइब्रेरी नेविगेशन';

  @override
  String get all => 'सब';

  @override
  String get allSkills => 'सभी Skills';

  @override
  String get updatesOnly => 'अद्यतन';

  @override
  String get allAgents => 'सभी Agents';

  @override
  String get allProjects => 'सभी परियोजनाएँ';

  @override
  String get specificProject => 'प्रोजेक्ट';

  @override
  String get userScope => 'वैश्विक';

  @override
  String get addProject => 'प्रोजेक्ट जोड़ें';

  @override
  String get relocateProject => 'स्थानांतरित करें';

  @override
  String get removeFromList => 'सूची से हटाएँ';

  @override
  String removeProjectTitle(String name) {
    return 'SkillsGo से $name हटाएं?';
  }

  @override
  String get removeProjectDescription =>
      'केवल ऐप संदर्भ हटा दिया जाएगा. SkillsGo इस निर्देशिका में किसी भी फाइल को बदलेगा या हटाएगा नहीं।';

  @override
  String projectRailUnavailable(String name) {
    return '$name - अनुपलब्ध';
  }

  @override
  String get emptyProjectTitle => 'अभी तक कोई Skills नहीं है';

  @override
  String get browseSkills => 'Skills ब्राउज़ करें';

  @override
  String get projectMissingTitle => 'प्रोजेक्ट निर्देशिका अनुपलब्ध है';

  @override
  String get projectMissingMessage =>
      'हो सकता है कि निर्देशिका स्थानांतरित हो गई हो या उसका वॉल्यूम ऑफ़लाइन हो। इसे स्थानांतरित करें या केवल इसके ऐप संदर्भ को हटा दें।';

  @override
  String get projectPermissionTitle => 'प्रोजेक्ट की अनुमति आवश्यक है';

  @override
  String get projectPermissionMessage =>
      'SkillsGo इस चयनित रूट का निरीक्षण नहीं कर सकता। इसे निर्देशिका पिकर के माध्यम से स्थानांतरित करके पहुंच प्रदान करें।';

  @override
  String get projectInaccessibleTitle =>
      'प्रोजेक्ट निर्देशिका पहुंच योग्य नहीं है';

  @override
  String get projectInaccessibleMessage =>
      'SkillsGo ने इस प्रोजेक्ट का संदर्भ रखा। पथ या आयतन की जाँच करें, फिर उसे स्थानांतरित करें।';

  @override
  String get checking => 'जाँच हो रही है...';

  @override
  String get checkUpdates => 'अपडेट जांचें';

  @override
  String get refresh => 'ताज़ा करें';

  @override
  String get libraryUnavailable => 'लाइब्रेरी अनुपलब्ध';

  @override
  String get libraryEmpty => 'अभी तक कोई कौशल स्थापित नहीं किया गया है';

  @override
  String get libraryEmptyMessage =>
      'डिस्कवर से एक Skill इंस्टॉल करें और यह यहां दिखाई देगा।';

  @override
  String get searchLibrary => 'स्थापित कौशल खोजें';

  @override
  String get libraryNoMatches => 'कोई मिलान नहीं Skills';

  @override
  String get libraryNoMatchesMessage =>
      'कोई भिन्न नाम, स्रोत, Agent, प्रोजेक्ट या संस्करण आज़माएँ।';

  @override
  String agentsSummary(int count) {
    return '$count Agents';
  }

  @override
  String projectsSummary(int count) {
    return '$count परियोजनाएं';
  }

  @override
  String versionsSummary(int count) {
    return '$count संस्करण';
  }

  @override
  String get hubManaged => 'Hub प्रबंधित';

  @override
  String get localManaged => 'स्थानीय प्रबंधित';

  @override
  String get externalInstallation => 'बाहरी स्थापना';

  @override
  String get readOnly => 'केवल पढ़ें';

  @override
  String get unversioned => 'असंक्रमित';

  @override
  String get supportingFiles => 'सहायक फ़ाइलें';

  @override
  String get versionDivergence => 'संस्करण विचलन';

  @override
  String get healthHealthy => 'स्वस्थ';

  @override
  String get healthMissing => 'लक्ष्य चूक गया';

  @override
  String get healthReplaced => 'लक्ष्य बदला गया';

  @override
  String get healthLocalModification => 'स्थानीय संशोधन';

  @override
  String get healthUnreadable => 'लक्ष्य अपठनीय';

  @override
  String get healthUndeclared => 'घोषित नहीं किया गया';

  @override
  String get healthWorkspaceUnreadable => 'कार्यस्थान स्थिति अपठनीय';

  @override
  String get healthLockMismatch => 'लॉक बेमेल';

  @override
  String get healthUnexpectedPath => 'अप्रत्याशित लक्ष्य पथ';

  @override
  String get modeExternal => 'बाहरी';

  @override
  String get notLinked => 'लिंक नहीं किया गया';

  @override
  String get update => 'अद्यतन करें';

  @override
  String get backToLibrary => 'लाइब्रेरी को लौटें';

  @override
  String get remove => 'हटाओ';

  @override
  String get manageTargets => 'दायरा प्रबंधित करें';

  @override
  String skillsSelected(int count) {
    return '$count चयनित';
  }

  @override
  String get clearSelection => 'स्पष्ट चयन';

  @override
  String get selectCurrentResults => 'वर्तमान परिणाम चुनें';

  @override
  String get clearCurrentResultSelection => 'वर्तमान परिणाम चयन साफ़ करें';

  @override
  String get manageTargetsTitle => 'स्थापना लक्ष्य प्रबंधित करें';

  @override
  String get manageTargetsDescription =>
      'प्रत्येक लक्ष्य के लिए एक सटीक कार्रवाई चुनें. अचयनित लक्ष्य नहीं बदलेंगे.';

  @override
  String targetActionsSelected(int selected, int total) {
    return '$total लक्ष्यों में से $selected चयनित';
  }

  @override
  String get confirmRemoveTarget => 'हटाने की पुष्टि करें';

  @override
  String get applyTargetActions => 'चयनित क्रियाएँ लागू करें';

  @override
  String get managementProgressTitle => 'लक्ष्य क्रियाएँ लागू करना';

  @override
  String get managementResultsTitle => 'लक्ष्य कार्रवाई परिणाम';

  @override
  String managementResultSummary(int succeeded, int failed) {
    return '$succeeded सफल हुआ, $failed विफल रहा';
  }

  @override
  String get workspaceOwnershipChanges =>
      'चयनित प्रोजेक्ट क्रियाएँ skillsgo.yaml और skillsgo.lock को अद्यतन करेंगी।';

  @override
  String get targetContentPreserved =>
      'वर्तमान लक्ष्य सामग्री संरक्षित की जाएगी.';

  @override
  String get localReadFailed => 'यह Skill नहीं पढ़ सकता';

  @override
  String get localReadFailedMessage =>
      'SkillsGo इस स्थापित कौशल को नहीं पढ़ सका। जांचें कि उसका फ़ोल्डर उपलब्ध और पहुंच योग्य है, फिर पुनः प्रयास करें।';

  @override
  String get localConfiguration => 'स्किल्सगो सेटिंग्स';

  @override
  String get settingsNavigation => 'सेटिंग नेविगेशन';

  @override
  String get general => 'वैयक्तिकृत करें';

  @override
  String get agents => 'Agents';

  @override
  String get hub => 'Hub';

  @override
  String get installationPolicy => 'स्थापना नीति';

  @override
  String get storage => 'भंडारण';

  @override
  String get colorScheme => 'रंग योजना';

  @override
  String get about => 'के बारे में';

  @override
  String get colorSchemeInspectorTitle =>
      'Material रंग भूमिकाएँ उत्पन्न की गईं';

  @override
  String get skillsColorTokensTitle => 'SkillsGo अर्थपूर्ण रंग';

  @override
  String get skillsColorTokensDescription =>
      'उत्पाद रंग Radix Sand से निर्मित और Primer शब्दार्थ के साथ व्यवस्थित, Folder के साथ एक समर्पित स्थानिक पदानुक्रम के रूप में।';

  @override
  String get colorSchemeInspectorDescription =>
      'वर्तमान बीज से उत्पन्न प्रत्येक गैर-बहिष्कृत ColorScheme टोकन का पूर्वावलोकन करें। किसी रंग का HEX मान कॉपी करने के लिए उस पर क्लिक करें।';

  @override
  String get colorSchemePairPreview => 'शब्दार्थ युग्म';

  @override
  String get colorSchemePairPreviewDescription =>
      'विरोधाभास और पदानुक्रम को उजागर करने के लिए अग्रभूमि और पृष्ठभूमि भूमिकाओं को एक साथ प्रस्तुत किया गया।';

  @override
  String get colorSchemeComponentPreview => 'घटक पूर्वावलोकन';

  @override
  String get colorSchemeComponentPreviewDescription =>
      'इस सटीक पूर्वावलोकन योजना के साथ प्रतिनिधि Material नियंत्रण प्रदान किए गए।';

  @override
  String get colorSchemeSampleTitle => 'Skill कार्ड शीर्षक';

  @override
  String get colorSchemeSampleBody =>
      'द्वितीयक प्रतिलिपि onSurfaceVariant का उपयोग करती है।';

  @override
  String get colorSchemeCopied => 'नकल की गई';

  @override
  String get colorSchemeSampleGlyphs => 'आ 123';

  @override
  String get colorSchemeGroupPrimary => 'प्राथमिक';

  @override
  String get colorSchemeGroupPrimaryDescription =>
      'प्राथमिक जोर, कंटेनर, और निश्चित उच्चारण भूमिकाएँ।';

  @override
  String get colorSchemeGroupSecondary => 'माध्यमिक';

  @override
  String get colorSchemeGroupSecondaryDescription =>
      'सहायक जोर और निश्चित माध्यमिक भूमिकाएँ।';

  @override
  String get colorSchemeGroupTertiary => 'तृतीयक';

  @override
  String get colorSchemeGroupTertiaryDescription =>
      'विरोधाभासी उच्चारण और निश्चित तृतीयक भूमिकाएँ।';

  @override
  String get colorSchemeGroupSurface => 'सतह';

  @override
  String get colorSchemeGroupSurfaceDescription =>
      'पृष्ठ, कंटेनर, ऊंचाई और अग्रभूमि पदानुक्रम।';

  @override
  String get colorSchemeGroupUtility => 'रूपरेखा एवं उपयोगिता';

  @override
  String get colorSchemeGroupUtilityDescription =>
      'सीमाएँ, छायाएँ, स्क्रिम और उलटी सतहें।';

  @override
  String get colorSchemeGroupError => 'त्रुटि';

  @override
  String get colorSchemeGroupErrorDescription =>
      'त्रुटि क्रियाएँ, संदेश और कंटेनर।';

  @override
  String get colorSchemeUsagePrimary =>
      'प्राथमिक क्रियाएँ, फोकस, और उच्च-जोर वाले उच्चारण।';

  @override
  String get colorSchemeUsageSecondary =>
      'सहायक क्रियाएं और मध्यम-जोर वाले उच्चारण।';

  @override
  String get colorSchemeUsageTertiary =>
      'विरोधाभासी लहजे जो प्राथमिक और माध्यमिक के पूरक हैं।';

  @override
  String colorSchemeUsageContentOn(String token) {
    return '$token पर प्रदर्शित टेक्स्ट और आइकन।';
  }

  @override
  String colorSchemeUsageContainer(String family) {
    return 'चयन और उच्चारण के लिए कम जोर वाला $family कंटेनर।';
  }

  @override
  String colorSchemeUsageFixed(String family) {
    return 'चमक-स्वतंत्र निश्चित $family कंटेनर।';
  }

  @override
  String colorSchemeUsageFixedDim(String family) {
    return 'मंद चमक-स्वतंत्र निश्चित $family कंटेनर।';
  }

  @override
  String colorSchemeUsageFixedContent(String family) {
    return 'निश्चित $family कंटेनर पर उच्च-जोर सामग्री।';
  }

  @override
  String colorSchemeUsageFixedVariantContent(String family) {
    return 'निश्चित $family कंटेनर पर कम जोर वाली सामग्री।';
  }

  @override
  String get colorSchemeUsageSurface => 'आधार पृष्ठ और बड़े क्षेत्र की सतह।';

  @override
  String get colorSchemeUsageSurfaceDim =>
      'सबसे गहरे रंग की सतह पर मंद आधार सतह का उपयोग किया जाता है।';

  @override
  String get colorSchemeUsageSurfaceBright =>
      'चमकदार आधार सतह का उपयोग सबसे हल्के सतह टोन पर किया जाता है।';

  @override
  String colorSchemeUsageSurfaceElevation(String level) {
    return '$level सतह-कंटेनर ऊंचाई।';
  }

  @override
  String get colorSchemeElevationLowest => 'सबसे कम';

  @override
  String get colorSchemeElevationLow => 'कम';

  @override
  String get colorSchemeElevationDefault => 'डिफ़ॉल्ट';

  @override
  String get colorSchemeElevationHigh => 'उच्च';

  @override
  String get colorSchemeElevationHighest => 'उच्चतम';

  @override
  String get colorSchemeUsageOnSurface =>
      'प्राथमिक पाठ और चिह्न सतहों पर प्रदर्शित होते हैं।';

  @override
  String get colorSchemeUsageOnSurfaceVariant =>
      'द्वितीयक पाठ, लेबल, और सतहों पर दबे हुए चिह्न।';

  @override
  String get colorSchemeUsageSurfaceTint =>
      'Material एलिवेशन टिंट प्राथमिक से प्राप्त हुआ।';

  @override
  String get colorSchemeUsageOutline =>
      'प्रमुख सीमाएँ और केंद्रित घटक रूपरेखाएँ।';

  @override
  String get colorSchemeUsageOutlineVariant =>
      'सूक्ष्म सीमाएँ, विभाजक, और कम-जोर वाली रूपरेखाएँ।';

  @override
  String get colorSchemeUsageShadow => 'ऊंची सतहों के लिए ड्रॉप-शैडो रंग।';

  @override
  String get colorSchemeUsageScrim =>
      'मोडल ओवरले का उपयोग पृष्ठभूमि सामग्री पर ज़ोर कम करने के लिए किया जाता है।';

  @override
  String get colorSchemeUsageInverseSurface =>
      'उल्टे प्रकाश और अंधेरे जोर के साथ सतह।';

  @override
  String get colorSchemeUsageInversePrimary =>
      'प्राथमिक उच्चारण उलटी सतह पर प्रदर्शित होता है।';

  @override
  String get colorSchemeUsageError =>
      'त्रुटि क्रियाएं, स्थिति और उच्च-जोर वाली प्रतिक्रिया।';

  @override
  String get save => 'सहेजें';

  @override
  String get advancedSettings => 'उन्नत';

  @override
  String get remindersSettings => 'अनुस्मारक';

  @override
  String get remindersSettingsTitle => 'अनुस्मारक सेटिंग्स';

  @override
  String get remindersSettingsDescription =>
      'चुनें कि कौन सा अनुस्मारक प्राप्त करना है।';

  @override
  String get updateReminderTitle => 'अनुस्मारक अद्यतन करें';

  @override
  String get updateReminderDescription =>
      'लाइब्रेरी खुलने पर अपडेट की जाँच करें।';

  @override
  String get securityReminderTitle => 'उच्च जोखिम वाले अलर्ट';

  @override
  String get securityReminderDescription =>
      'स्थापित कौशल में नए उच्च या गंभीर जोखिमों के बारे में आपको सूचित करें।';

  @override
  String availableUpdatesReminder(int count) {
    return '$count स्थापित कौशल में अद्यतन हैं';
  }

  @override
  String get openAvailableUpdates =>
      'उनकी समीक्षा और अद्यतन करने के लिए उपलब्ध-अद्यतन दृश्य खोलें।';

  @override
  String securityAdvisoriesReminder(int count) {
    return '$count स्थापित कौशल को सुरक्षा समीक्षा की आवश्यकता है';
  }

  @override
  String get reviewInstalledSkills =>
      'उनका उपयोग करने या अद्यतन करने से पहले उनकी जोखिम संबंधी जानकारी की समीक्षा करें।';

  @override
  String get generalSettingsTitle => 'SkillsGo को अपना बनाएं';

  @override
  String get generalSettingsDescription =>
      'इंटरफ़ेस आपके सिस्टम की भाषा, पहुंच और गति प्राथमिकताओं का अनुसरण करता है।';

  @override
  String get agentsSettingsTitle => 'Agent रनटाइम';

  @override
  String get hubSettingsTitle => 'Hub उत्पत्ति';

  @override
  String get hubSettingsDescription =>
      'आधिकारिक Hub या HTTP(S) स्व-होस्टेड मूल का उपयोग करें जो समान SkillsGo प्रोटोकॉल लागू करता है।';

  @override
  String get testConnection => 'कनेक्शन का परीक्षण करें';

  @override
  String get saveOrigin => 'उत्पत्ति सहेजें';

  @override
  String get resetDefault => 'डिफ़ॉल्ट पर रीसेट करें';

  @override
  String get connectionReady => 'कनेक्शन तैयार';

  @override
  String get connectionFailed => 'कनेक्शन विफल';

  @override
  String get hubInvalidOrigin =>
      'क्रेडेंशियल्स, क्वेरी या खंड के बिना एक वैध HTTP(S) उत्पत्ति दर्ज करें।';

  @override
  String hubHttpFailure(int status) {
    return 'Hub ने HTTP $status लौटा दिया। उत्पत्ति और सर्वर कॉन्फ़िगरेशन की जाँच करें।';
  }

  @override
  String get hubInvalidProtocol =>
      'सर्वर ने SkillsGo Hub खोज प्रोटोकॉल वापस नहीं किया।';

  @override
  String get hubInvalidJson => 'Hub ने अमान्य JSON लौटाया।';

  @override
  String get hubConnectionFailure =>
      'Hub तक नहीं पहुंच सका. उत्पत्ति, नेटवर्क, प्रॉक्सी और TLS कॉन्फ़िगरेशन की जाँच करें।';

  @override
  String get hubConnectionTimeout =>
      'Hub कनेक्शन का समय समाप्त हो गया। नेटवर्क जाँचें या पुनः प्रयास करें।';

  @override
  String get riskPolicyTitle => 'व्यक्तिगत जोखिम नीति';

  @override
  String get riskPolicyDescription =>
      'जब आप कोई कौशल स्थापित या अद्यतन करते हैं तो सुरक्षा नियम लागू होते हैं।';

  @override
  String get confirmHighRisk => 'उच्च जोखिम के लिए पुष्टि की आवश्यकता है';

  @override
  String get confirmHighRiskDescription =>
      'उच्च जोखिम वाली कलाकृतियों को हमेशा स्थापना से पहले अतिरिक्त पुष्टि की आवश्यकता होती है।';

  @override
  String get allowCriticalOverride =>
      'स्पष्ट क्रिटिकल-जोखिम ओवरराइड की अनुमति दें';

  @override
  String get allowCriticalOverrideDescription =>
      'गंभीर-जोखिम वाली कलाकृतियाँ डिफ़ॉल्ट रूप से अवरुद्ध रहती हैं। इसे केवल एक अलग मैन्युअल ओवरराइड को उजागर करने के लिए सक्षम करें।';

  @override
  String get storageHealthy => 'पठनीय';

  @override
  String get storageNotInitialized => 'प्रारंभ नहीं किया गया';

  @override
  String get storageUnavailable => 'अनुपलब्ध';

  @override
  String get storageInvalidResponse =>
      'बंडल किए गए CLI ने एक असमर्थित निदान प्रतिक्रिया लौटा दी।';

  @override
  String get aboutSettingsTitle => 'उत्पाद अनुकूलता';

  @override
  String get appVersion => 'ऐप संस्करण';

  @override
  String get cliVersion => 'बंडल CLI संस्करण';

  @override
  String get compatible => 'संगत';

  @override
  String get hubOriginSaved => 'Hub उत्पत्ति सहेजी गई और लागू की गई।';

  @override
  String get policySaved => 'स्थापना नीति सहेजी गई.';

  @override
  String get officialCli => 'SkillsGo CLI';

  @override
  String get ready => 'तैयार';

  @override
  String get unknown => 'अज्ञात';

  @override
  String get missing => 'लापता';

  @override
  String get incompatible => 'असंगत';

  @override
  String get detecting => 'पता लगाया जा रहा है...';

  @override
  String get customCliPath => 'कस्टम निष्पादन योग्य पथ';

  @override
  String get saveAndDetect => 'सहेजें और पता लगाएं';

  @override
  String get detectAgain => 'फिर से पता लगाएं';

  @override
  String get agentInstalled => 'स्थापित';

  @override
  String get agentSupported => 'समर्थित';

  @override
  String agentCatalogSummary(int installed, int supported) {
    return '$installed स्थापित · $supported समर्थित';
  }

  @override
  String installedAgentsTitle(int count) {
    return 'स्थापित · $count';
  }

  @override
  String notInstalledAgentsTitle(int count) {
    return 'स्थापित नहीं है · $count';
  }

  @override
  String get notInstalledAgentsDescription =>
      'SkillsGo द्वारा समर्थित, लेकिन इस Mac पर पता नहीं चला।';

  @override
  String agentDiscoveryRoots(String paths) {
    return 'Skill लोडिंग पथ: $paths';
  }

  @override
  String get agentInspectionFailed =>
      'Agent डिटेक्शन डेटा उपलब्ध नहीं है। पुनः पता लगाना चलाएँ।';

  @override
  String get noInstalledAgentsTitle => 'कोई स्थापित Agents नहीं पाया गया';

  @override
  String get noInstalledAgentsMessage =>
      'आप इस Skill को ब्राउज़ करना जारी रख सकते हैं, लेकिन अभी तक कोई इंस्टॉलेशन लक्ष्य नहीं है। समर्थित Agent स्थापित करें, फिर दोबारा डिटेक्शन चलाएँ।';

  @override
  String get clearCustomPath => 'कस्टम पथ साफ़ करें';

  @override
  String get privacyProvenance => 'गोपनीयता और उद्गम';

  @override
  String get privacySummary =>
      'आपकी खोजें सहेजी नहीं गई हैं, और SkillsGo कमांड लॉग नहीं रखता है।';

  @override
  String get language => 'भाषा';

  @override
  String get personalizationTheme => 'थीम';

  @override
  String get folderColorTheme => 'थीम रंग';

  @override
  String get folderColorThemeDescription =>
      'वह रंग चुनें जो आपको पसंद हो. SkillsGo इसके चारों ओर एक समन्वित इंटरफ़ेस पैलेट का निर्माण करेगा।';

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
  String get appearanceMode => 'मोड';

  @override
  String get appearanceModeDescription =>
      'अपने सिस्टम की उपस्थिति का पालन करें, या हमेशा हल्के या गहरे रंग की थीम का उपयोग करें।';

  @override
  String get followSystem => 'सिस्टम';

  @override
  String get lightMode => 'रोशनी';

  @override
  String get darkMode => 'अंधेरा';

  @override
  String get wallpaper => 'वॉलपेपर';

  @override
  String get wallpaperDescription =>
      'एक दिव्य पृष्ठभूमि चुनें. आपका चयन Folder के ठीक पीछे दिखाई देता है।';

  @override
  String get wallpaperSun => 'रवि';

  @override
  String get wallpaperMercury => 'बुध';

  @override
  String get wallpaperVenus => 'शुक्र';

  @override
  String get wallpaperEarth => 'पृथ्वी';

  @override
  String get wallpaperMars => 'मंगल';

  @override
  String get wallpaperJupiter => 'बृहस्पति';

  @override
  String get wallpaperSaturn => 'शनि';

  @override
  String get wallpaperUranus => 'यूरेनस';

  @override
  String get wallpaperNeptune => 'नेपच्यून';

  @override
  String get wallpaperPluto => 'प्लूटो';

  @override
  String get wallpaperMoon => 'चाँद';

  @override
  String folderThemeChoice(String theme) {
    return '$theme Folder थीम';
  }

  @override
  String get privacyAffiliation =>
      'अनाम इंस्टॉलेशन टेलीमेट्री को SkillsGo सेटिंग्स द्वारा नियंत्रित किया जाता है। SkillsGo OpenAI या Codex से संबद्ध नहीं है।';

  @override
  String get commandCompleted => 'आदेश पूरा हुआ';

  @override
  String get commandFailed => 'आदेश विफल रहा';

  @override
  String commandExit(int code) {
    return '$code से बाहर निकलें · इस सत्र के लॉग के लिए विस्तार करें';
  }

  @override
  String get command => 'आदेश';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get updateUnknown => 'अज्ञात';

  @override
  String get updateChecking => 'जाँच हो रही है';

  @override
  String get upToDate => 'अद्यतन';

  @override
  String get updateAvailable => 'अद्यतन करें';

  @override
  String get updateUnavailable => 'अनुपलब्ध';

  @override
  String get updateCheckFailed => 'जाँच विफल';

  @override
  String get installSkill => 'Skill स्थापित करें';

  @override
  String get installLocationTitle => 'स्थापना स्थान निर्धारित करें';

  @override
  String get userLevel => 'उपयोगकर्ता स्तर';

  @override
  String get projectLevel => 'परियोजना स्तर';

  @override
  String get projects => 'परियोजनाएं';

  @override
  String get loading => 'लोड हो रहा है...';

  @override
  String get repositoryParsing => 'पार्सिंग रिपॉजिटरी…';

  @override
  String userInstallSummary(int agents) {
    return 'उपयोगकर्ता स्तर पर $agents Agents के लिए उपलब्ध है';
  }

  @override
  String projectInstallSummary(int projects, int agents) {
    return '$projects परियोजनाएं · $agents Agents';
  }

  @override
  String get installationResults => 'स्थापना परिणाम';

  @override
  String get installationInProgress => 'स्थापना प्रगति पर है';

  @override
  String get installationSucceeded => 'स्थापना पूर्ण';

  @override
  String get installationSucceededMessage =>
      'Skill अब चयनित स्थानों पर उपलब्ध है।';

  @override
  String get projectUnavailable => 'प्रोजेक्ट अनुपलब्ध';

  @override
  String get installedCell => 'स्थापित';

  @override
  String get unsupportedCell => 'अनुपलब्ध';

  @override
  String get confirmInstall => 'स्थापना की पुष्टि करें';

  @override
  String installAllRepositorySkills(int count) {
    return 'सभी रिपॉजिटरी कौशल स्थापित करें ($count)';
  }

  @override
  String get installAllSkillsTo => 'सभी कौशल स्थापित करें';

  @override
  String installRepositorySkills(String repository, int count) {
    return 'सभी $repository कौशल स्थापित करें ($count)';
  }

  @override
  String installSkillTo(String skill) {
    return '$skill को स्थापित करें';
  }

  @override
  String get availableInAllProjects => 'सभी परियोजनाएँ';

  @override
  String get availableInSelectedProjects => 'चयनित परियोजनाएँ';

  @override
  String get usedBy => 'Agents के लिए';

  @override
  String get backToTargets => 'लक्ष्य पर वापस जाएँ';

  @override
  String get stayHere => 'यहीं रहो';

  @override
  String get viewInLibrary => 'लाइब्रेरी में देखें';

  @override
  String planCreateCount(int count) {
    return '$count बनाएं';
  }

  @override
  String planSkipCount(int count) {
    return '$count छोड़ें';
  }

  @override
  String planReplaceCount(int count) {
    return '$count बदलें';
  }

  @override
  String planConflictCount(int count) {
    return '$count संघर्ष';
  }

  @override
  String planRiskCount(int count) {
    return '$count जोखिम अवरुद्ध';
  }

  @override
  String get refreshInstallationPlan => 'संकल्प लागू करें';

  @override
  String get replaceVersionConflict => 'इस लक्ष्य पर स्थापित संस्करण को बदलें';

  @override
  String get replaceSkillIdCollision => 'इस लक्ष्य पर भिन्न Skill आईडी बदलें';

  @override
  String get replaceLocalModification =>
      'स्थानीय संशोधनों को त्यागें और इस लक्ष्य को बदलें';

  @override
  String get sharedTargetConflict =>
      'यह पथ अन्य Agent लक्ष्यों द्वारा साझा किया गया है';

  @override
  String sharedTargetConflictDescription(String agents) {
    return 'लक्ष्य मैट्रिक्स पर लौटें और प्रतिस्थापित करने से पहले प्रत्येक प्रभावित Agent का चयन करें: $agents';
  }

  @override
  String get replaceConflictingTarget => 'परस्पर विरोधी लक्ष्य बदलें';

  @override
  String get confirmHighRiskArtifact => 'उच्च जोखिम वाली कलाकृतियों की पुष्टि';

  @override
  String get confirmCriticalRiskArtifact => 'गंभीर-जोखिम ओवरराइड पुष्टिकरण';

  @override
  String get confirmRiskForSelectedTargets =>
      'मैंने आर्टिफैक्ट फ़ाइलों की समीक्षा की और चयनित लक्ष्यों के लिए इस जोखिम को स्वीकार किया';

  @override
  String get criticalRiskBlocked => 'गंभीर-जोखिम स्थापना अवरुद्ध है';

  @override
  String get criticalRiskOverrideDisabled =>
      'इस योजना को जारी रखने से पहले सेटिंग्स में स्पष्ट क्रिटिकल-रिस्क ओवरराइड सक्षम करें।';

  @override
  String get workspaceManifestChanges => 'Workspace Manifest परिवर्तन';

  @override
  String get noWorkspaceManifestChanges =>
      'कोई Workspace Manifest फ़ाइलें नहीं बदलेंगी.';

  @override
  String lockVersionChange(String from, String to) {
    return '$from → $to';
  }

  @override
  String get notPresent => 'मौजूद नहीं';

  @override
  String get planActionCreate => 'बनाएँ';

  @override
  String get planActionReplace => 'बदलें';

  @override
  String get planActionSkip => 'छोड़ें';

  @override
  String get planActionConflict => 'संघर्ष';

  @override
  String get planActionBlockedByRisk => 'जोखिम से अवरुद्ध';

  @override
  String installationResultSummary(int succeeded, int failed) {
    return '$succeeded लक्ष्य स्थापित, $failed विफल';
  }

  @override
  String get installationProgressTitle => 'स्थापना प्रगति पर है';

  @override
  String installationProgressSummary(int finished, int total) {
    return '$total में से $finished लक्ष्य समाप्त';
  }

  @override
  String get targetWaiting => 'इंतज़ार कर रहा हूँ';

  @override
  String get targetRunning => 'स्थापित करना';

  @override
  String retryFailedTargets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count विफल लक्ष्य फिर आज़माएँ',
      one: '1 विफल लक्ष्य फिर आज़माएँ',
    );
    return '$_temp0';
  }

  @override
  String get updatePlanTitle => 'अद्यतन करने के लिए लक्ष्य चुनें';

  @override
  String get updatePlanDescription =>
      'सटीक स्थापना लक्ष्य चुनें. अचयनित Agents और प्रोजेक्ट अपरिवर्तित रहेंगे।';

  @override
  String updateTargetsSelected(int selected, int available) {
    return '$available में से $selected अद्यतन योग्य लक्ष्य चयनित';
  }

  @override
  String updateVersionChange(String fromVersion, String toVersion) {
    return '$fromVersion → $toVersion';
  }

  @override
  String sourceReference(String reference) {
    return 'स्रोत संदर्भ: $reference';
  }

  @override
  String get fixedVersionTarget => 'पिन किया गया - कोई चल संदर्भ नहीं';

  @override
  String get currentVersionTarget => 'अप टू डेट';

  @override
  String get updateCheckTargetFailed => 'अद्यतन जांच विफल रही';

  @override
  String get reconcileWorkspaceManifestTarget =>
      'Workspace Manifest की मरम्मत करें';

  @override
  String get updateSelectedTargets => 'चयनित लक्ष्य अद्यतन करें';

  @override
  String get updateProgressTitle => 'लक्ष्य अद्यतन किया जा रहा है';

  @override
  String get updateResultsTitle => 'परिणाम अद्यतन करें';

  @override
  String updateProgressSummary(int finished, int total) {
    return '$total में से $finished लक्ष्य समाप्त';
  }

  @override
  String retryFailedUpdates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count विफल अपडेट फिर आज़माएँ',
      one: '1 विफल अपडेट फिर आज़माएँ',
    );
    return '$_temp0';
  }

  @override
  String get noUpdateableTargets =>
      'किसी भी चयनित लक्ष्य के लिए अद्यतन उपलब्ध नहीं है।';

  @override
  String get closeUpdatePlan => 'बंद करें';

  @override
  String get targetSucceeded => 'स्थापित';

  @override
  String get targetSkipped => 'छोड़ दिया गया';

  @override
  String get targetConflict => 'संघर्ष';

  @override
  String get targetFailed => 'असफल';

  @override
  String get targetFailureRetryable =>
      'यह स्थान बदला नहीं जा सका. आप पुनः प्रयास कर सकते हैं.';

  @override
  String get targetFailureNeedsAttention =>
      'दोबारा प्रयास करने से पहले इस स्थान पर आपका ध्यान चाहिए।';

  @override
  String get installationTargetFailureMessage =>
      'इस स्थान पर कुछ भी नहीं बदला गया. जांचें कि फ़ोल्डर उपलब्ध है और पुनः प्रयास करें।';

  @override
  String get workspacePersistenceFailureMessage =>
      'कुछ भी नहीं बदला गया क्योंकि SkillsGo प्रोजेक्ट सेटिंग्स को सहेज नहीं सका। जांचें कि प्रोजेक्ट फ़ोल्डर लिखने योग्य है और पुनः प्रयास करें।';

  @override
  String get installationStateChangedMessage =>
      'जब आप इसकी समीक्षा कर रहे थे तो यह स्थान बदल गया। दोबारा प्रयास करने से पहले नवीनतम स्थिति की समीक्षा करें।';

  @override
  String get updateTargetFailureMessage =>
      'यह स्थान अद्यतन नहीं किया जा सका. अन्य स्थान प्रभावित नहीं हुए, इसलिए आप केवल इसी स्थान पर पुनः प्रयास कर सकते हैं।';

  @override
  String get managementTargetFailureMessage =>
      'यहां यह कार्रवाई पूरी नहीं हो सकी. अन्य स्थान प्रभावित नहीं हुए, इसलिए आप केवल इसी स्थान पर पुनः प्रयास कर सकते हैं।';

  @override
  String get technicalDetails => 'तकनीकी विवरण';

  @override
  String get targetPathExists => 'इस स्थान पर एक अन्य वस्तु पहले से मौजूद है.';

  @override
  String get targetBlockedByRisk =>
      'आपकी वर्तमान सुरक्षा सेटिंग्स ने इस स्थान पर इंस्टॉलेशन को अवरुद्ध कर दिया है।';

  @override
  String get targetInstallFailed =>
      'इस स्थान पर कौशल स्थापित नहीं किया जा सका.';

  @override
  String get targetWorkspaceUpdateFailed =>
      'कौशल स्थापित किया गया था, लेकिन प्रोजेक्ट सेटिंग्स अद्यतन नहीं की जा सकीं।';

  @override
  String get installationPlanFailed => 'स्थापना योजना जारी नहीं रह सकी';

  @override
  String get installationFailed => 'स्थापना पूर्ण नहीं हो सकी';

  @override
  String get localSource => 'स्थानीय स्रोत';

  @override
  String get noDescriptionAvailable => 'कोई विवरण उपलब्ध नहीं है';

  @override
  String moreCoverage(int count) {
    return '+$count अधिक स्थान';
  }

  @override
  String get batchTakeoverAction => 'मौजूदा कौशल प्रबंधित करें';

  @override
  String batchTakeoverActionCount(int count) {
    return 'प्रबंधित करें ($count)';
  }

  @override
  String get batchTakeoverChecking => 'मौजूदा कौशल की जाँच हो रही है...';

  @override
  String get batchTakeoverRetry => 'प्रबंधनीय कौशल फिर से जाँचें';

  @override
  String batchTakeoverEligibleCount(int count) {
    return '$count को प्रबंधित किया जा सकता है';
  }

  @override
  String get batchTakeoverPending => 'प्रबंधन में कौशल जोड़ना...';

  @override
  String get batchTakeoverTitle => 'SkillsGo के साथ मौजूदा कौशल प्रबंधित करें?';

  @override
  String get batchTakeoverDescription =>
      'SkillsGo कौशल फ़ाइलों को स्थानांतरित किए बिना, ओवरराइट किए या अपलोड किए बिना स्थानीय प्रबंधन रिकॉर्ड जोड़ देगा। असमर्थित या परिवर्तित आइटम छोड़ दिए जाएंगे.';

  @override
  String get batchTakeoverStoryTitle =>
      'बिखरे हुए कौशल को एक स्पष्ट पुस्तकालय में बदलें';

  @override
  String batchTakeoverStoryDescription(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count मौजूदा Skills',
      one: '1 मौजूदा Skill',
    );
    return 'SkillsGo को इस स्थान पर $_temp0 मिलीं जिन्हें वह प्रबंधित कर सकता है।';
  }

  @override
  String get batchTakeoverBeforeSemantics =>
      'प्रबंधन से पहले, यह स्पष्ट नहीं है कि मौजूदा कौशल कहां स्थापित किए गए हैं, क्या वे वर्तमान हैं, उन्हें कैसे पुनर्प्राप्त किया जाए, या क्या परियोजनाएं समान संस्करण का उपयोग करती हैं।';

  @override
  String get batchTakeoverPainLocation => 'अज्ञात इंस्टॉल स्थान';

  @override
  String get batchTakeoverPainFreshness => 'अज्ञात अद्यतन स्थिति';

  @override
  String get batchTakeoverPainRecovery => 'टूटने पर कोई पुनर्प्राप्ति नहीं';

  @override
  String get batchTakeoverPainVersionDrift =>
      'सभी परियोजनाओं में विभिन्न संस्करण';

  @override
  String get batchTakeoverFolderTitle => 'मौजूदा Skills';

  @override
  String get batchTakeoverFolderSubtitle => 'अस्पष्ट स्थिति';

  @override
  String get batchTakeoverAfterLabel => 'बाद में';

  @override
  String get batchTakeoverAfterTitle => 'एक स्पष्ट पुस्तकालय';

  @override
  String get batchTakeoverLibraryTitle => 'SkillsGo लाइब्रेरी';

  @override
  String get batchTakeoverBenefitLocation => 'स्थान साफ़ करें';

  @override
  String get batchTakeoverBenefitFreshness => 'अद्यतन दृश्यमान';

  @override
  String get batchTakeoverBenefitRecovery => 'आसान पुनर्प्राप्ति';

  @override
  String get batchTakeoverBenefitVersions => 'संस्करण स्पष्ट';

  @override
  String get batchTakeoverManagedSection => 'SkillsGo द्वारा प्रबंधित';

  @override
  String get batchTakeoverPendingSection => 'लंबित';

  @override
  String batchTakeoverItemManaged(String name) {
    return '$name का प्रबंधन SkillsGo द्वारा किया जाता है';
  }

  @override
  String batchTakeoverItemSkipped(String name) {
    return '$name को प्रबंधन में नहीं जोड़ा जा सका';
  }

  @override
  String batchTakeoverItemPending(String name) {
    return '$name प्रबंधित होने की प्रतीक्षा कर रहा है';
  }

  @override
  String batchTakeoverAfterSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Skills',
      one: '1 Skill',
    );
    return 'प्रबंधन के बाद, $_temp0 स्पष्ट प्रबंधित स्थिति वाली एक Library में व्यवस्थित हैं।';
  }

  @override
  String batchTakeoverMoreSkills(int count) {
    return '+$count और अधिक';
  }

  @override
  String get batchTakeoverTransitionSemantics =>
      'इन मौजूदा कौशलों को SkillsGo प्रबंधन में जोड़ें।';

  @override
  String get batchTakeoverTransitionLabel => 'व्यवस्थित करें';

  @override
  String get batchTakeoverStatusTitle => 'प्रबंधन की स्थिति';

  @override
  String get batchTakeoverStatusManaged => 'प्रबंधित';

  @override
  String get batchTakeoverStatusProgress => 'आयोजन';

  @override
  String get batchTakeoverStatusSkipped => 'छोड़ दिया गया';

  @override
  String get batchTakeoverStatusFilesStay =>
      'Skill फ़ाइलें अपने मूल स्थान पर रहती हैं';

  @override
  String get batchTakeoverBoardSemantics =>
      'Skills को पूरी पंक्तियों में व्यवस्थित किया गया है और उनकी फ़ाइलों को स्थानांतरित किए बिना SkillsGo द्वारा रिकॉर्ड किया गया है।';

  @override
  String get batchTakeoverBoardComplete => 'सब साफ़';

  @override
  String get batchTakeoverBoardPartial => 'पूर्ण';

  @override
  String get batchTakeoverStatusTotal => 'कुल';

  @override
  String get batchTakeoverQueueComplete => 'कोई कौशल इंतजार नहीं कर रहा है';

  @override
  String get batchTakeoverQueueWaiting =>
      'सत्यापन के बाद Skills यहाँ दिखाई देंगे';

  @override
  String get batchTakeoverNextLabel => 'अगला';

  @override
  String batchTakeoverFillerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count SkillsGo आयोजक ब्लॉक',
      one: '1 SkillsGo आयोजक ब्लॉक',
    );
    return '$_temp0 अंतिम पंक्तियाँ पूरी करते हैं।';
  }

  @override
  String get batchTakeoverPreservation =>
      'आपकी फ़ाइलें, पथ और वर्तमान वर्कफ़्लो बिल्कुल वहीं रहते हैं जहाँ वे हैं। SkillsGo केवल अपने स्थानीय प्रबंधन रिकॉर्ड को पूरा करता है।';

  @override
  String get batchTakeoverLaterHint =>
      'यदि आप छोड़ते हैं, तो आप किसी भी समय लाइब्रेरी से मौजूदा कौशल प्रबंधित करें का उपयोग कर सकते हैं।';

  @override
  String get batchTakeoverSkip => 'अभी नहीं';

  @override
  String get batchTakeoverConfirm => 'प्रबंधन में जोड़ें';

  @override
  String get batchTakeoverExecutionRetry => 'पुनः प्रयास करें';

  @override
  String get batchTakeoverResultTitle => 'Skills को प्रबंधन में जोड़ा गया';

  @override
  String batchTakeoverSummary(int takenOver, int skipped) {
    return '$takenOver कौशल को प्रबंधन में जोड़ा गया, $skipped को छोड़ दिया गया।';
  }

  @override
  String get batchTakeoverClose => 'बंद करें';

  @override
  String get installMoreTargets => 'अधिक स्थानों पर स्थापित करें';

  @override
  String get detailRepository => 'भण्डार';

  @override
  String get detailStars => 'सितारे';

  @override
  String get detailUpdated => 'अद्यतन किया गया';

  @override
  String get detailArchiveSize => 'ZIP आकार';

  @override
  String get pathLabel => 'प्रोजेक्ट पथ';

  @override
  String get copyProjectPath => 'प्रोजेक्ट पथ कॉपी करें';

  @override
  String get projectPathCopied => 'प्रोजेक्ट पथ की प्रतिलिपि बनाई गई';

  @override
  String get onboardingWelcomeTitle => 'SkillsGo में आपका स्वागत है';

  @override
  String get onboardingWelcomeDescription =>
      'अपने Agents और प्रोजेक्ट्स में Skills खोजें, इंस्टॉल करें और प्रबंधित करें।';

  @override
  String get onboardingDetectedAgents => 'पहचाने गए Agents';

  @override
  String get onboardingNoAgents =>
      'कोई इंस्टॉल किया गया Agent नहीं मिला। आप फिर भी जारी रख सकते हैं।';

  @override
  String get onboardingNext => 'अगला';

  @override
  String get onboardingProjectsTitle => 'अपने प्रोजेक्ट जोड़ें';

  @override
  String get onboardingProjectsDescription =>
      'वे प्रोजेक्ट चुनें जिन्हें आप SkillsGo प्रबंधित करना चाहते हैं।';

  @override
  String get onboardingAddProject => 'अभी जोड़ें';

  @override
  String get onboardingAddProjectLater => 'या बाद में';

  @override
  String get onboardingStartUsing => 'SkillsGo का उपयोग प्रारंभ करें';

  @override
  String get onboardingBack => 'वापस';

  @override
  String get restartOnboardingTitle => 'जहाज पर चढ़ना';

  @override
  String get restartOnboardingDescription =>
      'प्रोजेक्ट, सेटिंग्स या Skills डेटा को हटाए बिना पहली-लॉन्च गाइड को दोबारा देखें।';

  @override
  String get restartOnboardingAction => 'ऑनबोर्डिंग पुनः प्रारंभ करें';

  @override
  String get restartOnboardingFailed =>
      'SkillsGo ऑनबोर्डिंग पुनः आरंभ नहीं कर सका।';

  @override
  String get libraryRefreshSettingsTitle => 'स्थानीय लाइब्रेरी को ताज़ा करें';

  @override
  String get libraryRefreshSettingsDescription =>
      'स्थापित Skills, जोड़े गए प्रोजेक्ट, Agents और बाहरी Skills को पुनः स्कैन करें जिन्हें प्रबंधित किया जा सकता है। यह कुछ भी इंस्टॉल, अपडेट या हटाता नहीं है।';

  @override
  String get libraryRefreshSettingsAction => 'लाइब्रेरी ताज़ा करें';

  @override
  String get libraryRefreshSettingsPending => 'लाइब्रेरी ताज़ा हो रही है...';

  @override
  String get libraryRefreshSettingsSuccess =>
      'स्थानीय पुस्तकालय को ताज़ा किया गया।';

  @override
  String get libraryRefreshSettingsFailed =>
      'SkillsGo स्थानीय लाइब्रेरी को ताज़ा नहीं कर सका।';

  @override
  String get onboardingProjectError =>
      'SkillsGo इस निर्देशिका से प्रोजेक्ट नहीं जोड़ सका।';

  @override
  String get onboardingProjectsLoadError =>
      'SkillsGo आपके जोड़े गए प्रोजेक्ट लोड नहीं कर सका।';

  @override
  String get onboardingStartupError => 'SkillsGo सेटअप लोड नहीं कर सका.';

  @override
  String get onboardingStateError =>
      'SkillsGo आपकी सेटअप प्रगति को सहेज नहीं सका। पुनः प्रयास करें।';

  @override
  String get onboardingCliErrorTitle =>
      'SkillsGo CLI पर ध्यान देने की जरूरत है';

  @override
  String get onboardingCliErrorDescription =>
      'बंडल किए गए CLI की मरम्मत करें, फिर जारी रखने के लिए पुनः प्रयास करें।';
}
