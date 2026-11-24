/// Strict, typed readers for persisted JSON (pure Dart).
///
/// Every reader throws [FormatException] when a value has the wrong type, so a
/// corrupt document is rejected as a whole instead of producing half-valid
/// state. Missing keys fall back to [fallback] when one is given, which keeps
/// older documents of the same schema readable after fields are added.
library;

/// A decoded JSON object.
typedef JsonMap = Map<String, Object?>;

/// Casts [value] to a JSON object or throws [FormatException].
JsonMap asJsonMap(Object? value, String what) {
  if (value is Map<String, Object?>) return value;
  throw FormatException('Expected a JSON object for $what');
}

/// Reads an integer at [key].
int readInt(JsonMap json, String key, {int? fallback}) {
  final value = json[key];
  if (value is int) return value;
  if (value == null && fallback != null) return fallback;
  throw FormatException('Expected an integer at "$key"');
}

/// Reads an optional integer at [key] (missing or null gives null).
int? readOptionalInt(JsonMap json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is int) return value;
  throw FormatException('Expected an integer or null at "$key"');
}

/// Reads a string at [key].
String readString(JsonMap json, String key, {String? fallback}) {
  final value = json[key];
  if (value is String) return value;
  if (value == null && fallback != null) return fallback;
  throw FormatException('Expected a string at "$key"');
}

/// Reads an optional string at [key] (missing or null gives null).
String? readOptionalString(JsonMap json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException('Expected a string or null at "$key"');
}

/// Reads a boolean at [key].
bool readBool(JsonMap json, String key, {bool? fallback}) {
  final value = json[key];
  if (value is bool) return value;
  if (value == null && fallback != null) return fallback;
  throw FormatException('Expected a boolean at "$key"');
}

/// Reads a list at [key], converting each item with [parse].
///
/// A missing key gives an empty list.
List<T> readList<T>(JsonMap json, String key, T Function(Object? item) parse) {
  final value = json[key];
  if (value == null) return <T>[];
  if (value is List<Object?>) return value.map(parse).toList();
  throw FormatException('Expected a list at "$key"');
}

/// Reads a list of strings at [key] (missing gives an empty list).
List<String> readStringList(JsonMap json, String key) {
  return readList<String>(json, key, (item) {
    if (item is String) return item;
    throw FormatException('Expected only strings in "$key"');
  });
}

/// Reads an enum stored by its [Enum.name].
T readEnum<T extends Enum>(
  JsonMap json,
  String key,
  List<T> values, {
  T? fallback,
}) {
  final value = json[key];
  if (value == null && fallback != null) return fallback;
  if (value is String) {
    for (final candidate in values) {
      if (candidate.name == value) return candidate;
    }
  }
  throw FormatException('Unknown value at "$key"');
}
