import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/tokens.dart';

/// Base names of the brand icon set in `assets/icons` (color variants).
abstract final class BrandIcons {
  static const String akun = 'bpedia-ikon-akun';
  static const String bag = 'bpedia-ikon-bag';
  static const String best = 'bpedia-ikon-best';
  static const String bodycare = 'bpedia-ikon-bodycare';
  static const String chat = 'bpedia-ikon-chat';
  static const String cod = 'bpedia-ikon-cod';
  static const String flash = 'bpedia-ikon-flash';
  static const String fragrance = 'bpedia-ikon-fragrance';
  static const String haircare = 'bpedia-ikon-haircare';
  static const String home = 'bpedia-ikon-home';
  static const String lashes = 'bpedia-ikon-lashes';
  static const String makeup = 'bpedia-ikon-makeup';
  static const String newItem = 'bpedia-ikon-new';
  static const String notif = 'bpedia-ikon-notif';
  static const String ongkir = 'bpedia-ikon-ongkir';
  static const String original = 'bpedia-ikon-original';
  static const String promo = 'bpedia-ikon-promo';
  static const String reward = 'bpedia-ikon-reward';
  static const String search = 'bpedia-ikon-search';
  static const String skincare = 'bpedia-ikon-skincare';
  static const String tips = 'bpedia-ikon-tips';
  static const String tools = 'bpedia-ikon-tools';

  /// Receipt for Transaksi (drawn on the same 24 grid, 1.8 stroke, so the
  /// orders tab no longer shares the cart's bag icon).
  static const String transaksi = 'bpedia-ikon-transaksi';
  static const String voucher = 'bpedia-ikon-voucher';
  static const String wishlist = 'bpedia-ikon-wishlist';

  /// Outline (mono) variant of [name], e.g. `bpedia-ikon-home-mono`.
  static String mono(String name) => '$name-mono';
}

/// Brand SVG icon `assets/icons/<name>.svg`; [color] tints it, otherwise brand colors are kept (remapped to Berry Night in dark mode).
class BrandIcon extends StatelessWidget {
  const BrandIcon(
    this.name, {
    super.key,
    this.size = BpSize.icon,
    this.color,
    this.semanticLabel,
  });

  /// File base name, e.g. [BrandIcons.home] or `BrandIcons.mono(BrandIcons.home)`.
  final String name;

  /// Width and height.
  final double size;

  /// Single tint color (applied with [BlendMode.srcIn]).
  final Color? color;

  /// Screen-reader label; null keeps the icon decorative.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tint = color;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SvgPicture.asset(
      'assets/icons/$name.svg',
      width: size,
      height: size,
      colorFilter: tint == null
          ? null
          : ColorFilter.mode(tint, BlendMode.srcIn),
      colorMapper: tint == null && isDark ? const _BerryNightMapper() : null,
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );
  }
}

/// Maps the three colors of the icon set to their Berry Night tokens.
class _BerryNightMapper extends ColorMapper {
  const _BerryNightMapper();

  static const int _berryStroke = 0xFFB3164B;
  static const int _plumStroke = 0xFF45122B;
  static const int _softFill = 0xFFFCCFDD;

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    switch (color.toARGB32()) {
      case _berryStroke:
        return BpColors.dark.berry700;
      case _plumStroke:
        return BpColors.dark.plum900;
      case _softFill:
        return BpColors.dark.pink200;
      default:
        return color;
    }
  }
}
