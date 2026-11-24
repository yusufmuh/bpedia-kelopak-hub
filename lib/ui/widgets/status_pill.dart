import 'package:flutter/material.dart';

import '../../core/tokens.dart';

/// Color tone of a [StatusPill].
enum StatusTone { success, info, warning, neutral, brand }

/// Status as icon + text (never color alone), e.g. "Sudah check-in" or "Buka Sabtu".
class StatusPill extends StatelessWidget {
  const StatusPill(
    this.icon,
    this.label, {
    super.key,
    this.tone = StatusTone.neutral,
  });

  /// Leading icon.
  final IconData icon;

  /// Status text.
  final String label;

  /// Color tone.
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = BpColors.of(context);
    final (Color background, Color iconColor, Color textColor) = switch (tone) {
      StatusTone.success => (
        colors.success100,
        colors.success700,
        colors.success700,
      ),
      StatusTone.info => (
        Color.alphaBlend(
          colors.info.withValues(alpha: 0.14),
          scheme.surfaceContainerLowest,
        ),
        colors.info,
        scheme.onSurface,
      ),
      StatusTone.warning => (colors.honey100, colors.honey800, colors.honey800),
      StatusTone.neutral => (
        scheme.surfaceContainerLowest,
        scheme.onSurfaceVariant,
        scheme.onSurfaceVariant,
      ),
      StatusTone.brand => (
        scheme.primaryContainer,
        scheme.primary,
        scheme.onPrimaryContainer,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(BpRadius.pill),
        border: tone == StatusTone.neutral
            ? Border.all(color: scheme.outlineVariant)
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium!.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
