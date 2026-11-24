import 'package:flutter/material.dart';

import '../../core/tokens.dart';

/// White card (radius 16) with the brand card shadow; tappable with a ripple
/// when [onTap] is set. A tappable card that has keyboard focus shows a 2 dp
/// Berry outline (the ink highlight alone is too faint to see).
class SoftCard extends StatefulWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(BpSpace.s4),
    this.onTap,
    this.color,
  });

  /// Card content.
  final Widget child;

  /// Inner padding.
  final EdgeInsetsGeometry padding;

  /// Makes the whole card tappable.
  final VoidCallback? onTap;

  /// Background; defaults to `colorScheme.surfaceContainerLowest` (white).
  final Color? color;

  @override
  State<SoftCard> createState() => _SoftCardState();
}

class _SoftCardState extends State<SoftCard> {
  bool _focused = false;

  @override
  void didUpdateWidget(SoftCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onTap == null && _focused) _focused = false;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(BpRadius.md);
    final content = Padding(padding: widget.padding, child: widget.child);
    final onTap = widget.onTap;
    final BorderSide side;
    if (_focused) {
      side = BorderSide(color: scheme.secondary, width: 2);
    } else if (isDark) {
      side = BorderSide(color: scheme.outlineVariant);
    } else {
      side = BorderSide.none;
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: BpShadows.cardOf(context),
      ),
      child: Material(
        color: widget.color ?? scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: radius, side: side),
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? content
            : InkWell(
                onTap: onTap,
                onFocusChange: (focused) {
                  if (focused != _focused) setState(() => _focused = focused);
                },
                child: content,
              ),
      ),
    );
  }
}
