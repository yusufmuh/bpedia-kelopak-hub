import 'package:flutter/material.dart';

import '../../core/tokens.dart';

/// Section title (semantic header) with an optional text action such as "Lihat semua"; the action wraps below the title at large text sizes.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.actionLabel, this.onAction});

  /// Section title.
  final String title;

  /// Label of the trailing text button.
  final String? actionLabel;

  /// Action of the trailing text button (hidden when null).
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    final heading = Semantics(
      header: true,
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
    if (label == null || onAction == null) {
      return Align(alignment: AlignmentDirectional.centerStart, child: heading);
    }
    return LayoutBuilder(
      builder: (context, constraints) => ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: constraints.maxWidth.isFinite ? constraints.maxWidth : 0,
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: BpSpace.s2,
          children: <Widget>[
            heading,
            TextButton(onPressed: onAction, child: Text(label)),
          ],
        ),
      ),
    );
  }
}
