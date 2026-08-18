import 'package:flutter/foundation.dart';

/// One page of items handed back by a [SwipeDeckPageFetcher].
@immutable
class SwipeDeckPage<T> {
  /// A page that may be followed by more.
  const SwipeDeckPage(this.items, {this.hasMore = true, this.nextCursor});

  /// The final page — the deck stops asking for more after this one.
  const SwipeDeckPage.last(this.items)
      : hasMore = false,
        nextCursor = null;

  /// An empty final page.
  const SwipeDeckPage.empty()
      : items = const [],
        hasMore = false,
        nextCursor = null;

  /// Items to append to the deck.
  final List<T> items;

  /// Whether another page can be requested.
  final bool hasMore;

  /// Opaque cursor handed back on the next request, for keyset/cursor APIs.
  final Object? nextCursor;
}

/// Loads the page numbered [page].
///
/// [cursor] is whatever the previous page returned as
/// [SwipeDeckPage.nextCursor], or `null` for the first page. Use whichever of
/// the two your backend speaks.
typedef SwipeDeckPageFetcher<T> = Future<SwipeDeckPage<T>> Function(
  int page,
  Object? cursor,
);

/// Buffers pages for a [PagedSwipeDeck].
///
/// Keeps one request in flight at a time, remembers the cursor, stops asking
/// once the source is exhausted and holds on to the last error so the UI can
/// offer a retry.
///
/// You only need to build one yourself when you want to trigger
/// [refresh] from outside the deck.
class SwipeDeckPaginator<T> extends ChangeNotifier {
  /// Creates a paginator that pulls pages from [fetcher].
  SwipeDeckPaginator({
    required this.fetcher,
    this.pageSize = 20,
    this.firstPage = 0,
    this.maxPage,
  })  : assert(pageSize > 0, 'pageSize must be greater than 0'),
        assert(
          maxPage == null || maxPage >= firstPage,
          'maxPage cannot be before firstPage',
        );

  /// Loads a page.
  final SwipeDeckPageFetcher<T> fetcher;

  /// Passed to [fetcher] and used to guess [hasMore] when a page does not say.
  final int pageSize;

  /// Number of the first page — `0` or `1`, whatever your API uses.
  final int firstPage;

  /// Highest page number that will ever be requested.
  ///
  /// Optional: leave it `null` for a feed that only ends when the source says
  /// so. Set it to cap a feed — `firstPage: 1, maxPage: 5` requests pages one
  /// through five and then stops.
  final int? maxPage;

  final List<T> _items = [];

  late int _page = firstPage;
  Object? _cursor;
  Object? _error;
  bool _loading = false;
  bool _hasMore = true;
  int _requestId = 0;

  /// Everything loaded so far, minus anything dropped by
  /// `PagedSwipeDeck.maxBufferedItems`.
  List<T> get items => List.unmodifiable(_items);

  /// How many items are currently buffered.
  int get length => _items.length;

  /// Whether a page request is in flight.
  bool get isLoading => _loading;

  /// Whether another page can be requested.
  bool get hasMore => _hasMore;

  /// The error thrown by the last request, if it failed.
  Object? get error => _error;

  /// Whether the last request failed and nothing has been loaded since.
  bool get hasError => _error != null;

  /// Whether nothing has ever been loaded.
  bool get isInitial =>
      _items.isEmpty && !_loading && _error == null && _hasMore;

  /// Requests the next page.
  ///
  /// Returns immediately when a request is already running, when the source is
  /// exhausted, or when the last request failed — call [retry] for that case.
  Future<void> loadMore() async {
    if (_loading || !_hasMore || _error != null) return;
    await _load();
  }

  /// Retries after a failed request.
  Future<void> retry() async {
    if (_loading) return;
    // Cleared inside _load, which notifies once the request is in flight:
    // clearing and notifying here would let a prefetch race the retry.
    _error = null;
    await _load();
  }

  /// Throws away every buffered item and starts from [firstPage].
  Future<void> refresh() async {
    _requestId++;
    _items.clear();
    _page = firstPage;
    _cursor = null;
    _error = null;
    _hasMore = true;
    _loading = false;
    notifyListeners();
    await _load();
  }

  Future<void> _load() async {
    final requestId = ++_requestId;
    _loading = true;
    notifyListeners();
    try {
      final page = await fetcher(_page, _cursor);
      // A refresh may have overtaken this request.
      if (requestId != _requestId) return;
      _items.addAll(page.items);
      _cursor = page.nextCursor;
      _page++;
      // An empty or short page means the source ran dry, whatever it claims.
      _hasMore = page.hasMore && page.items.isNotEmpty;
      final limit = maxPage;
      if (limit != null && _page > limit) _hasMore = false;
    } catch (error) {
      if (requestId != _requestId) return;
      _error = error;
    } finally {
      if (requestId == _requestId) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  /// Drops [count] items from the front of the buffer.
  ///
  /// Called by [PagedSwipeDeck] when `maxBufferedItems` is set; the deck
  /// shifts its cursor by the same amount.
  void trimLeading(int count) {
    if (count <= 0) return;
    final removable = count.clamp(0, _items.length);
    if (removable == 0) return;
    _items.removeRange(0, removable);
    notifyListeners();
  }
}
