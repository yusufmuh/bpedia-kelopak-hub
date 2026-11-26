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
const List<Shadow> _textShadow = <Shadow>[
  Shadow(color: Color(0x736B1439), offset: Offset(0, 1), blurRadius: 3),
];

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
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 16,
                                        height: 22 / 16,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        shadows: _textShadow,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  _MoreBadge(readyCount: readyCount),
                                ],
                              ),
                              const Text(
                                'Kumpulkan Kelopak, potong belanjamu',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 14 / 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  shadows: _textShadow,
                                ),
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

class _MoreBadge extends StatelessWidget {
  const _MoreBadge({required this.readyCount});

  final int readyCount;

  @override
  Widget build(BuildContext context) {
    final chevron = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: const Color(0x33FFFFFF),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0x80FFFFFF)),
      ),
      child: const Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: Colors.white,
      ),
    );
    return Semantics(
      label: readyCount > 0 ? '$readyCount siap' : 'Lihat semua',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (readyCount > 0) ...<Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: FestivePalette.goldLight,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                child: Text(
                  '$readyCount siap',
                  style: const TextStyle(
                    fontSize: 11,
                    height: 14 / 11,
                    fontWeight: FontWeight.w700,
                    color: FestivePalette.onGold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          chevron,
        ],
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

  @override
  Widget build(BuildContext context) {
    final tones = HubTones.of(context);
    final game = status.game;
    final art = Image(
      image: KelopakGameCard.artOf(game),
      width: 20,
      height: 20,
    );
    final progress = status.progress;
    final value = status.value;
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
        semanticLabel: '${game.title}. $value',
        child: Stack(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(7, 8, 5, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (game == KelopakGame.wheel)
                    SlowSpin(child: art)
                  else
                    Bobbing(
                      amplitude: 2,
                      phase: game == KelopakGame.checkIn ? 0 : 0.5,
                      child: art,
                    ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      _shortTitle(game),
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 11,
                        height: 14 / 11,
                        fontWeight: FontWeight.w600,
                        color: tones.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 1),
                  _ReadyPulse(
                    active: status.ready,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        value,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 12,
                          height: 16 / 12,
                          fontWeight: FontWeight.w800,
                          color: status.ready ? tones.brandStrong : tones.text,
                        ),
                      ),
                    ),
                  ),
                  if (game == KelopakGame.mission &&
                      progress != null) ...<Widget>[
                    const SizedBox(height: 6),
                    MiniProgressBar(value: progress, height: 4),
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
    alignment: Directionality.of(context) == TextDirection.rtl
        ? Alignment.centerRight
        : Alignment.centerLeft,
    scale: Tween<double>(
      begin: 1,
      end: 1.06,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
    child: widget.child,
  );
}
