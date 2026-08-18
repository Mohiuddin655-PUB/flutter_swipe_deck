import 'swipe_direction.dart';

/// Implemented by the deck's state so a [SwipeDeckController] can drive it.
abstract interface class SwipeDeckDelegate {
  /// Index of the card currently on top.
  int get currentIndex;

  /// Whether there is a swipe that can be taken back.
  bool get canUndo;

  /// Throws the top card towards [direction].
  void swipe(SwipeDirection direction);

  /// Brings the last swiped card back.
  void undo();

  /// Jumps to [index] without animating.
  void moveTo(int index);
}

/// Drives a [SwipeDeck] from outside — buttons, keyboard shortcuts, tests.
///
/// ```dart
/// final controller = SwipeDeckController();
/// ...
/// SwipeDeck(controller: controller, ...);
/// ...
/// IconButton(onPressed: controller.swipeRight, icon: const Icon(Icons.favorite)),
/// ```
///
/// The controller does nothing until a deck attaches itself, and it must not
/// be shared between two decks at the same time.
class SwipeDeckController {
  SwipeDeckDelegate? _delegate;

  /// Whether a [SwipeDeck] is currently listening to this controller.
  bool get isAttached => _delegate != null;

  /// Index of the card on top, or `0` when detached.
  int get currentIndex => _delegate?.currentIndex ?? 0;

  /// Whether [undo] would bring a card back.
  bool get canUndo => _delegate?.canUndo ?? false;

  /// Throws the top card to the left.
  void swipeLeft() => swipe(SwipeDirection.left);

  /// Throws the top card to the right.
  void swipeRight() => swipe(SwipeDirection.right);

  /// Throws the top card upwards.
  void swipeUp() => swipe(SwipeDirection.up);

  /// Throws the top card downwards.
  void swipeDown() => swipe(SwipeDirection.down);

  /// Throws the top card towards [direction].
  ///
  /// Directions outside `SwipeDeck.allowedDirections` are ignored.
  void swipe(SwipeDirection direction) => _delegate?.swipe(direction);

  /// Brings the last swiped card back to the top of the deck.
  void undo() => _delegate?.undo();

  /// Jumps straight to [index].
  void moveTo(int index) => _delegate?.moveTo(index);

  /// Called by [SwipeDeck]. You never need this.
  void attach(SwipeDeckDelegate delegate) => _delegate = delegate;

  /// Called by [SwipeDeck]. You never need this.
  void detach(SwipeDeckDelegate delegate) {
    if (identical(_delegate, delegate)) _delegate = null;
  }
}
