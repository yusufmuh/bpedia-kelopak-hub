import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/tokens.dart';

/// Largest text scale the Material app bar applies to its title (the
/// framework clamps app bar titles at this factor).
const double _appBarTitleMaxScale = 1.34;

/// App bar title of a pushed page. At large text sizes on narrow phones it
/// wraps to a second line instead of being cut off; give the app bar
/// [pageToolbarHeight] so both lines fit.
class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {super.key});

  /// Page title.
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      maxLines: 2,
      softWrap: true,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Toolbar height for an app bar showing [title] as a [PageTitle] after a
/// back button and before [actionsWidth] of actions: null (the default
/// height) when the title fits on one line, otherwise room for two lines.
double? pageToolbarHeight(
  BuildContext context,
  String title, {
  double actionsWidth = 0,
}) {
  final theme = Theme.of(context);
  final style = theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge;
  final painter = TextPainter(
    text: TextSpan(text: title, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: _appBarTitleMaxScale),
    maxLines: 1,
  )..layout();
  final titleWidth = painter.width;
  final lineHeight = painter.height;
  painter.dispose();
  final available =
      MediaQuery.sizeOf(context).width -
      kToolbarHeight -
      2 * NavigationToolbar.kMiddleSpacing -
      actionsWidth;
  if (titleWidth <= available) return null;
  return math.max(kToolbarHeight, 2 * lineHeight + 2 * BpSpace.s3);
}
