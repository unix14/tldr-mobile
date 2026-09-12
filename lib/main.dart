import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'data/content_repository.dart';
import 'data/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // SharedPreferences is initialised once and injected into every repo that
  // needs it. Keeps the async warmup out of widget build paths.
  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [
      contentRepositoryProvider.overrideWithValue(ContentRepository(prefs)),
    ],
  );
  await container.read(settingsControllerProvider.notifier).init();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const TldrApp(),
    ),
  );
}
