import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/config.dart';
import 'app/providers.dart';
import 'data/backend_factory.dart';
import 'data/local/local_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  if (config.missingFirebase) {
    runApp(const SetupNoticeApp());
    return;
  }
  final backend = await createBackend(config);
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(config),
      backendProvider.overrideWithValue(backend),
      localStoreProvider.overrideWithValue(LocalStore(prefs)),
    ],
    child: const AsistenteApp(),
  ));
}
