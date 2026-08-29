import 'package:shared_preferences/shared_preferences.dart';

abstract interface class ThemePreferencesRepository {
  Future<bool?> loadDarkMode();
  Future<void> saveDarkMode(bool enabled);
}

class SharedPreferencesThemePreferencesRepository
    implements ThemePreferencesRepository {
  static const _key = 'fluir.dark_mode';

  const SharedPreferencesThemePreferencesRepository(this._preferences);
  final SharedPreferences _preferences;

  @override
  Future<bool?> loadDarkMode() async => _preferences.getBool(_key);

  @override
  Future<void> saveDarkMode(bool enabled) =>
      _preferences.setBool(_key, enabled);
}

class MemoryThemePreferencesRepository implements ThemePreferencesRepository {
  MemoryThemePreferencesRepository([this.value]);
  bool? value;

  @override
  Future<bool?> loadDarkMode() async => value;

  @override
  Future<void> saveDarkMode(bool enabled) async => value = enabled;
}
