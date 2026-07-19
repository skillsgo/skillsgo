/*
 * Derived from Portal Labs Stacked Toast Interaction, Copyright (c) 2026 Luis Portal, MIT License.
 * See /app/THIRD_PARTY_NOTICES.md for the complete attribution and license text.
 * [INPUT]: Depends on Flutter Material animation, physics, semantics, and haptic APIs plus HugeIcons rendering.
 * [OUTPUT]: Provides a controller-driven, animated stack of compact SkillsGo-styled success, warning, information, and error toasts.
 * [POS]: Serves as the vendored transient-feedback component shared by App UI operation surfaces.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

enum StackedToastType { info, warning, success, error, custom }

class StackedToastItem {
  const StackedToastItem({
    required this.id,
    this.title = '',
    this.message = '',
    this.type = StackedToastType.info,
    this.duration = const Duration(seconds: 2),
    this.actionLabel = 'Close',
    this.onAction,
  });

  final String id;
  final String title;
  final String message;
  final StackedToastType type;
  final Duration duration;
  final String actionLabel;
  final VoidCallback? onAction;
}

class StackedToastStyle {
  const StackedToastStyle({
    this.horizontalPadding = 16,
    this.maxStackedItems = 3,
    this.stackOffset = 9,
    this.stackScaleFactor = .035,
    this.topMargin = 10,
    this.spring,
  });

  final double horizontalPadding;
  final int maxStackedItems;
  final double stackOffset;
  final double stackScaleFactor;
  final double topMargin;
  final SpringDescription? spring;
}

class StackedToastController {
  _StackedToastInteractionState? _state;

  void _attach(_StackedToastInteractionState state) => _state = state;
  void _detach() => _state = null;
  void show(StackedToastItem toast) => _state?.showToast(toast);
}

class StackedToastInteraction extends StatefulWidget {
  const StackedToastInteraction({
    super.key,
    this.controller,
    this.style = const StackedToastStyle(),
    this.animationDuration = const Duration(milliseconds: 420),
  });

  final StackedToastController? controller;
  final StackedToastStyle style;
  final Duration animationDuration;

  @override
  State<StackedToastInteraction> createState() =>
      _StackedToastInteractionState();
}

class _StackedToastInteractionState extends State<StackedToastInteraction> {
  final activeToasts = <StackedToastItem>[];
  final exitingToastIds = <String>{};
  final toastTimers = <String, Timer>{};

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
  }

  @override
  void dispose() {
    widget.controller?._detach();
    for (final timer in toastTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  void showToast(StackedToastItem item) {
    setState(() => activeToasts.insert(0, item));
    toastTimers[item.id] = Timer(item.duration, () => _removeToast(item.id));
  }

  void _removeToast(String id) {
    if (!mounted || exitingToastIds.contains(id)) return;
    setState(() => exitingToastIds.add(id));
    Future<void>.delayed(widget.animationDuration, () {
      if (!mounted) return;
      setState(() {
        activeToasts.removeWhere((toast) => toast.id == id);
        exitingToastIds.remove(id);
        toastTimers.remove(id)?.cancel();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final topPadding =
        MediaQuery.paddingOf(context).top + widget.style.topMargin;
    return Stack(
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      children: [
        ...activeToasts
            .asMap()
            .entries
            .map((entry) {
              final index = entry.key;
              final toast = entry.value;
              final exiting = exitingToastIds.contains(toast.id);
              if (index >= widget.style.maxStackedItems && !exiting) {
                return const SizedBox.shrink();
              }
              return _AnimatedToastCard(
                key: ValueKey(toast.id),
                toast: toast,
                index: index,
                exiting: exiting,
                style: widget.style,
                duration: widget.animationDuration,
                topPadding: topPadding,
                onClose: () => _removeToast(toast.id),
              );
            })
            .toList()
            .reversed,
      ],
    );
  }
}

class _AnimatedToastCard extends StatefulWidget {
  const _AnimatedToastCard({
    required super.key,
    required this.toast,
    required this.index,
    required this.exiting,
    required this.style,
    required this.duration,
    required this.topPadding,
    required this.onClose,
  });

  final StackedToastItem toast;
  final int index;
  final bool exiting;
  final StackedToastStyle style;
  final Duration duration;
  final double topPadding;
  final VoidCallback onClose;

  @override
  State<_AnimatedToastCard> createState() => _AnimatedToastCardState();
}

class _AnimatedToastCardState extends State<_AnimatedToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: this, duration: widget.duration);
    _runSpring(entering: true);
  }

  @override
  void didUpdateWidget(covariant _AnimatedToastCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.exiting && !oldWidget.exiting) _runSpring(entering: false);
  }

  void _runSpring({required bool entering}) {
    final spring =
        widget.style.spring ??
        const SpringDescription(mass: 1, stiffness: 190, damping: 23);
    controller.animateWith(
      SpringSimulation(
        spring,
        controller.value,
        entering ? 1 : 0,
        entering ? 2.1 : -2.1,
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, child) {
      final progress = controller.value;
      final front = widget.index == 0;
      final offset =
          (1 - progress) * -140 + widget.index * widget.style.stackOffset;
      final scale =
          (.97 + .03 * progress) - widget.index * widget.style.stackScaleFactor;
      final opacity = progress * (1 - widget.index * .14).clamp(0, 1);
      return Positioned(
        top: widget.topPadding + offset,
        left: widget.style.horizontalPadding,
        right: widget.style.horizontalPadding,
        child: GestureDetector(
          onVerticalDragEnd: (details) {
            if (front && (details.primaryVelocity ?? 0) < -100) {
              HapticFeedback.lightImpact();
              widget.onClose();
            }
          },
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity.clamp(0, 1),
              child: _ToastContent(
                toast: widget.toast,
                interactive: front && progress > .9,
                onClose: widget.onClose,
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _ToastContent extends StatelessWidget {
  const _ToastContent({
    required this.toast,
    required this.interactive,
    required this.onClose,
  });

  final StackedToastItem toast;
  final bool interactive;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantics = _semantics(scheme);
    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: 0,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: .55),
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: .10),
              blurRadius: 22,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: Row(
          children: [
            HugeIcon(
              icon: semantics.icon,
              color: semantics.color,
              size: 21,
              strokeWidth: 1.7,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    toast.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -.15,
                    ),
                  ),
                  if (toast.message.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      toast.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (interactive) ...[
              const SizedBox(width: 10),
              Semantics(
                button: true,
                label: toast.actionLabel,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () {
                    toast.onAction?.call();
                    onClose();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    child: Text(
                      toast.actionLabel,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  _ToastSemantics _semantics(ColorScheme scheme) => switch (toast.type) {
    StackedToastType.info => _ToastSemantics(
      color: scheme.primary,
      icon: HugeIcons.strokeRoundedInformationCircle,
    ),
    StackedToastType.warning => const _ToastSemantics(
      color: Color(0xFFB76E00),
      icon: HugeIcons.strokeRoundedAlert02,
    ),
    StackedToastType.success => const _ToastSemantics(
      color: Color(0xFF2E8B57),
      icon: HugeIcons.strokeRoundedCheckmarkCircle02,
    ),
    StackedToastType.error => _ToastSemantics(
      color: scheme.error,
      icon: HugeIcons.strokeRoundedAlertCircle,
    ),
    StackedToastType.custom => _ToastSemantics(
      color: scheme.onSurfaceVariant,
      icon: HugeIcons.strokeRoundedNotification02,
    ),
  };
}

class _ToastSemantics {
  const _ToastSemantics({required this.color, required this.icon});

  final Color color;
  final List<List<dynamic>> icon;
}
