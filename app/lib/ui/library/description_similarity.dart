/*
 * [INPUT]: Depends only on Dart Unicode code points and short local/remote Skill descriptions.
 * [OUTPUT]: Provides deterministic multilingual-friendly lexical description similarity with explicit incomparable results.
 * [POS]: Serves as the Library Adoption candidate-ordering policy, separate from Source identity and user confirmation.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */

class DescriptionSimilarity {
  const DescriptionSimilarity._({
    required this.score,
    required this.comparable,
  });

  const DescriptionSimilarity.incomparable()
    : this._(score: 0, comparable: false);

  const DescriptionSimilarity.comparable(double score)
    : this._(score: score, comparable: true);

  final double score;
  final bool comparable;
}

DescriptionSimilarity compareDescriptions(String local, String remote) {
  final left = _normalizedCodePoints(local);
  final right = _normalizedCodePoints(remote);
  if (left.isEmpty || right.isEmpty) {
    return const DescriptionSimilarity.incomparable();
  }

  final leftScript = _dominantScript(left);
  final rightScript = _dominantScript(right);
  if (leftScript != null && rightScript != null && leftScript != rightScript) {
    return const DescriptionSimilarity.incomparable();
  }

  final characterScore = _setDice(_ngrams(left, 3), _ngrams(right, 3));
  final leftTerms = _terms(left);
  final rightTerms = _terms(right);
  final tokenDice = _setDice(leftTerms.toSet(), rightTerms.toSet());
  final tokenSet = _tokenSetRatio(leftTerms, rightTerms);
  final score = (.45 * characterScore + .35 * tokenSet + .20 * tokenDice).clamp(
    0.0,
    1.0,
  );
  return DescriptionSimilarity.comparable(score);
}

List<int> _normalizedCodePoints(String value) {
  final result = <int>[];
  var pendingSpace = false;
  for (var codePoint in value.trim().toLowerCase().runes) {
    if (codePoint == 0x3000) codePoint = 0x20;
    if (codePoint >= 0xFF01 && codePoint <= 0xFF5E) {
      codePoint -= 0xFEE0;
    }
    if (_isLetterOrNumber(codePoint)) {
      if (pendingSpace && result.isNotEmpty) result.add(0x20);
      result.add(codePoint);
      pendingSpace = false;
    } else {
      pendingSpace = true;
    }
  }
  return result;
}

Set<String> _ngrams(List<int> value, int requestedSize) {
  final compact = value.where((codePoint) => codePoint != 0x20).toList();
  if (compact.isEmpty) return const {};
  final size = compact.length < requestedSize ? compact.length : requestedSize;
  return {
    for (var index = 0; index <= compact.length - size; index++)
      String.fromCharCodes(compact.sublist(index, index + size)),
  };
}

List<String> _terms(List<int> value) => String.fromCharCodes(
  value,
).split(' ').where((term) => term.runes.length > 1).toSet().toList()..sort();

double _tokenSetRatio(List<String> left, List<String> right) {
  if (left.isEmpty || right.isEmpty) return 0;
  final leftSet = left.toSet();
  final rightSet = right.toSet();
  final intersection = leftSet.intersection(rightSet).toList()..sort();
  final leftRemainder = leftSet.difference(rightSet).toList()..sort();
  final rightRemainder = rightSet.difference(leftSet).toList()..sort();
  final common = intersection.join(' ');
  final leftCombined = [...intersection, ...leftRemainder].join(' ');
  final rightCombined = [...intersection, ...rightRemainder].join(' ');
  return [
    _sequenceRatio(common, leftCombined),
    _sequenceRatio(common, rightCombined),
    _sequenceRatio(leftCombined, rightCombined),
  ].reduce((best, value) => value > best ? value : best);
}

double _sequenceRatio(String left, String right) {
  final a = left.runes.toList();
  final b = right.runes.toList();
  if (a.isEmpty && b.isEmpty) return 1;
  final longest = a.length > b.length ? a.length : b.length;
  return 1 - (_levenshtein(a, b) / longest);
}

int _levenshtein(List<int> left, List<int> right) {
  var previous = List<int>.generate(right.length + 1, (index) => index);
  for (var leftIndex = 0; leftIndex < left.length; leftIndex++) {
    final current = List<int>.filled(right.length + 1, 0);
    current[0] = leftIndex + 1;
    for (var rightIndex = 0; rightIndex < right.length; rightIndex++) {
      final substitution =
          previous[rightIndex] + (left[leftIndex] == right[rightIndex] ? 0 : 1);
      final insertion = current[rightIndex] + 1;
      final deletion = previous[rightIndex + 1] + 1;
      current[rightIndex + 1] = [
        substitution,
        insertion,
        deletion,
      ].reduce((best, value) => value < best ? value : best);
    }
    previous = current;
  }
  return previous.last;
}

double _setDice(Set<String> left, Set<String> right) {
  if (left.isEmpty || right.isEmpty) return 0;
  return (2 * left.intersection(right).length) / (left.length + right.length);
}

enum _Script {
  latin,
  han,
  kana,
  hangul,
  cyrillic,
  greek,
  arabic,
  devanagari,
  thai,
}

_Script? _dominantScript(List<int> value) {
  final counts = <_Script, int>{};
  for (final codePoint in value) {
    final script = _scriptOf(codePoint);
    if (script != null) {
      counts.update(script, (count) => count + 1, ifAbsent: () => 1);
    }
  }
  if (counts.isEmpty) return null;
  return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

_Script? _scriptOf(int value) => switch (value) {
  >= 0x0041 && <= 0x024F => _Script.latin,
  >= 0x1E00 && <= 0x1EFF => _Script.latin,
  >= 0x3400 && <= 0x9FFF => _Script.han,
  >= 0xF900 && <= 0xFAFF => _Script.han,
  >= 0x3040 && <= 0x30FF => _Script.kana,
  >= 0xAC00 && <= 0xD7AF => _Script.hangul,
  >= 0x0400 && <= 0x052F => _Script.cyrillic,
  >= 0x0370 && <= 0x03FF => _Script.greek,
  >= 0x0600 && <= 0x06FF => _Script.arabic,
  >= 0x0900 && <= 0x097F => _Script.devanagari,
  >= 0x0E00 && <= 0x0E7F => _Script.thai,
  _ => null,
};

bool _isLetterOrNumber(int value) => RegExp(
  r'^[\p{L}\p{N}]$',
  unicode: true,
).hasMatch(String.fromCharCode(value));
