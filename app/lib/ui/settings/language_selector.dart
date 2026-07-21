/*
 * [INPUT]: Depends on Presentation Locale values, language identity icons, dropdown overlay primitives, keyboard focus, and localized labels.
 * [OUTPUT]: Provides the controlled single-select Presentation Locale field and accessible popup.
 * [POS]: Serves as the language-selection presentation segment of the Settings journey.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../settings_screen.dart';

class _LanguageSingleSelect extends StatefulWidget {
  const _LanguageSingleSelect({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final AppLanguage selected;
  final ValueChanged<AppLanguage> onChanged;

  @override
  State<_LanguageSingleSelect> createState() => _LanguageSingleSelectState();
}

class _LanguageSingleSelectState extends State<_LanguageSingleSelect> {
  final controller = MultiSelectController<AppLanguage>();
  bool syncing = false;

  String _label(AppLanguage language) => language == AppLanguage.system
      ? context.l10n.followSystem
      : language.nativeName!;

  List<DropdownItem<AppLanguage>> get items => [
    for (final language in AppLanguage.values)
      DropdownItem(
        label: _label(language),
        value: language,
        selected: language == widget.selected,
      ),
  ];

  @override
  void didUpdateWidget(covariant _LanguageSingleSelect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || controller.isDisposed) return;
        syncing = true;
        controller.setItems(items);
        syncing = false;
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.skillsColors;
    return Semantics(
      label: '${context.l10n.language}: ${_label(widget.selected)}',
      button: true,
      excludeSemantics: true,
      child: SizedBox(
        width: 232,
        height: 36,
        child: Stack(
          fit: StackFit.expand,
          children: [
            MultiDropdown<AppLanguage>(
              controller: controller,
              items: items,
              singleSelect: true,
              fieldDecoration: FieldDecoration(
                hintText: '',
                showClearIcon: false,
                animateSuffixIcon: false,
                padding: EdgeInsets.zero,
                backgroundColor: Colors.transparent,
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                suffixIcon: null,
              ),
              dropdownDecoration: DropdownDecoration(
                backgroundColor: colors.surfaceMuted,
                elevation: 5,
                maxHeight: 240,
                marginTop: 6,
                borderRadius: BorderRadius.circular(14),
                listPadding: const EdgeInsets.symmetric(vertical: 6),
                animationDuration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                animationCurve: Curves.easeOutCubic,
              ),
              itemBuilder: (item, index, onTap) => Semantics(
                label: item.label,
                button: true,
                selected: item.selected,
                child: ExcludeSemantics(
                  child: InkWell(
                    onTap: onTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      child: Row(
                        children: [
                          LanguageIdentityIcon(language: item.value, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          AnimatedOpacity(
                            opacity: item.selected ? 1 : 0,
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 120),
                            child: const HugeIcon(
                              icon: HugeIcons.strokeRoundedTick01,
                              size: 18,
                              strokeWidth: 1.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              selectedItemBuilder: (_) => const SizedBox.shrink(),
              onSelectionChange: (values) {
                if (syncing || values.isEmpty) return;
                widget.onChanged(values.first);
              },
            ),
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: colors.borderMuted),
                ),
              ),
            ),
            PositionedDirectional(
              start: 0,
              top: 0,
              bottom: 0,
              end: 24,
              child: IgnorePointer(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 12),
                  child: Row(
                    children: [
                      LanguageIdentityIcon(language: widget.selected, size: 20),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          _label(widget.selected),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              end: 10,
              top: 11.5,
              child: IgnorePointer(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowDown01,
                  size: 13,
                  strokeWidth: 1.4,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
