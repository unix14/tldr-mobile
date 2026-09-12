import 'package:flutter/material.dart';

import '../../../models/card.dart';
import '../../../theme/colors.dart';
import '../../../widgets/confidence_chip.dart';
import '../../../widgets/publisher_favicon.dart';
import '../../../widgets/relative_date.dart';
import '../../../widgets/topic_chip.dart';
import 'card_actions.dart';
import 'read_more_link.dart';

/// Text/news card — editorial layout.
///
/// Rhythm (top → bottom):
///   • 24pt horizontal gutter
///   • Topic eyebrow (small caps, tightly tracked)
///   • Headline (serif, tight leading)
///   • 8pt gap → byline row (time · publisher · confidence)
///   • 24pt → bullets
///   • 24pt → Why it matters block
///   • 12pt → Disagreement callout (only when present)
///   • Divider
///   • Action row
class TextCard extends StatelessWidget {
  final ContentCard card;
  const TextCard({super.key, required this.card});

  bool get _isHe => card.language == 'he';

  @override
  Widget build(BuildContext context) {
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.headline,
                      style:
                          Theme.of(context).textTheme.headlineLarge!.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                    ),
                    const SizedBox(height: 12),
                    _byline(context),
                    const SizedBox(height: 24),
                    for (final b in card.bullets) _bullet(context, b),
                    if (card.sources.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      ReadMoreLink(card: card),
                    ],
                    if (card.whyItMatters != null) ...[
                      const SizedBox(height: 20),
                      _whyItMatters(context),
                    ],
                    if (card.disagreement != null) ...[
                      const SizedBox(height: 16),
                      _disagreement(context),
                    ],
                    const SizedBox(height: 24),
                  ],
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
          // "Published X ago" comes before the read-time so the freshness
          // signal reads first (bigger deal on a news feed than reading
          // duration).
          if (_publishedRelative().isNotEmpty) ...[
            Text(_publishedRelative()),
            _dot(),
          ],
          Text('~${card.estimatedSeconds}s'),
          if (card.confidence != Confidence.confirmed) ...[
            _dot(),
            ConfidenceChip(
                confidence: card.confidence, language: card.language),
          ],
        ],
      ),
    );
  }

  String _publishedRelative() =>
      formatRelative(card.publishedAt, isHe: _isHe);

  Widget _dot() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Text('·', style: TextStyle(color: AppColors.textMuted)),
      );

  Widget _whyItMatters(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          (_isHe ? 'למה זה חשוב' : 'Why it matters').toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall!.copyWith(
                color: AppColors.accent,
                letterSpacing: 1.2,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          card.whyItMatters!,
          style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                color: AppColors.textPrimary,
              ),
        ),
      ],
    );
  }

  Widget _disagreement(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: AppColors.disputed,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                (_isHe ? 'חילוקי דעות' : 'Disagreement').toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall!.copyWith(
                      color: AppColors.disputed,
                      letterSpacing: 1.2,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            card.disagreement!,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.55,
                ),
          ),
        ],
      ),
    );
  }

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
