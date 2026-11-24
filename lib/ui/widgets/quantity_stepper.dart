import 'package:flutter/material.dart';

import '../../core/tokens.dart';

/// "-  2  +" stepper with 48 dp buttons; the value is announced when it changes.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    this.min = 1,
    this.max = 99,
    required this.onChanged,
  });

  /// Current quantity.
  final int value;

  /// Lowest allowed value.
  final int min;

  /// Highest allowed value.
  final int max;

  /// Called with the new value; null disables the stepper.
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final change = onChanged;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(BpRadius.pill),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            tooltip: 'Kurangi jumlah',
            onPressed: change != null && value > min
                ? () => change(value - 1)
                : null,
            icon: const Icon(Icons.remove_rounded),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 32),
            child: Semantics(
              container: true,
              label: 'Jumlah',
              value: '$value',
              liveRegion: true,
              excludeSemantics: true,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Tambah jumlah',
            onPressed: change != null && value < max
                ? () => change(value + 1)
                : null,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}
