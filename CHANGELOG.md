## 1.1.0

* `PagedSwipeDeck<T>` — swipe through a feed of any size, page by page.
* `SwipeDeckPaginator<T>` — buffers pages, keeps one request in flight, stops
  when the source runs dry and holds the last error for a retry. Expose one
  yourself to call `refresh()`.
* `SwipeDeckPage<T>` — page result with `hasMore` and an optional
  `nextCursor`, so page-number and cursor APIs both work.
* Prefetching through `prefetchThreshold`, so the deck tops itself up before
  the user reaches the last card.
* Memory windowing through `maxBufferedItems` and `keepBehind`: swiped cards
  are dropped from the front while undo keeps working.
* `loadingBuilder` and `errorBuilder` for the states between pages.
* `SwipeDeckController.trimLeading` for decks whose list is trimmed at the
  front.
* Fixed: appending to `items` no longer resets the deck's cursor or its undo
  history.
* Fixed: a deck that was never dragged could assert while being disposed.

## 1.0.0

First release.

* `SwipeDeck<T>` — a Tinder-style card stack with drag, fling and tap-free
  reuse for any item type.
* `SwipeDeckController` — `swipeLeft`, `swipeRight`, `swipeUp`, `swipeDown`,
  `swipe`, `undo` and `moveTo`.
* Four-way swiping through `allowedDirections`, defaulting to horizontal.
* `overlayBuilder` for LIKE/NOPE style badges that follow the drag progress.
* Tunable stack: `visibleCount`, `backCardScale`, `backCardOffset`,
  `maxRotation`, `threshold`, `velocityThreshold`, `duration` and `curve`.
* `loop`, `swipeEnabled`, `hapticFeedback`, `initialIndex`, `emptyBuilder`,
  `onSwipe`, `onUndo`, `onIndexChanged` and `onEnd`.
* No third-party dependencies.
