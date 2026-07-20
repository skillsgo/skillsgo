/*
 * [INPUT]: Depends on menu requests, asynchronous Agent/Project/repository dependencies, failure copy, and location card rendering.
 * [OUTPUT]: Provides the independent loading, content, and recoverable error states for the installation selector.
 * [POS]: Serves as the async dependency owner of the anchored Installation Request selector.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../install_location_popover.dart';

class _AsyncInstallLocationCard extends StatefulWidget {
  const _AsyncInstallLocationCard({
    super.key,
    required this.summary,
    required this.loader,
    required this.onSubmit,
  });

  final SkillSummary summary;
  final Future<InstallLocationMenuRequest> Function() loader;
  final ValueChanged<InstallLocationChoice> onSubmit;

  @override
  State<_AsyncInstallLocationCard> createState() =>
      _AsyncInstallLocationCardState();
}

class _AsyncInstallLocationCardState extends State<_AsyncInstallLocationCard> {
  late Future<InstallLocationMenuRequest> request;

  @override
  void initState() {
    super.initState();
    request = widget.loader();
  }

  void retry() => setState(() => request = widget.loader());

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<InstallLocationMenuRequest>(
        future: request,
        builder: (context, snapshot) {
          final l10n = AppLocalizations.of(context);
          final ready = snapshot.data;
          if (ready != null) {
            return _InstallLocationCard(
              gateway: ready.gateway!,
              catalog: ready.catalog!,
              detail: ready.detail!,
              repositorySkills: ready.repositorySkills!,
              repositorySkillsFuture: ready.repositorySkillsFuture,
              preferredAction: ready.preferredAction,
              existingTargets: ready.existingTargets!,
              initialProjects: ready.projects!,
              onProjectAdded: ready.onProjectAdded!,
              onSubmit: widget.onSubmit,
            );
          }
          if (snapshot.hasError) {
            return SkillsCard(
              title: Text(l10n.installSkillTo(widget.summary.name)),
              description: Text(l10n.installationPlanFailed),
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: SkillsButton(onPressed: retry, child: Text(l10n.retry)),
              ),
            );
          }
          return Semantics(
            liveRegion: true,
            label: l10n.loading,
            child: SkillsCard(
              key: const ValueKey('install-location-skeleton'),
              title: Text(l10n.installSkillTo(widget.summary.name)),
              child: const Padding(
                padding: EdgeInsets.only(top: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkillsSkeletonBox(height: 18, width: 150),
                    SizedBox(height: 18),
                    SkillsSkeletonBox(height: 44, borderRadius: 12),
                    SizedBox(height: 14),
                    SkillsSkeletonBox(height: 18, width: 112),
                    SizedBox(height: 12),
                    SkillsSkeletonBox(height: 36),
                    SizedBox(height: 10),
                    SkillsSkeletonBox(height: 36),
                  ],
                ),
              ),
            ),
          );
        },
      );
}
