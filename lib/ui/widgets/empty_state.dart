import 'package:flutter/material.dart';

import '../../core/tokens.dart';

/// Friendly empty state: Bipy illustration, title, body and an optional next step.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.imageAsset,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  /// Illustration, e.g. `AppImages.bipyNgintip`.
  final String imageAsset;

  /// Short title.
  final String title;

  /// One or two sentences that say what to do next.
  final String body;

  /// Label of the primary action.
  final String? actionLabel;

  /// Primary action (hidden when null).
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = actionLabel;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: BpSpace.s6,
        vertical: BpSpace.s8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Image.asset(
            imageAsset,
            height: 140,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox(height: 140),
          ),
          const SizedBox(height: BpSpace.s4),
          Semantics(
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: BpSpace.s2),
          Text(
            body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (label != null && onAction != null) ...<Widget>[
            const SizedBox(height: BpSpace.s6),
            FilledButton(onPressed: onAction, child: Text(label)),
          ],
        ],
      ),
    );
  }
}
