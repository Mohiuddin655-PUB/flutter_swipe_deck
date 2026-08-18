import 'dart:ui';

/// The four directions a card can be thrown in.
enum SwipeDirection {
  /// Thrown towards the start of the screen.
  left,

  /// Thrown towards the end of the screen.
  right,

  /// Thrown towards the top of the screen.
  up,

  /// Thrown towards the bottom of the screen.
  down;

  /// Left and right only — the default for a Tinder-style deck.
  static const List<SwipeDirection> horizontal = [
    SwipeDirection.left,
    SwipeDirection.right,
  ];

  /// Up and down only.
  static const List<SwipeDirection> vertical = [
    SwipeDirection.up,
    SwipeDirection.down,
  ];

  /// All four directions.
  static const List<SwipeDirection> all = [
    SwipeDirection.left,
    SwipeDirection.right,
    SwipeDirection.up,
    SwipeDirection.down,
  ];

  /// Whether this is [left] or [right].
  bool get isHorizontal => this == left || this == right;

  /// Whether this is [up] or [down].
  bool get isVertical => !isHorizontal;

  /// Unit vector pointing the way the card flies out.
  Offset get unit => switch (this) {
        SwipeDirection.left => const Offset(-1, 0),
        SwipeDirection.right => const Offset(1, 0),
        SwipeDirection.up => const Offset(0, -1),
        SwipeDirection.down => const Offset(0, 1),
      };
}
