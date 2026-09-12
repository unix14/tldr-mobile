import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card.dart';

class ContentRepository {
  const ContentRepository();

  Future<List<ContentCard>> loadAll() async {
    final raw = await rootBundle.loadString('assets/content/cards.json');
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => ContentCard.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final contentRepositoryProvider =
    Provider<ContentRepository>((_) => const ContentRepository());

final allCardsProvider = FutureProvider<List<ContentCard>>((ref) async {
  return ref.read(contentRepositoryProvider).loadAll();
});
