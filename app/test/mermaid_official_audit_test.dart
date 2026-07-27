/*
 * [INPUT]: Depends on the vendored Mermaid 11.16.0 official syntax corpus and the native Mermaid parser.
 * [OUTPUT]: Requires every complete official documentation diagram to parse and validates native renderer configuration, formatting, color, layout, and paint gates.
 * [POS]: Serves as the hermetic upstream compatibility gate for all documented Mermaid types.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Canvas, PictureRecorder, Size;

import 'package:flutter/material.dart' show Icons;
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/ui/mermaid/flutter_mermaid.dart';

void main() {
  test('preserves official YAML frontmatter metadata and nested config', () {
    const source = '''   ---
   title: true
   displayMode: compact
   ignored: value
   config:
     pie:
       donutHole: 0.2
       textPosition: 0.6
       legendPosition: bottom
       highlightSlice: Potassium
       labels: [A, B]
     sankey:
       showValues: true
   ---
   pie showData
   "Potassium" : 42
''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    expect(result!.diagram.title, 'true');
    expect(result.frontmatter.title, 'true');
    expect(result.frontmatter.displayMode, 'compact');
    expect(result.frontmatter.numberAt(['pie', 'donutHole']), 0.2);
    expect(result.frontmatter.stringAt(['pie', 'highlightSlice']), 'Potassium');
    expect(result.frontmatter.boolAt(['sankey', 'showValues']), isTrue);
    expect(result.frontmatter.valueAt(['pie', 'labels']), ['A', 'B']);
    expect(result.frontmatter.config, isNot(contains('ignored')));
    expect(result.pieChartData!.donutHole, 0.2);
    expect(result.pieChartData!.textPosition, 0.6);
    expect(result.pieChartData!.legendPosition, PieLegendPosition.bottom);
    expect(result.pieChartData!.highlightSlice, 'Potassium');
  });

  test('applies Kanban frontmatter config through the shared pipeline', () {
    const source = r'''---
title: Delivery
config:
  kanban:
    padding: 14
    sectionWidth: 240
    ticketBaseUrl: https://example.com/browse/#TICKET#
---
kanban
todo[Todo]
    item[Ship] @{ ticket: "SG-7" }
''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    expect(result!.kanbanChartData!.title, 'Delivery');
    expect(
      result.kanbanChartData!.ticketBaseUrl,
      'https://example.com/browse/#TICKET#',
    );
    expect(result.kanbanChartData!.padding, 14);
    expect(result.kanbanChartData!.sectionWidth, 240);
  });

  test(
    'preserves complete Kanban indentation, nodes, metadata, and decoration',
    () {
      const source = r'''---
title: Delivery board
config:
  kanban:
    padding: 14
    sectionWidth: 230
    ticketBaseUrl: https://example.com/browse/#TICKET#
    useMaxWidth: false
---
kanban
accTitle: Accessible board
accDescr {
Work moving through stages
with ownership
}
  [Todo]
  ::icon(list)
  :::backlog
    rounded(Write docs)@{ assigned: 'Ada', ticket: SG-7, priority: 'Very High', extra: 3 }
    ::icon(file-text)
    :::documentation
    cloud)Investigate(
  done{{Done}}
    shipped["`Ship\nrelease`"]@{
      label: "Published"
      assigned: Lin
      priority: Very Low
    }
''';
      final result = const MermaidParser().parseWithData(source);
      expect(result, isNotNull);
      final data = result!.kanbanChartData!;
      expect(result.diagram.title, 'Delivery board');
      expect(data.accessibilityTitle, 'Accessible board');
      expect(
        data.accessibilityDescription,
        'Work moving through stages\nwith ownership',
      );
      expect(data.padding, 14);
      expect(data.sectionWidth, 230);
      expect(data.useMaxWidth, isFalse);
      expect(data.columns, hasLength(2));
      expect(data.columns.first.id, startsWith('kbn'));
      expect(data.columns.first.icon, 'list');
      expect(data.columns.first.cssClass, 'backlog');
      expect(data.columns.last.shape, KanbanNodeShape.hexagon);
      final docs = data.getTask('rounded')!;
      expect(docs.description, 'Write docs');
      expect(docs.shape, KanbanNodeShape.rounded);
      expect(docs.assigned, 'Ada');
      expect(docs.ticket, 'SG-7');
      expect(docs.priority, KanbanPriority.veryHigh);
      expect(docs.icon, 'file-text');
      expect(docs.cssClass, 'documentation');
      expect(docs.metadata['extra'], 3);
      expect(data.columns.first.tasks.last.shape, KanbanNodeShape.cloud);
      expect(data.getTask('shipped')!.description, 'Published');
      expect(data.getTask('shipped')!.priority, KanbanPriority.veryLow);
      expect(data.ticketUrlFor(docs), 'https://example.com/browse/SG-7');
      final layout = const KanbanChartLayout();
      final size = layout.computeLayout(
        data,
        const MermaidStyle(),
        const Size(1200, 700),
      );
      expect(size.width, lessThan(1200));
      final hitPainter = KanbanPainter(
        kanbanData: data,
        style: const MermaidStyle(),
      );
      MermaidIconRegistry.registerIconData('list', Icons.list_alt_outlined);
      MermaidIconRegistry.registerIconData(
        'file-text',
        Icons.description_outlined,
      );
      expect(MermaidIconRegistry.contains('list'), isTrue);
      KanbanTask? ticketHit;
      for (var y = 140.0; y < 240 && ticketHit == null; y += 2) {
        for (var x = 20.0; x < 230 && ticketHit == null; x += 2) {
          ticketHit = hitPainter.ticketAt(Offset(x, y), size);
        }
      }
      expect(ticketHit?.id, 'rounded');
      for (final style in [MermaidThemes.light, MermaidThemes.dark]) {
        final recorder = PictureRecorder();
        KanbanPainter(
          kanbanData: data,
          style: style,
        ).paint(Canvas(recorder), size);
        recorder.endRecording();
      }
      expect(
        const MermaidParser().parse('kanban\n    orphan[Task]\n  section'),
        isNull,
      );
    },
  );

  test('applies every official Packet rendering parameter', () {
    const source = '''---
title: Header
config:
  packet:
    rowHeight: 40
    bitWidth: 12.5
    bitsPerRow: 16
    showBits: false
    paddingX: 2
    paddingY: 7
    useMaxWidth: false
  themeVariables:
    packet:
      byteFontSize: 9px
      startByteColor: '#112233'
      endByteColor: rgb(20, 30, 40)
      labelColor: blue
      labelFontSize: 13px
      titleColor: red
      titleFontSize: 17px
      blockStrokeColor: '#445566'
      blockStrokeWidth: '3'
      blockFillColor: '#abcdef'
---
packet-beta
0-23: "Wide field"
''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    final data = result!.packetChartData!;
    expect(data.title, 'Header');
    expect(data.rowHeight, 40);
    expect(data.bitWidth, 12.5);
    expect(data.bitsPerRow, 16);
    expect(data.showBits, isFalse);
    expect(data.paddingX, 2);
    expect(data.paddingY, 7);
    expect(data.effectivePaddingY, 7);
    expect(data.useMaxWidth, isFalse);
    expect(data.theme.byteFontSize, 9);
    expect(data.theme.startByteColor, '#112233');
    expect(data.theme.endByteColor, 'rgb(20, 30, 40)');
    expect(data.theme.labelColor, 'blue');
    expect(data.theme.labelFontSize, 13);
    expect(data.theme.titleColor, 'red');
    expect(data.theme.titleFontSize, 17);
    expect(data.theme.blockStrokeColor, '#445566');
    expect(data.theme.blockStrokeWidth, 3);
    expect(data.theme.blockFillColor, '#abcdef');
    final size = const PacketChartLayout().computeLayout(
      data,
      const MermaidStyle(padding: 10),
      const Size(100, 100),
    );
    expect(size.width, 202);
    expect(size.height, 141);
    for (final style in [MermaidThemes.light, MermaidThemes.dark]) {
      final recorder = PictureRecorder();
      PacketPainter(data: data, style: style).paint(Canvas(recorder), size);
      recorder.endRecording();
    }
  });

  test('applies every official Sankey rendering parameter', () {
    const source = '''---
config:
  sankey:
    width: 720
    height: 360
    linkColor: source
    nodeAlignment: left
    useMaxWidth: false
    showValues: true
    prefix: \$
    suffix: kg
    nodeWidth: 18
    nodePadding: 9
    labelStyle: outlined
    nodeColors:
      Input: '#112233'
---
sankey-beta
Input,Output,12.5
''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    final data = result!.sankeyChartData!;
    expect(data.width, 720);
    expect(data.height, 360);
    expect(data.linkColor, 'source');
    expect(data.nodeAlignment, SankeyNodeAlignment.left);
    expect(data.useMaxWidth, isFalse);
    expect(data.showValues, isTrue);
    expect(data.prefix, r'$');
    expect(data.suffix, 'kg');
    expect(data.nodeWidth, 18);
    expect(data.nodePadding, 9);
    expect(data.labelStyle, SankeyLabelStyle.outlined);
    expect(data.nodeColors, {'Input': '#112233'});
    expect(
      const SankeyChartLayout().computeLayout(data, const Size(400, 200)),
      const Size(720, 360),
    );
  });

  test('executes d3-compatible Sankey relaxation for every alignment', () {
    const body = '''sankey
A,B,8
A,C,2
B,D,5
B,E,3
C,E,2
D,F,5
E,F,5''';
    for (final alignment in SankeyNodeAlignment.values) {
      final result = const MermaidParser().parseWithData('''---
config:
  sankey:
    nodeAlignment: ${alignment.name}
    nodeWidth: 16
    nodePadding: 4
    showValues: true
    labelStyle: outlined
    linkColor: gradient
---
$body''');
      final data = result!.sankeyChartData!;
      for (final style in [MermaidThemes.light, MermaidThemes.dark]) {
        final recorder = PictureRecorder();
        SankeyPainter(
          data: data,
          style: style,
        ).paint(Canvas(recorder), const Size(600, 400));
        recorder.endRecording();
      }
    }
    final responsive = const MermaidParser().parseWithData('''---
config:
  sankey:
    useMaxWidth: true
---
$body''')!.sankeyChartData!;
    expect(
      const SankeyChartLayout().computeLayout(
        responsive,
        const Size(300, 1000),
      ),
      const Size(300, 200),
    );
  });

  test('applies every official GitGraph configuration parameter', () {
    const source = '''---
title: Repository
config:
  themeVariables:
    git0: '#010203'
    gitInv0: '#111213'
    gitBranchLabel0: '#212223'
    commitLineColor: '#313233'
    textColor: '#414243'
    tagLabelColor: '#515253'
    tagLabelBackground: '#616263'
    tagLabelBorder: '#717273'
    tagLabelFontSize: 14px
    commitLabelColor: '#818283'
    commitLabelBackground: '#919293'
    commitLabelFontSize: 15px
    primaryColor: '#a1a2a3'
  gitGraph:
    titleTopMargin: 30
    diagramPadding: 12
    nodeLabel: { width: 80, height: 110, x: -20, y: 3 }
    mainBranchName: trunk
    mainBranchOrder: 2
    showCommitLabel: false
    showBranches: false
    rotateCommitLabel: false
    parallelCommits: true
    arrowMarkerAbsolute: true
    useMaxWidth: false
---
gitGraph LR:
commit id: "root"
branch feature
commit id: "work"
checkout trunk
merge feature
''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    final data = result!.gitGraphChartData!;
    expect(data.title, 'Repository');
    expect(data.branches.first.name, 'trunk');
    expect(data.currentBranch, 'trunk');
    expect(data.titleTopMargin, 30);
    expect(data.diagramPadding, 12);
    expect(data.nodeLabelWidth, 80);
    expect(data.nodeLabelHeight, 110);
    expect(data.nodeLabelX, -20);
    expect(data.nodeLabelY, 3);
    expect(data.mainBranchName, 'trunk');
    expect(data.mainBranchOrder, 2);
    expect(data.showCommitLabel, isFalse);
    expect(data.showBranches, isFalse);
    expect(data.rotateCommitLabel, isFalse);
    expect(data.parallelCommits, isTrue);
    expect(data.arrowMarkerAbsolute, isTrue);
    expect(data.useMaxWidth, isFalse);
    expect(data.theme.branchColors.first, '#010203');
    expect(data.theme.inverseColors.first, '#111213');
    expect(data.theme.branchLabelColors.first, '#212223');
    expect(data.theme.lineColor, '#313233');
    expect(data.theme.titleColor, '#414243');
    expect(data.theme.tagLabelColor, '#515253');
    expect(data.theme.tagLabelBackground, '#616263');
    expect(data.theme.tagLabelBorder, '#717273');
    expect(data.theme.tagLabelFontSize, 14);
    expect(data.theme.commitLabelColor, '#818283');
    expect(data.theme.commitLabelBackground, '#919293');
    expect(data.theme.commitLabelFontSize, 15);
    expect(data.theme.mergeColor, '#a1a2a3');
    final size = const GitGraphChartLayout().computeLayout(
      data,
      const Size(200, 200),
    );
    expect(size.width, 264);
    expect(size.height, greaterThan(200));
    for (final theme in [MermaidThemes.light, MermaidThemes.dark]) {
      final picture = PictureRecorder();
      GitGraphPainter(data: data, style: theme).paint(Canvas(picture), size);
      picture.endRecording();
    }
  });

  test('applies every official Tree View configuration parameter', () {
    MermaidIconRegistry.registerPack('material-icon-theme', {
      'docker': MermaidIconGlyph.iconData(Icons.inventory_2_outlined),
      'dart': MermaidIconGlyph.iconData(Icons.code),
      'folder': MermaidIconGlyph.iconData(Icons.folder_outlined),
      'file': MermaidIconGlyph.iconData(Icons.description_outlined),
    });
    const source = '''---
title: Files
config:
  treeView:
    rowIndent: 18
    paddingX: 7
    paddingY: 6
    lineThickness: 2
    showIcons: true
    defaultIconPack: material-icon-theme
    filenameIcons:
      Dockerfile: docker
    extensionIcons:
      .dart: dart
---
treeView-beta
root/
  Dockerfile
  main.dart
''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    final data = result!.treeViewChartData!;
    expect(data.title, 'Files');
    expect(data.rowIndent, 18);
    expect(data.paddingX, 7);
    expect(data.paddingY, 6);
    expect(data.lineThickness, 2);
    expect(data.showIcons, isTrue);
    expect(data.defaultIconPack, 'material-icon-theme');
    expect(data.filenameIcons, {'Dockerfile': 'docker'});
    expect(data.extensionIcons, {'.dart': 'dart'});
    expect(data.iconFor(data.nodes[0]), 'folder');
    expect(data.iconFor(data.nodes[1]), 'docker');
    expect(data.iconFor(data.nodes[2]), 'dart');
    expect(
      const TreeViewChartLayout()
          .computeLayout(data, const Size(100, 100))
          .height,
      greaterThan(100),
    );
    expect(
      MermaidIconRegistry.contains(
        'docker',
        defaultPack: 'material-icon-theme',
      ),
      isTrue,
    );
    final recorder = PictureRecorder();
    TreeViewPainter(
      data: data,
      style: const MermaidStyle(),
    ).paint(Canvas(recorder), const Size(500, 240));
    recorder.endRecording();
  });

  test('applies every official Radar rendering parameter', () {
    const source = '''---
title: Skills
config:
  radar:
    width: 720
    height: 480
    marginTop: 20
    marginRight: 30
    marginBottom: 40
    marginLeft: 50
    axisScaleFactor: 0.8
    axisLabelFactor: 1.2
    curveTension: 0.4
    useMaxWidth: false
  themeVariables:
    fontSize: 18px
    titleColor: '#101010'
    cScale0: '#112233'
    radar:
      axisColor: '#223344'
      axisStrokeWidth: 2
      axisLabelFontSize: 13
      curveOpacity: 0.35
      curveStrokeWidth: 4
      graticuleColor: '#334455'
      graticuleOpacity: 0.4
      graticuleStrokeWidth: 3
      legendBoxSize: 14
      legendFontSize: 15
---
radar-beta
axis A, B, C
curve Team{1, 2, 3}
''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    final data = result!.radarChartData!;
    expect(data.title, 'Skills');
    expect(data.width, 720);
    expect(data.height, 480);
    expect(data.marginTop, 20);
    expect(data.marginRight, 30);
    expect(data.marginBottom, 40);
    expect(data.marginLeft, 50);
    expect(data.axisScaleFactor, 0.8);
    expect(data.axisLabelFactor, 1.2);
    expect(data.curveTension, 0.4);
    expect(data.useMaxWidth, isFalse);
    expect(data.theme.titleFontSize, 18);
    expect(data.theme.titleColor, '#101010');
    expect(data.theme.curveColors[0], '#112233');
    expect(data.theme.axisColor, '#223344');
    expect(data.theme.axisStrokeWidth, 2);
    expect(data.theme.axisLabelFontSize, 13);
    expect(data.theme.curveOpacity, 0.35);
    expect(data.theme.curveStrokeWidth, 4);
    expect(data.theme.graticuleColor, '#334455');
    expect(data.theme.graticuleOpacity, 0.4);
    expect(data.theme.graticuleStrokeWidth, 3);
    expect(data.theme.legendBoxSize, 14);
    expect(data.theme.legendFontSize, 15);
    expect(
      const RadarChartLayout().computeLayout(
        data,
        const MermaidStyle(),
        const Size(100, 100),
      ),
      const Size(800, 540),
    );
    for (final style in [MermaidThemes.light, MermaidThemes.dark]) {
      final recorder = PictureRecorder();
      RadarPainter(
        radarData: data,
        style: style,
      ).paint(Canvas(recorder), const Size(800, 540));
      recorder.endRecording();
    }
  });

  test('preserves complete Radar Langium grammar and strict failures', () {
    const source = '''radar-beta:
accTitle: Accessible radar
accDescr {
  Ordered referenced entries
}
curve first["First"]{
  C: 3,
  A: 1,
  B: 2
}, second['Second']{1, 2, 3}
axis A["Alpha"], B['Beta'], C
ticks 4, showLegend false, min 1, max 9, graticule polygon''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    final data = result!.radarChartData!;
    expect(data.accessibilityTitle, 'Accessible radar');
    expect(data.accessibilityDescription, 'Ordered referenced entries');
    expect(data.axes.map((axis) => (axis.id, axis.label)), [
      ('A', 'Alpha'),
      ('B', 'Beta'),
      ('C', 'C'),
    ]);
    expect(data.curves.map((curve) => (curve.id, curve.label)), [
      ('first', 'First'),
      ('second', 'Second'),
    ]);
    expect(data.curves.first.values, [1.0, 2.0, 3.0]);
    expect(data.curves.last.values, [1.0, 2.0, 3.0]);
    expect(data.ticks, 4);
    expect(data.showLegend, isFalse);
    expect(data.min, 1);
    expect(data.max, 9);
    expect(data.graticule, RadarGraticule.polygon);
    expect(
      const MermaidParser().parseWithData('radar-beta\nticks 3'),
      isNotNull,
    );
    expect(const MermaidParser().parse('radar-beta\nunknown value'), isNull);
    expect(
      const MermaidParser().parse('radar-beta\naxis A\ncurve x{A:1,B:2}'),
      isNull,
    );
  });

  test('preserves the complete official Timeline configuration', () {
    const source = '''---
title: History
config:
  timeline:
    diagramMarginX: 20
    diagramMarginY: 12
    leftMargin: 40
    width: 180
    height: 60
    padding: 16
    boxMargin: 8
    boxTextMargin: 4
    noteMargin: 9
    messageMargin: 24
    messageAlign: left
    bottomMarginAdj: 3
    rightAngles: true
    taskFontSize: 15
    taskFontFamily: Inter
    taskMargin: 44
    activationWidth: 12
    textPlacement: tspan
    actorColours: ['#111111']
    sectionFills: ['#223344', '#556677']
    sectionColours: ['#ffffff']
    disableMulticolor: true
    useMaxWidth: false
---
timeline
section Era
2026 : Native renderer
''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    final data = result!.timelineChartData!;
    expect(data.title, 'History');
    expect(data.diagramMarginX, 20);
    expect(data.diagramMarginY, 12);
    expect(data.leftMargin, 40);
    expect(data.width, 180);
    expect(data.height, 60);
    expect(data.padding, 16);
    expect(data.boxMargin, 8);
    expect(data.boxTextMargin, 4);
    expect(data.noteMargin, 9);
    expect(data.messageMargin, 24);
    expect(data.messageAlign, TimelineMessageAlign.left);
    expect(data.bottomMarginAdj, 3);
    expect(data.rightAngles, isTrue);
    expect(data.taskFontSize, 15);
    expect(data.taskFontFamily, 'Inter');
    expect(data.taskMargin, 44);
    expect(data.activationWidth, 12);
    expect(data.textPlacement, 'tspan');
    expect(data.actorColours, ['#111111']);
    expect(data.sectionFills, ['#223344', '#556677']);
    expect(data.sectionColours, ['#ffffff']);
    expect(data.disableMulticolor, isTrue);
    expect(data.useMaxWidth, isFalse);
    expect(
      const TimelineChartLayout()
          .computeLayout(data, const MermaidStyle(), const Size(100, 100))
          .width,
      260,
    );
    expect(data.sections.single.title, 'Era');
    expect(data.sections.single.events.single.title, '2026');
    expect(data.sections.single.events.single.periods, ['Native renderer']);
  });

  test('preserves complete Timeline grammar, direction, and events', () {
    const source = '''timeline TD
title Product history
accTitle: Accessible history
accDescr {
  Multiple releases
  across eras
}
section Foundation
2024 : Started : [Roadmap](https://example.com/a:b)
     : Shipped
section Growth
# whole-line comment
2025
2026 : Scaled''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    final data = result!.timelineChartData!;
    expect(data.direction, TimelineDirection.topDown);
    expect(data.title, 'Product history');
    expect(data.accessibilityTitle, 'Accessible history');
    expect(data.accessibilityDescription, 'Multiple releases\nacross eras');
    expect(data.sections.map((section) => section.title), [
      'Foundation',
      'Growth',
    ]);
    expect(data.sections.first.events.first.title, '2024');
    expect(data.sections.first.events.first.periods, [
      'Started',
      '[Roadmap](https://example.com/a:b)',
      'Shipped',
    ]);
    expect(data.sections.last.events.map((task) => task.title), [
      '2025',
      '2026',
    ]);
    expect(
      const MermaidParser().parseWithData('timeline LR\n2024 : One'),
      isNotNull,
    );
    expect(const MermaidParser().parseWithData('timeline'), isNotNull);
    expect(
      const MermaidParser().parseWithData('timeline\n: orphan event'),
      isNull,
    );
    expect(const MermaidParser().parseWithData('timeline BT\n2024'), isNull);
    for (final direction in ['LR', 'TD']) {
      final oriented = const MermaidParser().parseWithData(
        'timeline $direction\nsection Era\n2024 : One : Two\n2025 : Three',
      );
      final timeline = oriented!.timelineChartData!;
      final size = const TimelineChartLayout().computeLayout(
        timeline,
        const MermaidStyle(),
        const Size(700, 500),
      );
      for (final theme in [MermaidThemes.light, MermaidThemes.dark]) {
        final picture = PictureRecorder();
        TimelinePainter(
          timelineData: timeline,
          style: theme,
        ).paint(Canvas(picture), size);
        picture.endRecording();
      }
    }
  });

  test('applies complete Gantt renderer config and compact lanes', () {
    const source = '''---
title: Release
displayMode: compact
config:
  themeVariables:
    sectionBkgColor: '#010101'
    altSectionBkgColor: '#020202'
    sectionBkgColor2: '#030303'
    excludeBkgColor: '#040404'
    taskBorderColor: '#050505'
    taskBkgColor: '#060606'
    taskTextColor: '#070707'
    taskTextDarkColor: '#080808'
    taskTextOutsideColor: '#090909'
    taskTextClickableColor: '#101010'
    activeTaskBorderColor: '#111111'
    activeTaskBkgColor: '#121212'
    gridColor: '#131313'
    doneTaskBkgColor: '#141414'
    doneTaskBorderColor: '#151515'
    critBorderColor: '#161616'
    critBkgColor: '#171717'
    todayLineColor: '#181818'
    vertLineColor: '#191919'
    titleColor: '#202020'
    textColor: '#212121'
  gantt:
    titleTopMargin: 12
    barHeight: 18
    barGap: 6
    topPadding: 30
    rightPadding: 40
    leftPadding: 60
    gridLineStartPadding: 22
    fontSize: 13
    sectionFontSize: 14
    numberSectionStyles: 3
    axisFormat: '%d/%m'
    tickInterval: 1day
    topAxis: true
    weekday: monday
    useMaxWidth: false
---
gantt
dateFormat YYYY-MM-DD
section Work
First :a, 2026-01-01, 2d
Second :b, 2026-01-03, 2d
Overlap :c, 2026-01-02, 2d
''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    final data = result!.ganttChartData!;
    expect(data.title, 'Release');
    expect(data.titleTopMargin, 12);
    expect(data.barHeight, 18);
    expect(data.barGap, 6);
    expect(data.topPadding, 30);
    expect(data.rightPadding, 40);
    expect(data.leftPadding, 60);
    expect(data.gridLineStartPadding, 22);
    expect(data.fontSize, 13);
    expect(data.sectionFontSize, 14);
    expect(data.numberSectionStyles, 3);
    expect(data.axisFormat, '%d/%m');
    expect(data.tickInterval, '1day');
    expect(data.topAxis, isTrue);
    expect(data.weekday, 'monday');
    expect(data.useMaxWidth, isFalse);
    expect(data.displayMode, 'compact');
    expect(data.theme.sectionBackground, '#010101');
    expect(data.theme.alternateSectionBackground, '#020202');
    expect(data.theme.sectionBackground2, '#030303');
    expect(data.theme.excludeBackground, '#040404');
    expect(data.theme.taskBorder, '#050505');
    expect(data.theme.taskBackground, '#060606');
    expect(data.theme.taskText, '#070707');
    expect(data.theme.taskTextDark, '#080808');
    expect(data.theme.taskTextOutside, '#090909');
    expect(data.theme.taskTextClickable, '#101010');
    expect(data.theme.activeTaskBorder, '#111111');
    expect(data.theme.activeTaskBackground, '#121212');
    expect(data.theme.grid, '#131313');
    expect(data.theme.doneTaskBackground, '#141414');
    expect(data.theme.doneTaskBorder, '#151515');
    expect(data.theme.criticalBorder, '#161616');
    expect(data.theme.criticalBackground, '#171717');
    expect(data.theme.todayLine, '#181818');
    expect(data.theme.verticalLine, '#191919');
    expect(data.theme.title, '#202020');
    expect(data.theme.text, '#212121');
    expect(data.taskLanes, [0, 0, 1]);
    expect(data.laneCount, 2);
    final layout = const GanttChartLayout().computeLayout(
      data,
      const MermaidStyle(),
      const Size(900, 600),
    );
    expect(layout.height, greaterThanOrEqualTo(230));
    final recorder = PictureRecorder();
    GanttPainter(
      ganttData: data,
      style: const MermaidStyle(),
    ).paint(Canvas(recorder), layout);
    recorder.endRecording();
    for (final interval in const [
      '1millisecond',
      '1second',
      '1minute',
      '1hour',
      '1day',
      '1week',
      '1month',
    ]) {
      final configured = data.copyWith(
        tickInterval: interval,
        axisFormat: '%a %b %d %Y %H:%M:%S.%L',
      );
      final intervalRecorder = PictureRecorder();
      GanttPainter(
        ganttData: configured,
        style: const MermaidStyle(),
      ).paint(Canvas(intervalRecorder), layout);
      intervalRecorder.endRecording();
    }
  });

  test('preserves and paints complete Quadrant styles and configuration', () {
    const source = '''---
title: Portfolio
config:
  quadrantChart:
    chartWidth: 640
    chartHeight: 480
    titleFontSize: 24
    titlePadding: 12
    quadrantPadding: 9
    xAxisLabelPadding: 7
    yAxisLabelPadding: 8
    xAxisLabelFontSize: 15
    yAxisLabelFontSize: 14
    quadrantLabelFontSize: 17
    quadrantTextTopPadding: 11
    pointTextPadding: 6
    pointLabelFontSize: 13
    pointRadius: 4
    xAxisPosition: bottom
    yAxisPosition: right
    quadrantInternalBorderStrokeWidth: 3
    quadrantExternalBorderStrokeWidth: 5
    useMaxWidth: false
  themeVariables:
    quadrantTitleFill: '#010101'
    quadrant1Fill: '#111111'
    quadrant2Fill: '#222222'
    quadrant3Fill: '#333333'
    quadrant4Fill: '#444444'
    quadrant1TextFill: '#515151'
    quadrant2TextFill: '#525252'
    quadrant3TextFill: '#535353'
    quadrant4TextFill: '#545454'
    quadrantPointFill: '#616161'
    quadrantPointTextFill: '#626262'
    quadrantXAxisTextFill: '#717171'
    quadrantYAxisTextFill: '#727272'
    quadrantInternalBorderStrokeFill: '#818181'
    quadrantExternalBorderStrokeFill: '#828282'
---
quadrantChart
accTitle: Accessible portfolio
accDescr: Campaign reach and reward
x-axis Low --> High
y-axis Risk --> Reward
quadrant-1 Expand
Campaign A:::priority: [0.8, 0.9] radius: 12, stroke-width: 5px
classDef priority color: #109060, radius: 10, stroke-color: #310085
''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    final data = result!.quadrantChartData!;
    expect(data.title, 'Portfolio');
    expect(data.accessibilityTitle, 'Accessible portfolio');
    expect(data.accessibilityDescription, 'Campaign reach and reward');
    expect(data.chartWidth, 640);
    expect(data.chartHeight, 480);
    expect(data.titleFontSize, 24);
    expect(data.titlePadding, 12);
    expect(data.quadrantPadding, 9);
    expect(data.xAxisLabelPadding, 7);
    expect(data.yAxisLabelPadding, 8);
    expect(data.xAxisLabelFontSize, 15);
    expect(data.yAxisLabelFontSize, 14);
    expect(data.quadrantLabelFontSize, 17);
    expect(data.quadrantTextTopPadding, 11);
    expect(data.pointTextPadding, 6);
    expect(data.pointLabelFontSize, 13);
    expect(data.pointRadius, 4);
    expect(data.xAxisPosition, 'bottom');
    expect(data.yAxisPosition, 'right');
    expect(data.quadrantInternalBorderStrokeWidth, 3);
    expect(data.quadrantExternalBorderStrokeWidth, 5);
    expect(data.useMaxWidth, isFalse);
    expect(data.theme.titleFill, '#010101');
    expect(data.theme.quadrant1Fill, '#111111');
    expect(data.theme.quadrant2Fill, '#222222');
    expect(data.theme.quadrant3Fill, '#333333');
    expect(data.theme.quadrant4Fill, '#444444');
    expect(data.theme.quadrant1TextFill, '#515151');
    expect(data.theme.quadrant2TextFill, '#525252');
    expect(data.theme.quadrant3TextFill, '#535353');
    expect(data.theme.quadrant4TextFill, '#545454');
    expect(data.theme.pointFill, '#616161');
    expect(data.theme.pointTextFill, '#626262');
    expect(data.theme.xAxisTextFill, '#717171');
    expect(data.theme.yAxisTextFill, '#727272');
    expect(data.theme.internalBorderStrokeFill, '#818181');
    expect(data.theme.externalBorderStrokeFill, '#828282');
    final point = data.points.single;
    expect(point.className, 'priority');
    expect(point.radius, 12);
    expect(point.color, '#109060');
    expect(point.strokeColor, '#310085');
    expect(point.strokeWidth, 5);
    final size = const QuadrantChartLayout().computeLayout(
      data,
      const MermaidStyle(),
      const Size(1000, 900),
    );
    expect(size, const Size(640, 480));
    for (final style in [MermaidThemes.light, MermaidThemes.dark]) {
      final recorder = PictureRecorder();
      QuadrantChartPainter(
        data: data,
        style: style,
      ).paint(Canvas(recorder), size);
      recorder.endRecording();
    }
    expect(const MermaidParser().parseWithData('quadrantChart'), isNotNull);
    final trailingAxis = const MermaidParser().parseWithData('''quadrantChart
x-axis Urgent -->
y-axis Risk -->
quadrant-1 Centered %% ignored comment''');
    expect(trailingAxis, isNotNull);
    expect(trailingAxis!.quadrantChartData!.xLeft, 'Urgent ⟶ ');
    expect(trailingAxis.quadrantChartData!.yBottom, 'Risk ⟶ ');
    expect(trailingAxis.quadrantChartData!.quadrant1, 'Centered');
  });

  test('preserves and paints complete Treemap styles and configuration', () {
    const source = '''---
title: Revenue
config:
  themeVariables:
    titleColor: '#010203'
    cScale0: '#112233'
    cScalePeer0: '#223344'
    cScaleLabel0: '#334455'
  treemap:
    padding: 4
    diagramPadding: 12
    showValues: true
    nodeWidth: 80
    nodeHeight: 45
    borderWidth: 3
    valueFontSize: 14
    labelFontSize: 16
    valueFormat: "\$,.2f"
    useMaxWidth: false
---
treemap-beta
accTitle: Accessible revenue
accDescr: Revenue by product
"Products":::group
   "Software"
      "License": 1234.5:::important
classDef group fill:#f96,stroke:#333,stroke-width:2px;
classDef important fill:red,color:blue,stroke:#FFD600;
''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    final data = result!.treemapChartData!;
    expect(data.title, 'Revenue');
    expect(data.accessibilityTitle, 'Accessible revenue');
    expect(data.accessibilityDescription, 'Revenue by product');
    expect(data.padding, 4);
    expect(data.diagramPadding, 12);
    expect(data.showValues, isTrue);
    expect(data.nodeWidth, 80);
    expect(data.nodeHeight, 45);
    expect(data.borderWidth, 3);
    expect(data.valueFontSize, 14);
    expect(data.labelFontSize, 16);
    expect(data.valueFormat, r'$,.2f');
    expect(data.useMaxWidth, isFalse);
    expect(data.theme.titleColor, '#010203');
    expect(data.theme.colors.first, '#112233');
    expect(data.theme.peerColors.first, '#223344');
    expect(data.theme.labelColors.first, '#334455');
    final root = data.roots.single;
    expect(root.className, 'group');
    expect(root.fillColor, '#f96');
    expect(root.strokeColor, '#333');
    expect(root.strokeWidth, 2);
    final leaf = root.children.single.children.single;
    expect(leaf.value, 1234.5);
    expect(leaf.className, 'important');
    expect(leaf.fillColor, 'red');
    expect(leaf.textColor, 'blue');
    expect(leaf.strokeColor, '#FFD600');
    expect(data.roots, hasLength(1));
    final size = const TreemapChartLayout().computeLayout(
      data,
      const Size(1200, 800),
    );
    expect(size, const Size(800, 480));
    final recorder = PictureRecorder();
    TreemapPainter(
      data: data,
      style: const MermaidStyle(),
    ).paint(Canvas(recorder), size);
    recorder.endRecording();
    final responsive = const MermaidParser().parseWithData('''treemap
"A"
  "A1": 6
  "A2": 4
"B"
  "B1": 3
  "B2": 2
  "B3": 1''');
    expect(responsive, isNotNull);
    expect(responsive!.treemapChartData!.nodeWidth, 100);
    expect(responsive.treemapChartData!.nodeHeight, 40);
    expect(
      const TreemapChartLayout().computeLayout(
        responsive.treemapChartData!,
        const Size(500, 900),
      ),
      const Size(500, 200),
    );
    for (final theme in [MermaidThemes.light, MermaidThemes.dark]) {
      final picture = PictureRecorder();
      TreemapPainter(
        data: responsive.treemapChartData!,
        style: theme,
      ).paint(Canvas(picture), const Size(500, 200));
      picture.endRecording();
    }
    expect(
      const MermaidParser().parseWithData('treemap-invalid\n"A": 1'),
      isNull,
    );
    expect(
      const MermaidParser().parseWithData('treemap\naccDescr { missing'),
      isNull,
    );
  });

  test('matches Treemap D3 value formats and CSS color forms', () {
    expect(formatTreemapValue(1234.5, ','), '1,234.5');
    expect(formatTreemapValue(1234.5, '.2f'), '1234.50');
    expect(formatTreemapValue(.35, '.1%'), '35.0%');
    expect(formatTreemapValue(1234.5, r'$0,0'), r'$1,234.5');
    expect(formatTreemapValue(1234.5, r'$.2f'), r'$1234.50');
    expect(formatTreemapValue(42, '08d'), '00000042');
    expect(formatTreemapValue(255, '#x'), '0xff');
    expect(formatTreemapValue(1500, '.2s'), '1.5k');
    expect(formatTreemapValue(1234.5, 'not-a-format'), '1,234.5');
    expect(parseTreemapColor('#f968'), isNotNull);
    expect(parseTreemapColor('#11223380'), isNotNull);
    expect(parseTreemapColor('rgb(17, 34, 51)'), isNotNull);
    expect(parseTreemapColor('rgba(17 34 51 / 50%)'), isNotNull);
    expect(parseTreemapColor('hsl(210 50% 13%)'), isNotNull);
    expect(parseTreemapColor('orange'), isNotNull);
    expect(parseTreemapColor('not-a-color'), isNull);
  });

  test('preserves and paints complete Venn styles and configuration', () {
    const source = '''---
title: Teams
config:
  look: handDrawn
  handDrawnSeed: 19
  themeVariables:
    venn1: '#101112'
    venn2: '#202122'
    vennTitleTextColor: '#303132'
    vennSetTextColor: '#404142'
  venn:
    width: 720
    height: 460
    padding: 24
    useDebugLayout: true
    useMaxWidth: false
---
venn-beta
accTitle: Accessible teams
accDescr: Team overlap
set A["Frontend"]:20
  text A1["React"]
set B["Backend"]:12
union A,B["Shared"]:3
text A,B AB1["OpenAPI"]
style A fill:#ff6b6b,stroke:#333,stroke-width:2px,opacity:0.4
style A,B color:#112233
style A1 color:rgb(10, 20, 30)
''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    final data = result!.vennChartData!;
    expect(data.title, 'Teams');
    expect(data.accessibilityTitle, 'Accessible teams');
    expect(data.accessibilityDescription, 'Team overlap');
    expect(data.width, 720);
    expect(data.height, 460);
    expect(data.padding, 24);
    expect(data.useDebugLayout, isTrue);
    expect(data.useMaxWidth, isFalse);
    expect(data.theme.colors.take(2), ['#101112', '#202122']);
    expect(data.theme.titleTextColor, '#303132');
    expect(data.theme.setTextColor, '#404142');
    expect(data.handDrawn, isTrue);
    expect(data.handDrawnSeed, 19);
    expect(data.subsets, hasLength(3));
    expect(data.subsets.last.sets, ['A', 'B']);
    expect(data.annotations.map((item) => item.id), ['A1', 'AB1']);
    expect(data.annotations.last.sets, ['A', 'B']);
    expect(data.styleForSets(['A'])['fill'], '#ff6b6b');
    expect(data.styleForSets(['B', 'A'])['color'], '#112233');
    expect(data.styleForAnnotation('A1')['color'], 'rgb(10, 20, 30)');
    final size = const VennChartLayout().computeLayout(
      data,
      const Size(1200, 800),
    );
    expect(size, const Size(720, 460));
    final recorder = PictureRecorder();
    VennPainter(
      data: data,
      style: const MermaidStyle(),
    ).paint(Canvas(recorder), size);
    recorder.endRecording();

    expect(const MermaidParser().parse('venn-beta\nunion A,B'), isNull);
    expect(const MermaidParser().parse('venn-beta\nset A\nunion A,A'), isNull);
    expect(const MermaidParser().parseWithData('venn-beta'), isNotNull);
    final multiSet = const MermaidParser().parseWithData('''venn-beta
set A["A"]:20
set B["B"]:15
set C["C"]:10
union A,B:4
union A,C:3
union B,C:2
union A,B,C["All"]:1
style A,B,C fill:rgba(255, 0, 0, 0.2),color:hsl(210, 50%, 30%)''');
    expect(multiSet, isNotNull);
    expect(multiSet!.vennChartData!.subsets, hasLength(7));
    expect(
      const VennChartLayout().computeLayout(
        multiSet.vennChartData!,
        const Size(400, 900),
      ),
      const Size(400, 225),
    );
    for (final theme in [MermaidThemes.light, MermaidThemes.dark]) {
      final picture = PictureRecorder();
      VennPainter(
        data: multiSet.vennChartData!,
        style: theme,
      ).paint(Canvas(picture), const Size(400, 225));
      picture.endRecording();
    }
  });

  test('matches official frontmatter delimiter and failure semantics', () {
    const parser = MermaidParser();
    final missingClosing = parser.parseWithData('''---
title: ignored
pie
"A": 1''');
    expect(missingClosing, isNull);

    final mismatchedIndent = parser.parseWithData('''---
title: ignored
   ---
pie
"A": 1''');
    expect(mismatchedIndent, isNull);

    expect(
      parser.parseWithData('''---
value: !!!
---
pie
"A": 1'''),
      isNull,
    );
  });

  test(
    'applies every Wardley renderer parameter and syntax size precedence',
    () {
      const source = '''---
title: Configured map
config:
  themeVariables:
    wardley:
      backgroundColor: '#010203'
      axisColor: '#111213'
      axisTextColor: '#212223'
      gridColor: '#313233'
      componentFill: '#414243'
      componentStroke: '#515253'
      componentLabelColor: '#616263'
      linkStroke: '#717273'
      evolutionStroke: '#818283'
      annotationStroke: '#919293'
      annotationTextColor: '#a1a2a3'
      annotationFill: '#b1b2b3'
  wardley:
    width: 700
    height: 420
    padding: 36
    nodeRadius: 9
    nodeLabelOffset: 14
    axisFontSize: 13
    labelFontSize: 15
    showGrid: true
    useMaxWidth: false
---
wardley-beta
accTitle: Accessible map
accDescr: Value chain
anchor Customer [0.9, 0.8]
component Service [0.6, 0.5]
Customer -> Service
''';
      final result = const MermaidParser().parseWithData(source);
      expect(result, isNotNull);
      final data = result!.wardleyChartData!;
      expect(data.accessibilityTitle, 'Accessible map');
      expect(data.accessibilityDescription, 'Value chain');
      expect(data.width, 700);
      expect(data.height, 420);
      expect(data.padding, 36);
      expect(data.nodeRadius, 9);
      expect(data.nodeLabelOffset, 14);
      expect(data.axisFontSize, 13);
      expect(data.labelFontSize, 15);
      expect(data.showGrid, isTrue);
      expect(data.useMaxWidth, isFalse);
      expect(data.theme.backgroundColor, '#010203');
      expect(data.theme.axisColor, '#111213');
      expect(data.theme.axisTextColor, '#212223');
      expect(data.theme.gridColor, '#313233');
      expect(data.theme.componentFill, '#414243');
      expect(data.theme.componentStroke, '#515253');
      expect(data.theme.componentLabelColor, '#616263');
      expect(data.theme.linkStroke, '#717273');
      expect(data.theme.evolutionStroke, '#818283');
      expect(data.theme.annotationStroke, '#919293');
      expect(data.theme.annotationTextColor, '#a1a2a3');
      expect(data.theme.annotationFill, '#b1b2b3');
      final size = const WardleyChartLayout().computeLayout(
        data,
        const Size(1200, 800),
      );
      expect(size, const Size(700, 420));
      final recorder = PictureRecorder();
      WardleyPainter(
        data: data,
        style: const MermaidStyle(),
        title: result.diagram.title,
      ).paint(Canvas(recorder), size);
      recorder.endRecording();

      final explicit = const MermaidParser().parseWithData('''---
config:
  wardley:
    width: 700
    height: 420
---
wardley-beta
size [900, 500]
component Service [0.6, 0.5]
''');
      expect(explicit, isNotNull);
      expect(explicit!.wardleyChartData!.width, 900);
      expect(explicit.wardleyChartData!.height, 500);
      expect(explicit.wardleyChartData!.hasExplicitSize, isTrue);
      final percentages = const MermaidParser().parseWithData('''wardley-beta
evolution Genesis@25 -> Custom@50 -> Product@75 -> Commodity@100
anchor Customer [90, 80]
component Service [60, 50]
evolve Service 85
note "percent coordinates" [40, 30]
annotations [5, 90]
annotation 1, [70, 20] "point"
accelerator Growth [65, 55]
deaccelerator Friction [35, 45] %% trailing comment
Customer -> Service''');
      expect(percentages, isNotNull);
      expect(percentages!.wardleyChartData!.components.first.visibility, .9);
      expect(percentages.wardleyChartData!.components.first.evolution, .8);
      expect(percentages.wardleyChartData!.stages.last.boundary, 1);
      expect(percentages.wardleyChartData!.evolutions.single.target, .85);
      expect(percentages.wardleyChartData!.notes.single.visibility, .4);
      expect(percentages.wardleyChartData!.annotationBoxX, .05);
      expect(percentages.wardleyChartData!.forces.last.y, .45);
      expect(
        const WardleyChartLayout().computeLayout(
          percentages.wardleyChartData!,
          const Size(450, 900),
        ),
        const Size(450, 300),
      );

      final complete = const MermaidParser().parseWithData('''wardley-beta
title Strategy
evolution "Genesis"@0.25 / Concept -> Custom@0.5 -> Product@0.75 -> Commodity@1.0
anchor User [0.95, 0.9]
component Platform [0.7, 0.5] label [-12, 8] (build) inertia
component Vendor [0.55, 0.7] (buy)
component Partner [0.45, 0.65] (outsource)
component Ecosystem [0.35, 0.8] (market)
pipeline Platform {
  component API [0.4] label [3, -4]
  component Data [0.6]
}
User +> --> Platform ; demand
Platform +<> Vendor
Vendor +'supply'< Partner
Partner -.-> Ecosystem
evolve Platform 0.85
note "Strategic note" [0.3, 0.2]
annotations [0.05, 0.9]
annotation 1, [0.7, 0.2] "Risk"
accelerator Growth [0.65, 0.55]
deaccelerator Friction [0.35, 0.45]''');
      expect(complete, isNotNull);
      final completeData = complete!.wardleyChartData!;
      expect(completeData.components, hasLength(7));
      expect(
        completeData.components
            .where((item) => item.pipelineParent != null)
            .map((item) => item.id),
        ['Platform_API', 'Platform_Data'],
      );
      expect(completeData.links.map((item) => item.kind), [
        WardleyLinkKind.forward,
        WardleyLinkKind.bidirectional,
        WardleyLinkKind.reverse,
        WardleyLinkKind.dashed,
      ]);
      expect(completeData.links.first.label, 'demand');
      expect(completeData.links[2].label, 'supply');
      for (final theme in [MermaidThemes.light, MermaidThemes.dark]) {
        final picture = PictureRecorder();
        WardleyPainter(
          data: completeData,
          style: theme,
          title: complete.diagram.title,
        ).paint(Canvas(picture), const Size(900, 600));
        picture.endRecording();
      }
    },
  );

  test('applies every Cynefin renderer parameter and accessibility field', () {
    const source = '''---
title: Configured framework
config:
  cynefin:
    width: 720
    height: 480
    padding: 24
    showDomainDescriptions: false
    boundaryAmplitude: 17
    seed: 314
    useMaxWidth: false
---
cynefin-beta
accTitle: Accessible framework
accDescr {
Five decision domains
and their transitions
}
complex
  "Experiment"
complicated
  "Analyse"
clear
  "Categorise"
chaotic
  "Act"
confusion
  "Unknown"
complex --> complicated: "stabilises"
''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    final data = result!.cynefinChartData!;
    expect(result.diagram.title, 'Configured framework');
    expect(data.accessibilityTitle, 'Accessible framework');
    expect(
      data.accessibilityDescription,
      'Five decision domains\nand their transitions',
    );
    expect(data.width, 720);
    expect(data.height, 480);
    expect(data.padding, 24);
    expect(data.showDomainDescriptions, isFalse);
    expect(data.boundaryAmplitude, 17);
    expect(data.seed, 314);
    expect(data.useMaxWidth, isFalse);
    final size = const CynefinChartLayout().computeLayout(
      data,
      const Size(1200, 800),
    );
    expect(size, const Size(768, 528));
    final recorder = PictureRecorder();
    CynefinPainter(
      data: data,
      style: const MermaidStyle(),
      title: result.diagram.title,
    ).paint(Canvas(recorder), size);
    recorder.endRecording();

    final clamped = const MermaidParser().parseWithData('''---
config:
  cynefin:
    boundaryAmplitude: 500
---
cynefin-beta
complex
  "Probe"
''');
    expect(clamped, isNotNull);
    expect(clamped!.cynefinChartData!.boundaryAmplitude, 50);
  });

  test('renders the complete Info grammar in light and dark themes', () {
    const parser = MermaidParser();
    for (final source in ['info', 'info showInfo']) {
      final result = parser.parseWithData(source);
      expect(result, isNotNull);
      expect(result!.diagram.type, DiagramType.info);
      expect(result.diagram.nodes.single.label, 'v11.16.0');
      for (final style in [MermaidThemes.light, MermaidThemes.dark]) {
        final recorder = PictureRecorder();
        InfoPainter(
          version: '11.16.0',
          style: style,
        ).paint(Canvas(recorder), const Size(400, 100));
        recorder.endRecording();
      }
    }
    expect(parser.parse('info unsupported'), isNull);
    expect(parser.parse('info\nshowInfo'), isNull);
  });

  test('applies official Ishikawa config and comment grammar', () {
    const source = '''---
config:
  look: handDrawn
  handDrawnSeed: 73
  fontSize: 16px
  themeVariables:
    lineColor: '#123456'
    mainBkg: '#f0f1f2'
    textColor: '#234567'
  ishikawa:
    diagramPadding: 12
    useMaxWidth: false
---
ishikawa
    Effect
    %% this line is not a cause
    Process
        Delay
    People''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    final data = result!.ishikawaChartData!;
    expect(data.diagramPadding, 12);
    expect(data.useMaxWidth, isFalse);
    expect(data.handDrawn, isTrue);
    expect(data.handDrawnSeed, 73);
    expect(data.fontSize, 16);
    expect(data.lineColor, '#123456');
    expect(data.fillColor, '#f0f1f2');
    expect(data.textColor, '#234567');
    expect(data.effect.text, 'Effect');
    expect(data.effect.children.map((node) => node.text), [
      'Process',
      'People',
    ]);
    expect(data.effect.children.first.children.single.text, 'Delay');
    final size = const IshikawaChartLayout().computeLayout(
      data,
      const Size(1200, 800),
    );
    expect(size, const Size(644, 384));
    for (final style in [MermaidThemes.light, MermaidThemes.dark]) {
      final recorder = PictureRecorder();
      IshikawaPainter(data: data, style: style).paint(Canvas(recorder), size);
      recorder.endRecording();
    }
  });

  test('parses every pinned official syntax documentation diagram', () {
    final corpus =
        jsonDecode(
              File(
                'test/fixtures/mermaid/official_syntax_examples_11_16_0.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    expect(corpus['mermaidVersion'], '11.16.0');
    expect(corpus['commit'], '7c0cafcf42e76bfaf79d0cbbd12edb986612f014');
    final fixtures = corpus['fixtures']! as List<dynamic>;
    expect(fixtures, hasLength(418));
    final failures = <String>[];
    for (final rawFixture in fixtures) {
      final fixture = rawFixture! as Map<String, dynamic>;
      if (const MermaidParser().parse(fixture['source']! as String) == null) {
        failures.add('${fixture['document']}#${fixture['index']}');
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test(
    'preserves ZenUML participants, calls, replies, comments, and fragments',
    () {
      const source = '''zenuml
title Checkout
@Actor Client
@Database Store as Inventory
// transactional path
Client->API.checkout(cart) {
  try {
    Store.reserve(cart) {
      return reservation
    }
  } catch {
    @return
    API->Client: failed
  } finally {
    API->Store: audit
  }
}''';
      final result = const MermaidParser().parseWithData(source);
      expect(result, isNotNull);
      expect(result!.diagram.type, DiagramType.zenuml);
      expect(result.diagram.title, 'Checkout');
      final data = result.zenUmlChartData!;
      expect(
        data.participants.map((item) => item.id),
        containsAll(['Client', 'Store', 'API']),
      );
      expect(
        data.participants.firstWhere((item) => item.id == 'Client').kind,
        ZenParticipantKind.actor,
      );
      expect(data.events.whereType<ZenCommentData>(), hasLength(1));
      expect(
        data.events.whereType<ZenFragmentData>().map((item) => item.kind),
        containsAll([
          ZenFragmentKind.tryBlock,
          ZenFragmentKind.catchBlock,
          ZenFragmentKind.finallyBlock,
        ]),
      );
      expect(
        data.events.whereType<ZenMessageData>().map((item) => item.kind),
        contains(ZenMessageKind.reply),
      );
      final officialReplies = const MermaidParser().parseWithData('''---
title: Native ZenUML
config:
  sequence:
    useMaxWidth: false
---
zenuml
// participant comment is ignored
BookService
// **message comment**
SomeType book = Store.getBook(42)
Store.lookup() {
  return found
}
@return
Store->BookService: result''');
      expect(officialReplies, isNotNull);
      final replyData = officialReplies!.zenUmlChartData!;
      expect(replyData.title, 'Native ZenUML');
      expect(replyData.useMaxWidth, isFalse);
      expect(replyData.events.whereType<ZenCommentData>(), hasLength(1));
      expect(
        replyData.events.whereType<ZenCommentData>().single.text,
        '**message comment**',
      );
      expect(
        replyData.events.whereType<ZenMessageData>().where(
          (message) => message.kind == ZenMessageKind.reply,
        ),
        hasLength(3),
      );
      expect(
        (officialReplies.diagram.getNode('Store')! as SequenceParticipant)
            .participantType,
        ParticipantType.participant,
      );
      final size = const SequenceLayout().computeLayout(
        officialReplies.diagram,
        const MermaidStyle(),
        const Size(900, 600),
      );
      for (final theme in [MermaidThemes.light, MermaidThemes.dark]) {
        final recorder = PictureRecorder();
        ZenUmlPainter(
          diagram: officialReplies.diagram,
          data: replyData,
          style: theme,
        ).paint(Canvas(recorder), size);
        recorder.endRecording();
      }
    },
  );

  test(
    'preserves complete sequence semantics instead of dropping directives',
    () {
      const source = '''sequenceDiagram
autonumber 10 5
actor A as Alice
participant DB@{ "type": "database", "alias": "Store" }
links A: {"Dashboard": "https://example.com"}
create participant B as Bob
A->>+DB: Query
Note over A,DB: Transaction
alt Found
  DB-->>A: Result
else Missing
  DB--xA: Failure
end
deactivate DB
destroy B''';
      final result = const MermaidParser().parseWithData(source);
      expect(result, isNotNull);
      final data = result!.sequenceChartData!;
      expect(data.autoNumber, isTrue);
      expect(data.autoNumberStart, 10);
      expect(data.autoNumberStep, 5);
      expect(
        data.participants.firstWhere((item) => item.id == 'DB').kind,
        SequenceParticipantKind.database,
      );
      expect(
        (result.diagram.getNode('DB')! as SequenceParticipant).participantType,
        ParticipantType.database,
      );
      expect(data.participants.first.links['Dashboard'], 'https://example.com');
      expect(data.events.whereType<SequenceNoteData>(), hasLength(1));
      expect(data.events.whereType<SequenceActivationData>(), hasLength(2));
      expect(
        data.events.whereType<SequenceFragmentData>().map((item) => item.kind),
        containsAll([
          SequenceFragmentKind.alternative,
          SequenceFragmentKind.elseAlternative,
        ]),
      );
      expect(
        data.events.whereType<SequenceLifecycleData>().map((item) => item.kind),
        containsAll([
          SequenceLifecycleKind.create,
          SequenceLifecycleKind.destroy,
        ]),
      );
      expect(
        data.events.whereType<SequenceMessageEventData>().map(
          (item) => item.number,
        ),
        [10, 15, 20],
      );
    },
  );

  test(
    'preserves Mermaid 11 sequence arrow, box, accessibility, and numbering semantics',
    () {
      const source = r'''sequenceDiagram
accTitle: Checkout exchange
accDescr {
  All supported native signal geometries
}
autonumber 3 2
box Aqua Clients
  actor A as Alice
end
box Services
  participant B
end
A->B: open
A-->B: dotted open
A->>B: solid
A-->>B: dotted
A<<->>B: bidirectional
A<<-->>B: bidirectional dotted
A-xB: cross
A--xB: dotted cross
A-)B: point
A--)B: dotted point
A-|\B: solid top
A-|/B: solid bottom
A-\\B: stick top
A-//B: stick bottom
A--|\B: dotted solid top
A--|/B: dotted solid bottom
A--\\B: dotted stick top
A--//B: dotted stick bottom
A/|-B: reverse top
A\|-B: reverse bottom
A//-B: reverse stick top
A\\-B: reverse stick bottom
A/|--B: dotted reverse top
A\|--B: dotted reverse bottom
A//--B: dotted reverse stick top
A\\--B: dotted reverse stick bottom
A() -> ()B: dual central
A->>+B: activate target
B-->>-A: deactivate source
autonumber off
A->B: hidden number''';
      final result = const MermaidParser().parseWithData(source);
      expect(result, isNotNull);
      final data = result!.sequenceChartData!;
      expect(data.accessibilityTitle, 'Checkout exchange');
      expect(
        data.accessibilityDescription,
        'All supported native signal geometries',
      );
      expect(data.boxes, hasLength(2));
      expect(data.boxes.first.color, 'Aqua');
      expect(data.boxes.first.label, 'Clients');
      expect(data.boxes.last.color, isNull);
      expect(data.boxes.last.label, 'Services');
      expect(data.participants.map((item) => item.boxId), [0, 1]);
      final messages = data.events
          .whereType<SequenceMessageEventData>()
          .toList();
      expect(
        messages.map((item) => item.signalKind).toSet(),
        containsAll(SequenceSignalKind.values),
      );
      expect(messages.first.number, 3);
      expect(messages[1].number, 5);
      expect(messages.last.number, isNull);
      final central = messages.singleWhere((item) => item.centralAtSource);
      expect(central.centralAtTarget, isTrue);
      final activations = data.events
          .whereType<SequenceActivationData>()
          .toList();
      expect(activations.map((item) => (item.actor, item.active)), [
        ('B', true),
        ('B', false),
      ]);

      final compact = const MermaidParser().parseWithData(
        'sequenceDiagram;actor Alice Smith;participant API Gateway;'
        'autonumber 10.1 .01;Alice Smith->>API Gateway:wrap: hello;'
        'autonumber off;API Gateway-->Alice Smith:nowrap: done;',
      );
      expect(compact, isNotNull);
      final compactData = compact!.sequenceChartData!;
      expect(compactData.participants.map((item) => item.id), [
        'Alice Smith',
        'API Gateway',
      ]);
      expect(compactData.autoNumberStart, 10.1);
      expect(compactData.autoNumberStep, .01);
      final compactMessages = compactData.events
          .whereType<SequenceMessageEventData>()
          .toList();
      expect(compactMessages.first.number, 10.1);
      expect(compactMessages.first.wrap, isTrue);
      expect(compactMessages.last.wrap, isFalse);

      final size = const SequenceLayout().computeLayout(
        result.diagram,
        const MermaidStyle(),
        const Size(900, 900),
      );
      for (final theme in [MermaidThemes.light, MermaidThemes.dark]) {
        final recorder = PictureRecorder();
        SequencePainter(
          diagram: result.diagram,
          sequenceData: data,
          style: theme,
        ).paint(Canvas(recorder), size);
        recorder.endRecording();
      }
    },
  );

  test('preserves complete class diagram semantics', () {
    const source = r'''classDiagram
direction LR
namespace Platform.Auth["Authentication"] {
  class Repository~T~:::service {
    <<interface>>
    -List~T~ values
    +find(id) T*
    +shared()$
  }
}
class Consumer
Consumer "1" --> "0..*" Repository : uses
note for Repository "Storage abstraction"
classDef service fill:#f96
style Consumer stroke:#333
link Repository "https://example.com" "Open docs"''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    final data = result!.classDiagramData!;
    final repository = data.classes.firstWhere(
      (item) => item.id == 'Repository',
    );
    expect(repository.genericType, 'T');
    expect(repository.namespace, 'Platform.Auth');
    expect(repository.annotations, ['interface']);
    expect(repository.members, hasLength(3));
    expect(repository.members.first.visibility, ClassMemberVisibility.private);
    expect(repository.members[1].isAbstract, isTrue);
    expect(repository.members[2].isStatic, isTrue);
    expect(repository.cssClass, 'service');
    expect(repository.link, 'https://example.com');
    expect(repository.tooltip, 'Open docs');
    expect(data.namespaces.map((item) => item.id), [
      'Platform',
      'Platform.Auth',
    ]);
    expect(data.relations.single.leftCardinality, '1');
    expect(data.relations.single.rightCardinality, '0..*');
    expect(data.relations.single.label, 'uses');
    expect(data.notes.single.text, 'Storage abstraction');
    expect(data.classDefinitions['service'], 'fill:#f96');
  });

  test('applies complete Class config/theme and paints UML semantics', () {
    const source = '''---
title: Domain model
config:
  look: neo
  class:
    titleTopMargin: 19
    arrowMarkerAbsolute: true
    dividerMargin: 13
    padding: 9
    textHeight: 14
    defaultRenderer: elk
    nodeSpacing: 61
    rankSpacing: 67
    diagramPadding: 15
    htmlLabels: true
    hideEmptyMembersBox: true
    hierarchicalNamespaces: false
    useMaxWidth: false
  themeVariables:
    mainBkg: '#111111'
    nodeBorder: '#222222'
    classText: '#333333'
    textColor: '#444444'
    lineColor: '#555555'
    edgeLabelBackground: '#666666'
    clusterBkg: '#777777'
    clusterBorder: '#888888'
    titleColor: '#999999'
    noteBkgColor: '#aaaaaa'
    noteBorderColor: '#bbbbbb'
    noteTextColor: '#cccccc'
    strokeWidth: 4
---
classDiagram-v2
accTitle: Accessible classes
accDescr: Native UML class model
direction RL
namespace Core.Domain {
  class Parent {
    +id String
  }
  class Child
}
Parent <|-- Child : extends
Parent <|.. Child : realizes
Parent *-- Child : owns
Parent o-- Child : groups
Parent <-- Child : points
Parent ()-- Child : service
note for Child "A child class"''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    final data = result!.classDiagramData!;
    expect(data.title, 'Domain model');
    expect(data.accessibilityTitle, 'Accessible classes');
    expect(data.accessibilityDescription, 'Native UML class model');
    expect(data.titleTopMargin, 19);
    expect(data.arrowMarkerAbsolute, isTrue);
    expect(data.dividerMargin, 13);
    expect(data.padding, 9);
    expect(data.textHeight, 14);
    expect(data.defaultRenderer, 'elk');
    expect(data.nodeSpacing, 61);
    expect(data.rankSpacing, 67);
    expect(data.diagramPadding, 15);
    expect(data.htmlLabels, isTrue);
    expect(data.hideEmptyMembersBox, isTrue);
    expect(data.hierarchicalNamespaces, isFalse);
    expect(data.useMaxWidth, isFalse);
    expect(data.look, 'neo');
    expect(data.theme.mainBackground, '#111111');
    expect(data.theme.nodeBorder, '#222222');
    expect(data.theme.classText, '#333333');
    expect(data.theme.edgeLabelBackground, '#666666');
    expect(data.theme.clusterBackground, '#777777');
    expect(data.theme.noteBackground, '#aaaaaa');
    expect(data.theme.strokeWidth, 4);
    expect(
      data.relations.map((relation) => relation.leftEnd),
      containsAll([
        ClassRelationEnd.inheritance,
        ClassRelationEnd.realization,
        ClassRelationEnd.composition,
        ClassRelationEnd.aggregation,
        ClassRelationEnd.association,
        ClassRelationEnd.lollipop,
      ]),
    );
    final size = const ClassChartLayout().computeLayout(
      result.diagram,
      data,
      const Size(700, 500),
    );
    final recorder = PictureRecorder();
    ClassPainter(
      diagram: result.diagram,
      data: data,
      style: const MermaidStyle(),
    ).paint(Canvas(recorder), size);
    recorder.endRecording();
  });

  test('Class rejects a displaced header', () {
    expect(
      const MermaidParser().parseWithData('unexpected\nclassDiagram\nclass A'),
      isNull,
    );
  });

  test('preserves complete state hierarchy and pseudostate semantics', () {
    const source = '''stateDiagram-v2
direction LR
classDef active fill:#f00,color:white
[*] --> Active:::active
state Active {
  direction TB
  [*] --> Waiting
  state decision <<choice>>
  Waiting --> decision : inspect
  decision --> Ready : yes
  --
  state forked <<fork>>
  forked --> Parallel
}
note right of Active : Composite state
class Ready active
Active --> [*]''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    final data = result!.stateDiagramData!;
    final active = data.states.firstWhere((item) => item.id == 'Active');
    expect(active.kind, StateNodeKind.composite);
    expect(active.direction, DiagramDirection.topToBottom);
    expect(active.cssClasses, ['active']);
    expect(
      data.states.firstWhere((item) => item.id == 'Waiting').parent,
      'Active',
    );
    expect(
      data.states.firstWhere((item) => item.id == 'decision').kind,
      StateNodeKind.choice,
    );
    expect(
      data.states.firstWhere((item) => item.id == 'forked').kind,
      StateNodeKind.fork,
    );
    expect(data.regions.single.parent, 'Active');
    expect(data.notes.single.text, 'Composite state');
    expect(data.transitions.map((item) => item.label), contains('inspect'));
    expect(data.classDefinitions['active'], 'fill:#f00,color:white');
  });

  test('applies complete State config/theme and paints native semantics', () {
    const source = '''---
title: Stateful workflow
config:
  look: neo
  state:
    titleTopMargin: 20
    arrowMarkerAbsolute: true
    dividerMargin: 12
    sizeUnit: 6
    padding: 11
    textHeight: 13
    titleShift: -9
    noteMargin: 14
    nodeSpacing: 65
    rankSpacing: 70
    forkWidth: 82
    forkHeight: 9
    miniPadding: 3
    fontSizeFactor: 5.5
    fontSize: 20
    labelHeight: 18
    edgeLengthFactor: '24'
    compositTitleSize: 40
    radius: 8
    defaultRenderer: dagre-wrapper
    useMaxWidth: false
  themeVariables:
    stateBkg: '#111111'
    stateBorder: '#222222'
    stateLabelColor: '#333333'
    compositeBackground: '#444444'
    compositeTitleBackground: '#555555'
    noteBkgColor: '#666666'
    noteBorderColor: '#777777'
    noteTextColor: '#888888'
    specialStateColor: '#999999'
    innerEndBackground: '#aaaaaa'
    transitionColor: '#bbbbbb'
    transitionLabelColor: '#cccccc'
    edgeLabelBackground: '#dddddd'
    lineColor: '#eeeeee'
    textColor: '#121212'
    strokeWidth: 4
---
stateDiagram-v2
accTitle: Accessible workflow
accDescr: Composite workflow states
[*] --> Idle
state Active {
  Idle --> Choice
  state Choice <<choice>>
  --
  state Work <<fork>>
}
note left of Idle : Waiting
Idle --> [*] : stop''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    final data = result!.stateDiagramData!;
    expect(data.title, 'Stateful workflow');
    expect(data.accessibilityTitle, 'Accessible workflow');
    expect(data.accessibilityDescription, 'Composite workflow states');
    expect(data.titleTopMargin, 20);
    expect(data.arrowMarkerAbsolute, isTrue);
    expect(data.dividerMargin, 12);
    expect(data.sizeUnit, 6);
    expect(data.padding, 11);
    expect(data.textHeight, 13);
    expect(data.titleShift, -9);
    expect(data.noteMargin, 14);
    expect(data.nodeSpacing, 65);
    expect(data.rankSpacing, 70);
    expect(data.forkWidth, 82);
    expect(data.forkHeight, 9);
    expect(data.miniPadding, 3);
    expect(data.fontSizeFactor, 5.5);
    expect(data.fontSize, 20);
    expect(data.labelHeight, 18);
    expect(data.edgeLengthFactor, '24');
    expect(data.compositeTitleSize, 40);
    expect(data.radius, 8);
    expect(data.defaultRenderer, 'dagre-wrapper');
    expect(data.useMaxWidth, isFalse);
    expect(data.look, 'neo');
    expect(data.theme.stateBackground, '#111111');
    expect(data.theme.compositeBackground, '#444444');
    expect(data.theme.noteBackground, '#666666');
    expect(data.theme.specialStateColor, '#999999');
    expect(data.theme.transitionColor, '#bbbbbb');
    expect(data.theme.strokeWidth, 4);
    final size = const StateChartLayout().computeLayout(
      result.diagram,
      data,
      const Size(500, 500),
    );
    final recorder = PictureRecorder();
    StatePainter(
      diagram: result.diagram,
      data: data,
      style: const MermaidStyle(),
    ).paint(Canvas(recorder), size);
    recorder.endRecording();
  });

  test('State rejects a displaced header', () {
    expect(
      const MermaidParser().parseWithData(
        'unexpected\nstateDiagram-v2\n[*] --> Ready',
      ),
      isNull,
    );
  });

  test('preserves complete ER attributes, cardinalities, and identity', () {
    const source = '''erDiagram
direction LR
classDef table fill:#f9f
p["Person"]:::table {
  string id PK "Primary identifier"
  string? middleName
  string[] roles UK, FK
}
a["Account"] {
  string email UK
}
p ||--o{ a : owns
a zero or one optionally to zero or more SESSION : opens
style a stroke:#333,stroke-width:2px''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    final data = result!.erDiagramData!;
    final person = data.entities.firstWhere((item) => item.id == 'p');
    expect(person.label, 'Person');
    expect(person.cssClasses, ['table']);
    expect(person.attributes, hasLength(3));
    expect(person.attributes.first.keys, [ErAttributeKey.primary]);
    expect(person.attributes.first.comment, 'Primary identifier');
    expect(person.attributes[1].type, 'string?');
    expect(person.attributes[2].keys, [
      ErAttributeKey.unique,
      ErAttributeKey.foreign,
    ]);
    expect(data.relationships, hasLength(2));
    expect(data.relationships.first.fromCardinality, ErCardinality.exactlyOne);
    expect(data.relationships.first.toCardinality, ErCardinality.zeroOrMore);
    expect(data.relationships.first.identifying, isTrue);
    expect(data.relationships.last.identifying, isFalse);
    expect(data.relationships.last.fromCardinality, ErCardinality.zeroOrOne);
    expect(data.relationships.last.toCardinality, ErCardinality.zeroOrMore);
    expect(data.classDefinitions['table'], 'fill:#f9f');
  });

  test('applies complete ER config/theme and paints cardinalities', () {
    const source = '''---
title: Data model
config:
  look: neo
  er:
    titleTopMargin: 18
    diagramPadding: 26
    layoutDirection: RL
    minEntityWidth: 190
    minEntityHeight: 130
    entityPadding: 17
    nodeSpacing: 155
    rankSpacing: 95
    stroke: '#111111'
    fill: '#222222'
    fontSize: 15
    useMaxWidth: false
  themeVariables:
    mainBkg: '#333333'
    nodeBorder: '#444444'
    nodeTextColor: '#555555'
    textColor: '#666666'
    lineColor: '#777777'
    tertiaryColor: '#888888'
    edgeLabelBackground: '#999999'
    erEdgeLabelBackground: '#aaaaaa'
    bkgColorArray: ['#bbbbbb', '#cccccc']
    borderColorArray: ['#dddddd', '#eeeeee']
    strokeWidth: 4
---
erDiagram
accTitle: Accessible model
accDescr: Entities and cardinalities
CUSTOMER {
  int id PK "identifier"
  string email UK
}
ORDER {
  int customer_id FK
}
CUSTOMER ||--o{ ORDER : places
ORDER }o..|| CUSTOMER : references''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    final data = result!.erDiagramData!;
    expect(data.title, 'Data model');
    expect(data.accessibilityTitle, 'Accessible model');
    expect(data.accessibilityDescription, 'Entities and cardinalities');
    expect(data.titleTopMargin, 18);
    expect(data.diagramPadding, 26);
    expect(data.layoutDirection, 'RL');
    expect(data.minEntityWidth, 190);
    expect(data.minEntityHeight, 130);
    expect(data.entityPadding, 17);
    expect(data.nodeSpacing, 155);
    expect(data.rankSpacing, 95);
    expect(data.stroke, '#111111');
    expect(data.fill, '#222222');
    expect(data.fontSize, 15);
    expect(data.useMaxWidth, isFalse);
    expect(data.look, 'neo');
    expect(data.theme.mainBackground, '#333333');
    expect(data.theme.nodeBorder, '#444444');
    expect(data.theme.nodeTextColor, '#555555');
    expect(data.theme.lineColor, '#777777');
    expect(data.theme.erEdgeLabelBackground, '#aaaaaa');
    expect(data.theme.backgroundColors, ['#bbbbbb', '#cccccc']);
    expect(data.theme.borderColors, ['#dddddd', '#eeeeee']);
    expect(data.theme.strokeWidth, 4);
    final size = const ErChartLayout().computeLayout(
      data,
      const Size(500, 500),
    );
    final recorder = PictureRecorder();
    ErPainter(
      data: data,
      style: const MermaidStyle(),
    ).paint(Canvas(recorder), size);
    recorder.endRecording();
  });

  test('ER rejects a displaced header', () {
    expect(
      const MermaidParser().parseWithData(
        'unexpected\nerDiagram\nA ||--|| B : has',
      ),
      isNull,
    );
  });

  test(
    'preserves complete Requirement semantics and relationship direction',
    () {
      const source = '''requirementDiagram
title Safety allocation
accTitle: Accessible requirements
accDescr: Requirement relationship example
direction LR
classDef critical fill:#f96,stroke:#333,stroke-width:4px
functionalRequirement "Safe stop":::critical {
  id: SYS-1
  text: "Stop within **two seconds**"
  risk: high
  verifyMethod: test
}
element Controller {
  type: embedded system
  docRef: docs/controller.md
}
Controller - satisfies -> "Safe stop"
"Safe stop" <- verifies - Controller
style Controller fill:#f9f,stroke:#333
class Controller critical''';
      final result = const MermaidParser().parseWithData(source);
      expect(result, isNotNull);
      final data = result!.requirementDiagramData!;
      expect(data.title, 'Safety allocation');
      expect(data.accessibilityTitle, 'Accessible requirements');
      expect(data.accessibilityDescription, 'Requirement relationship example');
      final requirement = data.requirements.single;
      expect(requirement.name, 'Safe stop');
      expect(requirement.kind, RequirementKind.functionalRequirement);
      expect(requirement.requirementId, 'SYS-1');
      expect(requirement.text, 'Stop within **two seconds**');
      expect(requirement.risk, RequirementRisk.high);
      expect(
        requirement.verificationMethod,
        RequirementVerificationMethod.test,
      );
      expect(requirement.cssClasses, ['default', 'critical']);
      final element = data.elements.single;
      expect(element.type, 'embedded system');
      expect(element.documentReference, 'docs/controller.md');
      expect(element.rawStyle, 'fill:#f9f,stroke:#333');
      expect(element.cssClasses, ['default', 'critical']);
      expect(data.relationships, hasLength(2));
      expect(
        data.relationships.first.kind,
        RequirementRelationshipKind.satisfies,
      );
      expect(data.relationships.first.usedLeftArrowSyntax, isFalse);
      expect(data.relationships.last.from, 'Controller');
      expect(data.relationships.last.to, 'Safe stop');
      expect(
        data.relationships.last.kind,
        RequirementRelationshipKind.verifies,
      );
      expect(data.relationships.last.usedLeftArrowSyntax, isTrue);
      expect(data.classDefinitions['critical'], contains('fill:#f96'));
    },
  );

  test('applies complete Requirement config/theme and paints directions', () {
    const source = '''---
title: Styled requirements
config:
  look: neo
  requirement:
    rect_fill: '#111111'
    text_color: '#222222'
    rect_border_size: 3px
    rect_border_color: '#333333'
    rect_min_width: 180
    rect_min_height: 160
    fontSize: 15
    rect_padding: 12
    line_height: 23
    useMaxWidth: false
  themeVariables:
    requirementBackground: '#444444'
    requirementBorderColor: '#555555'
    requirementBorderSize: 4px
    requirementTextColor: '#666666'
    relationColor: '#777777'
    relationLabelBackground: '#888888'
    relationLabelColor: '#999999'
    edgeLabelBackground: '#aaaaaa'
    requirementEdgeLabelBackground: '#bbbbbb'
    nodeBorder: '#cccccc'
    bkgColorArray: ['#dddddd', '#eeeeee']
    borderColorArray: ['#121212', '#232323']
    strokeWidth: 5
---
requirementDiagram
accDescr {Styled native requirement graph}
requirement Parent {
  id: P
  text: Parent requirement
}
functionalRequirement Child {
  id: C
  text: Child requirement
  risk: medium
  verifyMethod: analysis
}
element System {
  type: software
  docRef: system.md
}
Parent - contains -> Child
Child - satisfies -> System''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    final data = result!.requirementDiagramData!;
    expect(data.title, 'Styled requirements');
    expect(data.accessibilityDescription, 'Styled native requirement graph');
    expect(data.rectFill, '#111111');
    expect(data.textColor, '#222222');
    expect(data.rectBorderSize, '3px');
    expect(data.rectBorderColor, '#333333');
    expect(data.rectMinWidth, 180);
    expect(data.rectMinHeight, 160);
    expect(data.fontSize, 15);
    expect(data.rectPadding, 12);
    expect(data.lineHeight, 23);
    expect(data.useMaxWidth, isFalse);
    expect(data.look, 'neo');
    expect(data.theme.background, '#444444');
    expect(data.theme.borderColor, '#555555');
    expect(data.theme.borderSize, '4px');
    expect(data.theme.textColor, '#666666');
    expect(data.theme.relationColor, '#777777');
    expect(data.theme.relationLabelBackground, '#888888');
    expect(data.theme.relationLabelColor, '#999999');
    expect(data.theme.edgeLabelBackground, '#aaaaaa');
    expect(data.theme.requirementEdgeLabelBackground, '#bbbbbb');
    expect(data.theme.backgroundColors, ['#dddddd', '#eeeeee']);
    expect(data.theme.borderColors, ['#121212', '#232323']);
    expect(data.theme.strokeWidth, 5);
    for (final direction in DiagramDirection.values) {
      final diagram = result.diagram.copyWith(direction: direction);
      final size = const RequirementChartLayout().computeLayout(
        diagram,
        data,
        const Size(500, 500),
      );
      final recorder = PictureRecorder();
      RequirementPainter(
        diagram: diagram,
        data: data,
        style: const MermaidStyle(),
      ).paint(Canvas(recorder), size);
      recorder.endRecording();
    }
  });

  test('Requirement rejects a displaced header', () {
    expect(
      const MermaidParser().parseWithData(
        'unexpected\nrequirementDiagram\nrequirement A {\nid: A\n}',
      ),
      isNull,
    );
  });

  test('preserves Journey sections, scores, actors, and directives', () {
    const source = '''journey
title Checkout journey
accTitle: Accessible checkout
accDescr {
An ordered checkout journey
for multiple people
}
section Browse
Find item: 4.5: Buyer, Helper
section Purchase
Pay: 2: Buyer
section Purchase
Confirm: 5''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    final data = result!.journeyChartData!;
    expect(data.title, 'Checkout journey');
    expect(data.accessibilityTitle, 'Accessible checkout');
    expect(
      data.accessibilityDescription,
      'An ordered checkout journey\nfor multiple people',
    );
    expect(data.sections.map((section) => section.title), [
      'Browse',
      'Purchase',
      'Purchase',
    ]);
    expect(data.tasks.map((task) => task.name), [
      'Find item',
      'Pay',
      'Confirm',
    ]);
    expect(data.tasks.first.score, 4.5);
    expect(data.tasks.first.actors, ['Buyer', 'Helper']);
    expect(data.tasks.last.actors, isEmpty);
    expect(data.tasks.last.sectionIndex, 2);
    expect(data.actors, ['Buyer', 'Helper']);
    expect(result.diagram.title, 'Checkout journey');
  });

  test('applies complete Journey config/theme and paints natively', () {
    const source = '''---
title: Configured journey
config:
  journey:
    diagramMarginX: 21
    diagramMarginY: 12
    leftMargin: 90
    maxLabelWidth: 240
    width: 130
    height: 55
    boxMargin: 11
    boxTextMargin: 6
    noteMargin: 13
    messageMargin: 31
    messageAlign: right
    bottomMarginAdj: 4
    rightAngles: true
    taskFontSize: 16
    taskFontFamily: Inter
    taskMargin: 42
    activationWidth: 12
    textPlacement: fo
    actorColours: ['#111111', '#222222']
    sectionFills: ['#abcdef']
    sectionColours: ['#123456']
    titleColor: '#fedcba'
    titleFontFamily: Georgia
    titleFontSize: 28px
    useMaxWidth: false
  themeVariables:
    fillType0: '#010101'
    actor0: '#020202'
    section0: '#030303'
    faceColor: '#040404'
    textColor: '#050505'
    lineColor: '#060606'
    titleColor: '#070707'
    nodeBorder: '#080808'
---
journey
accDescr {One-line accessible journey}
section Explore #ideas
Research #tools: 4: Ada, Bob
Build: 2: Ada''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    final data = result!.journeyChartData!;
    expect(data.title, 'Configured journey');
    expect(data.accessibilityDescription, 'One-line accessible journey');
    expect(data.sections.single.title, 'Explore #ideas');
    expect(data.tasks.first.name, 'Research #tools');
    expect(data.diagramMarginX, 21);
    expect(data.diagramMarginY, 12);
    expect(data.leftMargin, 90);
    expect(data.maxLabelWidth, 240);
    expect(data.width, 130);
    expect(data.height, 55);
    expect(data.boxMargin, 11);
    expect(data.boxTextMargin, 6);
    expect(data.noteMargin, 13);
    expect(data.messageMargin, 31);
    expect(data.messageAlign, JourneyMessageAlign.right);
    expect(data.bottomMarginAdj, 4);
    expect(data.rightAngles, isTrue);
    expect(data.taskFontSize, 16);
    expect(data.taskFontFamily, 'Inter');
    expect(data.taskMargin, 42);
    expect(data.activationWidth, 12);
    expect(data.textPlacement, 'fo');
    expect(data.actorColors, ['#111111', '#222222']);
    expect(data.sectionFills, ['#abcdef']);
    expect(data.sectionColors, ['#123456']);
    expect(data.titleColor, '#fedcba');
    expect(data.titleFontFamily, 'Georgia');
    expect(data.titleFontSize, '28px');
    expect(data.useMaxWidth, isFalse);
    expect(data.theme.fillColors.first, '#010101');
    expect(data.theme.actorColors.first, '#020202');
    expect(data.theme.sectionTextColors.first, '#030303');
    expect(data.theme.faceColor, '#040404');
    expect(data.theme.textColor, '#050505');
    expect(data.theme.lineColor, '#060606');
    expect(data.theme.titleColor, '#070707');
    expect(data.theme.nodeBorder, '#080808');
    final size = const JourneyChartLayout().computeLayout(
      data,
      const Size(320, 500),
    );
    expect(size.width, greaterThan(320));
    final recorder = PictureRecorder();
    JourneyPainter(
      data: data,
      style: const MermaidStyle(),
    ).paint(Canvas(recorder), size);
    recorder.endRecording();
  });

  test('Journey accepts an empty document and rejects a displaced header', () {
    final empty = const MermaidParser().parseWithData('journey');
    expect(empty, isNotNull);
    expect(empty!.journeyChartData!.tasks, isEmpty);
    expect(
      const MermaidParser().parseWithData('unexpected\njourney\nTask: 5'),
      isNull,
    );
  });

  test('preserves Mindmap hierarchy, shapes, Markdown, icons, and classes', () {
    const source = '''mindmap
    root((Mind map))
        square[Square]
        ::icon(fa fa-book)
          cloud)Cloud(
      rounded(Rounded)
      :::urgent large
        bang))Bang((
        hex{{Hexagon}}
          markdown["`**Bold** with
a second line`"]''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    final data = result!.mindmapChartData!;
    expect(data.nodes, hasLength(7));
    expect(data.nodes.first.sourceId, 'root');
    expect(data.nodes.first.shape, MindmapNodeShape.circle);
    expect(data.nodes[1].shape, MindmapNodeShape.rectangle);
    expect(data.nodes[1].icon, 'fa fa-book');
    expect(data.nodes[2].shape, MindmapNodeShape.cloud);
    expect(data.nodes[2].parentIndex, 1);
    expect(data.nodes[3].parentIndex, 0);
    expect(data.nodes[3].cssClass, 'urgent large');
    expect(data.nodes[4].shape, MindmapNodeShape.bang);
    expect(data.nodes[5].shape, MindmapNodeShape.hexagon);
    expect(data.nodes[6].label, '**Bold** with\na second line');
    expect(data.nodes[1].section, 0);
    expect(data.nodes[3].section, 1);
  });

  test('applies complete Mindmap config/theme and paints both layouts', () {
    const source = '''---
title: Native mindmap
config:
  look: neo
  mindmap:
    padding: 24
    maxNodeWidth: 170
    layoutAlgorithm: dagre
    useMaxWidth: false
  themeVariables:
    cScale0: '#101010'
    cScaleInv0: '#202020'
    cScaleLabel0: '#303030'
    lineColor0: '#404040'
    git0: '#505050'
    gitBranchLabel0: '#606060'
    nodeBorder: '#707070'
    mainBkg: '#808080'
    useGradient: true
    gradientStart: '#909090'
    gradientStop: '#a0a0a0'
    strokeWidth: 4
---
mindmap
  root((Root))
    Plan
      Research
      Build
        ::icon(fa fa-star)
    Ship''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    final data = result!.mindmapChartData!;
    expect(data.title, 'Native mindmap');
    expect(data.padding, 24);
    expect(data.maxNodeWidth, 170);
    expect(data.layoutAlgorithm, 'dagre');
    expect(data.useMaxWidth, isFalse);
    expect(data.look, 'neo');
    expect(data.theme.colors.first, '#101010');
    expect(data.theme.inverseColors.first, '#202020');
    expect(data.theme.labelColors.first, '#303030');
    expect(data.theme.lineColors.first, '#404040');
    expect(data.theme.rootColor, '#505050');
    expect(data.theme.rootLabelColor, '#606060');
    expect(data.theme.nodeBorder, '#707070');
    expect(data.theme.mainBackground, '#808080');
    expect(data.theme.useGradient, isTrue);
    expect(data.theme.gradientStart, '#909090');
    expect(data.theme.gradientStop, '#a0a0a0');
    expect(data.theme.strokeWidth, 4);
    expect(
      data.nodes.firstWhere((node) => node.label == 'Build').icon,
      'fa fa-star',
    );
    for (final chart in [
      data,
      data.copyWith(layoutAlgorithm: 'cose-bilkent'),
    ]) {
      final size = const MindmapChartLayout().computeLayout(
        chart,
        const Size(500, 500),
      );
      final recorder = PictureRecorder();
      MindmapPainter(
        data: chart,
        style: const MermaidStyle(),
      ).paint(Canvas(recorder), size);
      recorder.endRecording();
    }
  });

  test('Mindmap rejects a displaced header', () {
    expect(
      const MermaidParser().parseWithData('unexpected\nmindmap\n  Root'),
      isNull,
    );
  });

  test('preserves Sankey node order, numeric weights, and escaped CSV', () {
    const source = '''sankey-beta
Source,"Target, primary",12.5
Source,"Target with ""quotes""",3
"Multi
line",Sink,1''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    final data = result!.sankeyChartData!;
    expect(data.nodes.map((node) => node.id), [
      'Source',
      'Target, primary',
      'Target with "quotes"',
      'Multi\nline',
      'Sink',
    ]);
    expect(data.links.map((link) => link.value), [12.5, 3, 1]);
    expect(data.links.last.source, 'Multi\nline');
  });

  test('preserves GitGraph DAG, attributes, branch order, and cherry-pick', () {
    const source = '''gitGraph TB:
title Release history
accTitle: Accessible Git history
commit id:"ZERO" msg:"root" tag:"v0" tag:"stable" type:HIGHLIGHT
branch develop order: 2
commit id:"A" type:REVERSE
branch release order: 1
commit id:"R"
checkout main
commit id:"ONE"
merge develop id:"MERGE" tag:"merged" type:NORMAL
switch release
cherry-pick id:"MERGE" parent:"A" tag:"backport"''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    final data = result!.gitGraphChartData!;
    expect(data.direction, GitGraphDirection.topToBottom);
    expect(data.title, 'Release history');
    expect(data.accessibilityTitle, 'Accessible Git history');
    expect(data.branches.map((branch) => branch.name), [
      'main',
      'develop',
      'release',
    ]);
    expect(
      data.branches.firstWhere((branch) => branch.name == 'develop').order,
      2,
    );
    expect(data.commits.first.tags, ['v0', 'stable']);
    expect(data.commits.first.kind, GitCommitKind.highlight);
    expect(data.commits.first.message, 'root');
    final merge = data.commits.firstWhere((commit) => commit.id == 'MERGE');
    expect(merge.kind, GitCommitKind.merge);
    expect(merge.customKind, GitCommitKind.normal);
    expect(merge.parents, ['ONE', 'A']);
    final cherryPick = data.commits.last;
    expect(cherryPick.kind, GitCommitKind.cherryPick);
    expect(cherryPick.cherryPickedFrom, 'MERGE');
    expect(cherryPick.cherryPickParent, 'A');
    expect(cherryPick.parents, ['R', 'MERGE']);
    expect(cherryPick.tags, ['backport']);
    expect(data.currentBranch, 'release');
    expect(data.commands, hasLength(10));
    expect(const MermaidParser().parseWithData('gitGraph'), isNotNull);
    final quotedComment = const MermaidParser().parseWithData('''gitGraph
commit id:"A%%B" msg:"keeps %% text" %% real comment''');
    expect(quotedComment, isNotNull);
    expect(quotedComment!.gitGraphChartData!.commits.single.id, 'A%%B');
    expect(
      const MermaidParser().parseWithData('not git\ngitGraph\ncommit'),
      isNull,
    );
    expect(const MermaidParser().parseWithData('gitGraph sideways'), isNull);
    for (final direction in ['LR', 'TB', 'BT']) {
      final oriented = const MermaidParser().parseWithData(
        '''gitGraph $direction:
commit id:"root" type:HIGHLIGHT
branch feature order:1
commit id:"reverse" type:REVERSE
checkout main
commit id:"main"
merge feature id:"merge" type:NORMAL
switch feature
cherry-pick id:"main" tag:"picked"''',
      );
      expect(oriented, isNotNull);
      final orientedData = oriented!.gitGraphChartData!;
      final orientedSize = const GitGraphChartLayout().computeLayout(
        orientedData,
        const Size(500, 400),
      );
      for (final theme in [MermaidThemes.light, MermaidThemes.dark]) {
        final picture = PictureRecorder();
        GitGraphPainter(
          data: orientedData,
          style: theme,
        ).paint(Canvas(picture), orientedSize);
        picture.endRecording();
      }
    }
  });

  test('preserves Tree View types, hierarchy, annotations, and metadata', () {
    const source = '''treeView-beta
title Workspace
accTitle: Accessible workspace
root/
├── src/
│   ├── App.tsx :::highlight icon(logos:react) ## main component
│   └── index.ts ## entry point
└── "README file.md"''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    final data = result!.treeViewChartData!;
    expect(data.title, 'Workspace');
    expect(data.accessibilityTitle, 'Accessible workspace');
    expect(data.nodes.map((node) => node.name), [
      'root',
      'src',
      'App.tsx',
      'index.ts',
      'README file.md',
    ]);
    expect(data.nodes.first.kind, TreeViewNodeKind.directory);
    expect(data.nodes[1].parentIndex, 0);
    expect(data.nodes[2].parentIndex, 1);
    expect(data.nodes[2].cssClass, 'highlight');
    expect(data.nodes[2].icon, 'logos:react');
    expect(data.nodes[2].description, 'main component');
    expect(data.nodes.last.parentIndex, 0);
  });

  test('preserves Packet declarations, resolved ranges, and directives', () {
    const source = '''packet-beta
title Protocol header
accTitle: Accessible packet
accDescr: Bit layout
+1: "Flag"
+7: "Kind"
8-15: "Length"
16: "Marker"''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    final data = result!.packetChartData!;
    expect(data.title, 'Protocol header');
    expect(data.accessibilityTitle, 'Accessible packet');
    expect(data.accessibilityDescription, 'Bit layout');
    expect(data.fields.map((field) => (field.start, field.end)), [
      (0, 0),
      (1, 7),
      (8, 15),
      (16, 16),
    ]);
    expect(data.fields.first.relative, isTrue);
    expect(data.fields.first.declaredBits, 1);
    expect(data.fields[2].relative, isFalse);
    expect(data.fields[2].declaredStart, 8);
    expect(data.fields[2].declaredEnd, 15);
    expect(result.diagram.title, 'Protocol header');
    expect(const MermaidParser().parse('packet\n0: "A"\n2: "gap"'), isNull);
    expect(const MermaidParser().parse('packet\n+0: "empty"'), isNull);
    final escaped = const MermaidParser().parseWithData(r'''packet
0: "A \"quoted\" field\nnext"''');
    expect(
      escaped!.packetChartData!.fields.single.label,
      'A "quoted" field\nnext',
    );
    final empty = const MermaidParser().parseWithData('packet-beta');
    expect(empty, isNotNull);
    expect(empty!.packetChartData!.fields, isEmpty);
    expect(
      const PacketChartLayout().computeLayout(
        empty.packetChartData!,
        const MermaidStyle(),
        const Size(100, 100),
      ),
      const Size(1026, 15),
    );
    expect(const MermaidParser().parse('packet\n0-10000: "too large"'), isNull);
  });

  test('resolves complete Gantt timing, controls, tags, and interactions', () {
    const source = '''gantt
title Release plan
accTitle: Accessible release plan
accDescr: Dependency schedule
dateFormat YYYY-MM-DD
axisFormat %Y-%m-%d
tickInterval 1week
weekday monday
weekend friday
excludes weekends,2024-01-05
includes 2024-01-05
inclusiveEndDates
topAxis
todayMarker stroke:red,stroke-width:2px
section Build
Base :done, a, 2024-01-01, 2d
Quick :active, b, 2024-01-02, 5h
Until release :crit, done, vert, u, after b, until release
Release :milestone, release, 2024-01-10, 0d
After both :after a b, 1h
Month :month, 2024-01-01, 1M
Manual :manual, 2024-02-01, 2024-02-02
click a href "https://example.com" call openTask("a", 2)''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    final data = result!.ganttChartData!;
    expect(data.title, 'Release plan');
    expect(data.accessibilityTitle, 'Accessible release plan');
    expect(data.accessibilityDescription, 'Dependency schedule');
    expect(data.tickInterval, '1week');
    expect(data.weekday, 'monday');
    expect(data.weekend, 'friday');
    expect(data.excludes, 'weekends,2024-01-05');
    expect(data.includes, '2024-01-05');
    expect(data.inclusiveEndDates, isTrue);
    expect(data.topAxis, isTrue);
    expect(data.todayMarkerStyle, 'stroke:red,stroke-width:2px');
    final until = data.getTask('u')!;
    expect(until.tags, [
      GanttTaskTag.critical,
      GanttTaskTag.done,
      GanttTaskTag.vertical,
    ]);
    expect(until.startKind, GanttTimingKind.after);
    expect(until.endKind, GanttTimingKind.until);
    expect(until.dependencies, ['b']);
    expect(until.untilDependencies, ['release']);
    expect(until.endDate, DateTime(2024, 1, 10));
    final afterBoth = data.tasks.firstWhere(
      (task) => task.name == 'After both',
    );
    expect(afterBoth.dependencies, ['a', 'b']);
    expect(afterBoth.startDate, DateTime(2024, 1, 3));
    expect(afterBoth.endDate, DateTime(2024, 1, 3, 1));
    expect(data.getTask('month')!.endDate, DateTime(2024, 2, 12));
    expect(data.getTask('manual')!.endDate, DateTime(2024, 2, 3));
    expect(data.interactions.single.taskId, 'a');
    expect(data.interactions.single.href, 'https://example.com');
    expect(data.interactions.single.callback, 'openTask');
    expect(data.interactions.single.callbackArguments, '"a", 2');
    expect(const MermaidParser().parseWithData('gantt'), isNotNull);
    expect(
      const MermaidParser()
          .parseWithData('gantt\naccDescr { Inline description }')
          ?.ganttChartData
          ?.accessibilityDescription,
      'Inline description',
    );
    expect(const MermaidParser().parseWithData('not gantt\ngantt'), isNull);
    final today = DateTime.now();
    final interactive = GanttChartData(
      tasks: [
        GanttTask(
          id: 'tap',
          name: 'T',
          startDate: today.subtract(const Duration(days: 1)),
          endDate: today.add(const Duration(days: 1)),
          status: GanttTaskStatus.milestone,
          tags: const [
            GanttTaskTag.critical,
            GanttTaskTag.done,
            GanttTaskTag.milestone,
            GanttTaskTag.vertical,
          ],
        ),
      ],
      interactions: const [
        GanttTaskInteraction(taskId: 'tap', href: 'https://example.com/task'),
      ],
      todayMarkerStyle: 'stroke:#123456,stroke-width:4px',
    );
    final interactiveSize = const GanttChartLayout().computeLayout(
      interactive,
      const MermaidStyle(),
      const Size(700, 400),
    );
    final painter = GanttPainter(
      ganttData: interactive,
      style: const MermaidStyle(),
    );
    expect(
      painter.interactionAt(const Offset(180, 30), interactiveSize)?.taskId,
      'tap',
    );
    final picture = PictureRecorder();
    painter.paint(Canvas(picture), interactiveSize);
    picture.endRecording();
  });

  test('extends Gantt durations across merged excluded calendar days', () {
    const source = '''gantt
dateFormat YYYY-MM-DD
excludes weekends
excludes 2024-03-06, friday
excludes weekends
includes 2024-03-01
includes 2024-03-06
weekend saturday
section Calendar
Friday included :a, 2024-03-01, 1d
After weekend :b, after a, 2d''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    final data = result!.ganttChartData!;
    expect(data.excludes, 'weekends,2024-03-06,friday');
    expect(data.includes, '2024-03-01,2024-03-06');
    expect(data.getTask('a')!.endDate, DateTime(2024, 3, 4));
    expect(data.getTask('b')!.startDate, DateTime(2024, 3, 4));
    expect(data.getTask('b')!.endDate, DateTime(2024, 3, 6));
  });

  test(
    'honors Friday-Saturday weekends and rejects all-excluded calendars',
    () {
      final fridayWeekend = const MermaidParser().parseWithData('''gantt
dateFormat YYYY-MM-DD
excludes weekends
weekend friday
Task :a, 2024-02-28, 3d''');
      expect(fridayWeekend, isNotNull);
      expect(
        fridayWeekend!.ganttChartData!.getTask('a')!.endDate,
        DateTime(2024, 3, 4),
      );

      final impossible = const MermaidParser().parseWithData('''gantt
dateFormat YYYY-MM-DD
excludes weekends,monday,tuesday,wednesday,thursday,friday
Task :a, 2024-02-28, 1d''');
      expect(impossible, isNull);
    },
  );

  test('preserves strict Pie labels, values, duplicates, and directives', () {
    const source = '''pie showData
title Composition
accTitle: Accessible composition
accDescr: Slice values
"Escaped \\"label\\"" : 2.5
'Single \\'quote' : 0
"Escaped \\"label\\"" : 9''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    final data = result!.pieChartData!;
    expect(data.title, 'Composition');
    expect(data.accessibilityTitle, 'Accessible composition');
    expect(data.accessibilityDescription, 'Slice values');
    expect(data.showValuesInLegend, isTrue);
    expect(data.slices, hasLength(2));
    expect(data.slices.first.label, 'Escaped "label"');
    expect(data.slices.first.value, 2.5);
    expect(data.slices.last.label, "Single 'quote");
    expect(data.slices.last.value, 0);
    expect(const MermaidParser().parse('pie\n"Bad": -1'), isNull);
    expect(const MermaidParser().parse('pie\nBad: 1'), isNull);
  });

  test(
    'executes Pie legend placement, sizing, and multiline accessibility',
    () {
      const source = '''---
config:
  pie:
    useMaxWidth: false
    textPosition: 0.42
    donutHole: 0.35
    legendPosition: left
    highlightSlice: Main
  themeVariables:
    pie1: '#112233'
    pie3: 'rgb(44, 55, 66)'
    pieTitleTextSize: 29px
    pieTitleTextColor: '#010203'
    pieSectionTextSize: 15px
    pieSectionTextColor: white
    pieLegendTextSize: 13px
    pieLegendTextColor: '#040506'
    pieStrokeColor: '#070809'
    pieStrokeWidth: 3px
    pieOuterStrokeColor: rgba(10, 20, 30, 0.5)
    pieOuterStrokeWidth: 4px
    pieOpacity: 0.55
---
pie showData
accDescr {
Composition by
native slices
}
"Main" : 99
"Trace" : 0.5
"Other" : 0.5
''';
      final result = const MermaidParser().parseWithData(source);
      expect(result, isNotNull);
      final data = result!.pieChartData!;
      expect(data.accessibilityDescription, 'Composition by\nnative slices');
      expect(data.textPosition, .42);
      expect(data.donutHole, .35);
      expect(data.legendPosition, PieLegendPosition.left);
      expect(data.highlightSlice, 'Main');
      expect(data.useMaxWidth, isFalse);
      expect(data.theme.colors, {0: '#112233', 2: 'rgb(44, 55, 66)'});
      expect(data.theme.titleTextSize, 29);
      expect(data.theme.titleTextColor, '#010203');
      expect(data.theme.sectionTextSize, 15);
      expect(data.theme.sectionTextColor, 'white');
      expect(data.theme.legendTextSize, 13);
      expect(data.theme.legendTextColor, '#040506');
      expect(data.theme.strokeColor, '#070809');
      expect(data.theme.strokeWidth, 3);
      expect(data.theme.outerStrokeColor, 'rgba(10, 20, 30, 0.5)');
      expect(data.theme.outerStrokeWidth, 4);
      expect(data.theme.opacity, .55);
      final layout = const PieChartLayout();
      final intrinsic = layout.computeLayout(
        data,
        const MermaidStyle(),
        const Size(1200, 800),
      );
      expect(intrinsic.width, lessThan(1200));
      expect(
        layout
            .computeLayout(
              data.copyWith(useMaxWidth: true),
              const MermaidStyle(),
              const Size(1200, 800),
            )
            .width,
        1200,
      );
      for (final position in PieLegendPosition.values) {
        for (final style in [MermaidThemes.light, MermaidThemes.dark]) {
          final configured = data.copyWith(legendPosition: position);
          final size = layout.computeLayout(
            configured,
            style,
            const Size(760, 620),
          );
          final recorder = PictureRecorder();
          PieChartPainter(
            pieData: configured,
            style: style,
          ).paint(Canvas(recorder), size);
          recorder.endRecording();
        }
      }
      final hoverData = data.copyWith(
        donutHole: 0,
        legendPosition: PieLegendPosition.center,
        highlightSlice: 'hover',
      );
      final hoverSize = layout.computeLayout(
        hoverData,
        const MermaidStyle(),
        const Size(400, 300),
      );
      final hoverPainter = PieChartPainter(
        pieData: hoverData,
        style: const MermaidStyle(),
        hoveredSlice: 'Main',
      );
      expect(
        hoverPainter.sliceAt(
          Offset(hoverSize.width / 2, hoverSize.height / 2 - 40),
          hoverSize,
        ),
        'Main',
      );
      expect(
        const MermaidParser().parse('pie\naccDescr {\nmissing close\n"A": 1'),
        isNull,
      );
    },
  );

  test('applies every official XY Chart rendering parameter', () {
    const source = r'''---
title: Horizontal sales
config:
  themeVariables:
    xyChart:
      backgroundColor: '#010203'
      titleColor: '#111213'
      dataLabelColor: '#212223'
      xAxisLabelColor: '#313233'
      xAxisTitleColor: '#414243'
      xAxisTickColor: '#515253'
      xAxisLineColor: '#616263'
      yAxisLabelColor: '#717273'
      yAxisTitleColor: '#818283'
      yAxisTickColor: '#919293'
      yAxisLineColor: '#a1a2a3'
      plotColorPalette: '#b1b2b3, #c1c2c3'
  xyChart:
    width: 820
    height: 420
    titleFontSize: 24
    titlePadding: 13
    showDataLabel: true
    showDataLabelOutsideBar: true
    showTitle: false
    chartOrientation: horizontal
    plotReservedSpacePercent: 72
    xAxis:
      showLabel: false
      labelFontSize: 11
      labelPadding: 7
      showTitle: false
      titleFontSize: 17
      titlePadding: 8
      showTick: false
      tickLength: 6
      tickWidth: 3
      showAxisLine: false
      axisLineWidth: 4
      labelRotation: -30
    yAxis:
      showLabel: true
      labelFontSize: 12
      labelPadding: 9
      showTitle: true
      titleFontSize: 18
      titlePadding: 10
      showTick: true
      tickLength: 7
      tickWidth: 2.5
      showAxisLine: true
      axisLineWidth: 5
      labelRotation: 25
---
xychart-beta horizontal
  accTitle: Quarterly revenue
  accDescr {
    Revenue by quarter
    including forecast
  }
  x-axis [Q1, Q2]
  y-axis "Revenue" -10 --> 30
  bar [12, -4]
  line "Trend" [1e1 "ten, exact", 20 "twenty \"quoted\""]
''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    final data = result!.xyChartData!;
    expect(data.title, 'Horizontal sales');
    expect(data.width, 820);
    expect(data.height, 420);
    expect(data.titleFontSize, 24);
    expect(data.titlePadding, 13);
    expect(data.showDataLabel, isTrue);
    expect(data.showDataLabelOutsideBar, isTrue);
    expect(data.showTitle, isFalse);
    expect(data.orientation, XYChartOrientation.horizontal);
    expect(data.plotReservedSpacePercent, 72);
    expect(data.xAxisStyle.showLabel, isFalse);
    expect(data.xAxisStyle.labelFontSize, 11);
    expect(data.xAxisStyle.labelPadding, 7);
    expect(data.xAxisStyle.showTitle, isFalse);
    expect(data.xAxisStyle.titleFontSize, 17);
    expect(data.xAxisStyle.titlePadding, 8);
    expect(data.xAxisStyle.showTick, isFalse);
    expect(data.xAxisStyle.tickLength, 6);
    expect(data.xAxisStyle.tickWidth, 3);
    expect(data.xAxisStyle.showAxisLine, isFalse);
    expect(data.xAxisStyle.axisLineWidth, 4);
    expect(data.xAxisStyle.labelRotation, -30);
    expect(data.yAxisStyle.showLabel, isTrue);
    expect(data.yAxisStyle.labelFontSize, 12);
    expect(data.yAxisStyle.labelPadding, 9);
    expect(data.yAxisStyle.showTitle, isTrue);
    expect(data.yAxisStyle.titleFontSize, 18);
    expect(data.yAxisStyle.titlePadding, 10);
    expect(data.yAxisStyle.showTick, isTrue);
    expect(data.yAxisStyle.tickLength, 7);
    expect(data.yAxisStyle.tickWidth, 2.5);
    expect(data.yAxisStyle.showAxisLine, isTrue);
    expect(data.yAxisStyle.axisLineWidth, 5);
    expect(data.yAxisStyle.labelRotation, 25);
    expect(data.series.last.values, [10, 20]);
    expect(data.series.last.title, 'Trend');
    expect(data.series.last.pointLabels, ['ten, exact', 'twenty "quoted"']);
    expect(data.accessibilityTitle, 'Quarterly revenue');
    expect(
      data.accessibilityDescription,
      'Revenue by quarter\n    including forecast',
    );
    expect(data.theme.backgroundColor, '#010203');
    expect(data.theme.titleColor, '#111213');
    expect(data.theme.dataLabelColor, '#212223');
    expect(data.theme.xAxisLabelColor, '#313233');
    expect(data.theme.xAxisTitleColor, '#414243');
    expect(data.theme.xAxisTickColor, '#515253');
    expect(data.theme.xAxisLineColor, '#616263');
    expect(data.theme.yAxisLabelColor, '#717273');
    expect(data.theme.yAxisTitleColor, '#818283');
    expect(data.theme.yAxisTickColor, '#919293');
    expect(data.theme.yAxisLineColor, '#a1a2a3');
    expect(data.theme.plotColorPalette, ['#b1b2b3', '#c1c2c3']);
    expect(
      const XYChartLayout().computeLayout(
        data,
        MermaidThemes.light,
        Size.infinite,
      ),
      const Size(820, 420),
    );
    expect(
      const XYChartLayout().computeLayout(
        data,
        MermaidThemes.light,
        const Size(410, 1000),
      ),
      const Size(410, 210),
    );
    final recorder = PictureRecorder();
    XYChartPainter(
      xyData: data,
      style: MermaidThemes.light,
    ).paint(Canvas(recorder), const Size(820, 420));
    recorder.endRecording();
    final numeric = const MermaidParser().parseWithData(
      'xychart; x-axis "Index" -2 --> 2; y-axis "Value"; '
      'bar "`Constant bars`" [4, 4, 4]; line [4 "same", 4, 4]',
    );
    expect(numeric, isNotNull);
    expect(numeric!.xyChartData!.series.first.title, 'Constant bars');
    expect(numeric.xyChartData!.series.first.titleIsMarkdown, isTrue);
    expect(numeric.xyChartData!.effectiveYMin, 4);
    expect(numeric.xyChartData!.effectiveYMax, 4);
    for (final theme in [MermaidThemes.light, MermaidThemes.dark]) {
      final picture = PictureRecorder();
      XYChartPainter(
        xyData: numeric.xyChartData!,
        style: theme,
      ).paint(Canvas(picture), const Size(350, 250));
      picture.endRecording();
    }
    for (final invalid in [
      'xychart diagonal\nbar [1]',
      'xychart\ny-axis [one, two]\nbar [1, 2]',
      'xychart\nline [1,,2]',
      'xychart\nline [one, 2]',
      'xychart\nline [1, 2] trailing',
      'xychart\nunknown [1, 2]',
    ]) {
      expect(const MermaidParser().parseWithData(invalid), isNull);
    }
  });

  test('applies every official Flowchart renderer parameter', () {
    const source = '''---
title: Configured flow
config:
  htmlLabels: false
  flowchart:
    titleTopMargin: 19
    subGraphTitleMargin:
      top: 6
      bottom: 7
    arrowMarkerAbsolute: true
    diagramPadding: 12
    htmlLabels: true
    nodeSpacing: 33
    rankSpacing: 47
    curve: stepAfter
    padding: 18
    useMaxWidth: false
    defaultRenderer: elk
    wrappingWidth: 96
    inheritDir: true
---
flowchart LR
  subgraph cluster [Configured cluster]
    A[This label wraps because it is deliberately long] --> B{Ready?}
  end
  B --> A
''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    final diagram = result!.diagram;
    final config = diagram.flowchartConfig!;
    expect(diagram.title, 'Configured flow');
    expect(config.titleTopMargin, 19);
    expect(config.subgraphTitleMarginTop, 6);
    expect(config.subgraphTitleMarginBottom, 7);
    expect(config.arrowMarkerAbsolute, isTrue);
    expect(config.diagramPadding, 12);
    expect(config.htmlLabels, isFalse);
    expect(config.nodeSpacing, 33);
    expect(config.rankSpacing, 47);
    expect(config.curve, FlowchartCurve.stepAfter);
    expect(config.padding, 18);
    expect(config.useMaxWidth, isFalse);
    expect(config.defaultRenderer, FlowchartRenderer.elk);
    expect(config.wrappingWidth, 96);
    expect(config.inheritDirection, isTrue);
    expect(diagram.style.padding, 12);

    final size = const DagreLayout().computeLayout(
      diagram,
      diagram.style,
      const Size(900, 700),
    );
    expect(size.width, greaterThan(0));
    expect(size.height, greaterThan(config.titleTopMargin));
    expect(diagram.nodes.first.width, lessThanOrEqualTo(96 + 18 * 4));
    for (final curve in FlowchartCurve.values) {
      final configured = diagram.copyWith(
        flowchartConfig: config.copyWith(curve: curve),
      );
      final recorder = PictureRecorder();
      FlowchartPainter(
        diagram: configured,
        style: configured.style,
      ).paint(Canvas(recorder), size);
      recorder.endRecording();
    }
  });

  test('preserves complete Mermaid 11 flowchart grammar and expanded shapes', () {
    const shapeNames = [
      'rect',
      'rounded',
      'stadium',
      'fr-rect',
      'cyl',
      'datastore',
      'circle',
      'bang',
      'cloud',
      'diam',
      'hex',
      'lean-r',
      'lean-l',
      'trap-b',
      'trap-t',
      'dbl-circ',
      'text',
      'notch-rect',
      'lin-rect',
      'sm-circ',
      'fr-circ',
      'fork',
      'hourglass',
      'brace',
      'brace-r',
      'braces',
      'bolt',
      'doc',
      'delay',
      'h-cyl',
      'lin-cyl',
      'curv-trap',
      'div-rect',
      'tri',
      'win-pane',
      'f-circ',
      'notch-pent',
      'flip-tri',
      'sl-rect',
      'docs',
      'st-rect',
      'bow-rect',
      'cross-circ',
      'tag-doc',
      'tag-rect',
      'flag',
      'odd',
      'lin-doc',
    ];
    final shapeLines = [
      for (var index = 0; index < shapeNames.length; index++)
        'S$index@{ shape: ${shapeNames[index]}, label: "${shapeNames[index]}" }',
    ];
    final source = '''flowchart LR
accTitle: Native flow
accDescr {Complete v11 semantics}
subgraph outer[Outer]
  direction TB
  subgraph inner[Inner]
    direction RL
    A:::hot & B --> C & D
  end
end
C e1@==>|processed| D
e1@{ animate: true, animation: fast, curve: stepAfter }
linkStyle 0 stroke:#123456,stroke-width:3px,curve:linear
classDef hot fill:#ff0000,stroke:#00ff00
style D fill:#abcdef,color:#010203
click A href "https://example.com" "Open docs" _blank
I@{ icon: "fa:user", form: circle, label: "User", pos: t, h: 60 }
M@{ img: "https://example.com/a.png", label: "Image", pos: b, w: 80, h: 60, constraint: on }
${shapeLines.join('\n')}''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    final diagram = result!.diagram;
    expect(diagram.accessibilityTitle, 'Native flow');
    expect(diagram.accessibilityDescription, 'Complete v11 semantics');
    expect(diagram.subgraphs, hasLength(2));
    expect(
      diagram.subgraphs.firstWhere((item) => item.id == 'inner').direction,
      DiagramDirection.rightToLeft,
    );
    expect(diagram.edges.where((edge) => edge.from == 'A'), hasLength(2));
    expect(diagram.edges.where((edge) => edge.from == 'B'), hasLength(2));
    final identified = diagram.edges.singleWhere((edge) => edge.id == 'e1');
    expect(identified.lineType, LineType.thick);
    expect(identified.animated, isTrue);
    expect(identified.animationSpeed, 'fast');
    expect(identified.interpolate, 'stepAfter');
    expect(identified.label, 'processed');
    final actor = diagram.getNode('A')!;
    expect(actor.link, 'https://example.com');
    expect(actor.tooltip, 'Open docs');
    expect(actor.linkTarget, '_blank');
    expect(actor.style?.fillColor, 0xFFFF0000);
    expect(diagram.getNode('I')!.shape, NodeShape.icon);
    expect(diagram.getNode('M')!.shape, NodeShape.image);
    expect(diagram.getNode('M')!.attributes['constraint'], 'on');
    expect(
      List.generate(
        shapeLines.length,
        (index) => diagram.getNode('S$index')!.shape,
      ).toSet(),
      hasLength(shapeNames.length),
    );

    final size = const DagreLayout().computeLayout(
      diagram,
      diagram.style,
      const Size(1600, 1200),
    );
    for (final theme in [MermaidThemes.light, MermaidThemes.dark]) {
      final recorder = PictureRecorder();
      FlowchartPainter(
        diagram: diagram,
        style: theme,
      ).paint(Canvas(recorder), size);
      recorder.endRecording();
    }
  });

  test(
    'matches official Flowchart parser edge, Markdown, and ID long tails',
    () {
      for (final statement in [
        '1-->2abc',
        'A<-- text -->B',
        'B<== thick ==>C',
        'C<-. dotted .->D',
        'D o--x E',
        'E ~~~ F',
        'H(((Stop)))',
        'N-1-->N_2',
        'X & Y edgeA@--> Z & W',
      ]) {
        expect(
          const MermaidParser().parseWithData('graph TD\n$statement'),
          isNotNull,
          reason: statement,
        );
      }
      const source = '''graph TD
1-->2abc
A<-- text -->B
B<== thick ==>C
C<-. dotted .->D
D o--x E
E ~~~ F
G["`**Bold**
line`"]
H(((Stop)))
N-1-->N_2
X & Y edgeA@--> Z & W
X1 edgeA@--> Z1 & W1
edgeA@{ animate: true }
linkStyle 0,1 interpolate cardinal stroke-width:2px
classDef default fill:#eeeeee
style A,B fill:#abcdef
click A call inspect("one", 2) "Inspect"
click B href "https://example.com" "Open" _self''';
      final sourceLines = source.split('\n');
      for (var count = 2; count <= sourceLines.length; count++) {
        final prefix = sourceLines.take(count).join('\n');
        if ('`'.allMatches(prefix).length.isOdd) continue;
        expect(
          const MermaidParser().parseWithData(prefix),
          isNotNull,
          reason: 'prefix ending at ${sourceLines[count - 1]}',
        );
      }
      final result = const MermaidParser().parseWithData(source);
      expect(result, isNotNull);
      final diagram = result!.diagram;
      expect(diagram.getNode('1'), isNotNull);
      expect(diagram.getNode('2abc'), isNotNull);
      expect(diagram.getNode('H')!.shape, NodeShape.doubleCircle);
      expect(diagram.getNode('G')!.label, '**Bold**\nline');
      expect(diagram.getNode('A')!.callback, 'inspect');
      expect(diagram.getNode('A')!.callbackArgs, ['"one"', '2']);
      expect(diagram.getNode('B')!.link, 'https://example.com');
      expect(diagram.getNode('B')!.linkTarget, '_self');
      expect(diagram.getNode('A')!.style?.fillColor, 0xFFABCDEF);
      expect(diagram.getNode('F')!.style?.fillColor, 0xFFEEEEEE);
      expect(diagram.edges.any((edge) => edge.invisible), isTrue);
      final mixed = diagram.edges.firstWhere(
        (edge) => edge.from == 'D' && edge.to == 'E',
      );
      expect(mixed.sourceArrowType, ArrowType.circle);
      expect(mixed.arrowType, ArrowType.cross);
      final explicit = diagram.edges.where((edge) => edge.id == 'edgeA');
      expect(explicit, hasLength(1));
      expect(explicit.single.from, 'Y');
      expect(explicit.single.to, 'Z');
      expect(explicit.single.animated, isTrue);
      expect(diagram.edges[0].interpolate, 'cardinal');
      expect(diagram.edges[1].interpolate, 'cardinal');
    },
  );

  test('applies every official Sequence renderer parameter', () {
    const source = '''---
title: Configured sequence
config:
  sequence:
    arrowMarkerAbsolute: true
    hideUnusedParticipants: true
    activationWidth: 14
    diagramMarginX: 22
    diagramMarginY: 17
    actorMargin: 31
    width: 132
    height: 58
    boxMargin: 12
    boxTextMargin: 7
    noteMargin: 9
    messageMargin: 41
    messageAlign: right
    mirrorActors: false
    forceMenus: true
    bottomMarginAdj: 4
    useMaxWidth: false
    rightAngles: true
    showSequenceNumbers: true
    actorFontSize: 13px
    actorFontFamily: Inter
    actorFontWeight: 600
    noteFontSize: 12
    noteFontFamily: Georgia
    noteFontWeight: bold
    noteAlign: left
    messageFontSize: 15px
    messageFontFamily: Mono
    messageFontWeight: 500
    wrap: true
    wrapPadding: 11
    labelBoxWidth: 61
    labelBoxHeight: 24
---
sequenceDiagram
  participant A as Alice
  participant B as Bob
  participant C as Unused
  A->>B: A deliberately long wrapped message
  activate B
  Note right of B: Active worker
  deactivate B
''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    final diagram = result!.diagram;
    final data = result.sequenceChartData!;
    final config = data.config;
    expect(diagram.title, 'Configured sequence');
    expect(diagram.nodes.map((node) => node.id), ['A', 'B']);
    expect(data.participants.map((participant) => participant.id), ['A', 'B']);
    expect(config.arrowMarkerAbsolute, isTrue);
    expect(config.hideUnusedParticipants, isTrue);
    expect(config.activationWidth, 14);
    expect(config.diagramMarginX, 22);
    expect(config.diagramMarginY, 17);
    expect(config.actorMargin, 31);
    expect(config.width, 132);
    expect(config.height, 58);
    expect(config.boxMargin, 12);
    expect(config.boxTextMargin, 7);
    expect(config.noteMargin, 9);
    expect(config.messageMargin, 41);
    expect(config.messageAlign, SequenceTextAlign.right);
    expect(config.mirrorActors, isFalse);
    expect(config.forceMenus, isTrue);
    expect(config.bottomMarginAdjustment, 4);
    expect(config.useMaxWidth, isFalse);
    expect(config.rightAngles, isTrue);
    expect(config.showSequenceNumbers, isTrue);
    expect(config.actorFontSize, 13);
    expect(config.actorFontFamily, 'Inter');
    expect(config.actorFontWeight, '600');
    expect(config.noteFontSize, 12);
    expect(config.noteFontFamily, 'Georgia');
    expect(config.noteFontWeight, 'bold');
    expect(config.noteAlign, SequenceTextAlign.left);
    expect(config.messageFontSize, 15);
    expect(config.messageFontFamily, 'Mono');
    expect(config.messageFontWeight, '500');
    expect(config.wrap, isTrue);
    expect(config.wrapPadding, 11);
    expect(config.labelBoxWidth, 61);
    expect(config.labelBoxHeight, 24);
    expect(diagram.sequenceConfig, same(config));

    final size = const SequenceLayout().computeLayout(
      diagram,
      MermaidThemes.light,
      const Size(900, 700),
    );
    expect(diagram.nodes.first.x, 22);
    expect(diagram.nodes.first.y, 17);
    expect(diagram.nodes.first.width, 132);
    expect(diagram.nodes.first.height, 58);
    final recorder = PictureRecorder();
    SequencePainter(
      diagram: diagram,
      style: MermaidThemes.light,
      sequenceData: data,
    ).paint(Canvas(recorder), size);
    recorder.endRecording();
  });

  test('projects and paints every official Sequence participant kind', () {
    const source = '''sequenceDiagram
participant P as Participant
actor A as Actor
participant B@{type: 'boundary', alias: 'Boundary'}
participant C@{"type":"control","alias":"Control"}
participant E@{"type":"entity","alias":"Entity"}
participant D@{"type":"database","alias":"Database"}
participant S@{"type":"collections","alias":"Collections"}
participant Q@{"type":"queue","alias":"Queue"}
properties B: {"class":"external-api","icon":"@clock","priority":2}
details B: boundary-details
P->>A: one
A->>B: two
B->>C: three
C->>E: four
E->>D: five
D->>S: six
S->>Q: seven
''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    final diagram = result!.diagram;
    expect(
      diagram.nodes.cast<SequenceParticipant>().map(
        (node) => node.participantType,
      ),
      ParticipantType.values,
    );
    final boundary = result.sequenceChartData!.participants.firstWhere(
      (participant) => participant.id == 'B',
    );
    expect(boundary.label, 'Boundary');
    expect(boundary.cssClass, 'external-api');
    expect(boundary.icon, '@clock');
    expect(boundary.properties['priority'], 2);
    expect(boundary.detailsReference, 'boundary-details');
    expect(diagram.getNode('B')!.className, 'external-api');
    final size = const SequenceLayout().computeLayout(
      diagram,
      MermaidThemes.light,
      const Size(1800, 900),
    );
    final recorder = PictureRecorder();
    SequencePainter(
      diagram: diagram,
      style: MermaidThemes.light,
      sequenceData: result.sequenceChartData,
    ).paint(Canvas(recorder), size);
    recorder.endRecording();
  });

  test('applies every Railroad setting across all four grammar dialects', () {
    const source = '''---
title: Native grammar
config:
  railroad:
    compactMode: true
    padding: 12
    verticalSeparation: 9
    horizontalSeparation: 11
    arcRadius: 13
    fontSize: 16
    fontFamily: Courier
    terminalFill: '#111111'
    terminalStroke: '#222222'
    terminalTextColor: '#333333'
    nonTerminalFill: '#444444'
    nonTerminalStroke: '#555555'
    nonTerminalTextColor: '#666666'
    lineColor: '#777777'
    strokeWidth: 3
    markerFill: '#888888'
    commentFill: '#999999'
    commentStroke: '#aaaaaa'
    commentTextColor: '#bbbbbb'
    specialFill: '#cccccc'
    specialStroke: '#dddddd'
    ruleNameColor: '#eeeeee'
    showMarkers: false
    markerRadius: 7
    useMaxWidth: false
---
railroad-beta
accTitle: Accessible grammar
accDescr {
Grammar tracks
drawn natively
}
/* official block comment */
expression = sequence(nonterminal("term"), zeroOrMore(choice(terminal("+"), special("operator")))) ;''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    final data = result!.railroadChartData!;
    expect(data.title, 'Native grammar');
    expect(data.accessibilityTitle, 'Accessible grammar');
    expect(data.accessibilityDescription, 'Grammar tracks\ndrawn natively');
    expect(data.compactMode, isTrue);
    expect(data.padding, 12);
    expect(data.verticalSeparation, 9);
    expect(data.horizontalSeparation, 11);
    expect(data.arcRadius, 13);
    expect(data.fontSize, 16);
    expect(data.fontFamily, 'Courier');
    expect(data.terminalFill, '#111111');
    expect(data.terminalStroke, '#222222');
    expect(data.terminalTextColor, '#333333');
    expect(data.nonTerminalFill, '#444444');
    expect(data.nonTerminalStroke, '#555555');
    expect(data.nonTerminalTextColor, '#666666');
    expect(data.lineColor, '#777777');
    expect(data.strokeWidth, 3);
    expect(data.markerFill, '#888888');
    expect(data.commentFill, '#999999');
    expect(data.commentStroke, '#aaaaaa');
    expect(data.commentTextColor, '#bbbbbb');
    expect(data.specialFill, '#cccccc');
    expect(data.specialStroke, '#dddddd');
    expect(data.ruleNameColor, '#eeeeee');
    expect(data.showMarkers, isFalse);
    expect(data.markerRadius, 7);
    expect(data.useMaxWidth, isFalse);
    final size = const RailroadChartLayout().computeLayout(
      data,
      const Size(800, 500),
    );
    expect(size.width, lessThan(800));
    final recorder = PictureRecorder();
    RailroadPainter(
      data: data,
      style: const MermaidStyle(),
    ).paint(Canvas(recorder), size);
    recorder.endRecording();

    const dialects = {
      'railroad-ebnf-beta\nrule = [ "a" ] , { "b" } , ? special ? ;':
          RailroadDialect.ebnf,
      'railroad-abnf-beta\nrule = 1*3%x41 / [ other-rule ] ;':
          RailroadDialect.abnf,
      'railroad-peg-beta\nrule <- !"x" ("a" / other)+ . ;': RailroadDialect.peg,
    };
    for (final entry in dialects.entries) {
      final parsed = const MermaidParser().parseWithData(entry.key);
      expect(parsed, isNotNull, reason: entry.key);
      expect(parsed!.railroadChartData!.dialect, entry.value);
      final recorder = PictureRecorder();
      RailroadPainter(
        data: parsed.railroadChartData!,
        style: const MermaidStyle(),
      ).paint(Canvas(recorder), const Size(700, 300));
      recorder.endRecording();
    }
    final empty = const MermaidParser().parseWithData(
      'railroad-beta\ntitle "Empty Grammar"',
    );
    expect(empty, isNotNull);
    expect(empty!.railroadChartData!.title, 'Empty Grammar');
    expect(empty.railroadChartData!.rules, isEmpty);
  });

  test('preserves nested Block grids, arrows, spans, config, and painting', () {
    const source = '''---
title: System blocks
config:
  block:
    padding: 14
    useMaxWidth: false
---
block
accTitle: Accessible blocks
accDescr {
Nested native
block grid
}
columns 2
start([Start])
block:services["Services"]
  columns 2
  api["API"]
  block
    columns 1
    db[(Database)]
    cache[[Cache]]
  end
end
fan<[""]>(up, down, left, right, x, y):2
space
finish(((Done)))
start --> api
api -- "stores" --> db
classDef hot fill:#ff0000,color:#ffffff
class api hot
style cache stroke:#333,stroke-width:3px''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    final data = result!.blockChartData!;
    expect(data.title, 'System blocks');
    expect(data.accessibilityTitle, 'Accessible blocks');
    expect(data.accessibilityDescription, 'Nested native\nblock grid');
    expect(data.columns, 2);
    expect(data.padding, 14);
    expect(data.useMaxWidth, isFalse);
    expect(data.groups, hasLength(2));
    final services = data.groups.firstWhere((group) => group.id == 'services');
    expect(services.label, 'Services');
    expect(services.columns, 2);
    final anonymous = data.groups.firstWhere(
      (group) => group.id.startsWith('__block_'),
    );
    expect(anonymous.parent, 'services');
    expect(anonymous.columns, 1);
    expect(data.placements.firstWhere((item) => item.nodeId == 'fan').span, 2);
    expect(data.arrows.single.directions, [
      'up',
      'down',
      'left',
      'right',
      'x',
      'y',
    ]);
    expect(result.diagram.edges, hasLength(2));
    expect(result.diagram.subgraphs, hasLength(2));
    final size = const BlockChartLayout().computeLayout(
      result.diagram,
      data,
      const MermaidStyle(),
      const Size(900, 700),
    );
    expect(size.width, lessThan(900));
    expect(result.diagram.getNode('db')!.y, isNot(0));
    expect(result.diagram.getNode('cache')!.y, isNot(0));
    final recorder = PictureRecorder();
    BlockPainter(
      diagram: result.diagram,
      data: data,
      style: const MermaidStyle(),
    ).paint(Canvas(recorder), size);
    recorder.endRecording();
  });

  test('executes complete Event Modeling config, theme, and semantics', () {
    const source = '''---
title: Order lifecycle
config:
  eventmodeling:
    padding: 17
    rowHeight: 84
    useMaxWidth: false
  themeVariables:
    emUiFill: '#111111'
    emUiStroke: '#222222'
    emProcessorFill: '#333333'
    emProcessorStroke: '#444444'
    emReadModelFill: '#555555'
    emReadModelStroke: '#666666'
    emCommandFill: '#777777'
    emCommandStroke: '#888888'
    emEventFill: '#999999'
    emEventStroke: '#aaaaaa'
    emRelationStroke: '#bbbbbb'
    emSwimlaneBackgroundOdd: '#cccccc'
    emSwimlaneBackgroundStroke: '#dddddd'
    emArrowhead: '#eeeeee'
    textColor: '#fafafa'
---
eventmodeling
accTitle: Accessible order model
accDescr {Native event model}
/* an official hidden comment */
entity Shop.Page
entity Shop.Automation
entity Sales.AddOrder
entity Sales.OrderAdded
entity Sales.Orders
data payload `json`
{
  "orderId": 7
}
tf 01 ui Shop.Page
tf 02 pcr Shop.Automation ->> 01
tf 03 cmd Sales.AddOrder ->> 02 [[payload]]
tf 04 evt Sales.OrderAdded ->> 03 { "orderId": 7 }
rf 05 rmo Sales.Orders ->> 04
note 04 `md`
{
  Event persisted
}
gwt 05 given ui Shop.Page
  when command Sales.AddOrder
  then event Sales.OrderAdded''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    final data = result!.eventModelingChartData!;
    expect(data.title, 'Order lifecycle');
    expect(data.accessibilityTitle, 'Accessible order model');
    expect(data.accessibilityDescription, 'Native event model');
    expect(data.padding, 17);
    expect(data.rowHeight, 84);
    expect(data.useMaxWidth, isFalse);
    expect(data.frames.map((frame) => frame.entityType).toSet(), {
      ...EventModelingEntityType.values,
    });
    expect(data.entities, hasLength(5));
    expect(data.frames.last.isReset, isTrue);
    expect(data.frames[2].dataReference, 'payload');
    expect(data.frames[3].inlineData, '{ "orderId": 7 }');
    expect(data.notes.single.frameId, '04');
    expect(data.scenarios.single.frameId, '05');
    expect(data.theme.uiFill, '#111111');
    expect(data.theme.processorFill, '#333333');
    expect(data.theme.readModelFill, '#555555');
    expect(data.theme.commandFill, '#777777');
    expect(data.theme.eventFill, '#999999');
    expect(data.theme.relationStroke, '#bbbbbb');
    expect(data.theme.swimlaneBackgroundOdd, '#cccccc');
    expect(data.theme.arrowhead, '#eeeeee');
    final size = const EventModelingChartLayout().computeLayout(
      result.diagram,
      data,
      const MermaidStyle(),
      const Size(1200, 800),
    );
    expect(size.width, lessThan(1200));
    final recorder = PictureRecorder();
    EventModelingPainter(
      diagram: result.diagram,
      data: data,
      style: const MermaidStyle(),
    ).paint(Canvas(recorder), size);
    recorder.endRecording();
    final empty = const MermaidParser().parseWithData(
      'eventmodeling\ntitle Empty event model\n// comment',
    );
    expect(empty, isNotNull);
    expect(empty!.eventModelingChartData!.frames, isEmpty);
  });

  test(
    'executes complete Architecture grammar, config, layout, and painting',
    () {
      const source = '''---
title: Cloud system
config:
  architecture:
    useMaxWidth: false
    padding: 24
    iconSize: 64
    fontSize: 15
    randomize: true
    nodeSeparation: 110
    idealEdgeLengthMultiplier: 2
    edgeElasticity: 0.6
    numIter: 180
    seed: 42
  themeVariables:
    archEdgeColor: '#123456'
    archEdgeArrowColor: '#234567'
    archEdgeWidth: 3px
    archGroupBorderColor: '#345678'
    archGroupBorderWidth: 2px
---
architecture-beta
accTitle: Accessible cloud architecture
accDescr {
Native compound architecture
}
group cloud(cloud)[Cloud]
group data(database)[Data] in cloud
service api(server)[API] in cloud
service db(database)[Database] in data
service custom "logos:dart"[Worker] in cloud
junction route in cloud
api:R --> L:custom
custom:B -[routes]- T:route
route{group}:R <--> L:db{group}
align row api custom route''';
      final result = const MermaidParser().parseWithData(source);
      expect(result, isNotNull);
      final data = result!.architectureChartData!;
      expect(data.title, 'Cloud system');
      expect(data.accessibilityTitle, 'Accessible cloud architecture');
      expect(data.accessibilityDescription, 'Native compound architecture');
      expect(data.groups, hasLength(2));
      expect(data.groups.last.parentId, 'cloud');
      expect(
        data.items.lastWhere((item) => item.id == 'custom').icon,
        'logos:dart',
      );
      expect(data.useMaxWidth, isFalse);
      expect(data.padding, 24);
      expect(data.iconSize, 64);
      expect(data.fontSize, 15);
      expect(data.randomize, isTrue);
      expect(data.nodeSeparation, 110);
      expect(data.idealEdgeLengthMultiplier, 2);
      expect(data.edgeElasticity, .6);
      expect(data.numIter, 180);
      expect(data.seed, 42);
      expect(data.edgeColor, '#123456');
      expect(data.edgeArrowColor, '#234567');
      expect(data.edgeWidth, 3);
      expect(data.groupBorderColor, '#345678');
      expect(data.groupBorderWidth, 2);
      expect(data.edges.last.fromGroup, isTrue);
      expect(data.edges.last.arrowAtStart, isTrue);
      expect(data.edges.last.arrowAtEnd, isTrue);
      final size = const ArchitectureChartLayout().computeLayout(
        result.diagram,
        data,
        const MermaidStyle(),
        const Size(1200, 800),
      );
      expect(size.width, lessThan(1200));
      final aligned = [
        'api',
        'custom',
        'route',
      ].map((id) => result.diagram.getNode(id)!.y).toSet();
      expect(aligned, hasLength(1));
      final recorder = PictureRecorder();
      ArchitecturePainter(
        diagram: result.diagram,
        data: data,
        style: const MermaidStyle(),
      ).paint(Canvas(recorder), size);
      recorder.endRecording();
      final darkRecorder = PictureRecorder();
      ArchitecturePainter(
        diagram: result.diagram,
        data: data,
        style: MermaidStyle.dark(),
      ).paint(Canvas(darkRecorder), size);
      darkRecorder.endRecording();

      final empty = const MermaidParser().parseWithData('architecture-beta');
      expect(empty, isNotNull);
      expect(empty!.architectureChartData!.items, isEmpty);
      expect(
        const MermaidParser().parseWithData(
          'architecture-beta\nservice a(server)[A]\nalign row a a',
        ),
        isNull,
      );
      expect(
        const MermaidParser().parseWithData(
          'architecture-beta\nservice row(server)[Reserved]',
        ),
        isNull,
      );
    },
  );

  test('preserves and paints complete C4 semantics and renderer config', () {
    const source = r'''---
title: Native C4
config:
  c4:
    useMaxWidth: false
    diagramMarginX: 18
    diagramMarginY: 12
    c4ShapeMargin: 24
    c4ShapePadding: 10
    width: 180
    height: 70
    boxMargin: 9
    c4ShapeInRow: 3
    c4BoundaryInRow: 1
    nextLinePaddingX: 15
    wrap: true
    wrapPadding: 7
    personFontSize: 17
    personFontFamily: Inter
    personFontWeight: 600
    person_bg_color: '#123456'
    person_border_color: '#234567'
    messageFontSize: 13
---
C4Deployment
direction LR
accTitle: Accessible C4
accDescr {
Complete native C4
}
Deployment_Node(cloud, "Cloud", "AWS", "Region")
{
  Person(user, "Customer", "Uses the system", "person-sprite", "human", $link="https://example.com")
  ContainerDb(db, "Database", "PostgreSQL", "Stores data", "db-sprite", "data")
  Node_R(runtime, "Runtime", "Linux", "Host") {
    ComponentQueue(queue, "Events", "Kafka", "Streams events")
  }
}
Rel_R(user, db, "Reads", "SQL", "Query relation")
RelIndex(2, db, queue, "Publishes", "Kafka")
BiRel(queue, user, "Notifies")
UpdateElementStyle(user, $bgColor="#345678", $fontColor="#ffffff", $borderColor="#456789", $shadowing="true", $shape="rounded", $sprite="custom", $techn="Browser")
UpdateRelStyle(user, db, $textColor="#567890", $lineColor="#678901", $offsetX="8", $offsetY="-4")
UpdateLayoutConfig($c4ShapeInRow="2", $c4BoundaryInRow="1")''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    final data = result!.c4ChartData!;
    expect(data.kind, C4DiagramKind.deployment);
    expect(data.title, 'Native C4');
    expect(data.accessibilityTitle, 'Accessible C4');
    expect(data.accessibilityDescription, 'Complete native C4');
    expect(data.direction, 'LR');
    expect(data.boundaries, hasLength(2));
    expect(data.boundaries.last.parentBoundaryId, 'cloud');
    expect(data.elements, hasLength(3));
    final user = data.elements.firstWhere((element) => element.id == 'user');
    expect(user.stereotype, 'person');
    expect(user.description, 'Uses the system');
    expect(user.sprite, 'person-sprite');
    expect(user.tags, 'human');
    expect(user.link, 'https://example.com');
    expect(user.style.backgroundColor, '#345678');
    expect(user.style.shadowing, isTrue);
    expect(user.style.shape, 'rounded');
    expect(data.relations, hasLength(3));
    expect(data.relations.first.direction, C4RelationDirection.right);
    expect(data.relations.first.textColor, '#567890');
    expect(data.relations.first.offsetX, 8);
    expect(data.relations[1].index, 2);
    expect(data.relations.last.bidirectional, isTrue);
    expect(data.shapesPerRow, 2);
    expect(data.boundariesPerRow, 1);
    expect(data.setting('personFontSize'), 17);
    expect(data.setting('person_bg_color'), '#123456');
    final size = const C4ChartLayout().computeLayout(
      result.diagram,
      data,
      const MermaidStyle(),
      const Size(1200, 800),
    );
    expect(size.width, lessThan(1200));
    final recorder = PictureRecorder();
    C4Painter(
      diagram: result.diagram,
      data: data,
      style: const MermaidStyle(),
    ).paint(Canvas(recorder), size);
    recorder.endRecording();
    final darkRecorder = PictureRecorder();
    C4Painter(
      diagram: result.diagram,
      data: data,
      style: MermaidStyle.dark(),
    ).paint(Canvas(darkRecorder), size);
    darkRecorder.endRecording();
  });

  test('executes complete Swimlane configuration and native lane layout', () {
    const source = '''---
title: Support handoff
config:
  flowchart:
    diagramPadding: 14
    nodeSpacing: 62
    rankSpacing: 74
    curve: linear
    wrappingWidth: 170
  swimlane:
    useMaxWidth: false
    lineHops: gap
    ignoreCrossLaneEdges: false
    optimizeRanksByCrossings: true
    automaticLaneOrdering: true
---
swimlane-beta LR
accTitle: Accessible support workflow
accDescr {
Cross-team handoff
}
subgraph customer [Customer]
  request[Open request]
  receive[Receive update]
end
subgraph support [Support]
  triage{Known issue?}
  answer[Send answer]
end
subgraph engineering [Engineering]
  investigate[Investigate]
  fix[Prepare fix]
end
request --> triage
triage -->|Yes| answer --> receive
triage -->|No| investigate --> fix --> answer''';
    final result = const MermaidParser().parseWithData(source);
    expect(result, isNotNull);
    final data = result!.swimlaneData!;
    expect(data.title, 'Support handoff');
    expect(data.accessibilityTitle, 'Accessible support workflow');
    expect(data.accessibilityDescription, 'Cross-team handoff');
    expect(data.laneIds, ['customer', 'support', 'engineering']);
    expect(data.lineHops, SwimlaneLineHops.gap);
    expect(data.ignoreCrossLaneEdges, isFalse);
    expect(data.optimizeRanksByCrossings, isTrue);
    expect(data.automaticLaneOrdering, isTrue);
    expect(data.useMaxWidth, isFalse);
    expect(result.diagram.flowchartConfig!.diagramPadding, 14);
    expect(result.diagram.flowchartConfig!.rankSpacing, 74);
    final size = const SwimlaneChartLayout().computeLayout(
      result.diagram,
      data,
      const MermaidStyle(),
      const Size(2000, 800),
    );
    expect(size.width, lessThan(2000));
    expect(
      result.diagram.getNode('request')!.y,
      isNot(result.diagram.getNode('triage')!.y),
    );
    final recorder = PictureRecorder();
    SwimlanePainter(
      diagram: result.diagram,
      data: data,
      style: const MermaidStyle(),
    ).paint(Canvas(recorder), size);
    recorder.endRecording();
    for (final hops in [true, 'arc', false]) {
      final parsed = const MermaidParser().parseWithData('''---
config:
  swimlane:
    lineHops: $hops
---
swimlane-beta TB
subgraph A
  one[One]
end
subgraph B
  two[Two]
end
one --> two''');
      expect(parsed, isNotNull);
      final expected = hops == false
          ? SwimlaneLineHops.none
          : SwimlaneLineHops.arc;
      expect(parsed!.swimlaneData!.lineHops, expected);
      const SwimlaneChartLayout().computeLayout(
        parsed.diagram,
        parsed.swimlaneData!,
        const MermaidStyle(),
        const Size(600, 500),
      );
      final darkRecorder = PictureRecorder();
      SwimlanePainter(
        diagram: parsed.diagram,
        data: parsed.swimlaneData!,
        style: MermaidStyle.dark(),
      ).paint(Canvas(darkRecorder), const Size(600, 500));
      darkRecorder.endRecording();
    }
    final bare = const MermaidParser().parseWithData(
      'swimlane-beta TD; A[Start] --> B[Finish];',
    );
    expect(bare, isNotNull);
    expect(bare!.diagram.subgraphs, isEmpty);
    expect(bare.diagram.nodes, hasLength(2));
    const SwimlaneChartLayout().computeLayout(
      bare.diagram,
      bare.swimlaneData!,
      const MermaidStyle(),
      const Size(600, 400),
    );
    expect(
      bare.diagram.getNode('B')!.y,
      greaterThan(bare.diagram.getNode('A')!.y),
    );
  });
}
