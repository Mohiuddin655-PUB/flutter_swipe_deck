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
