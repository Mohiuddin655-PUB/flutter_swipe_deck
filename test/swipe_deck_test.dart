import 'package:flutter/material.dart';
import 'package:flutter_swipe_deck/flutter_swipe_deck.dart';
import 'package:flutter_test/flutter_test.dart';

const _items = ['A', 'B', 'C'];

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(width: 300, height: 400, child: child),
      ),
    ),
  );
}

Widget _card(BuildContext context, String item, int index) {
  return Container(
    key: ValueKey('card-$item'),
    alignment: Alignment.center,
    color: Colors.blueGrey,
    child: Text(item),
  );
}

void main() {
  testWidgets('renders the top card and the cards behind it', (tester) async {
    await tester.pumpWidget(
      _host(SwipeDeck<String>(items: _items, itemBuilder: _card)),
    );

    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
  });

  testWidgets('honours visibleCount', (tester) async {
    await tester.pumpWidget(
      _host(
        SwipeDeck<String>(
          items: _items,
          itemBuilder: _card,
          visibleCount: 2,
        ),
      ),
    );

    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('C'), findsNothing);
  });

  testWidgets('a drag to the right swipes the top card away', (tester) async {
    final swiped = <String>[];
    SwipeDirection? direction;

    await tester.pumpWidget(
      _host(
        SwipeDeck<String>(
          items: _items,
          itemBuilder: _card,
          onSwipe: (index, item, value) {
            swiped.add(item);
            direction = value;
          },
        ),
      ),
    );

    await tester.drag(find.text('A'), const Offset(250, 0));
    await tester.pumpAndSettle();

    expect(swiped, ['A']);
    expect(direction, SwipeDirection.right);
    expect(find.text('A'), findsNothing);
  });

  testWidgets('a short drag snaps back without swiping', (tester) async {
    final swiped = <String>[];

    await tester.pumpWidget(
      _host(
        SwipeDeck<String>(
          items: _items,
          itemBuilder: _card,
          onSwipe: (index, item, direction) => swiped.add(item),
        ),
      ),
    );

    await tester.drag(find.text('A'), const Offset(20, 0));
    await tester.pumpAndSettle();

    expect(swiped, isEmpty);
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('vertical drags are ignored while horizontal-only',
      (tester) async {
    final swiped = <String>[];

    await tester.pumpWidget(
      _host(
        SwipeDeck<String>(
          items: _items,
          itemBuilder: _card,
          onSwipe: (index, item, direction) => swiped.add(item),
        ),
      ),
    );

    await tester.drag(find.text('A'), const Offset(0, -250));
    await tester.pumpAndSettle();

    expect(swiped, isEmpty);
  });

  testWidgets('vertical swiping works when allowed', (tester) async {
    SwipeDirection? direction;

    await tester.pumpWidget(
      _host(
        SwipeDeck<String>(
          items: _items,
          itemBuilder: _card,
          allowedDirections: SwipeDirection.all,
          onSwipe: (index, item, value) => direction = value,
        ),
      ),
    );

    await tester.drag(find.text('A'), const Offset(0, -250));
    await tester.pumpAndSettle();

    expect(direction, SwipeDirection.up);
  });

  testWidgets('the controller swipes and undoes', (tester) async {
    final controller = SwipeDeckController();
    final swiped = <String>[];
    final undone = <String>[];

    await tester.pumpWidget(
      _host(
        SwipeDeck<String>(
          items: _items,
          itemBuilder: _card,
          controller: controller,
          onSwipe: (index, item, direction) => swiped.add(item),
          onUndo: (index, item, direction) => undone.add(item),
        ),
      ),
    );

    expect(controller.isAttached, isTrue);
    expect(controller.canUndo, isFalse);

    controller.swipeLeft();
    await tester.pumpAndSettle();
    expect(swiped, ['A']);
    expect(controller.currentIndex, 1);
    expect(controller.canUndo, isTrue);

    controller.undo();
    await tester.pumpAndSettle();
    expect(undone, ['A']);
    expect(controller.currentIndex, 0);
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('moveTo jumps to another card', (tester) async {
    final controller = SwipeDeckController();

    await tester.pumpWidget(
      _host(
        SwipeDeck<String>(
          items: _items,
          itemBuilder: _card,
          controller: controller,
        ),
      ),
    );

    controller.moveTo(2);
    await tester.pumpAndSettle();

    expect(controller.currentIndex, 2);
    expect(find.text('A'), findsNothing);
    expect(find.text('C'), findsOneWidget);
  });

  testWidgets('onEnd fires once and emptyBuilder takes over', (tester) async {
    final controller = SwipeDeckController();
    var ends = 0;

    await tester.pumpWidget(
      _host(
        SwipeDeck<String>(
          items: _items,
          itemBuilder: _card,
          controller: controller,
          onEnd: () => ends++,
          emptyBuilder: (context) => const Text('done'),
        ),
      ),
    );

    for (var i = 0; i < _items.length; i++) {
      controller.swipeRight();
      await tester.pumpAndSettle();
    }

    expect(ends, 1);
    expect(find.text('done'), findsOneWidget);
  });

  testWidgets('loop starts over instead of ending', (tester) async {
    final controller = SwipeDeckController();
    var ends = 0;

    await tester.pumpWidget(
      _host(
        SwipeDeck<String>(
          items: _items,
          itemBuilder: _card,
          controller: controller,
          loop: true,
          onEnd: () => ends++,
        ),
      ),
    );

    for (var i = 0; i < _items.length; i++) {
      controller.swipeRight();
      await tester.pumpAndSettle();
    }

    expect(ends, 0);
    expect(controller.currentIndex, 0);
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('the overlay follows the drag', (tester) async {
    await tester.pumpWidget(
      _host(
        SwipeDeck<String>(
          items: _items,
          itemBuilder: _card,
          overlayBuilder: (context, direction, progress) {
            return Align(
              alignment: Alignment.topCenter,
              child: Text('${direction.name}:${progress.toStringAsFixed(1)}'),
            );
          },
        ),
      ),
    );

    expect(find.textContaining('right:'), findsNothing);

    final gesture = await tester.startGesture(tester.getCenter(find.text('A')));
    await gesture.moveBy(const Offset(120, 0));
    await tester.pump();

    expect(find.text('right:1.0'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('swipeEnabled false blocks dragging but not the controller',
      (tester) async {
    final controller = SwipeDeckController();
    final swiped = <String>[];

    await tester.pumpWidget(
      _host(
        SwipeDeck<String>(
          items: _items,
          itemBuilder: _card,
          controller: controller,
          swipeEnabled: false,
          onSwipe: (index, item, direction) => swiped.add(item),
        ),
      ),
    );

    await tester.drag(find.text('A'), const Offset(250, 0));
    await tester.pumpAndSettle();
    expect(swiped, isEmpty);

    controller.swipeRight();
    await tester.pumpAndSettle();
    expect(swiped, ['A']);
  });

  testWidgets('an empty list falls back to emptyBuilder', (tester) async {
    await tester.pumpWidget(
      _host(
        SwipeDeck<String>(
          items: const [],
          itemBuilder: _card,
          emptyBuilder: (context) => const Text('nothing here'),
        ),
      ),
    );

    expect(find.text('nothing here'), findsOneWidget);
  });
}
