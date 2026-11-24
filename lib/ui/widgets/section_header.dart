import 'package:flutter/material.dart';

import '../../core/tokens.dart';

/// Section title (semantic header) with an optional text action such as
/// "Semua hadiah". The action sits at the end of the title's row; only at
/// large text sizes does it move under the title, aligned with it.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.actionLabel, this.onAction});

  /// Section title.
  final String title;

  /// Label of the trailing text button.
  final String? actionLabel;

  /// Action of the trailing text button (hidden when null).
  final VoidCallback? onAction;

  /// Same threshold as the shop layouts: text enlarged to 150% or more.
  static bool _largeText(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(16) >= 24;

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    final action = onAction;
    final heading = Semantics(
      container: true,
      header: true,
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
    if (label == null || action == null) {
      return Align(alignment: AlignmentDirectional.centerStart, child: heading);
    }
    if (!_largeText(context)) {
      return Row(
        children: <Widget>[
          Expanded(child: heading),
          const SizedBox(width: BpSpace.s2),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: BpSpace.s2),
            ),
            onPressed: action,
            child: Text(label),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        heading,
        TextButton(
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            alignment: AlignmentDirectional.centerStart,
          ),
          onPressed: action,
          child: Text(label),
        ),
      ],
    );
  }
}
