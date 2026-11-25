/// Penyimpanan kunci-nilai teks untuk dokumen tersimpan (tanpa plugin).
///
/// Aplikasi host menyediakan implementasi berbasis penyimpanan perangkat.
library;

/// Asynchronous string storage.
abstract interface class KeyValueStore {
  /// Value stored under [key], or null.
  Future<String?> read(String key);

  /// Stores [value] under [key].
  Future<void> write(String key, String value);

  /// Removes [key].
  Future<void> delete(String key);
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
