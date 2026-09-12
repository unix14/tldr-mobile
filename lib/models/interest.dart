/// News-only V1 interest catalog. Bilingual labels.
class Interest {
  final String id;
  final String en;
  final String he;

  const Interest({required this.id, required this.en, required this.he});

  String label(String lang) => lang == 'he' ? he : en;
}

const List<Interest> kInterests = [
  Interest(id: 'world', en: 'World News', he: 'חדשות עולם'),
  Interest(id: 'israel', en: 'Israel', he: 'ישראל'),
  Interest(id: 'markets', en: 'Markets', he: 'שווקים'),
  Interest(id: 'tech', en: 'Tech', he: 'טכנולוגיה'),
  Interest(id: 'ai', en: 'AI', he: 'בינה מלאכותית'),
  Interest(id: 'science', en: 'Science', he: 'מדע'),
  Interest(id: 'geopolitics', en: 'Geopolitics', he: 'גאופוליטיקה'),
  Interest(id: 'energy', en: 'Energy', he: 'אנרגיה'),
];
