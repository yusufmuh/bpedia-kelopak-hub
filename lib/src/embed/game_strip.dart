/// Strip "Main bareng Bipy" untuk Beranda host (SPEC-V3 §4.1 butir 5).
library;

import 'package:flutter/material.dart';

import '../../kit.dart';
import '../controller/kelopak_scope.dart';
import '../core/paths.dart';
import '../games/game_actions.dart';
import '../ui/game_status.dart';
import '../ui/hub_widgets.dart';
import '../ui/kelopak_navigation.dart';
import '../ui/rewards_hub_page.dart'
    show KelopakGameCard, MiniProgressBar, SlowSpin;

/// Satu-satunya blok pesta di Beranda: kartu gradasi pink dengan Bipy
/// berjalan dan tiga kartu mini game. Ketuk kartu mini membuka game; ketuk
/// latar membuka zona Hadiah. Membaca `KelopakScope` terdekat.
class KelopakGameStrip extends StatelessWidget {
  /// Membuat strip. [margin] bawaan 16 kiri-kanan.
  const KelopakGameStrip({
    super.key,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
  });

  /// Jarak luar.
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final c = KelopakScope.of(context);
    final statuses = KelopakGameStatus.all(c);
    final readyCount = statuses.where((status) => status.ready).length;
    return Padding(
      padding: margin,
      child: Semantics(
        container: true,
        label: readyCount > 0
            ? 'Main bareng Bipy, $readyCount hadiah bisa diambil'
            : 'Main bareng Bipy',
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () =>
                KelopakNavigation.openPath(context, KelopakPaths.rewards),
            child: Ink(
              decoration: const BoxDecoration(gradient: FestivePalette.hero),
              child: Stack(
                children: <Widget>[
                  const Positioned.fill(
                    child: SunburstRays(
                      opacity: 0.07,
                      center: Alignment(-0.75, 0.2),
                    ),
                  ),
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: Sparkles(count: 9, maxSize: 12),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      4,
                      10,
                      10,
                      10,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        const SizedBox(
                          width: 86,
                          height: 120,
                          child: OverflowBox(
                            maxWidth: 120,
                            alignment: Alignment.bottomCenter,
                            child: BipySprite(BipySprites.walk, height: 112),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  const Expanded(
                                    child: Text(
                                      'Main bareng Bipy',
                                      style: TextStyle(
                                        fontSize: 16,
                                        height: 22 / 16,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        shadows: <Shadow>[
                                          Shadow(
                                            color: Color(0x556B1439),
                                            offset: Offset(0, 1),
                                            blurRadius: 3,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Text(
                                    readyCount > 0
                                        ? '$readyCount siap'
                                        : 'Lihat semua',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    for (
                                      var i = 0;
                                      i < statuses.length;
                                      i++
                                    ) ...<Widget>[
                                      if (i > 0) const SizedBox(width: 6),
                                      Expanded(
                                        child: _MiniGameCard(
                                          status: statuses[i],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniGameCard extends StatelessWidget {
  const _MiniGameCard({required this.status});

  final KelopakGameStatus status;

  static String _shortTitle(KelopakGame game) => switch (game) {
    KelopakGame.checkIn => 'Check-in',
    KelopakGame.wheel => 'Roda Sabtu',
    KelopakGame.mission => 'Misi',
  };

  String get _line {
    switch (status.game) {
      case KelopakGame.checkIn:
        return status.ready ? 'Klaim +1' : 'Sudah klaim';
      case KelopakGame.wheel:
        return status.ready ? 'Putar sekarang' : status.headline;
      case KelopakGame.mission:
        return status.headline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tones = HubTones.of(context);
    final game = status.game;
    final art = Image(
      image: KelopakGameCard.artOf(game),
      width: 34,
      height: 34,
    );
    final progress = status.progress;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tones.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x296B1439),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Pressable(
        onTap: () => KelopakNavigation.openPath(context, status.path),
        semanticLabel: '${game.title}. $_line',
        child: Stack(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (game == KelopakGame.wheel)
                    SlowSpin(child: art)
                  else
                    Bobbing(
                      amplitude: 3,
                      phase: game == KelopakGame.checkIn ? 0 : 0.5,
                      child: art,
                    ),
                  const SizedBox(height: 4),
                  Text(
                    _shortTitle(game),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      height: 14 / 11,
                      fontWeight: FontWeight.w700,
                      color: tones.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _ReadyPulse(
                    active: status.ready,
                    child: Text(
                      _line,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        height: 13 / 10,
                        fontWeight: FontWeight.w600,
                        color: status.ready
                            ? tones.brandStrong
                            : tones.textMuted,
                      ),
                    ),
                  ),
                  if (game == KelopakGame.mission &&
                      progress != null) ...<Widget>[
                    const SizedBox(height: 4),
                    MiniProgressBar(value: progress),
                  ],
                ],
              ),
            ),
            if (status.ready)
              const PositionedDirectional(
                top: 5,
                end: 5,
                child: ReadyDot(size: 9),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReadyPulse extends StatefulWidget {
  const _ReadyPulse({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_ReadyPulse> createState() => _ReadyPulseState();
}

class _ReadyPulseState extends State<_ReadyPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_ReadyPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() => syncRepeat(
    _pulse,
    enabled: widget.active && !reduceMotionOf(context),
    reverse: true,
  );

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: Tween<double>(
      begin: 1,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
    child: widget.child,
  );
}
