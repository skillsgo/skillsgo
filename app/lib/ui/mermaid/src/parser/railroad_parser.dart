/*
 * [INPUT]: Depends on Mermaid 11.16.0 Railroad, ISO EBNF, ABNF, and PEG grammar definitions plus the unified native Railroad AST.
 * [OUTPUT]: Parses all four headers, rule assignments, sequences, choices, grouping, optional/repetition operators, terminals, nonterminals, specials, ABNF ranges, and PEG predicates.
 * [POS]: Serves as the shared recursive-descent parser for Mermaid's Railroad diagram family.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import '../models/diagram.dart';
import '../models/railroad.dart';

class RailroadDiagramParser {
  const RailroadDiagramParser();

  (MermaidDiagramData, RailroadChartData)? parse(List<String> lines) {
    if (lines.isEmpty) return null;
    final dialect = switch (lines.first.trim().toLowerCase()) {
      'railroad-beta' => RailroadDialect.railroad,
      'railroad-ebnf-beta' => RailroadDialect.ebnf,
      'railroad-abnf-beta' => RailroadDialect.abnf,
      'railroad-peg-beta' => RailroadDialect.peg,
      _ => null,
    };
    if (dialect == null) return null;
    String? title;
    String? accessibilityTitle;
    String? accessibilityDescription;
    final accessibilityLines = <String>[];
    var readingAccessibility = false;
    final source = StringBuffer();
    final body = lines
        .skip(1)
        .join('\n')
        .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
        .split('\n');
    for (final raw in body) {
      final line = raw.trim();
      if (readingAccessibility) {
        if (line == '}') {
          accessibilityDescription = accessibilityLines.join('\n').trim();
          readingAccessibility = false;
        } else {
          accessibilityLines.add(line);
        }
        continue;
      }
      if (line.startsWith('title ')) {
        final value = line.substring(6).trim();
        title = _isQuoted(value) ? _unquote(value) : value;
      } else if (line.startsWith('accTitle:')) {
        accessibilityTitle = line.substring('accTitle:'.length).trim();
      } else if (line.startsWith('accDescr:')) {
        accessibilityDescription = line.substring('accDescr:'.length).trim();
      } else if (RegExp(
        r'^accDescr\s*\{$',
        caseSensitive: false,
      ).hasMatch(line)) {
        readingAccessibility = true;
      } else if (!line.startsWith('accDescr')) {
        source.writeln(line);
      }
    }
    if (readingAccessibility) return null;
    final statements = _splitRules(source.toString());
    if (statements.isEmpty && source.toString().trim().isNotEmpty) return null;
    final rules = <RailroadRuleData>[];
    for (final statement in statements) {
      final assignment = dialect == RailroadDialect.peg
          ? RegExp(r'^([A-Za-z_][\w-]*)\s*<-\s*(.+)$', dotAll: true)
          : RegExp(r'^([A-Za-z_][\w-]*)\s*(?:::)?=\s*(.+)$', dotAll: true);
      final match = assignment.firstMatch(statement.trim());
      if (match == null) return null;
      final tokens = _tokenize(match.group(2)!);
      if (tokens == null || tokens.isEmpty) return null;
      final reader = _TokenReader(tokens);
      final expression = switch (dialect) {
        RailroadDialect.railroad => _parseExplicit(reader),
        RailroadDialect.ebnf => _parseEbnfChoice(reader),
        RailroadDialect.abnf => _parseAbnfChoice(reader),
        RailroadDialect.peg => _parsePegChoice(reader),
      };
      if (expression == null || !reader.isDone) return null;
      rules.add(
        RailroadRuleData(name: match.group(1)!, definition: expression),
      );
    }
    return (
      MermaidDiagramData(
        type: DiagramType.railroad,
        nodes: const [],
        edges: const [],
        title: title,
      ),
      RailroadChartData(
        dialect: dialect,
        rules: rules,
        title: title,
        accessibilityTitle: accessibilityTitle,
        accessibilityDescription: accessibilityDescription,
      ),
    );
  }

  List<String> _splitRules(String source) {
    final result = <String>[];
    final buffer = StringBuffer();
    String? quote;
    for (var index = 0; index < source.length; index++) {
      final char = source[index];
      if ((char == '"' || char == "'") &&
          (index == 0 || source[index - 1] != r'\')) {
        quote = quote == null ? char : (quote == char ? null : quote);
      }
      if (char == ';' && quote == null) {
        if (buffer.toString().trim().isNotEmpty) result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    if (buffer.toString().trim().isNotEmpty) return const [];
    return result;
  }

  List<String>? _tokenize(String source) {
    final tokens = <String>[];
    for (var index = 0; index < source.length;) {
      final char = source[index];
      if (RegExp(r'\s').hasMatch(char)) {
        index++;
        continue;
      }
      if (char == '"' || char == "'") {
        final quote = char;
        final start = index++;
        while (index < source.length && source[index] != quote) {
          if (source[index] == r'\' && index + 1 < source.length) index++;
          index++;
        }
        if (index >= source.length) return null;
        tokens.add(source.substring(start, ++index));
        continue;
      }
      final primaryPosition =
          tokens.isEmpty ||
          const {'(', '[', '{', ',', '|'}.contains(tokens.last);
      if (char == '?' && primaryPosition) {
        final end = source.indexOf('?', index + 1);
        if (end > index + 1) {
          tokens.add(source.substring(index, end + 1));
          index = end + 1;
          continue;
        }
      }
      final operator = RegExp(
        r'^(::=|<-|[()\[\]{},|/*+?&!.-])',
      ).firstMatch(source.substring(index));
      if (operator != null) {
        tokens.add(operator.group(1)!);
        index += operator.group(1)!.length;
        continue;
      }
      final value = RegExp(
        r'^(?:%[xXdDbB][0-9A-Fa-f]+(?:-[0-9A-Fa-f]+|\.[0-9A-Fa-f]+)*|[0-9]*\*[0-9]*|[0-9]+|[A-Za-z_][\w-]*)',
      ).firstMatch(source.substring(index));
      if (value == null || value.group(0)!.isEmpty) return null;
      tokens.add(value.group(0)!);
      index += value.group(0)!.length;
    }
    return tokens;
  }

  RailroadExpression? _parseExplicit(_TokenReader reader) {
    final name = reader.take();
    if (name == null || !reader.consume('(')) return null;
    if (name == 'terminal' || name == 'nonterminal' || name == 'special') {
      final value = reader.take();
      if (value == null || !_isQuoted(value) || !reader.consume(')')) {
        return null;
      }
      return RailroadExpression(
        kind: name == 'terminal'
            ? RailroadExpressionKind.terminal
            : name == 'nonterminal'
            ? RailroadExpressionKind.nonTerminal
            : RailroadExpressionKind.special,
        text: _unquote(value),
      );
    }
    final children = <RailroadExpression>[];
    do {
      final child = _parseExplicit(reader);
      if (child == null) return null;
      children.add(child);
    } while (reader.consume(','));
    if (!reader.consume(')')) return null;
    return switch (name) {
      'sequence' => _sequence(children),
      'choice' => _choice(children),
      'optional' when children.length == 1 => RailroadExpression(
        kind: RailroadExpressionKind.optional,
        children: children,
      ),
      'oneOrMore' when children.length == 1 => RailroadExpression(
        kind: RailroadExpressionKind.repetition,
        children: children,
        min: 1,
      ),
      'zeroOrMore' when children.length == 1 => RailroadExpression(
        kind: RailroadExpressionKind.repetition,
        children: children,
        min: 0,
      ),
      _ => null,
    };
  }

  RailroadExpression? _parseEbnfChoice(_TokenReader reader, [String? stop]) {
    final alternatives = <RailroadExpression>[];
    do {
      final sequence = _parseEbnfSequence(reader, stop);
      if (sequence == null) return null;
      alternatives.add(sequence);
    } while (reader.consume('|'));
    return _choice(alternatives);
  }

  RailroadExpression? _parseEbnfSequence(_TokenReader reader, String? stop) {
    final elements = <RailroadExpression>[];
    while (!reader.isDone && reader.peek != stop && reader.peek != '|') {
      reader.consume(',');
      if (reader.peek == stop || reader.peek == '|') break;
      final parsedTerm = _parseEbnfPrimary(reader);
      if (parsedTerm == null) return null;
      RailroadExpression term = parsedTerm;
      while (true) {
        if (reader.consume('?')) {
          term = RailroadExpression(
            kind: RailroadExpressionKind.optional,
            children: [term],
          );
        } else if (reader.consume('*')) {
          term = RailroadExpression(
            kind: RailroadExpressionKind.repetition,
            children: [term],
            min: 0,
          );
        } else if (reader.consume('+')) {
          term = RailroadExpression(
            kind: RailroadExpressionKind.repetition,
            children: [term],
            min: 1,
          );
        } else if (reader.consume('-')) {
          final except = _parseEbnfPrimary(reader);
          if (except == null) return null;
          term = RailroadExpression(
            kind: RailroadExpressionKind.special,
            text: 'except',
            children: [term, except],
          );
        } else {
          break;
        }
      }
      elements.add(term);
    }
    return elements.isEmpty ? null : _sequence(elements);
  }

  RailroadExpression? _parseEbnfPrimary(_TokenReader reader) {
    final token = reader.take();
    if (token == null) return null;
    if (_isQuoted(token)) {
      return RailroadExpression(
        kind: RailroadExpressionKind.terminal,
        text: _unquote(token),
      );
    }
    if (token.startsWith('?') && token.endsWith('?')) {
      return RailroadExpression(
        kind: RailroadExpressionKind.special,
        text: token.substring(1, token.length - 1).trim(),
      );
    }
    final close = switch (token) {
      '(' => ')',
      '[' => ']',
      '{' => '}',
      _ => null,
    };
    if (close != null) {
      final value = _parseEbnfChoice(reader, close);
      if (value == null || !reader.consume(close)) return null;
      return switch (token) {
        '[' => RailroadExpression(
          kind: RailroadExpressionKind.optional,
          children: [value],
        ),
        '{' => RailroadExpression(
          kind: RailroadExpressionKind.repetition,
          children: [value],
          min: 0,
        ),
        _ => value,
      };
    }
    return _identifier(token);
  }

  RailroadExpression? _parseAbnfChoice(_TokenReader reader, [String? stop]) {
    final alternatives = <RailroadExpression>[];
    do {
      final elements = <RailroadExpression>[];
      while (!reader.isDone && reader.peek != stop && reader.peek != '/') {
        final repeat = RegExp(r'^(?:\d+|\d*\*\d*)$').hasMatch(reader.peek ?? '')
            ? reader.take()
            : null;
        var primary = _parseAbnfPrimary(reader);
        if (primary == null) return null;
        if (repeat != null) {
          final bounds = repeat.contains('*')
              ? repeat.split('*')
              : [repeat, repeat];
          primary = RailroadExpression(
            kind: RailroadExpressionKind.repetition,
            children: [primary],
            min: int.tryParse(bounds[0]) ?? 0,
            max: int.tryParse(bounds[1]),
          );
        }
        elements.add(primary);
      }
      if (elements.isEmpty) return null;
      alternatives.add(_sequence(elements));
    } while (reader.consume('/'));
    return _choice(alternatives);
  }

  RailroadExpression? _parseAbnfPrimary(_TokenReader reader) {
    final token = reader.take();
    if (token == null) return null;
    if (_isQuoted(token) || token.startsWith('%')) {
      return RailroadExpression(
        kind: RailroadExpressionKind.terminal,
        text: _isQuoted(token) ? _unquote(token) : token,
      );
    }
    if (token == '(' || token == '[') {
      final close = token == '(' ? ')' : ']';
      final value = _parseAbnfChoice(reader, close);
      if (value == null || !reader.consume(close)) return null;
      return token == '['
          ? RailroadExpression(
              kind: RailroadExpressionKind.optional,
              children: [value],
            )
          : value;
    }
    return _identifier(token);
  }

  RailroadExpression? _parsePegChoice(_TokenReader reader, [String? stop]) {
    final alternatives = <RailroadExpression>[];
    do {
      final elements = <RailroadExpression>[];
      while (!reader.isDone && reader.peek != stop && reader.peek != '/') {
        final predicate = reader.peek == '&' || reader.peek == '!'
            ? reader.take()
            : null;
        final parsedPrimary = _parsePegPrimary(reader);
        if (parsedPrimary == null) return null;
        RailroadExpression primary = parsedPrimary;
        final suffix =
            reader.peek == '?' || reader.peek == '*' || reader.peek == '+'
            ? reader.take()
            : null;
        if (suffix == '?') {
          primary = RailroadExpression(
            kind: RailroadExpressionKind.optional,
            children: [primary],
          );
        }
        if (suffix == '*' || suffix == '+') {
          primary = RailroadExpression(
            kind: RailroadExpressionKind.repetition,
            children: [primary],
            min: suffix == '+' ? 1 : 0,
          );
        }
        if (predicate != null) {
          primary = RailroadExpression(
            kind: RailroadExpressionKind.predicate,
            text: predicate,
            children: [primary],
          );
        }
        elements.add(primary);
      }
      if (elements.isEmpty) return null;
      alternatives.add(_sequence(elements));
    } while (reader.consume('/'));
    return _choice(alternatives);
  }

  RailroadExpression? _parsePegPrimary(_TokenReader reader) {
    final token = reader.take();
    if (token == null) return null;
    if (_isQuoted(token)) {
      return RailroadExpression(
        kind: RailroadExpressionKind.terminal,
        text: _unquote(token),
      );
    }
    if (token == '.') {
      return const RailroadExpression(
        kind: RailroadExpressionKind.special,
        text: 'any',
      );
    }
    if (token == '(') {
      final value = _parsePegChoice(reader, ')');
      if (value == null || !reader.consume(')')) return null;
      return value;
    }
    return _identifier(token);
  }

  RailroadExpression _identifier(String token) =>
      RailroadExpression(kind: RailroadExpressionKind.nonTerminal, text: token);
  RailroadExpression _sequence(List<RailroadExpression> nodes) =>
      nodes.length == 1
      ? nodes.single
      : RailroadExpression(
          kind: RailroadExpressionKind.sequence,
          children: nodes,
        );
  RailroadExpression _choice(List<RailroadExpression> nodes) =>
      nodes.length == 1
      ? nodes.single
      : RailroadExpression(
          kind: RailroadExpressionKind.choice,
          children: nodes,
        );
  bool _isQuoted(String token) =>
      token.length >= 2 &&
      ((token.startsWith('"') && token.endsWith('"')) ||
          (token.startsWith("'") && token.endsWith("'")));
  String _unquote(String token) => token
      .substring(1, token.length - 1)
      .replaceAll(r'\"', '"')
      .replaceAll(r"\'", "'")
      .replaceAll(r'\\', r'\');
}

class _TokenReader {
  _TokenReader(this.tokens);
  final List<String> tokens;
  var index = 0;
  bool get isDone => index >= tokens.length;
  String? get peek => isDone ? null : tokens[index];
  String? take() => isDone ? null : tokens[index++];
  bool consume(String value) {
    if (peek != value) return false;
    index++;
    return true;
  }
}
