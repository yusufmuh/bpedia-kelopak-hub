/// User preferences (Akun > Suara & getar, Tampilan).
library;

import 'package:flutter/material.dart' show ThemeMode;

import 'json_reader.dart';

/// Immutable user preferences.
final class AppSettings {
  const AppSettings({
    this.sfxEnabled = true,
    this.musicEnabled = false,
    this.hapticsEnabled = true,
    this.themeMode = ThemeMode.system,
  });

  /// Restores settings written by [toJson]; missing keys use the defaults.
  factory AppSettings.fromJson(Object? source) {
    final json = asJsonMap(source, 'settings');
    return AppSettings(
      sfxEnabled: readBool(json, 'sfxEnabled', fallback: true),
      musicEnabled: readBool(json, 'musicEnabled', fallback: false),
      hapticsEnabled: readBool(json, 'hapticsEnabled', fallback: true),
      themeMode: readEnum(
        json,
        'themeMode',
        ThemeMode.values,
        fallback: ThemeMode.system,
      ),
    );
  }

  /// Sound effects on (default on).
  final bool sfxEnabled;

  /// Background music on the Hadiah and game screens (default off).
  final bool musicEnabled;

  /// Vibration feedback (default on).
  final bool hapticsEnabled;

  /// Ikuti sistem / Terang / Gelap.
  final ThemeMode themeMode;

  /// Returns a copy with the given fields replaced.
  AppSettings copyWith({
    bool? sfxEnabled,
    bool? musicEnabled,
    bool? hapticsEnabled,
    ThemeMode? themeMode,
  }) {
    return AppSettings(
      sfxEnabled: sfxEnabled ?? this.sfxEnabled,
      musicEnabled: musicEnabled ?? this.musicEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  /// Serializes the settings.
  Map<String, Object?> toJson() => <String, Object?>{
    'sfxEnabled': sfxEnabled,
    'musicEnabled': musicEnabled,
    'hapticsEnabled': hapticsEnabled,
    'themeMode': themeMode.name,
  };

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.sfxEnabled == sfxEnabled &&
      other.musicEnabled == musicEnabled &&
      other.hapticsEnabled == hapticsEnabled &&
      other.themeMode == themeMode;

  @override
  int get hashCode =>
      Object.hash(sfxEnabled, musicEnabled, hapticsEnabled, themeMode);
}
