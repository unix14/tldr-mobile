import 'package:flutter/material.dart';

import '../models/card.dart';
import '../theme/colors.dart';

class ConfidenceChip extends StatelessWidget {
  final Confidence confidence;
  final String language;
  const ConfidenceChip({
    super.key,
    required this.confidence,
    required this.language,
  });

  @override
  Widget build(BuildContext context) {
    // Never show a chip for the default state — cards are presumed confirmed
    // by default and the chip becomes visual noise.
    if (confidence == Confidence.confirmed) {
      return const SizedBox.shrink();
    }
    final (label, color) = _map(language);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            letterSpacing: 0.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  (String, Color) _map(String lang) {
    switch (confidence) {
      case Confidence.confirmed:
        return (lang == 'he' ? 'מאומת' : 'Confirmed', AppColors.confirmed);
      case Confidence.developing:
        return (lang == 'he' ? 'מתפתח' : 'Developing', AppColors.developing);
      case Confidence.disputed:
        return (lang == 'he' ? 'במחלוקת' : 'Disputed', AppColors.disputed);
      case Confidence.analysis:
        return (lang == 'he' ? 'ניתוח' : 'Analysis', AppColors.analysis);
      case Confidence.opinion:
        return (lang == 'he' ? 'דעה' : 'Opinion', AppColors.opinion);
      case Confidence.unverified:
        return (lang == 'he' ? 'לא מאומת' : 'Unverified', AppColors.disputed);
    }
  }
}
