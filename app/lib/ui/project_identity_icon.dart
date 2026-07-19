/*
 * [INPUT]: Depends on AddedProject icon metadata, Flutter file image rendering, flutter_svg, and SkillsGo semantic color tokens.
 * [OUTPUT]: Provides a compact project identity that preserves geometry with a deterministic monogram while local icons load or fail to decode.
 * [POS]: Serves as the shared visual identity for Added Projects across Library and installation selection surfaces.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as p;

import '../domain/skills_gateway.dart';
import 'design_system/skills_color_tokens.dart';

class ProjectIdentityIcon extends StatelessWidget {
  const ProjectIdentityIcon({super.key, required this.project, this.size = 20});

  final AddedProject project;
  final double size;

  @override
  Widget build(BuildContext context) {
    final icon = project.icon;
    if (icon != null) {
      final image = p.extension(icon.path).toLowerCase() == '.svg'
          ? SvgPicture.file(
              File(icon.path),
              width: size,
              height: size,
              fit: BoxFit.contain,
              placeholderBuilder: (_) => _fallback(context),
            )
          : Image.file(
              File(icon.path),
              key: ValueKey('project-icon-image-${project.id}'),
              width: size,
              height: size,
              fit: BoxFit.contain,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
                  wasSynchronouslyLoaded || frame != null
                  ? child
                  : _fallback(context),
              errorBuilder: (_, _, _) => _fallback(context),
            );
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * .24),
        child: SizedBox.square(dimension: size, child: image),
      );
    }
    return _fallback(context);
  }

  Widget _fallback(BuildContext context) {
    final colors = context.skillsColors;
    return Container(
      key: ValueKey('project-icon-placeholder-${project.id}'),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(size * .24),
        border: Border.all(color: colors.borderMuted),
      ),
      child: Text(
        projectInitials(project.name),
        maxLines: 1,
        style: TextStyle(
          color: colors.foregroundDefault,
          fontSize: size * .38,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

String projectInitials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'[\s_-]+'))
      .where((word) => word.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) return '?';
  if (words.length > 1) {
    return '${words.first.characters.first}${words.last.characters.first}'
        .toUpperCase();
  }
  return words.single.characters.take(2).toString().toUpperCase();
}
