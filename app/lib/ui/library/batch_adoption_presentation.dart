/*
 * [INPUT]: Depends on the Library screen library, current-theme design tokens, Package avatars, localized adoption copy, and caller-provided preflight identities plus exact CLI transaction results.
 * [OUTPUT]: Provides a responsive modal hardware-console Batch Adoption surface with an input-blocking dismissible scrim, symmetric entrance and exit motion, automatic reviewed execution, transaction-accurate controls independent from the continuing story animation, vintage brand stickers, a borderless pending queue, a deterministic Tetris story ending with four localized LED pain-point pieces, a self-clearing managed board, and an in-board settlement.
 * [POS]: Serves as the visual product-story and truthful post-transaction feedback module of the Library Batch Adoption journey while delegated callbacks retain mutation ownership.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../library_screen.dart';

typedef _AdoptionIllustratedSkill = ({String name, String skillId});

const _adoptionFallbackNames = <String>[
  'my-review',
  'commit-helper',
  'docs-writer',
  'release-check',
  'test-runner',
];

const _adoptionBoardColumns = 10;
const _adoptionBoardRows = 18;
const _adoptionLcdGlass = Color(0xffaeb89a);
const _adoptionLcdPanel = Color(0xffa8b394);
const _adoptionLcdInk = Color(0xff273127);
const _adoptionLcdMutedInk = Color(0xff596555);
const _adoptionLcdGrid = Color(0xff7b8873);

enum _BatchAdoptionDialogOutcome { skipped, completed }

enum _AdoptionPieceType { i, o, t, s, z, j, l }

enum _AdoptionPainPoint { location, freshness, recovery, versionDrift }

Color _adoptionPainPointColor(_AdoptionPainPoint painPoint) =>
    switch (painPoint) {
      _AdoptionPainPoint.location => const Color(0xffffb000),
      _AdoptionPainPoint.freshness => const Color(0xff32cfff),
      _AdoptionPainPoint.recovery => const Color(0xff35df83),
      _AdoptionPainPoint.versionDrift => const Color(0xffff4f9a),
    };

String _adoptionPainPointName(
  BuildContext context,
  _AdoptionPainPoint painPoint,
) => switch (painPoint) {
  _AdoptionPainPoint.location => context.l10n.batchAdoptionPainLocation,
  _AdoptionPainPoint.freshness => context.l10n.batchAdoptionPainFreshness,
  _AdoptionPainPoint.recovery => context.l10n.batchAdoptionPainRecovery,
  _AdoptionPainPoint.versionDrift => context.l10n.batchAdoptionPainVersionDrift,
};

typedef _AdoptionCell = ({int row, int column});

class _AdoptionPiecePlan {
  const _AdoptionPiecePlan({
    required this.type,
    required this.column,
    required this.cells,
    required this.coreCellIndex,
  });

  final _AdoptionPieceType type;
  final int column;
  final List<_AdoptionCell> cells;
  final int coreCellIndex;
}

// Five pieces cover a complete 10 × 2 strip. Their order is gravity-safe:
// the final I piece rests across the J/L pieces before both rows clear.
const _adoptionClearTemplate = <_AdoptionPiecePlan>[
  _AdoptionPiecePlan(
    type: _AdoptionPieceType.o,
    column: 0,
    cells: [
      (row: 0, column: 0),
      (row: 0, column: 1),
      (row: 1, column: 0),
      (row: 1, column: 1),
    ],
    coreCellIndex: 0,
  ),
  _AdoptionPiecePlan(
    type: _AdoptionPieceType.o,
    column: 2,
    cells: [
      (row: 0, column: 2),
      (row: 0, column: 3),
      (row: 1, column: 2),
      (row: 1, column: 3),
    ],
    coreCellIndex: 0,
  ),
  _AdoptionPiecePlan(
    type: _AdoptionPieceType.j,
    column: 4,
    cells: [
      (row: 0, column: 4),
      (row: 1, column: 4),
      (row: 1, column: 5),
      (row: 1, column: 6),
    ],
    coreCellIndex: 1,
  ),
  _AdoptionPiecePlan(
    type: _AdoptionPieceType.l,
    column: 7,
    cells: [
      (row: 0, column: 9),
      (row: 1, column: 7),
      (row: 1, column: 8),
      (row: 1, column: 9),
    ],
    coreCellIndex: 3,
  ),
  _AdoptionPiecePlan(
    type: _AdoptionPieceType.i,
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
const _adoptionDiverseClearTemplate = <_AdoptionPiecePlan>[
  _AdoptionPiecePlan(
    type: _AdoptionPieceType.l,
    column: 0,
    cells: [
      (row: 1, column: 0),
      (row: 2, column: 0),
      (row: 3, column: 0),
      (row: 3, column: 1),
    ],
    coreCellIndex: 2,
  ),
  _AdoptionPiecePlan(
    type: _AdoptionPieceType.s,
    column: 1,
    cells: [
      (row: 1, column: 1),
      (row: 2, column: 1),
      (row: 2, column: 2),
      (row: 3, column: 2),
    ],
    coreCellIndex: 1,
  ),
  _AdoptionPiecePlan(
    type: _AdoptionPieceType.l,
    column: 2,
    cells: [
      (row: 1, column: 2),
      (row: 1, column: 3),
      (row: 2, column: 3),
      (row: 3, column: 3),
    ],
    coreCellIndex: 2,
  ),
  _AdoptionPiecePlan(
    type: _AdoptionPieceType.i,
    column: 0,
    cells: [
      (row: 0, column: 0),
      (row: 0, column: 1),
      (row: 0, column: 2),
      (row: 0, column: 3),
    ],
    coreCellIndex: 1,
  ),
  _AdoptionPiecePlan(
    type: _AdoptionPieceType.o,
    column: 4,
    cells: [
      (row: 2, column: 4),
      (row: 2, column: 5),
      (row: 3, column: 4),
      (row: 3, column: 5),
    ],
    coreCellIndex: 0,
  ),
  _AdoptionPiecePlan(
    type: _AdoptionPieceType.t,
    column: 7,
    cells: [
      (row: 2, column: 8),
      (row: 3, column: 7),
      (row: 3, column: 8),
      (row: 3, column: 9),
    ],
    coreCellIndex: 2,
  ),
  _AdoptionPiecePlan(
    type: _AdoptionPieceType.t,
    column: 8,
    cells: [
      (row: 0, column: 9),
      (row: 1, column: 8),
      (row: 1, column: 9),
      (row: 2, column: 9),
    ],
    coreCellIndex: 2,
  ),
  _AdoptionPiecePlan(
    type: _AdoptionPieceType.z,
    column: 6,
    cells: [
      (row: 1, column: 7),
      (row: 2, column: 6),
      (row: 2, column: 7),
      (row: 3, column: 6),
    ],
    coreCellIndex: 2,
  ),
  _AdoptionPiecePlan(
    type: _AdoptionPieceType.j,
    column: 4,
    cells: [
      (row: 0, column: 4),
      (row: 1, column: 4),
      (row: 1, column: 5),
      (row: 1, column: 6),
    ],
    coreCellIndex: 1,
  ),
  _AdoptionPiecePlan(
    type: _AdoptionPieceType.i,
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

bool _adoptionTemplateIsExactCover() {
  bool covers(
    List<_AdoptionPiecePlan> template,
    int rows, {
    bool requireEveryType = false,
  }) {
    final cells = <String>{};
    final types = <_AdoptionPieceType>{};
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
        (!requireEveryType || types.length == _AdoptionPieceType.values.length);
  }

  return _adoptionClearTemplate.length == 5 &&
      covers(_adoptionClearTemplate, 2) &&
      _adoptionDiverseClearTemplate.length == 10 &&
      covers(_adoptionDiverseClearTemplate, 4, requireEveryType: true);
}

List<_AdoptionPiecePlan> _adoptionTemplateAt(int index, int totalCount) {
  final diverseCount = (totalCount ~/ 10) * 10;
  if (index < diverseCount) return _adoptionDiverseClearTemplate;
  return _adoptionClearTemplate;
}

int _adoptionBatchStart(int index, int totalCount) {
  final diverseCount = (totalCount ~/ 10) * 10;
  if (index < diverseCount) return (index ~/ 10) * 10;
  return diverseCount;
}

int _adoptionTemplateRows(List<_AdoptionPiecePlan> template) {
  var rows = 0;
  for (final piece in template) {
    for (final cell in piece.cells) {
      rows = math.max(rows, cell.row + 1);
    }
  }
  return rows;
}

int _adoptionFillerCount(int realSkillCount, {int trailingCount = 0}) =>
    (5 - (realSkillCount + trailingCount) % 5) % 5;

class _AdoptionVisualPiece {
  const _AdoptionVisualPiece({
    required this.skill,
    required this.isFiller,
    this.painPoint,
  });

  final _AdoptionIllustratedSkill? skill;
  final bool isFiller;
  final _AdoptionPainPoint? painPoint;
}

class _BatchAdoptionConsole extends StatefulWidget {
  const _BatchAdoptionConsole({
    required this.eligibleCount,
    required this.initiallyCompleted,
    required this.skillPreviews,
    required this.onConfirm,
    required this.onExit,
  });

  final int eligibleCount;
  final bool initiallyCompleted;
  final List<BatchAdoptionPreview> skillPreviews;
  final Future<BatchAdoptionResult> Function() onConfirm;
  final Future<void> Function(_BatchAdoptionDialogOutcome outcome) onExit;

  @override
  State<_BatchAdoptionConsole> createState() => _BatchAdoptionConsoleState();
}

class _BatchAdoptionConsoleState extends State<_BatchAdoptionConsole>
    with SingleTickerProviderStateMixin {
  final _modalOverlay = OverlayPortalController();
  AnimationController? _revealController;
  bool _executing = false;
  bool _exiting = false;
  bool _transactionCompleted = false;
  bool _completed = false;
  Object? _error;
  BatchAdoptionResult? _result;
  List<_AdoptionVisualPiece> _pieces = const [];
  int _settledCount = 0;
  bool _clearing = false;
  bool _automaticExecutionScheduled = false;

  @override
  void initState() {
    super.initState();
    _modalOverlay.show();
    if (widget.initiallyCompleted) {
      _transactionCompleted = true;
      _completed = true;
      _result = const BatchAdoptionResult(adopted: 0, failed: 0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.initiallyCompleted || _automaticExecutionScheduled) return;
    _automaticExecutionScheduled = true;
    final delay = const Duration(milliseconds: 900);
    Future<void>.delayed(delay, () {
      if (mounted) unawaited(_confirm());
    });
  }

  @override
  void dispose() {
    _revealController?.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_executing) return;
    setState(() {
      _executing = true;
      _transactionCompleted = false;
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
          _adoptionSkillKey(preview.name, preview.skillId): (
            name: preview.name,
            skillId: preview.skillId,
          ),
      };
      final successful = result.items
          .where((item) => item.status == BatchAdoptionItemStatus.adopted)
          .map(
            (item) =>
                previewByKey[_adoptionSkillKey(item.name, item.skillId)] ??
                (name: item.name, skillId: item.skillId),
          )
          .toList(growable: false);
      final fillerCount = _adoptionFillerCount(
        successful.length,
        trailingCount: _AdoptionPainPoint.values.length,
      );
      final pieces = <_AdoptionVisualPiece>[
        for (final skill in successful)
          _AdoptionVisualPiece(skill: skill, isFiller: false),
        for (var index = 0; index < fillerCount; index++)
          const _AdoptionVisualPiece(skill: null, isFiller: true),
        for (final painPoint in _AdoptionPainPoint.values)
          _AdoptionVisualPiece(
            skill: null,
            isFiller: false,
            painPoint: painPoint,
          ),
      ];
      setState(() {
        _result = result;
        _pieces = List.unmodifiable(pieces);
        _executing = false;
        _transactionCompleted = true;
      });

      for (var index = 0; index < pieces.length; index++) {
        if (!mounted) return;
        await Future<void>.delayed(_adoptionPieceDuration(index));
        if (!mounted) return;
        setState(() => _settledCount = index + 1);
        final template = _adoptionTemplateAt(index, pieces.length);
        final batchStart = _adoptionBatchStart(index, pieces.length);
        if (index + 1 == batchStart + template.length) {
          setState(() => _clearing = true);
          await Future<void>.delayed(const Duration(milliseconds: 180));
          if (!mounted) return;
          setState(() => _clearing = false);
        }
      }
      if (!mounted) return;
      setState(() {
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

  Duration _adoptionPieceDuration(int index) {
    if (index < 4) return const Duration(milliseconds: 320);
    if (index < 12) return const Duration(milliseconds: 180);
    return const Duration(milliseconds: 105);
  }

  Future<void> _exit(_BatchAdoptionDialogOutcome outcome) async {
    if (_exiting || _executing) return;
    setState(() => _exiting = true);
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

    final revealController = _revealController ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    final back = _buildBackConsole(context);
    return _buildModalPortal(
      AnimatedBuilder(
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
          return _buildModalLayer(
            context,
            progress: opacity,
            console: AbsorbPointer(
              absorbing: revealController.isAnimating,
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
            ),
          );
        },
      ),
    );
  }

  Widget _buildModalPortal(Widget modal) {
    return OverlayPortal(
      controller: _modalOverlay,
      overlayLocation: OverlayChildLocation.rootOverlay,
      overlayChildBuilder: (context) => Positioned.fill(child: modal),
      child: const SizedBox.shrink(),
    );
  }

  Widget _buildModalLayer(
    BuildContext context, {
    required Widget console,
    required double progress,
  }) {
    final canDismiss = !_executing && !_exiting;
    return Stack(
      key: const Key('batch-adoption-modal'),
      fit: StackFit.expand,
      children: [
        ModalBarrier(
          key: const Key('batch-adoption-modal-barrier'),
          color: Colors.black.withValues(alpha: .36 * progress),
          dismissible: canDismiss,
          onDismiss: canDismiss
              ? () => unawaited(
                  _exit(
                    _transactionCompleted
                        ? _BatchAdoptionDialogOutcome.completed
                        : _BatchAdoptionDialogOutcome.skipped,
                  ),
                )
              : null,
          semanticsLabel: _transactionCompleted
              ? context.l10n.batchAdoptionClose
              : context.l10n.batchAdoptionSkip,
          barrierSemanticsDismissible: canDismiss,
        ),
        console,
      ],
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
          key: const Key('batch-adoption-dialog'),
          child: _AdoptionHardwareShell(
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
                          color: _transactionCompleted
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
                        _transactionCompleted
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
                    child: _BatchAdoptionStory(
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
                  const SizedBox(height: 9),
                  _AdoptionStickerControls(
                    completed: _transactionCompleted || _error != null,
                    onClose: () => _exit(_BatchAdoptionDialogOutcome.completed),
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
        key: Key('batch-adoption-console-back'),
        child: _AdoptionHardwareShell(child: _AdoptionHardwareBack()),
      ),
    ),
  );
}

class _AdoptionStickerControls extends StatelessWidget {
  const _AdoptionStickerControls({
    required this.completed,
    required this.onClose,
  });

  final bool completed;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const Key('batch-adoption-vintage-stickers'),
    height: 80,
    child: Row(
      children: [
        Expanded(
          key: const Key('batch-adoption-sticker-image-region'),
          flex: 2,
          child: Center(
            child: Transform.scale(
              scale: 1.24,
              child: Transform.rotate(
                angle: -.09,
                child: Image.asset(
                  'assets/branding/sticker-image.webp',
                  key: const Key('batch-adoption-sticker-image'),
                  width: 108,
                  height: 76,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          key: const Key('batch-adoption-control-region'),
          child: Center(
            child: _AdoptionHardwareButton(
              key: Key(
                completed ? 'batch-adoption-close' : 'batch-adoption-importing',
              ),
              enabled: completed,
              preserveDisabledColor: true,
              primary: true,
              onPressed: completed ? onClose : null,
              label: completed
                  ? context.l10n.batchAdoptionClose
                  : context.l10n.batchAdoptionPending,
            ),
          ),
        ),
        Expanded(
          key: const Key('batch-adoption-sticker-text-region'),
          flex: 2,
          child: Center(
            child: Transform.rotate(
              angle: .045,
              child: Image.asset(
                'assets/branding/sticker-text.webp',
                key: const Key('batch-adoption-sticker-text'),
                width: 146,
                height: 76,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                excludeFromSemantics: true,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _AdoptionHardwareBack extends StatelessWidget {
  const _AdoptionHardwareBack();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: 430,
      height: 590,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Stack(
          children: [
            const Positioned(left: 0, top: 0, child: _AdoptionBackScrew()),
            const Positioned(right: 0, top: 0, child: _AdoptionBackScrew()),
            const Positioned(left: 0, bottom: 0, child: _AdoptionBackScrew()),
            const Positioned(right: 0, bottom: 0, child: _AdoptionBackScrew()),
            Positioned(
              top: 48,
              left: 0,
              right: 0,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/branding/skillsgo-logo.webp',
                    key: const Key('batch-adoption-console-back-logo'),
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
                      fontFamily: 'AdoptionPixel',
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
                            fontFamily: 'AdoptionPixel',
                            fontSize: 8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const _AdoptionBackVent(),
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

class _AdoptionBackScrew extends StatelessWidget {
  const _AdoptionBackScrew();

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

class _AdoptionBackVent extends StatelessWidget {
  const _AdoptionBackVent();

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

class _AdoptionHardwareShell extends StatelessWidget {
  const _AdoptionHardwareShell({required this.child});

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

class _AdoptionHardwareButton extends StatefulWidget {
  const _AdoptionHardwareButton({
    super.key,
    required this.label,
    required this.primary,
    required this.enabled,
    required this.onPressed,
    this.preserveDisabledColor = false,
  });

  final String label;
  final bool primary;
  final bool enabled;
  final VoidCallback? onPressed;
  final bool preserveDisabledColor;

  @override
  State<_AdoptionHardwareButton> createState() =>
      _AdoptionHardwareButtonState();
}

class _AdoptionHardwareButtonState extends State<_AdoptionHardwareButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || !widget.enabled) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final visuallyEnabled = widget.enabled || widget.preserveDisabledColor;
    final buttonColor = visuallyEnabled
        ? widget.primary
              ? const Color(0xffd95750)
              : const Color(0xffaaa397)
        : const Color(0xffb8b1a5);
    final edgeColor = widget.primary
        ? const Color(0xff973c37)
        : const Color(0xff746f66);
    final duration = const Duration(milliseconds: 70);
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
                            ? 'batch-adoption-confirm-face'
                            : 'batch-adoption-skip-face',
                      ),
                      duration: duration,
                      curve: Curves.easeOut,
                      tween: Tween(end: _pressed ? 1 : 0),
                      builder: (context, press, child) => Transform.scale(
                        scale: 1 - .035 * press,
                        child: DecoratedBox(
                          key: Key(
                            widget.primary
                                ? 'batch-adoption-confirm-face-decoration'
                                : 'batch-adoption-skip-face-decoration',
                          ),
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
                            foregroundPainter: _AdoptionButtonHighlightPainter(
                              opacity: visuallyEnabled
                                  ? .38 * (1 - press)
                                  : .12,
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
                            fontFamily: 'AdoptionPixel',
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
                color: visuallyEnabled
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

class _AdoptionButtonHighlightPainter extends CustomPainter {
  const _AdoptionButtonHighlightPainter({required this.opacity});

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
  bool shouldRepaint(_AdoptionButtonHighlightPainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}

class _BatchAdoptionStory extends StatelessWidget {
  const _BatchAdoptionStory({
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
  final List<BatchAdoptionPreview> skillPreviews;
  final BatchAdoptionResult? result;
  final List<_AdoptionVisualPiece> pieces;
  final int settledCount;
  final bool clearing;
  final bool executing;
  final bool completed;

  List<_AdoptionIllustratedSkill> get _orderedSkills {
    final candidates = <_AdoptionIllustratedSkill>[];
    final seen = <String>{};
    for (final preview in skillPreviews) {
      final name = preview.name.trim();
      if (name.isEmpty) continue;
      if (!seen.add(_adoptionSkillKey(name, preview.skillId))) continue;
      candidates.add((name: name, skillId: preview.skillId));
    }
    final selected = <_AdoptionIllustratedSkill>[];
    final deferred = <_AdoptionIllustratedSkill>[];
    final packages = <String>{};
    for (final candidate in candidates) {
      if (packages.add(_adoptionPackageIdentity(candidate))) {
        selected.add(candidate);
      } else {
        deferred.add(candidate);
      }
    }
    selected.addAll(deferred);
    for (final fallback in _adoptionFallbackNames) {
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
          (piece) => _adoptionSkillKey(piece.skill!.name, piece.skill!.skillId),
        )
        .toSet();
    final orderedSkills = _orderedSkills;
    final plannedIndexBySkillKey = <String, int>{
      for (var index = 0; index < orderedSkills.length; index++)
        _adoptionSkillKey(
          orderedSkills[index].name,
          orderedSkills[index].skillId,
        ): index,
      for (var index = 0; index < pieces.length; index++)
        if (!pieces[index].isFiller && pieces[index].skill != null)
          _adoptionSkillKey(
            pieces[index].skill!.name,
            pieces[index].skill!.skillId,
          ): index,
    };
    final pending = orderedSkills
        .where(
          (skill) => !settledSkillKeys.contains(
            _adoptionSkillKey(skill.name, skill.skillId),
          ),
        )
        .toList(growable: false);
    final initialPlannedPieceCount =
        eligibleCount +
        _adoptionFillerCount(
          eligibleCount,
          trailingCount: _AdoptionPainPoint.values.length,
        ) +
        _AdoptionPainPoint.values.length;
    final plannedPieceCount = math.max(initialPlannedPieceCount, pieces.length);
    final remainingPainPoints = pieces.isEmpty
        ? _AdoptionPainPoint.values
        : pieces
              .skip(settledCount)
              .map((piece) => piece.painPoint)
              .whereType<_AdoptionPainPoint>()
              .toList(growable: false);
    final plannedIndexByPainPoint = <_AdoptionPainPoint, int>{
      if (pieces.isEmpty)
        for (var index = 0; index < _AdoptionPainPoint.values.length; index++)
          _AdoptionPainPoint.values[index]:
              plannedPieceCount - _AdoptionPainPoint.values.length + index
      else
        for (var index = 0; index < pieces.length; index++)
          if (pieces[index].painPoint != null) pieces[index].painPoint!: index,
    };
    final content = completed
        ? _AdoptionCompletedGameScreen(
            key: const ValueKey('settlement'),
            result: result,
            eligibleCount: eligibleCount,
          )
        : _AdoptionGameScreen(
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
      key: const Key('batch-adoption-tetris-story'),
      container: true,
      label: context.l10n.batchAdoptionBeforeSemantics,
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.center,
        child: _AdoptionRecessedLcd(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 420),
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

class _AdoptionCompletedGameScreen extends StatelessWidget {
  const _AdoptionCompletedGameScreen({
    super.key,
    required this.result,
    required this.eligibleCount,
  });

  final BatchAdoptionResult? result;
  final int eligibleCount;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: _AdoptionSettlementScreen(
          result: result,
          eligibleCount: eligibleCount,
        ),
      ),
      const SizedBox(width: 4),
      SizedBox(
        width: 122,
        child: _AdoptionPendingQueue(
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

class _AdoptionGameScreen extends StatelessWidget {
  const _AdoptionGameScreen({
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

  final List<_AdoptionVisualPiece> pieces;
  final int settledCount;
  final bool clearing;
  final int eligibleCount;
  final int settledRealCount;
  final BatchAdoptionResult? result;
  final bool executing;
  final List<_AdoptionIllustratedSkill> pending;
  final Map<String, int> plannedIndexBySkillKey;
  final List<_AdoptionPainPoint> painPoints;
  final Map<_AdoptionPainPoint, int> plannedIndexByPainPoint;
  final int plannedPieceCount;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: _AdoptionTetrisBoard(
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
        child: _AdoptionPendingQueue(
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

class _AdoptionSettlementScreen extends StatelessWidget {
  const _AdoptionSettlementScreen({
    required this.result,
    required this.eligibleCount,
  });

  final BatchAdoptionResult? result;
  final int eligibleCount;

  @override
  Widget build(BuildContext context) {
    final managed = result?.adopted ?? 0;
    final failed = result?.failed ?? 0;
    final allClear = failed == 0;
    return Semantics(
      key: const Key('batch-adoption-board-complete'),
      container: true,
      label: context.l10n.batchAdoptionFailureSummary(managed, failed),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _adoptionLcdPanel,
          border: Border.all(color: _adoptionLcdInk, width: 1.5),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: .24,
                child: CustomPaint(painter: _AdoptionSettlementGridPainter()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 44, 28, 24),
              child: Column(
                children: [
                  Text(
                    allClear
                        ? context.l10n.batchAdoptionBoardComplete
                        : context.l10n.batchAdoptionBoardPartial,
                    style: context.skillsTypography.sectionTitle.copyWith(
                      color: _adoptionLcdInk,
                      fontFamily: 'AdoptionPixel',
                      fontSize: 22,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(width: 84, height: 2, color: _adoptionLcdInk),
                  const Spacer(flex: 2),
                  _AdoptionSettlementStat(
                    label: context.l10n.batchAdoptionStatusManaged,
                    value: managed,
                  ),
                  const SizedBox(height: 18),
                  _AdoptionSettlementStat(
                    label: context.l10n.batchAdoptionStatusFailed,
                    value: failed,
                  ),
                  const SizedBox(height: 18),
                  _AdoptionSettlementStat(
                    label: context.l10n.batchAdoptionStatusTotal,
                    value: eligibleCount,
                  ),
                  const SizedBox(height: 18),
                  Container(
                    height: 1,
                    color: _adoptionLcdGrid.withValues(alpha: .72),
                  ),
                  const SizedBox(height: 14),
                  const _AdoptionBenefitSummary(),
                  const Spacer(),
                  const _AdoptionClearedRowsTrace(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdoptionBenefitSummary extends StatelessWidget {
  const _AdoptionBenefitSummary();

  @override
  Widget build(BuildContext context) {
    final benefits = [
      context.l10n.batchAdoptionBenefitLocation,
      context.l10n.batchAdoptionBenefitFreshness,
      context.l10n.batchAdoptionBenefitRecovery,
      context.l10n.batchAdoptionBenefitVersions,
    ];
    return Column(
      children: [
        for (var index = 0; index < benefits.length; index++) ...[
          _AdoptionBenefitRow(label: benefits[index]),
          if (index < benefits.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _AdoptionBenefitRow extends StatelessWidget {
  const _AdoptionBenefitRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.skillsTypography.caption.copyWith(
            color: _adoptionLcdInk,
            fontFamily: 'AdoptionPixel',
            fontSize: 9,
            letterSpacing: .2,
          ),
        ),
      ),
      const SizedBox(width: 8),
      const _AdoptionSettlementTrailingSlot(
        child: SizedBox(
          key: Key('batch-adoption-benefit-check'),
          width: 12,
          height: 12,
          child: CustomPaint(painter: _AdoptionPixelCheckPainter()),
        ),
      ),
    ],
  );
}

class _AdoptionSettlementTrailingSlot extends StatelessWidget {
  const _AdoptionSettlementTrailingSlot({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 28,
    height: 12,
    child: Align(alignment: Alignment.centerRight, child: child),
  );
}

class _AdoptionPixelCheckPainter extends CustomPainter {
  const _AdoptionPixelCheckPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _adoptionLcdInk
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
      Path()
        ..moveTo(size.width * .12, size.height * .54)
        ..lineTo(size.width * .4, size.height * .82)
        ..lineTo(size.width * .9, size.height * .18),
      paint,
    );
  }

  @override
  bool shouldRepaint(_AdoptionPixelCheckPainter oldDelegate) => false;
}

class _AdoptionSettlementStat extends StatelessWidget {
  const _AdoptionSettlementStat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label.toUpperCase(),
          style: context.skillsTypography.caption.copyWith(
            color: _adoptionLcdMutedInk,
            fontFamily: 'AdoptionPixel',
            fontSize: 9,
            letterSpacing: .4,
          ),
        ),
      ),
      _AdoptionSettlementTrailingSlot(
        child: _AdoptionLcdNumber(
          '$value',
          key: const Key('batch-adoption-stat-value'),
          color: _adoptionLcdInk,
        ),
      ),
    ],
  );
}

class _AdoptionClearedRowsTrace extends StatelessWidget {
  const _AdoptionClearedRowsTrace();

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: .52,
    child: Column(
      children: [
        for (var row = 0; row < 2; row++)
          Row(
            children: [
              for (var column = 0; column < _adoptionBoardColumns; column++)
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: _adoptionLcdGrid),
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

class _AdoptionSettlementGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _adoptionLcdGrid
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
  bool shouldRepaint(_AdoptionSettlementGridPainter oldDelegate) => false;
}

class _AdoptionRecessedLcd extends StatelessWidget {
  const _AdoptionRecessedLcd({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 390,
    height: 450,
    child: CustomPaint(
      painter: const _AdoptionRecessedLcdPainter(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(7, 7, 5, 6),
        child: child,
      ),
    ),
  );
}

class _AdoptionRecessedLcdPainter extends CustomPainter {
  const _AdoptionRecessedLcdPainter();

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

    canvas.drawRect(inner, Paint()..color = _adoptionLcdGlass);
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
  bool shouldRepaint(covariant _AdoptionRecessedLcdPainter oldDelegate) =>
      false;
}

class _AdoptionStatusPanel extends StatelessWidget {
  const _AdoptionStatusPanel({
    required this.eligibleCount,
    required this.settledCount,
    required this.result,
    required this.executing,
    required this.completed,
  });

  final int eligibleCount;
  final int settledCount;
  final BatchAdoptionResult? result;
  final bool executing;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final managed = completed ? result?.adopted ?? settledCount : settledCount;
    final failed = result?.failed ?? 0;
    final pending = math.max(0, eligibleCount - managed - failed);
    return DecoratedBox(
      key: const Key('batch-adoption-status-panel'),
      decoration: const BoxDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _AdoptionStatusItem(
              label: context.l10n.batchAdoptionPendingSection,
              value: '$pending',
            ),
          ),
          Expanded(
            child: _AdoptionStatusItem(
              label: context.l10n.batchAdoptionStatusManaged,
              value: '$managed',
              color: managed > 0 ? _adoptionLcdInk : null,
            ),
          ),
          Expanded(
            child: _AdoptionStatusItem(
              label: context.l10n.batchAdoptionStatusFailed,
              value: '$failed',
            ),
          ),
        ],
      ),
    );
  }
}

class _AdoptionStatusItem extends StatelessWidget {
  const _AdoptionStatusItem({
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
            color: _adoptionLcdMutedInk,
            fontSize: 9,
            height: 1.05,
            fontFamily: 'Menlo',
            letterSpacing: -.35,
          ),
        ),
        const SizedBox(height: 4),
        _AdoptionLcdNumber(value, color: color ?? _adoptionLcdInk),
      ],
    );
  }
}

class _AdoptionLcdNumber extends StatelessWidget {
  const _AdoptionLcdNumber(this.value, {super.key, required this.color});

  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: value,
    child: CustomPaint(
      size: Size(value.length * 7.0, 12),
      painter: _AdoptionLcdNumberPainter(value: value, color: color),
    ),
  );
}

class _AdoptionLcdNumberPainter extends CustomPainter {
  const _AdoptionLcdNumberPainter({required this.value, required this.color});

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
  bool shouldRepaint(_AdoptionLcdNumberPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.color != color;
}

class _AdoptionTetrisBoard extends StatelessWidget {
  const _AdoptionTetrisBoard({
    required this.pieces,
    required this.settledCount,
    required this.clearing,
    required this.eligibleCount,
    required this.settledRealCount,
    required this.result,
    required this.executing,
  });

  final List<_AdoptionVisualPiece> pieces;
  final int settledCount;
  final bool clearing;
  final int eligibleCount;
  final int settledRealCount;
  final BatchAdoptionResult? result;
  final bool executing;

  @override
  Widget build(BuildContext context) {
    assert(
      _adoptionTemplateIsExactCover(),
      'Adoption templates must exactly cover their intended board strips.',
    );
    final referenceIndex = clearing && settledCount > 0
        ? settledCount - 1
        : settledCount;
    final template = _adoptionTemplateAt(referenceIndex, pieces.length);
    final templateRows = _adoptionTemplateRows(template);
    final batchStart = _adoptionBatchStart(referenceIndex, pieces.length);
    final visibleSettled = clearing
        ? template.length
        : settledCount >= pieces.length
        ? 0
        : settledCount - batchStart;
    final activeIndex = !clearing && settledCount < pieces.length
        ? settledCount
        : null;
    return Semantics(
      key: const Key('batch-adoption-tetris-board'),
      container: true,
      label: context.l10n.batchAdoptionBoardSemantics,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _adoptionLcdPanel,
          border: Border.all(color: _adoptionLcdInk, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 7, 0, 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cell = math.min(
                (constraints.maxWidth - 20) / _adoptionBoardColumns,
                (constraints.maxHeight - 40) / _adoptionBoardRows,
              );
              final boardSize = Size(
                cell * _adoptionBoardColumns,
                cell * _adoptionBoardRows,
              );
              return Column(
                children: [
                  SizedBox(
                    height: 36,
                    child: Center(
                      child: SizedBox(
                        width: boardSize.width,
                        child: _AdoptionStatusPanel(
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
                            const Positioned.fill(child: _AdoptionBoardGrid()),
                            for (var index = 0; index < visibleSettled; index++)
                              _AdoptionPlacedPiece(
                                key: ValueKey('settled-${batchStart + index}'),
                                piece: pieces.isEmpty
                                    ? const _AdoptionVisualPiece(
                                        skill: null,
                                        isFiller: true,
                                      )
                                    : pieces[math.min(
                                        batchStart + index,
                                        pieces.length - 1,
                                      )],
                                plan: template[index],
                                cellSize: cell,
                                boardRows: _adoptionBoardRows,
                                templateRows: templateRows,
                                clearing: clearing,
                              ),
                            if (activeIndex != null)
                              _AdoptionDroppingPiece(
                                key: ValueKey('active-$activeIndex'),
                                piece: pieces[activeIndex],
                                plan: template[activeIndex - batchStart],
                                cellSize: cell,
                                boardRows: _adoptionBoardRows,
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

class _AdoptionBoardGrid extends StatelessWidget {
  const _AdoptionBoardGrid();

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _AdoptionBoardGridPainter(
      color: _adoptionLcdGrid.withValues(alpha: .58),
    ),
  );
}

class _AdoptionBoardGridPainter extends CustomPainter {
  const _AdoptionBoardGridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = .6;
    final cellWidth = size.width / _adoptionBoardColumns;
    final cellHeight = size.height / _adoptionBoardRows;
    for (var column = 0; column <= _adoptionBoardColumns; column++) {
      canvas.drawLine(
        Offset(column * cellWidth, 0),
        Offset(column * cellWidth, size.height),
        paint,
      );
    }
    for (var row = 0; row <= _adoptionBoardRows; row++) {
      canvas.drawLine(
        Offset(0, row * cellHeight),
        Offset(size.width, row * cellHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_AdoptionBoardGridPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _AdoptionDroppingPiece extends StatelessWidget {
  const _AdoptionDroppingPiece({
    super.key,
    required this.piece,
    required this.plan,
    required this.cellSize,
    required this.boardRows,
    required this.templateRows,
    required this.duration,
  });

  final _AdoptionVisualPiece piece;
  final _AdoptionPiecePlan plan;
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
      final initialQuarterTurns = _adoptionInitialQuarterTurns(plan.type);
      return _AdoptionPieceCells(
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

int _adoptionInitialQuarterTurns(_AdoptionPieceType type) => switch (type) {
  _AdoptionPieceType.o => 0,
  _AdoptionPieceType.i || _AdoptionPieceType.s || _AdoptionPieceType.j => 1,
  _AdoptionPieceType.t || _AdoptionPieceType.z || _AdoptionPieceType.l => -1,
};

class _AdoptionPlacedPiece extends StatelessWidget {
  const _AdoptionPlacedPiece({
    super.key,
    required this.piece,
    required this.plan,
    required this.cellSize,
    required this.boardRows,
    required this.templateRows,
    required this.clearing,
  });

  final _AdoptionVisualPiece piece;
  final _AdoptionPiecePlan plan;
  final double cellSize;
  final int boardRows;
  final int templateRows;
  final bool clearing;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    duration: const Duration(milliseconds: 160),
    opacity: clearing ? .22 : 1,
    child: _AdoptionPieceCells(
      piece: piece,
      plan: plan,
      cellSize: cellSize,
      rowOffset: (boardRows - templateRows).toDouble(),
    ),
  );
}

class _AdoptionPieceCells extends StatelessWidget {
  const _AdoptionPieceCells({
    required this.piece,
    required this.plan,
    required this.cellSize,
    required this.rowOffset,
    this.columnOffset = 0,
    this.rotationRadians = 0,
  });

  final _AdoptionVisualPiece piece;
  final _AdoptionPiecePlan plan;
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
                    ? _AdoptionLedCell(
                        color: _adoptionPainPointColor(piece.painPoint!),
                        child: index == plan.coreCellIndex
                            ? _AdoptionPieceIdentity(piece: piece)
                            : null,
                      )
                    : isAvatarCell
                    ? _AdoptionPieceIdentity(piece: piece)
                    : _AdoptionBlackCell(
                        child: index == plan.coreCellIndex
                            ? _AdoptionPieceIdentity(piece: piece)
                            : null,
                      ),
              );
            },
          ),
      ],
    );
  }
}

class _AdoptionPieceIdentity extends StatelessWidget {
  const _AdoptionPieceIdentity({required this.piece});

  final _AdoptionVisualPiece piece;

  @override
  Widget build(BuildContext context) {
    final painPoint = piece.painPoint;
    if (painPoint != null) {
      return CustomPaint(
        painter: _AdoptionPainPointSymbolPainter(
          painPoint: painPoint,
          color: _adoptionLcdInk,
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
          child: PackageAvatar(
            source: skill.skillId,
            imageUrl: _packageAvatarUrl(skill.skillId),
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

class _AdoptionLedCell extends StatelessWidget {
  const _AdoptionLedCell({required this.color, this.child});

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

class _AdoptionPainPointSymbolPainter extends CustomPainter {
  const _AdoptionPainPointSymbolPainter({
    required this.painPoint,
    required this.color,
  });

  final _AdoptionPainPoint painPoint;
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
      case _AdoptionPainPoint.location:
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
      case _AdoptionPainPoint.freshness:
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
      case _AdoptionPainPoint.recovery:
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
      case _AdoptionPainPoint.versionDrift:
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
  bool shouldRepaint(_AdoptionPainPointSymbolPainter oldDelegate) =>
      oldDelegate.painPoint != painPoint || oldDelegate.color != color;
}

class _AdoptionBlackCell extends StatelessWidget {
  const _AdoptionBlackCell({this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: _adoptionLcdInk, width: 1),
    ),
    child: Padding(
      padding: const EdgeInsets.all(2),
      child: ColoredBox(
        color: _adoptionLcdInk,
        child: child == null ? null : Center(child: child),
      ),
    ),
  );
}

class _AdoptionPendingQueue extends StatefulWidget {
  const _AdoptionPendingQueue({
    required this.skills,
    required this.painPoints,
    required this.plannedIndexBySkillKey,
    required this.plannedIndexByPainPoint,
    required this.plannedPieceCount,
    required this.result,
    required this.fillerCount,
    required this.showWaitingMessage,
  });

  final List<_AdoptionIllustratedSkill> skills;
  final List<_AdoptionPainPoint> painPoints;
  final Map<String, int> plannedIndexBySkillKey;
  final Map<_AdoptionPainPoint, int> plannedIndexByPainPoint;
  final int plannedPieceCount;
  final BatchAdoptionResult? result;
  final int fillerCount;
  final bool showWaitingMessage;

  @override
  State<_AdoptionPendingQueue> createState() => _AdoptionPendingQueueState();
}

class _AdoptionPendingQueueState extends State<_AdoptionPendingQueue> {
  final ScrollController _controller = ScrollController();

  @override
  void didUpdateWidget(_AdoptionPendingQueue oldWidget) {
    super.didUpdateWidget(oldWidget);
    final itemCount = widget.skills.length + widget.painPoints.length;
    final oldItemCount = oldWidget.skills.length + oldWidget.painPoints.length;
    if (itemCount >= oldItemCount) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_controller.hasClients) return;
      _controller.animateTo(
        math.min(_controller.offset + 58, _controller.position.maxScrollExtent),
        duration: const Duration(milliseconds: 180),
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
      key: const Key('batch-adoption-pending-queue'),
      decoration: const BoxDecoration(color: _adoptionLcdGlass),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.batchAdoptionNextLabel,
                    style: context.skillsTypography.caption.copyWith(
                      color: _adoptionLcdInk,
                      fontFamily: 'AdoptionPixel',
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      letterSpacing: .8,
                    ),
                  ),
                ),
                _AdoptionLcdNumber(
                  '${widget.skills.length + widget.painPoints.length}',
                  color: _adoptionLcdMutedInk,
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
                        context.l10n.batchAdoptionQueueWaiting,
                        textAlign: TextAlign.center,
                        style: context.skillsTypography.caption.copyWith(
                          color: _adoptionLcdMutedInk,
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
                        key: const Key('batch-adoption-pending-list'),
                        controller: _controller,
                        padding: EdgeInsets.zero,
                        itemCount:
                            widget.skills.length + widget.painPoints.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          if (index >= widget.skills.length) {
                            final painPoint =
                                widget.painPoints[index - widget.skills.length];
                            return _AdoptionPainQueueItem(
                              painPoint: painPoint,
                              planIndex:
                                  widget.plannedIndexByPainPoint[painPoint] ??
                                  0,
                              plannedPieceCount: widget.plannedPieceCount,
                            );
                          }
                          final skill = widget.skills[index];
                          return _AdoptionQueueItem(
                            skill: skill,
                            planIndex:
                                widget.plannedIndexBySkillKey[_adoptionSkillKey(
                                  skill.name,
                                  skill.skillId,
                                )] ??
                                _adoptionStableIndex(skill) %
                                    widget.plannedPieceCount,
                            plannedPieceCount: widget.plannedPieceCount,
                            failureReason: _failureReason(skill),
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

  String _failureReason(_AdoptionIllustratedSkill skill) =>
      widget.result?.items
          .where(
            (item) =>
                item.status == BatchAdoptionItemStatus.failed &&
                _adoptionSkillKey(item.name, item.skillId) ==
                    _adoptionSkillKey(skill.name, skill.skillId),
          )
          .firstOrNull
          ?.reason ??
      '';
}

class _AdoptionQueueItem extends StatelessWidget {
  const _AdoptionQueueItem({
    required this.skill,
    required this.planIndex,
    required this.plannedPieceCount,
    required this.failureReason,
  });

  final _AdoptionIllustratedSkill skill;
  final int planIndex;
  final int plannedPieceCount;
  final String failureReason;

  @override
  Widget build(BuildContext context) {
    final piece = _AdoptionVisualPiece(skill: skill, isFiller: false);
    final template = _adoptionTemplateAt(planIndex, plannedPieceCount);
    final batchStart = _adoptionBatchStart(planIndex, plannedPieceCount);
    final plan = template[planIndex - batchStart];
    final failed = failureReason.isNotEmpty;
    final content = Semantics(
      label: failed
          ? '${context.l10n.batchAdoptionItemFailed(skill.name)}: $failureReason'
          : context.l10n.batchAdoptionItemPending(skill.name),
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
                  child: _AdoptionQueuePiece(piece: piece, plan: plan),
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
                  color: failed ? _adoptionLcdMutedInk : _adoptionLcdInk,
                  fontFamily: 'AdoptionPixel',
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
    return failed ? Tooltip(message: failureReason, child: content) : content;
  }
}

class _AdoptionPainQueueItem extends StatelessWidget {
  const _AdoptionPainQueueItem({
    required this.painPoint,
    required this.planIndex,
    required this.plannedPieceCount,
  });

  final _AdoptionPainPoint painPoint;
  final int planIndex;
  final int plannedPieceCount;

  @override
  Widget build(BuildContext context) {
    final piece = _AdoptionVisualPiece(
      skill: null,
      isFiller: false,
      painPoint: painPoint,
    );
    final template = _adoptionTemplateAt(planIndex, plannedPieceCount);
    final batchStart = _adoptionBatchStart(planIndex, plannedPieceCount);
    final plan = template[planIndex - batchStart];
    final name = _adoptionPainPointName(context, painPoint);
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
                  child: _AdoptionQueuePiece(piece: piece, plan: plan),
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
                  color: _adoptionLcdInk,
                  fontFamily: 'AdoptionPixel',
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

class _AdoptionQueuePiece extends StatelessWidget {
  const _AdoptionQueuePiece({required this.piece, required this.plan});

  final _AdoptionVisualPiece piece;
  final _AdoptionPiecePlan plan;

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
                    ? _AdoptionLedCell(
                        color: _adoptionPainPointColor(piece.painPoint!),
                        child: index == plan.coreCellIndex
                            ? _AdoptionPieceIdentity(piece: piece)
                            : null,
                      )
                    : isAvatarCell
                    ? _AdoptionPieceIdentity(piece: piece)
                    : _AdoptionBlackCell(
                        child: index == plan.coreCellIndex
                            ? _AdoptionPieceIdentity(piece: piece)
                            : null,
                      ),
              );
            },
          ),
      ],
    );
  }
}

int _adoptionStableIndex(_AdoptionIllustratedSkill skill) {
  var value = 0;
  for (final unit in '${skill.skillId}\u0000${skill.name}'.codeUnits) {
    value = ((value * 31) + unit) & 0x7fffffff;
  }
  return value;
}

String _adoptionPackageIdentity(_AdoptionIllustratedSkill skill) {
  final skillId = skill.skillId.trim();
  if (skillId.isEmpty) return 'unresolved:${skill.name}';
  final separator = skillId.indexOf('/-/');
  return separator < 0 ? skillId : skillId.substring(0, separator);
}

String _adoptionSkillKey(String name, String skillId) =>
    '${skillId.trim()}\u0000${name.trim()}';
