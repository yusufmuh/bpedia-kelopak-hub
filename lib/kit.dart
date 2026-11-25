/// Kit pesta dan sprite Bipy untuk aplikasi induk.
///
/// `import 'package:kelopak_hub/kit.dart'` memberi seluruh komponen kit
/// (tombol permen, konfeti, lembar hasil, sprite) plus empat animasi Bipy yang
/// dibawa paket ini.
library;

import 'package:flutter/widgets.dart';

import 'src/kit/kit.dart';

export 'src/kit/kit.dart';

/// Lembar sprite Bipy milik paket `kelopak_hub` (12 fps, urut baris).
abstract final class BipySprites {
  /// Nama paket pemilik aset.
  static const String package = 'kelopak_hub';

  /// Berdiri dan bernapas.
  static const SpriteSheetSpec idle = SpriteSheetSpec(
    asset: 'assets/bipy/bipy_diam.webp',
    package: package,
    columns: 8,
    rows: 3,
    frameCount: 22,
    frameSize: Size(188, 340),
    loopMode: SpriteLoopMode.pingPong,
  );

  /// Melambaikan tangan sekali.
  static const SpriteSheetSpec wave = SpriteSheetSpec(
    asset: 'assets/bipy/bipy_sapa.webp',
    package: package,
    columns: 10,
    rows: 4,
    frameCount: 40,
    frameSize: Size(200, 340),
    loopMode: SpriteLoopMode.once,
  );

  /// Mengintip dari tas belanja.
  static const SpriteSheetSpec peek = SpriteSheetSpec(
    asset: 'assets/bipy/bipy_tas.webp',
    package: package,
    columns: 6,
    rows: 3,
    frameCount: 18,
    frameSize: Size(264, 320),
    loopMode: SpriteLoopMode.pingPong,
  );

  /// Berjalan di tempat.
  static const SpriteSheetSpec walk = SpriteSheetSpec(
    asset: 'assets/bipy/bipy_jalan.webp',
    package: package,
    columns: 6,
    rows: 5,
    frameCount: 28,
    frameSize: Size(320, 340),
  );

  /// Semua lembar, untuk pramuat dan tes.
  static const List<SpriteSheetSpec> values = <SpriteSheetSpec>[idle, wave, peek, walk];
}

/// Bipy bergerak dari salah satu [BipySprites].
class BipySprite extends StatelessWidget {
  /// Membuat animasi Bipy setinggi [height].
  const BipySprite(
    this.spec, {
    super.key,
    this.height = 96,
    this.playing = true,
    this.alignment = Alignment.bottomCenter,
    this.semanticLabel,
    this.onCompleted,
  });

  /// Lembar yang diputar.
  final SpriteSheetSpec spec;

  /// Tinggi tampil; lebar mengikuti rasio frame.
  final double height;

  /// False menahan frame pertama.
  final bool playing;

  /// Letak frame di dalam kotaknya.
  final Alignment alignment;

  /// Label pembaca layar; null berarti hiasan.
  final String? semanticLabel;

  /// Dipanggil setelah lembar bermode sekali selesai.
  final VoidCallback? onCompleted;

  @override
  Widget build(BuildContext context) {
    return SpriteAnimation(
      spec: spec,
      height: height,
      playing: playing,
      alignment: alignment,
      semanticLabel: semanticLabel,
      onCompleted: onCompleted,
    );
  }
}
