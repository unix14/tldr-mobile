import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Async lazy-init SharedPreferences provider.
final sharedPrefsProvider = FutureProvider<SharedPreferences>(
  (_) async => SharedPreferences.getInstance(),
);

const _kOnboarded = 'onboarded';
const _kLanguage = 'language';
const _kInterests = 'interests';
const _kInterestWeights = 'interest_weights';
const _kLibrary = 'library';
const _kSeen = 'seen';
const _kSessionMinutes = 'session_minutes';
const _kNightAuto = 'night_auto';
const _kAllowSensitive = 'allow_sensitive';

class SettingsSnapshot {
  final bool onboarded;
  final String language;
  final Set<String> interests;
  final Map<String, double> interestWeights;
  final Set<String> librarySavedIds;
  final Set<String> seenIds;
  final int sessionMinutes;
  final bool nightAuto;
  final bool allowSensitive;

  const SettingsSnapshot({
    required this.onboarded,
    required this.language,
    required this.interests,
    required this.interestWeights,
    required this.librarySavedIds,
    required this.seenIds,
    required this.sessionMinutes,
    required this.nightAuto,
    required this.allowSensitive,
  });

  SettingsSnapshot copyWith({
    bool? onboarded,
    String? language,
    Set<String>? interests,
    Map<String, double>? interestWeights,
    Set<String>? librarySavedIds,
    Set<String>? seenIds,
    int? sessionMinutes,
    bool? nightAuto,
    bool? allowSensitive,
  }) =>
      SettingsSnapshot(
        onboarded: onboarded ?? this.onboarded,
        language: language ?? this.language,
        interests: interests ?? this.interests,
        interestWeights: interestWeights ?? this.interestWeights,
        librarySavedIds: librarySavedIds ?? this.librarySavedIds,
        seenIds: seenIds ?? this.seenIds,
        sessionMinutes: sessionMinutes ?? this.sessionMinutes,
        nightAuto: nightAuto ?? this.nightAuto,
        allowSensitive: allowSensitive ?? this.allowSensitive,
      );

  factory SettingsSnapshot.fromPrefs(SharedPreferences p) {
    final weightsList = p.getStringList(_kInterestWeights) ?? const [];
    final weights = <String, double>{};
    for (final entry in weightsList) {
      final parts = entry.split('|');
      if (parts.length == 2) {
        weights[parts[0]] = double.tryParse(parts[1]) ?? 1.0;
      }
    }
    return SettingsSnapshot(
      onboarded: p.getBool(_kOnboarded) ?? false,
      language: p.getString(_kLanguage) ?? 'en',
      interests: (p.getStringList(_kInterests) ?? const []).toSet(),
      interestWeights: weights,
      librarySavedIds: (p.getStringList(_kLibrary) ?? const []).toSet(),
      seenIds: (p.getStringList(_kSeen) ?? const []).toSet(),
      sessionMinutes: p.getInt(_kSessionMinutes) ?? 15,
      nightAuto: p.getBool(_kNightAuto) ?? true,
      allowSensitive: p.getBool(_kAllowSensitive) ?? false,
    );
  }
}

class SettingsController extends Notifier<SettingsSnapshot> {
  late SharedPreferences _prefs;

  @override
  SettingsSnapshot build() {
    return const SettingsSnapshot(
      onboarded: false,
      language: 'en',
      interests: {},
      interestWeights: {},
      librarySavedIds: {},
      seenIds: {},
      sessionMinutes: 15,
      nightAuto: true,
      allowSensitive: false,
    );
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    state = SettingsSnapshot.fromPrefs(_prefs);
  }

  Future<void> completeOnboarding({
    required String language,
    required Set<String> interests,
  }) async {
    final weights = <String, double>{
      for (final id in interests) id: 1.0,
    };
    await _prefs.setBool(_kOnboarded, true);
    await _prefs.setString(_kLanguage, language);
    await _prefs.setStringList(_kInterests, interests.toList());
    await _saveWeights(weights);
    state = state.copyWith(
      onboarded: true,
      language: language,
      interests: interests,
      interestWeights: weights,
    );
  }

  Future<void> setLanguage(String lang) async {
    await _prefs.setString(_kLanguage, lang);
    state = state.copyWith(language: lang);
  }

  Future<void> setInterests(Set<String> interests) async {
    final weights = Map<String, double>.from(state.interestWeights);
    // Add any new interest with 1.0; keep existing weights; drop removed.
    for (final id in interests) {
      weights.putIfAbsent(id, () => 1.0);
    }
    weights.removeWhere((k, _) => !interests.contains(k));
    await _prefs.setStringList(_kInterests, interests.toList());
    await _saveWeights(weights);
    state = state.copyWith(interests: interests, interestWeights: weights);
  }

  Future<void> setSessionMinutes(int m) async {
    await _prefs.setInt(_kSessionMinutes, m);
    state = state.copyWith(sessionMinutes: m);
  }

  Future<void> setNightAuto(bool v) async {
    await _prefs.setBool(_kNightAuto, v);
    state = state.copyWith(nightAuto: v);
  }

  Future<void> setAllowSensitive(bool v) async {
    await _prefs.setBool(_kAllowSensitive, v);
    state = state.copyWith(allowSensitive: v);
  }

  Future<void> toggleSave(String id) async {
    final saved = Set<String>.from(state.librarySavedIds);
    if (saved.contains(id)) {
      saved.remove(id);
    } else {
      saved.add(id);
    }
    await _prefs.setStringList(_kLibrary, saved.toList());
    state = state.copyWith(librarySavedIds: saved);
  }

  Future<void> markSeen(String id) async {
    final seen = Set<String>.from(state.seenIds)..add(id);
    // Cap seen history to avoid unbounded growth.
    final list = seen.toList();
    if (list.length > 500) {
      list.removeRange(0, list.length - 500);
    }
    await _prefs.setStringList(_kSeen, list);
    state = state.copyWith(seenIds: list.toSet());
  }

  Future<void> adjustInterestWeight(String topic, double delta) async {
    final weights = Map<String, double>.from(state.interestWeights);
    final cur = weights[topic] ?? 1.0;
    final next = (cur + delta).clamp(0.1, 3.0);
    weights[topic] = next;
    await _saveWeights(weights);
    state = state.copyWith(interestWeights: weights);
  }

  Future<void> clearAll() async {
    await _prefs.clear();
    state = SettingsSnapshot.fromPrefs(_prefs);
  }

  Future<void> _saveWeights(Map<String, double> weights) async {
    final list = weights.entries.map((e) => '${e.key}|${e.value}').toList();
    await _prefs.setStringList(_kInterestWeights, list);
  }
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, SettingsSnapshot>(
        SettingsController.new);
