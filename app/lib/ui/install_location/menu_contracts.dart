/*
 * [INPUT]: Depends on Installation target selections, Agent catalogs, Added Projects, Package members, and async submission outcomes.
 * [OUTPUT]: Provides the public menu request with uniform install intent, action, choice, presenter, and submission contracts.
 * [POS]: Serves as the small external interface of the anchored Installation Request selector.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../install_location_popover.dart';

class InstallLocationMenuRequest {
  const InstallLocationMenuRequest({
    required this.summary,
    required this.gateway,
    required this.catalog,
    required this.detail,
    required this.projects,
    required this.onProjectAdded,
    this.moduleSkills = const [],
    this.moduleSkillsFuture,
    this.preferredAction = InstallLocationAction.currentSkill,
  }) : loader = null;

  const InstallLocationMenuRequest.loading({
    required this.summary,
    required this.loader,
  }) : gateway = null,
       catalog = null,
       detail = null,
       projects = null,
       onProjectAdded = null,
       moduleSkills = null,
       moduleSkillsFuture = null,
       preferredAction = InstallLocationAction.currentSkill;

  final SkillsGateway? gateway;
  final AgentCatalog? catalog;
  final SkillDetail? detail;
  final List<AddedProject>? projects;
  final ValueChanged<AddedProject>? onProjectAdded;
  final List<SkillSummary>? moduleSkills;
  final Future<List<SkillSummary>>? moduleSkillsFuture;
  final InstallLocationAction preferredAction;
  final SkillSummary? summary;
  final Future<InstallLocationMenuRequest> Function()? loader;

  bool get isLoading => loader != null;
}

enum InstallLocationAction { currentSkill, moduleSkills }

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
  const InstallLocationSubmission.success()
    : title = null,
      message = null,
      cancelled = false;

  const InstallLocationSubmission.cancelled()
    : title = null,
      message = null,
      cancelled = true;

  const InstallLocationSubmission.failure({
    required this.title,
    required this.message,
  }) : cancelled = false;

  final String? title;
  final String? message;
  final bool cancelled;

  bool get succeeded => title == null && !cancelled;
}
