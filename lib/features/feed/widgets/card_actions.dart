import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data/session_stats.dart';
import '../../../data/settings_repository.dart';
import '../../../data/signals.dart';
import '../../../models/card.dart';
import '../../../theme/colors.dart';
import 'sources_sheet.dart';
import 'video_player_drawer.dart';

/// Card action row.
///
/// The row is *chrome*, not article body — its labels follow the UI
/// language (settings.language), not the card's language. That way a
/// Hebrew user reading an English article still sees Hebrew action
/// labels; only the article body renders in its own direction.
///
/// No More/Less buttons anymore — interest weights are driven by
/// implicit signals (dwell, save, sources open) via `SignalTracker`.
/// Unsave still lives here (single tap on Save toggles); double-tap on
/// the card body is save-only (never unsave — that behaviour lives in
/// `GestureLayer`).
class CardActions extends ConsumerStatefulWidget {
  final ContentCard card;
  const CardActions({super.key, required this.card});

  @override
  ConsumerState<CardActions> createState() => _CardActionsState();
}

class _CardActionsState extends ConsumerState<CardActions>
    with SingleTickerProviderStateMixin {
  late final AnimationController _saveAnim;

  @override
  void initState() {
    super.initState();
    _saveAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
  }

  @override
  void dispose() {
    _saveAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
    final saved = settings.librarySavedIds.contains(widget.card.id);
    final isHe = settings.language == 'he';

    Widget btn({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
      Color? color,
      Widget? iconOverride,
    }) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                iconOverride ??
                    Icon(icon,
                        size: 22, color: color ?? AppColors.textPrimary),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: color ?? AppColors.textSecondary,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        btn(
          icon: saved ? Icons.bookmark : Icons.bookmark_border,
          color: saved ? AppColors.accent : null,
          label: isHe ? 'שמור' : 'Save',
          iconOverride: AnimatedBuilder(
            animation: _saveAnim,
            builder: (context, _) {
              final t = _saveAnim.value;
              final scale = 1.0 + (0.35 * (t < 0.5 ? t * 2 : (1 - t) * 2));
              return Transform.scale(
                scale: scale,
                child: Icon(
                  saved ? Icons.bookmark : Icons.bookmark_border,
                  size: 22,
                  color: saved ? AppColors.accent : AppColors.textPrimary,
                ),
              );
            },
          ),
          onTap: () async {
            HapticFeedback.selectionClick();
            _saveAnim.forward(from: 0);
            final messenger = ScaffoldMessenger.of(context);
            final becomingSaved = !saved;
            await ref
                .read(settingsControllerProvider.notifier)
                .toggleSave(widget.card.id);
            if (becomingSaved) {
              ref.read(sessionStatsProvider.notifier).markSaved();
              await SignalTracker(ref).recordSave(widget.card);
              _showToast(
                  messenger, isHe ? 'נשמר לספרייה' : 'Saved to Library');
            }
          },
        ),
        btn(
          icon: Icons.article_outlined,
          label: isHe ? 'מקורות' : 'Sources',
          onTap: () => _showSources(context),
        ),
        if (widget.card.hasVideo)
          btn(
            icon: Icons.play_circle_outline,
            label: isHe ? 'צפייה' : 'Watch',
            onTap: () => _showPlayer(context),
          ),
        btn(
          icon: Icons.ios_share,
          label: isHe ? 'שתף' : 'Share',
          onTap: () => _share(),
        ),
      ],
    );
  }

  void _showSources(BuildContext context) {
    ref.read(sessionStatsProvider.notifier).markSourcesOpened();
    SignalTracker(ref).recordSourcesOpened(widget.card);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SourcesSheet(card: widget.card),
    );
  }

  void _showPlayer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surfaceElevated,
      builder: (_) => VideoPlayerDrawer(card: widget.card),
    );
  }

  Future<void> _share() async {
    final firstSource =
        widget.card.sources.isNotEmpty ? widget.card.sources.first.url : '';
    final body = [
      widget.card.headline,
      if (widget.card.whyItMatters != null) '\n${widget.card.whyItMatters}',
      if (firstSource.isNotEmpty) '\n\n$firstSource',
      '\n\nvia tldr',
    ].join();
    await Share.share(body);
  }

  void _showToast(ScaffoldMessengerState messenger, String msg) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 1),
        backgroundColor: AppColors.surfaceElevated,
      ),
    );
  }
}
