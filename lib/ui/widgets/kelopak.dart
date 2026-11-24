import 'package:flutter/material.dart';

import '../../core/assets.dart';
import '../../core/format.dart';
import '../../core/tokens.dart';

/// The 3D Kelopak token image (decorative; amounts carry the semantics).
class KelopakToken extends StatelessWidget {
  const KelopakToken({super.key, this.size = BpSize.icon});

  /// Width and height.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppImages.kelopakToken3d,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.local_florist_rounded,
        size: size,
        color: BpColors.of(context).petal400,
      ),
    );
  }
}

/// Visual size of [KelopakAmount].
enum KelopakAmountSize { small, medium, large }

/// Token + "12 Kelopak" + "(Rp1.200)"; large shows the balance style with "Setara Rp1.200" below.
class KelopakAmount extends StatelessWidget {
  const KelopakAmount(
    this.amount, {
    super.key,
    this.size = KelopakAmountSize.medium,
    this.showRupiah = true,
  });

  /// Kelopak amount.
  final int amount;

  /// Visual size.
  final KelopakAmountSize size;

  /// Whether the rupiah value is shown next to (or under) the amount.
  final bool showRupiah;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final semantics = showRupiah
        ? '${kelopakLabel(amount)}, setara ${kelopakRupiah(amount)}'
        : kelopakLabel(amount);

    if (size == KelopakAmountSize.large) {
      return Semantics(
        label: semantics,
        excludeSemantics: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  const WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: EdgeInsets.only(right: BpSpace.s2),
                      child: KelopakToken(size: 40),
                    ),
                  ),
                  TextSpan(
                    text: groupThousands(amount),
                    style: text.displayLarge!.copyWith(
                      color: BpColors.of(context).pink500,
                    ),
                  ),
                  TextSpan(
                    text: ' Kelopak',
                    style: text.titleLarge!.copyWith(color: scheme.onSurface),
                  ),
                ],
              ),
            ),
            if (showRupiah)
              Text(
                'Setara ${kelopakRupiah(amount)}',
                style: text.bodyMedium!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      );
    }

    final small = size == KelopakAmountSize.small;
    final amountStyle = (small ? text.titleSmall! : text.titleMedium!).copyWith(
      color: scheme.onSurface,
      fontWeight: FontWeight.w700,
    );
    final rupiahStyle = (small ? text.labelMedium! : text.bodyMedium!).copyWith(
      color: scheme.onSurfaceVariant,
    );
    return Semantics(
      label: semantics,
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(right: BpSpace.s1),
                child: KelopakToken(size: small ? 18 : BpSize.icon),
              ),
            ),
            TextSpan(text: kelopakLabel(amount), style: amountStyle),
            if (showRupiah)
              TextSpan(text: ' (${kelopakRupiah(amount)})', style: rupiahStyle),
          ],
        ),
      ),
    );
  }
}
