/// Minimal string key-value storage used for the persisted app document.
library;

import 'package:shared_preferences/shared_preferences.dart';

/// Asynchronous string storage.
abstract interface class KeyValueStore {
  /// Value stored under [key], or null.
  Future<String?> read(String key);

  /// Stores [value] under [key].
  Future<void> write(String key, String value);

  /// Removes [key].
  Future<void> delete(String key);
}

/// Production store backed by [SharedPreferencesAsync]
/// (DataStore on Android, NSUserDefaults on iOS, localStorage on web).
final class SharedPreferencesKeyValueStore implements KeyValueStore {
  /// Uses [preferences] or a default [SharedPreferencesAsync].
  ///
  /// Throws [StateError] when no shared_preferences platform is registered.
  SharedPreferencesKeyValueStore([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> read(String key) => _preferences.getString(key);

  @override
  Future<void> write(String key, String value) =>
      _preferences.setString(key, value);

  @override
  Future<void> delete(String key) => _preferences.remove(key);
}

/// In-memory store for tests and as a fallback when no platform store exists.
final class MemoryKeyValueStore implements KeyValueStore {
  /// Starts with a copy of [initial].
  MemoryKeyValueStore([Map<String, String> initial = const <String, String>{}])
    : _values = Map<String, String>.of(initial);

  final Map<String, String> _values;

  /// Read-only view of the stored values.
  Map<String, String> get values => Map<String, String>.unmodifiable(_values);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}
