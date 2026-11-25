import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelopak_hub/kelopak_hub.dart';
import 'package:kelopak_hub/src/ui/hub_widgets.dart' show HubTones;

import '../support/shot.dart';
import 'hub_harness.dart';

const Size _small = Size(360, 740);

final Map<String, Widget> _pages = <String, Widget>{
  'zona hadiah': const RewardsHubPage(),
  'hadiahku': const MyGiftsPage(),
  'voucher': const VouchersPage(),
  'voucher riwayat': const VouchersPage(showHistory: true),
  'riwayat': const LedgerPage(),
  'widget tanam': const Scaffold(
    body: SingleChildScrollView(
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
};

void main() {
  for (final brightness in Brightness.values) {
    for (final loggedIn in <bool>[true, false]) {
      final label =
          '${brightness.name}, ${loggedIn ? 'masuk' : 'tamu'}, teks 200%';
      testWidgets('all hub pages fit 360 dp ($label)', (tester) async {
        final fixture = (await tester.runAsync(openRichHub))!;
        addTearDown(fixture.controller.dispose);
        fixture.host.isLoggedIn = loggedIn;
        for (final entry in _pages.entries) {
          await pumpShot(
            tester,
            hubApp(
              fixture,
              home: entry.value,
              brightness: brightness,
              textScale: 2,
            ),
            size: _small,
            pixelRatio: 1,
          );
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull, reason: entry.key);
          final scrollables = find.byType(Scrollable);
          if (scrollables.evaluate().isNotEmpty) {
            await tester.drag(scrollables.first, const Offset(0, -2000));
            await tester.pump(const Duration(milliseconds: 300));
            expect(
              tester.takeException(),
              isNull,
              reason: '${entry.key} bawah',
            );
          }
          await tester.pumpWidget(const SizedBox());
        }
      });
    }
  }

  testWidgets('tap targets are 48 dp and labelled', (tester) async {
    final fixture = (await tester.runAsync(openRichHub))!;
    addTearDown(fixture.controller.dispose);
    final handle = tester.ensureSemantics();
    for (final entry in _pages.entries) {
      await pumpShot(
        tester,
        hubApp(fixture, home: entry.value),
        size: const Size(390, 2400),
        pixelRatio: 1,
      );
      await expectLater(
        tester,
        meetsGuideline(androidTapTargetGuideline),
        reason: entry.key,
      );
      await expectLater(
        tester,
        meetsGuideline(labeledTapTargetGuideline),
        reason: entry.key,
      );
      await tester.pumpWidget(const SizedBox());
    }
    handle.dispose();
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'text pairs used by the hub meet contrast (${brightness.name})',
      (tester) async {
        late HubTones tones;
        await tester.pumpWidget(
          MaterialApp(
            theme: kelopakPreviewTheme(brightness),
            home: Builder(
              builder: (context) {
                tones = HubTones.of(context);
                return const SizedBox();
              },
            ),
          ),
        );
        double ratio(Color a, Color b) {
          final la = a.computeLuminance();
          final lb = b.computeLuminance();
          return (la > lb ? la + 0.05 : lb + 0.05) /
              (la > lb ? lb + 0.05 : la + 0.05);
        }

        final pairs = <String, (Color, Color)>{
          'teks/permukaan': (tones.text, tones.surface),
          'teks redup/permukaan': (tones.textMuted, tones.surface),
          'teks redup/kanvas': (tones.textMuted, tones.canvas),
          'teks redup/redup': (tones.textMuted, tones.muted),
          'merek kuat/permukaan': (tones.brandStrong, tones.surface),
          'merek kuat/tint': (tones.brandStrong, tones.brandTint),
          'emas/tint emas': (tones.onGoldTint, tones.goldTint),
          'hijau/permukaan': (tones.success, tones.surface),
          'hijau/tint hijau': (tones.success, tones.successTint),
          'tombol': (tones.scheme.onPrimary, tones.brand),
          'tautan/permukaan': (tones.brand, tones.surface),
        };
        for (final entry in pairs.entries) {
          expect(
            ratio(entry.value.$1, entry.value.$2),
            greaterThanOrEqualTo(4.5),
            reason: entry.key,
          );
        }
      },
    );
  }

  testWidgets('reduced motion lets every page settle', (tester) async {
    final fixture = (await tester.runAsync(openRichHub))!;
    addTearDown(fixture.controller.dispose);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    for (final entry in _pages.entries) {
      await pumpShot(tester, hubApp(fixture, home: entry.value), pixelRatio: 1);
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse, reason: entry.key);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('game cards and the strip read as named buttons', (tester) async {
    final fixture = (await tester.runAsync(openRichHub))!;
    addTearDown(fixture.controller.dispose);
    final handle = tester.ensureSemantics();
    await pumpShot(
      tester,
      hubApp(fixture, home: _pages['widget tanam']),
      pixelRatio: 1,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'^31 Kelopak, senilai Rp3\.100$')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'^Check-in Harian\. Klaim \+1$')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('^Main bareng Bipy, 1 hadiah')),
      findsOneWidget,
    );

    await pumpShot(
      tester,
      hubApp(fixture, home: const RewardsHubPage()),
      pixelRatio: 1,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'^Check-in Harian\. Klaim \+1 Kelopak\. ')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Bipy, ketuk untuk menyapa'), findsOneWidget);
    handle.dispose();
  });
}
