import 'package:flutter/material.dart';

import '../../../models/card.dart';
import '../../../theme/colors.dart';
import '../../../widgets/confidence_chip.dart';
import '../../../widgets/publisher_favicon.dart';
import '../../../widgets/relative_date.dart';
import '../../../widgets/topic_chip.dart';
import 'card_actions.dart';
import 'read_more_link.dart';

class VideoCard extends StatelessWidget {
  final ContentCard card;
  const VideoCard({super.key, required this.card});

  bool get _isHe => card.language == 'he';

  String get _thumb =>
      'https://i.ytimg.com/vi/${card.youtubeId}/hqdefault.jpg';

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
                    _thumbnail(context),
                    const SizedBox(height: 16),
                    Text(
                      card.headline,
                      style:
                          Theme.of(context).textTheme.headlineMedium!.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                    ),
                    const SizedBox(height: 10),
                    _byline(context),
                    const SizedBox(height: 16),
                    for (final b in card.bullets)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '• $b',
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge!
                              .copyWith(color: AppColors.textPrimary),
                        ),
                      ),
                    if (card.sources.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      ReadMoreLink(card: card),
                    ],
                    if (card.whyItMatters != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        (_isHe ? 'למה זה חשוב' : 'Why it matters').toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall!.copyWith(
                              color: AppColors.accent,
                              letterSpacing: 1.2,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        card.whyItMatters!,
                        style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                              color: AppColors.textPrimary,
                            ),
                      ),
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
        card.sources.isNotEmpty ? card.sources.first.publisher : 'YouTube';
    final url = card.sources.isNotEmpty
        ? card.sources.first.url
        : 'https://www.youtube.com';
    return DefaultTextStyle(
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 12,
        letterSpacing: 0.1,
      ),
      child: Row(
        children: [
          PublisherFavicon(publisher: publisher, url: url, size: 14),
          const SizedBox(width: 8),
          if (card.channel != null)
            Flexible(
              child: Text(
                card.channel!,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else
            Text(
              publisher,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          _dot(),
          Text(_isHe ? 'וידאו' : 'Video'),
          if (formatRelative(card.publishedAt, isHe: _isHe).isNotEmpty) ...[
            _dot(),
            Text(formatRelative(card.publishedAt, isHe: _isHe)),
          ],
          _dot(),
          Text('~${card.estimatedSeconds}s'),
          if (card.confidence != Confidence.confirmed) ...[
            _dot(),
            ConfidenceChip(confidence: card.confidence, language: card.language),
          ],
        ],
      ),
    );
  }

  Widget _dot() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Text('·', style: TextStyle(color: AppColors.textMuted)),
      );

  Widget _thumbnail(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: AppColors.surfaceElevated),
            Image.network(
              _thumb,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.surfaceElevated,
                alignment: Alignment.center,
                child: const Icon(Icons.play_circle_outline,
                    size: 48, color: AppColors.textSecondary),
              ),
              loadingBuilder: (context, child, loading) =>
                  loading == null ? child : Container(color: AppColors.surface),
            ),
            // Subtle bottom gradient so the play glyph reads on bright frames.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x66000000)],
                  stops: [0.65, 1.0],
                ),
              ),
              child: SizedBox.expand(),
            ),
            const Center(
              child: Icon(Icons.play_circle_fill,
                  size: 60, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
