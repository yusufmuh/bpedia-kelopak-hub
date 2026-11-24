import 'package:flutter/material.dart';

import '../../core/tokens.dart';

/// Small "DEMO" chip for app bars of screens that show demo data (Hadiah, Checkout).
class DemoChip extends StatelessWidget {
  const DemoChip({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = BpColors.of(context);
    return Semantics(
      label: 'Mode demo, data hanya di perangkat ini',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.honey100,
          borderRadius: BorderRadius.circular(BpRadius.pill),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BpSpace.s2,
            vertical: 2,
          ),
          child: Text(
            'DEMO',
            style: Theme.of(context).textTheme.labelMedium!.copyWith(
              color: colors.honey800,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }
}
