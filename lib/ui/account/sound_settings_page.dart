import 'package:flutter/material.dart';

import '../../core/sound.dart';
import '../../core/tokens.dart';
import '../../domain/app_state.dart';
import 'account_widgets.dart';

/// Akun > Suara & getar: sound effects, background music and vibration.
///
/// Each switch is saved right away. Turning sound effects or vibration on
/// plays a short sample so the user knows what changed.
class SoundSettingsPage extends StatelessWidget {
  const SoundSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final settings = app.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Suara & getar')),
      body: AccountListView(
        children: <Widget>[
          SettingsGroup(
            children: <Widget>[
              SwitchListTile(
                shape: const RoundedRectangleBorder(),
                secondary: const Icon(Icons.volume_up_outlined),
                title: const Text('Efek suara'),
                subtitle: const Text(
                  'Bunyi singkat saat ambil Kelopak, memutar roda, dan dapat '
                  'hadiah',
                ),
                value: settings.sfxEnabled,
                onChanged: (enabled) {
                  app.setSfx(enabled);
                  if (enabled) app.sound.play(Sfx.tap);
                },
              ),
              SwitchListTile(
                shape: const RoundedRectangleBorder(),
                secondary: const Icon(Icons.music_note_outlined),
                title: const Text('Musik latar'),
                subtitle: const Text(
                  'Jingle lembut di tab Hadiah dan layar game. Awalnya mati.',
                ),
                value: settings.musicEnabled,
                onChanged: app.setMusic,
              ),
              SwitchListTile(
                shape: const RoundedRectangleBorder(),
                secondary: const Icon(Icons.vibration_rounded),
                title: const Text('Getar'),
                subtitle: const Text('Getar ringan saat hadiah masuk'),
                value: settings.hapticsEnabled,
                onChanged: (enabled) {
                  app.setHaptics(enabled);
                  if (enabled) app.haptics.light();
                },
              ),
            ],
          ),
          const SizedBox(height: BpSpace.s4),
          const InfoNote(
            'Suara aplikasi tidak menghentikan musik dari aplikasi lain. '
            'Atur keras pelannya lewat tombol volume ponsel.',
          ),
        ],
      ),
    );
  }
}
