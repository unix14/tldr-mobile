enum CardKind { news, video, explainer, whyItMatters }

enum Confidence { confirmed, developing, disputed, analysis, opinion, unverified }

enum Risk { standard, sensitive, highRisk, distressing }

class SourceRef {
  final String publisher;
  final String url;
  final String? note;
  final DateTime publishedAt;
  final int tier; // 0..4 (0 = primary)

  SourceRef({
    required this.publisher,
    required this.url,
    DateTime? publishedAt,
    this.note,
    this.tier = 1,
  }) : publishedAt =
            publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  factory SourceRef.fromJson(Map<String, dynamic> j) => SourceRef(
        publisher: j['publisher'] as String,
        url: j['url'] as String,
        note: j['note'] as String?,
        tier: j['tier'] as int? ?? 1,
        publishedAt:
            DateTime.tryParse(j['publishedAt'] as String? ?? ''),
      );
}

class ContentCard {
  final String id;
  final CardKind kind;
  final String language; // 'en' or 'he'
  final List<String> topicTags;
  final String headline;
  final List<String> bullets;
  final String? whyItMatters;
  final Confidence confidence;
  final Risk risk;
  final int estimatedSeconds;
  final DateTime publishedAt;
  final List<SourceRef> sources;
  final String? disagreement;

  // Video-specific
  final String? youtubeId;
  final String? channel;

  // Optional imagery
  final String? imageUrl;

  const ContentCard({
    required this.id,
    required this.kind,
    required this.language,
    required this.topicTags,
    required this.headline,
    required this.bullets,
    required this.confidence,
    required this.risk,
    required this.estimatedSeconds,
    required this.publishedAt,
    required this.sources,
    this.whyItMatters,
    this.disagreement,
    this.youtubeId,
    this.channel,
    this.imageUrl,
  });

  factory ContentCard.fromJson(Map<String, dynamic> j) => ContentCard(
        id: j['id'] as String,
        kind: CardKind.values.firstWhere((k) => k.name == j['kind']),
        language: j['language'] as String? ?? 'en',
        topicTags: (j['topicTags'] as List).cast<String>(),
        headline: j['headline'] as String,
        bullets: (j['bullets'] as List? ?? const []).cast<String>(),
        whyItMatters: j['whyItMatters'] as String?,
        confidence: Confidence.values
            .firstWhere((c) => c.name == (j['confidence'] ?? 'confirmed')),
        risk: Risk.values.firstWhere((r) => r.name == (j['risk'] ?? 'standard')),
        estimatedSeconds: j['estimatedSeconds'] as int? ?? 45,
        publishedAt:
            DateTime.tryParse(j['publishedAt'] as String? ?? '') ?? DateTime.now(),
        sources: (j['sources'] as List? ?? const [])
            .map((s) => SourceRef.fromJson(s as Map<String, dynamic>))
            .toList(),
        disagreement: j['disagreement'] as String?,
        youtubeId: j['youtubeId'] as String?,
        channel: j['channel'] as String?,
        imageUrl: j['imageUrl'] as String?,
      );

  bool get hasVideo => youtubeId != null && youtubeId!.isNotEmpty;
  bool get hasGoDeeper => hasVideo || sources.isNotEmpty;
}
