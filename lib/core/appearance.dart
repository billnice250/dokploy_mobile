import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeModeKey = 'dploygo.theme_mode';

class AppearanceStore {
  const AppearanceStore();

  Future<ThemeMode> load() async {
    try {
      final value =
          (await SharedPreferences.getInstance()).getString(_themeModeKey);
      return ThemeMode.values.where((mode) => mode.name == value).firstOrNull ??
          ThemeMode.system;
    } catch (_) {
      return ThemeMode.system;
    }
  }

  Future<void> save(ThemeMode mode) async {
    await (await SharedPreferences.getInstance())
        .setString(_themeModeKey, mode.name);
  }
}

class AppearanceController extends StateNotifier<ThemeMode> {
  AppearanceController({
    required AppearanceStore store,
    ThemeMode initialMode = ThemeMode.system,
  })  : _store = store,
        super(initialMode);

  final AppearanceStore _store;

  Future<void> setMode(ThemeMode mode) async {
    if (state == mode) return;
    state = mode;
    try {
      await _store.save(mode);
    } catch (_) {
      // Keep the in-memory selection when preferences are unavailable.
    }
  }
}

final appearanceStoreProvider = Provider((ref) => const AppearanceStore());

final themeModeProvider =
    StateNotifierProvider<AppearanceController, ThemeMode>((ref) {
  return AppearanceController(store: ref.watch(appearanceStoreProvider));
});

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
