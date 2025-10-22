import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show WidgetsBinding;  // Para postFrameCallback

// Provider global para SharedPreferences (FutureProvider async)
final sharedPrefsProvider = FutureProvider<SharedPreferences>((ref) async {
  return await SharedPreferences.getInstance();
});

class ThemeState {
  final ThemeMode themeMode;
  final bool isLoading;  // Nuevo: Para indicar si prefs loading

  const ThemeState({
    this.themeMode = ThemeMode.system,
    this.isLoading = true,  // Default loading hasta load
  });

  ThemeState copyWith({ThemeMode? themeMode, bool? isLoading}) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ThemeNotifier extends StateNotifier<ThemeState> {
  static const String _themeKey = 'theme_mode';

  ThemeNotifier() : super(const ThemeState(isLoading: true)) {
    // Async init post-frame (no block constructor)
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTheme());
  }

  // Load theme async desde prefs (usa ref? o global; aquí manual await)
  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();  // Direct get (o usa sharedPrefsProvider si inyectas ref)
      final int? modeIndex = prefs.getInt(_themeKey);
      if (modeIndex != null && modeIndex < ThemeMode.values.length) {
        state = state.copyWith(
          themeMode: ThemeMode.values[modeIndex],
          isLoading: false,
        );
        debugPrint('✅ Theme loaded from prefs: ${state.themeMode}');
      } else {
        // Default si no saved
        state = state.copyWith(isLoading: false);
        debugPrint('ℹ️ No theme saved, using default: system');
      }
    } catch (e) {
      debugPrint('❌ Error loading theme: $e');
      state = state.copyWith(isLoading: false);  // Fallback system
    }
  }

  // Toggle theme (async save)
  Future<void> toggleTheme() async {
    final nextMode = _getNextThemeMode();
    state = state.copyWith(
      themeMode: nextMode,
      isLoading: false,  // No loading en toggle
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeKey, nextMode.index);
      debugPrint('✅ Theme saved: $nextMode');
    } catch (e) {
      debugPrint('❌ Error saving theme: $e');  // No rethrow (UX no block)
    }
  }

  ThemeMode _getNextThemeMode() {
    switch (state.themeMode) {
      case ThemeMode.light:
        return ThemeMode.dark;
      case ThemeMode.dark:
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }
}

// StateNotifierProvider para theme (crea notifier sin deps sync)
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  return ThemeNotifier();  // No watch aquí; async internal
});
