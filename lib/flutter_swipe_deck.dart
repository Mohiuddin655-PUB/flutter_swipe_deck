/// A customizable Tinder-style swipeable card deck for Flutter.
///
/// [SwipeDeck] renders a fixed list, [PagedSwipeDeck] pulls its cards in pages
/// so a feed of any size can be swiped, and [SwipeDeckController] drives
/// either one from a button.
library;

export 'src/paged_swipe_deck.dart'
    show PagedSwipeDeck, SwipeDeckErrorBuilder, SwipeDeckLoadingBuilder;
export 'src/swipe_deck.dart'
    show
        SwipeDeck,
        SwipeDeckCallback,
        SwipeDeckItemBuilder,
        SwipeDeckOverlayBuilder;
export 'src/swipe_deck_controller.dart'
    show SwipeDeckController, SwipeDeckDelegate;
export 'src/swipe_deck_pagination.dart'
    show SwipeDeckPage, SwipeDeckPageFetcher, SwipeDeckPaginator;
export 'src/swipe_direction.dart' show SwipeDirection;
