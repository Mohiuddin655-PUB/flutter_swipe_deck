/// A customizable Tinder-style swipeable card deck for Flutter.
///
/// See [SwipeDeck] for the widget and [SwipeDeckController] for driving it
/// from buttons or tests.
library;

export 'src/swipe_deck.dart'
    show
        SwipeDeck,
        SwipeDeckCallback,
        SwipeDeckItemBuilder,
        SwipeDeckOverlayBuilder;
export 'src/swipe_deck_controller.dart'
    show SwipeDeckController, SwipeDeckDelegate;
export 'src/swipe_direction.dart' show SwipeDirection;
