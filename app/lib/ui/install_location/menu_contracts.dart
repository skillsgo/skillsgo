/*
 * [INPUT]: Depends on Installation target selections, Agent catalogs, Added Projects, repository members, and async submission outcomes.
 * [OUTPUT]: Provides the public menu request with exact existing-target exclusions, action, choice, presenter, and submission contracts.
 * [POS]: Serves as the small external interface of the anchored Installation Request selector.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../install_location_popover.dart';

class InstallLocationMenuRequest {
  const InstallLocationMenuRequest({
    required this.gateway,
    required this.catalog,
    required this.detail,
    required this.projects,
    required this.onProjectAdded,
    this.repositorySkills = const [],
    this.repositorySkillsFuture,
    this.preferredAction = InstallLocationAction.currentSkill,
    this.existingTargets = const [],
  }) : summary = null,
       loader = null;

  const InstallLocationMenuRequest.loading({
    required this.summary,
    required this.loader,
  }) : gateway = null,
       catalog = null,
       detail = null,
       projects = null,
       onProjectAdded = null,
       repositorySkills = null,
       repositorySkillsFuture = null,
       preferredAction = InstallLocationAction.currentSkill,
       existingTargets = null;

  final SkillsGateway? gateway;
  final AgentCatalog? catalog;
  final SkillDetail? detail;
  final List<AddedProject>? projects;
  final ValueChanged<AddedProject>? onProjectAdded;
  final List<SkillSummary>? repositorySkills;
  final Future<List<SkillSummary>>? repositorySkillsFuture;
  final InstallLocationAction preferredAction;
  final List<SkillInstallationTarget>? existingTargets;
  final SkillSummary? summary;
  final Future<InstallLocationMenuRequest> Function()? loader;

  bool get isLoading => loader != null;
}

enum InstallLocationAction { currentSkill, repositorySkills }

class InstallLocationChoice {
  const InstallLocationChoice({required this.selections, required this.action});

  final List<InstallationTargetSelection> selections;
  final InstallLocationAction action;
}

typedef InstallLocationMenuPresenter =
    Future<bool?> Function(
      InstallLocationMenuRequest request,
      Future<InstallLocationSubmission> Function(InstallLocationChoice choice)
      submit,
    );

class InstallLocationSubmission {
  const InstallLocationSubmission.success() : title = null, message = null;

  const InstallLocationSubmission.failure({
    required this.title,
    required this.message,
  });

  final String? title;
  final String? message;

  bool get succeeded => title == null;
}
