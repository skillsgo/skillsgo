/*
 * [INPUT]: Depends on text/focus controllers, search appearance, keyboard/focus semantics, HugeIcons, and SkillsGo component tokens.
 * [OUTPUT]: Provides the reusable capsule and leaderboard SkillSearchField with focus, hover, clear, submit, and reduced-motion behavior.
 * [POS]: Serves as the search-input segment of the SkillsGo brand library.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../brand.dart';

class SkillSearchField extends StatelessWidget {
  const SkillSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    this.onCleared,
    this.onChanged,
    this.active = false,
    this.loading = false,
    this.compact = false,
    this.showClearButton = true,
    this.height,
    this.appearance = SkillSearchAppearance.capsule,
    this.showShortcutHint = false,
    this.hintText,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;
  final VoidCallback? onCleared;
  final ValueChanged<String>? onChanged;
  final bool active;
  final bool loading;
  final bool compact;
  final bool showClearButton;
  final double? height;
  final SkillSearchAppearance appearance;
  final bool showShortcutHint;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final searchLabel = hintText ?? l10n.searchSkills;
    return Semantics(
      label: searchLabel,
      textField: true,
      child: SizedBox(
        key: const Key('skill-search'),
        height: height ?? (compact ? 44 : 52),
        child: AnimatedBuilder(
          animation: Listenable.merge([controller, focusNode]),
          builder: (context, _) {
            final scheme = Theme.of(context).colorScheme;
            final components = context.skillsComponents;
            final value = controller.value;
            if (appearance == SkillSearchAppearance.leaderboard) {
              const contentAlignment = skillSearchLeaderboardContentAlignment;
              final showSparkles =
                  value.text.contains(' ') && value.text.trim().length >= 2;
              final reduceMotion = MediaQuery.disableAnimationsOf(context);
              final animationDuration = MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 100);
              return AnimatedContainer(
                duration: animationDuration,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: focusNode.hasFocus
                          ? scheme.onSurface
                          : components.controlBorder,
                      width: 1,
                    ),
                  ),
                ),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: onChanged,
                  onSubmitted: onSubmitted,
                  textInputAction: TextInputAction.search,
                  textAlignVertical: const TextAlignVertical(
                    y: contentAlignment,
                  ),
                  cursorColor: scheme.onSurface,
                  style: context.skillsTypography.bodySecondary.copyWith(
                    color: scheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.only(bottom: 2),
                    prefixIconConstraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 45,
                    ),
                    prefixIcon: Align(
                      alignment: const Alignment(-1, contentAlignment),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedOpacity(
                            key: const Key('search-visual-icon'),
                            opacity: showSparkles ? 0 : 1,
                            duration: reduceMotion
                                ? Duration.zero
                                : const Duration(milliseconds: 200),
                            curve: const Cubic(0.4, 0, 0.2, 1),
                            child: SearchVisualIcon(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          AnimatedOpacity(
                            key: const Key('search-sparkles-icon'),
                            opacity: showSparkles ? 1 : 0,
                            duration: reduceMotion
                                ? Duration.zero
                                : const Duration(milliseconds: 200),
                            curve: const Cubic(0.4, 0, 0.2, 1),
                            child: SearchVisualIcon(
                              color: scheme.onSurfaceVariant,
                              sparkles: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    hintText: searchLabel,
                    hintStyle: context.skillsTypography.bodySecondary.copyWith(
                      color: scheme.textTertiary,
                    ),
                    suffixIconConstraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 45,
                    ),
                    suffixIcon: loading
                        ? const Align(
                            alignment: Alignment(0, contentAlignment),
                            child: SizedBox.square(
                              dimension: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.8,
                              ),
                            ),
                          )
                        : value.text.isNotEmpty && showClearButton
                        ? Align(
                            alignment: const Alignment(0, contentAlignment),
                            child: SizedBox.square(
                              dimension: 24,
                              child: IconButton(
                                key: const Key('skill-search-clear'),
                                tooltip: null,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 24,
                                  height: 24,
                                ),
                                style: ButtonStyle(
                                  minimumSize: const WidgetStatePropertyAll(
                                    Size.zero,
                                  ),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  backgroundColor:
                                      WidgetStateProperty.resolveWith((states) {
                                        if (states.contains(
                                          WidgetState.pressed,
                                        )) {
                                          return scheme.onSurface.withValues(
                                            alpha: 0.12,
                                          );
                                        }
                                        if (states.contains(
                                          WidgetState.hovered,
                                        )) {
                                          return scheme.onSurface.withValues(
                                            alpha: 0.08,
                                          );
                                        }
                                        return Colors.transparent;
                                      }),
                                  overlayColor: const WidgetStatePropertyAll(
                                    Colors.transparent,
                                  ),
                                  shape: WidgetStatePropertyAll(
                                    RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                                onPressed: () {
                                  controller.clear();
                                  onCleared?.call();
                                  focusNode.requestFocus();
                                },
                                icon: HugeIcon(
                                  icon: HugeIcons.strokeRoundedCancel01,
                                  size: 16,
                                  strokeWidth: 1.8,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          )
                        : showShortcutHint
                        ? Align(
                            alignment: const Alignment(0, contentAlignment),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.onSurface.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '⌘ F',
                                style: context.skillsTypography.metadata
                                    .copyWith(
                                      color: scheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.2,
                                      height: 1,
                                    ),
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
              );
            }
            final foreground = active
                ? scheme.onPrimaryContainer
                : scheme.onSurface;
            final secondary = active
                ? scheme.onPrimaryContainer.withValues(alpha: .72)
                : scheme.onSurfaceVariant;
            final radius = BorderRadius.circular(999);
            final border = OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(
                color: active ? Colors.transparent : components.controlBorder,
              ),
            );
            return AnimatedContainer(
              key: const Key('skill-search-surface'),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 160),
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: active
                    ? const [
                        BoxShadow(
                          color: Color(0x29000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ]
                    : const [],
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                textInputAction: TextInputAction.search,
                cursorColor: foreground,
                style: context.skillsTypography.body.copyWith(
                  color: foreground,
                  fontSize: compact ? 14 : 17,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: active
                      ? components.searchActive
                      : components.searchRest,
                  hintText: searchLabel,
                  hintStyle: context.skillsTypography.body.copyWith(
                    color: scheme.textTertiary,
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 42,
                    minHeight: 42,
                  ),
                  prefixIcon: SizedBox(
                    width: 42,
                    height: 42,
                    child: Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedSearch01,
                        size: 17,
                        strokeWidth: 1.5,
                        color: secondary,
                      ),
                    ),
                  ),
                  suffixIcon: loading
                      ? Padding(
                          padding: const EdgeInsets.all(13),
                          child: SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: secondary,
                            ),
                          ),
                        )
                      : value.text.isEmpty || !showClearButton
                      ? null
                      : IconButton(
                          key: const Key('skill-search-clear'),
                          tooltip: null,
                          onPressed: () {
                            controller.clear();
                            onCleared?.call();
                            focusNode.requestFocus();
                          },
                          icon: HugeIcon(
                            icon: HugeIcons.strokeRoundedCancel01,
                            size: 17,
                            strokeWidth: 1.8,
                            color: secondary,
                          ),
                        ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: compact ? 12 : 16,
                    vertical: 0,
                  ),
                  border: border,
                  enabledBorder: border,
                  focusedBorder: OutlineInputBorder(
                    borderRadius: radius,
                    borderSide: BorderSide(
                      color: active
                          ? components.focusRing
                          : components.controlBorder,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
