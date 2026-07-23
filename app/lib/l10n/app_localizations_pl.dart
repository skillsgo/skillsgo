// ignore_for_file: text_direction_code_point_in_literal, text_direction_code_point_in_comment

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get discover => 'Odkryć';

  @override
  String get discoverSkills => 'Miło jest wiedzieć trochę więcej.';

  @override
  String get library => 'Biblioteka';

  @override
  String get settings => 'Ustawienia';

  @override
  String get openSettings => 'Otwórz Ustawienia';

  @override
  String get cliNeedsAttention => 'Wymagany komponent SkillsGo wymaga uwagi.';

  @override
  String get cliMissingBundled =>
      'Brak wymaganego komponentu SkillsGo lub nie można go uruchomić. Zainstaluj ponownie SkillsGo, aby go przywrócić.';

  @override
  String get cliDamagedBundled =>
      'Wymagany komponent SkillsGo jest uszkodzony. Zainstaluj ponownie SkillsGo, aby go przywrócić.';

  @override
  String get cliIncompatibleBundled =>
      'Wymagany komponent SkillsGo nie pasuje do tej wersji aplikacji. Zaktualizuj lub zainstaluj ponownie SkillsGo.';

  @override
  String get officialIndex => 'SkillsGo Hub';

  @override
  String get discoverTitle => 'Znajdź skill do następnego ruchu.';

  @override
  String get skillsLeaderboard => 'Miło jest wiedzieć trochę więcej.';

  @override
  String searchResultsFor(String query) {
    return 'Wyniki dla „$query”';
  }

  @override
  String get searchSkills => 'Wyszukaj skills lub wklej link Git…';

  @override
  String get search => 'Szukaj';

  @override
  String get ranking => 'Zaszeregowanie';

  @override
  String get trending => 'Trendy';

  @override
  String get hot => 'Gorący';

  @override
  String get discoverNavigation => 'Odkryj nawigację';

  @override
  String get allTimeRanking => 'Ranking wszechczasów';

  @override
  String get trendingNow => 'Trendy w ciągu ostatnich 24 godzin';

  @override
  String get hotNow => 'Gorąco teraz';

  @override
  String get allTimeDescription =>
      'Publiczne Skills posortowane według łącznej liczby zaakceptowanych instalacji.';

  @override
  String get trendingDescription =>
      'Publiczne Skills posortowane według zaakceptowanych instalacji z ostatnich 24 godzin.';

  @override
  String get hotDescription =>
      'Publiczne Skills posortowane według krótkoterminowego tempa instalacji i jego zmiany.';

  @override
  String get offlineTitle => 'Nie można połączyć się z SkillsGo';

  @override
  String get offlineMessage =>
      'Sprawdź swoje połączenie internetowe i spróbuj ponownie. Jeśli korzystasz z serwera proxy lub niestandardowego adresu usługi, sprawdź to w Ustawieniach.';

  @override
  String get searchFailedTitle => 'Wyszukiwanie nie powiodło się';

  @override
  String get validationTitle => 'Sprawdź, co wpisałeś';

  @override
  String get validationMessage =>
      'SkillsGo nie mógł skorzystać z tego żądania. Sprawdź wprowadzone dane i spróbuj ponownie.';

  @override
  String get serverTitle => 'Usługa chwilowo niedostępna';

  @override
  String get serverMessage =>
      'SkillsGo nie może teraz zrealizować tego żądania. Spróbuj ponownie za chwilę.';

  @override
  String get timeoutTitle => 'To trwa zbyt długo';

  @override
  String get timeoutMessage =>
      'Serwis nie odpowiedział na czas. Sprawdź połączenie lub spróbuj ponownie.';

  @override
  String get invalidResponseTitle => 'SkillsGo wymaga aktualizacji';

  @override
  String get invalidResponseMessage =>
      'Ta odpowiedź nie może zostać odczytana przez twoją wersję SkillsGo. Zaktualizuj aplikację i spróbuj ponownie.';

  @override
  String get invalidLocalDataTitle =>
      'Nie można odczytać zainstalowanego skill';

  @override
  String get invalidLocalDataMessage =>
      'Niektóre informacje dotyczące instalacji lokalnej są uszkodzone lub niezgodne. Zaktualizuj lub zainstaluj ponownie SkillsGo, a następnie spróbuj ponownie.';

  @override
  String get tryAgain => 'Spróbuj ponownie';

  @override
  String get searchEmptyTitle => 'Szukaj, nie przewijaj.';

  @override
  String get searchEmptyMessage =>
      'Wprowadź możliwość, źródło lub zadanie do przeszukiwania publicznego skills.';

  @override
  String get noSkillsTitle => 'Nie znaleziono skills';

  @override
  String get noSkillsMessage =>
      'Spróbuj użyć szerszego wyrażenia lub sprawdź pisownię.';

  @override
  String get focusSearch => 'Wyszukiwanie fokusowe';

  @override
  String get skillsFromLink => 'Skills z tego linku';

  @override
  String skillCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count skills',
      one: '1 skill',
    );
    return '$_temp0';
  }

  @override
  String sourceResultsSummary(String source, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count skills z $source',
      one: '1 skill z $source',
    );
    return '$_temp0';
  }

  @override
  String get sourceSearchEmptyTitle => 'To łącze jest gotowe do sprawdzenia';

  @override
  String sourceSearchEmptyMessage(String source) {
    return '$source nie ma w bieżących wynikach wyszukiwania. SkillsGo może sprawdzić łącze bezpośrednio w następnym kroku.';
  }

  @override
  String get inspectSource => 'Zobacz skills pod tym linkiem';

  @override
  String get collectionEmptyTitle => 'W tej kolekcji nie ma Skills';

  @override
  String get collectionEmptyMessage =>
      'Jeszcze nic tu nie ma. Spróbuj ponownie po większej aktywności instalacyjnej.';

  @override
  String get loadMore => 'Załaduj więcej';

  @override
  String get install => 'Zainstalować';

  @override
  String get installAll => 'Zainstaluj wszystkie skills';

  @override
  String get latestCommit => 'Najnowsze zatwierdzenie';

  @override
  String get installToMoreTargets =>
      'Zainstaluj w większej liczbie lokalizacji';

  @override
  String localTargets(int count) {
    return 'Lokalne cele $count';
  }

  @override
  String allTimeMetric(String count) {
    return 'Instalacje $count wszechczasów';
  }

  @override
  String trendingMetric(String count) {
    return 'Instalacje $count / 24h';
  }

  @override
  String hotMetric(String value, String change) {
    return '$value w tej godzinie · $change';
  }

  @override
  String get trustUnverified => 'Niesprawdzony';

  @override
  String get trustCommunityVerified => 'Społeczność zweryfikowana';

  @override
  String get trustPublisherVerified => 'Wydawca zweryfikowany';

  @override
  String get trustOfficial => 'Urzędnik';

  @override
  String get trustWarned => 'Ostrzeżony';

  @override
  String get trustDelisted => 'Usunięto';

  @override
  String get riskUnknown => 'Ryzyko nieznane';

  @override
  String get riskLow => 'Niskie ryzyko';

  @override
  String get riskMedium => 'Średnie ryzyko';

  @override
  String get riskHigh => 'Wysokie ryzyko';

  @override
  String get riskCritical => 'Ryzyko krytyczne';

  @override
  String openSkill(String name) {
    return 'Otwórz $name';
  }

  @override
  String installs(String count) {
    return 'Instaluje się $count';
  }

  @override
  String get detailFailedTitle => 'Nie można załadować tego Skill';

  @override
  String get detailLoading =>
      'Ładowanie podlegających kontroli szczegółów Skill';

  @override
  String get artifactUnavailableTitle => 'Artefakt niedostępny';

  @override
  String get artifactUnavailableMessage =>
      'Ta wersja nie jest obecnie dostępna. Spróbuj ponownie lub wybierz inną wersję.';

  @override
  String get detailInvalidTitle => 'Metadane artefaktów nie są obsługiwane';

  @override
  String get detailInvalidMessage =>
      'Niektóre szczegóły tego skill są niekompletne lub nie można ich odczytać. Zaktualizuj SkillsGo i spróbuj ponownie.';

  @override
  String get instructionsTab => 'Instrukcje';

  @override
  String get manifestTab => 'Oczywisty';

  @override
  String immutableVersionLabel(String version) {
    return 'Niezmienny $version';
  }

  @override
  String commitIdentity(String sha) {
    return 'Zatwierdź $sha';
  }

  @override
  String treeIdentity(String sha) {
    return 'Drzewo $sha';
  }

  @override
  String contentIdentity(String digest) {
    return 'Treść $digest';
  }

  @override
  String get trustDoesNotProveSafety =>
      'Zaufanie wydawcy weryfikuje własność lub konserwację; nie potwierdza bezpieczeństwa artefaktów. Ryzyko jest oceniane oddzielnie dla tej niezmiennej wersji.';

  @override
  String get knownInstallationTargets => 'Znane cele instalacji';

  @override
  String get installationRange => 'Zainstalowany zakres';

  @override
  String get targetDetails => 'Pokaż szczegóły celu';

  @override
  String get hideTargetDetails => 'Ukryj szczegóły celu';

  @override
  String installedVersionLabel(String version) {
    return 'Wersja $version';
  }

  @override
  String targetSummary(String scope, String agent, String version) {
    return '$scope / $agent · $version';
  }

  @override
  String get projectScope => 'Projekt';

  @override
  String get fileContentUnavailable => 'Podgląd binarny lub niedostępny';

  @override
  String get fileContentTruncated =>
      'Podgląd obcięty ze względu na limit bezpieczeństwa Hub.';

  @override
  String get retry => 'Spróbować ponownie';

  @override
  String get backToSearch => 'Wróć do wyszukiwania';

  @override
  String get installForCodex => 'Zainstaluj dla Codex';

  @override
  String get cliNotDetected => 'skills (nie wykryto)';

  @override
  String get snapshotFiles => 'Pliki migawek';

  @override
  String get globalCodex => 'Globalny · Codex';

  @override
  String get yourLibrary => 'Wszystko, co wiesz, jest tutaj.';

  @override
  String get libraryNavigation => 'Nawigacja w bibliotece';

  @override
  String get all => 'Wszystko';

  @override
  String get allSkills => 'Wszystkie Skills';

  @override
  String get updatesOnly => 'Aktualizacje';

  @override
  String get allAgents => 'Wszystkie Agents';

  @override
  String get allProjects => 'Wszystkie projekty';

  @override
  String get specificProject => 'Projekt';

  @override
  String get userScope => 'Światowy';

  @override
  String get addProject => 'Dodaj projekt';

  @override
  String get relocateProject => 'Przenieść się';

  @override
  String get removeFromList => 'Usuń z listy';

  @override
  String removeProjectTitle(String name) {
    return 'Usunąć $name z SkillsGo?';
  }

  @override
  String get removeProjectDescription =>
      'Usunięte zostanie tylko odniesienie do aplikacji. SkillsGo nie zmieni ani nie usunie żadnych plików w tym katalogu.';

  @override
  String projectRailUnavailable(String name) {
    return '$name — niedostępny';
  }

  @override
  String get emptyProjectTitle => 'Nie ma jeszcze Skills';

  @override
  String get browseSkills => 'Przeglądaj Skills';

  @override
  String get projectMissingTitle => 'Brak katalogu projektu';

  @override
  String get projectMissingMessage =>
      'Katalog mógł zostać przeniesiony lub jego wolumen może być w trybie offline. Przenieś go lub usuń tylko odniesienie do aplikacji.';

  @override
  String get projectPermissionTitle => 'Wymagane jest pozwolenie na projekt';

  @override
  String get projectPermissionMessage =>
      'SkillsGo nie może sprawdzić tego wybranego katalogu głównego. Przyznaj dostęp, przenosząc go za pomocą selektora katalogów.';

  @override
  String get projectInaccessibleTitle => 'Katalog projektu jest niedostępny';

  @override
  String get projectInaccessibleMessage =>
      'SkillsGo zachował to odniesienie do projektu. Sprawdź ścieżkę lub wolumin, a następnie przenieś go.';

  @override
  String get checking => 'Kontrola…';

  @override
  String get checkUpdates => 'Sprawdź aktualizacje';

  @override
  String get refresh => 'Odświeżać';

  @override
  String get libraryUnavailable => 'Biblioteka niedostępna';

  @override
  String get libraryEmpty => 'Nie zainstalowano jeszcze żadnego skills';

  @override
  String get libraryEmptyMessage =>
      'Zainstaluj Skill z Discover, a pojawi się tutaj.';

  @override
  String get searchLibrary => 'Wyszukaj zainstalowany skills';

  @override
  String get libraryNoMatches => 'Brak pasującego Skills';

  @override
  String get libraryNoMatchesMessage =>
      'Wypróbuj inną nazwę, źródło, Agent, projekt lub wersję.';

  @override
  String agentsSummary(int count) {
    return '$count Agents';
  }

  @override
  String projectsSummary(int count) {
    return 'Projekty $count';
  }

  @override
  String versionsSummary(int count) {
    return 'Wersje $count';
  }

  @override
  String get hubManaged => 'Zarządzane Hub';

  @override
  String get localManaged => 'Zarządzane lokalnie';

  @override
  String get externalInstallation => 'Instalacja zewnętrzna';

  @override
  String get readOnly => 'Tylko do odczytu';

  @override
  String get unversioned => 'Niewersjonowane';

  @override
  String get supportingFiles => 'Pliki pomocnicze';

  @override
  String get versionDivergence => 'Rozbieżność wersji';

  @override
  String get healthHealthy => 'Zdrowy';

  @override
  String get healthMissing => 'Brak celu';

  @override
  String get healthReplaced => 'Cel wymieniony';

  @override
  String get healthLocalModification => 'Lokalna modyfikacja';

  @override
  String get healthUnreadable => 'Cel nieczytelny';

  @override
  String get healthUndeclared => 'Nie zadeklarowano';

  @override
  String get healthWorkspaceUnreadable => 'Stan obszaru roboczego nieczytelny';

  @override
  String get healthLockMismatch => 'Niedopasowanie blokady';

  @override
  String get healthUnexpectedPath => 'Nieoczekiwana ścieżka docelowa';

  @override
  String get modeExternal => 'Zewnętrzny';

  @override
  String get notLinked => 'NIE POŁĄCZONE';

  @override
  String get update => 'Aktualizacja';

  @override
  String get backToLibrary => 'Powrót do Biblioteki';

  @override
  String get remove => 'Usunąć';

  @override
  String get manageTargets => 'Zarządzaj zakresem';

  @override
  String skillsSelected(int count) {
    return 'Wybrano $count';
  }

  @override
  String get clearSelection => 'Wyczyść wybór';

  @override
  String get selectCurrentResults => 'Aktualne wyniki Select';

  @override
  String get clearCurrentResultSelection => 'Wyczyść bieżący wybór wyników';

  @override
  String get manageTargetsTitle => 'Zarządzaj celami instalacji';

  @override
  String get manageTargetsDescription =>
      'Wybierz konkretną akcję dla każdego celu. Niewybrane cele nie ulegną zmianie.';

  @override
  String targetActionsSelected(int selected, int total) {
    return 'Wybrano cele $selected z $total';
  }

  @override
  String get confirmRemoveTarget => 'Potwierdź usunięcie';

  @override
  String get applyTargetActions => 'Zastosuj wybrane działania';

  @override
  String get managementProgressTitle => 'Stosowanie działań docelowych';

  @override
  String get managementResultsTitle => 'Docelowe wyniki działań';

  @override
  String managementResultSummary(int succeeded, int failed) {
    return '$succeeded powiodło się, $failed nie powiodło się';
  }

  @override
  String get workspaceOwnershipChanges =>
      'Wybrane działania projektu zostaną zaktualizowane skillsgo.yaml i skillsgo.lock.';

  @override
  String get targetContentPreserved =>
      'Bieżąca treść docelowa zostanie zachowana.';

  @override
  String get localReadFailed => 'Nie można odczytać tego Skill';

  @override
  String get localReadFailedMessage =>
      'SkillsGo nie mógł odczytać zainstalowanego skill. Sprawdź, czy jego folder jest dostępny i dostępny, a następnie spróbuj ponownie.';

  @override
  String get localConfiguration => 'USTAWIENIA SKILLSGO';

  @override
  String get settingsNavigation => 'Ustawienia nawigacji';

  @override
  String get general => 'Być uosobieniem';

  @override
  String get agents => 'Agents';

  @override
  String get hub => 'Hub';

  @override
  String get installationPolicy => 'Zasady instalacji';

  @override
  String get storage => 'Składowanie';

  @override
  String get colorScheme => 'Schemat kolorów';

  @override
  String get about => 'O';

  @override
  String get colorSchemeInspectorTitle => 'Wygenerowano role kolorów Material';

  @override
  String get skillsColorTokensTitle => 'Kolory semantyczne SkillsGo';

  @override
  String get skillsColorTokensDescription =>
      'Kolory produktu zbudowane na podstawie Radix Sand i zorganizowane przy użyciu semantyki Primer, z Folder jako dedykowaną hierarchią przestrzenną.';

  @override
  String get colorSchemeInspectorDescription =>
      'Wyświetl podgląd każdego nieprzestarzałego tokena ColorScheme wygenerowanego z bieżącego materiału siewnego. Kliknij kolor, aby skopiować jego wartość HEX.';

  @override
  String get colorSchemePairPreview => 'Pary semantyczne';

  @override
  String get colorSchemePairPreviewDescription =>
      'Role pierwszego planu i tła renderowane razem, aby uwidocznić kontrast i hierarchię.';

  @override
  String get colorSchemeComponentPreview => 'Podgląd komponentu';

  @override
  String get colorSchemeComponentPreviewDescription =>
      'Reprezentatywne elementy sterujące Material renderowane przy użyciu dokładnie tego schematu podglądu.';

  @override
  String get colorSchemeSampleTitle => 'Tytuł karty Skill';

  @override
  String get colorSchemeSampleBody => 'Kopia dodatkowa używa onSurfaceVariant.';

  @override
  String get colorSchemeCopied => 'Skopiowano';

  @override
  String get colorSchemeSampleGlyphs => 'Aaa 123';

  @override
  String get colorSchemeGroupPrimary => 'Podstawowy';

  @override
  String get colorSchemeGroupPrimaryDescription =>
      'Główny nacisk, pojemniki i stałe role akcentujące.';

  @override
  String get colorSchemeGroupSecondary => 'Wtórny';

  @override
  String get colorSchemeGroupSecondaryDescription =>
      'Nacisk wspierający i ustalone role drugoplanowe.';

  @override
  String get colorSchemeGroupTertiary => 'Trzeciorzędowy';

  @override
  String get colorSchemeGroupTertiaryDescription =>
      'Kontrastujące akcenty i ustalone role trzeciorzędne.';

  @override
  String get colorSchemeGroupSurface => 'Powierzchnia';

  @override
  String get colorSchemeGroupSurfaceDescription =>
      'Hierarchia strony, kontenera, elewacji i pierwszego planu.';

  @override
  String get colorSchemeGroupUtility => 'Zarys i użyteczność';

  @override
  String get colorSchemeGroupUtilityDescription =>
      'Granice, cienie, siatki i powierzchnie odwrotne.';

  @override
  String get colorSchemeGroupError => 'Błąd';

  @override
  String get colorSchemeGroupErrorDescription =>
      'Działania związane z błędami, komunikaty i kontenery.';

  @override
  String get colorSchemeUsagePrimary =>
      'Działania podstawowe, skupienie i akcenty o dużym nacisku.';

  @override
  String get colorSchemeUsageSecondary =>
      'Działania wspierające i akcenty o średnim nacisku.';

  @override
  String get colorSchemeUsageTertiary =>
      'Kontrastujące akcenty, które uzupełniają pierwotne i wtórne.';

  @override
  String colorSchemeUsageContentOn(String token) {
    return 'Tekst i ikony wyświetlane na $token.';
  }

  @override
  String colorSchemeUsageContainer(String family) {
    return 'Pojemnik $family o niższym nacisku na selekcje i akcenty.';
  }

  @override
  String colorSchemeUsageFixed(String family) {
    return 'Niezależny od jasności stały pojemnik $family.';
  }

  @override
  String colorSchemeUsageFixedDim(String family) {
    return 'Przyciemniony, niezależny od jasności, stały pojemnik $family.';
  }

  @override
  String colorSchemeUsageFixedContent(String family) {
    return 'Treści o dużym nacisku na stałym pojemniku $family.';
  }

  @override
  String colorSchemeUsageFixedVariantContent(String family) {
    return 'Treść o mniejszym nacisku na stałym kontenerze $family.';
  }

  @override
  String get colorSchemeUsageSurface =>
      'Strona bazowa i powierzchnia wielkoobszarowa.';

  @override
  String get colorSchemeUsageSurfaceDim =>
      'Przyciemniona powierzchnia bazowa stosowana przy najciemniejszym odcieniu powierzchni.';

  @override
  String get colorSchemeUsageSurfaceBright =>
      'Jasna powierzchnia bazowa stosowana przy najjaśniejszym odcieniu powierzchni.';

  @override
  String colorSchemeUsageSurfaceElevation(String level) {
    return 'Elewacja kontenera naziemnego $level.';
  }

  @override
  String get colorSchemeElevationLowest => 'najniższy';

  @override
  String get colorSchemeElevationLow => 'Niski';

  @override
  String get colorSchemeElevationDefault => 'domyślny';

  @override
  String get colorSchemeElevationHigh => 'wysoki';

  @override
  String get colorSchemeElevationHighest => 'najwyższy';

  @override
  String get colorSchemeUsageOnSurface =>
      'Podstawowy tekst i ikony wyświetlane na powierzchniach.';

  @override
  String get colorSchemeUsageOnSurfaceVariant =>
      'Tekst dodatkowy, etykiety i przytłumione ikony na powierzchniach.';

  @override
  String get colorSchemeUsageSurfaceTint =>
      'Odcień elewacji Material wywodzący się z podstawowego.';

  @override
  String get colorSchemeUsageOutline =>
      'Wyraźne granice i skupione kontury komponentów.';

  @override
  String get colorSchemeUsageOutlineVariant =>
      'Subtelne granice, separatory i kontury o niskim nacisku.';

  @override
  String get colorSchemeUsageShadow =>
      'Kolor cieniujący dla podwyższonych powierzchni.';

  @override
  String get colorSchemeUsageScrim =>
      'Nakładka modalna używana do zmniejszania nacisku na zawartość tła.';

  @override
  String get colorSchemeUsageInverseSurface =>
      'Powierzchnia z odwróconym akcentem światła i ciemności.';

  @override
  String get colorSchemeUsageInversePrimary =>
      'Główny akcent wyświetlany na odwrotnej powierzchni.';

  @override
  String get colorSchemeUsageError =>
      'Działania związane z błędami, status i informacje zwrotne o dużym nacisku.';

  @override
  String get save => 'Ratować';

  @override
  String get advancedSettings => 'Zaawansowany';

  @override
  String get remindersSettings => 'Przypomnienia';

  @override
  String get remindersSettingsTitle => 'Ustawienia przypomnień';

  @override
  String get remindersSettingsDescription =>
      'Wybierz, które przypomnienia chcesz otrzymywać.';

  @override
  String get updateReminderTitle => 'Aktualizuj przypomnienia';

  @override
  String get updateReminderDescription =>
      'Sprawdź aktualizacje po otwarciu biblioteki.';

  @override
  String get securityReminderTitle => 'Alerty wysokiego ryzyka';

  @override
  String get securityReminderDescription =>
      'Powiadamia Cię o nowych zagrożeniach Wysokich lub Krytycznych w zainstalowanym skills.';

  @override
  String availableUpdatesReminder(int count) {
    return '$count zainstalowany skills ma aktualizacje';
  }

  @override
  String get openAvailableUpdates =>
      'Otwórz widok dostępnych aktualizacji, aby je przejrzeć i zaktualizować.';

  @override
  String securityAdvisoriesReminder(int count) {
    return 'Zainstalowany $count skills wymaga przeglądu bezpieczeństwa';
  }

  @override
  String get reviewInstalledSkills =>
      'Przed użyciem lub aktualizacją zapoznaj się z zawartymi w nich informacjami o ryzyku.';

  @override
  String get generalSettingsTitle => 'Spraw, aby SkillsGo był Twój';

  @override
  String get generalSettingsDescription =>
      'Interfejs dostosowuje się do języka systemu, dostępności i preferencji ruchu.';

  @override
  String get agentsSettingsTitle => 'Środowisko wykonawcze Agent';

  @override
  String get hubSettingsTitle => 'Pochodzenie Hub';

  @override
  String get hubSettingsDescription =>
      'Użyj oficjalnego Hub lub samodzielnego źródła HTTP(S), które implementuje ten sam protokół SkillsGo.';

  @override
  String get testConnection => 'Połączenie testowe';

  @override
  String get saveOrigin => 'Zapisz Pochodzenie';

  @override
  String get resetDefault => 'Przywróć ustawienia domyślne';

  @override
  String get connectionReady => 'Połączenie gotowe';

  @override
  String get connectionFailed => 'Połączenie nie powiodło się';

  @override
  String get hubInvalidOrigin =>
      'Wprowadź prawidłowe źródło HTTP(S) bez poświadczeń, zapytania lub fragmentu.';

  @override
  String hubHttpFailure(int status) {
    return 'Hub zwróciło HTTP $status. Sprawdź Origin i konfigurację serwera.';
  }

  @override
  String get hubInvalidProtocol =>
      'Serwer nie zwrócił protokołu wyszukiwania SkillsGo Hub.';

  @override
  String get hubInvalidJson => 'Hub zwrócił nieprawidłowy JSON.';

  @override
  String get hubConnectionFailure =>
      'Nie udało się połączyć z Hub. Sprawdź konfigurację Origin, sieci, proxy i TLS.';

  @override
  String get hubConnectionTimeout =>
      'Upłynął limit czasu połączenia Hub. Sprawdź sieć lub spróbuj ponownie.';

  @override
  String get riskPolicyTitle => 'Polityka ryzyka osobistego';

  @override
  String get riskPolicyDescription =>
      'Podczas instalacji lub aktualizacji skill obowiązują zasady bezpieczeństwa.';

  @override
  String get confirmHighRisk => 'Wymagaj potwierdzenia dla wysokiego ryzyka';

  @override
  String get confirmHighRiskDescription =>
      'Artefakty wysokiego ryzyka zawsze wymagają dodatkowego potwierdzenia przed instalacją.';

  @override
  String get allowCriticalOverride =>
      'Zezwalaj na jawne obejście ryzyka krytycznego';

  @override
  String get allowCriticalOverrideDescription =>
      'Artefakty związane z ryzykiem krytycznym pozostają domyślnie blokowane. Włącz tę opcję tylko, aby udostępnić oddzielne ręczne nadpisanie.';

  @override
  String get storageHealthy => 'Czytelny';

  @override
  String get storageNotInitialized => 'Nie zainicjowano';

  @override
  String get storageUnavailable => 'Nie płynny';

  @override
  String get storageInvalidResponse =>
      'Dołączony CLI zwrócił nieobsługiwaną odpowiedź diagnostyczną.';

  @override
  String get aboutSettingsTitle => 'Kompatybilność produktu';

  @override
  String get appVersion => 'Wersja aplikacji';

  @override
  String get cliVersion => 'Dołączona wersja CLI';

  @override
  String get compatible => 'Zgodny';

  @override
  String get hubOriginSaved =>
      'Hub Pochodzenie zostało zapisane i zastosowane.';

  @override
  String get policySaved => 'Zasady instalacji zostały zapisane.';

  @override
  String get officialCli => 'SkillsGo CLI';

  @override
  String get ready => 'GOTOWY';

  @override
  String get unknown => 'NIEZNANY';

  @override
  String get missing => 'ZAGINIONY';

  @override
  String get incompatible => 'NIEZGODNY';

  @override
  String get detecting => 'Wykrywanie…';

  @override
  String get customCliPath => 'Niestandardowa ścieżka pliku wykonywalnego';

  @override
  String get saveAndDetect => 'Zapisz i wykryj';

  @override
  String get detectAgain => 'Wykryj ponownie';

  @override
  String get agentInstalled => 'Zainstalowany';

  @override
  String get agentSupported => 'Utrzymany';

  @override
  String agentCatalogSummary(int installed, int supported) {
    return 'Zainstalowano $installed · Obsługiwane $supported';
  }

  @override
  String installedAgentsTitle(int count) {
    return 'Zainstalowano · $count';
  }

  @override
  String notInstalledAgentsTitle(int count) {
    return 'Niezainstalowany · $count';
  }

  @override
  String get notInstalledAgentsDescription =>
      'Obsługiwane przez SkillsGo, ale nie wykryte na tym komputerze Mac.';

  @override
  String agentDiscoveryRoots(String paths) {
    return 'Skill ścieżki ładowania: $paths';
  }

  @override
  String get agentInspectionFailed =>
      'Dane dotyczące wykrywania Agent są niedostępne. Uruchom ponownie wykrywanie.';

  @override
  String get noInstalledAgentsTitle => 'Nie wykryto zainstalowanego Agents';

  @override
  String get noInstalledAgentsMessage =>
      'Możesz dalej przeglądać ten Skill, ale nie ma jeszcze celu instalacji. Zainstaluj obsługiwany Agent, a następnie ponownie uruchom wykrywanie.';

  @override
  String get clearCustomPath => 'Wyczyść niestandardową ścieżkę';

  @override
  String get privacyProvenance => 'Prywatność i pochodzenie';

  @override
  String get privacySummary =>
      'Twoje wyszukiwania nie są zapisywane, a SkillsGo nie przechowuje dzienników poleceń.';

  @override
  String get language => 'Język';

  @override
  String get personalizationTheme => 'Temat';

  @override
  String get folderColorTheme => 'Kolor motywu';

  @override
  String get folderColorThemeDescription =>
      'Wybierz kolor, który Ci się podoba. SkillsGo zbuduje wokół niego skoordynowaną paletę interfejsów.';

  @override
  String get brandNameNeteaseCloudMusic => 'Muzyka w chmurze NetEase';

  @override
  String get brandNameRaspberryPi => 'Malinowe Pi';

  @override
  String get brandNameChinaEasternAirlines =>
      'Chińskie wschodnie linie lotnicze';

  @override
  String get brandNameNvidia => 'NVIDIA';

  @override
  String get brandNameTaobao => 'Taobao';

  @override
  String get brandNameBitcoin => 'Bitcoina';

  @override
  String get appearanceMode => 'Tryb';

  @override
  String get appearanceModeDescription =>
      'Postępuj zgodnie z wyglądem systemu lub zawsze używaj jasnego lub ciemnego motywu.';

  @override
  String get followSystem => 'System';

  @override
  String get lightMode => 'Światło';

  @override
  String get darkMode => 'Ciemny';

  @override
  String get wallpaper => 'Tapeta';

  @override
  String get wallpaperDescription =>
      'Wybierz niebiańskie tło. Twój wybór pojawi się bezpośrednio za Folder.';

  @override
  String get wallpaperSun => 'Słoneczny';

  @override
  String get wallpaperMercury => 'Rtęć';

  @override
  String get wallpaperVenus => 'Wenus';

  @override
  String get wallpaperEarth => 'Ziemia';

  @override
  String get wallpaperMars => 'Mars';

  @override
  String get wallpaperJupiter => 'Jupiter';

  @override
  String get wallpaperSaturn => 'Saturn';

  @override
  String get wallpaperUranus => 'Uran';

  @override
  String get wallpaperNeptune => 'Neptun';

  @override
  String get wallpaperPluto => 'Pluton';

  @override
  String get wallpaperMoon => 'Księżyc';

  @override
  String folderThemeChoice(String theme) {
    return 'Motyw $theme Folder';
  }

  @override
  String get privacyAffiliation =>
      'Telemetria instalacji anonimowej jest kontrolowana przez ustawienia SkillsGo. SkillsGo nie jest powiązany z OpenAI ani Codex.';

  @override
  String get commandCompleted => 'Polecenie wykonane';

  @override
  String get commandFailed => 'Polecenie nie powiodło się';

  @override
  String commandExit(int code) {
    return 'Wyjdź z $code · rozwiń dziennik tej sesji';
  }

  @override
  String get command => 'Rozkaz';

  @override
  String get cancel => 'Anuluj';

  @override
  String get updateUnknown => 'NIEZNANY';

  @override
  String get updateChecking => 'KONTROLA';

  @override
  String get upToDate => 'AKTUALNE';

  @override
  String get updateAvailable => 'AKTUALIZACJA';

  @override
  String get updateUnavailable => 'NIE PŁYNNY';

  @override
  String get updateCheckFailed => 'SPRAWDZENIE NIEUDANE';

  @override
  String get installSkill => 'Zainstaluj Skill';

  @override
  String get installLocationTitle => 'Ustaw miejsce instalacji';

  @override
  String get userLevel => 'Poziom użytkownika';

  @override
  String get projectLevel => 'Poziom projektu';

  @override
  String get projects => 'Projektowanie';

  @override
  String get loading => 'Załadunek…';

  @override
  String get repositoryParsing => 'Analizuję repozytorium…';

  @override
  String userInstallSummary(int agents) {
    return 'Dostępne dla $agents Agents na poziomie użytkownika';
  }

  @override
  String projectInstallSummary(int projects, int agents) {
    return 'Projekty $projects · $agents Agents';
  }

  @override
  String get installationResults => 'Wyniki instalacji';

  @override
  String get installationInProgress => 'Instalacja w toku';

  @override
  String get installationSucceeded => 'Instalacja zakończona';

  @override
  String get installationSucceededMessage =>
      'Skill jest teraz dostępny w wybranych lokalizacjach.';

  @override
  String get projectUnavailable => 'Projekt niedostępny';

  @override
  String get installedCell => 'Zainstalowany';

  @override
  String get unsupportedCell => 'Nie płynny';

  @override
  String get confirmInstall => 'Potwierdź instalację';

  @override
  String installAllRepositorySkills(int count) {
    return 'Zainstaluj całe repozytorium skills ($count)';
  }

  @override
  String get installAllSkillsTo => 'Zainstaluj wszystkie skills w';

  @override
  String installRepositorySkills(String repository, int count) {
    return 'Zainstaluj wszystkie $repository skills ($count)';
  }

  @override
  String installSkillTo(String skill) {
    return 'Zainstaluj $skill na';
  }

  @override
  String get availableInAllProjects => 'Wszystkie projekty';

  @override
  String get availableInSelectedProjects => 'Wybrane projekty';

  @override
  String get usedBy => 'Dla Agents';

  @override
  String get backToTargets => 'Powrót do celów';

  @override
  String get stayHere => 'Zostań tutaj';

  @override
  String get viewInLibrary => 'Zobacz w Bibliotece';

  @override
  String planCreateCount(int count) {
    return '$count utwórz';
  }

  @override
  String planSkipCount(int count) {
    return 'Pomiń $count';
  }

  @override
  String planReplaceCount(int count) {
    return '$count wymienić';
  }

  @override
  String planConflictCount(int count) {
    return 'Konflikt $count';
  }

  @override
  String planRiskCount(int count) {
    return 'Ryzyko $count zablokowane';
  }

  @override
  String get refreshInstallationPlan => 'Zastosuj uchwały';

  @override
  String get replaceVersionConflict =>
      'Zastąp zainstalowaną wersję w tym miejscu docelowym';

  @override
  String get replaceSkillIdCollision =>
      'Wymień inny Skill ID w tym miejscu docelowym';

  @override
  String get replaceLocalModification =>
      'Odrzuć lokalne modyfikacje i zastąp ten cel';

  @override
  String get sharedTargetConflict =>
      'Ta ścieżka jest współdzielona przez cele other Agent';

  @override
  String sharedTargetConflictDescription(String agents) {
    return 'Wróć do docelowej matrycy i select każdego dotkniętego Agent przed wymianą: $agents';
  }

  @override
  String get replaceConflictingTarget => 'Zastąp sprzeczny cel';

  @override
  String get confirmHighRiskArtifact =>
      'Potwierdzenie artefaktu wysokiego ryzyka';

  @override
  String get confirmCriticalRiskArtifact =>
      'Potwierdzenie obejścia ryzyka krytycznego';

  @override
  String get confirmRiskForSelectedTargets =>
      'Przejrzałem pliki artefaktów i akceptuję ryzyko w przypadku wybranych celów';

  @override
  String get criticalRiskBlocked =>
      'Instalacja stwarzająca ryzyko krytyczne jest zablokowana';

  @override
  String get criticalRiskOverrideDisabled =>
      'Włącz jawne zastąpienie ryzyka krytycznego w Ustawieniach, zanim ten plan będzie mógł być kontynuowany.';

  @override
  String get workspaceManifestChanges => 'Zmiany w obszarze roboczym';

  @override
  String get noWorkspaceManifestChanges =>
      'Żadne pliki manifestu Workspace nie ulegną zmianie.';

  @override
  String lockVersionChange(String from, String to) {
    return '$from → $to';
  }

  @override
  String get notPresent => 'nieobecny';

  @override
  String get planActionCreate => 'Tworzyć';

  @override
  String get planActionReplace => 'Zastępować';

  @override
  String get planActionSkip => 'Pominąć';

  @override
  String get planActionConflict => 'Konflikt';

  @override
  String get planActionBlockedByRisk => 'Zablokowany przez ryzyko';

  @override
  String installationResultSummary(int succeeded, int failed) {
    return 'Zainstalowano cele $succeeded, błąd $failed';
  }

  @override
  String get installationProgressTitle => 'Instalacja w toku';

  @override
  String installationProgressSummary(int finished, int total) {
    return 'Ukończono cele $finished z $total';
  }

  @override
  String get targetWaiting => 'Czekanie';

  @override
  String get targetRunning => 'Instalowanie';

  @override
  String retryFailedTargets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ponów $count nieudanego celu',
      many: 'Ponów $count nieudanych celów',
      few: 'Ponów $count nieudane cele',
      one: 'Ponów 1 nieudany cel',
    );
    return '$_temp0';
  }

  @override
  String get updatePlanTitle => 'Cele Select do aktualizacji';

  @override
  String get updatePlanDescription =>
      'Wybierz dokładne cele instalacji. Niewybrane Agents i projekty pozostają niezmienione.';

  @override
  String updateTargetsSelected(int selected, int available) {
    return 'Wybrano aktualizowalne cele $selected z $available';
  }

  @override
  String updateVersionChange(String fromVersion, String toVersion) {
    return '$fromVersion → $toVersion';
  }

  @override
  String sourceReference(String reference) {
    return 'Źródło: $reference';
  }

  @override
  String get fixedVersionTarget => 'Przypięty — brak ruchomego odniesienia';

  @override
  String get currentVersionTarget => 'Aktualne';

  @override
  String get updateCheckTargetFailed =>
      'Sprawdzanie aktualizacji nie powiodło się';

  @override
  String get reconcileWorkspaceManifestTarget =>
      'Napraw manifest obszaru roboczego';

  @override
  String get updateSelectedTargets => 'Zaktualizuj wybrane cele';

  @override
  String get updateProgressTitle => 'Aktualizacja celów';

  @override
  String get updateResultsTitle => 'Aktualizuj wyniki';

  @override
  String updateProgressSummary(int finished, int total) {
    return 'Ukończono cele $finished z $total';
  }

  @override
  String retryFailedUpdates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ponów $count nieudanej aktualizacji',
      many: 'Ponów $count nieudanych aktualizacji',
      few: 'Ponów $count nieudane aktualizacje',
      one: 'Ponów 1 nieudaną aktualizację',
    );
    return '$_temp0';
  }

  @override
  String get noUpdateableTargets =>
      'Żaden wybrany cel nie ma dostępnej aktualizacji.';

  @override
  String get closeUpdatePlan => 'Zamknąć';

  @override
  String get targetSucceeded => 'Zainstalowany';

  @override
  String get targetSkipped => 'Pominięte';

  @override
  String get targetConflict => 'Konflikt';

  @override
  String get targetFailed => 'Przegrany';

  @override
  String get targetFailureRetryable =>
      'Nie można było zmienić tej lokalizacji. Możesz spróbować ponownie.';

  @override
  String get targetFailureNeedsAttention =>
      'Ta lokalizacja wymaga Twojej uwagi, zanim spróbujesz ponownie.';

  @override
  String get installationTargetFailureMessage =>
      'W tym miejscu nic się nie zmieniło. Sprawdź, czy folder jest dostępny i spróbuj ponownie.';

  @override
  String get workspacePersistenceFailureMessage =>
      'Nic nie zostało zmienione, ponieważ SkillsGo nie mógł zapisać ustawień projektu. Sprawdź, czy projekt folder nadaje się do zapisu i spróbuj ponownie.';

  @override
  String get installationStateChangedMessage =>
      'Ta lokalizacja uległa zmianie podczas jej sprawdzania. Zanim spróbujesz ponownie, przejrzyj najnowszy stan.';

  @override
  String get updateTargetFailureMessage =>
      'Nie udało się zaktualizować tej lokalizacji. Nie miało to wpływu na lokalizacje Other, więc możesz ponowić próbę tylko w tej.';

  @override
  String get managementTargetFailureMessage =>
      'Nie można tutaj zakończyć tej akcji. Nie miało to wpływu na lokalizacje Other, więc możesz ponowić próbę tylko w tej.';

  @override
  String get technicalDetails => 'Szczegóły techniczne';

  @override
  String get targetPathExists =>
      'Inny przedmiot już istnieje w tej lokalizacji.';

  @override
  String get targetBlockedByRisk =>
      'Twoje obecne ustawienia bezpieczeństwa blokowały instalację w tej lokalizacji.';

  @override
  String get targetInstallFailed =>
      'Nie można zainstalować skill w tej lokalizacji.';

  @override
  String get targetWorkspaceUpdateFailed =>
      'skill został zainstalowany, ale nie można było zaktualizować ustawień projektu.';

  @override
  String get installationPlanFailed => 'Nie można kontynuować planu instalacji';

  @override
  String get installationFailed => 'Nie można ukończyć instalacji';

  @override
  String get localSource => 'Źródło lokalne';

  @override
  String get noDescriptionAvailable => 'Brak opisu';

  @override
  String moreCoverage(int count) {
    return '+$count więcej lokalizacji';
  }

  @override
  String get batchTakeoverAction => 'Zarządzaj istniejącym skills';

  @override
  String batchTakeoverActionCount(int count) {
    return 'Zarządzaj ($count)';
  }

  @override
  String get batchTakeoverChecking => 'Sprawdzanie istniejącego skills…';

  @override
  String get batchTakeoverRetry => 'Sprawdź ponownie zarządzalny skills';

  @override
  String batchTakeoverEligibleCount(int count) {
    return '$count można zarządzać';
  }

  @override
  String get batchTakeoverPending => 'Dodawanie skills do zarządzania…';

  @override
  String get batchTakeoverTitle =>
      'Zarządzaj istniejącym skills za pomocą SkillsGo?';

  @override
  String get batchTakeoverDescription =>
      'SkillsGo doda lokalne rekordy zarządzania bez przenoszenia, nadpisywania lub przesyłania plików skill. Nieobsługiwane lub zmienione elementy zostaną pominięte.';

  @override
  String get batchTakeoverStoryTitle =>
      'Zmień rozproszone skills w jedną przejrzystą bibliotekę';

  @override
  String batchTakeoverStoryDescription(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count istniejący skills',
      one: '1 istniejący skill',
    );
    return 'SkillsGo znalazł $_temp0, którym może zarządzać w tej lokalizacji.';
  }

  @override
  String get batchTakeoverBeforeSemantics =>
      'Przed zarządem nie jest jasne, gdzie zainstalowane są istniejące skills, czy są aktualne, jak je odzyskać lub czy projekty korzystają z tej samej wersji.';

  @override
  String get batchTakeoverPainLocation => 'Nieznana lokalizacja instalacji';

  @override
  String get batchTakeoverPainFreshness => 'Nieznany stan aktualizacji';

  @override
  String get batchTakeoverPainRecovery => 'Brak regeneracji po uszkodzeniu';

  @override
  String get batchTakeoverPainVersionDrift =>
      'Różne wersje w różnych projektach';

  @override
  String get batchTakeoverFolderTitle => 'Istniejący Skills';

  @override
  String get batchTakeoverFolderSubtitle => 'Niejasny stan';

  @override
  String get batchTakeoverAfterLabel => 'PO';

  @override
  String get batchTakeoverAfterTitle => 'Jedna przejrzysta biblioteka';

  @override
  String get batchTakeoverLibraryTitle => 'Biblioteka SkillsGo';

  @override
  String get batchTakeoverBenefitLocation => 'Wyczyść lokalizacje';

  @override
  String get batchTakeoverBenefitFreshness => 'Aktualizacje widoczne';

  @override
  String get batchTakeoverBenefitRecovery => 'Łatwe odzyskiwanie';

  @override
  String get batchTakeoverBenefitVersions => 'Wersje jasne';

  @override
  String get batchTakeoverManagedSection => 'Zarządzane przez SkillsGo';

  @override
  String get batchTakeoverPendingSection => 'Aż do';

  @override
  String batchTakeoverItemManaged(String name) {
    return '$name jest zarządzany przez SkillsGo';
  }

  @override
  String batchTakeoverItemSkipped(String name) {
    return 'Nie można dodać $name do zarządzania';
  }

  @override
  String batchTakeoverItemPending(String name) {
    return '$name czeka na zarządzanie';
  }

  @override
  String batchTakeoverAfterSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count skills are',
      one: '1 skill is',
    );
    return 'Po zarządzaniu, $_temp0 są zorganizowane w jedną Bibliotekę z jasnym statusem zarządzanym.';
  }

  @override
  String batchTakeoverMoreSkills(int count) {
    return '+$count więcej';
  }

  @override
  String get batchTakeoverTransitionSemantics =>
      'Dodaj istniejące skills do zarządzania SkillsGo.';

  @override
  String get batchTakeoverTransitionLabel => 'ZORGANIZOWAĆ';

  @override
  String get batchTakeoverStatusTitle => 'Stan zarządzania';

  @override
  String get batchTakeoverStatusManaged => 'Zarządzany';

  @override
  String get batchTakeoverStatusProgress => 'Organizowanie';

  @override
  String get batchTakeoverStatusSkipped => 'Pominięte';

  @override
  String get batchTakeoverStatusFilesStay =>
      'Pliki Skill pozostają w oryginalnych lokalizacjach';

  @override
  String get batchTakeoverBoardSemantics =>
      'Skills są układane w pełne wiersze i rejestrowane przez SkillsGo bez przenoszenia ich plików.';

  @override
  String get batchTakeoverBoardComplete => 'WSZYSTKO JASNE';

  @override
  String get batchTakeoverBoardPartial => 'KOMPLETNY';

  @override
  String get batchTakeoverStatusTotal => 'Całkowity';

  @override
  String get batchTakeoverQueueComplete => 'Żadne skills nie czekają';

  @override
  String get batchTakeoverQueueWaiting =>
      'Po weryfikacji Skills pojawią się tutaj';

  @override
  String get batchTakeoverNextLabel => 'NASTĘPNY';

  @override
  String batchTakeoverFillerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count SkillsGo bloki organizatora',
      one: '1 SkillsGo blok organizatora',
    );
    return '$_temp0 uzupełnij ostatnie rzędy';
  }

  @override
  String get batchTakeoverPreservation =>
      'Twoje pliki, ścieżki i bieżące przepływy pracy pozostają dokładnie tam, gdzie są. SkillsGo uzupełnia jedynie swoje lokalne zapisy zarządcze.';

  @override
  String get batchTakeoverLaterHint =>
      'Jeśli pominiesz, możesz w dowolnym momencie skorzystać z opcji Zarządzaj istniejącym skills z Biblioteki.';

  @override
  String get batchTakeoverSkip => 'Nie teraz';

  @override
  String get batchTakeoverConfirm => 'Dodaj do zarządzania';

  @override
  String get batchTakeoverExecutionRetry => 'Spróbować ponownie';

  @override
  String get batchTakeoverResultTitle => 'Skills dodano do zarządzania';

  @override
  String batchTakeoverSummary(int takenOver, int skipped) {
    return '$takenOver skills dodano do zarządzania, $skipped pominięto.';
  }

  @override
  String get batchTakeoverClose => 'Zamknąć';

  @override
  String get installMoreTargets => 'Zainstaluj w większej liczbie lokalizacji';

  @override
  String get detailRepository => 'Magazyn';

  @override
  String get detailStars => 'Gwiazdy';

  @override
  String get detailUpdated => 'Zaktualizowano';

  @override
  String get detailArchiveSize => 'Rozmiar ZIP';

  @override
  String get pathLabel => 'Ścieżka projektu';

  @override
  String get copyProjectPath => 'Skopiuj ścieżkę projektu';

  @override
  String get projectPathCopied => 'Skopiowano ścieżkę projektu';

  @override
  String get onboardingWelcomeTitle => 'Witamy w SkillsGo';

  @override
  String get onboardingWelcomeDescription =>
      'Odkryj, zainstaluj i zarządzaj Skills w swoim Agents i projektach.';

  @override
  String get onboardingDetectedAgents => 'Wykryto Agents';

  @override
  String get onboardingNoAgents =>
      'Nie wykryto zainstalowanego Agents. Nadal możesz kontynuować.';

  @override
  String get onboardingNext => 'Następny';

  @override
  String get onboardingProjectsTitle => 'Dodaj swoje projekty';

  @override
  String get onboardingProjectsDescription =>
      'Wybierz projekty, którymi chcesz zarządzać SkillsGo.';

  @override
  String get onboardingAddProject => 'Dodaj teraz';

  @override
  String get onboardingAddProjectLater => 'lub później';

  @override
  String get onboardingStartUsing => 'Zacznij używać SkillsGo';

  @override
  String get onboardingBack => 'Z powrotem';

  @override
  String get restartOnboardingTitle =>
      'Proces wdrażania do firmy nowego pracownika';

  @override
  String get restartOnboardingDescription =>
      'Wyświetl ponownie przewodnik pierwszego uruchomienia bez usuwania projektów, ustawień lub danych Skills.';

  @override
  String get restartOnboardingAction => 'Uruchom ponownie wdrażanie';

  @override
  String get restartOnboardingFailed =>
      'SkillsGo nie mógł ponownie uruchomić procesu wdrażania.';

  @override
  String get libraryRefreshSettingsTitle => 'Odśwież lokalną bibliotekę';

  @override
  String get libraryRefreshSettingsDescription =>
      'Przeskanuj ponownie zainstalowane Skills, Dodane projekty, Agents i zewnętrzne Skills, którymi można zarządzać. Nie powoduje to instalacji, aktualizacji ani usunięcia czegokolwiek.';

  @override
  String get libraryRefreshSettingsAction => 'Odśwież bibliotekę';

  @override
  String get libraryRefreshSettingsPending => 'Odświeżanie biblioteki…';

  @override
  String get libraryRefreshSettingsSuccess => 'Lokalna biblioteka odświeżona.';

  @override
  String get libraryRefreshSettingsFailed =>
      'SkillsGo nie mógł odświeżyć biblioteki lokalnej.';

  @override
  String get onboardingProjectError =>
      'SkillsGo nie mógł dodać projektów z tego katalogu.';

  @override
  String get onboardingProjectsLoadError =>
      'SkillsGo nie mógł załadować dodanych projektów.';

  @override
  String get onboardingStartupError =>
      'SkillsGo nie mógł załadować konfiguracji.';

  @override
  String get onboardingStateError =>
      'SkillsGo nie mógł zapisać postępu konfiguracji. Spróbuj ponownie.';

  @override
  String get onboardingCliErrorTitle => 'SkillsGo CLI wymaga uwagi';

  @override
  String get onboardingCliErrorDescription =>
      'Napraw dołączony CLI, a następnie spróbuj ponownie, aby kontynuować.';
}
