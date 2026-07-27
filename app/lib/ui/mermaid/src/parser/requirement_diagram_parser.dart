/*
 * [INPUT]: Depends on Mermaid 11.16.0 requirementDiagram grammar and native requirement plus shared graph models.
 * [OUTPUT]: Strictly parses requirements, elements, relationships, directions, directives, classes, shorthand classes, and direct styles.
 * [POS]: Serves as the lossless native parser for requirementDiagram and rejects unknown statements instead of dropping semantics.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import '../models/diagram.dart';
import '../models/edge.dart';
import '../models/node.dart';
import '../models/requirement_diagram.dart';

class NativeRequirementDiagramParser {
  const NativeRequirementDiagramParser();

  (MermaidDiagramData, RequirementDiagramData)? parse(List<String> lines) {
    final header = lines.indexWhere((line) => line.trim().isNotEmpty);
    if (header < 0 ||
        lines[header].trim().toLowerCase() != 'requirementdiagram') {
      return null;
    }
    final requirements = <String, RequirementData>{};
    final elements = <String, RequirementElementData>{};
    final relationships = <RequirementRelationshipData>[];
    final classDefinitions = <String, String>{};
    var direction = DiagramDirection.topToBottom;
    String? title;
    String? accessibilityTitle;
    String? accessibilityDescription;

    var index = header + 1;
    while (index < lines.length) {
      var line = lines[index].trim().replaceFirst(RegExp(r';\s*$'), '');
      index++;
      if (line.isEmpty ||
          line == '---' ||
          line.startsWith('#') ||
          line.startsWith('%%')) {
        continue;
      }
      final lower = line.toLowerCase();
      if (lower.startsWith('direction ')) {
        final parsed = _direction(line.substring(10));
        if (parsed == null) return null;
        direction = parsed;
        continue;
      }
      if (lower.startsWith('title ')) {
        title = line.substring(6).trim();
        continue;
      }
      if (lower.startsWith('acctitle:')) {
        accessibilityTitle = line.substring(line.indexOf(':') + 1).trim();
        continue;
      }
      if (lower.startsWith('accdescr:')) {
        accessibilityDescription = line.substring(line.indexOf(':') + 1).trim();
        continue;
      }
      final inlineAccDescr = RegExp(
        r'^accDescr\s*\{(.*)\}\s*$',
        caseSensitive: false,
      ).firstMatch(line);
      if (inlineAccDescr != null) {
        accessibilityDescription = inlineAccDescr.group(1)!.trim();
        continue;
      }
      if (RegExp(r'^accDescr\s*\{$', caseSensitive: false).hasMatch(line)) {
        final values = <String>[];
        var closed = false;
        while (index < lines.length) {
          final value = lines[index++].trim();
          if (value == '}') {
            closed = true;
            break;
          }
          values.add(value);
        }
        if (!closed) return null;
        accessibilityDescription = values.join('\n').trim();
        continue;
      }

      final declaration = RegExp(
        r'^(requirement|functionalRequirement|interfaceRequirement|performanceRequirement|physicalRequirement|designConstraint|element)\s+("[^"]*"|[^\s:{]+)(?:\s*:::\s*([\w,-]+))?\s*\{$',
        caseSensitive: false,
      ).firstMatch(line);
      if (declaration != null) {
        final keyword = declaration.group(1)!;
        final name = _unquote(declaration.group(2)!);
        if (requirements.containsKey(name) || elements.containsKey(name)) {
          return null;
        }
        final fields = <String, String>{};
        var closed = false;
        while (index < lines.length) {
          line = lines[index++].trim().replaceFirst(RegExp(r';\s*$'), '');
          if (line.isEmpty || line.startsWith('#') || line.startsWith('%%')) {
            continue;
          }
          if (line == '}') {
            closed = true;
            break;
          }
          final field = RegExp(
            r'^(id|text|risk|verifyMethod|type|docref)\s*:\s*(.+)$',
            caseSensitive: false,
          ).firstMatch(line);
          if (field == null) return null;
          fields[field.group(1)!.toLowerCase()] = _unquote(
            field.group(2)!.trim(),
          );
        }
        if (!closed) return null;
        final classes = ['default', ...?declaration.group(3)?.split(',')];
        if (keyword.toLowerCase() == 'element') {
          if (fields.keys.any((key) => key != 'type' && key != 'docref')) {
            return null;
          }
          elements[name] = RequirementElementData(
            name: name,
            type: fields['type'] ?? '',
            documentReference: fields['docref'] ?? '',
            cssClasses: classes,
          );
        } else {
          if (fields.keys.any(
            (key) =>
                !const {'id', 'text', 'risk', 'verifymethod'}.contains(key),
          )) {
            return null;
          }
          final risk = _risk(fields['risk']);
          final verification = _verification(fields['verifymethod']);
          if ((fields.containsKey('risk') && risk == null) ||
              (fields.containsKey('verifymethod') && verification == null)) {
            return null;
          }
          requirements[name] = RequirementData(
            name: name,
            kind: _kind(keyword)!,
            requirementId: fields['id'] ?? '',
            text: fields['text'] ?? '',
            risk: risk,
            verificationMethod: verification,
            cssClasses: classes,
          );
        }
        continue;
      }

      final relation = RegExp(
        r'^("[^"]*"|[^\s]+)\s*(?:-\s*(contains|copies|derives|satisfies|verifies|refines|traces)\s*->|<-\s*(contains|copies|derives|satisfies|verifies|refines|traces)\s*-)\s*("[^"]*"|[^\s]+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (relation != null) {
        final left = _unquote(relation.group(1)!);
        final right = _unquote(relation.group(4)!);
        final reversed = relation.group(3) != null;
        relationships.add(
          RequirementRelationshipData(
            from: reversed ? right : left,
            to: reversed ? left : right,
            kind: _relationship(relation.group(2) ?? relation.group(3)!)!,
            usedLeftArrowSyntax: reversed,
          ),
        );
        continue;
      }
      final classDef = RegExp(
        r'^classDef\s+([^\s]+)\s+(.+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (classDef != null) {
        for (final name in classDef.group(1)!.split(',')) {
          classDefinitions[name] = classDef.group(2)!;
        }
        continue;
      }
      final style = RegExp(
        r'^style\s+([^\s]+)\s+(.+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (style != null) {
        for (final name in style.group(1)!.split(',')) {
          if (!_setStyle(name, style.group(2)!, requirements, elements)) {
            return null;
          }
        }
        continue;
      }
      final classStatement = RegExp(
        r'^class\s+([^\s]+)\s+([^\s]+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (classStatement != null) {
        final classes = classStatement.group(2)!.split(',');
        for (final name in classStatement.group(1)!.split(',')) {
          if (!_addClasses(name, classes, requirements, elements)) return null;
        }
        continue;
      }
      final shorthand = RegExp(
        r'^("[^"]*"|[^\s:]+)\s*:::\s*([\w,-]+)$',
      ).firstMatch(line);
      if (shorthand != null &&
          _addClasses(
            _unquote(shorthand.group(1)!),
            shorthand.group(2)!.split(','),
            requirements,
            elements,
          )) {
        continue;
      }
      return null;
    }

    if (requirements.isEmpty && elements.isEmpty) return null;
    final known = {...requirements.keys, ...elements.keys};
    if (relationships.any(
      (relation) =>
          !known.contains(relation.from) || !known.contains(relation.to),
    )) {
      return null;
    }
    final nodes = <MermaidNode>[
      for (final item in requirements.values)
        MermaidNode(
          id: item.name,
          label: [
            _kindLabel(item.kind),
            item.name,
            if (item.requirementId.isNotEmpty) 'id: ${item.requirementId}',
            if (item.text.isNotEmpty) 'text: ${item.text}',
            if (item.risk != null) 'risk: ${item.risk!.name}',
            if (item.verificationMethod != null)
              'verifyMethod: ${item.verificationMethod!.name}',
          ].join('\n'),
          className: item.cssClasses.join(' '),
          style: _resolvedStyle(
            item.cssClasses,
            item.rawStyle,
            classDefinitions,
          ),
        ),
      for (final item in elements.values)
        MermaidNode(
          id: item.name,
          label: [
            'Element',
            item.name,
            if (item.type.isNotEmpty) 'type: ${item.type}',
            if (item.documentReference.isNotEmpty)
              'docRef: ${item.documentReference}',
          ].join('\n'),
          shape: NodeShape.roundedRect,
          className: item.cssClasses.join(' '),
          style: _resolvedStyle(
            item.cssClasses,
            item.rawStyle,
            classDefinitions,
          ),
        ),
    ];
    return (
      MermaidDiagramData(
        type: DiagramType.requirementDiagram,
        nodes: nodes,
        edges: [
          for (final relation in relationships)
            MermaidEdge(
              from: relation.from,
              to: relation.to,
              label: relation.kind.name,
            ),
        ],
        direction: direction,
        title: title,
      ),
      RequirementDiagramData(
        requirements: requirements.values.toList(),
        elements: elements.values.toList(),
        relationships: relationships,
        classDefinitions: classDefinitions,
        title: title,
        accessibilityTitle: accessibilityTitle,
        accessibilityDescription: accessibilityDescription,
      ),
    );
  }

  bool _setStyle(
    String name,
    String style,
    Map<String, RequirementData> requirements,
    Map<String, RequirementElementData> elements,
  ) {
    if (requirements[name] case final RequirementData value) {
      requirements[name] = value.copyWith(rawStyle: style);
      return true;
    }
    if (elements[name] case final RequirementElementData value) {
      elements[name] = value.copyWith(rawStyle: style);
      return true;
    }
    return false;
  }

  bool _addClasses(
    String name,
    List<String> classes,
    Map<String, RequirementData> requirements,
    Map<String, RequirementElementData> elements,
  ) {
    if (requirements[name] case final RequirementData value) {
      requirements[name] = value.copyWith(
        cssClasses: {...value.cssClasses, ...classes}.toList(),
      );
      return true;
    }
    if (elements[name] case final RequirementElementData value) {
      elements[name] = value.copyWith(
        cssClasses: {...value.cssClasses, ...classes}.toList(),
      );
      return true;
    }
    return false;
  }

  RequirementKind? _kind(String value) => switch (value.toLowerCase()) {
    'requirement' => RequirementKind.requirement,
    'functionalrequirement' => RequirementKind.functionalRequirement,
    'interfacerequirement' => RequirementKind.interfaceRequirement,
    'performancerequirement' => RequirementKind.performanceRequirement,
    'physicalrequirement' => RequirementKind.physicalRequirement,
    'designconstraint' => RequirementKind.designConstraint,
    _ => null,
  };
  String _kindLabel(RequirementKind kind) => switch (kind) {
    RequirementKind.requirement => 'Requirement',
    RequirementKind.functionalRequirement => 'Functional Requirement',
    RequirementKind.interfaceRequirement => 'Interface Requirement',
    RequirementKind.performanceRequirement => 'Performance Requirement',
    RequirementKind.physicalRequirement => 'Physical Requirement',
    RequirementKind.designConstraint => 'Design Constraint',
  };
  RequirementRisk? _risk(String? value) => switch (value?.toLowerCase()) {
    null => null,
    'low' => RequirementRisk.low,
    'medium' => RequirementRisk.medium,
    'high' => RequirementRisk.high,
    _ => null,
  };
  RequirementVerificationMethod? _verification(String? value) =>
      switch (value?.toLowerCase()) {
        null => null,
        'analysis' => RequirementVerificationMethod.analysis,
        'demonstration' => RequirementVerificationMethod.demonstration,
        'inspection' => RequirementVerificationMethod.inspection,
        'test' => RequirementVerificationMethod.test,
        _ => null,
      };
  RequirementRelationshipKind? _relationship(String value) =>
      switch (value.toLowerCase()) {
        'contains' => RequirementRelationshipKind.contains,
        'copies' => RequirementRelationshipKind.copies,
        'derives' => RequirementRelationshipKind.derives,
        'satisfies' => RequirementRelationshipKind.satisfies,
        'verifies' => RequirementRelationshipKind.verifies,
        'refines' => RequirementRelationshipKind.refines,
        'traces' => RequirementRelationshipKind.traces,
        _ => null,
      };
  DiagramDirection? _direction(String value) =>
      switch (value.trim().toUpperCase()) {
        'TB' => DiagramDirection.topToBottom,
        'BT' => DiagramDirection.bottomToTop,
        'LR' => DiagramDirection.leftToRight,
        'RL' => DiagramDirection.rightToLeft,
        _ => null,
      };
  String _unquote(String value) =>
      value.length >= 2 && value.startsWith('"') && value.endsWith('"')
      ? value.substring(1, value.length - 1)
      : value;

  NodeStyle? _resolvedStyle(
    List<String> classes,
    String? rawStyle,
    Map<String, String> definitions,
  ) {
    final sources = [
      for (final name in classes)
        if (definitions[name] case final String value) value,
      ?rawStyle,
    ];
    if (sources.isEmpty) return null;
    final values = <String, String>{};
    for (final source in sources) {
      for (final part in source.split(',')) {
        final separator = part.indexOf(':');
        if (separator > 0) {
          values[part.substring(0, separator).trim()] = part
              .substring(separator + 1)
              .trim();
        }
      }
    }
    return NodeStyle(
      fillColor: _color(values['fill']),
      strokeColor: _color(values['stroke']),
      textColor: _color(values['color']),
      strokeWidth:
          double.tryParse(
            values['stroke-width']?.replaceAll(RegExp(r'[^0-9.]'), '') ?? '',
          ) ??
          1,
    );
  }

  int? _color(String? value) {
    if (value == null || !value.startsWith('#')) return null;
    final hex = value.substring(1);
    final expanded = hex.length == 3
        ? hex.split('').map((item) => '$item$item').join()
        : hex;
    final parsed = int.tryParse(expanded, radix: 16);
    return parsed == null ? null : 0xFF000000 | parsed;
  }
}
