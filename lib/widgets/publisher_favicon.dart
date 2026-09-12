import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Renders a small favicon for a source publisher.
///
/// * If a source URL is provided, we fetch the favicon via
///   `https://www.google.com/s2/favicons?domain=<host>&sz=64` — no auth,
///   cacheable, works for effectively any public publisher domain.
/// * If the URL can't be parsed or the request fails, we fall back to a
///   monogram square (first letter of publisher name) so the meta row always
///   renders cleanly.
///
/// Intentionally not clickable — the whole row / Sources button already
/// carries navigation.
class PublisherFavicon extends StatelessWidget {
  final String publisher;
  final String? url;
  final double size;

  const PublisherFavicon({
    super.key,
    required this.publisher,
    this.url,
    this.size = 14,
  });

  String? _host() {
    if (url == null || url!.isEmpty) return null;
    try {
      final u = Uri.parse(url!);
      return u.host.isEmpty ? null : u.host;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final host = _host();
    final radius = BorderRadius.circular(3);
    Widget monogram() => Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.divider,
            borderRadius: radius,
          ),
          child: Text(
            publisher.isEmpty ? '·' : publisher.characters.first.toUpperCase(),
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: size * 0.65,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        );

    if (host == null) return monogram();
    final src =
        'https://www.google.com/s2/favicons?domain=$host&sz=64';
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          src,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => monogram(),
          loadingBuilder: (context, child, loading) =>
              loading == null ? child : monogram(),
        ),
      ),
    );
  }
}
