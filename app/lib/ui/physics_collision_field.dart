/*
 * Derived from Portal Labs Physics Collision Card, Copyright (c) 2026 Luis Portal, MIT License.
 * See /app/THIRD_PARTY_NOTICES.md for the complete attribution and license text.
 * [INPUT]: Depends on Flutter rendering, ticker, gestures, haptics, caller-provided stable item identities, widgets, and physical parameters.
 * [OUTPUT]: Provides a deterministic, draggable oriented-box collision field with identity-preserving rebuilds, gravity, damping, SAT wall/body collisions, rotation, sleep, and reduced-motion support.
 * [POS]: Serves as the locally adapted Portal Labs physics interaction primitive whose collision geometry matches rectangular visual children.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

@immutable
class PhysicsCollisionFieldItem {
  const PhysicsCollisionFieldItem({
    this.id,
    required this.child,
    required this.collisionSize,
    this.mass,
    this.initialPosition,
    this.initialVelocity = Offset.zero,
    this.decoration,
    this.clipToCircle = true,
  });

  final Object? id;
  final Widget child;
  final Size collisionSize;
  final double? mass;
  final Offset? initialPosition;
  final Offset initialVelocity;
  final BoxDecoration? decoration;
  final bool clipToCircle;
}

@immutable
class PhysicsCollisionFieldStyle {
  const PhysicsCollisionFieldStyle({
    required this.decoration,
    required this.itemDecoration,
    this.gravity = const Offset(0, 900),
    this.restitution = .7,
    this.damping = .2,
    this.enableHaptics = false,
    this.hapticThreshold = 80,
    this.showGrid = true,
    required this.gridColor,
    this.gridSpacing = 28,
  });

  final BoxDecoration decoration;
  final BoxDecoration itemDecoration;
  final Offset gravity;
  final double restitution;
  final double damping;
  final bool enableHaptics;
  final double hapticThreshold;
  final bool showGrid;
  final Color gridColor;
  final double gridSpacing;
}

/// A locally owned adaptation of Portal Labs' Physics Collision Card.
///
/// Bodies use oriented rectangular collision bounds matching their visual
/// children. Deterministic fallback positions keep screenshots and tests
/// stable. Motion automatically stops when animations are disabled.
class PhysicsCollisionField extends StatefulWidget {
  const PhysicsCollisionField({
    super.key,
    required this.items,
    required this.style,
    this.height = 280,
    this.motionEnabled = true,
    this.interactionEnabled = true,
    this.seed = 7,
  });

  final List<PhysicsCollisionFieldItem> items;
  final PhysicsCollisionFieldStyle style;
  final double height;
  final bool motionEnabled;
  final bool interactionEnabled;
  final int seed;

  @override
  State<PhysicsCollisionField> createState() => _PhysicsCollisionFieldState();
}

class _PhysicsCollisionFieldState extends State<PhysicsCollisionField>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final List<_PhysicsBody> _bodies = [];
  Size _containerSize = Size.zero;
  double _lastElapsedSeconds = 0;
  bool _sleeping = false;
  int _restFrames = 0;
  DateTime? _lastHapticTime;

  bool get _motionAllowed =>
      widget.motionEnabled &&
      TickerMode.valuesOf(context).enabled &&
      !MediaQuery.disableAnimationsOf(context);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_updatePhysics);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_motionAllowed) {
      _wakeUp();
    } else {
      _ticker.stop();
      _lastElapsedSeconds = 0;
    }
  }

  @override
  void didUpdateWidget(covariant PhysicsCollisionField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bodiesChanged = !_sameBodies(oldWidget.items, widget.items);
    if (bodiesChanged || oldWidget.seed != widget.seed) {
      _initializeBodies();
    } else {
      for (var index = 0; index < _bodies.length; index++) {
        _bodies[index].child = widget.items[index].child;
      }
    }
    if (!oldWidget.motionEnabled && _motionAllowed) {
      _wakeUp();
    } else if (!_motionAllowed) {
      _ticker.stop();
    }
  }

  bool _sameBodies(
    List<PhysicsCollisionFieldItem> previous,
    List<PhysicsCollisionFieldItem> next,
  ) {
    if (previous.length != next.length) return false;
    for (var index = 0; index < previous.length; index++) {
      final before = previous[index];
      final after = next[index];
      if (before.id == null ||
          after.id == null ||
          before.id != after.id ||
          before.collisionSize != after.collisionSize ||
          before.mass != after.mass ||
          before.initialPosition != after.initialPosition ||
          before.initialVelocity != after.initialVelocity ||
          before.clipToCircle != after.clipToCircle) {
        return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _initializeBodies() {
    if (_containerSize == Size.zero) return;
    _bodies.clear();
    final random = math.Random(widget.seed);
    for (var index = 0; index < widget.items.length; index++) {
      final item = widget.items[index];
      final size = Size(
        math.min(item.collisionSize.width, _containerSize.width),
        math.min(item.collisionSize.height, _containerSize.height),
      );
      final radius =
          math.sqrt(size.width * size.width + size.height * size.height) / 2;
      final position = item.initialPosition == null
          ? _findNonOverlappingPosition(radius, random)
          : _clampPosition(item.initialPosition!, radius);
      _bodies.add(
        _PhysicsBody(
          position: position,
          velocity: item.initialVelocity,
          size: size,
          mass: item.mass ?? size.width * size.height,
          child: item.child,
          decoration: item.decoration,
          clipToCircle: item.clipToCircle,
          lastDragPosition: position,
        ),
      );
    }
    _restFrames = 0;
    if (_motionAllowed) _wakeUp();
    if (mounted) setState(() {});
  }

  Offset _findNonOverlappingPosition(double radius, math.Random random) {
    final minX = radius;
    final maxX = math.max(minX, _containerSize.width - radius);
    final minY = radius;
    final maxY = math.max(minY, _containerSize.height - radius);
    for (var attempt = 0; attempt < 20; attempt++) {
      final candidate = Offset(
        minX + random.nextDouble() * (maxX - minX),
        minY + random.nextDouble() * (maxY - minY),
      );
      if (_bodies.every(
        (body) =>
            (body.position - candidate).distance >=
            body.boundingRadius + radius,
      )) {
        return candidate;
      }
    }
    return Offset(
      minX + random.nextDouble() * (maxX - minX),
      minY + random.nextDouble() * (maxY - minY),
    );
  }

  Offset _clampPosition(Offset position, double radius) => Offset(
    position.dx.clamp(radius, math.max(radius, _containerSize.width - radius)),
    position.dy.clamp(radius, math.max(radius, _containerSize.height - radius)),
  );

  Offset _clampBodyPosition(Offset position, _PhysicsBody body) {
    final extent = body.axisAlignedExtent;
    return Offset(
      position.dx.clamp(
        extent.width,
        math.max(extent.width, _containerSize.width - extent.width),
      ),
      position.dy.clamp(
        extent.height,
        math.max(extent.height, _containerSize.height - extent.height),
      ),
    );
  }

  void _wakeUp() {
    if (!_motionAllowed) return;
    if (_sleeping || !_ticker.isActive) {
      _sleeping = false;
      _restFrames = 0;
      _lastElapsedSeconds = 0;
      if (!_ticker.isActive) _ticker.start();
    }
  }

  void _updatePhysics(Duration elapsed) {
    if (_containerSize == Size.zero || !_motionAllowed) return;
    final elapsedSeconds =
        elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    if (_lastElapsedSeconds == 0) {
      _lastElapsedSeconds = elapsedSeconds;
      return;
    }
    final dt = (elapsedSeconds - _lastElapsedSeconds).clamp(0, .03);
    _lastElapsedSeconds = elapsedSeconds;
    if (dt == 0) return;
    const substeps = 6;
    final substep = dt / substeps;
    for (var step = 0; step < substeps; step++) {
      for (final body in _bodies) {
        if (body.dragged) continue;
        body.velocity += widget.style.gravity * substep;
        body.velocity *= 1 - widget.style.damping * substep;
        body.position += body.velocity * substep;
        body.angle += body.angularVelocity * substep;
        body.angularVelocity *= 1 - widget.style.damping * substep;
      }
      for (final body in _bodies) {
        _resolveWallCollision(body);
      }
      for (var first = 0; first < _bodies.length; first++) {
        for (var second = first + 1; second < _bodies.length; second++) {
          _resolveBodyCollision(_bodies[first], _bodies[second]);
        }
      }
    }

    final atRest = _bodies.every(
      (body) =>
          !body.dragged &&
          body.velocity.distanceSquared <= 16 &&
          body.angularVelocity.abs() <= .1,
    );
    if (atRest) {
      _restFrames++;
      if (_restFrames > 30) {
        for (final body in _bodies) {
          body
            ..velocity = Offset.zero
            ..angularVelocity = 0;
        }
        _ticker.stop();
        _sleeping = true;
        _restFrames = 0;
      }
    } else {
      _restFrames = 0;
    }
    if (mounted) setState(() {});
  }

  void _resolveWallCollision(_PhysicsBody body) {
    final extent = body.axisAlignedExtent;
    var position = body.position;
    var velocity = body.velocity;
    var impact = 0.0;
    if (position.dx - extent.width < 0 && velocity.dx < 0) {
      impact = math.max(impact, velocity.dx.abs());
      position = Offset(extent.width, position.dy);
      velocity = Offset(-velocity.dx * widget.style.restitution, velocity.dy);
    } else if (position.dx + extent.width > _containerSize.width &&
        velocity.dx > 0) {
      impact = math.max(impact, velocity.dx.abs());
      position = Offset(_containerSize.width - extent.width, position.dy);
      velocity = Offset(-velocity.dx * widget.style.restitution, velocity.dy);
    }
    if (position.dy - extent.height < 0 && velocity.dy < 0) {
      impact = math.max(impact, velocity.dy.abs());
      position = Offset(position.dx, extent.height);
      velocity = Offset(velocity.dx, -velocity.dy * widget.style.restitution);
    } else if (position.dy + extent.height > _containerSize.height &&
        velocity.dy > 0) {
      impact = math.max(impact, velocity.dy.abs());
      position = Offset(position.dx, _containerSize.height - extent.height);
      velocity = Offset(velocity.dx, -velocity.dy * widget.style.restitution);
    }
    body
      ..position = position
      ..velocity = velocity;
    if (impact > 0) _triggerHaptics(impact);
  }

  void _resolveBodyCollision(_PhysicsBody first, _PhysicsBody second) {
    final delta = second.position - first.position;
    var overlap = double.infinity;
    var unit = Offset.zero;
    for (final axis in [...first.axes, ...second.axes]) {
      final distance = (delta.dx * axis.dx + delta.dy * axis.dy).abs();
      final penetration =
          first.projectionRadius(axis) +
          second.projectionRadius(axis) -
          distance;
      if (penetration <= 0) return;
      if (penetration < overlap) {
        overlap = penetration;
        final direction = delta.dx * axis.dx + delta.dy * axis.dy;
        unit = direction < 0 ? -axis : axis;
      }
    }
    if (first.dragged && second.dragged) return;
    if (first.dragged) {
      second.position += unit * overlap;
    } else if (second.dragged) {
      first.position -= unit * overlap;
    } else {
      final totalMass = first.mass + second.mass;
      first.position -= unit * overlap * (second.mass / totalMass);
      second.position += unit * overlap * (first.mass / totalMass);
    }

    final relativeVelocity = second.velocity - first.velocity;
    final normalVelocity =
        relativeVelocity.dx * unit.dx + relativeVelocity.dy * unit.dy;
    if (normalVelocity > 0) return;
    final firstInverseMass = first.dragged ? 0.0 : 1 / first.mass;
    final secondInverseMass = second.dragged ? 0.0 : 1 / second.mass;
    if (firstInverseMass + secondInverseMass == 0) return;
    final impulse =
        -(1 + widget.style.restitution) *
        normalVelocity /
        (firstInverseMass + secondInverseMass);
    final impulseVector = unit * impulse;
    if (!first.dragged) first.velocity -= impulseVector * firstInverseMass;
    if (!second.dragged) second.velocity += impulseVector * secondInverseMass;

    final tangent = Offset(-unit.dy, unit.dx);
    final tangentVelocity =
        (second.velocity.dx - first.velocity.dx) * tangent.dx +
        (second.velocity.dy - first.velocity.dy) * tangent.dy -
        first.angularVelocity * first.meanHalfExtent -
        second.angularVelocity * second.meanHalfExtent;
    final inertia = 3 * (firstInverseMass + secondInverseMass);
    if (inertia > 0) {
      final frictionLimit = .35 * impulse.abs();
      final frictionImpulse = (-tangentVelocity / inertia).clamp(
        -frictionLimit,
        frictionLimit,
      );
      if (!first.dragged) {
        first.velocity -= tangent * frictionImpulse * firstInverseMass;
        first.angularVelocity -=
            frictionImpulse * firstInverseMass * 2 / first.meanHalfExtent;
      }
      if (!second.dragged) {
        second.velocity += tangent * frictionImpulse * secondInverseMass;
        second.angularVelocity -=
            frictionImpulse * secondInverseMass * 2 / second.meanHalfExtent;
      }
    }
    _triggerHaptics(impulse);
  }

  void _triggerHaptics(double force) {
    if (!widget.style.enableHaptics || force <= widget.style.hapticThreshold) {
      return;
    }
    final now = DateTime.now();
    if (_lastHapticTime == null ||
        now.difference(_lastHapticTime!).inMilliseconds > 80) {
      HapticFeedback.lightImpact();
      _lastHapticTime = now;
    }
  }

  void _dragStart(_PhysicsBody body) {
    if (!widget.interactionEnabled || !_motionAllowed) return;
    _wakeUp();
    body
      ..dragged = true
      ..velocity = Offset.zero
      ..lastDragTime = DateTime.now()
      ..lastDragPosition = body.position;
    setState(() {});
  }

  void _dragUpdate(_PhysicsBody body, DragUpdateDetails details) {
    if (!body.dragged) return;
    final oldX = body.position.dx;
    body.position = _clampBodyPosition(body.position + details.delta, body);
    body.angle += (body.position.dx - oldX) / body.meanHalfExtent;
    final now = DateTime.now();
    final dt =
        now.difference(body.lastDragTime).inMicroseconds /
        Duration.microsecondsPerSecond;
    if (dt > .001) {
      final instantVelocity = (body.position - body.lastDragPosition) / dt;
      body.velocity = Offset.lerp(body.velocity, instantVelocity, .4)!;
      final instantSpin =
          (body.position.dx - body.lastDragPosition.dx) /
          body.meanHalfExtent /
          dt;
      body.angularVelocity = body.angularVelocity * .6 + instantSpin * .4;
    }
    body
      ..lastDragTime = now
      ..lastDragPosition = body.position;
    setState(() {});
  }

  void _dragEnd(_PhysicsBody body, DragEndDetails details) {
    if (!body.dragged) return;
    body.dragged = false;
    final gestureVelocity = details.velocity.pixelsPerSecond;
    body.velocity = _clampSpeed(
      gestureVelocity.distanceSquared > 100 ? gestureVelocity : body.velocity,
      2200,
    );
    body.angularVelocity = body.angularVelocity.clamp(-40, 40);
    setState(() {});
  }

  Offset _clampSpeed(Offset velocity, double maximum) =>
      velocity.distance > maximum
      ? velocity / velocity.distance * maximum
      : velocity;

  void _resize(Size size) {
    if (_containerSize == size || size.isEmpty) return;
    final firstLayout = _containerSize == Size.zero;
    _containerSize = size;
    if (firstLayout) {
      _initializeBodies();
    } else {
      for (final body in _bodies) {
        body.position = _clampBodyPosition(body.position, body);
      }
      if (_motionAllowed) _wakeUp();
      if (mounted) setState(() {});
    }
  }

  Widget _body(_PhysicsBody body) {
    return Positioned(
      left: body.position.dx - body.size.width / 2,
      top: body.position.dy - body.size.height / 2,
      width: body.size.width,
      height: body.size.height,
      child: MouseRegion(
        cursor: widget.interactionEnabled && _motionAllowed
            ? body.dragged
                  ? SystemMouseCursors.grabbing
                  : SystemMouseCursors.grab
            : MouseCursor.defer,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => _dragStart(body),
          onPanUpdate: (details) => _dragUpdate(body, details),
          onPanEnd: (details) => _dragEnd(body, details),
          child: AnimatedScale(
            scale: body.dragged ? 1.06 : 1,
            duration: _motionAllowed
                ? const Duration(milliseconds: 150)
                : Duration.zero,
            curve: Curves.easeOutCubic,
            child: Container(
              decoration: body.decoration ?? widget.style.itemDecoration,
              clipBehavior: body.clipToCircle ? Clip.antiAlias : Clip.none,
              child: Transform.rotate(
                angle: body.angle,
                child: body.clipToCircle
                    ? ClipOval(child: body.child)
                    : body.child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size(
        constraints.hasBoundedWidth ? constraints.maxWidth : 360,
        constraints.hasBoundedHeight ? constraints.maxHeight : widget.height,
      );
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _resize(size);
      });
      return SizedBox(
        width: double.infinity,
        height: widget.height,
        child: DecoratedBox(
          decoration: widget.style.decoration,
          child: ClipRRect(
            borderRadius:
                widget.style.decoration.borderRadius?.resolve(
                  Directionality.of(context),
                ) ??
                BorderRadius.zero,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (widget.style.showGrid)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _CollisionGridPainter(
                        color: widget.style.gridColor,
                        spacing: widget.style.gridSpacing,
                      ),
                    ),
                  ),
                for (final body in _bodies) _body(body),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _PhysicsBody {
  _PhysicsBody({
    required this.position,
    required this.velocity,
    required this.size,
    required this.mass,
    required this.child,
    required this.decoration,
    required this.clipToCircle,
    required this.lastDragPosition,
  });

  Offset position;
  Offset velocity;
  final Size size;
  final double mass;
  Widget child;
  final BoxDecoration? decoration;
  final bool clipToCircle;
  double angle = 0;
  double angularVelocity = 0;
  bool dragged = false;
  DateTime lastDragTime = DateTime.now();
  Offset lastDragPosition;

  double get meanHalfExtent => (size.width + size.height) / 4;

  double get boundingRadius =>
      math.sqrt(size.width * size.width + size.height * size.height) / 2;

  List<Offset> get axes {
    final cosine = math.cos(angle);
    final sine = math.sin(angle);
    return [Offset(cosine, sine), Offset(-sine, cosine)];
  }

  Size get axisAlignedExtent {
    final cosine = math.cos(angle).abs();
    final sine = math.sin(angle).abs();
    return Size(
      cosine * size.width / 2 + sine * size.height / 2,
      sine * size.width / 2 + cosine * size.height / 2,
    );
  }

  double projectionRadius(Offset axis) {
    final bodyAxes = axes;
    final firstProjection =
        (bodyAxes[0].dx * axis.dx + bodyAxes[0].dy * axis.dy).abs();
    final secondProjection =
        (bodyAxes[1].dx * axis.dx + bodyAxes[1].dy * axis.dy).abs();
    return size.width / 2 * firstProjection +
        size.height / 2 * secondProjection;
  }
}

class _CollisionGridPainter extends CustomPainter {
  const _CollisionGridPainter({required this.color, required this.spacing});

  final Color color;
  final double spacing;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = .8;
    for (var x = 0.0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CollisionGridPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.spacing != spacing;
}
