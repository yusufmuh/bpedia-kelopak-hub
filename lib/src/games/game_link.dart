/// Sambungan bersama antara controller game hub dan [KelopakController].
library;

import 'package:flutter/foundation.dart';

import '../controller/kelopak_controller.dart';
import '../host/kelopak_host.dart';
import '../kit/game_cue.dart';
import 'game_actions.dart';

/// Mendengarkan [kelopak], meneruskan perubahan ke pendengar game, dan
/// menyediakan jalan pintas ke host. Dipakai ketiga controller game hub.
mixin KelopakGameLink on ChangeNotifier {
  late final KelopakController _kelopak;
  VoidCallback? _onOpenTerms;
  ValueChanged<String>? _onOpenPath;
  bool _linkDisposed = false;

  /// Sumber data Kelopak.
  KelopakController get kelopak => _kelopak;

  /// Aplikasi induk, bila ada.
  KelopakHost? get host => _kelopak.host;

  /// Aksi tambahan host, bila host menyediakannya.
  KelopakGameActions? get gameActions {
    final Object? current = host;
    return current is KelopakGameActions ? current : null;
  }

  /// Dipanggil konstruktor controller.
  @protected
  void linkTo(
    KelopakController kelopak, {
    VoidCallback? onOpenTerms,
    ValueChanged<String>? onOpenPath,
  }) {
    _kelopak = kelopak;
    _onOpenTerms = onOpenTerms;
    _onOpenPath = onOpenPath;
    kelopak.addListener(_kelopakChanged);
  }

  /// Dipanggil saat data Kelopak berubah, sebelum pendengar diberi tahu.
  @protected
  void onKelopakChanged() {}

  void _kelopakChanged() {
    if (_linkDisposed) return;
    onKelopakChanged();
    notifyListeners();
  }

  /// Memutar isyarat [cueName] lewat host (nama `GameCue` modul sama dengan
  /// nama `GameCue` hub).
  @protected
  void playCueNamed(String cueName) {
    for (final cue in GameCue.values) {
      if (cue.name == cueName) {
        host?.playCue(cue);
        return;
      }
    }
  }

  /// Status suara host; null bila host tidak menyediakan sakelar suara.
  @protected
  bool? get hostSoundOn => gameActions?.soundOn;

  /// Mengubah suara host lalu memberi tahu pendengar.
  @protected
  void setHostSound(bool value) {
    final actions = gameActions;
    if (actions == null) return;
    actions.setSoundOn(value);
    notifyListeners();
  }

  /// Membuka aturan lengkap (lembar "Cara pakai" milik layar pembungkus).
  @protected
  void openTermsSheet() => _onOpenTerms?.call();

  /// Membuka jalur hub [path] lewat layar pembungkus.
  @protected
  void openHubPath(String path) => _onOpenPath?.call(path);

  /// Melepas pendengar; panggil dari `dispose` controller.
  @protected
  void unlink() {
    _linkDisposed = true;
    _kelopak.removeListener(_kelopakChanged);
  }
}
