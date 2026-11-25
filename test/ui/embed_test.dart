import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelopak_hub/kelopak_hub.dart';

import '../support/shot.dart';
import 'hub_harness.dart';

Widget _home(List<String> opened) => KelopakNavigation(
  open: (context, location) => opened.add(location),
  child: const Scaffold(
    body: Column(
      children: <Widget>[
        SizedBox(height: 24),
        KelopakWalletStrip(),
        SizedBox(height: 16),
        KelopakGameStrip(),
      ],
    ),
  ),
);

void main() {
  testWidgets('wallet cells open history, vouchers and the cart', (
    tester,
  ) async {
    final fixture = (await tester.runAsync(openRichHub))!;
    addTearDown(fixture.controller.dispose);
    final opened = <String>[];
    await pumpShot(tester, hubApp(fixture, home: _home(opened)), pixelRatio: 1);

    expect(find.text('31 Kelopak'), findsOneWidget);
    expect(find.text('senilai Rp3.100'), findsOneWidget);
    expect(find.text('2 voucher'), findsOneWidget);
    expect(find.text('1 hadiah'), findsOneWidget);

    await tester.tap(find.text('31 Kelopak'));
    await tester.tap(find.text('2 voucher'));
    await tester.tap(find.text('1 hadiah'));
    expect(opened, <String>[KelopakPaths.ledger, KelopakPaths.vouchers]);
    expect(fixture.host.navigations, <String>['cart']);
  });

  testWidgets('a guest wallet asks to log in', (tester) async {
    final fixture = (await tester.runAsync(() => openHub(loggedIn: false)))!;
    addTearDown(fixture.controller.dispose);
    final opened = <String>[];
    await pumpShot(tester, hubApp(fixture, home: _home(opened)), pixelRatio: 1);

    expect(find.text('Kelopak'), findsOneWidget);
    await tester.tap(find.text('Kelopak'));
    expect(opened, isEmpty);
    expect(fixture.host.navigations, <String>['login']);
  });

  testWidgets('the game strip opens each game and the zone', (tester) async {
    final fixture = (await tester.runAsync(openRichHub))!;
    addTearDown(fixture.controller.dispose);
    final opened = <String>[];
    await pumpShot(tester, hubApp(fixture, home: _home(opened)), pixelRatio: 1);

    expect(find.text('Klaim +1'), findsOneWidget);
    expect(find.text('1 siap'), findsOneWidget);
    await tester.tap(find.text('Check-in'));
    await tester.tap(find.text('Roda Sabtu'));
    await tester.tap(find.text('Misi'));
    await tester.tap(find.text('Main bareng Bipy'));
    expect(opened, <String>[
      KelopakPaths.checkIn,
      KelopakPaths.wheel,
      KelopakPaths.mission,
      KelopakPaths.rewards,
    ]);

    await tester.runAsync(fixture.controller.claimCheckIn);
    await tester.pump();
    expect(find.text('Sudah klaim'), findsOneWidget);
    expect(find.text('Lihat semua'), findsOneWidget);
  });

  testWidgets('MissionCompleteCelebration shows the voucher once the order is '
      'received', (tester) async {
    final fixture = (await tester.runAsync(openHub))!;
    final c = fixture.controller;
    addTearDown(c.dispose);
    final opened = <String>[];
    await pumpShot(
      tester,
      hubApp(
        fixture,
        home: KelopakNavigation(
          open: (context, location) => opened.add(location),
          child: const MissionCompleteCelebration(
            child: Scaffold(body: Text('Detail pesanan')),
          ),
        ),
      ),
      pixelRatio: 1,
    );

    await tester.runAsync(() async {
      final quote = c.quote(
        CheckoutRequest(
          lines: const <CheckoutLine>[
            CheckoutLine(
              productCode: 'P39A06S01000007',
              unitPrice: 26000,
              quantity: 3,
            ),
          ],
          shippingFee: 9000,
          useKelopak: false,
        ),
      );
      await c.commitOrder('BP-7', quote);
      await c.completeOrder('BP-7');
    });
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Misi tuntas!'), findsOneWidget);
    expect(find.text('Tahap 1 Misi Belanja selesai'), findsOneWidget);
    await tester.tap(find.text('Lihat voucher'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(opened, <String>[KelopakPaths.vouchers]);
  });
}
