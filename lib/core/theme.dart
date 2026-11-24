/// Material 3 themes built from the Bpedia tokens (SPEC-CONTRACT section 3).
///
/// Text roles (Poppins, letter spacing 0):
///
/// | Role | Size / line / weight | Brand style |
/// |---|---|---|
/// | displayLarge | 40/48 w800 | big numbers (balance) |
/// | displayMedium | 34/40 w700 | |
/// | displaySmall | 28/34 w700 | app-display |
/// | headlineLarge | 24/30 w700 | |
/// | headlineMedium | 22/28 w600 | app-title |
/// | headlineSmall | 20/26 w600 | |
/// | titleLarge | 22/28 w600 | app-title |
/// | titleMedium | 18/24 w600 | app-headline |
/// | titleSmall | 14/20 w600 | |
/// | bodyLarge | 16/24 w400 | app-body |
/// | bodyMedium | 14/20 w400 | app-body-s |
/// | bodySmall | 12/16 w400 | |
/// | labelLarge | 16/20 w600 | app-button |
/// | labelMedium | 12/16 w500 | app-caption |
/// | labelSmall | 12/16 w500 | (minimum 12 px) |
///
/// Brand names are available through [BpTextStyles] (`textTheme.bpPrice`, ...).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

/// Light theme "Pearl".
ThemeData buildLightTheme() => _buildTheme(BpColors.light, Brightness.light);

/// Dark theme "Berry Night".
ThemeData buildDarkTheme() => _buildTheme(BpColors.dark, Brightness.dark);

/// Brand text styles on top of the Material roles.
extension BpTextStyles on TextTheme {
  /// app-display 28/34 w700: page titles, banners.
  TextStyle get bpDisplay => displaySmall!;

  /// app-title 22/28 w600: section titles.
  TextStyle get bpTitle => titleLarge!;

  /// app-headline 18/24 w600: product names, card titles.
  TextStyle get bpHeadline => titleMedium!;

  /// app-body 16/24 w400.
  TextStyle get bpBody => bodyLarge!;

  /// app-body-s 14/20 w400.
  TextStyle get bpBodyS => bodyMedium!;

  /// app-caption 12/16 w500: meta, small labels.
  TextStyle get bpCaption => labelMedium!;

  /// app-button 16/20 w600.
  TextStyle get bpButton => labelLarge!;

  /// app-price 18/24 w800 (color it with `colorScheme.secondary`).
  TextStyle get bpPrice => titleMedium!.copyWith(fontWeight: FontWeight.w800);

  /// 40/48 w800 for hero numbers such as the Kelopak balance.
  TextStyle get bpHero => displayLarge!;

  /// tagline-s: Fraunces italic 24/30 w600.
  TextStyle get bpTagline => titleLarge!.copyWith(
    fontFamily: BpFonts.serif,
    fontStyle: FontStyle.italic,
    fontSize: 24,
    height: 30 / 24,
    fontWeight: FontWeight.w600,
  );
}

