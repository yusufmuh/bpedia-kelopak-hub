import 'package:flutter/material.dart';

import '../../core/tokens.dart';
import 'brand_icon.dart';

/// Product badge from the brand guideline: radius 6, 8 dp side padding, a
/// brand icon and a small bold label, e.g. "Original" (success on success-100)
/// or "Gratis ongkir (Demo)" (Berry on blush).
class BrandBadge extends StatelessWidget {
  const BrandBadge({
    super.key,
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
  });

  /// Brand icon base name, e.g. [BrandIcons.original].
  final String icon;

  /// Badge text.
  final String label;

  /// Label color.
  final Color foreground;

  /// Fill color.
  final Color background;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(BpRadius.xs),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: BpSpace.s2,
          vertical: BpSpace.s1,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            BrandIcon(icon, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium!.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
