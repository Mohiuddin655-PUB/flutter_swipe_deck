import 'package:flutter/material.dart';
import 'package:flutter_swipe_deck/flutter_swipe_deck.dart';
import 'package:flutter_test/flutter_test.dart';

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
  return Container(alignment: Alignment.center, child: Text(item));
}

/// Endless feed: page `n` yields `n0 … n4`.
Future<SwipeDeckPage<String>> _endless(int page, Object? cursor) async {
  return SwipeDeckPage(
    List.generate(5, (index) => 'p$page-i$index'),
    nextCursor: 'cursor-$page',
  );
}

void main() {
  testWidgets('loads the first page on mount', (tester) async {
    await tester.pumpWidget(
      _host(PagedSwipeDeck<String>(fetcher: _endless, itemBuilder: _card)),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('p0-i0'), findsOneWidget);
  });

  testWidgets('prefetches the next page before the deck runs out',
      (tester) async {
    final requested = <int>[];
    final controller = SwipeDeckController();

    await tester.pumpWidget(
      _host(
        PagedSwipeDeck<String>(
          controller: controller,
          pageSize: 5,
          prefetchThreshold: 2,
          fetcher: (page, cursor) {
            requested.add(page);
            return _endless(page, cursor);
          },
          itemBuilder: _card,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(requested, [0]);

    // Three swipes leave two cards — the prefetch threshold.
    for (var i = 0; i < 3; i++) {
      controller.swipeRight();
      await tester.pumpAndSettle();
    }

    expect(requested, [0, 1]);
    expect(find.text('p0-i3'), findsOneWidget);
  });

  testWidgets('passes the cursor of the previous page along', (tester) async {
    final cursors = <Object?>[];
    final controller = SwipeDeckController();

    await tester.pumpWidget(
      _host(
        PagedSwipeDeck<String>(
          controller: controller,
          pageSize: 5,
          prefetchThreshold: 2,
          fetcher: (page, cursor) {
            cursors.add(cursor);
            return _endless(page, cursor);
          },
          itemBuilder: _card,
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (var i = 0; i < 3; i++) {
      controller.swipeRight();
      await tester.pumpAndSettle();
    }

    expect(cursors, [null, 'cursor-0']);
  });

  testWidgets('keeps swiping across page boundaries', (tester) async {
    final controller = SwipeDeckController();
    final swiped = <String>[];

    await tester.pumpWidget(
      _host(
        PagedSwipeDeck<String>(
          controller: controller,
          pageSize: 5,
          prefetchThreshold: 2,
          fetcher: _endless,
          itemBuilder: _card,
          onSwipe: (index, item, direction) => swiped.add(item),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (var i = 0; i < 7; i++) {
      controller.swipeRight();
      await tester.pumpAndSettle();
    }

    expect(swiped.length, 7);
    expect(swiped.last, 'p1-i1');
    expect(find.text('p1-i2'), findsOneWidget);
  });

  testWidgets('a short page ends the deck', (tester) async {
    final controller = SwipeDeckController();
    var ends = 0;

    await tester.pumpWidget(
      _host(
        PagedSwipeDeck<String>(
          controller: controller,
          pageSize: 5,
          prefetchThreshold: 1,
          fetcher: (page, cursor) async => page == 0
              ? const SwipeDeckPage(['a', 'b'], hasMore: true)
              : const SwipeDeckPage<String>.empty(),
          itemBuilder: _card,
          onEnd: () => ends++,
          emptyBuilder: (context) => const Text('done'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    controller.swipeRight();
    await tester.pumpAndSettle();
    controller.swipeRight();
    await tester.pumpAndSettle();

    expect(ends, 1);
    expect(find.text('done'), findsOneWidget);
  });

  testWidgets('a failed page surfaces a retry', (tester) async {
    var attempts = 0;

    await tester.pumpWidget(
      _host(
        PagedSwipeDeck<String>(
          fetcher: (page, cursor) async {
            attempts++;
            if (attempts == 1) throw StateError('offline');
            return const SwipeDeckPage(['recovered'], hasMore: false);
          },
          itemBuilder: _card,
          errorBuilder: (context, error, retry) => TextButton(
            onPressed: retry,
            child: const Text('retry'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('retry'), findsOneWidget);

    await tester.tap(find.text('retry'));
    await tester.pumpAndSettle();

    expect(find.text('recovered'), findsOneWidget);
    expect(attempts, 2);
  });

  testWidgets('trims the buffer but keeps undo working', (tester) async {
    final controller = SwipeDeckController();

    await tester.pumpWidget(
      _host(
        PagedSwipeDeck<String>(
          controller: controller,
          pageSize: 5,
          prefetchThreshold: 2,
          maxBufferedItems: 8,
          keepBehind: 2,
          fetcher: _endless,
          itemBuilder: _card,
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (var i = 0; i < 6; i++) {
      controller.swipeRight();
      await tester.pumpAndSettle();
    }

    // The cursor is still pointing at the right card after trimming.
    expect(find.text('p1-i1'), findsOneWidget);
    expect(controller.canUndo, isTrue);

    controller.undo();
    await tester.pumpAndSettle();
    expect(find.text('p1-i0'), findsOneWidget);
  });

  testWidgets('an external paginator can refresh the deck', (tester) async {
    var generation = 0;
    final paginator = SwipeDeckPaginator<String>(
      pageSize: 2,
      fetcher: (page, cursor) async =>
          SwipeDeckPage(['g$generation-p$page'], hasMore: false),
    );
    addTearDown(paginator.dispose);

    await tester.pumpWidget(
      _host(PagedSwipeDeck<String>(paginator: paginator, itemBuilder: _card)),
    );
    await tester.pumpAndSettle();
    expect(find.text('g0-p0'), findsOneWidget);

    generation = 1;
    await paginator.refresh();
    await tester.pumpAndSettle();

    expect(find.text('g1-p0'), findsOneWidget);
    expect(paginator.length, 1);
  });

  testWidgets('one request runs at a time', (tester) async {
    var inFlight = 0;
    var overlaps = 0;
    final controller = SwipeDeckController();

    await tester.pumpWidget(
      _host(
        PagedSwipeDeck<String>(
          controller: controller,
          pageSize: 5,
          prefetchThreshold: 4,
          fetcher: (page, cursor) async {
            inFlight++;
            if (inFlight > 1) overlaps++;
            await Future<void>.delayed(const Duration(milliseconds: 5));
            inFlight--;
            return _endless(page, cursor);
          },
          itemBuilder: _card,
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (var i = 0; i < 4; i++) {
      controller.swipeRight();
      await tester.pump(const Duration(milliseconds: 5));
    }
    // Let every delayed fetch finish before the tree goes away.
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(overlaps, 0);
  });
}
