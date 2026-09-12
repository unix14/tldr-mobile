import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/settings_repository.dart';
import '../../../data/signals.dart';
import '../../../models/card.dart';
import '../../../theme/colors.dart';

/// "Read full story on Publisher →" inline link.
///
/// Appears at the end of a card's bullets when a source URL exists. Opens
/// the article externally. Existence solves the "text was cut with …"
/// problem: users always have an escape hatch to the full piece.
///
/// Records a source-open signal so the ranker treats the topic as
/// engaging.
class ReadMoreLink extends ConsumerWidget {
  final ContentCard card;
  const ReadMoreLink({super.key, required this.card});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (card.sources.isEmpty) return const SizedBox.shrink();
    final src = card.sources.first;
    if (src.url.isEmpty) return const SizedBox.shrink();

    final isHe = ref.watch(settingsControllerProvider).language == 'he';
    final t = Theme.of(context).textTheme;
    final arrow = isHe ? '←' : '→';
    final label = isHe
        ? 'קריאת הסיפור המלא ב־${src.publisher}'
        : 'Read full story on ${src.publisher}';

    return InkWell(
      onTap: () async {
        final uri = Uri.tryParse(src.url);
        if (uri == null) return;
        SignalTracker(ref).recordSourceOpened(card);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                '$label  $arrow',
                style: t.bodyMedium!.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
