/// Shared human-readable relative-date formatter.
///
/// Used in card bylines and in the Sources sheet. Returns short forms
/// ("2h ago", "3d ago", "just now") so it fits in a compact meta row.
String formatRelative(DateTime? when, {required bool isHe}) {
  if (when == null) return '';
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);
  if (when == epoch) return '';
  final diff = DateTime.now().difference(when);

  if (diff.inSeconds < 60) return isHe ? 'עכשיו' : 'just now';
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
  // Older than a week — show absolute short date.
  return '${when.day}.${when.month}.${when.year % 100}';
}
