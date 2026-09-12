import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/card.dart';
import '../../../theme/colors.dart';
import '../../../widgets/publisher_favicon.dart';

/// The trust surface.
///
/// Each row is treated like a proper footnote: publisher name, host/date,
/// a subtle chip when it's a primary source (tier 0), open externally on
/// tap and copy the URL on a long-press. Disagreement is rendered in the
/// same callout style as the card body for visual continuity.
class SourcesSheet extends StatelessWidget {
  final ContentCard card;
  const SourcesSheet({super.key, required this.card});

  bool get _isHe => card.language == 'he';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Directionality(
      textDirection: _isHe ? TextDirection.rtl : TextDirection.ltr,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(context, t),
              const SizedBox(height: 18),
              for (var i = 0; i < card.sources.length; i++)
                _SourceRow(source: card.sources[i], isHe: _isHe, index: i),
              if (card.disagreement != null) ...[
                const SizedBox(height: 20),
                _disagreement(context, t),
              ],
              const SizedBox(height: 20),
              _reportRow(context, t),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, TextTheme t) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.divider),
          ),
          child: const Icon(Icons.format_quote_outlined,
              size: 16, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isHe ? 'מקורות' : 'Sources',
                style: t.titleLarge!.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                _isHe
                    ? 'סוכם מ־${card.sources.length} מקורות'
                    : 'Summarised from ${card.sources.length} '
                        '${card.sources.length == 1 ? "source" : "sources"}',
                style: t.bodySmall!.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
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

  Widget _reportRow(BuildContext context, TextTheme t) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isHe
                  ? 'תודה. הכרטיס הועבר לבדיקה.'
                  : 'Thanks. The card has been flagged for review.',
            ),
            backgroundColor: AppColors.surfaceElevated,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.flag_outlined,
                color: AppColors.textMuted, size: 16),
            const SizedBox(width: 8),
            Text(
              _isHe ? 'דיווח על כרטיס זה' : 'Report this card',
              style: t.bodyMedium!.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  final SourceRef source;
  final bool isHe;
  final int index;

  const _SourceRow({
    required this.source,
    required this.isHe,
    required this.index,
  });

  String get _host {
    try {
      final u = Uri.parse(source.url);
      return u.host.replaceFirst(RegExp(r'^www\.'), '');
    } catch (_) {
      return '';
    }
  }

  String _relativeDate() {
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    if (source.publishedAt == epoch) return '';
    final now = DateTime.now();
    final diff = now.difference(source.publishedAt);
    if (diff.inMinutes < 1) return isHe ? 'עכשיו' : 'just now';
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return isHe ? 'לפני $m ד׳' : '${m}m ago';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return isHe ? 'לפני $h ש׳' : '${h}h ago';
    }
    if (diff.inDays < 7) {
      final d = diff.inDays;
      return isHe ? 'לפני $d ימים' : '${d}d ago';
    }
    // Older: absolute date
    final d = source.publishedAt;
    return '${d.day}.${d.month}.${d.year % 100}';
  }

  Future<void> _open() async {
    final uri = Uri.tryParse(source.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: source.url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isHe ? 'הקישור הועתק' : 'Link copied'),
        backgroundColor: AppColors.surfaceElevated,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final host = _host;
    final date = _relativeDate();
    final isPrimary = source.tier == 0;

    // Anim on open: quick fade + tiny slide-up, staggered by index.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + index * 60),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 6),
          child: child,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: _open,
            onLongPress: () => _copy(context),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  PublisherFavicon(
                    publisher: source.publisher,
                    url: source.url,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                source.publisher,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.titleMedium!.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (isPrimary) ...[
                              const SizedBox(width: 8),
                              _primaryBadge(),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if (host.isNotEmpty)
                              Flexible(
                                child: Text(
                                  host,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.bodySmall!.copyWith(
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                            if (host.isNotEmpty && date.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text('·',
                                  style: TextStyle(
                                      color: AppColors.textMuted
                                          .withValues(alpha: 0.6))),
                              const SizedBox(width: 8),
                            ],
                            if (date.isNotEmpty)
                              Text(
                                date,
                                style: t.bodySmall!.copyWith(
                                  color: AppColors.textMuted,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_outward,
                      size: 16, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _primaryBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: AppColors.confirmed.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isHe ? 'ראשי' : 'PRIMARY',
        style: const TextStyle(
          color: AppColors.confirmed,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          height: 1,
        ),
      ),
    );
  }
}
