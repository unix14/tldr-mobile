import 'package:flutter/material.dart';

import '../theme/colors.dart';

class SourceBadge extends StatelessWidget {
  final String publisher;
  const SourceBadge({super.key, required this.publisher});

  @override
  Widget build(BuildContext context) {
    return Text(
      publisher,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 11.5,
        letterSpacing: 0.2,
        fontWeight: FontWeight.w500,
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }
}
