import 'package:flutter/material.dart';
import 'package:flutter_swipe_deck/flutter_swipe_deck.dart';

void main() => runApp(const SwipeDeckDemo());

class SwipeDeckDemo extends StatelessWidget {
  const SwipeDeckDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_swipe_deck',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const DeckPage(),
    );
  }
}

class Profile {
  const Profile(this.name, this.tagline, this.color);

  final String name;
  final String tagline;
  final Color color;
}

const _profiles = [
  Profile('Ramen crawl', 'Old town · 2 hours', Color(0xFFEF6C6C)),
  Profile('Rooftop cinema', 'Late showing · tonight', Color(0xFF6C7BEF)),
  Profile('Sunrise hike', 'Lookout trail · half day', Color(0xFF37A86B)),
  Profile('Pottery class', 'Craft studio · beginners', Color(0xFFE0A030)),
  Profile('Blanket fort', 'Home · board games', Color(0xFF8E5BD0)),
];

class DeckPage extends StatefulWidget {
  const DeckPage({super.key});

  @override
  State<DeckPage> createState() => _DeckPageState();
}

class _DeckPageState extends State<DeckPage> {
  final controller = SwipeDeckController();
  final liked = <String>[];
  final skipped = <String>[];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('flutter_swipe_deck'),
        actions: [
          IconButton(
            tooltip: 'Undo',
            onPressed: () => setState(controller.undo),
            icon: const Icon(Icons.undo_rounded),
          ),
          IconButton(
            tooltip: 'Paginated feed',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const PagedPage())),
            icon: const Icon(Icons.all_inclusive_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SwipeDeck<Profile>(
                items: _profiles,
                controller: controller,
                // Swipe up to super-like as well as left/right.
                allowedDirections: const [
                  SwipeDirection.left,
                  SwipeDirection.right,
                  SwipeDirection.up,
                ],
                backCardOffset: Offset(0, 24),
                itemBuilder: (context, profile, index) => _Card(profile),
                overlayBuilder: (context, direction, progress) {
                  return _Badge(direction: direction, progress: progress);
                },
                emptyBuilder: (context) =>
                    const Center(child: Text('That is everyone for now.')),
                onSwipe: (index, profile, direction) => setState(() {
                  if (direction == SwipeDirection.left) {
                    skipped.add(profile.name);
                  } else {
                    liked.add(profile.name);
                  }
                }),
                onUndo: (index, profile, direction) => setState(() {
                  liked.remove(profile.name);
                  skipped.remove(profile.name);
                }),
                onEnd: () => debugPrint('deck finished'),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('${liked.length} liked · ${skipped.length} skipped'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _RoundButton(
                  icon: Icons.close_rounded,
                  color: Colors.redAccent,
                  onPressed: controller.swipeLeft,
                ),
                _RoundButton(
                  icon: Icons.star_rounded,
                  color: Colors.blueAccent,
                  onPressed: controller.swipeUp,
                ),
                _RoundButton(
                  icon: Icons.favorite_rounded,
                  color: Colors.green,
                  onPressed: controller.swipeRight,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card(this.profile);

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1 / 1.5,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: profile.color,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              profile.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              profile.tagline,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.direction, required this.progress});

  final SwipeDirection direction;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final (label, color, alignment) = switch (direction) {
      SwipeDirection.right => ('LIKE', Colors.green, Alignment.topLeft),
      SwipeDirection.left => ('NOPE', Colors.redAccent, Alignment.topRight),
      SwipeDirection.up => ('SUPER', Colors.blueAccent, Alignment.bottomCenter),
      SwipeDirection.down => ('LATER', Colors.orange, Alignment.topCenter),
    };

    return Opacity(
      opacity: progress,
      child: Align(
        alignment: alignment,
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onPressed,
      iconSize: 32,
      padding: const EdgeInsets.all(16),
      icon: Icon(icon, color: color),
    );
  }
}

/// An endless feed loaded page by page.
class PagedPage extends StatelessWidget {
  const PagedPage({super.key});

  /// Stands in for a paginated API call.
  static Future<SwipeDeckPage<Profile>> _fetch(int page, Object? cursor) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return SwipeDeckPage(
      List.generate(10, (index) {
        final number = page * 10 + index + 1;
        final base = _profiles[number % _profiles.length];
        return Profile('${base.name} #$number', base.tagline, base.color);
      }),
      // Six pages, then the feed runs dry.
      hasMore: page < 5,
      nextCursor: 'page-$page',
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = SwipeDeckController();
    return Scaffold(
      appBar: AppBar(title: const Text('Paginated feed')),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: PagedSwipeDeck<Profile>(
                controller: controller,
                fetcher: _fetch,
                pageSize: 10,
                backCardOffset: Offset(0, 18),
                prefetchThreshold: 4,
                // Never hold more than 40 cards, but keep 8 for undo.
                maxBufferedItems: 40,
                keepBehind: 8,
                itemBuilder: (context, profile, index) => _Card(profile),
                overlayBuilder: (context, direction, progress) =>
                    _Badge(direction: direction, progress: progress),
                loadingBuilder: (context) =>
                    const Center(child: CircularProgressIndicator()),
                errorBuilder: (context, error, retry) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$error'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: retry,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                emptyBuilder: (context) => const Center(
                  child: Text('You reached the end of the feed.'),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _RoundButton(
                  icon: Icons.close_rounded,
                  color: Colors.redAccent,
                  onPressed: controller.swipeLeft,
                ),
                _RoundButton(
                  icon: Icons.undo_rounded,
                  color: Colors.blueGrey,
                  onPressed: controller.undo,
                ),
                _RoundButton(
                  icon: Icons.favorite_rounded,
                  color: Colors.green,
                  onPressed: controller.swipeRight,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
