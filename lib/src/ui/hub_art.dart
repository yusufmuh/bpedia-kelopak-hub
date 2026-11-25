/// Seni 3D, pose Bipy, dan stiker milik paket `kelopak_hub`.
library;

import 'package:flutter/painting.dart';

/// Gambar paket hub (WebP beralfa). Dirujuk dengan `package:` supaya tetap
/// terbaca dari aplikasi induk.
abstract final class HubArt {
  static const String _package = 'kelopak_hub';

  /// Koin Kelopak 3D.
  static const AssetImage coin = AssetImage(
    'assets/art/coin.webp',
    package: _package,
  );

  /// Kalender bercentang (kartu Check-in Harian).
  static const AssetImage calendar = AssetImage(
    'assets/art/calendar.webp',
    package: _package,
  );

  /// Roda mini (kartu Roda Sabtu).
  static const AssetImage wheel = AssetImage(
    'assets/art/wheel_mini.webp',
    package: _package,
  );

  /// Tas belanja (kartu Misi Belanja).
  static const AssetImage bag = AssetImage(
    'assets/art/bag.webp',
    package: _package,
  );

  /// Kotak kado tertutup (hadiah menunggu).
  static const AssetImage gift = AssetImage(
    'assets/art/gift_closed.webp',
    package: _package,
  );

  /// Kupon tiket (voucher).
  static const AssetImage ticket = AssetImage(
    'assets/art/ticket.webp',
    package: _package,
  );

  /// Bipy melambai sebagai pembawa acara.
  static const AssetImage bipyHost = AssetImage(
    'assets/bipy/bipy_pose_host.webp',
    package: _package,
  );

  /// Bipy melompat gembira.
  static const AssetImage bipyCheer = AssetImage(
    'assets/bipy/bipy_pose_rayakan.webp',
    package: _package,
  );

  /// Stiker kilau emas.
  static const AssetImage sparkle = AssetImage(
    'assets/fx/stiker_kilau.webp',
    package: _package,
  );

  /// Stiker bintang.
  static const AssetImage star = AssetImage(
    'assets/fx/stiker_bintang.webp',
    package: _package,
  );

  /// Stiker hati.
  static const AssetImage heart = AssetImage(
    'assets/fx/stiker_hati.webp',
    package: _package,
  );

  /// Semua gambar, untuk pramuat dan tes.
  static const List<AssetImage> values = <AssetImage>[
    coin,
    calendar,
    wheel,
    bag,
    gift,
    ticket,
    bipyHost,
    bipyCheer,
    sparkle,
    star,
    heart,
  ];
}
