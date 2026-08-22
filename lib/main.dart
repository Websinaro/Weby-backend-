import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'firebase_options.dart';
// Referenced (not called) so the AOT compiler retains overlayMain() as a
// reachable entrypoint - OverlayService.kt looks it up by name at
// runtime via DartExecutor.DartEntrypoint("...", "overlayMain"). Without
// this import, tree-shaking can strip it since main.dart never calls it.
// ignore: unused_import
import 'overlay_main.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    // Falls through in dev builds before `flutterfire configure` has been
    // run - Google sign-in simply won't work until firebase_options.dart
    // is populated with real values. Email/password auth is unaffected.
    debugPrint('Firebase.initializeApp failed: $e');
  }
  runApp(const ProviderScope(child: WebyApp()));
}
