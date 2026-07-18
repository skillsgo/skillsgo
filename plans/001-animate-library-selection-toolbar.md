# 001 — Animate the Library selection toolbar

- **Status**: DONE
- **Commit**: 3a5271ad
- **Severity**: MEDIUM
- **Category**: Missed opportunities; Accessibility; Interruptibility
- **Estimated scope**: 2 files, approximately 60 lines

## Problem

The floating Library selection toolbar is mounted and unmounted by a collection
`if`, so it teleports into and out of the bottom of the Library as selection
changes. This misses the spatial relationship between selecting a row and the
bulk-action surface appearing above the bottom edge.

```dart
// app/lib/ui/library_screen.dart:500 — current
if (selected.isNotEmpty)
  Positioned(
    left: 24,
    right: 28,
    bottom: 18,
    child: Align(
      alignment: Alignment.bottomCenter,
      child: _LibrarySelectionBar(
        selectedCount: selected.length,
        updateableCount: updateableSelected.length,
        operating: selected.any(
          (skill) => operatingSkills.contains(skill.name),
        ),
        onClear: () => setState(selectedSkillKeys.clear),
        onUpdate: _updateSelectedSkills,
        onManage: _manageSelectedSkills,
        manageLabel:
            selected.every(
              (skill) => skill.provenance == LibraryProvenance.external,
            )
            ? context.l10n.remove
            : context.l10n.manageTargets,
      ),
    ),
  ),
```

The toolbar is an occasional state-change surface, so a short entrance is
appropriate. It must remain interruptible because users can rapidly select,
clear, and reselect rows. It must also respect Flutter's reduced-motion signal.

## Target

Keep one bottom-positioned animation host mounted in the `Stack`. Switch its
child between a keyed empty state and the keyed toolbar with
`AnimatedSwitcher`.

- Enter over exactly `200ms`.
- Exit over exactly `160ms`, so system response is faster than presentation.
- Use the strong ease-out curve `Cubic(0.23, 1, 0.32, 1)` for both directions.
- Normal motion: animate only opacity and transform. Translate from
  `Offset(0, 0.25)` to `Offset.zero`; the percentage is relative to the
  toolbar's own height and therefore does not require a hard-coded pixel
  distance.
- Reduced motion: retain the `200ms`/`160ms` opacity transition but omit the
  `SlideTransition` entirely.
- Do not scale the toolbar. Its elevation and border already communicate a
  floating surface; adding scale would make the command surface feel inflated.
- Keep the toolbar child key stable while it is visible. Changes to selected
  count, enabled actions, or the dynamic Manage/Remove label must update in
  place without replaying the entrance.
- A rapid clear followed by reselection must reverse/retarget from the current
  visual state; it must not restart from fully hidden.

Use this exact structure as the target implementation shape:

```dart
// app/lib/ui/library_screen.dart — target shape
final disableAnimations = MediaQuery.disableAnimationsOf(context);
const selectionBarEaseOut = Cubic(0.23, 1, 0.32, 1);

Positioned(
  left: 24,
  right: 28,
  bottom: 18,
  child: Align(
    alignment: Alignment.bottomCenter,
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 160),
      switchInCurve: selectionBarEaseOut,
      switchOutCurve: selectionBarEaseOut,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.bottomCenter,
        children: [...previousChildren, if (currentChild != null) currentChild],
      ),
      transitionBuilder: (child, animation) {
        final faded = FadeTransition(opacity: animation, child: child);
        if (disableAnimations) return faded;
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, .25),
            end: Offset.zero,
          ).animate(animation),
          child: faded,
        );
      },
      child: selected.isEmpty
          ? const SizedBox.shrink(key: ValueKey('selection-bar-empty'))
          : _LibrarySelectionBar(
              key: const ValueKey('selection-bar-visible'),
              // Preserve the current arguments unchanged.
            ),
    ),
  ),
),
```

Because `_LibrarySelectionBar` currently has no `key` parameter, add
`super.key` to its constructor. Preserve its existing internal
`Key('library-selection-bar')` used by tests.

## Repo conventions to follow

- Flutter implicit animations already branch on
  `MediaQuery.disableAnimationsOf(context)` in
  `app/lib/ui/library_screen.dart:789-792`.
- The App uses interruptible Flutter springs for spatial navigation in
  `app/lib/ui/nested_navigation.dart:121-132`; do not introduce a third-party
  animation dependency.
- The App is a crisp desktop management tool. Keep this transition short and
  non-bouncy; do not copy the playful spring used by the Folder tabs or Bloom
  color picker.
