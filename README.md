# flutter_swipe_deck

[![pub package](https://img.shields.io/pub/v/flutter_swipe_deck.svg)](https://pub.dev/packages/flutter_swipe_deck)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A customizable Tinder-style swipeable card deck for Flutter — drag a card away,
throw it with a button, take it back with undo, and paint your own badges while
it moves.

No third-party dependencies. Works with any item type.

## Features

- **Any data** — `SwipeDeck<T>` builds your own widget for every item.
- **Four directions** — left and right by default, opt into up and down.
- **Controller** — `swipeLeft()`, `swipeRight()`, `swipeUp()`, `swipeDown()`,
  `swipe(direction)`, `undo()` and `moveTo(index)`.
- **Undo** — the last card slides back in from where it left.
- **Drag overlays** — build LIKE / NOPE badges that follow the swipe progress.
- **Tunable stack** — how many cards show behind, how far back they sit, how
  much the top card tilts, how far it must travel, how fast it animates.
- **Loop mode**, **empty state**, **haptics** and a **read-only mode** for
  button-only decks.

## Getting started

```yaml
dependencies:
  flutter_swipe_deck: ^1.0.0
```

```dart
import 'package:flutter_swipe_deck/flutter_swipe_deck.dart';
```

## Usage

```dart
SwipeDeck<Profile>(
  items: profiles,
  itemBuilder: (context, profile, index) => ProfileCard(profile),
  onSwipe: (index, profile, direction) {
    if (direction == SwipeDirection.right) like(profile);
  },
  onEnd: () => debugPrint('deck finished'),
)
```

The deck keeps its own cursor into `items`, so the list you pass in never has
to change. `onSwipe` tells you which item left and which way it went.

### Driving it from buttons

```dart
final controller = SwipeDeckController();

SwipeDeck<Profile>(
  controller: controller,
  items: profiles,
  itemBuilder: ...,
);

Row(
  children: [
    IconButton(onPressed: controller.swipeLeft, icon: const Icon(Icons.close)),
    IconButton(onPressed: controller.undo, icon: const Icon(Icons.undo)),
    IconButton(onPressed: controller.swipeRight, icon: const Icon(Icons.favorite)),
  ],
)
```

### Badges while dragging

`overlayBuilder` runs for the card being dragged. `progress` goes from `0` to
`1`, hitting `1` exactly when releasing would complete the swipe.

```dart
overlayBuilder: (context, direction, progress) {
  if (direction == SwipeDirection.up) return null; // nothing for super-likes
  return Opacity(
    opacity: progress,
    child: Align(
      alignment: direction == SwipeDirection.right
          ? Alignment.topLeft
          : Alignment.topRight,
      child: Text(direction == SwipeDirection.right ? 'LIKE' : 'NOPE'),
    ),
  );
},
```

### Swiping up and down

```dart
SwipeDeck<Profile>(
  allowedDirections: SwipeDirection.all, // or .horizontal, .vertical, or your own list
  ...
)
```

## Parameters

| Parameter | Default | What it does |
| --- | --- | --- |
| `items` | required | The cards, top of the deck first. |
| `itemBuilder` | required | Builds a card for an item. |
| `controller` | `null` | Swipe, undo and jump from outside. |
| `onSwipe` | `null` | A card left the deck. |
| `onUndo` | `null` | A swipe was taken back. |
| `onEnd` | `null` | Fired once when the last card is gone. |
| `onIndexChanged` | `null` | A different card reached the top. |
| `overlayBuilder` | `null` | Badge drawn over the dragged card. |
| `emptyBuilder` | `null` | Shown when the deck runs out. |
| `allowedDirections` | `SwipeDirection.horizontal` | Which ways cards may fly. |
| `visibleCount` | `3` | Cards rendered, including the top one. |
| `backCardScale` | `0.04` | How much smaller each card behind is. |
| `backCardOffset` | `Offset(0, 12)` | How far each card behind is offset. |
| `threshold` | `110` | Pixels a card must travel to count as swiped. |
| `velocityThreshold` | `700` | A faster flick completes the swipe anyway. |
| `maxRotation` | `12` | Maximum tilt of the dragged card, in degrees. |
| `duration` | `220ms` | Fly-out and snap-back duration. |
| `curve` | `Curves.easeOut` | Fly-out and snap-back curve. |
| `swipeEnabled` | `true` | Whether dragging is allowed. |
| `loop` | `false` | Start over instead of running out. |
| `hapticFeedback` | `true` | Tick when a card leaves the deck. |
| `initialIndex` | `0` | Card to start on. |

## Example

A full demo — three action buttons, undo, super-like on swipe up and animated
badges — lives in [`example/lib/main.dart`](example/lib/main.dart).

```sh
cd example
flutter run
```

## License

MIT — see [LICENSE](LICENSE).
