import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/content_repository.dart';
import '../../data/settings_repository.dart';
import '../../models/card.dart';
import '../../theme/colors.dart';
import '../feed/widgets/text_card.dart';
import '../feed/widgets/video_card.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final isHe = settings.language == 'he';
    final cardsAsync = ref.watch(allCardsProvider);
    return cardsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (all) {
        final saved =
            all.where((c) => settings.librarySavedIds.contains(c.id)).toList();
        return CustomScrollView(
          slivers: [
            SliverAppBar.large(
              backgroundColor: AppColors.bg,
              title: Text(isHe ? 'ספרייה' : 'Library'),
              pinned: true,
            ),
            if (saved.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _LibraryEmpty(isHe: isHe),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList.separated(
                  itemCount: saved.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) =>
                      _LibraryTile(card: saved[i]),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _LibraryTile extends ConsumerWidget {
  final ContentCard card;
  const _LibraryTile({required this.card});

  bool get _isHe => card.language == 'he';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final publisher =
        card.sources.isNotEmpty ? card.sources.first.publisher : '';
    return Material(
      color: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openFull(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Directionality(
            textDirection:
                _isHe ? TextDirection.rtl : TextDirection.ltr,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (publisher.isNotEmpty) ...[
                        Text(
                          publisher.toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10.5,
                            letterSpacing: 1.0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        card.headline,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium!
                            .copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (card.bullets.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          card.bullets.first,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium!
                              .copyWith(
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: _isHe ? 'הסר' : 'Remove',
                  onPressed: () async {
                    await ref
                        .read(settingsControllerProvider.notifier)
                        .toggleSave(card.id);
                  },
                  icon: const Icon(Icons.close,
                      color: AppColors.textSecondary, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openFull(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, __, ___) => _FullCardScreen(card: card),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
      ),
    );
  }
}

class _FullCardScreen extends StatelessWidget {
  final ContentCard card;
  const _FullCardScreen({required this.card});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: card.kind == CardKind.video && card.hasVideo
          ? VideoCard(card: card)
          : TextCard(card: card),
    );
  }
}

class _LibraryEmpty extends StatelessWidget {
  final bool isHe;
  const _LibraryEmpty({required this.isHe});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.divider),
            ),
            child: const Icon(
              Icons.bookmark_border,
              size: 32,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            isHe ? 'הספרייה שלך שקטה.' : 'Your Library is quiet.',
            textAlign: TextAlign.center,
            style: t.headlineSmall!.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isHe
                ? 'הקש הקשה כפולה על כרטיס או על הסימנייה כדי לשמור אותו לכאן — הכל מקומי, רק על המכשיר שלך.'
                : 'Double-tap a card or use the bookmark to keep it here — everything stays on your device.',
            textAlign: TextAlign.center,
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
