/// Building blocks shared by the Hadiah screens: navigation helper, status
/// banner, rule sheets and tables, card badges.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/assets.dart';
import '../../core/tokens.dart';
import '../widgets/widgets.dart';

/// Pushes [page] as a full-screen route on top of [context]'s navigator.
void openRewardsPage(BuildContext context, Widget page) {
  unawaited(
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (context) => page)),
  );
}

/// Top inset that vertically centers a [boxSize] box on the first line of
/// text drawn with [style] (honors the text scale).
double firstLineInset(BuildContext context, TextStyle style, double boxSize) {
  final fontSize = style.fontSize ?? 14;
  final lineHeight =
      MediaQuery.textScalerOf(context).scale(fontSize) * (style.height ?? 1.4);
  return math.max(0, (lineHeight - boxSize) / 2);
}

/// Whether the user enlarged text enough that side-by-side rows should stack.
bool isLargeText(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(16) > 16 * 1.3;

/// Page padding shared by the Hadiah screens (16 dp sides, 32 dp bottom).
const EdgeInsets rewardsPagePadding = EdgeInsets.fromLTRB(
  BpSpace.s4,
  BpSpace.s2,
  BpSpace.s4,
  BpSpace.s8,
);

/// App bar actions with the "DEMO" chip, as used on every Hadiah screen. At
/// large text sizes the chip moves into the page ([DemoBodyChip]) so the
/// title keeps the room it needs.
List<Widget> demoAppBarActions(BuildContext context) => isLargeText(context)
    ? const <Widget>[]
    : const <Widget>[Center(child: DemoChip()), SizedBox(width: BpSpace.s4)];

/// The "DEMO" chip at the top of a Hadiah page, shown only at large text
/// sizes, when [demoAppBarActions] leaves it out of the app bar.
class DemoBodyChip extends StatelessWidget {
  const DemoBodyChip({super.key});

  @override
  Widget build(BuildContext context) {
    if (!isLargeText(context)) return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.only(bottom: BpSpace.s3),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: DemoChip(),
      ),
    );
  }
}

typedef _TonePalette = ({
  Color background,
  Color icon,
  Color title,
  Color detail,
  Color? border,
});

_TonePalette _paletteFor(BuildContext context, StatusTone tone) {
  final scheme = Theme.of(context).colorScheme;
  final colors = BpColors.of(context);
  return switch (tone) {
    StatusTone.success => (
      background: colors.success100,
      icon: colors.success700,
      title: colors.success700,
      detail: colors.success700,
      border: null,
    ),
    StatusTone.info => (
      background: Color.alphaBlend(
        colors.info.withValues(alpha: 0.12),
        scheme.surfaceContainerLowest,
      ),
      icon: colors.info,
      title: scheme.onSurface,
      detail: scheme.onSurfaceVariant,
      border: null,
    ),
    StatusTone.warning => (
      background: colors.honey100,
      icon: colors.honey800,
      title: colors.honey800,
      detail: colors.honey800,
      border: null,
    ),
    StatusTone.neutral => (
      background: scheme.surfaceContainerLowest,
      icon: scheme.onSurfaceVariant,
      title: scheme.onSurface,
      detail: scheme.onSurfaceVariant,
      border: scheme.outlineVariant,
    ),
    StatusTone.brand => (
      background: scheme.primaryContainer,
      icon: scheme.primary,
      title: scheme.onPrimaryContainer,
      detail: scheme.onSurfaceVariant,
      border: null,
    ),
  };
}

