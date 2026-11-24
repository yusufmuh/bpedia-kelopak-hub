import 'package:flutter/material.dart';

import '../../core/tokens.dart';

/// Centers [child] and caps its width (560 dp by default) for transaction flows on wide screens.
class ContentWidth extends StatelessWidget {
  const ContentWidth({
    super.key,
    required this.child,
    this.maxWidth = BpSize.contentMaxWidth,
  });

  /// Content.
  final Widget child;

  /// Maximum width.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
