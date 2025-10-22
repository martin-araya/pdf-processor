import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// FutureProvider para SharedPreferences (async init)
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  ref.keepAlive();  // Mantiene alive para reuse
  return prefs;
});
