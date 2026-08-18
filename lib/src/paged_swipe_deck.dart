import 'package:flutter/material.dart';

import 'swipe_deck.dart';
import 'swipe_deck_controller.dart';
import 'swipe_deck_pagination.dart';
import 'swipe_direction.dart';

/// Builds the view shown when the deck has run dry but a page is on its way.
typedef SwipeDeckLoadingBuilder = Widget Function(BuildContext context);

/// Builds the view shown when a page request failed.
///
/// Call [retry] to try the same page again.
typedef SwipeDeckErrorBuilder = Widget Function(
  BuildContext context,
  Object error,
  VoidCallback retry,
);

/// A [SwipeDeck] that pulls its cards in pages, so the user can keep swiping
/// through a feed of any size.
///
/// The next page is requested while there are still cards left to swipe, so
/// the deck normally never stalls. One request runs at a time, a failed page
/// stops the loop until [SwipeDeckPaginator.retry] is called, and an empty or
/// short page ends it.
///
/// ```dart
/// PagedSwipeDeck<Profile>(
///   pageSize: 20,
///   prefetchThreshold: 5,
///   fetcher: (page, cursor) async {
///     final result = await api.profiles(page: page, limit: 20);
///     return SwipeDeckPage(result.items, hasMore: result.hasNext);
///   },
///   itemBuilder: (context, profile, index) => ProfileCard(profile),
///   onSwipe: (index, profile, direction) => report(profile, direction),
/// )
/// ```
class PagedSwipeDeck<T> extends StatefulWidget {
  /// Creates a paginated deck.
  ///
  /// Pass either a [fetcher] or a ready-made [paginator].
  const PagedSwipeDeck({
    super.key,
    required this.itemBuilder,
    this.fetcher,
    this.paginator,
    this.pageSize = 20,
    this.firstPage = 0,
    this.prefetchThreshold = 5,
    this.maxBufferedItems,
    this.keepBehind = 10,
    this.controller,
    this.onSwipe,
    this.onUndo,
    this.onEnd,
    this.onIndexChanged,
    this.overlayBuilder,
    this.loadingBuilder,
    this.errorBuilder,
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
    this.hapticFeedback = true,
  })  : assert(
          fetcher != null || paginator != null,
          'Pass either a fetcher or a paginator',
        ),
        assert(prefetchThreshold >= 0, 'prefetchThreshold cannot be negative'),
        assert(keepBehind >= 0, 'keepBehind cannot be negative'),
        assert(
          maxBufferedItems == null || maxBufferedItems > keepBehind,
          'maxBufferedItems must leave room for keepBehind',
        );

  /// Builds each card.
  final SwipeDeckItemBuilder<T> itemBuilder;

  /// Loads a page. Ignored when [paginator] is given.
  final SwipeDeckPageFetcher<T>? fetcher;

  /// A paginator you own — pass one to call
  /// [SwipeDeckPaginator.refresh] yourself.
  final SwipeDeckPaginator<T>? paginator;

  /// Items per page. Ignored when [paginator] is given.
  final int pageSize;

  /// Number of the first page. Ignored when [paginator] is given.
  final int firstPage;

  /// Request the next page once this many cards are left unswiped.
  final int prefetchThreshold;

  /// Cap on buffered items. Older, already swiped cards are dropped once the
  /// buffer grows past it. `null` keeps everything.
  final int? maxBufferedItems;

  /// How many swiped cards to keep behind the cursor when trimming, so undo
  /// still works.
  final int keepBehind;

  /// Lets you swipe and undo from outside the deck.
  final SwipeDeckController? controller;

  /// Called when a card has flown off the deck.
  final SwipeDeckCallback<T>? onSwipe;

  /// Called when a swipe has been taken back.
  final SwipeDeckCallback<T>? onUndo;

  /// Called when the last card of the last page is gone.
  final VoidCallback? onEnd;

  /// Called whenever a different card reaches the top.
  final ValueChanged<int>? onIndexChanged;

  /// Draws badges over the card being dragged.
  final SwipeDeckOverlayBuilder? overlayBuilder;

  /// Shown while waiting for a page with no cards left to swipe.
  final SwipeDeckLoadingBuilder? loadingBuilder;

  /// Shown when a page request failed and no cards are left to swipe.
  final SwipeDeckErrorBuilder? errorBuilder;

  /// Shown when every page has been loaded and every card swiped.
  final WidgetBuilder? emptyBuilder;

