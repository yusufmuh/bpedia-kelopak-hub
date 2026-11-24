import 'package:flutter/material.dart';

import '../../domain/app_state.dart';
import '../widgets/widgets.dart';
import 'shop_navigation.dart';

/// Bag icon with the item count; opens the cart. Read as "Keranjang, N barang".
class CartButton extends StatelessWidget {
  const CartButton({super.key});

  @override
  Widget build(BuildContext context) {
    final count = AppScope.of(context).cartCount;
    return IconButton(
      tooltip: 'Keranjang, $count barang',
      onPressed: () => openCart(context),
      icon: Badge(
        isLabelVisible: count > 0,
        label: ExcludeSemantics(child: Text(count > 99 ? '99+' : '$count')),
        child: BrandIcon(
          BrandIcons.mono(BrandIcons.bag),
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}
