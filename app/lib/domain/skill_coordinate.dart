/*
 * [INPUT]: Depends on canonical Package Path and Skill Name strings supplied by trusted CLI machine documents.
 * [OUTPUT]: Provides value equality and a collision-safe internal key for one Package member coordinate.
 * [POS]: Serves as the shared App domain identity used across discovery, installation, Library, and update models.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
final class SkillCoordinate {
  const SkillCoordinate({required this.packagePath, required this.name});

  final String packagePath;
  final String name;

  String get key => '$packagePath\u0000$name';

  @override
  bool operator ==(Object other) =>
      other is SkillCoordinate &&
      other.packagePath == packagePath &&
      other.name == name;

  @override
  int get hashCode => Object.hash(packagePath, name);
}
