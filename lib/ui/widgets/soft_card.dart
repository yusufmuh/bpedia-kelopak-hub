import 'package:flutter/material.dart';

import '../../core/tokens.dart';

/// White card (radius 16) with the brand card shadow; tappable with a ripple when [onTap] is set.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(BpSpace.s4),
    this.onTap,
    this.color,
  });

  /// Card content.
  final Widget child;

  /// Inner padding.
  final EdgeInsetsGeometry padding;

  /// Makes the whole card tappable.
  final VoidCallback? onTap;

  /// Background; defaults to `colorScheme.surfaceContainerLowest` (white).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(BpRadius.md);
    final content = Padding(padding: padding, child: child);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: BpShadows.cardOf(context),
      ),
      child: Material(
        color: color ?? scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: isDark
              ? BorderSide(color: scheme.outlineVariant)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}
