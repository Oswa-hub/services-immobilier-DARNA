import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Configuration comes from `.env` (declared as an asset in pubspec.yaml).
    await dotenv.load(fileName: '.env');
    await _initFirebase().timeout(const Duration(seconds: 20));
  } catch (e, st) {
    // Never a silent black screen: show what failed at start-up.
    debugPrint('DARNA start-up failed: $e\n$st');
    runApp(_StartupErrorApp(error: '$e'));
    return;
  }
  runApp(const ProviderScope(child: ImmoFindApp()));
}

/// On Android the native SDK already starts the default Firebase app from
/// `android/app/google-services.json` (the source of truth for com.darna.app),
/// so Dart reuses it instead of starting a second one from `.env`, which failed
/// with [core/duplicate-app] when the two ids differed. Other platforms use `.env`.
Future<void> _initFirebase() async {
  final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  try {
    await Firebase.initializeApp(options: android ? null : DefaultFirebaseOptions.currentPlatform);
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
  }
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text('DARNA ne peut pas démarrer',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                // The technical detail only in debug builds.
                Text(kReleaseMode ? 'Vérifiez votre connexion et relancez l\'application.' : error,
                    textAlign: TextAlign.center),
              ]),
            ),
          ),
        ),
      );
}
