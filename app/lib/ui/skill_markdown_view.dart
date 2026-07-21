/*
 * [INPUT]: Depends on flutter_markdown_plus, Material 3 ThemeData, url_launcher, SkillsGo typography tokens, and shared bidirectional-content detection.
 * [OUTPUT]: Provides the single theme-aware, direction-aware, selectable, link-safe Markdown reader used by every Skill document surface.
 * [POS]: Serves as the App UI boundary around third-party Markdown parsing and rendering.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'brand.dart';
import 'bidirectional_content.dart';

class SkillMarkdownView extends StatelessWidget {
  const SkillMarkdownView({
    super.key,
    required this.data,
    this.padding = EdgeInsets.zero,
    this.scrollable = true,
    this.maxHeight,
    this.stripFrontMatter = false,
    this.presentation = SkillMarkdownPresentation.document,
  });

  final String data;
  final EdgeInsets padding;
  final bool scrollable;
  final double? maxHeight;
  final bool stripFrontMatter;
  final SkillMarkdownPresentation presentation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final markdown = stripFrontMatter ? withoutYamlFrontMatter(data) : data;
    final markdownDirection = contentTextDirection(markdown);
    if (!scrollable) {
      final body = Padding(
        padding: padding,
        child: MarkdownBody(
          data: markdown,
          selectable: true,
          styleSheet: buildSkillMarkdownStyleSheet(
            theme,
            presentation: presentation,
            textDirection: markdownDirection,
          ),
          onTapLink: (_, href, _) => _openExternalLink(href),
        ),
      );
      if (maxHeight == null) {
        return Directionality(textDirection: markdownDirection, child: body);
      }
      return SizedBox(
        height: maxHeight,
        child: Directionality(
          textDirection: contentTextDirection(markdown),
          child: Markdown(
            data: markdown,
            selectable: true,
            padding: padding,
            physics: const ClampingScrollPhysics(),
            styleSheet: buildSkillMarkdownStyleSheet(
              theme,
              presentation: presentation,
              textDirection: markdownDirection,
            ),
            onTapLink: (_, href, _) => _openExternalLink(href),
          ),
        ),
      );
    }
    return Directionality(
      textDirection: markdownDirection,
      child: Markdown(
        data: markdown,
        selectable: true,
        padding: padding,
        styleSheet: buildSkillMarkdownStyleSheet(
          theme,
          presentation: presentation,
          textDirection: markdownDirection,
        ),
        onTapLink: (_, href, _) => _openExternalLink(href),
      ),
    );
  }
}

enum SkillMarkdownPresentation { document, summary }

String withoutYamlFrontMatter(String markdown) {
  final normalized = markdown.startsWith('\uFEFF')
      ? markdown.substring(1)
      : markdown;
  final lines = normalized.split('\n');
  if (lines.isEmpty || lines.first.trim() != '---') return markdown;
  for (var index = 1; index < lines.length; index++) {
    if (lines[index].trim() != '---') continue;
    return lines.skip(index + 1).join('\n').trimLeft();
  }
  return markdown;
}

MarkdownStyleSheet buildSkillMarkdownStyleSheet(
  ThemeData theme, {
  SkillMarkdownPresentation presentation = SkillMarkdownPresentation.document,
  TextDirection textDirection = TextDirection.ltr,
}) {
  final scheme = theme.colorScheme;
  final typography = theme.extension<SkillsTypography>()!;
  final isSummary = presentation == SkillMarkdownPresentation.summary;
  final body = typography.body.copyWith(
    color: isSummary ? scheme.onSurfaceVariant : scheme.onSurface,
    fontSize: isSummary ? 15 : 16,
    height: isSummary ? 1.42 : 1.55,
  );
  TextStyle heading(double size, FontWeight weight) =>
      typography.sectionTitle.copyWith(
        color: scheme.onSurface,
        fontSize: size,
        height: 1.2,
        fontWeight: weight,
        letterSpacing: -.2,
      );
  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    a: body.copyWith(
      color: scheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: scheme.primary.withValues(alpha: .55),
    ),
    p: body,
    pPadding: EdgeInsets.only(bottom: isSummary ? 0 : 10),
    h1: heading(26, FontWeight.w700),
    h1Padding: const EdgeInsets.fromLTRB(0, 8, 0, 18),
    h2: heading(22, FontWeight.w600),
    h2Padding: const EdgeInsets.fromLTRB(0, 28, 0, 12),
    h3: heading(18, FontWeight.w600),
    h3Padding: const EdgeInsets.fromLTRB(0, 22, 0, 10),
    h4: heading(16, FontWeight.w600),
    h4Padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
    h5: heading(15, FontWeight.w600),
    h5Padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
    h6: heading(14, FontWeight.w600).copyWith(color: scheme.onSurfaceVariant),
    h6Padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
    em: body.copyWith(fontStyle: FontStyle.italic),
    strong: body.copyWith(fontWeight: FontWeight.w700),
    del: body.copyWith(
      color: scheme.onSurfaceVariant,
      decoration: TextDecoration.lineThrough,
    ),
    code: typography.code.copyWith(
      color: scheme.onSurface,
      backgroundColor: scheme.surfaceContainerHighest,
      fontSize: 13,
      height: 1.45,
    ),
    blockquote: body.copyWith(color: scheme.onSurfaceVariant),
    blockquotePadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    blockquoteDecoration: BoxDecoration(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(10),
      border: BorderDirectional(
        start: BorderSide(color: scheme.primary, width: 3),
      ),
    ),
    codeblockPadding: const EdgeInsets.all(14),
    codeblockDecoration: BoxDecoration(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
    ),
    listBullet: body.copyWith(color: scheme.primary),
    listIndent: 24,
    listBulletPadding: textDirection == TextDirection.rtl
        ? const EdgeInsets.only(left: 8)
        : const EdgeInsets.only(right: 8),
    tableHead: body.copyWith(fontWeight: FontWeight.w700),
    tableBody: body.copyWith(fontSize: 14),
    tableBorder: TableBorder.all(color: scheme.outlineVariant),
    tableCellsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    tableCellsDecoration: BoxDecoration(color: scheme.surfaceContainerLow),
    tableHeadCellsDecoration: BoxDecoration(color: scheme.surfaceContainerHigh),
    tableScrollbarThumbVisibility: true,
    horizontalRuleDecoration: BoxDecoration(
      border: Border(top: BorderSide(color: scheme.outlineVariant)),
    ),
    blockSpacing: 12,
  );
}

Future<void> _openExternalLink(String? href) async {
  final uri = href == null ? null : Uri.tryParse(href);
  if (uri == null || !const {'https', 'http', 'mailto'}.contains(uri.scheme)) {
    return;
  }
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