  /// Directions a card may be thrown in.
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

  /// Whether dragging is allowed.
  final bool swipeEnabled;

  /// Whether a light haptic tick fires when a card leaves the deck.
  final bool hapticFeedback;

  @override
  State<PagedSwipeDeck<T>> createState() => _PagedSwipeDeckState<T>();
}

class _PagedSwipeDeckState<T> extends State<PagedSwipeDeck<T>> {
  late SwipeDeckPaginator<T> _paginator;
  late SwipeDeckController _controller;

  bool _ownsPaginator = false;
  bool _ownsController = false;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _createPaginator();
    _createController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pump());
  }

  @override
  void didUpdateWidget(covariant PagedSwipeDeck<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paginator != widget.paginator ||
        (widget.paginator == null && oldWidget.fetcher != widget.fetcher)) {
      _disposePaginator();
      _createPaginator();
      _index = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) => _pump());
    }
    if (oldWidget.controller != widget.controller) {
      if (_ownsController) _controller = SwipeDeckController();
      _createController();
    }
  }

  @override
  void dispose() {
    _disposePaginator();
    super.dispose();
  }

  void _createPaginator() {
    final external = widget.paginator;
    _ownsPaginator = external == null;
    _paginator = external ??
        SwipeDeckPaginator<T>(
          fetcher: widget.fetcher!,
          pageSize: widget.pageSize,
          firstPage: widget.firstPage,
        );
    _paginator.addListener(_onPaginatorChanged);
  }

  void _disposePaginator() {
    _paginator.removeListener(_onPaginatorChanged);
    if (_ownsPaginator) _paginator.dispose();
  }

  void _createController() {
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? SwipeDeckController();
  }

  void _onPaginatorChanged() {
    if (!mounted) return;
    setState(() {});
    // A page may have landed while the deck was already empty.
    _pump();
  }

  /// Trims what is no longer needed, then tops the buffer back up.
  void _pump() {
    if (!mounted) return;
    if (_controller.isAttached) _index = _controller.currentIndex;
    _trim();
    _prefetch();
  }

  void _trim() {
    final max = widget.maxBufferedItems;
    if (max == null || _paginator.length <= max) return;
    final trim = _index - widget.keepBehind;
    if (trim <= 0) return;
    _paginator.trimLeading(trim);
    _controller.trimLeading(trim);
    _index -= trim;
  }

  void _prefetch() {
    if (_paginator.isLoading || !_paginator.hasMore || _paginator.hasError) {
      return;
    }
    final remaining = _paginator.length - _index;
    if (remaining > widget.prefetchThreshold) return;
    _paginator.loadMore();
  }

  void _onIndexChanged(int index) {
    _index = index;
    widget.onIndexChanged?.call(index);
    _pump();
  }

  void _onEnd() {
    _pump();
    // Only a genuinely exhausted source counts as the end of the deck.
    if (!_paginator.hasMore && !_paginator.isLoading) widget.onEnd?.call();
  }

  Widget _buildPlaceholder(BuildContext context) {
    final error = _paginator.error;
    if (error != null) {
      return widget.errorBuilder?.call(context, error, _paginator.retry) ??
          Center(
            child: TextButton(
              onPressed: _paginator.retry,
              child: const Text('Retry'),
            ),
          );
    }
    if (_paginator.isLoading || _paginator.hasMore) {
      return widget.loadingBuilder?.call(context) ??
          const Center(child: CircularProgressIndicator());
    }
    return widget.emptyBuilder?.call(context) ?? const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return SwipeDeck<T>(
      items: _paginator.items,
      itemBuilder: widget.itemBuilder,
      controller: _controller,
      onSwipe: widget.onSwipe,
      onUndo: widget.onUndo,
      onIndexChanged: _onIndexChanged,
      onEnd: _onEnd,
      overlayBuilder: widget.overlayBuilder,
      emptyBuilder: _buildPlaceholder,
      allowedDirections: widget.allowedDirections,
      visibleCount: widget.visibleCount,
      backCardScale: widget.backCardScale,
      backCardOffset: widget.backCardOffset,
      threshold: widget.threshold,
      velocityThreshold: widget.velocityThreshold,
      maxRotation: widget.maxRotation,
      duration: widget.duration,
      curve: widget.curve,
      swipeEnabled: widget.swipeEnabled,
      hapticFeedback: widget.hapticFeedback,
    );
  }
}
