import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/tokens.dart';

/// Burst of pink petals over the whole app (about 900 ms, gravity, spin, fade).
abstract final class PetalBurst {
  /// Total duration of a burst.
  static const Duration duration = Duration(milliseconds: 900);

  /// Plays a burst from [globalOrigin] (defaults to the center of [context]'s
  /// render box). Returns immediately; does nothing when animations are
  /// disabled. The overlay entry removes itself when the burst ends.
  static void play(
    BuildContext context, {
    Offset? globalOrigin,
    int count = 26,
  }) {
    if (count <= 0 || MediaQuery.disableAnimationsOf(context)) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    final overlayBox = overlay.context.findRenderObject();
    if (overlayBox is! RenderBox || !overlayBox.hasSize) return;

    Offset origin = overlayBox.size.center(Offset.zero);
    if (globalOrigin != null) {
      origin = overlayBox.globalToLocal(globalOrigin);
    } else {
      final box = context.findRenderObject();
      if (box is RenderBox && box.hasSize && box.attached) {
        origin = overlayBox.globalToLocal(
          box.localToGlobal(box.size.center(Offset.zero)),
        );
      }
    }

    final colors = BpColors.of(context);
    final palette = <Color>[
      colors.petal400,
      colors.pink500,
      colors.tulip300,
      colors.bipyHood,
      colors.pink600,
      colors.honey400,
    ];
    final random = math.Random();
    final particles = List<_Petal>.generate(
      count,
      (index) => _Petal.random(random, palette[index % palette.length]),
    );

    late final OverlayEntry entry;
    var removed = false;
    void remove() {
      if (removed) return;
      removed = true;
      entry.remove();
      entry.dispose();
    }

    entry = OverlayEntry(
      builder: (context) => _PetalBurstLayer(
        origin: origin,
        particles: particles,
        onFinished: remove,
      ),
    );
    overlay.insert(entry);
  }
}

class _Petal {
  _Petal({
    required this.velocity,
    required this.spin,
    required this.angle,
    required this.color,
    required this.path,
  });

  factory _Petal.random(math.Random random, Color color) {
    final direction =
        -math.pi / 2 + (random.nextDouble() - 0.5) * math.pi * 1.3;
    final speed = 260 + random.nextDouble() * 380;
    final length = 10 + random.nextDouble() * 9;
    final width = length * (0.55 + random.nextDouble() * 0.2);
    final path = Path()
      ..moveTo(0, -length / 2)
      ..quadraticBezierTo(width, -length / 8, 0, length / 2)
      ..quadraticBezierTo(-width, -length / 8, 0, -length / 2)
      ..close();
    return _Petal(
      velocity: Offset(math.cos(direction), math.sin(direction)) * speed,
      spin: (random.nextDouble() - 0.5) * 14,
      angle: random.nextDouble() * math.pi * 2,
      color: color,
      path: path,
    );
  }

  final Offset velocity;
  final double spin;
  final double angle;
  final Color color;
  final Path path;
}

class _PetalBurstLayer extends StatefulWidget {
  const _PetalBurstLayer({
    required this.origin,
    required this.particles,
    required this.onFinished,
  });

  final Offset origin;
  final List<_Petal> particles;
  final VoidCallback onFinished;

  @override
  State<_PetalBurstLayer> createState() => _PetalBurstLayerState();
}

/// Uses a plain [Ticker] (not muted by [TickerMode]) so the burst always
/// finishes and removes its entry, even if a route covers it meanwhile.
class _PetalBurstLayerState extends State<_PetalBurstLayer> {
  final ValueNotifier<double> _progress = ValueNotifier<double>(0);
  late final Ticker _ticker;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _ticker = Ticker(_onTick, debugLabel: 'PetalBurst')..start();
  }

  void _onTick(Duration elapsed) {
    final t = elapsed.inMicroseconds / PetalBurst.duration.inMicroseconds;
    if (t < 1) {
      _progress.value = t;
      return;
    }
    if (_finished) return;
    _finished = true;
    _ticker.stop();
    widget.onFinished();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: _PetalPainter(
              origin: widget.origin,
              particles: widget.particles,
              progress: _progress,
            ),
          ),
        ),
      ),
    );
  }
}

class _PetalPainter extends CustomPainter {
  _PetalPainter({
    required this.origin,
    required this.particles,
    required this.progress,
  }) : super(repaint: progress);

  static const double _gravity = 1150;

  final Offset origin;
  final List<_Petal> particles;
  final ValueListenable<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    final seconds = t * PetalBurst.duration.inMilliseconds / 1000;
    final fade = t < 0.6 ? 1.0 : (1 - (t - 0.6) / 0.4).clamp(0.0, 1.0);
    final paint = Paint()..style = PaintingStyle.fill;
    for (final petal in particles) {
      final position =
          origin +
          petal.velocity * seconds +
          Offset(0, 0.5 * _gravity * seconds * seconds);
      paint.color = petal.color.withValues(alpha: petal.color.a * fade);
      canvas
        ..save()
        ..translate(position.dx, position.dy)
        ..rotate(petal.angle + petal.spin * seconds)
        ..drawPath(petal.path, paint)
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_PetalPainter oldDelegate) =>
      oldDelegate.origin != origin || oldDelegate.particles != particles;
}
