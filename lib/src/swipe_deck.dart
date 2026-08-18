import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'swipe_deck_controller.dart';
import 'swipe_direction.dart';

/// Builds the card for [item] at [index].
typedef SwipeDeckItemBuilder<T> = Widget Function(
  BuildContext context,
  T item,
  int index,
);

/// Builds the badge drawn over the top card while it is being dragged.
///
/// [direction] is where the card is heading and [progress] runs from `0` (just
/// started) to `1` (far enough that releasing would complete the swipe).
/// Return `null` to draw nothing for that direction.
typedef SwipeDeckOverlayBuilder = Widget? Function(
  BuildContext context,
  SwipeDirection direction,
  double progress,
);

/// Called once a card has left the deck.
typedef SwipeDeckCallback<T> = void Function(
  int index,
  T item,
  SwipeDirection direction,
);

/// A Tinder-style stack of cards you can throw away with a swipe.
///
/// The deck keeps its own cursor into [items]: swiping simply moves to the
/// next index, so the list you pass in never has to change. Use
/// [SwipeDeckController] to swipe or undo from a button.
///
/// ```dart
/// SwipeDeck<Profile>(
///   items: profiles,
///   itemBuilder: (context, profile, index) => ProfileCard(profile),
///   onSwipe: (index, profile, direction) {
///     if (direction == SwipeDirection.right) like(profile);
///   },
///   onEnd: () => debugPrint('deck finished'),
/// )
/// ```
class SwipeDeck<T> extends StatefulWidget {
  /// Creates a swipeable card deck over [items].
  const SwipeDeck({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.controller,
    this.onSwipe,
    this.onUndo,
    this.onEnd,
    this.onIndexChanged,
    this.overlayBuilder,
    this.emptyBuilder,
    this.allowedDirections = SwipeDirection.horizontal,
    this.visibleCount = 3,
    this.backCardScale = 0.04,
    this.backCardOffset = const Offset(0, 12),
    this.threshold = 110,
    this.velocityThreshold = 700,
    this.maxRotation = 12,
    this.duration = const Duration(milliseconds: 220),
    this.curve = Curves.easeOut,
    this.swipeEnabled = true,
    this.loop = false,
    this.hapticFeedback = true,
    this.initialIndex = 0,
  })  : assert(visibleCount >= 1, 'visibleCount must be at least 1'),
        assert(threshold > 0, 'threshold must be greater than 0'),
        assert(velocityThreshold > 0, 'velocityThreshold must be > 0'),
        assert(initialIndex >= 0, 'initialIndex cannot be negative');

  /// The cards, top of the deck first.
  final List<T> items;

  /// Builds each card.
  final SwipeDeckItemBuilder<T> itemBuilder;

  /// Lets you swipe and undo from outside the deck.
  final SwipeDeckController? controller;

  /// Called when a card has flown off the deck.
  final SwipeDeckCallback<T>? onSwipe;

  /// Called when a swipe has been taken back with
  /// [SwipeDeckController.undo].
  final SwipeDeckCallback<T>? onUndo;

  /// Called once, when the last card has been swiped away.
  ///
  /// Never called while [loop] is true.
  final VoidCallback? onEnd;

  /// Called whenever a different card reaches the top.
  final ValueChanged<int>? onIndexChanged;

  /// Draws "LIKE"/"NOPE" style badges over the card being dragged.
  final SwipeDeckOverlayBuilder? overlayBuilder;

  /// Shown once every card has been swiped away.
  final WidgetBuilder? emptyBuilder;

  /// Directions a card may be thrown in. Defaults to left and right.
  final List<SwipeDirection> allowedDirections;

  /// How many cards are rendered, including the top one.
  final int visibleCount;

  /// How much smaller each card behind the top one is drawn, per step.
  final double backCardScale;

  /// How far each card behind the top one is offset, per step.
  final Offset backCardOffset;

  /// Distance in logical pixels a card must travel to count as swiped.
  final double threshold;

  /// A flick faster than this completes the swipe regardless of [threshold].
  final double velocityThreshold;

  /// Maximum tilt of the dragged card, in degrees.
  final double maxRotation;

  /// How long the fly-out and snap-back animations take.
  final Duration duration;

  /// Curve of the fly-out and snap-back animations.
  final Curve curve;

  /// Whether dragging is allowed. Controller swipes still work when `false`.
  final bool swipeEnabled;

  /// Whether the deck starts over instead of running out.
  final bool loop;

  /// Whether a light haptic tick fires when a card leaves the deck.
  final bool hapticFeedback;

  /// Card to start on.
  final int initialIndex;

  @override
  State<SwipeDeck<T>> createState() => _SwipeDeckState<T>();
}

