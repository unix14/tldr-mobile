import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/card.dart';
import '../../../theme/colors.dart';
import '../../../widgets/confidence_chip.dart';
import '../../../widgets/publisher_favicon.dart';
import '../../../widgets/relative_date.dart';
import '../../../widgets/topic_chip.dart';
import 'card_actions.dart';
import 'expanded_card_screen.dart';
import 'read_more_link.dart';

/// Text/news card — feed variant. Kept intentionally tight:
///   * headline capped to 4 lines
///   * body renders at most 2 bullets
///   * "Show more" affordance always appears when there is more content to
///     read (extra bullets, whyItMatters, disagreement, or a very long
///     headline), opening [ExpandedCardScreen] for the scrollable full view
///
/// A `ClipRect` on the body area is a defensive backstop — even if a
/// pathological headline slips past the maxLines guard, we clip instead
/// of flashing Flutter's overflow stripes.
class TextCard extends ConsumerWidget {
  final ContentCard card;
  const TextCard({super.key, required this.card});

  bool get _isHe => card.language == 'he';

  static const _feedBulletCap = 2;
  static const _headlineMaxLines = 4;

  bool get _hasMore =>
      card.bullets.length > _feedBulletCap ||
      card.whyItMatters != null ||
      card.disagreement != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Directionality(
      textDirection: _isHe ? TextDirection.rtl : TextDirection.ltr,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _topicEyebrow(context),
              const SizedBox(height: 12),
              Expanded(
                child: ClipRect(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.headline,
                        maxLines: _headlineMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .headlineLarge!
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      _byline(context),
                      const SizedBox(height: 20),
                      for (final b in card.bullets.take(_feedBulletCap))
                        _bullet(context, b),
                      if (_hasMore) ...[
                        const SizedBox(height: 6),
                        _ShowMoreLink(card: card),
                      ],
                      if (card.sources.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        ReadMoreLink(card: card),
                      ],
                    ],
                  ),
                ),
              ),
              const Divider(),
              CardActions(card: card),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topicEyebrow(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final t in card.topicTags.take(3))
          TopicChip(topicId: t, language: card.language),
      ],
    );
  }

  Widget _byline(BuildContext context) {
    final publisher =
        card.sources.isNotEmpty ? card.sources.first.publisher : '';
    final url = card.sources.isNotEmpty ? card.sources.first.url : null;
    final relative = formatRelative(card.publishedAt, isHe: _isHe);
    return DefaultTextStyle(
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 12,
        letterSpacing: 0.1,
      ),
      child: Row(
        children: [
          if (publisher.isNotEmpty) ...[
            PublisherFavicon(publisher: publisher, url: url, size: 14),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                publisher,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            _dot(),
          ],
          if (relative.isNotEmpty) Text(relative),
          if (card.confidence != Confidence.confirmed) ...[
            _dot(),
            ConfidenceChip(
                confidence: card.confidence, language: card.language),
          ],
        ],
      ),
    );
  }

  Widget _dot() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Text('·', style: TextStyle(color: AppColors.textMuted)),
      );

  Widget _bullet(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 4,
            margin: const EdgeInsets.only(top: 10),
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                    color: AppColors.textPrimary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small "Show more" link at the bottom of a feed card. Opens the
/// full scrollable [ExpandedCardScreen]. Uses the CARD's language.
class _ShowMoreLink extends StatelessWidget {
  final ContentCard card;
  const _ShowMoreLink({required this.card});

  bool get _isHe => card.language == 'he';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: _isHe ? TextDirection.rtl : TextDirection.ltr,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {
          Navigator.of(context).push(
            PageRouteBuilder(
              opaque: true,
              transitionDuration: const Duration(milliseconds: 220),
              pageBuilder: (_, __, ___) => ExpandedCardScreen(card: card),
              transitionsBuilder: (_, a, __, child) => FadeTransition(
                opacity: a,
                child: child,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isHe ? 'הרחב את הכתבה' : 'Show more',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                _isHe ? Icons.arrow_back : Icons.arrow_forward,
                size: 14,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
