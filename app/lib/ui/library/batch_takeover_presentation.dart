/*
 * [INPUT]: Depends on the Library screen library, current-theme design tokens, repository avatars, localized takeover copy, and caller-provided preflight identities plus exact CLI transaction results.
 * [OUTPUT]: Provides a responsive floating hardware-console Batch Takeover surface whose deterministic Tetris story ends with four localized LED pain-point pieces, a self-clearing managed board, an in-board settlement, physical controls, retry, and reduced-motion behavior.
 * [POS]: Serves as the visual product-story and truthful post-transaction feedback module of the Library Batch Takeover journey while delegated callbacks retain mutation ownership.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../library_screen.dart';

typedef _TakeoverIllustratedSkill = ({String name, String skillId});

const _takeoverFallbackNames = <String>[
  'my-review',
  'commit-helper',
  'docs-writer',
  'release-check',
  'test-runner',
];

const _takeoverBoardColumns = 10;
const _takeoverBoardRows = 18;
const _takeoverLcdGlass = Color(0xffaeb89a);
const _takeoverLcdPanel = Color(0xffa8b394);
const _takeoverLcdInk = Color(0xff273127);
const _takeoverLcdMutedInk = Color(0xff596555);
const _takeoverLcdGrid = Color(0xff7b8873);

enum _BatchTakeoverDialogOutcome { skipped, completed }

enum _TakeoverPieceType { i, o, t, s, z, j, l }

enum _TakeoverPainPoint { location, freshness, recovery, versionDrift }

Color _takeoverPainPointColor(_TakeoverPainPoint painPoint) =>
    switch (painPoint) {
      _TakeoverPainPoint.location => const Color(0xffffb000),
      _TakeoverPainPoint.freshness => const Color(0xff32cfff),
      _TakeoverPainPoint.recovery => const Color(0xff35df83),
      _TakeoverPainPoint.versionDrift => const Color(0xffff4f9a),
    };

String _takeoverPainPointName(
  BuildContext context,
  _TakeoverPainPoint painPoint,
) => switch (painPoint) {
  _TakeoverPainPoint.location => context.l10n.batchTakeoverPainLocation,
  _TakeoverPainPoint.freshness => context.l10n.batchTakeoverPainFreshness,
  _TakeoverPainPoint.recovery => context.l10n.batchTakeoverPainRecovery,
  _TakeoverPainPoint.versionDrift => context.l10n.batchTakeoverPainVersionDrift,
};

typedef _TakeoverCell = ({int row, int column});

class _TakeoverPiecePlan {
  const _TakeoverPiecePlan({
    required this.type,
    required this.column,
    required this.cells,
    required this.coreCellIndex,
  });

  final _TakeoverPieceType type;
  final int column;
  final List<_TakeoverCell> cells;
  final int coreCellIndex;
}

// Five pieces cover a complete 10 × 2 strip. Their order is gravity-safe:
// the final I piece rests across the J/L pieces before both rows clear.
const _takeoverClearTemplate = <_TakeoverPiecePlan>[
  _TakeoverPiecePlan(
    type: _TakeoverPieceType.o,
    column: 0,
    cells: [
      (row: 0, column: 0),
      (row: 0, column: 1),
      (row: 1, column: 0),
      (row: 1, column: 1),
    ],
    coreCellIndex: 0,
  ),
  _TakeoverPiecePlan(
    type: _TakeoverPieceType.o,
    column: 2,
    cells: [
      (row: 0, column: 2),
      (row: 0, column: 3),
      (row: 1, column: 2),
      (row: 1, column: 3),
    ],
    coreCellIndex: 0,
  ),
  _TakeoverPiecePlan(
    type: _TakeoverPieceType.j,
    column: 4,
    cells: [
      (row: 0, column: 4),
      (row: 1, column: 4),
      (row: 1, column: 5),
      (row: 1, column: 6),
    ],
    coreCellIndex: 1,
  ),
  _TakeoverPiecePlan(
    type: _TakeoverPieceType.l,
    column: 7,
    cells: [
      (row: 0, column: 9),
      (row: 1, column: 7),
      (row: 1, column: 8),
      (row: 1, column: 9),
    ],
    coreCellIndex: 3,
  ),
  _TakeoverPiecePlan(
    type: _TakeoverPieceType.i,
    column: 5,
    cells: [
      (row: 0, column: 5),
      (row: 0, column: 6),
      (row: 0, column: 7),
      (row: 0, column: 8),
    ],
    coreCellIndex: 1,
  ),
];

// Ten gravity-safe placements cover a 10 × 4 strip and exercise all seven
// Tetromino types. Early pieces deliberately leave gaps for later pieces.
const _takeoverDiverseClearTemplate = <_TakeoverPiecePlan>[
  _TakeoverPiecePlan(
    type: _TakeoverPieceType.l,
    column: 0,
    cells: [
      (row: 1, column: 0),
      (row: 2, column: 0),
      (row: 3, column: 0),
      (row: 3, column: 1),
    ],
    coreCellIndex: 2,
  ),
  _TakeoverPiecePlan(
    type: _TakeoverPieceType.s,
    column: 1,
    cells: [
      (row: 1, column: 1),
      (row: 2, column: 1),
      (row: 2, column: 2),
      (row: 3, column: 2),
    ],
    coreCellIndex: 1,
  ),
  _TakeoverPiecePlan(
    type: _TakeoverPieceType.l,
    column: 2,
    cells: [
      (row: 1, column: 2),
      (row: 1, column: 3),
      (row: 2, column: 3),
      (row: 3, column: 3),
    ],
    coreCellIndex: 2,
  ),
  _TakeoverPiecePlan(
    type: _TakeoverPieceType.i,
    column: 0,
    cells: [
      (row: 0, column: 0),
      (row: 0, column: 1),
      (row: 0, column: 2),
      (row: 0, column: 3),
    ],
    coreCellIndex: 1,
  ),
  _TakeoverPiecePlan(
    type: _TakeoverPieceType.o,
    column: 4,
    cells: [
      (row: 2, column: 4),
      (row: 2, column: 5),
      (row: 3, column: 4),
      (row: 3, column: 5),
    ],
    coreCellIndex: 0,
  ),
  _TakeoverPiecePlan(
    type: _TakeoverPieceType.t,
    column: 7,
    cells: [
      (row: 2, column: 8),
      (row: 3, column: 7),
      (row: 3, column: 8),
      (row: 3, column: 9),
    ],
    coreCellIndex: 2,
  ),
  _TakeoverPiecePlan(
    type: _TakeoverPieceType.t,
    column: 8,
    cells: [
      (row: 0, column: 9),
      (row: 1, column: 8),
      (row: 1, column: 9),
      (row: 2, column: 9),
    ],
    coreCellIndex: 2,
  ),
  _TakeoverPiecePlan(
    type: _TakeoverPieceType.z,
    column: 6,
    cells: [
      (row: 1, column: 7),
      (row: 2, column: 6),
      (row: 2, column: 7),
      (row: 3, column: 6),
    ],
    coreCellIndex: 2,
  ),
  _TakeoverPiecePlan(
    type: _TakeoverPieceType.j,
    column: 4,
    cells: [
      (row: 0, column: 4),
      (row: 1, column: 4),
      (row: 1, column: 5),
      (row: 1, column: 6),
    ],
    coreCellIndex: 1,
  ),
  _TakeoverPiecePlan(
    type: _TakeoverPieceType.i,
    column: 5,
    cells: [
      (row: 0, column: 5),
      (row: 0, column: 6),
      (row: 0, column: 7),
      (row: 0, column: 8),
    ],
    coreCellIndex: 1,
  ),
];

bool _takeoverTemplateIsExactCover() {
  bool covers(
    List<_TakeoverPiecePlan> template,
    int rows, {
    bool requireEveryType = false,
  }) {
    final cells = <String>{};
    final types = <_TakeoverPieceType>{};
    for (final piece in template) {
      types.add(piece.type);
      if (piece.cells.length != 4) return false;
      for (final cell in piece.cells) {
        if (cell.row < 0 || cell.row >= rows) return false;
        if (cell.column < 0 || cell.column >= 10) return false;
        if (!cells.add('${cell.row}:${cell.column}')) return false;
      }
    }
    return cells.length == rows * 10 &&
        (!requireEveryType || types.length == _TakeoverPieceType.values.length);
  }

  return _takeoverClearTemplate.length == 5 &&
      covers(_takeoverClearTemplate, 2) &&
      _takeoverDiverseClearTemplate.length == 10 &&
      covers(_takeoverDiverseClearTemplate, 4, requireEveryType: true);
}

List<_TakeoverPiecePlan> _takeoverTemplateAt(int index, int totalCount) {
  final diverseCount = (totalCount ~/ 10) * 10;
  if (index < diverseCount) return _takeoverDiverseClearTemplate;
  return _takeoverClearTemplate;
}

int _takeoverBatchStart(int index, int totalCount) {
  final diverseCount = (totalCount ~/ 10) * 10;
  if (index < diverseCount) return (index ~/ 10) * 10;
  return diverseCount;
}

int _takeoverTemplateRows(List<_TakeoverPiecePlan> template) {
  var rows = 0;
  for (final piece in template) {
    for (final cell in piece.cells) {
      rows = math.max(rows, cell.row + 1);
    }
  }
  return rows;
}

int _takeoverFillerCount(int realSkillCount, {int trailingCount = 0}) =>
    (5 - (realSkillCount + trailingCount) % 5) % 5;

class _TakeoverVisualPiece {
  const _TakeoverVisualPiece({
    required this.skill,
    required this.isFiller,
    this.painPoint,
  });

  final _TakeoverIllustratedSkill? skill;
  final bool isFiller;
  final _TakeoverPainPoint? painPoint;
}

class _BatchTakeoverConsole extends StatefulWidget {
  const _BatchTakeoverConsole({
    required this.eligibleCount,
    required this.skillPreviews,
    required this.onConfirm,
    required this.onExit,
  });

  final int eligibleCount;
  final List<BatchTakeoverPreview> skillPreviews;
  final Future<BatchTakeoverResult> Function() onConfirm;
  final Future<void> Function(_BatchTakeoverDialogOutcome outcome) onExit;

  @override
  State<_BatchTakeoverConsole> createState() => _BatchTakeoverConsoleState();
}

class _BatchTakeoverConsoleState extends State<_BatchTakeoverConsole>
    with SingleTickerProviderStateMixin {
  AnimationController? _revealController;
  bool _executing = false;
  bool _completed = false;
  Object? _error;
  BatchTakeoverResult? _result;
  List<_TakeoverVisualPiece> _pieces = const [];
  int _settledCount = 0;
  bool _clearing = false;

  @override
  void dispose() {
    _revealController?.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_executing) return;
    setState(() {
      _executing = true;
      _completed = false;
      _error = null;
      _result = null;
      _pieces = const [];
      _settledCount = 0;
      _clearing = false;
    });
    try {
      final result = await widget.onConfirm();
      if (!mounted) return;
      final previewByKey = {
        for (final preview in widget.skillPreviews)
          _takeoverSkillKey(preview.name, preview.skillId): (
            name: preview.name,
            skillId: preview.skillId,
          ),
      };
      final successful = result.items
          .where((item) => item.status == BatchTakeoverItemStatus.takenOver)
          .map(
            (item) =>
                previewByKey[_takeoverSkillKey(item.name, item.skillId)] ??
                (name: item.name, skillId: item.skillId),
          )
          .toList(growable: false);
      final fillerCount = _takeoverFillerCount(
        successful.length,
        trailingCount: _TakeoverPainPoint.values.length,
      );
      final pieces = <_TakeoverVisualPiece>[
        for (final skill in successful)
          _TakeoverVisualPiece(skill: skill, isFiller: false),
        for (var index = 0; index < fillerCount; index++)
          const _TakeoverVisualPiece(skill: null, isFiller: true),
        for (final painPoint in _TakeoverPainPoint.values)
          _TakeoverVisualPiece(
            skill: null,
            isFiller: false,
            painPoint: painPoint,
          ),
      ];
      setState(() {
        _result = result;
        _pieces = List.unmodifiable(pieces);
      });
      if (MediaQuery.disableAnimationsOf(context)) {
        setState(() {
          _settledCount = pieces.length;
          _completed = true;
          _executing = false;
        });
        return;
      }
      for (var index = 0; index < pieces.length; index++) {
        if (!mounted) return;
        await Future<void>.delayed(_takeoverPieceDuration(index));
        if (!mounted) return;
        setState(() => _settledCount = index + 1);
        final template = _takeoverTemplateAt(index, pieces.length);
        final batchStart = _takeoverBatchStart(index, pieces.length);
        if (index + 1 == batchStart + template.length) {
          setState(() => _clearing = true);
          await Future<void>.delayed(const Duration(milliseconds: 180));
          if (!mounted) return;
          setState(() => _clearing = false);
        }
      }
      if (!mounted) return;
      setState(() {
        _executing = false;
        _completed = true;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _executing = false;
        _error = error;
      });
    }
  }

  Duration _takeoverPieceDuration(int index) {
    if (index < 4) return const Duration(milliseconds: 320);
    if (index < 12) return const Duration(milliseconds: 180);
    return const Duration(milliseconds: 105);
  }

  Future<void> _exit(_BatchTakeoverDialogOutcome outcome) async {
    final revealController = _revealController;
    if (revealController != null) {
      await revealController.reverse();
      if (!mounted) return;
    }
    await widget.onExit(outcome);
  }

  @override
  Widget build(BuildContext context) {
    final front = _buildFrontConsole(context);
    if (MediaQuery.disableAnimationsOf(context)) return front;
    final revealController = _revealController ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    final back = _buildBackConsole(context);
    return AnimatedBuilder(
      animation: revealController,
      builder: (context, _) {
        final riseProgress = const Interval(
          0,
          .3,
          curve: Curves.easeOutCubic,
        ).transform(revealController.value);
        final flipProgress = const Interval(
          .3,
          1,
          curve: Curves.easeInOutCubic,
        ).transform(revealController.value);
        final angle = -math.pi * (1 - flipProgress);
        final verticalOffset = 48 * (1 - riseProgress);
        final frontFacing = math.cos(angle) >= 0;
        final face = frontFacing
            ? front
            : Transform(
                alignment: Alignment.center,
                transform: Matrix4.rotationY(math.pi),
                child: back,
              );
        final scale =
            .96 + .04 * flipProgress - .04 * math.sin(math.pi * flipProgress);
        final opacity = Curves.easeOut.transform(
          math.min(1, revealController.value / .18),
        );
        return IgnorePointer(
          ignoring: revealController.isAnimating,
          child: Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: Offset(0, verticalOffset),
              child: Transform.scale(
                scale: scale,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, .0011)
                    ..rotateY(angle),
                  child: face,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFrontConsole(BuildContext context) {
    final result = _result;
    final failure = _error == null ? null : failureCopy(context, _error!);
    const hardwareInk = Color(0xff262521);
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430, maxHeight: 590),
        child: RepaintBoundary(
          key: const Key('batch-takeover-dialog'),
          child: _TakeoverHardwareShell(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 18),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'SKILLSGO',
                        style: context.skillsTypography.caption.copyWith(
                          color: hardwareInk.withValues(alpha: .72),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.4,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _completed
                              ? const Color(0xff24b47e)
                              : _executing
                              ? const Color(0xffffb020)
                              : const Color(0xffef625b),
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(color: Color(0x55000000), blurRadius: 4),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _completed
                            ? 'DONE'
                            : _executing
                            ? 'PLAY'
                            : 'READY',
                        style: context.skillsTypography.caption.copyWith(
                          color: hardwareInk.withValues(alpha: .65),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _BatchTakeoverStory(
                      eligibleCount: widget.eligibleCount,
                      skillPreviews: widget.skillPreviews,
                      result: result,
                      pieces: _pieces,
                      settledCount: _settledCount,
                      clearing: _clearing,
                      executing: _executing,
                      completed: _completed,
                    ),
                  ),
                  if (failure != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      failure.message,
                      textAlign: TextAlign.center,
                      style: context.skillsTypography.caption.copyWith(
                        color: const Color(0xffa32920),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (_completed)
                    SizedBox(
                      width: 156,
                      child: _TakeoverHardwareButton(
                        key: const Key('batch-takeover-close'),
                        enabled: true,
                        primary: true,
                        onPressed: () =>
                            _exit(_BatchTakeoverDialogOutcome.completed),
                        label: context.l10n.batchTakeoverClose,
                      ),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 132,
                          child: _TakeoverHardwareButton(
                            key: const Key('batch-takeover-skip'),
                            enabled: !_executing,
                            primary: false,
                            onPressed: _executing
                                ? null
                                : () => _exit(
                                    _BatchTakeoverDialogOutcome.skipped,
                                  ),
                            label: context.l10n.batchTakeoverSkip,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: SizedBox(
                            width: 156,
                            child: _TakeoverHardwareButton(
                              key: const Key('batch-takeover-confirm'),
                              enabled: !_executing,
                              primary: true,
                              onPressed: _executing ? null : _confirm,
                              label: _executing
                                  ? context.l10n.batchTakeoverPending
                                  : _error == null
                                  ? context.l10n.batchTakeoverConfirm
                                  : context.l10n.batchTakeoverExecutionRetry,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackConsole(BuildContext context) => Align(
    alignment: Alignment.center,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 430, maxHeight: 590),
      child: const RepaintBoundary(
        key: Key('batch-takeover-console-back'),
        child: _TakeoverHardwareShell(child: _TakeoverHardwareBack()),
      ),
    ),
  );
}

class _TakeoverHardwareBack extends StatelessWidget {
  const _TakeoverHardwareBack();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: 430,
      height: 590,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Stack(
          children: [
            const Positioned(left: 0, top: 0, child: _TakeoverBackScrew()),
            const Positioned(right: 0, top: 0, child: _TakeoverBackScrew()),
            const Positioned(left: 0, bottom: 0, child: _TakeoverBackScrew()),
            const Positioned(right: 0, bottom: 0, child: _TakeoverBackScrew()),
            Positioned(
              top: 48,
              left: 0,
              right: 0,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/branding/skillsgo-logo.png',
                    key: const Key('batch-takeover-console-back-logo'),
                    width: 108,
                    height: 108,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'SKILLSGO',
                    style: context.skillsTypography.caption.copyWith(
                      color: const Color(0xff575249),
                      fontFamily: 'TakeoverPixel',
                      fontSize: 12,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: 180,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x26777065),
                      border: Border.all(color: const Color(0xffaaa397)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'MODEL SG-01',
                          style: context.skillsTypography.caption.copyWith(
                            color: const Color(0xff5f5a51),
                            fontFamily: 'TakeoverPixel',
                            fontSize: 8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const _TakeoverBackVent(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TakeoverBackScrew extends StatelessWidget {
  const _TakeoverBackScrew();

  @override
  Widget build(BuildContext context) => Container(
    width: 12,
    height: 12,
    decoration: BoxDecoration(
      color: const Color(0xffaaa397),
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xff777168)),
    ),
    child: const Center(
      child: SizedBox(
        width: 6,
        height: 1,
        child: ColoredBox(color: Color(0xff5a554d)),
      ),
    ),
  );
}

class _TakeoverBackVent extends StatelessWidget {
  const _TakeoverBackVent();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var index = 0; index < 5; index++) ...[
        const SizedBox(
          width: 110,
          height: 2,
          child: ColoredBox(color: Color(0xff777168)),
        ),
        if (index < 4) const SizedBox(height: 5),
      ],
    ],
  );
}

class _TakeoverHardwareShell extends StatelessWidget {
  const _TakeoverHardwareShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final shadow = context.skillsColors.shadow;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 3,
          top: 6,
          right: 0,
          bottom: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xff8e877b),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xff777065), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: shadow.withValues(alpha: .34),
                  blurRadius: 38,
                  spreadRadius: 1,
                  offset: const Offset(3, 20),
                ),
                BoxShadow(
                  color: shadow.withValues(alpha: .18),
                  blurRadius: 8,
                  offset: const Offset(3, 7),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 3, bottom: 6),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xffe2ddd2), Color(0xffd2ccbf)],
                stops: [0, 1],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xff9a9387), width: 1.5),
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}

class _TakeoverHardwareButton extends StatefulWidget {
  const _TakeoverHardwareButton({
    super.key,
    required this.label,
    required this.primary,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool primary;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  State<_TakeoverHardwareButton> createState() =>
      _TakeoverHardwareButtonState();
}

class _TakeoverHardwareButtonState extends State<_TakeoverHardwareButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || !widget.enabled) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final buttonColor = widget.enabled
        ? widget.primary
              ? const Color(0xffd95750)
              : const Color(0xffaaa397)
        : const Color(0xffb8b1a5);
    final edgeColor = widget.primary
        ? const Color(0xff973c37)
        : const Color(0xff746f66);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 70);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled ? (_) => _setPressed(true) : null,
      onTapUp: widget.enabled ? (_) => _setPressed(false) : null,
      onTapCancel: widget.enabled ? () => _setPressed(false) : null,
      onTap: widget.enabled ? widget.onPressed : null,
      child: Semantics(
        button: true,
        enabled: widget.enabled,
        label: widget.label,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 58,
              height: 58,
              child: Stack(
                children: [
                  Positioned(
                    left: 2,
                    top: 3,
                    right: 0,
                    bottom: 0,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        color: Color(0xff25241f),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x4d000000),
                            blurRadius: 2,
                            offset: Offset(1, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    right: 3,
                    bottom: 3,
                    child: TweenAnimationBuilder<double>(
                      key: Key(
                        widget.primary
                            ? 'batch-takeover-confirm-face'
                            : 'batch-takeover-skip-face',
                      ),
                      duration: duration,
                      curve: Curves.easeOut,
                      tween: Tween(end: _pressed ? 1 : 0),
                      builder: (context, press, child) => Transform.scale(
                        scale: 1 - .035 * press,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color.lerp(
                                  buttonColor,
                                  const Color(0xffffffff),
                                  .2 * (1 - press),
                                )!,
                                Color.lerp(
                                  buttonColor,
                                  const Color(0xff201f1c),
                                  .06 * press,
                                )!,
                                Color.lerp(
                                  buttonColor,
                                  const Color(0xff201f1c),
                                  .25 + .08 * press,
                                )!,
                              ],
                              stops: const [0, .58, 1],
                            ),
                            border: Border.all(
                              color: Color.lerp(
                                edgeColor,
                                const Color(0xff282621),
                                .25 * press,
                              )!,
                              width: 1.5,
                            ),
                          ),
                          child: CustomPaint(
                            foregroundPainter: _TakeoverButtonHighlightPainter(
                              opacity: widget.enabled ? .38 * (1 - press) : .12,
                            ),
                            child: child,
                          ),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          widget.primary ? 'A' : 'B',
                          style: context.skillsTypography.sectionTitle.copyWith(
                            color: widget.primary
                                ? const Color(0xffffffff)
                                : const Color(0xff282722),
                            fontFamily: 'TakeoverPixel',
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.skillsTypography.caption.copyWith(
                color: widget.enabled
                    ? const Color(0xff5a564e)
                    : const Color(0xff777168),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TakeoverButtonHighlightPainter extends CustomPainter {
  const _TakeoverButtonHighlightPainter({required this.opacity});

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = size.shortestSide * .13;
    final rect = (Offset.zero & size).deflate(inset);
    canvas.drawArc(
      rect,
      math.pi * 1.12,
      math.pi * .7,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, size.shortestSide * .035)
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_TakeoverButtonHighlightPainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}

class _BatchTakeoverStory extends StatelessWidget {
  const _BatchTakeoverStory({
    required this.eligibleCount,
    required this.skillPreviews,
    required this.result,
    required this.pieces,
    required this.settledCount,
    required this.clearing,
    required this.executing,
    required this.completed,
  });

  final int eligibleCount;
  final List<BatchTakeoverPreview> skillPreviews;
  final BatchTakeoverResult? result;
  final List<_TakeoverVisualPiece> pieces;
  final int settledCount;
  final bool clearing;
  final bool executing;
  final bool completed;

  List<_TakeoverIllustratedSkill> get _orderedSkills {
    final candidates = <_TakeoverIllustratedSkill>[];
    final seen = <String>{};
    for (final preview in skillPreviews) {
      final name = preview.name.trim();
      if (name.isEmpty) continue;
      if (!seen.add(_takeoverSkillKey(name, preview.skillId))) continue;
      candidates.add((name: name, skillId: preview.skillId));
    }
    final selected = <_TakeoverIllustratedSkill>[];
    final deferred = <_TakeoverIllustratedSkill>[];
    final repositories = <String>{};
    for (final candidate in candidates) {
      if (repositories.add(_takeoverRepositoryIdentity(candidate))) {
        selected.add(candidate);
      } else {
        deferred.add(candidate);
      }
    }
    selected.addAll(deferred);
    for (final fallback in _takeoverFallbackNames) {
      if (selected.length >= eligibleCount) break;
      selected.add((name: fallback, skillId: ''));
    }
    return selected.take(eligibleCount).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final settledRealCount = pieces
        .take(settledCount)
        .where((piece) => piece.skill != null)
        .length;
    final settledSkillKeys = pieces
        .take(settledCount)
        .where((piece) => !piece.isFiller && piece.skill != null)
        .map(
          (piece) => _takeoverSkillKey(piece.skill!.name, piece.skill!.skillId),
        )
        .toSet();
    final orderedSkills = _orderedSkills;
    final plannedIndexBySkillKey = <String, int>{
      for (var index = 0; index < orderedSkills.length; index++)
        _takeoverSkillKey(
          orderedSkills[index].name,
          orderedSkills[index].skillId,
        ): index,
      for (var index = 0; index < pieces.length; index++)
        if (!pieces[index].isFiller && pieces[index].skill != null)
          _takeoverSkillKey(
            pieces[index].skill!.name,
            pieces[index].skill!.skillId,
          ): index,
    };
    final pending = orderedSkills
        .where(
          (skill) => !settledSkillKeys.contains(
            _takeoverSkillKey(skill.name, skill.skillId),
          ),
        )
        .toList(growable: false);
    final plannedPieceCount = pieces.isEmpty
        ? eligibleCount +
              _takeoverFillerCount(
                eligibleCount,
                trailingCount: _TakeoverPainPoint.values.length,
              ) +
              _TakeoverPainPoint.values.length
        : pieces.length;
    final remainingPainPoints = pieces.isEmpty
        ? _TakeoverPainPoint.values
        : pieces
              .skip(settledCount)
              .map((piece) => piece.painPoint)
              .whereType<_TakeoverPainPoint>()
              .toList(growable: false);
    final plannedIndexByPainPoint = <_TakeoverPainPoint, int>{
      if (pieces.isEmpty)
        for (var index = 0; index < _TakeoverPainPoint.values.length; index++)
          _TakeoverPainPoint.values[index]:
              plannedPieceCount - _TakeoverPainPoint.values.length + index
      else
        for (var index = 0; index < pieces.length; index++)
          if (pieces[index].painPoint != null) pieces[index].painPoint!: index,
    };
    final content = completed
        ? _TakeoverCompletedGameScreen(
            key: const ValueKey('settlement'),
            result: result,
            eligibleCount: eligibleCount,
          )
        : _TakeoverGameScreen(
            key: const ValueKey('game'),
            pieces: pieces,
            settledCount: settledCount,
            clearing: clearing,
            eligibleCount: eligibleCount,
            settledRealCount: settledRealCount,
            result: result,
            executing: executing,
            pending: pending,
            plannedIndexBySkillKey: plannedIndexBySkillKey,
            painPoints: remainingPainPoints,
            plannedIndexByPainPoint: plannedIndexByPainPoint,
            plannedPieceCount: plannedPieceCount,
          );
    return Semantics(
      key: const Key('batch-takeover-tetris-story'),
      container: true,
      label: context.l10n.batchTakeoverBeforeSemantics,
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.center,
        child: _TakeoverRecessedLcd(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 420),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

class _TakeoverCompletedGameScreen extends StatelessWidget {
  const _TakeoverCompletedGameScreen({
    super.key,
    required this.result,
    required this.eligibleCount,
  });

  final BatchTakeoverResult? result;
  final int eligibleCount;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: _TakeoverSettlementScreen(
          result: result,
          eligibleCount: eligibleCount,
        ),
      ),
      const SizedBox(width: 4),
      SizedBox(
        width: 122,
        child: _TakeoverPendingQueue(
          skills: const [],
          painPoints: const [],
          plannedIndexBySkillKey: const {},
          plannedIndexByPainPoint: const {},
          plannedPieceCount: math.max(1, eligibleCount),
          result: result,
          fillerCount: 0,
          showWaitingMessage: false,
        ),
      ),
    ],
  );
}

class _TakeoverGameScreen extends StatelessWidget {
  const _TakeoverGameScreen({
    super.key,
    required this.pieces,
    required this.settledCount,
    required this.clearing,
    required this.eligibleCount,
    required this.settledRealCount,
    required this.result,
    required this.executing,
    required this.pending,
    required this.plannedIndexBySkillKey,
    required this.painPoints,
    required this.plannedIndexByPainPoint,
    required this.plannedPieceCount,
  });

  final List<_TakeoverVisualPiece> pieces;
  final int settledCount;
  final bool clearing;
  final int eligibleCount;
  final int settledRealCount;
  final BatchTakeoverResult? result;
  final bool executing;
  final List<_TakeoverIllustratedSkill> pending;
  final Map<String, int> plannedIndexBySkillKey;
  final List<_TakeoverPainPoint> painPoints;
  final Map<_TakeoverPainPoint, int> plannedIndexByPainPoint;
  final int plannedPieceCount;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: _TakeoverTetrisBoard(
          pieces: pieces,
          settledCount: settledCount,
          clearing: clearing,
          eligibleCount: eligibleCount,
          settledRealCount: settledRealCount,
          result: result,
          executing: executing,
        ),
      ),
      const SizedBox(width: 4),
      SizedBox(
        width: 122,
        child: _TakeoverPendingQueue(
          skills: pending,
          painPoints: painPoints,
          plannedIndexBySkillKey: plannedIndexBySkillKey,
          plannedIndexByPainPoint: plannedIndexByPainPoint,
          plannedPieceCount: plannedPieceCount,
          result: result,
          fillerCount: pieces.where((piece) => piece.isFiller).length,
          showWaitingMessage: true,
        ),
      ),
    ],
  );
}

class _TakeoverSettlementScreen extends StatelessWidget {
  const _TakeoverSettlementScreen({
    required this.result,
    required this.eligibleCount,
  });

  final BatchTakeoverResult? result;
  final int eligibleCount;

  @override
  Widget build(BuildContext context) {
    final managed = result?.takenOver ?? 0;
    final skipped = result?.skipped ?? 0;
    final allClear = skipped == 0;
    return Semantics(
      key: const Key('batch-takeover-board-complete'),
      container: true,
      label: context.l10n.batchTakeoverSummary(managed, skipped),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _takeoverLcdPanel,
          border: Border.all(color: _takeoverLcdInk, width: 1.5),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: .24,
                child: CustomPaint(painter: _TakeoverSettlementGridPainter()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 44, 28, 24),
              child: Column(
                children: [
                  Text(
                    allClear
                        ? context.l10n.batchTakeoverBoardComplete
                        : context.l10n.batchTakeoverBoardPartial,
                    style: context.skillsTypography.sectionTitle.copyWith(
                      color: _takeoverLcdInk,
                      fontFamily: 'TakeoverPixel',
                      fontSize: 22,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(width: 84, height: 2, color: _takeoverLcdInk),
                  const Spacer(flex: 2),
                  _TakeoverSettlementStat(
                    label: context.l10n.batchTakeoverStatusManaged,
                    value: managed,
                  ),
                  const SizedBox(height: 18),
                  _TakeoverSettlementStat(
                    label: context.l10n.batchTakeoverStatusSkipped,
                    value: skipped,
                  ),
                  const SizedBox(height: 18),
                  _TakeoverSettlementStat(
                    label: context.l10n.batchTakeoverStatusTotal,
                    value: eligibleCount,
                  ),
                  const Spacer(flex: 2),
                  const _TakeoverClearedRowsTrace(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TakeoverSettlementStat extends StatelessWidget {
  const _TakeoverSettlementStat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label.toUpperCase(),
          style: context.skillsTypography.caption.copyWith(
            color: _takeoverLcdMutedInk,
            fontFamily: 'TakeoverPixel',
            fontSize: 9,
            letterSpacing: .4,
          ),
        ),
      ),
      _TakeoverLcdNumber('$value', color: _takeoverLcdInk),
    ],
  );
}

class _TakeoverClearedRowsTrace extends StatelessWidget {
  const _TakeoverClearedRowsTrace();

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: .52,
    child: Column(
      children: [
        for (var row = 0; row < 2; row++)
          Row(
            children: [
              for (var column = 0; column < _takeoverBoardColumns; column++)
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: _takeoverLcdGrid),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    ),
  );
}

class _TakeoverSettlementGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _takeoverLcdGrid
      ..strokeWidth = .6;
    const columns = 10;
    const rows = 12;
    for (var column = 1; column < columns; column++) {
      final x = size.width * column / columns;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var row = 1; row < rows; row++) {
      final y = size.height * row / rows;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_TakeoverSettlementGridPainter oldDelegate) => false;
}

class _TakeoverRecessedLcd extends StatelessWidget {
  const _TakeoverRecessedLcd({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 390,
    height: 450,
    child: CustomPaint(
      painter: const _TakeoverRecessedLcdPainter(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(7, 7, 5, 6),
        child: child,
      ),
    ),
  );
}

class _TakeoverRecessedLcdPainter extends CustomPainter {
  const _TakeoverRecessedLcdPainter();

  static const _innerInsets = EdgeInsets.fromLTRB(6, 6, 4, 5);

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Offset.zero & size;
    final inner = Rect.fromLTRB(
      _innerInsets.left,
      _innerInsets.top,
      size.width - _innerInsets.right,
      size.height - _innerInsets.bottom,
    );

    _paintPlane(
      canvas,
      Path()
        ..moveTo(outer.left, outer.top)
        ..lineTo(outer.right, outer.top)
        ..lineTo(inner.right, inner.top)
        ..lineTo(inner.left, inner.top)
        ..close(),
      const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xffbbb7ac), Color(0xff55584b)],
      ),
      Rect.fromLTRB(0, 0, size.width, inner.top),
    );
    _paintPlane(
      canvas,
      Path()
        ..moveTo(outer.left, outer.top)
        ..lineTo(inner.left, inner.top)
        ..lineTo(inner.left, inner.bottom)
        ..lineTo(outer.left, outer.bottom)
        ..close(),
      const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Color(0xffb5b2a7), Color(0xff585b4e)],
      ),
      Rect.fromLTRB(0, 0, inner.left, size.height),
    );
    _paintPlane(
      canvas,
      Path()
        ..moveTo(outer.left, outer.bottom)
        ..lineTo(inner.left, inner.bottom)
        ..lineTo(inner.right, inner.bottom)
        ..lineTo(outer.right, outer.bottom)
        ..close(),
      const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xffd0cbc0), Color(0xffc2beb3)],
      ),
      Rect.fromLTRB(0, inner.bottom, size.width, size.height),
    );
    _paintPlane(
      canvas,
      Path()
        ..moveTo(outer.right, outer.top)
        ..lineTo(outer.right, outer.bottom)
        ..lineTo(inner.right, inner.bottom)
        ..lineTo(inner.right, inner.top)
        ..close(),
      const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Color(0xffcec9be), Color(0xffbebbb0)],
      ),
      Rect.fromLTRB(inner.right, 0, size.width, size.height),
    );

    canvas.drawRect(inner, Paint()..color = _takeoverLcdGlass);
    canvas.drawRect(
      inner.deflate(.5),
      Paint()
        ..color = const Color(0xff68715e)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  static void _paintPlane(
    Canvas canvas,
    Path path,
    LinearGradient gradient,
    Rect bounds,
  ) {
    canvas.drawPath(path, Paint()..shader = gradient.createShader(bounds));
  }

  @override
  bool shouldRepaint(covariant _TakeoverRecessedLcdPainter oldDelegate) =>
      false;
}

class _TakeoverStatusPanel extends StatelessWidget {
  const _TakeoverStatusPanel({
    required this.eligibleCount,
    required this.settledCount,
    required this.result,
    required this.executing,
    required this.completed,
  });

  final int eligibleCount;
  final int settledCount;
  final BatchTakeoverResult? result;
  final bool executing;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final managed = completed
        ? result?.takenOver ?? settledCount
        : settledCount;
    final skipped = result?.skipped ?? 0;
    final pending = math.max(0, eligibleCount - managed - skipped);
    return DecoratedBox(
      key: const Key('batch-takeover-status-panel'),
      decoration: const BoxDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _TakeoverStatusItem(
              label: context.l10n.batchTakeoverPendingSection,
              value: '$pending',
            ),
          ),
          Expanded(
            child: _TakeoverStatusItem(
              label: context.l10n.batchTakeoverStatusManaged,
              value: '$managed',
              color: managed > 0 ? _takeoverLcdInk : null,
            ),
          ),
          Expanded(
            child: _TakeoverStatusItem(
              label: context.l10n.batchTakeoverStatusSkipped,
              value: '$skipped',
            ),
          ),
        ],
      ),
    );
  }
}

class _TakeoverStatusItem extends StatelessWidget {
  const _TakeoverStatusItem({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 2,
          softWrap: true,
          overflow: TextOverflow.ellipsis,
          style: context.skillsTypography.caption.copyWith(
            color: _takeoverLcdMutedInk,
            fontSize: 9,
            height: 1.05,
            fontFamily: 'Menlo',
            letterSpacing: -.35,
          ),
        ),
        const SizedBox(height: 4),
        _TakeoverLcdNumber(value, color: color ?? _takeoverLcdInk),
      ],
    );
  }
}

class _TakeoverLcdNumber extends StatelessWidget {
  const _TakeoverLcdNumber(this.value, {required this.color});

  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: value,
    child: CustomPaint(
      size: Size(value.length * 7.0, 12),
      painter: _TakeoverLcdNumberPainter(value: value, color: color),
    ),
  );
}

class _TakeoverLcdNumberPainter extends CustomPainter {
  const _TakeoverLcdNumberPainter({required this.value, required this.color});

  static const _segments = <int, List<int>>{
    0: [0, 1, 2, 3, 4, 5],
    1: [1, 2],
    2: [0, 1, 6, 4, 3],
    3: [0, 1, 6, 2, 3],
    4: [5, 6, 1, 2],
    5: [0, 5, 6, 2, 3],
    6: [0, 5, 6, 4, 2, 3],
    7: [0, 1, 2],
    8: [0, 1, 2, 3, 4, 5, 6],
    9: [0, 1, 2, 3, 5, 6],
  };

  final String value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.45
      ..strokeCap = StrokeCap.square;
    for (var index = 0; index < value.length; index++) {
      final digit = int.tryParse(value[index]);
      if (digit == null) continue;
      final x = index * 7.0 + .75;
      final points = <(Offset, Offset)>[
        (Offset(x + 1, .75), Offset(x + 4.5, .75)),
        (Offset(x + 5, 1.25), Offset(x + 5, 5.25)),
        (Offset(x + 5, 6.75), Offset(x + 5, 10.75)),
        (Offset(x + 1, 11.25), Offset(x + 4.5, 11.25)),
        (Offset(x + .5, 6.75), Offset(x + .5, 10.75)),
        (Offset(x + .5, 1.25), Offset(x + .5, 5.25)),
        (Offset(x + 1, 6), Offset(x + 4.5, 6)),
      ];
      for (final segment in _segments[digit]!) {
        final (start, end) = points[segment];
        canvas.drawLine(start, end, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_TakeoverLcdNumberPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.color != color;
}

class _TakeoverTetrisBoard extends StatelessWidget {
  const _TakeoverTetrisBoard({
    required this.pieces,
    required this.settledCount,
    required this.clearing,
    required this.eligibleCount,
    required this.settledRealCount,
    required this.result,
    required this.executing,
  });

  final List<_TakeoverVisualPiece> pieces;
  final int settledCount;
  final bool clearing;
  final int eligibleCount;
  final int settledRealCount;
  final BatchTakeoverResult? result;
  final bool executing;

  @override
  Widget build(BuildContext context) {
    assert(
      _takeoverTemplateIsExactCover(),
      'Takeover templates must exactly cover their intended board strips.',
    );
    final referenceIndex = clearing && settledCount > 0
        ? settledCount - 1
        : settledCount;
    final template = _takeoverTemplateAt(referenceIndex, pieces.length);
    final templateRows = _takeoverTemplateRows(template);
    final batchStart = _takeoverBatchStart(referenceIndex, pieces.length);
    final visibleSettled = clearing
        ? template.length
        : settledCount >= pieces.length
        ? 0
        : settledCount - batchStart;
    final activeIndex = !clearing && settledCount < pieces.length
        ? settledCount
        : null;
    return Semantics(
      key: const Key('batch-takeover-tetris-board'),
      container: true,
      label: context.l10n.batchTakeoverBoardSemantics,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _takeoverLcdPanel,
          border: Border.all(color: _takeoverLcdInk, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 7, 0, 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cell = math.min(
                (constraints.maxWidth - 20) / _takeoverBoardColumns,
                (constraints.maxHeight - 40) / _takeoverBoardRows,
              );
              final boardSize = Size(
                cell * _takeoverBoardColumns,
                cell * _takeoverBoardRows,
              );
              return Column(
                children: [
                  SizedBox(
                    height: 36,
                    child: Center(
                      child: SizedBox(
                        width: boardSize.width,
                        child: _TakeoverStatusPanel(
                          eligibleCount: eligibleCount,
                          settledCount: settledRealCount,
                          result: result,
                          executing: executing,
                          completed: false,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Center(
                      child: SizedBox.fromSize(
                        size: boardSize,
                        child: Stack(
                          children: [
                            const Positioned.fill(child: _TakeoverBoardGrid()),
                            for (var index = 0; index < visibleSettled; index++)
                              _TakeoverPlacedPiece(
                                key: ValueKey('settled-${batchStart + index}'),
                                piece: pieces.isEmpty
                                    ? const _TakeoverVisualPiece(
                                        skill: null,
                                        isFiller: true,
                                      )
                                    : pieces[math.min(
                                        batchStart + index,
                                        pieces.length - 1,
                                      )],
                                plan: template[index],
                                cellSize: cell,
                                boardRows: _takeoverBoardRows,
                                templateRows: templateRows,
                                clearing: clearing,
                              ),
                            if (activeIndex != null)
                              _TakeoverDroppingPiece(
                                key: ValueKey('active-$activeIndex'),
                                piece: pieces[activeIndex],
                                plan: template[activeIndex - batchStart],
                                cellSize: cell,
                                boardRows: _takeoverBoardRows,
                                templateRows: templateRows,
                                duration: _activeDropDuration(activeIndex),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Duration _activeDropDuration(int index) {
    if (index < 4) return const Duration(milliseconds: 320);
    if (index < 12) return const Duration(milliseconds: 180);
    return const Duration(milliseconds: 105);
  }
}

class _TakeoverBoardGrid extends StatelessWidget {
  const _TakeoverBoardGrid();

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _TakeoverBoardGridPainter(
      color: _takeoverLcdGrid.withValues(alpha: .58),
    ),
  );
}

class _TakeoverBoardGridPainter extends CustomPainter {
  const _TakeoverBoardGridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = .6;
    final cellWidth = size.width / _takeoverBoardColumns;
    final cellHeight = size.height / _takeoverBoardRows;
    for (var column = 0; column <= _takeoverBoardColumns; column++) {
      canvas.drawLine(
        Offset(column * cellWidth, 0),
        Offset(column * cellWidth, size.height),
        paint,
      );
    }
    for (var row = 0; row <= _takeoverBoardRows; row++) {
      canvas.drawLine(
        Offset(0, row * cellHeight),
        Offset(size.width, row * cellHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_TakeoverBoardGridPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _TakeoverDroppingPiece extends StatelessWidget {
  const _TakeoverDroppingPiece({
    super.key,
    required this.piece,
    required this.plan,
    required this.cellSize,
    required this.boardRows,
    required this.templateRows,
    required this.duration,
  });

  final _TakeoverVisualPiece piece;
  final _TakeoverPiecePlan plan;
  final double cellSize;
  final int boardRows;
  final int templateRows;
  final Duration duration;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: duration,
    curve: Curves.easeInCubic,
    builder: (context, progress, _) {
      final firstRow = plan.cells.map((cell) => cell.row).reduce(math.min);
      final startOffset = -firstRow.toDouble();
      final endOffset = (boardRows - templateRows).toDouble();
      final movementProgress = Curves.easeInOutCubic.transform(
        math.min(1, progress / .82),
      );
      final rotationProgress = Curves.easeInOutCubic.transform(
        math.min(1, progress / .62),
      );
      final pivotColumn =
          plan.cells.map((cell) => cell.column).reduce((a, b) => a + b) /
          plan.cells.length;
      final spawnColumnOffset = 4.5 - pivotColumn;
      final initialQuarterTurns = _takeoverInitialQuarterTurns(plan.type);
      return _TakeoverPieceCells(
        piece: piece,
        plan: plan,
        cellSize: cellSize,
        rowOffset: startOffset + (endOffset - startOffset) * progress,
        columnOffset: spawnColumnOffset * (1 - movementProgress),
        rotationRadians:
            initialQuarterTurns * math.pi / 2 * (1 - rotationProgress),
      );
    },
  );
}

int _takeoverInitialQuarterTurns(_TakeoverPieceType type) => switch (type) {
  _TakeoverPieceType.o => 0,
  _TakeoverPieceType.i || _TakeoverPieceType.s || _TakeoverPieceType.j => 1,
  _TakeoverPieceType.t || _TakeoverPieceType.z || _TakeoverPieceType.l => -1,
};

class _TakeoverPlacedPiece extends StatelessWidget {
  const _TakeoverPlacedPiece({
    super.key,
    required this.piece,
    required this.plan,
    required this.cellSize,
    required this.boardRows,
    required this.templateRows,
    required this.clearing,
  });

  final _TakeoverVisualPiece piece;
  final _TakeoverPiecePlan plan;
  final double cellSize;
  final int boardRows;
  final int templateRows;
  final bool clearing;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    duration: const Duration(milliseconds: 160),
    opacity: clearing ? .22 : 1,
    child: _TakeoverPieceCells(
      piece: piece,
      plan: plan,
      cellSize: cellSize,
      rowOffset: (boardRows - templateRows).toDouble(),
    ),
  );
}

class _TakeoverPieceCells extends StatelessWidget {
  const _TakeoverPieceCells({
    required this.piece,
    required this.plan,
    required this.cellSize,
    required this.rowOffset,
    this.columnOffset = 0,
    this.rotationRadians = 0,
  });

  final _TakeoverVisualPiece piece;
  final _TakeoverPiecePlan plan;
  final double cellSize;
  final double rowOffset;
  final double columnOffset;
  final double rotationRadians;

  @override
  Widget build(BuildContext context) {
    final pivotColumn =
        plan.cells.map((cell) => cell.column).reduce((a, b) => a + b) /
        plan.cells.length;
    final pivotRow =
        plan.cells.map((cell) => cell.row).reduce((a, b) => a + b) /
        plan.cells.length;
    final cosine = math.cos(rotationRadians);
    final sine = math.sin(rotationRadians);
    return Stack(
      children: [
        for (var index = 0; index < plan.cells.length; index++)
          Builder(
            builder: (context) {
              final source = plan.cells[index];
              final isAvatarCell =
                  index == plan.coreCellIndex &&
                  !piece.isFiller &&
                  piece.skill != null;
              final isPainPoint = piece.painPoint != null;
              final relativeColumn = source.column - pivotColumn;
              final relativeRow = source.row - pivotRow;
              final column =
                  pivotColumn +
                  relativeColumn * cosine -
                  relativeRow * sine +
                  columnOffset;
              final row =
                  pivotRow +
                  relativeColumn * sine +
                  relativeRow * cosine +
                  rowOffset;
              return Positioned(
                left: column * cellSize + 1,
                top: row * cellSize + 1,
                width: cellSize - 2,
                height: cellSize - 2,
                child: isPainPoint
                    ? _TakeoverLedCell(
                        color: _takeoverPainPointColor(piece.painPoint!),
                        child: index == plan.coreCellIndex
                            ? _TakeoverPieceIdentity(piece: piece)
                            : null,
                      )
                    : isAvatarCell
                    ? _TakeoverPieceIdentity(piece: piece)
                    : _TakeoverBlackCell(
                        child: index == plan.coreCellIndex
                            ? _TakeoverPieceIdentity(piece: piece)
                            : null,
                      ),
              );
            },
          ),
      ],
    );
  }
}

class _TakeoverPieceIdentity extends StatelessWidget {
  const _TakeoverPieceIdentity({required this.piece});

  final _TakeoverVisualPiece piece;

  @override
  Widget build(BuildContext context) {
    final painPoint = piece.painPoint;
    if (painPoint != null) {
      return CustomPaint(
        painter: _TakeoverPainPointSymbolPainter(
          painPoint: painPoint,
          color: _takeoverLcdInk,
        ),
      );
    }
    if (piece.isFiller || piece.skill == null) {
      return HugeIcon(
        icon: HugeIcons.strokeRoundedZap,
        size: 15,
        strokeWidth: 2,
        color: context.skillsComponents.primaryRest,
      );
    }
    final skill = piece.skill!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        return Center(
          child: RepositoryAvatar(
            source: skill.skillId,
            imageUrl: _repositoryAvatarUrl(skill.skillId),
            size: size,
            borderRadius: 0,
            backgroundColor: context.skillsColors.surfaceMuted,
            fallbackForegroundColor: context.skillsColors.foregroundDefault,
          ),
        );
      },
    );
  }
}

class _TakeoverLedCell extends StatelessWidget {
  const _TakeoverLedCell({required this.color, this.child});

  final Color color;
  final Widget? child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color.withValues(alpha: .28),
      border: Border.all(color: color, width: 1),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: .72),
          blurRadius: 4,
          spreadRadius: .4,
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(2),
      child: ColoredBox(
        color: color,
        child: child == null
            ? null
            : Padding(padding: const EdgeInsets.all(2), child: child),
      ),
    ),
  );
}

class _TakeoverPainPointSymbolPainter extends CustomPainter {
  const _TakeoverPainPointSymbolPainter({
    required this.painPoint,
    required this.color,
  });

  final _TakeoverPainPoint painPoint;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = math.max(1, size.shortestSide * .12)
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;
    final center = size.center(Offset.zero);
    final unit = size.shortestSide / 6;
    switch (painPoint) {
      case _TakeoverPainPoint.location:
        canvas.drawCircle(center, unit * 1.3, paint);
        canvas.drawLine(
          Offset(center.dx, unit * .2),
          Offset(center.dx, unit * 1.2),
          paint,
        );
        canvas.drawLine(
          Offset(center.dx, size.height - unit * .2),
          Offset(center.dx, size.height - unit * 1.2),
          paint,
        );
      case _TakeoverPainPoint.freshness:
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: unit * 1.65),
          -.2,
          math.pi * 1.45,
          false,
          paint,
        );
        canvas.drawLine(
          Offset(size.width - unit * 1.2, unit * 1.15),
          Offset(size.width - unit * .55, unit * 1.15),
          paint,
        );
      case _TakeoverPainPoint.recovery:
        canvas.drawLine(
          Offset(unit * 1.2, size.height - unit * 1.2),
          Offset(size.width - unit * 1.2, unit * 1.2),
          paint,
        );
        canvas.drawCircle(
          Offset(size.width - unit * 1.35, unit * 1.35),
          unit * .7,
          paint,
        );
      case _TakeoverPainPoint.versionDrift:
        canvas.drawLine(
          Offset(unit, center.dy),
          Offset(center.dx, center.dy),
          paint,
        );
        canvas.drawLine(
          Offset(center.dx, center.dy),
          Offset(size.width - unit, unit * 1.2),
          paint,
        );
        canvas.drawLine(
          Offset(center.dx, center.dy),
          Offset(size.width - unit, size.height - unit * 1.2),
          paint,
        );
    }
  }

  @override
  bool shouldRepaint(_TakeoverPainPointSymbolPainter oldDelegate) =>
      oldDelegate.painPoint != painPoint || oldDelegate.color != color;
}

class _TakeoverBlackCell extends StatelessWidget {
  const _TakeoverBlackCell({this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: _takeoverLcdInk, width: 1),
    ),
    child: Padding(
      padding: const EdgeInsets.all(2),
      child: ColoredBox(
        color: _takeoverLcdInk,
        child: child == null ? null : Center(child: child),
      ),
    ),
  );
}

class _TakeoverPendingQueue extends StatefulWidget {
  const _TakeoverPendingQueue({
    required this.skills,
    required this.painPoints,
    required this.plannedIndexBySkillKey,
    required this.plannedIndexByPainPoint,
    required this.plannedPieceCount,
    required this.result,
    required this.fillerCount,
    required this.showWaitingMessage,
  });

  final List<_TakeoverIllustratedSkill> skills;
  final List<_TakeoverPainPoint> painPoints;
  final Map<String, int> plannedIndexBySkillKey;
  final Map<_TakeoverPainPoint, int> plannedIndexByPainPoint;
  final int plannedPieceCount;
  final BatchTakeoverResult? result;
  final int fillerCount;
  final bool showWaitingMessage;

  @override
  State<_TakeoverPendingQueue> createState() => _TakeoverPendingQueueState();
}

class _TakeoverPendingQueueState extends State<_TakeoverPendingQueue> {
  final ScrollController _controller = ScrollController();

  @override
  void didUpdateWidget(_TakeoverPendingQueue oldWidget) {
    super.didUpdateWidget(oldWidget);
    final itemCount = widget.skills.length + widget.painPoints.length;
    final oldItemCount = oldWidget.skills.length + oldWidget.painPoints.length;
    if (itemCount >= oldItemCount) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_controller.hasClients) return;
      _controller.animateTo(
        math.min(_controller.offset + 58, _controller.position.maxScrollExtent),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const Key('batch-takeover-pending-queue'),
      decoration: const BoxDecoration(color: _takeoverLcdGlass),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.batchTakeoverNextLabel,
                    style: context.skillsTypography.caption.copyWith(
                      color: _takeoverLcdInk,
                      fontFamily: 'TakeoverPixel',
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      letterSpacing: .8,
                    ),
                  ),
                ),
                _TakeoverLcdNumber(
                  '${widget.skills.length + widget.painPoints.length}',
                  color: _takeoverLcdMutedInk,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child:
                  widget.skills.isEmpty &&
                      widget.painPoints.isEmpty &&
                      widget.showWaitingMessage
                  ? Center(
                      child: Text(
                        context.l10n.batchTakeoverQueueWaiting,
                        textAlign: TextAlign.center,
                        style: context.skillsTypography.caption.copyWith(
                          color: _takeoverLcdMutedInk,
                        ),
                      ),
                    )
                  : widget.skills.isEmpty && widget.painPoints.isEmpty
                  ? const SizedBox.shrink()
                  : ScrollConfiguration(
                      behavior: ScrollConfiguration.of(
                        context,
                      ).copyWith(scrollbars: false),
                      child: ListView.separated(
                        key: const Key('batch-takeover-pending-list'),
                        controller: _controller,
                        padding: EdgeInsets.zero,
                        itemCount:
                            widget.skills.length + widget.painPoints.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          if (index >= widget.skills.length) {
                            final painPoint =
                                widget.painPoints[index - widget.skills.length];
                            return _TakeoverPainQueueItem(
                              painPoint: painPoint,
                              planIndex:
                                  widget.plannedIndexByPainPoint[painPoint] ??
                                  0,
                              plannedPieceCount: widget.plannedPieceCount,
                            );
                          }
                          final skill = widget.skills[index];
                          return _TakeoverQueueItem(
                            skill: skill,
                            planIndex:
                                widget.plannedIndexBySkillKey[_takeoverSkillKey(
                                  skill.name,
                                  skill.skillId,
                                )] ??
                                _takeoverStableIndex(skill) %
                                    widget.plannedPieceCount,
                            plannedPieceCount: widget.plannedPieceCount,
                            skipped: _isSkipped(skill),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSkipped(_TakeoverIllustratedSkill skill) =>
      widget.result?.items.any(
        (item) =>
            item.status == BatchTakeoverItemStatus.skipped &&
            _takeoverSkillKey(item.name, item.skillId) ==
                _takeoverSkillKey(skill.name, skill.skillId),
      ) ??
      false;
}

class _TakeoverQueueItem extends StatelessWidget {
  const _TakeoverQueueItem({
    required this.skill,
    required this.planIndex,
    required this.plannedPieceCount,
    required this.skipped,
  });

  final _TakeoverIllustratedSkill skill;
  final int planIndex;
  final int plannedPieceCount;
  final bool skipped;

  @override
  Widget build(BuildContext context) {
    final piece = _TakeoverVisualPiece(skill: skill, isFiller: false);
    final template = _takeoverTemplateAt(planIndex, plannedPieceCount);
    final batchStart = _takeoverBatchStart(planIndex, plannedPieceCount);
    final plan = template[planIndex - batchStart];
    return Semantics(
      label: skipped
          ? context.l10n.batchTakeoverItemSkipped(skill.name)
          : context.l10n.batchTakeoverItemPending(skill.name),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: skipped ? Border.all(color: const Color(0xffef625b)) : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 34,
                height: 30,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: 80,
                    height: 52,
                    child: _TakeoverQueuePiece(piece: piece, plan: plan),
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  skill.name.replaceAll('-', ' '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.skillsTypography.caption.copyWith(
                    color: skipped ? const Color(0xffff837b) : _takeoverLcdInk,
                    fontFamily: 'TakeoverPixel',
                    fontSize: 9,
                    fontWeight: FontWeight.w400,
                    letterSpacing: .15,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TakeoverPainQueueItem extends StatelessWidget {
  const _TakeoverPainQueueItem({
    required this.painPoint,
    required this.planIndex,
    required this.plannedPieceCount,
  });

  final _TakeoverPainPoint painPoint;
  final int planIndex;
  final int plannedPieceCount;

  @override
  Widget build(BuildContext context) {
    final piece = _TakeoverVisualPiece(
      skill: null,
      isFiller: false,
      painPoint: painPoint,
    );
    final template = _takeoverTemplateAt(planIndex, plannedPieceCount);
    final batchStart = _takeoverBatchStart(planIndex, plannedPieceCount);
    final plan = template[planIndex - batchStart];
    final name = _takeoverPainPointName(context, painPoint);
    return Semantics(
      label: name,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              height: 30,
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: 80,
                  height: 52,
                  child: _TakeoverQueuePiece(piece: piece, plan: plan),
                ),
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.skillsTypography.caption.copyWith(
                  color: _takeoverLcdInk,
                  fontFamily: 'TakeoverPixel',
                  fontSize: 9,
                  fontWeight: FontWeight.w400,
                  letterSpacing: .15,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TakeoverQueuePiece extends StatelessWidget {
  const _TakeoverQueuePiece({required this.piece, required this.plan});

  final _TakeoverVisualPiece piece;
  final _TakeoverPiecePlan plan;

  @override
  Widget build(BuildContext context) {
    const cell = 18.0;
    final minColumn = plan.cells.map((cell) => cell.column).reduce(math.min);
    final minRow = plan.cells.map((cell) => cell.row).reduce(math.min);
    return Stack(
      children: [
        for (var index = 0; index < plan.cells.length; index++)
          Builder(
            builder: (context) {
              final isAvatarCell =
                  index == plan.coreCellIndex &&
                  !piece.isFiller &&
                  piece.skill != null;
              final isPainPoint = piece.painPoint != null;
              return Positioned(
                left: (plan.cells[index].column - minColumn) * cell,
                top: (plan.cells[index].row - minRow) * cell,
                width: cell - 2,
                height: cell - 2,
                child: isPainPoint
                    ? _TakeoverLedCell(
                        color: _takeoverPainPointColor(piece.painPoint!),
                        child: index == plan.coreCellIndex
                            ? _TakeoverPieceIdentity(piece: piece)
                            : null,
                      )
                    : isAvatarCell
                    ? _TakeoverPieceIdentity(piece: piece)
                    : _TakeoverBlackCell(
                        child: index == plan.coreCellIndex
                            ? _TakeoverPieceIdentity(piece: piece)
                            : null,
                      ),
              );
            },
          ),
      ],
    );
  }
}

int _takeoverStableIndex(_TakeoverIllustratedSkill skill) {
  var value = 0;
  for (final unit in '${skill.skillId}\u0000${skill.name}'.codeUnits) {
    value = ((value * 31) + unit) & 0x7fffffff;
  }
  return value;
}

String _takeoverRepositoryIdentity(_TakeoverIllustratedSkill skill) {
  final skillId = skill.skillId.trim();
  if (skillId.isEmpty) return 'unresolved:${skill.name}';
  final separator = skillId.indexOf('/-/');
  return separator < 0 ? skillId : skillId.substring(0, separator);
}

String _takeoverSkillKey(String name, String skillId) =>
    '${skillId.trim()}\u0000${name.trim()}';