class _SwipeDeckState<T> extends State<SwipeDeck<T>>
    with SingleTickerProviderStateMixin
    implements SwipeDeckDelegate {
  // Built in initState, never lazily: a `late final` initialiser would run
  // inside dispose() for a deck that was never dragged.
  late final AnimationController _animationController;

  final List<_SwipeRecord> _history = [];

  Animation<Offset>? _animation;
  Offset _drag = Offset.zero;
  Size _deckSize = Size.zero;
  bool _settling = false;
  bool _ended = false;

  int _index = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _index = widget.initialIndex;
    widget.controller?.attach(this);
  }

  @override
  void didUpdateWidget(covariant SwipeDeck<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.detach(this);
      widget.controller?.attach(this);
    }
    if (oldWidget.duration != widget.duration) {
      _animationController.duration = widget.duration;
    }
    if (oldWidget.items.length != widget.items.length) {
      if (widget.items.length < oldWidget.items.length) {
        // The list shrank: keep the cursor and the undo history in range.
        if (_index > widget.items.length) _index = widget.items.length;
        _history.removeWhere((record) => record.index >= widget.items.length);
      }
      // More cards arrived, so the deck can reach its end again later.
      if (_index < widget.items.length) _ended = false;
    }
  }

  @override
  void dispose() {
    widget.controller?.detach(this);
    _animation?.removeListener(_followAnimation);
    _animationController.dispose();
    super.dispose();
  }

  // --- SwipeDeckDelegate -----------------------------------------------

  @override
  int get currentIndex => _index;

  @override
  bool get canUndo => _history.isNotEmpty;

  @override
  void swipe(SwipeDirection direction) {
    if (!widget.allowedDirections.contains(direction)) return;
    _fling(direction);
  }

  @override
  void undo() {
    if (_settling || _history.isEmpty) return;
    final record = _history.removeLast();
    final item =
        record.index < widget.items.length ? widget.items[record.index] : null;
    setState(() {
      _index = record.index;
      _ended = false;
      // Start where the card left and slide it back home.
      _drag = _offscreenOffset(record.direction);
    });
    _animateTo(Offset.zero, () {
      if (item != null) {
        widget.onUndo?.call(record.index, item, record.direction);
      }
      widget.onIndexChanged?.call(_index);
    });
  }

  @override
  void handleLeadingTrimmed(int count) {
    if (count <= 0) return;
    setState(() {
      _index = math.max(0, _index - count);
      for (var i = _history.length - 1; i >= 0; i--) {
        final record = _history[i];
        if (record.index < count) {
          _history.removeAt(i);
        } else {
          _history[i] = _SwipeRecord(
            index: record.index - count,
            direction: record.direction,
          );
        }
      }
    });
  }

  @override
  void moveTo(int index) {
    if (index < 0 || index > widget.items.length) return;
    setState(() {
      _index = index;
      _drag = Offset.zero;
      _ended = false;
      _history.clear();
    });
    widget.onIndexChanged?.call(_index);
  }

  // --- Gestures ---------------------------------------------------------

  bool get _isEmpty =>
      widget.items.isEmpty || (!widget.loop && _index >= widget.items.length);

  Offset _offscreenOffset(SwipeDirection direction) {
    final size =
        _deckSize == Size.zero ? MediaQuery.sizeOf(context) : _deckSize;
    final travel = math.max(size.width, size.height) * 1.6;
    return direction.unit * travel;
  }

  SwipeDirection? _resolveDirection(Offset drag, Offset velocity) {
    final allowed = widget.allowedDirections;
    if (allowed.isEmpty) return null;

    final byVelocity = velocity.distance > widget.velocityThreshold;
    final horizontalFirst = drag.dx.abs() >= drag.dy.abs();

    SwipeDirection? pick(bool horizontal) {
      if (horizontal) {
        final passed = drag.dx.abs() > widget.threshold ||
            (byVelocity && velocity.dx.abs() >= velocity.dy.abs());
        if (!passed) return null;
        final direction =
            drag.dx > 0 ? SwipeDirection.right : SwipeDirection.left;
        return allowed.contains(direction) ? direction : null;
      }
      final passed = drag.dy.abs() > widget.threshold ||
          (byVelocity && velocity.dy.abs() > velocity.dx.abs());
      if (!passed) return null;
      final direction = drag.dy > 0 ? SwipeDirection.down : SwipeDirection.up;
      return allowed.contains(direction) ? direction : null;
    }

    return pick(horizontalFirst) ?? pick(!horizontalFirst);
  }

  /// Direction the card is leaning towards right now, for the overlay.
  SwipeDirection? get _activeDirection {
    if (_drag == Offset.zero) return null;
    final allowed = widget.allowedDirections;
    final horizontal = _drag.dx.abs() >= _drag.dy.abs();
    final candidate = horizontal
        ? (_drag.dx > 0 ? SwipeDirection.right : SwipeDirection.left)
        : (_drag.dy > 0 ? SwipeDirection.down : SwipeDirection.up);
    if (allowed.contains(candidate)) return candidate;
    final fallback = horizontal
        ? (_drag.dy > 0 ? SwipeDirection.down : SwipeDirection.up)
        : (_drag.dx > 0 ? SwipeDirection.right : SwipeDirection.left);
    return allowed.contains(fallback) ? fallback : null;
  }

  double _progressFor(SwipeDirection direction) {
    final travelled = direction.isHorizontal ? _drag.dx.abs() : _drag.dy.abs();
    return (travelled / widget.threshold).clamp(0.0, 1.0);
  }

  void _animateTo(Offset target, VoidCallback onDone) {
    _settling = true;
    final animation = Tween<Offset>(begin: _drag, end: target).animate(
      CurvedAnimation(parent: _animationController, curve: widget.curve),
    );
    _animation?.removeListener(_followAnimation);
    _animation = animation..addListener(_followAnimation);
    _animationController.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      _settling = false;
      setState(() => _drag = Offset.zero);
      onDone();
    });
  }

  void _followAnimation() {
    final animation = _animation;
    if (animation == null || !mounted) return;
    setState(() => _drag = animation.value);
  }

  void _fling(SwipeDirection direction) {
    if (_settling || _isEmpty) return;
    final index = widget.loop ? _index % widget.items.length : _index;
    if (index < 0 || index >= widget.items.length) return;
    final item = widget.items[index];
    if (widget.hapticFeedback) HapticFeedback.mediumImpact();
    _animateTo(_offscreenOffset(direction), () {
      _history.add(_SwipeRecord(index: index, direction: direction));
      widget.onSwipe?.call(index, item, direction);
      _advance();
    });
  }

  void _advance() {
    final next = _index + 1;
    setState(() {
      _index = widget.loop ? next % widget.items.length : next;
    });
    if (!widget.loop && _index >= widget.items.length) {
      if (!_ended) {
        _ended = true;
        widget.onEnd?.call();
      }
      return;
    }
    widget.onIndexChanged?.call(_index);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_settling) return;
    setState(() => _drag += details.delta);
  }

  void _onPanEnd(DragEndDetails details) {
    if (_settling) return;
    final velocity = details.velocity.pixelsPerSecond;
    final direction = _resolveDirection(_drag, velocity);
    if (direction != null) {
      _fling(direction);
      return;
    }
    _animateTo(Offset.zero, () {});
  }

  // --- Painting ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _deckSize = constraints.biggest.isFinite
            ? constraints.biggest
            : MediaQuery.sizeOf(context);

        if (_isEmpty) {
          return widget.emptyBuilder?.call(context) ?? const SizedBox.shrink();
        }

        final cards = <Widget>[];
        for (var depth = widget.visibleCount - 1; depth >= 0; depth--) {
          final raw = _index + depth;
          if (!widget.loop && raw >= widget.items.length) continue;
          final index = widget.loop ? raw % widget.items.length : raw;
          cards.add(
            KeyedSubtree(
              key: ValueKey('swipe-deck-$index-$depth'),
              child: _buildCard(index: index, depth: depth),
            ),
          );
        }

        return Stack(alignment: Alignment.center, children: cards);
      },
    );
  }

  Widget _buildCard({required int index, required int depth}) {
    final isTop = depth == 0;
    final settle = math.min(1.0, _drag.distance / (widget.threshold * 1.4));
    final scale = 1 -
        depth * widget.backCardScale +
        (isTop ? 0.0 : settle * widget.backCardScale);
    final offset = widget.backCardOffset * depth.toDouble() -
        (isTop ? Offset.zero : widget.backCardOffset * settle);

    Widget card = widget.itemBuilder(context, widget.items[index], index);

    if (isTop) {
      final direction = _activeDirection;
      final overlay = direction == null
          ? null
          : widget.overlayBuilder?.call(
              context,
              direction,
              _progressFor(direction),
            );
      if (overlay != null) {
        card = Stack(
          fit: StackFit.passthrough,
          children: [card, Positioned.fill(child: overlay)],
        );
      }
    }

    card = Transform.translate(
      offset: offset,
      child: Transform.scale(scale: scale, child: card),
    );

    if (!isTop) return IgnorePointer(child: card);

    final width = _deckSize.width == 0 ? 1.0 : _deckSize.width;
    final angle = (_drag.dx / (width / 2) * widget.maxRotation)
            .clamp(-widget.maxRotation, widget.maxRotation) *
        math.pi /
        180;

    return Transform.translate(
      offset: _drag,
      child: Transform.rotate(
        angle: angle,
        child: widget.swipeEnabled
            ? GestureDetector(
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: card,
              )
            : card,
      ),
    );
  }
}

class _SwipeRecord {
  const _SwipeRecord({required this.index, required this.direction});

  final int index;
  final SwipeDirection direction;
}
