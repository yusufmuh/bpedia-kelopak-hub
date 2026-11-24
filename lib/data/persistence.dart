/// The single persisted JSON document of the app.
///
/// Key [appStateStorageKey], `"schema": 1`. A missing, corrupt or unknown-schema
/// document loads as a fresh state instead of crashing.
library;

import 'dart:convert';

import '../domain/app_settings.dart';
import '../domain/json_reader.dart';
import '../domain/rewards_engine.dart';
import '../domain/shop_engine.dart';
import 'key_value_store.dart';

/// Storage key of the app document.
const String appStateStorageKey = 'bpedia_preview_state_v1';

/// Schema version written into the document.
const int appStateSchema = 1;

/// Everything the app persists.
final class AppSnapshot {
  AppSnapshot({
    required this.settings,
    required this.clockOffsetDays,
    required this.rewards,
    required this.shop,
  });

  /// State of a first launch.
  factory AppSnapshot.fresh() => AppSnapshot(
    settings: const AppSettings(),
    clockOffsetDays: 0,
    rewards: RewardsState(),
    shop: ShopState(),
  );

  /// Parses a schema-1 document; throws [FormatException] when invalid.
  factory AppSnapshot.fromJson(Object? source) {
    final json = asJsonMap(source, 'document');
    if (readInt(json, 'schema') != appStateSchema) {
      throw const FormatException('Unknown schema');
    }
    final offset = readInt(json, 'clockOffsetDays', fallback: 0);
    if (offset < 0) throw const FormatException('Negative clock offset');
    return AppSnapshot(
      settings: json['settings'] == null
          ? const AppSettings()
          : AppSettings.fromJson(json['settings']),
      clockOffsetDays: offset,
      rewards: json['rewards'] == null
          ? RewardsState()
          : RewardsState.fromJson(json['rewards']),
      shop: json['shop'] == null
          ? ShopState()
          : ShopState.fromJson(json['shop']),
    );
  }

  /// Decodes [raw]; null, corrupt JSON or an unknown schema give [AppSnapshot.fresh].
  factory AppSnapshot.decode(String? raw) {
    if (raw == null || raw.isEmpty) return AppSnapshot.fresh();
    try {
      return AppSnapshot.fromJson(jsonDecode(raw));
    } catch (_) {
      // Any decoding failure (bad JSON, wrong types, module parsing errors)
      // means the document cannot be trusted: start over.
      return AppSnapshot.fresh();
    }
  }

  /// User preferences.
  final AppSettings settings;

  /// Mode Demo day offset added to the real WIB date (0 or more).
  final int clockOffsetDays;

  /// Reward data.
  final RewardsState rewards;

  /// Cart and orders.
  final ShopState shop;

  /// Reads and decodes the document from [store].
  ///
  /// Errors from [KeyValueStore.read] are rethrown so callers can avoid
  /// overwriting data they could not read.
  static Future<AppSnapshot> load(KeyValueStore store) async {
    final raw = await store.read(appStateStorageKey);
    return AppSnapshot.decode(raw);
  }

  /// Writes the document to [store].
  Future<void> save(KeyValueStore store) =>
      store.write(appStateStorageKey, encode());

  /// JSON text of [toJson].
  String encode() => jsonEncode(toJson());

  /// Serializes the snapshot.
  Map<String, Object?> toJson() => <String, Object?>{
    'schema': appStateSchema,
    'settings': settings.toJson(),
    'clockOffsetDays': clockOffsetDays,
    'rewards': rewards.toJson(),
    'shop': shop.toJson(),
  };
}
