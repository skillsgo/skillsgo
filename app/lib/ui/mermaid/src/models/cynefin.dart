/*
 * [INPUT]: Depends on Mermaid Cynefin's five fixed domains, quoted items, cross-domain transitions, accessibility metadata, and renderer configuration.
 * [OUTPUT]: Defines immutable configured Cynefin domain and transition data for native layout and rendering.
 * [POS]: Serves as the chart-specific intermediate representation for cynefin-beta diagrams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
enum CynefinDomainName { complex, complicated, clear, chaotic, confusion }

class CynefinDomainData {
  const CynefinDomainData({required this.name, required this.items});
  final CynefinDomainName name;
  final List<String> items;
}

class CynefinTransitionData {
  const CynefinTransitionData({
    required this.from,
    required this.to,
    this.label,
  });
  final CynefinDomainName from;
  final CynefinDomainName to;
  final String? label;
}

class CynefinChartData {
  const CynefinChartData({
    required this.domains,
    required this.transitions,
    this.accessibilityTitle,
    this.accessibilityDescription,
    this.width = 800,
    this.height = 600,
    this.padding = 40,
    this.showDomainDescriptions = true,
    this.boundaryAmplitude = 8,
    this.seed = 0,
    this.useMaxWidth = true,
  });
  final List<CynefinDomainData> domains;
  final List<CynefinTransitionData> transitions;
  final String? accessibilityTitle;
  final String? accessibilityDescription;
  final double width;
  final double height;
  final double padding;
  final bool showDomainDescriptions;
  final double boundaryAmplitude;
  final double seed;
  final bool useMaxWidth;

  CynefinChartData copyWith({
    double? width,
    double? height,
    double? padding,
    bool? showDomainDescriptions,
    double? boundaryAmplitude,
    double? seed,
    bool? useMaxWidth,
  }) => CynefinChartData(
    domains: domains,
    transitions: transitions,
    accessibilityTitle: accessibilityTitle,
    accessibilityDescription: accessibilityDescription,
    width: width ?? this.width,
    height: height ?? this.height,
    padding: padding ?? this.padding,
    showDomainDescriptions:
        showDomainDescriptions ?? this.showDomainDescriptions,
    boundaryAmplitude: boundaryAmplitude ?? this.boundaryAmplitude,
    seed: seed ?? this.seed,
    useMaxWidth: useMaxWidth ?? this.useMaxWidth,
  );
}
