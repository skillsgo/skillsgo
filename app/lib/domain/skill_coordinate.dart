/*
 * [INPUT]: Depends on canonical Repository ID and Skill Name strings supplied by trusted CLI machine documents.
 * [OUTPUT]: Provides value equality and a collision-safe internal key for one Repository member coordinate.
 * [POS]: Serves as the shared App domain identity used across discovery, installation, Library, and update models.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
final class SkillCoordinate {
  const SkillCoordinate({required this.repositoryId, required this.name});

  final String repositoryId;
  final String name;

  String get key => '$repositoryId\u0000$name';

  @override
  bool operator ==(Object other) =>
      other is SkillCoordinate &&
      other.repositoryId == repositoryId &&
      other.name == name;

  @override
  int get hashCode => Object.hash(repositoryId, name);
}
