/// Layout pieces shared by the shopping and order screens.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/tokens.dart';

/// Widest the browsing pages (Beranda, search) grow before they center.
const double browseMaxWidth = 1040;

/// Side padding that keeps browsing content at most [browseMaxWidth] wide and
/// centered, never below the 16 dp phone margin.
double browsePadding(double width) =>
    math.max(BpSpace.s4, (width - browseMaxWidth) / 2);

/// Whether text is enlarged to 150% or more. Bottom bars then keep only their
/// button and move amounts into the scrolling content, so the page stays
/// readable instead of being covered by a tall bar.
bool isLargeText(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(16) >= 24;

/// Centers [child] at most [maxWidth] wide and lets it fill that width,
/// without taking extra height (safe in lists and bottom bars).
class CenteredWidth extends StatelessWidget {
  const CenteredWidth({
    super.key,
    required this.child,
    this.maxWidth = BpSize.contentMaxWidth,
  });

  /// Content.
  final Widget child;

  /// Maximum width.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}

/// White bar for the page's main action: top hairline, safe-area aware,
/// content capped at 560 dp. Use it as `Scaffold.bottomNavigationBar`.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.child});

  /// Bar content, usually the primary button.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            BpSpace.s4,
            BpSpace.s3,
            BpSpace.s4,
            BpSpace.s3,
          ),
          child: CenteredWidth(child: child),
        ),
      ),
    );
  }
}

/// Look of an [AmountRow].
enum AmountTone {
  /// Regular line: muted label, plum value.
  normal,

  /// A discount: value in success green (it always carries a minus sign).
  saving,

  /// The amount to pay: price style in berry.
  total,
}

/// "Label ........ Rp10.000". The value moves under the label when both do
/// not fit on one line (large text), so nothing is ever clipped.
class AmountRow extends StatelessWidget {
  const AmountRow({
    super.key,
    required this.label,
    required this.value,
    this.tone = AmountTone.normal,
    this.semanticValue,
  });

  /// Left text.
  final String label;

  /// Right text, usually from `rupiah()`.
  final String value;

  /// Visual weight.
  final AmountTone tone;

  /// Spoken value when it differs from [value] ("potongan Rp10.000").
  final String? semanticValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final (TextStyle labelStyle, TextStyle valueStyle) = switch (tone) {
      AmountTone.normal => (
        text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
        text.bodyMedium!.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      AmountTone.saving => (
        text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
        text.bodyMedium!.copyWith(
          color: BpColors.of(context).success700,
          fontWeight: FontWeight.w600,
        ),
      ),
      AmountTone.total => (
        text.titleSmall!.copyWith(color: scheme.onSurface),
        text.bpPrice.copyWith(color: scheme.secondary),
      ),
    };
    return Semantics(
      label: '$label, ${semanticValue ?? value}',
      excludeSemantics: true,
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: BpSpace.s3,
          runSpacing: BpSpace.s1,
          children: <Widget>[
            Text(label, style: labelStyle),
            Text(value, style: valueStyle),
          ],
        ),
      ),
    );
  }
}

/// Rounded square packshot with a soft blush backdrop and an icon fallback.
class ProductThumbnail extends StatelessWidget {
  const ProductThumbnail(this.imageAsset, {super.key, this.size = 72});

  /// Packshot asset path.
  final String imageAsset;

  /// Width and height.
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cacheWidth = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(BpRadius.sm),
      child: ColoredBox(
        color: scheme.surfaceContainer,
        child: SizedBox.square(
          dimension: size,
          child: Image.asset(
            imageAsset,
            fit: BoxFit.cover,
            cacheWidth: cacheWidth,
            excludeFromSemantics: true,
            errorBuilder: (context, error, stackTrace) =>
                Icon(Icons.image_outlined, color: scheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

/// Icon (or image) inside a round blush well, so mixed icon styles line up.
class IconWell extends StatelessWidget {
  const IconWell({super.key, required this.child, this.size = 48});

  /// Icon, token or small illustration.
  final Widget child;

  /// Diameter of the well.
  final double size;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: SizedBox.square(
        dimension: size,
        child: Center(child: child),
      ),
    );
  }
}

/// [text] with a small [icon] inline before it, centered on the first line,
/// so the pair stays aligned at every text size.
class IconText extends StatelessWidget {
  const IconText(
    this.icon,
    this.text, {
    super.key,
    required this.style,
    this.iconColor,
    this.iconSize = 16,
  });

  /// Leading icon (decorative; the text carries the meaning).
  final IconData icon;

  /// The text.
  final String text;

  /// Text style.
  final TextStyle style;

  /// Icon color; defaults to the text color.
  final Color? iconColor;

  /// Icon size.
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: BpSpace.s1 + 2),
              child: Icon(
                icon,
                size: iconSize,
                color: iconColor ?? style.color,
              ),
            ),
          ),
          TextSpan(text: text),
        ],
      ),
      style: style,
    );
  }
}

/// Global center of the render box behind [context], or null before layout.
Offset? globalCenterOf(BuildContext context) {
  final box = context.findRenderObject();
  if (box is RenderBox && box.attached && box.hasSize) {
    return box.localToGlobal(box.size.center(Offset.zero));
  }
  return null;
}

/// Replaces the current snack bar with [message] (auto-dismissing, even with
/// an action).
void showShopSnackBar(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final action = onAction;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        persist: false,
        action: actionLabel == null || action == null
            ? null
            : SnackBarAction(label: actionLabel, onPressed: action),
      ),
    );
}