/// Rounded status block: icon + title + optional detail, always readable as
/// text (never color alone). Set [liveRegion] when the status changes in place.
class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.icon,
    required this.title,
    this.detail,
    this.tone = StatusTone.neutral,
    this.liveRegion = false,
  });

  /// Leading icon.
  final IconData icon;

  /// Status in a few words.
  final String title;

  /// Supporting line, usually a [Text] without style (it inherits one).
  final Widget? detail;

  /// Color tone.
  final StatusTone tone;

  /// Announces changes to screen readers.
  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _paletteFor(context, tone);
    final titleStyle = theme.textTheme.titleSmall!.copyWith(
      color: palette.title,
    );
    final border = palette.border;
    final extra = detail;
    return Semantics(
      container: true,
      liveRegion: liveRegion,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: BorderRadius.circular(BpRadius.md),
          border: border == null ? null : Border.all(color: border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BpSpace.s4,
            vertical: BpSpace.s3,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.only(
                  top: firstLineInset(context, titleStyle, 22),
                ),
                child: Icon(icon, size: 22, color: palette.icon),
              ),
              const SizedBox(width: BpSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(title, style: titleStyle),
                    if (extra != null) ...<Widget>[
                      const SizedBox(height: 2),
                      DefaultTextStyle.merge(
                        style: theme.textTheme.bodyMedium!.copyWith(
                          color: palette.detail,
                        ),
                        child: extra,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circle badge (blush) that holds a card's leading artwork.
class RewardIconBadge extends StatelessWidget {
  const RewardIconBadge({super.key, required this.child, this.size = 48});

  /// Artwork, about half of [size].
  final Widget child;

  /// Diameter.
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// The 3D gift box render (free products), decorative.
class GiftArt extends StatelessWidget {
  const GiftArt({super.key, this.size = 28});

  /// Width and height.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppImages.giftBox3d,
      width: size,
      height: size,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.redeem_rounded,
        size: size,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

/// Tiny Roda Sabtu wheel glyph in the theme colors (gold slice = product).
class MiniWheelIcon extends StatelessWidget {
  const MiniWheelIcon({super.key, this.size = 28});

  /// Width and height.
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      size: Size.square(size),
      painter: _MiniWheelPainter(
        rim: scheme.primary,
        sliceA: scheme.surfaceContainerLowest,
        sliceB: scheme.secondaryContainer,
        prize: scheme.tertiary,
      ),
    );
  }
}

class _MiniWheelPainter extends CustomPainter {
  const _MiniWheelPainter({
    required this.rim,
    required this.sliceA,
    required this.sliceB,
    required this.prize,
  });

  static const int _slices = 6;

  final Color rim;
  final Color sliceA;
  final Color sliceB;
  final Color prize;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final center = size.center(Offset.zero);
    final stroke = size.shortestSide * 0.09;
    final radius = size.shortestSide / 2 - stroke / 2;
    final disc = Rect.fromCircle(center: center, radius: radius);
    const sweep = 2 * math.pi / _slices;
    final fill = Paint()..style = PaintingStyle.fill;
    for (var index = 0; index < _slices; index++) {
      fill.color = index == 0 ? prize : (index.isOdd ? sliceB : sliceA);
      canvas.drawArc(
        disc,
        -math.pi / 2 - sweep / 2 + index * sweep,
        sweep,
        true,
        fill,
      );
    }
    canvas
      ..drawCircle(
        center,
        radius,
        Paint()
          ..color = rim
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke,
      )
      ..drawCircle(center, radius * 0.24, Paint()..color = rim);
  }

  @override
  bool shouldRepaint(_MiniWheelPainter oldDelegate) =>
      oldDelegate.rim != rim ||
      oldDelegate.sliceA != sliceA ||
      oldDelegate.sliceB != sliceB ||
      oldDelegate.prize != prize;
}

/// One label/value pair of a [RulesTable].
@immutable
class RuleRow {
  const RuleRow(this.label, this.value);

  /// Left column.
  final String label;

  /// Right column.
  final String value;
}

/// Bordered two-column table for rules and examples; both columns wrap.
class RulesTable extends StatelessWidget {
  const RulesTable({
    super.key,
    required this.rows,
    this.header,
    this.labelFlex = 5,
    this.valueFlex = 6,
  });

  /// Body rows.
  final List<RuleRow> rows;

  /// Optional column titles.
  final RuleRow? header;

  /// Width share of the label column.
  final int labelFlex;

  /// Width share of the value column.
  final int valueFlex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final titles = header;
    final children = <Widget>[
      if (titles != null) ...<Widget>[
        _RuleRowView(
          row: titles,
          isHeader: true,
          labelFlex: labelFlex,
          valueFlex: valueFlex,
        ),
        const Divider(),
      ],
    ];
    for (var index = 0; index < rows.length; index++) {
      if (index > 0) children.add(const Divider());
      children.add(
        _RuleRowView(
          row: rows[index],
          labelFlex: labelFlex,
          valueFlex: valueFlex,
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(BpRadius.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _RuleRowView extends StatelessWidget {
  const _RuleRowView({
    required this.row,
    required this.labelFlex,
    required this.valueFlex,
    this.isHeader = false,
  });

  final RuleRow row;
  final int labelFlex;
  final int valueFlex;
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelStyle = isHeader
        ? theme.textTheme.labelMedium!.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          )
        : theme.textTheme.bodyMedium!.copyWith(color: scheme.onSurfaceVariant);
    final valueStyle = isHeader
        ? labelStyle
        : theme.textTheme.bodyMedium!.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w600,
          );
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: BpSpace.s4,
          vertical: BpSpace.s3,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              flex: labelFlex,
              child: Text(row.label, style: labelStyle),
            ),
            const SizedBox(width: BpSpace.s3),
            Expanded(
              flex: valueFlex,
              child: Text(row.value, style: valueStyle),
            ),
          ],
        ),
      ),
    );
  }
}

