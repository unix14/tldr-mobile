import 'package:flutter/material.dart';

import '../models/interest.dart';
import '../theme/colors.dart';

/// Topic pill — small-caps, tight tracking, borderless.
///
/// Not a button. Purely a category signal that sits at the top of a card
/// as an eyebrow.
class TopicChip extends StatelessWidget {
  final String topicId;
  final String language;
  const TopicChip({super.key, required this.topicId, required this.language});

  @override
  Widget build(BuildContext context) {
    final label = kInterests
        .firstWhere(
          (i) => i.id == topicId,
          orElse: () => Interest(id: topicId, en: topicId, he: topicId),
        )
        .label(language);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          letterSpacing: 1.1,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}
