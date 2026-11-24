import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/tokens.dart';

/// Final price (berry, w800) with the struck-through original price and discount when [strikePrice] is higher.
class PriceText extends StatelessWidget {
  const PriceText(
    this.price,
    this.strikePrice, {
    super.key,
    this.compact = false,
    this.showDiscount = true,
  });

  /// Final price in rupiah.
  final int price;

  /// Original price in rupiah; ignored unless higher than [price].
  final int? strikePrice;

  /// Smaller type for cards and lists.
  final bool compact;

  /// Whether the "-39%" pill is shown (cards already show a badge).
  final bool showDiscount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final original = strikePrice;
    final discounted = original != null && original > price;
    final percent = discounted ? (original - price) * 100 ~/ original : 0;
    final priceStyle = compact
        ? text.titleSmall!.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: scheme.secondary,
          )
        : text.bpPrice.copyWith(color: scheme.secondary);
    final label = StringBuffer('Harga ${rupiah(price)}');
    if (discounted) {
      label.write(', sebelumnya ${rupiah(original)}, hemat $percent%');
    }

    return Semantics(
      label: label.toString(),
      excludeSemantics: true,
      child: Wrap(
        spacing: BpSpace.s2,
        runSpacing: BpSpace.s1,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Text(rupiah(price), style: priceStyle),
          if (discounted)
            Text(
              rupiah(original),
              style: (compact ? text.labelMedium! : text.bodyMedium!).copyWith(
                color: scheme.onSurfaceVariant,
                decoration: TextDecoration.lineThrough,
                decorationColor: scheme.onSurfaceVariant,
              ),
            ),
          if (discounted && showDiscount) DiscountBadge(percent: percent),
        ],
      ),
    );
  }
}

/// Small "-39%" pill rendered by the UI (never baked into photos).
class DiscountBadge extends StatelessWidget {
  const DiscountBadge({super.key, required this.percent});

  /// Whole discount percentage.
  final int percent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(BpRadius.xs),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          '-$percent%',
          style: Theme.of(context).textTheme.labelMedium!.copyWith(
            color: scheme.onPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
