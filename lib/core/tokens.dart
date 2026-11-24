/// Bpedia brand tokens (official design system 2026: `bpedia-tokens.css`).
///
/// Use `Theme.of(context).colorScheme` for the standard roles and
/// [BpColors.of] for brand-only colors (success, honey, night, ...).
library;

import 'package:flutter/material.dart';

/// Official Bpedia color tokens for one theme: light "Pearl" or dark "Berry Night".
@immutable
final class BpColors {
  const BpColors._({
    required this.pink500,
    required this.pink600,
    required this.onPink,
    required this.berry700,
    required this.plum900,
    required this.ink700,
    required this.ink500,
    required this.petal400,
    required this.tulip300,
    required this.pink200,
    required this.blush100,
    required this.pearl50,
    required this.card,
    required this.night950,
    required this.onNight,
    required this.onNightAccent,
    required this.honey400,
    required this.line,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.success100,
    required this.success700,
    required this.honey100,
    required this.honey800,
    required this.bipyHood,
    required this.bipyHair,
    required this.bipySkin,
    required this.bipyHeart,
  });

  /// Light theme "Pearl".
  static const BpColors light = BpColors._(
    pink500: Color(0xFFE62B5E),
    pink600: Color(0xFFD81F57),
    onPink: Color(0xFFFFFFFF),
    berry700: Color(0xFFB3164B),
    plum900: Color(0xFF45122B),
    ink700: Color(0xFF6E4556),
    ink500: Color(0xFF9C7E8A),
    petal400: Color(0xFFF7729A),
    tulip300: Color(0xFFF9A2C1),
    pink200: Color(0xFFFBCFDB),
    blush100: Color(0xFFFDE7EC),
    pearl50: Color(0xFFFFF7F8),
    card: Color(0xFFFFFFFF),
    night950: Color(0xFF2A0A18),
    onNight: Color(0xFFFFFFFF),
    onNightAccent: Color(0xFFF9A2C1),
    honey400: Color(0xFFF5B83D),
    line: Color(0xFFF3D3DD),
    success: Color(0xFF1E9E6A),
    warning: Color(0xFFE08A1E),
    error: Color(0xFFC62828),
    info: Color(0xFF3E7BD9),
    success100: Color(0xFFE9F7F0),
    success700: Color(0xFF1E7A55),
    honey100: Color(0xFFFFF4DB),
    honey800: Color(0xFF8A5A00),
    bipyHood: Color(0xFFFA89AA),
    bipyHair: Color(0xFFF9BF90),
    bipySkin: Color(0xFFFBDACA),
    bipyHeart: Color(0xFFEE2564),
  );

  /// Dark theme "Berry Night" (`[data-theme="dark"]`).
  static const BpColors dark = BpColors._(
    pink500: Color(0xFFFF5C8A),
    pink600: Color(0xFFFF7AA0),
    onPink: Color(0xFF2A0A18),
    berry700: Color(0xFFF9A2C1),
    plum900: Color(0xFFFDEAF0),
    ink700: Color(0xFFE7C9D4),
    ink500: Color(0xFFB89AA7),
    petal400: Color(0xFFF7729A),
    tulip300: Color(0xFFC24C77),
    pink200: Color(0xFF5A1A36),
    blush100: Color(0xFF3B1026),
    pearl50: Color(0xFF2A0A18),
    card: Color(0xFF3B1026),
    night950: Color(0xFF1A0610),
    onNight: Color(0xFFFFFFFF),
    onNightAccent: Color(0xFFF9A2C1),
    honey400: Color(0xFFF5B83D),
    line: Color(0xFF5A1A36),
    success: Color(0xFF4CC99A),
    warning: Color(0xFFF2B25C),
    error: Color(0xFFFF8A80),
    info: Color(0xFF8DB6F2),
    success100: Color(0xFF0F3B2A),
    success700: Color(0xFF7FE0B5),
    honey100: Color(0xFF3D2A05),
    honey800: Color(0xFFF5C96B),
    bipyHood: Color(0xFFFA89AA),
    bipyHair: Color(0xFFF9BF90),
    bipySkin: Color(0xFFFBDACA),
    bipyHeart: Color(0xFFEE2564),
  );

  /// Tokens matching the brightness of the ambient [Theme].
  static BpColors of(BuildContext context) =>
      forBrightness(Theme.of(context).brightness);

  /// Tokens for [brightness].
  static BpColors forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// Bpedia Pink: logo, big numbers, titles of 24 px and more.
  final Color pink500;

  /// Primary buttons and links (ColorScheme.primary).
  final Color pink600;

  /// Text and icons on [pink600].
  final Color onPink;

  /// Accent text, prices, icons (ColorScheme.secondary).
  final Color berry700;

  /// Main text and titles (ColorScheme.onSurface).
  final Color plum900;

  /// Secondary body text (ColorScheme.onSurfaceVariant).
  final Color ink700;

  /// Strike prices and meta at 18 px and more (ColorScheme.outline).
  final Color ink500;

  /// Decorative petals and charts; never behind white text.
  final Color petal400;

  /// Soft panels, illustrations, text on plum/night.
  final Color tulip300;

