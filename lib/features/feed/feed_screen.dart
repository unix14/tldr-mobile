import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/content_repository.dart';
import '../../data/session_stats.dart';
import '../../data/session_timer.dart';
import '../../data/settings_repository.dart';
import '../../models/card.dart';
import '../../theme/colors.dart';
import 'feed_ranker.dart';
import 'widgets/end_of_feed_screen.dart';
import 'widgets/gesture_layer.dart';
import 'widgets/session_check_in_sheet.dart';
import 'widgets/text_card.dart';
import 'widgets/video_card.dart';

/// Snap-any-drag page physics — snaps to nearest page after ~15% drag even
/// without a fling. Better for both slow mouse users on the PWA and for
/// touch users who make small deliberate swipes.
class _SnappyPagePhysics extends PageScrollPhysics {
  const _SnappyPagePhysics({super.parent});

  @override
  _SnappyPagePhysics applyTo(ScrollPhysics? ancestor) =>
      _SnappyPagePhysics(parent: buildParent(ancestor));

  double _pageWidth(ScrollMetrics position) =>
      position.viewportDimension.clamp(1.0, double.infinity);

  double _targetPixels(ScrollMetrics position, double velocity) {
    final page = position.pixels / _pageWidth(position);
    final rounded = velocity > 200
        ? page.ceilToDouble()
        : velocity < -200
            ? page.floorToDouble()
            : (page - page.floor() > 0.15
                ? page.ceilToDouble()
                : page.floorToDouble());
    return rounded * _pageWidth(position);
  }

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final target = _targetPixels(position, velocity);
    if ((target - position.pixels).abs() < toleranceFor(position).distance) {
      return null;
    }
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: toleranceFor(position),
    );
  }
}

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final PageController _controller = PageController();
  List<ContentCard>? _cards;
  String? _rankedForLanguage;
  Set<String>? _rankedForInterests;

  Timer? _checkInTicker;

  @override
  void initState() {
    super.initState();
    // Periodic check against the session timer. 30s cadence is fine — the
    // decision is coarse ("has the user chosen session length been
    // exceeded?"), not a stopwatch.
    _checkInTicker = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _maybeShowCheckIn(),
    );
  }

  @override
  void dispose() {
    _checkInTicker?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _maybeShowCheckIn() async {
    if (!mounted) return;
    final settings = ref.read(settingsControllerProvider);
    final timer = ref.read(sessionTimerProvider);
    if (!timer.shouldShowCheckIn(sessionMinutes: settings.sessionMinutes)) {
      return;
    }
    // Only show when the Feed tab is actually foregrounded — the check-in
    // is a reading nudge, it makes no sense to pop it over Library/Settings.
    if (!ModalRoute.of(context)!.isCurrent) return;
    await SessionCheckInSheet.show(context);
  }

  /// Rank once per (language, interests) tuple. Mutations to the seen/save
  /// set from within-feed actions do NOT recompute the feed order — that
  /// would trash the current page position and defeat the whole product
  /// promise of a stable swipe surface.
  Future<void> _ensureRanked() async {
    final settings = ref.read(settingsControllerProvider);
    final needRank = _cards == null ||
        _rankedForLanguage != settings.language ||
        _rankedForInterests == null ||
        !_setEquals(_rankedForInterests!, settings.interests);
    if (!needRank) return;
    final all = await ref.read(contentRepositoryProvider).loadAll();
    final ranked = const FeedRanker().rank(
      pool: all,
      language: settings.language,
      interests: settings.interests,
      weights: settings.interestWeights,
      seenIds: settings.seenIds,
      allowSensitive: settings.allowSensitive,
    );
    if (!mounted) return;
    setState(() {
      _cards = ranked;
      _rankedForLanguage = settings.language;
      _rankedForInterests = Set<String>.from(settings.interests);
    });
  }

  bool _setEquals(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    for (final x in a) {
      if (!b.contains(x)) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // Watch these two so a language/interest change triggers re-rank.
    final settings = ref.watch(settingsControllerProvider);
    // Kick a rank if needed. Uses microtask so build stays synchronous.
    _ensureRanked();
    final cards = _cards;
    if (cards == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (cards.isEmpty) return _emptyState(context, settings.language);
    return PageView.builder(
      controller: _controller,
      scrollDirection: Axis.vertical,
      physics: const _SnappyPagePhysics(),
      itemCount: cards.length + 1,
      onPageChanged: (i) {
        if (i < cards.length) {
          ref
              .read(settingsControllerProvider.notifier)
              .markSeen(cards[i].id);
          ref.read(sessionStatsProvider.notifier).markSeen();
        }
      },
      itemBuilder: (context, i) {
        if (i == cards.length) {
          return _PageDepthWrapper(
            controller: _controller,
            index: i,
            child: EndOfFeedScreen(
              language: settings.language,
              totalCards: cards.length,
              onBackToTop: () {
                if (_controller.hasClients) _controller.jumpToPage(0);
              },
            ),
          );
        }
        final card = cards[i];
        final content = card.kind == CardKind.video && card.hasVideo
            ? VideoCard(card: card)
            : TextCard(card: card);
        return _PageDepthWrapper(
          controller: _controller,
          index: i,
          child: GestureLayer(card: card, child: content),
        );
      },
    );
  }

  Widget _emptyState(BuildContext context, String lang) {
    final isHe = lang == 'he';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          isHe
              ? 'אין כרגע כרטיסים.\nחזרי שוב מאוחר יותר.'
              : 'Nothing to show yet.\nCheck back in a bit.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 15),
        ),
      ),
    );
  }

}

/// Subtle depth cue during a page transition: the incoming/outgoing card
/// fades and scales in from 96% → 100%. Only the visible ±1 page is animated
/// so cost stays flat regardless of feed length.
class _PageDepthWrapper extends StatelessWidget {
  final PageController controller;
  final int index;
  final Widget child;

  const _PageDepthWrapper({
    required this.controller,
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        double delta = 0;
        if (controller.hasClients &&
            controller.position.haveDimensions) {
          delta = (controller.page ?? controller.initialPage.toDouble()) -
              index;
        }
        final t = delta.abs().clamp(0.0, 1.0);
        final opacity = 1.0 - (t * 0.35);
        final scale = 1.0 - (t * 0.04);
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: child,
          ),
        );
      },
    );
  }
}
