import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/card.dart';
import '../../../theme/colors.dart';
import '../../../widgets/confidence_chip.dart';
import '../../../widgets/publisher_favicon.dart';
import '../../../widgets/relative_date.dart';
import '../../../widgets/topic_chip.dart';
import 'card_actions.dart';
import 'read_more_link.dart';

/// Full-screen scrollable version of a card.
///
/// The feed card is deliberately kept tight (single-screen, non-scrolling)
/// so vertical swipes always page. When a headline or body is genuinely
/// long we truncate on the feed and expose a "Show more" affordance;
/// tapping opens this route, where the same content can breathe and
/// scroll freely.
class ExpandedCardScreen extends ConsumerWidget {
  final ContentCard card;
  const ExpandedCardScreen({super.key, required this.card});

  bool get _isHe => card.language == 'he';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    return Directionality(
      textDirection: _isHe ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final tag in card.topicTags.take(3))
                            TopicChip(topicId: tag, language: card.language),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        card.headline,
                        style: t.displayMedium!.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _byline(context, t),
                      const SizedBox(height: 24),
                      for (final b in card.bullets) _bullet(context, b),
                      if (card.sources.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        ReadMoreLink(card: card),
                      ],
                      if (card.whyItMatters != null) ...[
                        const SizedBox(height: 24),
                        Text(
                          (_isHe ? 'למה זה חשוב' : 'Why it matters')
                              .toUpperCase(),
                          style: t.labelSmall!.copyWith(
                            color: AppColors.accent,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          card.whyItMatters!,
                          style: t.bodyLarge!.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                      if (card.disagreement != null) ...[
                        const SizedBox(height: 20),
                        _disagreement(context, t),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: CardActions(card: card),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _byline(BuildContext context, TextTheme t) {
    final publisher =
        card.sources.isNotEmpty ? card.sources.first.publisher : '';
    final url = card.sources.isNotEmpty ? card.sources.first.url : null;
    final relative = formatRelative(card.publishedAt, isHe: _isHe);
    return DefaultTextStyle(
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 12.5,
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
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            _dot(),
          ],
          if (relative.isNotEmpty) ...[
            Text(relative),
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

  Widget _dot() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Text('·', style: TextStyle(color: AppColors.textMuted)),
      );

  Widget _bullet(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 4,
            margin: const EdgeInsets.only(top: 11),
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
                    height: 1.55,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _disagreement(BuildContext context, TextTheme t) {
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
                style: t.labelSmall!.copyWith(
                  color: AppColors.disputed,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            card.disagreement!,
            style: t.bodyMedium!.copyWith(
              color: AppColors.textSecondary,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
