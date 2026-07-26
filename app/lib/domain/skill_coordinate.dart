/*
 * [INPUT]: Depends on canonical Module Path and Skill Name strings supplied by trusted CLI machine documents.
 * [OUTPUT]: Provides value equality and a collision-safe internal key for one Module member coordinate.
 * [POS]: Serves as the shared App domain identity used across discovery, installation, Library, and update models.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
final class SkillCoordinate {
  const SkillCoordinate({required this.modulePath, required this.name});

  final String modulePath;
  final String name;

  String get key => '$modulePath\u0000$name';

  @override
  bool operator ==(Object other) =>
      other is SkillCoordinate &&
      other.modulePath == modulePath &&
      other.name == name;

  @override
  int get hashCode => Object.hash(modulePath, name);
}
