/*
 * [INPUT]: Uses the Library description-similarity policy with multilingual short-text fixtures.
 * [OUTPUT]: Specifies exact, reordered, edited, CJK, cross-script, empty, and deterministic similarity behavior.
 * [POS]: Serves as the focused unit contract for Adoption candidate presentation ordering.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/ui/library/description_similarity.dart';

void main() {
  test('identical descriptions have full similarity', () {
    final result = compareDescriptions(
      'Compact the current conversation into a handoff document.',
      'Compact the current conversation into a handoff document.',
    );
    expect(result.comparable, isTrue);
    expect(result.score, 1);
  });

  test('word reordering and added context remain strongly similar', () {
    final result = compareDescriptions(
      'Compact the current conversation into a handoff document.',
      'Create a handoff document by compacting the current conversation for another agent.',
    );
    expect(result.comparable, isTrue);
    expect(result.score, greaterThan(.45));
  });

  test('edited CJK descriptions retain lexical similarity', () {
    final result = compareDescriptions(
      '将当前对话压缩为交接文档，供另一个代理继续。',
      '将本次对话整理成交接文档，交给其他代理继续处理。',
    );
    expect(result.comparable, isTrue);
    expect(result.score, greaterThan(.2));
  });

  test('different dominant scripts are explicitly incomparable', () {
    final result = compareDescriptions(
      'Compact the current conversation into a handoff document.',
      '将当前对话压缩为交接文档，供另一个代理继续。',
    );
    expect(result.comparable, isFalse);
    expect(result.score, 0);
  });

  test('empty descriptions are explicitly incomparable', () {
    expect(compareDescriptions('', 'Some description').comparable, isFalse);
  });

  test('full-width Latin forms normalize deterministically', () {
    final result = compareDescriptions('ＡＳＫ ＭＡＴＴ', 'ask matt');
    expect(result.comparable, isTrue);
    expect(result.score, 1);
  });
}
