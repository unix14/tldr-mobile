import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/signals.dart';
import '../../../models/card.dart';
import '../../../theme/colors.dart';

/// "Read full story on Publisher →" inline link.
///
/// Uses the CARD's language (not the UI language) so the label direction
/// matches the surrounding article body — no mixed LTR/RTL wobble when a
/// Hebrew UI user is reading an English article.
class ReadMoreLink extends ConsumerWidget {
  final ContentCard card;
  const ReadMoreLink({super.key, required this.card});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (card.sources.isEmpty) return const SizedBox.shrink();
    final src = card.sources.first;
    if (src.url.isEmpty) return const SizedBox.shrink();

    final isHe = card.language == 'he';
    final t = Theme.of(context).textTheme;
    final arrow = isHe ? '←' : '→';
    final label = isHe
        ? 'קריאת הכתבה המלאה ב־${src.publisher}'
        : 'Read full story on ${src.publisher}';

    return Directionality(
      // Force this widget to render in the card's own direction so mixed
      // (UI=HE, card=EN) rendering doesn't reorder the publisher name.
      textDirection: isHe ? TextDirection.rtl : TextDirection.ltr,
      child: InkWell(
        onTap: () async {
          final uri = Uri.tryParse(src.url);
          if (uri == null) return;
          SignalTracker(ref).recordSourceOpened(card);
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        },
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
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
      ),
    );
  }
}
