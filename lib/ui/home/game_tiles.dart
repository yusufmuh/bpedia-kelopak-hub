import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:roda_sabtu/roda_sabtu.dart' show SpinEligibility;

import '../../core/tokens.dart';
import '../../domain/app_state.dart';
import '../shop/shop_layout.dart';
import '../shop/shop_navigation.dart';
import '../widgets/widgets.dart';

/// How a tile status reads.
enum _TileTone { ready, done, waiting }

class _TileData {
  const _TileData({
    required this.title,
    required this.icon,
    required this.status,
    required this.statusIcon,
    required this.tone,
    required this.onTap,
  });

  final String title;
  final Widget icon;
  final String status;
  final IconData statusIcon;
  final _TileTone tone;
  final VoidCallback onTap;
}

/// "Main bareng Bipy": Check-in Harian, Roda Sabtu and Misi Belanja, each
/// with its live status. Three equal tiles in a row; they stack into full
/// width rows when a word would not fit (narrow screens, large text).
class GameTiles extends StatelessWidget {
  const GameTiles({super.key});

  static const double _gap = BpSpace.s3;
  static const double _padding = BpSpace.s3;

  /// Inline status icon (16) plus its gap (6), see `IconText`.
  static const double _statusIconSpace = 22;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final tiles = <_TileData>[
      _checkInTile(context, app),
      _wheelTile(context, app),
      _missionTile(context, app),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.maxWidth - 2 * _gap) / 3;
        if (_fitsInColumns(context, tiles, tileWidth)) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: _gap,
              children: <Widget>[
                for (final tile in tiles)
                  Expanded(child: _GameTile(data: tile, compact: true)),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: _gap,
          children: <Widget>[
            for (final tile in tiles) _GameTile(data: tile, compact: false),
          ],
        );
      },
    );
  }

  /// Whether every word of every title and status fits inside a column tile.
  static bool _fitsInColumns(
    BuildContext context,
    List<_TileData> tiles,
    double tileWidth,
  ) {
    final text = Theme.of(context).textTheme;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final inner = tileWidth - 2 * _padding;
    double widestWord(String value, TextStyle style) {
      var widest = 0.0;
      for (final word in value.split(' ')) {
        final painter = TextPainter(
          text: TextSpan(text: word, style: style),
          textDirection: direction,
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        widest = math.max(widest, painter.width);
        painter.dispose();
      }
      return widest;
    }

    for (final tile in tiles) {
      if (widestWord(tile.title, text.titleSmall!) > inner) return false;
      if (widestWord(tile.status, _statusStyle(text)) >
          inner - _statusIconSpace) {
        return false;
      }
    }
    return true;
  }

  static TextStyle _statusStyle(TextTheme text) =>
      text.labelMedium!.copyWith(fontWeight: FontWeight.w600);

  static _TileData _checkInTile(BuildContext context, AppState app) {
    final ready = app.canCheckIn;
    return _TileData(
      title: 'Check-in Harian',
      icon: const KelopakToken(size: 28),
      status: ready ? 'Siap diambil' : 'Sudah hari ini',
      statusIcon: ready ? Icons.redeem_rounded : Icons.check_circle_rounded,
      tone: ready ? _TileTone.ready : _TileTone.done,
      onTap: () => openCheckIn(context),
    );
  }

  static _TileData _wheelTile(BuildContext context, AppState app) {
    final (
      String status,
      IconData icon,
      _TileTone tone,
    ) = switch (app.spinEligibility) {
      SpinEligibility.available => (
        'Siap diputar',
        Icons.play_circle_rounded,
        _TileTone.ready,
      ),
      SpinEligibility.alreadySpun => (
        'Sudah diputar',
        Icons.check_circle_rounded,
        _TileTone.done,
      ),
      SpinEligibility.notSaturday => (
        'Buka Sabtu · ${app.daysUntilNextSaturday} hari lagi',
        Icons.schedule_rounded,
        _TileTone.waiting,
      ),
      SpinEligibility.promoInactive => (
        'Promo sedang jeda',
        Icons.pause_circle_outline_rounded,
        _TileTone.waiting,
      ),
    };
    return _TileData(
      title: 'Roda Sabtu',
      icon: const MiniWheelIcon(size: 28),
      status: status,
      statusIcon: icon,
      tone: tone,
      onTap: () => openWheel(context),
    );
  }

  static _TileData _missionTile(BuildContext context, AppState app) {
    final stage = app.activeMissionStage;
    final String status;
    final IconData icon;
    final _TileTone tone;
    if (stage == null) {
      status = 'Semua tahap selesai';
      icon = Icons.check_circle_rounded;
      tone = _TileTone.done;
    } else if (app.ordersAwaitingMission.isNotEmpty) {
      status = 'Tahap ${stage.number} · tunggu pesanan diterima';
      icon = Icons.local_shipping_outlined;
      tone = _TileTone.ready;
    } else {
      status = 'Tahap ${stage.number} · 0 dari 1 pesanan';
      icon = Icons.flag_outlined;
      tone = _TileTone.waiting;
    }
    return _TileData(
      title: 'Misi Belanja',
      icon: const BrandIcon(BrandIcons.voucher, size: 26),
      status: status,
      statusIcon: icon,
      tone: tone,
      onTap: () => openMissions(context),
    );
  }
}

