import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'data/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final container = ProviderContainer();
  await container.read(settingsControllerProvider.notifier).init();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const TldrApp(),
    ),
  );
}