  /// Secondary card background (ColorScheme.secondaryContainer; in Berry
  /// Night also ColorScheme.primaryContainer, because [blush100] equals [card]).
  final Color pink200;

  /// Panels and active chips (ColorScheme.primaryContainer in the light theme).
  final Color blush100;

  /// Page background (ColorScheme.surface).
  final Color pearl50;

  /// Brand token "white": cards and inputs (ColorScheme.surfaceContainerLowest).
  final Color card;

  /// Berry Night background for closing panels.
  final Color night950;

  /// Text on [night950].
  final Color onNight;

  /// Accents and strike prices on [night950].
  final Color onNightAccent;

  /// Rating stars, sparkle, best-seller badges (text on it: [night950]).
  final Color honey400;

  /// Dividers and 1.5 px card borders (ColorScheme.outlineVariant).
  final Color line;

  /// Success status (always with a label).
  final Color success;

  /// Stock and deadline warnings.
  final Color warning;

  /// Errors and cancellations.
  final Color error;

  /// Neutral info and shipping status.
  final Color info;

  /// Background of the Original/verified badge (pair with [success700]).
  final Color success100;

  /// Text on [success100].
  final Color success700;

  /// Background of the "Baru" badge (pair with [honey800]).
  final Color honey100;

  /// Text on [honey100].
  final Color honey800;

  /// Bipy hood (illustration only).
  final Color bipyHood;

  /// Bipy hair (illustration only).
  final Color bipyHair;

  /// Bipy skin (illustration only).
  final Color bipySkin;

  /// Bipy heart accent (illustration only).
  final Color bipyHeart;
}

/// Spacing scale on a 4 pt grid (brand `space-N` = N x 4).
abstract final class BpSpace {
  /// 4: tight icon-to-text gap.
  static const double s1 = 4;

  /// 8: inside chips and badges.
  static const double s2 = 8;

  /// 12: gap between small cards.
  static const double s3 = 12;

  /// 16: card padding, phone screen margin.
  static const double s4 = 16;

  /// 24: horizontal button padding, large gutters.
  static const double s6 = 24;

  /// 32: gap between sections.
  static const double s8 = 32;

  /// 48: large blocks.
  static const double s12 = 48;

  /// 72: hero margins.
  static const double s18 = 72;
}

/// Corner radii.
abstract final class BpRadius {
  /// 6: discount badges, small chips.
  static const double xs = 6;

  /// 10: inputs, thumbnails.
  static const double sm = 10;

  /// 16: product cards, inputs, list tiles (buttons are pills).
  static const double md = 16;

  /// 24: bottom sheets, dialogs, content cards.
  static const double lg = 24;

  /// 40: large panels.
  static const double xl = 40;

  /// Fully rounded pills.
  static const double pill = 999;
}

/// Sizes from the brand guideline.
abstract final class BpSize {
  /// Minimum touch target (48 dp).
  static const double touchTarget = 48;

  /// Standard icon size.
  static const double icon = 24;

  /// Maximum content width for transaction flows on wide screens.
  static const double contentMaxWidth = 560;
}

/// Brand shadows.
abstract final class BpShadows {
  /// `0 10 30 rgba(179,22,75,.08)` for cards on pearl.
  static final List<BoxShadow> card = <BoxShadow>[
    BoxShadow(
      color: BpColors.light.berry700.withValues(alpha: 0.08),
      offset: const Offset(0, 10),
      blurRadius: 30,
    ),
  ];

  /// `0 16 34 rgba(179,22,75,.28)` for floating CTAs and stickers.
  static final List<BoxShadow> pop = <BoxShadow>[
    BoxShadow(
      color: BpColors.light.berry700.withValues(alpha: 0.28),
      offset: const Offset(0, 16),
      blurRadius: 34,
    ),
  ];

  /// Card shadow for Berry Night (berry shadows vanish on dark surfaces).
  static final List<BoxShadow> cardDark = <BoxShadow>[
    BoxShadow(
      color: BpColors.dark.night950.withValues(alpha: 0.55),
      offset: const Offset(0, 10),
      blurRadius: 30,
    ),
  ];

  /// [card] or [cardDark] for the ambient theme.
  static List<BoxShadow> cardOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? cardDark : card;
}

/// Motion durations and curves.
abstract final class BpMotion {
  /// 150 ms: taps, small state changes.
  static const Duration fast = Duration(milliseconds: 150);

  /// 250 ms: cards, sheets, toggles.
  static const Duration medium = Duration(milliseconds: 250);

  /// 400 ms: larger transitions.
  static const Duration slow = Duration(milliseconds: 400);

  /// Default easing.
  static const Curve standard = Curves.easeOutCubic;

  /// Playful overshoot for rewards appearing.
  static const Curve emphasized = Curves.easeOutBack;

  /// Whether the user asked to reduce motion.
  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  /// [duration], or zero when motion is reduced.
  static Duration resolve(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}

/// Font families bundled in `assets/fonts`.
abstract final class BpFonts {
  /// Poppins 400-800: all UI text.
  static const String sans = 'Poppins';

  /// Fraunces italic: taglines only.
  static const String serif = 'Fraunces';
}
