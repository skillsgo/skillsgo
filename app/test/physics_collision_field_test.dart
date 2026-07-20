/*
 * [INPUT]: Depends on Flutter widget testing and the locally vendored PhysicsCollisionField public interaction contract.
 * [OUTPUT]: Specifies deterministic oriented-box separation, identity-preserving parent rebuilds, drag/fling wake-up, natural settling without timed freezes, and reduced-motion interaction behavior.
 * [POS]: Serves as the focused regression suite for the reusable vendored collision primitive outside its Library product consumer.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/ui/physics_collision_field.dart';

const _style = PhysicsCollisionFieldStyle(
  decoration: BoxDecoration(color: Color(0xffeeeeee)),
  itemDecoration: BoxDecoration(color: Color(0xffffffff)),
  gravity: Offset.zero,
  damping: .5,
  gridColor: Color(0xffcccccc),
);

const _persistentMotionStyle = PhysicsCollisionFieldStyle(
  decoration: BoxDecoration(color: Color(0xffeeeeee)),
  itemDecoration: BoxDecoration(color: Color(0xffffffff)),
  gravity: Offset.zero,
  restitution: 1,
  damping: 0,
  gridColor: Color(0xffcccccc),
);

Widget _field({
  bool disableAnimations = false,
  PhysicsCollisionFieldStyle style = _style,
  Offset initialVelocity = Offset.zero,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Center(
      child: SizedBox(
        width: 300,
        height: 200,
        child: PhysicsCollisionField(
          height: 200,
          style: style,
          items: [
            PhysicsCollisionFieldItem(
              id: 'test-body',
              collisionSize: const Size.square(60),
              initialPosition: const Offset(80, 80),
              initialVelocity: initialVelocity,
              child: const ColoredBox(
                key: Key('collision-test-body'),
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('overlapping rectangular bodies separate along their box edges', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 300,
            height: 200,
            child: PhysicsCollisionField(
              height: 200,
              style: _style,
              items: const [
                PhysicsCollisionFieldItem(
                  collisionSize: Size.square(60),
                  initialPosition: Offset(100, 100),
                  child: ColoredBox(
                    key: Key('collision-box-first'),
                    color: Colors.blue,
                  ),
                ),
                PhysicsCollisionFieldItem(
                  collisionSize: Size.square(60),
                  initialPosition: Offset(130, 100),
                  child: ColoredBox(
                    key: Key('collision-box-second'),
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    for (var frame = 0; frame < 4; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final first = tester.getCenter(
      find.byKey(const Key('collision-box-first')),
    );
    final second = tester.getCenter(
      find.byKey(const Key('collision-box-second')),
    );
    expect((second.dx - first.dx).abs(), greaterThanOrEqualTo(59.9));
  });

  testWidgets('dragging a body moves it and automatic motion is bounded', (
    tester,
  ) async {
    await tester.pumpWidget(_field());
    await tester.pump();
    await tester.pump();
    final body = find.byKey(const Key('collision-test-body'));
    final before = tester.getCenter(body);

    final gesture = await tester.startGesture(before);
    await gesture.moveBy(const Offset(64, 24));
    await tester.pump();
    final dragged = tester.getCenter(body);
    expect(dragged.dx, greaterThan(before.dx + 50));
    expect(dragged.dy, greaterThan(before.dy + 15));
    await gesture.up();

    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('a moving body does not freeze after an arbitrary time budget', (
    tester,
  ) async {
    await tester.pumpWidget(
      _field(
        style: _persistentMotionStyle,
        initialVelocity: const Offset(90, 0),
      ),
    );
    await tester.pump();
    await tester.pump();
    final body = find.byKey(const Key('collision-test-body'));
    for (var frame = 0; frame < 60; frame++) {
      await tester.pump(const Duration(milliseconds: 32));
    }
    final before = tester.getCenter(body);
    await tester.pump(const Duration(milliseconds: 32));
    final after = tester.getCenter(body);

    expect(after, isNot(before));
  });

  testWidgets('reduced motion keeps deterministic layout and disables drag', (
    tester,
  ) async {
    await tester.pumpWidget(_field(disableAnimations: true));
    await tester.pump();
    await tester.pumpAndSettle();
    final body = find.byKey(const Key('collision-test-body'));
    final before = tester.getCenter(body);

    await tester.drag(body, const Offset(64, 24));
    await tester.pumpAndSettle();

    expect(tester.getCenter(body), before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unrelated parent rebuild preserves body position', (
    tester,
  ) async {
    var revision = 0;
    late StateSetter rebuild;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          rebuild = setState;
          return MaterialApp(
            home: Center(
              child: SizedBox(
                width: 300,
                height: 200,
                child: PhysicsCollisionField(
                  height: 200,
                  style: _persistentMotionStyle,
                  items: [
                    PhysicsCollisionFieldItem(
                      id: 'stable-body',
                      collisionSize: const Size.square(60),
                      initialPosition: const Offset(80, 80),
                      initialVelocity: const Offset(90, 0),
                      child: ColoredBox(
                        key: const Key('stable-collision-body'),
                        color: revision.isEven ? Colors.blue : Colors.cyan,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    await tester.pump();
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final before = tester.getCenter(
      find.byKey(const Key('stable-collision-body')),
    );

    rebuild(() => revision++);
    await tester.pump();
    final after = tester.getCenter(
      find.byKey(const Key('stable-collision-body')),
    );

    expect((after - before).distance, lessThan(5));
    expect(after.dx, greaterThan(80));
  });
}