ThemeData _buildTheme(BpColors c, Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme = _colorScheme(c, brightness);
  final text = _textTheme(scheme);
  final cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(BpRadius.md),
    side: BorderSide(color: scheme.outlineVariant),
  );
  // Brand UI kit: pill buttons, 52 high, 24 horizontal padding, 16 w600 label.
  const buttonShape = StadiumBorder();
  const buttonMinimumSize = Size(64, 52);
  const buttonPadding = EdgeInsets.symmetric(horizontal: BpSpace.s6);
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(BpRadius.md),
    borderSide: BorderSide(color: scheme.outlineVariant),
  );
  final navBackground = isDark ? scheme.surface : scheme.surfaceContainerLowest;
  final overlayStyle =
      (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: navBackground,
            systemNavigationBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
            systemNavigationBarDividerColor: Colors.transparent,
          );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: BpFonts.sans,
    textTheme: text,
    scaffoldBackgroundColor: scheme.surface,
    canvasColor: scheme.surface,
    // Keyboard focus on ink surfaces: a Berry tint instead of the faint grey
    // default (cards add a 2 dp Berry outline on top).
    focusColor: scheme.secondary.withValues(alpha: 0.16),
    iconTheme: IconThemeData(color: scheme.onSurface, size: BpSize.icon),
    dividerColor: scheme.outlineVariant,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: scheme.primary,
      selectionColor: scheme.primary.withValues(alpha: 0.28),
      selectionHandleColor: scheme.primary,
    ),
    appBarTheme: AppBarThemeData(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleSpacing: BpSpace.s4,
      titleTextStyle: text.titleMedium!.copyWith(color: scheme.onSurface),
      iconTheme: IconThemeData(color: scheme.onSurface, size: BpSize.icon),
      actionsIconTheme: IconThemeData(
        color: scheme.onSurface,
        size: BpSize.icon,
      ),
      systemOverlayStyle: overlayStyle,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: buttonMinimumSize,
        padding: buttonPadding,
        shape: buttonShape,
        textStyle: text.labelLarge,
      ),
    ),
    // Secondary: white fill, Berry outline and label (e.g. "+ Keranjang").
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll<Size>(buttonMinimumSize),
        padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
          buttonPadding,
        ),
        shape: const WidgetStatePropertyAll<OutlinedBorder>(buttonShape),
        textStyle: WidgetStatePropertyAll<TextStyle?>(text.labelLarge),
        backgroundColor: WidgetStateProperty.resolveWith<Color?>(
          (states) => states.contains(WidgetState.disabled)
              ? Colors.transparent
              : scheme.surfaceContainerLowest,
        ),
        foregroundColor: WidgetStateProperty.resolveWith<Color?>(
          (states) => states.contains(WidgetState.disabled)
              ? scheme.onSurface.withValues(alpha: 0.38)
              : scheme.secondary,
        ),
        overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.pressed) ||
              states.contains(WidgetState.focused)) {
            return scheme.secondary.withValues(alpha: 0.1);
          }
          if (states.contains(WidgetState.hovered)) {
            return scheme.secondary.withValues(alpha: 0.08);
          }
          return null;
        }),
        side: WidgetStateProperty.resolveWith<BorderSide?>(
          (states) => BorderSide(
            color: states.contains(WidgetState.disabled)
                ? scheme.onSurface.withValues(alpha: 0.12)
                : scheme.secondary,
            width: 1.5,
          ),
        ),
      ),
    ),
    // Tertiary: Berry text (e.g. "Lihat detail").
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: buttonMinimumSize,
        padding: buttonPadding,
        shape: buttonShape,
        foregroundColor: scheme.secondary,
        textStyle: text.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(BpSize.touchTarget, BpSize.touchTarget),
        foregroundColor: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: cardShape,
    ),
    // Brand chips: inactive = white, line border, Plum label; selected =
    // blush fill with a Berry border and Berry label, so the state never
    // rests on the fill alone (the fills differ only about 1.2:1).
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      selectedColor: scheme.primaryContainer,
      disabledColor: scheme.surfaceContainer,
      checkmarkColor: scheme.secondary,
      labelStyle: text.bodyMedium!.copyWith(
        fontWeight: FontWeight.w500,
        color: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.secondary
              : scheme.onSurface,
        ),
      ),
      side: WidgetStateBorderSide.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? BorderSide(color: scheme.secondary, width: 1.5)
            : BorderSide(color: scheme.outlineVariant),
      ),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(
        horizontal: BpSpace.s2,
        vertical: BpSpace.s2,
      ),
      iconTheme: IconThemeData(color: scheme.secondary, size: 18),
      showCheckmark: false,
      elevation: 0,
      pressElevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: navBackground,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      indicatorColor: scheme.primaryContainer,
      indicatorShape: const StadiumBorder(),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
        (states) => states.contains(WidgetState.selected)
            ? text.labelMedium!.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              )
            : text.labelMedium!.copyWith(color: scheme.onSurfaceVariant),
      ),
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>(
        (states) => IconThemeData(
          size: BpSize.icon,
          color: states.contains(WidgetState.selected)
              ? scheme.secondary
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      modalBackgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: c.night950.withValues(alpha: 0.45),
      showDragHandle: true,
      dragHandleColor: scheme.outline,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(BpRadius.lg)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: text.bodyMedium!.copyWith(
        color: scheme.onInverseSurface,
      ),
      actionTextColor: scheme.inversePrimary,
      closeIconColor: scheme.onInverseSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.disabled)) {
          return scheme.onSurface.withValues(alpha: 0.38);
        }
        return states.contains(WidgetState.selected)
            ? scheme.onPrimary
            : scheme.outline;
      }),
      trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.disabled)) {
          return scheme.onSurface.withValues(alpha: 0.12);
        }
        return states.contains(WidgetState.selected)
            ? scheme.primary
            : scheme.surfaceContainerHighest;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith<Color?>(
        (states) => states.contains(WidgetState.selected)
            ? Colors.transparent
            : scheme.outline,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BpRadius.lg),
      ),
      titleTextStyle: text.titleLarge!.copyWith(color: scheme.onSurface),
      contentTextStyle: text.bodyLarge!.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      barrierColor: c.night950.withValues(alpha: 0.45),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: BpSpace.s4,
        vertical: 14,
      ),
      hintStyle: text.bodyLarge!.copyWith(color: scheme.onSurfaceVariant),
      labelStyle: text.bodyLarge!.copyWith(color: scheme.onSurfaceVariant),
      prefixIconColor: scheme.onSurfaceVariant,
      suffixIconColor: scheme.onSurfaceVariant,
      border: inputBorder,
      enabledBorder: inputBorder,
      disabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: scheme.error, width: 2),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.secondary,
      textColor: scheme.onSurface,
      titleTextStyle: text.bodyLarge!.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w500,
      ),
      subtitleTextStyle: text.bodyMedium!.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      leadingAndTrailingTextStyle: text.bodyMedium!.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: BpSpace.s4),
      minVerticalPadding: BpSpace.s3,
      minTileHeight: 56,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BpRadius.md),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        minimumSize: const Size(BpSize.touchTarget, BpSize.touchTarget),
        backgroundColor: scheme.surfaceContainerLowest,
        foregroundColor: scheme.onSurface,
        selectedBackgroundColor: scheme.primaryContainer,
        selectedForegroundColor: scheme.onPrimaryContainer,
        side: BorderSide(color: scheme.outlineVariant),
        textStyle: text.bodyMedium!.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      indicatorColor: scheme.primary,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: scheme.outlineVariant,
      labelColor: scheme.onSurface,
      unselectedLabelColor: scheme.onSurfaceVariant,
      labelStyle: text.titleSmall,
      unselectedLabelStyle: text.bodyMedium!.copyWith(
        fontWeight: FontWeight.w500,
      ),
    ),
    badgeTheme: BadgeThemeData(
      backgroundColor: scheme.primary,
      textColor: scheme.onPrimary,
      smallSize: 8,
      largeSize: 18,
      textStyle: text.labelSmall!.copyWith(fontWeight: FontWeight.w700),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.secondaryContainer,
      circularTrackColor: scheme.secondaryContainer,
      linearMinHeight: 8,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BpRadius.md),
      ),
      textStyle: text.bodyLarge,
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color?>(
        (states) => states.contains(WidgetState.selected)
            ? scheme.primary
            : scheme.outline,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color?>(
        (states) => states.contains(WidgetState.selected)
            ? scheme.primary
            : Colors.transparent,
      ),
      checkColor: WidgetStatePropertyAll<Color>(scheme.onPrimary),
      side: BorderSide(color: scheme.outline, width: 1.5),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(BpRadius.sm),
      ),
      textStyle: text.labelMedium!.copyWith(color: scheme.onInverseSurface),
    ),
  );
}