- Every touched semantic Dart file must retain an accurate F4 header and the
  exact protocol line required by `app/AGENTS.md`.

## Steps

1. In `app/lib/ui/library_screen.dart`, compute
   `disableAnimations = MediaQuery.disableAnimationsOf(context)` in the build
   scope that owns the Library `Stack`, and define the exact local curve
   `const Cubic(0.23, 1, 0.32, 1)`.
2. Replace the collection-`if` at current lines 500-524 with one always-mounted
   `Positioned`/`Align` host containing the exact `AnimatedSwitcher` behavior
   described in **Target**.
3. Give the visible and empty children different stable `ValueKey`s. Do not key
   the visible child by selected count, selected IDs, action availability, or
   label.
4. Add `super.key` to `_LibrarySelectionBar` while preserving the existing
   `Key('library-selection-bar')` on its internal `Material`.
5. Update the F4 `INPUT` header of `app/lib/ui/library_screen.dart` only if the
   resulting dependencies or role description are no longer accurate.
6. In `app/test/widget_test.dart`, extend the existing Library selection tests
   near the `library-selection-bar` expectations to cover entrance, exit,
   interruption, and reduced motion as described below. Do not rewrite the
   unrelated fake gateway or other tests.

## Boundaries

- Do NOT change toolbar colors, border, elevation, radius, padding, typography,
  iconography, button hierarchy, or callbacks.
- Do NOT animate selected row layout, toolbar width, height, padding, margin,
  `Positioned.bottom`, blur, shadow, or elevation.
- Do NOT animate count or label changes within an already visible toolbar.
- Do NOT add a new package, global animation token, animation controller, or
  custom ticker for this one transition.
- Do NOT modify `app/lib/ui/nested_navigation.dart`; it is only a convention
  exemplar.
- Do NOT fix unrelated pre-existing failures in `app/test/widget_test.dart`. If
  that file still fails to parse or compile before the planned test edits can
  run, stop and report the blocker instead of broadening scope.
- If the cited structure has drifted since commit `3a5271ad`, stop and report
  the mismatch instead of improvising.

## Verification

- **Mechanical**:
  - Run `dart format lib/ui/library_screen.dart test/widget_test.dart` from
    `app/`.
  - Run `flutter analyze lib/ui/library_screen.dart` and expect no issues.
  - Run the narrow existing Library selection widget tests by their
    `--plain-name` values after adding the assertions. If unrelated existing
    syntax/interface errors prevent the test file from compiling, report them
    without fixing them.
  - Run `rg -n "library-selection-bar|selection-bar-visible|selection-bar-empty" lib/ui/library_screen.dart test/widget_test.dart` and confirm all three
    stable keys are present where expected.
- **Widget behavior**:
  - Select one Library row, call `tester.pump()`, and confirm the toolbar is
    mounted immediately so intent receives next-frame feedback.
  - Pump `100ms` and confirm the transition has not completed; then
    `pumpAndSettle()` and confirm the toolbar remains present.
  - Tap Clear, pump once, and confirm the outgoing toolbar remains mounted;
    after `pumpAndSettle()`, confirm it is absent.
  - During exit, reselect a row before `160ms` elapses and confirm the animation
    retargets without a disappearance frame.
  - Under `MediaQueryData(disableAnimations: true)`, confirm the transition
    subtree contains `FadeTransition` but no `SlideTransition`.
- **Feel check**:
  - Run `flutter run -d macos`, select a row, clear, then rapidly select/clear
    several times. The bar should feel attached to the lower viewport edge,
    never bounce, flash, or restart from fully hidden.
  - Use Flutter Inspector slow animations and confirm the bar moves upward by
    exactly one quarter of its own height while fading in.
  - Confirm selection-count changes update in place with no toolbar replay.
  - Enable macOS Reduce Motion and confirm only opacity changes; the toolbar
    must not translate.
- **Done when**: the toolbar has an interruptible `200ms` entrance and `160ms`
  exit using `Cubic(0.23, 1, 0.32, 1)`, normal mode animates only transform and
  opacity, reduced-motion mode drops translation, and count/label changes do
  not replay the transition.

## Execution result

Completed with one reviewed implementation correction: `AnimatedSwitcher`
created duplicate toolbar instances when exit was interrupted by reselection.
The final implementation uses one stateful transition host and one
`AnimationController`, reverses from the current value, retains exactly one
toolbar instance, and unmounts it only after dismissal. The reverse curve is
`FlippedCurve(Cubic(0.23, 1, 0.32, 1))`, which preserves visual ease-out during
the controller's `1 → 0` direction. Focused entrance/exit/reversal and reduced
motion widget tests pass.