/// A rule sentence with a pink dot and a hanging indent.
class RuleBullet extends StatelessWidget {
  const RuleBullet(this.text, {super.key});

  /// The rule.
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium!.copyWith(
      color: theme.colorScheme.onSurface,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: BpSpace.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(top: firstLineInset(context, style, 6)),
            child: ExcludeSemantics(
              child: SizedBox.square(
                dimension: 6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: BpSpace.s3),
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }
}

/// Small heading inside rule sheets.
class RuleHeading extends StatelessWidget {
  const RuleHeading(this.text, {super.key});

  /// Heading text.
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: BpSpace.s2, bottom: BpSpace.s2),
      child: Semantics(
        header: true,
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      ),
    );
  }
}

/// Shows a scrollable rules/terms sheet with an optional Bipy pose and a
/// single "Mengerti" button (the themed secondary button: white, Berry
/// outline and label). Completes when the sheet closes.
Future<void> showRewardsInfoSheet(
  BuildContext context, {
  required String title,
  required List<Widget> children,
  String? imageAsset,
  String closeLabel = 'Mengerti',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _RewardsInfoSheet(
      title: title,
      imageAsset: imageAsset,
      closeLabel: closeLabel,
      children: children,
    ),
  );
}

class _RewardsInfoSheet extends StatelessWidget {
  const _RewardsInfoSheet({
    required this.title,
    required this.imageAsset,
    required this.closeLabel,
    required this.children,
  });

  final String title;
  final String? imageAsset;
  final String closeLabel;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final image = imageAsset;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(BpSpace.s6, 0, BpSpace.s6, BpSpace.s6),
      child: ContentWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (image != null) ...<Widget>[
              Center(
                child: Image.asset(
                  image,
                  height: 96,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: BpSpace.s3),
            ],
            Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: BpSpace.s4),
            ...children,
            const SizedBox(height: BpSpace.s6),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(closeLabel),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-width content, capped at 560 dp and centered on wide screens.
///
/// Unlike [ContentWidth] alone, [child] always gets the full width, so cards
/// and short texts line up with each other.
class RewardsContent extends StatelessWidget {
  const RewardsContent({super.key, required this.child});

  /// Content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ContentWidth(
      child: SizedBox(width: double.infinity, child: child),
    );
  }
}

/// Centers [child] in the available height and scrolls when it does not fit
/// (empty states at large text sizes).
class ScrollableCenter extends StatelessWidget {
  const ScrollableCenter({super.key, required this.child});

  /// Content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0,
          ),
          child: Center(child: ContentWidth(child: child)),
        ),
      ),
    );
  }
}