class _GameTile extends StatelessWidget {
  const _GameTile({required this.data, required this.compact});

  final _TileData data;

  /// Column tile (icon above text) instead of a full-width row.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = Text(data.title, style: theme.textTheme.titleSmall);
    final status = _TileStatus(data: data);
    final icon = IconWell(size: 44, child: data.icon);

    return Semantics(
      button: true,
      label: '${data.title}, ${data.status}',
      excludeSemantics: true,
      onTap: data.onTap,
      child: SoftCard(
        onTap: data.onTap,
        padding: const EdgeInsets.all(GameTiles._padding),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  icon,
                  const SizedBox(height: BpSpace.s2),
                  title,
                  const Spacer(),
                  const SizedBox(height: BpSpace.s2),
                  status,
                ],
              )
            : Row(
                children: <Widget>[
                  icon,
                  const SizedBox(width: BpSpace.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        title,
                        const SizedBox(height: BpSpace.s1),
                        status,
                      ],
                    ),
                  ),
                  const SizedBox(width: BpSpace.s2),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
      ),
    );
  }
}

class _TileStatus extends StatelessWidget {
  const _TileStatus({required this.data});

  final _TileData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = BpColors.of(context);
    final (Color iconColor, Color textColor) = switch (data.tone) {
      _TileTone.ready => (scheme.primary, scheme.onSurface),
      _TileTone.done => (colors.success700, colors.success700),
      _TileTone.waiting => (scheme.onSurfaceVariant, scheme.onSurfaceVariant),
    };
    return IconText(
      data.statusIcon,
      data.status,
      iconColor: iconColor,
      style: GameTiles._statusStyle(theme.textTheme).copyWith(color: textColor),
    );
  }
}

/// Small Roda Sabtu wheel: alternating petals, berry rim, hub and pointer.
class MiniWheelIcon extends StatelessWidget {
  const MiniWheelIcon({super.key, this.size = BpSize.icon});

  /// Width and height.
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = BpColors.of(context);
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _MiniWheelPainter(
          segmentA: colors.pink500,
          segmentB: colors.pink200,
          rim: colors.berry700,
          hub: colors.card,
          pointer: colors.honey400,
        ),
      ),
    );
  }
}

class _MiniWheelPainter extends CustomPainter {
  const _MiniWheelPainter({
    required this.segmentA,
    required this.segmentB,
    required this.rim,
    required this.hub,
    required this.pointer,
  });

  static const int _segments = 8;

  final Color segmentA;
  final Color segmentB;
  final Color rim;
  final Color hub;
  final Color pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.07;
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - stroke;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const sweep = 2 * math.pi / _segments;
    final fill = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < _segments; i++) {
      fill.color = i.isEven ? segmentA : segmentB;
      canvas.drawArc(rect, -math.pi / 2 + i * sweep, sweep, true, fill);
    }
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = rim;
    canvas
      ..drawCircle(center, radius, outline)
      ..drawCircle(center, radius * 0.24, Paint()..color = hub)
      ..drawCircle(center, radius * 0.24, outline);
    final half = size.width * 0.14;
    final pointerPath = Path()
      ..moveTo(center.dx - half, 0)
      ..lineTo(center.dx + half, 0)
      ..lineTo(center.dx, size.height * 0.26)
      ..close();
    canvas
      ..drawPath(pointerPath, Paint()..color = pointer)
      ..drawPath(
        pointerPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke * 0.6
          ..strokeJoin = StrokeJoin.round
          ..color = rim,
      );
  }

  @override
  bool shouldRepaint(_MiniWheelPainter oldDelegate) =>
      oldDelegate.segmentA != segmentA ||
      oldDelegate.segmentB != segmentB ||
      oldDelegate.rim != rim ||
      oldDelegate.hub != hub ||
      oldDelegate.pointer != pointer;
}
