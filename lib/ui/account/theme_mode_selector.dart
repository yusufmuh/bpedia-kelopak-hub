import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/tokens.dart';

/// "Ikuti sistem / Terang / Gelap" picker built on [SegmentedButton].
///
/// The segments sit in one full-width row when every label fits on a single
/// line; on narrow phones and with large text they stack vertically so no
/// label is ever cut or broken mid-word.
class ThemeModeSelector extends StatelessWidget {
  const ThemeModeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  /// Selected mode.
  final ThemeMode value;

  /// Called with the newly selected mode.
  final ValueChanged<ThemeMode> onChanged;

  static const List<_ThemeOption> _options = <_ThemeOption>[
    _ThemeOption(
      ThemeMode.system,
      'Ikuti sistem',
      Icons.brightness_auto_outlined,
    ),
    _ThemeOption(ThemeMode.light, 'Terang', Icons.light_mode_outlined),
    _ThemeOption(ThemeMode.dark, 'Gelap', Icons.dark_mode_outlined),
  ];

  /// Width a segment needs around its label: icon (18), gap and padding
  /// (about 54 dp in Material 3), plus a safety margin.
  static const double _segmentChrome = 72;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final inRow =
            constraints.maxWidth >=
            _options.length * (_widestLabel(context) + _segmentChrome);
        final button = SegmentedButton<ThemeMode>(
          segments: <ButtonSegment<ThemeMode>>[
            for (final option in _options)
              ButtonSegment<ThemeMode>(
                value: option.mode,
                label: Text(option.label),
                icon: Icon(option.icon),
              ),
          ],
          selected: <ThemeMode>{value},
          onSelectionChanged: (selection) {
            if (selection.isNotEmpty) onChanged(selection.first);
          },
          direction: inRow ? Axis.horizontal : Axis.vertical,
          expandedInsets: inRow ? EdgeInsets.zero : null,
          style: SegmentedButton.styleFrom(
            alignment: inRow ? null : AlignmentDirectional.centerStart,
            shape: inRow
                ? null
                : RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(BpRadius.md),
                  ),
          ),
        );
        if (inRow) return button;
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: button,
        );
      },
    );
  }

  double _widestLabel(BuildContext context) {
    final theme = Theme.of(context);
    final style =
        theme.segmentedButtonTheme.style?.textStyle?.resolve(
          const <WidgetState>{},
        ) ??
        theme.textTheme.labelLarge;
    final textScaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    var widest = 0.0;
    for (final option in _options) {
      final painter = TextPainter(
        text: TextSpan(text: option.label, style: style),
        textDirection: direction,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      widest = math.max(widest, painter.width);
      painter.dispose();
    }
    return widest;
  }
}

class _ThemeOption {
  const _ThemeOption(this.mode, this.label, this.icon);

  final ThemeMode mode;
  final String label;
  final IconData icon;
}
