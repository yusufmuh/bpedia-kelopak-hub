import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelopak_hub/kelopak_hub.dart';

import '../support/shot.dart';
import '../ui/hub_harness.dart';

const Size _long = Size(390, 1900);

void main() {
  for (final brightness in Brightness.values) {
    final tone = brightness == Brightness.light ? 'terang' : 'gelap';

    testWidgets('zona hadiah $tone', (tester) async {
      final fixture = (await tester.runAsync(openRichHub))!;
      addTearDown(fixture.controller.dispose);
      await shot(
        tester,
        hubApp(fixture, home: const RewardsHubPage(), brightness: brightness),
        name: 'hub_$tone',
        size: _long,
      );
      await shot(
        tester,
        hubApp(fixture, home: const RewardsHubPage(), brightness: brightness),
        name: 'hub_layar_$tone',
      );
    });

    testWidgets('zona hadiah tamu $tone', (tester) async {
      final fixture = (await tester.runAsync(() => openHub(loggedIn: false)))!;
      addTearDown(fixture.controller.dispose);
      await shot(
        tester,
        hubApp(fixture, home: const RewardsHubPage(), brightness: brightness),
        name: 'hub_tamu_$tone',
        size: const Size(390, 1300),
      );
    });

    testWidgets('zona hadiah baru $tone', (tester) async {
      final fixture = (await tester.runAsync(openHub))!;
      addTearDown(fixture.controller.dispose);
      await shot(
        tester,
        hubApp(fixture, home: const RewardsHubPage(), brightness: brightness),
        name: 'hub_baru_$tone',
        size: const Size(390, 1500),
      );
    });

    testWidgets('halaman turunan $tone', (tester) async {
      final fixture = (await tester.runAsync(openRichHub))!;
      addTearDown(fixture.controller.dispose);
      await shot(
        tester,
        hubApp(fixture, home: const MyGiftsPage(), brightness: brightness),
        name: 'hadiahku_$tone',
      );
      await shot(
        tester,
        hubApp(fixture, home: const VouchersPage(), brightness: brightness),
        name: 'voucher_$tone',
      );
      await shot(
        tester,
        hubApp(
          fixture,
          home: const VouchersPage(
            key: ValueKey<String>('riwayat'),
            showHistory: true,
          ),
          brightness: brightness,
        ),
        name: 'voucher_riwayat_$tone',
      );
      await shot(
        tester,
        hubApp(fixture, home: const LedgerPage(), brightness: brightness),
        name: 'riwayat_$tone',
        size: const Size(390, 1400),
      );
    });

    testWidgets('lembar cara pakai $tone', (tester) async {
      final fixture = (await tester.runAsync(openRichHub))!;
      addTearDown(fixture.controller.dispose);
      await pumpShot(
        tester,
        hubApp(fixture, home: const RewardsHubPage(), brightness: brightness),
      );
      await tester.tap(find.text('Cara pakai').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await settleImages(tester, rounds: 3);
      await saveShot(tester, 'cara_pakai_$tone');
    });

    testWidgets('widget tanam $tone', (tester) async {
      final fixture = (await tester.runAsync(openRichHub))!;
      addTearDown(fixture.controller.dispose);
      await shot(
        tester,
        hubApp(
          fixture,
          brightness: brightness,
          home: Builder(
            builder: (context) => Scaffold(
              backgroundColor: Theme.of(context).colorScheme.surfaceDim,
              body: const SafeArea(
                child: Column(
                  children: <Widget>[
                    SizedBox(height: 16),
                    KelopakWalletStrip(),
                    SizedBox(height: 16),
                    KelopakGameStrip(),
                  ],
                ),
              ),
            ),
          ),
        ),
        name: 'tanam_$tone',
        size: const Size(390, 420),
      );
    });

    testWidgets('perayaan misi $tone', (tester) async {
      final fixture = (await tester.runAsync(openRichHub))!;
      addTearDown(fixture.controller.dispose);
      await pumpShot(
        tester,
        hubApp(
          fixture,
          brightness: brightness,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showMissionCompleteCelebration(
                    context,
                    voucher: fixture.controller.activeVouchers.last,
                  ),
                  child: const Text('Rayakan'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Rayakan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1400));
      await settleImages(tester, rounds: 3);
      await saveShot(tester, 'perayaan_misi_$tone');
    });

    testWidgets('tiga game lewat hub $tone', (tester) async {
      final fixture = (await tester.runAsync(openRichHub))!;
      addTearDown(fixture.controller.dispose);
      const screens = <String, Widget>{
        'checkin': KelopakCheckInScreen(),
        'roda': KelopakWheelScreen(),
        'misi': KelopakMissionScreen(),
      };
      for (final entry in screens.entries) {
        await shot(
          tester,
          hubApp(fixture, home: entry.value, brightness: brightness),
          name: 'game_${entry.key}_$tone',
          settle: const Duration(milliseconds: 1200),
        );
      }
    });
  }
}
