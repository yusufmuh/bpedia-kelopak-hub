import 'package:daily_checkin/daily_checkin.dart' show CheckInPage;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelopak_hub/kelopak_hub.dart';
import 'package:misi_belanja/misi_belanja.dart' show MissionsPage;
import 'package:roda_sabtu/roda_sabtu.dart' show WheelPage;

import '../support/shot.dart';
import 'hub_harness.dart';

Future<HubFixture> _rich(WidgetTester tester) async {
  final fixture = (await tester.runAsync(openRichHub))!;
  addTearDown(fixture.controller.dispose);
  return fixture;
}

Future<HubFixture> _fresh(WidgetTester tester, {bool loggedIn = true}) async {
  final fixture = (await tester.runAsync(() => openHub(loggedIn: loggedIn)))!;
  addTearDown(fixture.controller.dispose);
  return fixture;
}

Future<void> _pump(WidgetTester tester, Widget app, {Size size = shotPhone}) =>
    pumpShot(tester, app, size: size, pixelRatio: 1);

void main() {
  group('RewardsHubPage', () {
    testWidgets('shows the balance, three games, gifts, vouchers and history', (
      tester,
    ) async {
      final fixture = await _rich(tester);
      await _pump(
        tester,
        hubApp(fixture, home: const RewardsHubPage()),
        size: const Size(390, 2400),
      );

      expect(find.bySemanticsLabel('Saldo 31 Kelopak'), findsOneWidget);
      expect(find.text('senilai Rp3.100 · 1 Kelopak = Rp100'), findsOneWidget);
      expect(find.byType(KelopakGameCard), findsNWidgets(3));
      expect(find.text('Klaim +1 Kelopak'), findsOneWidget);
      expect(find.text('Buka Sabtu · 2 hari lagi'), findsOneWidget);
      expect(find.text('Hadiah menunggu (1)'), findsOneWidget);
      expect(find.text('Animate Whitening Day Cream 10 g'), findsOneWidget);
      expect(find.text('Voucherku (2)'), findsOneWidget);
      expect(find.byType(VoucherTicket), findsNWidgets(2));
      expect(find.byType(LedgerTile), findsNWidgets(3));
      expect(find.text('Check-in hari ke-31'), findsOneWidget);
      expect(find.text('Cara kerja Kelopak'), findsOneWidget);
    });

    testWidgets('a game card opens its game page through kelopakRoutes', (
      tester,
    ) async {
      final fixture = await _rich(tester);
      await _pump(tester, hubApp(fixture, home: const RewardsHubPage()));

      await tester.tap(find.text('Klaim'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(CheckInPage), findsOneWidget);
      expect(find.byType(KelopakCheckInScreen), findsOneWidget);
    });

    testWidgets('a host opener replaces Navigator.pushNamed', (tester) async {
      final fixture = await _rich(tester);
      final opened = <String>[];
      await _pump(
        tester,
        hubApp(
          fixture,
          home: KelopakNavigation(
            open: (context, location) => opened.add(location),
            child: const RewardsHubPage(),
          ),
        ),
      );

      await tester.tap(find.text('Riwayat'));
      await tester.tap(find.text('Roda Sabtu'));
      await tester.tap(find.text('Misi Belanja'));
      expect(opened, <String>[
        KelopakPaths.ledger,
        KelopakPaths.wheel,
        KelopakPaths.mission,
      ]);
    });

    testWidgets('"Pakai" on a voucher leaves the reward pages', (tester) async {
      final fixture = await _rich(tester);
      await _pump(
        tester,
        hubApp(fixture, home: const RewardsHubPage()),
        size: const Size(390, 2400),
      );

      await tester.tap(find.text('Pakai').first);
      expect(fixture.host.navigations, <String>['cart']);
    });

    testWidgets('a guest sees an invitation and no wallet sections', (
      tester,
    ) async {
      final fixture = await _fresh(tester, loggedIn: false);
      await _pump(
        tester,
        hubApp(fixture, home: const RewardsHubPage()),
        size: const Size(390, 1600),
      );

      expect(find.text('Hai, Babes!'), findsOneWidget);
      expect(find.text('Voucherku'), findsNothing);
      expect(find.text('Riwayat Kelopak'), findsNothing);
      expect(find.byType(KelopakGameCard), findsNWidgets(3));

      await tester.tap(find.text('Masuk'));
      expect(fixture.host.navigations, <String>['login']);

      fixture.host.isLoggedIn = true;
      await tester.pump();
      expect(find.text('Hai, Babes!'), findsNothing);
      expect(find.text('Kelopakmu'), findsOneWidget);
    });

    testWidgets('an empty history invites a check-in and then records it', (
      tester,
    ) async {
      final fixture = await _fresh(tester);
      await _pump(
        tester,
        hubApp(fixture, home: const RewardsHubPage()),
        size: const Size(390, 2000),
      );

      expect(find.text('Belum ada riwayat'), findsOneWidget);
      expect(find.text('Belum ada voucher'), findsOneWidget);
      expect(find.text('Hadiah menunggu (1)'), findsNothing);

      await tester.runAsync(fixture.controller.claimCheckIn);
      await tester.pump();
      expect(find.text('Belum ada riwayat'), findsNothing);
      expect(find.byType(LedgerTile), findsOneWidget);
      expect(find.text('Sudah klaim hari ini'), findsOneWidget);
    });

    testWidgets('the "Cara pakai" sheet shows live odds and stages', (
      tester,
    ) async {
      final fixture = await _rich(tester);
      await _pump(tester, hubApp(fixture, home: const RewardsHubPage()));

      await tester.tap(find.text('Cara pakai'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Cara pakai Kelopak'), findsOneWidget);
      expect(find.text('Produk gratis: 5%'), findsOneWidget);
      final stage = find.textContaining('Tahap 1: belanja produk misi');
      await tester.scrollUntilVisible(
        stage,
        200,
        scrollable: find.descendant(
          of: find.byType(KelopakHowTo),
          matching: find.byType(Scrollable),
        ),
      );
      expect(stage, findsOneWidget);
    });
  });

  group('Hadiahku, Voucherku, Riwayat', () {
    testWidgets('Hadiahku groups gifts by status', (tester) async {
      final fixture = await _rich(tester);
      await _pump(tester, hubApp(fixture, home: const MyGiftsPage()));

      expect(find.text('Menunggu pesanan berikutnya (1)'), findsOneWidget);
      expect(find.text('Sudah diterima (1)'), findsOneWidget);
      expect(find.text('Pesanan BP-261107-0003'), findsOneWidget);
      await tester.tap(find.text('Belanja'));
      await tester.tap(find.text('Keranjang'));
      expect(fixture.host.navigations, <String>['shop', 'cart']);
    });

    testWidgets('Hadiahku without gifts points to Roda Sabtu', (tester) async {
      final fixture = await _fresh(tester);
      final opened = <String>[];
      await _pump(
        tester,
        hubApp(
          fixture,
          home: KelopakNavigation(
            open: (context, location) => opened.add(location),
            child: const MyGiftsPage(),
          ),
        ),
      );
      expect(find.text('Belum ada hadiah produk'), findsOneWidget);
      await tester.tap(find.text('Main Roda Sabtu'));
      expect(opened, <String>[KelopakPaths.wheel]);
    });

    testWidgets('Voucherku splits usable and history', (tester) async {
      final fixture = await _rich(tester);
      await _pump(tester, hubApp(fixture, home: const VouchersPage()));

      expect(find.text('Bisa dipakai (2)'), findsOneWidget);
      expect(find.text('Riwayat (0)'), findsOneWidget);
      expect(find.text('Rp12.000'), findsOneWidget);
      expect(find.text('Berlaku s.d. 27 Nov 2026'), findsOneWidget);

      fixture.shiftDays(2);
      await tester.pump();
      expect(find.text('Bisa dipakai (1)'), findsOneWidget);
      expect(find.text('Riwayat (1)'), findsOneWidget);
    });

    testWidgets('Riwayat filters credits and debits with a running balance', (
      tester,
    ) async {
      final fixture = await _rich(tester);
      await _pump(
        tester,
        hubApp(fixture, home: const LedgerPage()),
        size: const Size(390, 6000),
      );

      final all = find.byType(LedgerTile).evaluate().length;
      expect(all, fixture.controller.ledgerHistory.length);
      expect(find.text('Saldo 31'), findsOneWidget);

      await tester.tap(find.text('Dipakai'));
      await tester.pump();
      final spent = fixture.controller.ledgerHistory
          .where((line) => !line.entry.isCredit)
          .length;
      expect(find.byType(LedgerTile), findsNWidgets(spent));
      expect(spent, greaterThan(0));

      await tester.tap(find.text('Didapat'));
      await tester.pump();
      expect(find.byType(LedgerTile), findsNWidgets(all - spent));
    });

    testWidgets('guests are asked to log in on every sub page', (tester) async {
      final fixture = await _fresh(tester, loggedIn: false);
      for (final page in const <Widget>[
        MyGiftsPage(),
        VouchersPage(),
        LedgerPage(),
      ]) {
        await _pump(tester, hubApp(fixture, home: page));
        expect(find.text('Masuk dulu, Babes'), findsOneWidget);
        await tester.tap(find.text('Masuk'));
      }
      expect(fixture.host.navigations, <String>['login', 'login', 'login']);
    });
  });

  group('kelopakRoutes', () {
    test('covers every /hadiah path', () {
      expect(kelopakRoutes.keys.toSet(), <String>{
        KelopakPaths.rewards,
        KelopakPaths.checkIn,
        KelopakPaths.wheel,
        KelopakPaths.mission,
        KelopakPaths.myGifts,
        KelopakPaths.vouchers,
        KelopakPaths.ledger,
      });
      expect(kelopakRouteFor('hadiah/roda'), isNotNull);
      expect(kelopakRouteFor('/hadiah/voucher/?dari=notif'), isNotNull);
      expect(kelopakRouteFor('/hadiah/lain'), isNull);
      expect(kelopakRouteFor('/keranjang'), isNull);
    });

    testWidgets('each route builds its page', (tester) async {
      final fixture = await _rich(tester);
      final expected = <String, Type>{
        KelopakPaths.rewards: RewardsHubPage,
        KelopakPaths.checkIn: CheckInPage,
        KelopakPaths.wheel: WheelPage,
        KelopakPaths.mission: MissionsPage,
        KelopakPaths.myGifts: MyGiftsPage,
        KelopakPaths.vouchers: VouchersPage,
        KelopakPaths.ledger: LedgerPage,
      };
      for (final entry in expected.entries) {
        await _pump(
          tester,
          hubApp(fixture, home: Builder(builder: kelopakRoutes[entry.key]!)),
        );
        expect(find.byType(entry.value), findsOneWidget, reason: entry.key);
        await tester.pumpWidget(const SizedBox());
      }
    });
  });
}
