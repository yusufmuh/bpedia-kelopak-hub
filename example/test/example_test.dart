import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelopak_hub/kelopak_hub.dart';
import 'package:kelopak_hub_example/demo_data.dart';
import 'package:kelopak_hub_example/demo_host.dart';
import 'package:kelopak_hub_example/main.dart';

void main() {
  testWidgets('contoh membuka Beranda, zona Hadiah, dan panel demo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final navigatorKey = GlobalKey<NavigatorState>();
    final host = DemoHost(products: demoProducts, navigatorKey: navigatorKey);
    final controller = (await tester.runAsync(
      () => KelopakController.open(
        backend: LocalKelopakBackend(
          store: MemoryKeyValueStore(),
          campaign: demoCampaign,
        ),
        host: host,
        watchDayChange: false,
      ),
    ))!;
    await tester.pumpWidget(
      KelopakHubExample(
        controller: controller,
        host: host,
        navigatorKey: navigatorKey,
      ),
    );
    await tester.pump();

    expect(find.text('Main bareng Bipy'), findsOneWidget);
    expect(find.byType(KelopakWalletStrip), findsOneWidget);

    await tester.tap(find.text('Zona Hadiah'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(RewardsHubPage), findsOneWidget);

    await tester.tap(find.text('Klaim'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(KelopakCheckInScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