ColorScheme _colorScheme(BpColors c, Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  // Berry Night uses the same value for blush panels and cards, so fills that
  // sit on cards (chips, pills, tiles, segments) take the deeper pink there.
  final primaryContainer = isDark ? c.pink200 : c.blush100;
  final containerOnCard = isDark
      ? Color.alphaBlend(c.pink200.withValues(alpha: 0.5), c.card)
      : c.blush100;
  return ColorScheme(
    brightness: brightness,
    primary: c.pink600,
    onPrimary: c.onPink,
    primaryContainer: primaryContainer,
    onPrimaryContainer: c.plum900,
    secondary: c.berry700,
    onSecondary: c.onPink,
    // Berry Night: a step lighter than primaryContainer (also pink-200 there),
    // so alternating fills such as the wheel segments stay distinguishable.
    secondaryContainer: isDark
        ? Color.alphaBlend(c.tulip300.withValues(alpha: 0.35), c.card)
        : c.pink200,
    onSecondaryContainer: c.plum900,
    tertiary: c.honey400,
    onTertiary: c.night950,
    tertiaryContainer: c.honey100,
    onTertiaryContainer: c.honey800,
    error: c.error,
    onError: c.onPink,
    errorContainer: Color.alphaBlend(
      c.error.withValues(alpha: isDark ? 0.18 : 0.10),
      c.card,
    ),
    onErrorContainer: c.error,
    surface: c.pearl50,
    onSurface: c.plum900,
    onSurfaceVariant: c.ink700,
    surfaceContainerLowest: c.card,
    surfaceContainerLow: c.pearl50,
    surfaceContainer: containerOnCard,
    surfaceContainerHigh: containerOnCard,
    surfaceContainerHighest: c.pink200,
    outline: c.ink500,
    outlineVariant: c.line,
    shadow: c.night950,
    scrim: c.night950,
    inverseSurface: c.plum900,
    onInverseSurface: c.pearl50,
    inversePrimary: isDark ? BpColors.light.berry700 : c.tulip300,
    surfaceTint: Colors.transparent,
  );
}

TextTheme _textTheme(ColorScheme scheme) {
  TextStyle style(double size, double lineHeight, FontWeight weight) {
    return TextStyle(
      fontFamily: BpFonts.sans,
      fontSize: size,
      height: lineHeight / size,
      fontWeight: weight,
      letterSpacing: 0,
      leadingDistribution: TextLeadingDistribution.even,
    );
  }

  return TextTheme(
    displayLarge: style(40, 48, FontWeight.w800),
    displayMedium: style(34, 40, FontWeight.w700),
    displaySmall: style(28, 34, FontWeight.w700),
    headlineLarge: style(24, 30, FontWeight.w700),
    headlineMedium: style(22, 28, FontWeight.w600),
    headlineSmall: style(20, 26, FontWeight.w600),
    titleLarge: style(22, 28, FontWeight.w600),
    titleMedium: style(18, 24, FontWeight.w600),
    titleSmall: style(14, 20, FontWeight.w600),
    bodyLarge: style(16, 24, FontWeight.w400),
    bodyMedium: style(14, 20, FontWeight.w400),
    bodySmall: style(12, 16, FontWeight.w400),
    labelLarge: style(16, 20, FontWeight.w600),
    labelMedium: style(12, 16, FontWeight.w500),
    labelSmall: style(12, 16, FontWeight.w500),
  ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
}
