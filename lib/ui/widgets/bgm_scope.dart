import 'package:flutter/widgets.dart';

import '../../core/sound.dart';
import '../../domain/app_state.dart';

/// Keeps background music requested while [child] is mounted (wrap game screens with it).
///
/// Music only plays when the user switched it on (Akun > Suara & getar).
class BgmScope extends StatefulWidget {
  const BgmScope({super.key, required this.child});

  /// The screen that wants music.
  final Widget child;

  @override
  State<BgmScope> createState() => _BgmScopeState();
}

class _BgmScopeState extends State<BgmScope> {
  late final SoundService _sound;

  @override
  void initState() {
    super.initState();
    _sound = AppScope.read(context).sound..startMusic();
  }

  @override
  void dispose() {
    _sound.stopMusic();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
