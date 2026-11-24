import 'dart:async';

import 'package:daily_checkin/daily_checkin.dart' show CheckInWeekTrack;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelopak_hub/app.dart';
import 'package:kelopak_hub/core/assets.dart';
import 'package:kelopak_hub/core/theme.dart';
import 'package:kelopak_hub/data/catalog.dart';
import 'package:kelopak_hub/domain/app_state.dart';
import 'package:kelopak_hub/domain/rewards_engine.dart' show kelopakCapRule;
import 'package:kelopak_hub/domain/shop_engine.dart';
import 'package:kelopak_hub/ui/account/demo_tools_page.dart';
import 'package:kelopak_hub/ui/account/terms_page.dart';
import 'package:kelopak_hub/ui/orders/order_detail_page.dart';
import 'package:kelopak_hub/ui/orders/orders_page.dart';
import 'package:kelopak_hub/ui/rewards/checkin_page.dart';
import 'package:kelopak_hub/ui/rewards/my_rewards_page.dart';
import 'package:kelopak_hub/ui/rewards/rewards_sheets.dart';
import 'package:kelopak_hub/ui/rewards/wheel_page.dart';
import 'package:kelopak_hub/ui/shell.dart';
import 'package:kelopak_hub/ui/shop/cart_page.dart';
import 'package:kelopak_hub/ui/shop/checkout_page.dart';
import 'package:kelopak_hub/ui/shop/order_success_page.dart';
import 'package:kelopak_hub/ui/shop/product_page.dart';
import 'package:kelopak_hub/ui/shop/search_page.dart';
import 'package:kelopak_hub/ui/widgets/widgets.dart';
import 'package:roda_sabtu/roda_sabtu.dart' show SaturdayWheel;

import '../support/test_app_state.dart';

const String _skintific = 'skintific-matte-fit-serum-spf50';
const String _cushion = 'somethinc-copy-paste-cushion-nina';

Future<void> _loadBrandFonts() async {
  final poppins = FontLoader('Poppins');
  for (final weight in <int>[400, 500, 600, 700, 800]) {
    poppins.addFont(rootBundle.load('assets/fonts/Poppins-$weight.ttf'));
  }
  await poppins.load();
}

void _usePhone(WidgetTester tester, {double width = 360, double height = 740}) {
  tester.view
    ..physicalSize = Size(width * 3, height * 3)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void _disableAnimations(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

Future<void> _pumpApp(WidgetTester tester, AppState state) async {
  await tester.pumpWidget(AppScope(notifier: state, child: const BpediaApp()));
  await tester.pumpAndSettle();
}

Future<void> _finish(WidgetTester tester, AppState state) async {
  await tester.pumpWidget(const SizedBox.shrink());
  state.dispose();
}

NavigatorState _navigator(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator).first);

Future<void> _push(WidgetTester tester, Widget page) async {
  unawaited(
    _navigator(
      tester,
    ).push<void>(MaterialPageRoute<void>(builder: (context) => page)),
  );
  await tester.pumpAndSettle();
}

Future<void> _pop(WidgetTester tester) async {
  _navigator(tester).pop();
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapTab(WidgetTester tester, String label) => _tap(
  tester,
  find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
);

Order _place(AppState state) {
  final result = state.placeOrder(state.quote());
  expect(result, isA<OrderPlaced>());
  return (result as OrderPlaced).order;
}

Finder _image(String asset) => find.byWidgetPredicate(
  (widget) =>
      widget is Image &&
      widget.image is AssetImage &&
      (widget.image as AssetImage).assetName == asset,
);

void main() {
  setUpAll(_loadBrandFonts);

  group('Roda Sabtu wait (finding 2 + owner request)', () {
    testWidgets('Friday 23.30: Beranda, Hadiah, Roda Sabtu and Mode Demo all '
        'say "30 menit lagi"', (tester) async {
      _usePhone(tester);
      _disableAnimations(tester);
      final clock = FakeClock(wibInstant(2026, 11, 27, hour: 23, minute: 30));
      final state = await createTestAppState(now: clock.now);
      await _pumpApp(tester, state);

      expect(
        find.textContaining('Buka Sabtu, 28 Nov · 30 menit lagi'),
        findsOneWidget,
      );
      expect(find.textContaining('hari lagi'), findsNothing);
      expect(find.textContaining('jam'), findsNothing);

      // The Beranda tile keeps counting without any other change.
      clock.advance(const Duration(minutes: 1));
      await tester.pump(const Duration(minutes: 1, seconds: 1));
      expect(
        find.textContaining('Buka Sabtu, 28 Nov · 29 menit lagi'),
        findsOneWidget,
      );
      clock.current = wibInstant(2026, 11, 27, hour: 23, minute: 30);
      await tester.pump(const Duration(minutes: 1, seconds: 1));

      await _tapTab(tester, 'Hadiah');
      expect(find.text('Buka Sabtu, 28 Nov · 00.00 WIB'), findsOneWidget);
      expect(
        find.text('Putaran gratis berikutnya 30 menit lagi.'),
        findsOneWidget,
      );
      expect(find.textContaining('hari lagi'), findsNothing);

      await _tap(tester, find.text('Lihat roda'));
      expect(find.byType(WheelPage), findsOneWidget);
      expect(find.text('Buka Sabtu, 28 Nov · 00.00 WIB'), findsOneWidget);
      expect(find.text('30 menit lagi'), findsOneWidget);
      expect(
        find.text('Tombol aktif Sabtu, 28 Nov · 00.00 WIB.'),
        findsOneWidget,
      );
      expect(find.textContaining('hari lagi'), findsNothing);
      await _pop(tester);

      await _push(tester, const DemoToolsPage());
      expect(
        find.text('Sabtu berikutnya Sabtu, 28 Nov · 00.00 WIB, 30 menit lagi.'),
        findsOneWidget,
      );
      await _finish(tester, state);
    });

    testWidgets('Wednesday 02.00: every screen counts 3 calendar days', (
      tester,
    ) async {
      _usePhone(tester);
      _disableAnimations(tester);
      final state = await createTestAppState(
        now: () => wibInstant(2026, 11, 25, hour: 2),
      );
      await _pumpApp(tester, state);
      expect(
        find.textContaining('Buka Sabtu, 28 Nov · 3 hari lagi'),
        findsOneWidget,
      );
      await _tapTab(tester, 'Hadiah');
      expect(
        find.text('Putaran gratis berikutnya 3 hari lagi.'),
        findsOneWidget,
      );
      expect(find.textContaining('jam'), findsNothing);
      await _push(tester, const WheelPage());
      expect(find.text('3 hari lagi'), findsOneWidget);
      await _pop(tester);
      await _push(tester, const DemoToolsPage());
      expect(
        find.text('Sabtu berikutnya Sabtu, 28 Nov · 00.00 WIB, 3 hari lagi.'),
        findsOneWidget,
      );
      await _finish(tester, state);
    });
  });

  testWidgets('finding 1: two qualifying orders, one voucher, and only the '
      'single waiting order is promised it', (tester) async {
    _usePhone(tester);
    final state = await createTestAppState();
    state.addToCart(_skintific);
    final first = _place(state);
    await _pumpApp(tester, state);
    const certain =
        'pesanan ini menyelesaikan Misi Belanja tahap 1 dan voucher';

    await _push(tester, OrderSuccessPage(orderId: first.id));
    expect(find.textContaining(certain), findsOneWidget);
    await _pop(tester);

    state.addToCart(_skintific);
    await _push(tester, const CartPage());
    expect(
      find.textContaining(
        'Sudah ada pesanan Dikirim yang memenuhi syarat tahap 1',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Pesanan ini memenuhi syarat Misi Belanja tahap 1 setelah diterima',
      ),
      findsNothing,
    );
    await _pop(tester);

    final second = _place(state);
    expect(second.subtotal, first.subtotal);
    await _push(tester, OrderSuccessPage(orderId: second.id));
    expect(find.textContaining(certain), findsNothing);
    expect(
      find.textContaining(
        'voucher Rp10.000 terbit untuk pesanan memenuhi syarat yang lebih '
        'dulu diterima',
      ),
      findsOneWidget,
    );
    await _pop(tester);
    await _push(tester, OrderDetailPage(orderId: second.id));
    expect(find.textContaining('yang lebih dulu diterima'), findsOneWidget);
    await _pop(tester);

    state
      ..markOrderReceived(first.id)
      ..markOrderReceived(second.id);
    expect(state.vouchers, hasLength(1));
    await _finish(tester, state);
  });

  testWidgets('finding 4: the Kelopak limit reads "after voucher" everywhere', (
    tester,
  ) async {
    _usePhone(tester);
    _disableAnimations(tester);
    final state = await createTestAppState();
    state
      ..claimCheckIn()
      ..addToCart(_skintific);
    await _pumpApp(tester, state);
    expect(kelopakCapRule, 'Maks. 50% dari total setelah voucher (Demo)');

    await _push(tester, const CheckoutPage());
    expect(find.text('$kelopakCapRule · saldo 1 Kelopak'), findsOneWidget);
    expect(find.textContaining('total belanja'), findsNothing);
    await _pop(tester);

    await _push(tester, const TermsPage());
    expect(find.textContaining(kelopakCapRule), findsOneWidget);
    await _pop(tester);

    unawaited(showKelopakRulesSheet(tester.element(find.byType(AppShell))));
    await tester.pumpAndSettle();
    expect(find.text(kelopakCapRule), findsOneWidget);
    // The sheet closes with the themed secondary button (finding 13).
    expect(find.widgetWithText(OutlinedButton, 'Mengerti'), findsOneWidget);
    await _finish(tester, state);
  });

  testWidgets('finding 6: "Putar gratis" is on screen at 360 x 740, right '
      'under the odds', (tester) async {
    _usePhone(tester);
    _disableAnimations(tester);
    final state = await createTestAppState(now: () => wibInstant(2026, 11, 28));
    await _pumpApp(tester, state);
    await _push(tester, const WheelPage());

    final button = find.widgetWithText(FilledButton, 'Putar gratis');
    final rect = tester.getRect(button);
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(740));
    final summary = find.text('Peluang: Produk gratis 10% · 3 Kelopak 90%');
    expect(tester.getRect(summary).bottom, lessThanOrEqualTo(rect.top));
    expect(find.text('Peluang & ketentuan'), findsOneWidget);
    await _finish(tester, state);
  });

  testWidgets('finding 9: Bipy poses follow the message', (tester) async {
    _usePhone(tester);
    _disableAnimations(tester);
    final state = await createTestAppState();
    await _pumpApp(tester, state);

    await _push(tester, const CartPage());
    expect(_image(AppImages.bipyNgintip), findsOneWidget);
    expect(_image(AppImages.bipyTasHati), findsNothing);
    await _pop(tester);

    state.addToCart(_skintific);
    final order = _place(state);
    await _push(tester, OrderSuccessPage(orderId: order.id));
    expect(_image(AppImages.bipyTasHati), findsOneWidget);
    expect(_image(AppImages.bipyMenyapa), findsNothing);
    await _pop(tester);

    await _push(tester, const CheckInPage());
    await _tap(tester, find.text('Ambil 1 Kelopak'));
    final sheet = find.byType(BottomSheet);
    expect(
      find.descendant(of: sheet, matching: _image(AppImages.kelopakToken3d)),
      findsOneWidget,
    );
    expect(_image(AppImages.bipyWink), findsNothing);
    await _finish(tester, state);
  });

  testWidgets('finding 10: section actions share the title row at 100%', (
    tester,
  ) async {
    _usePhone(tester);
    final state = await createTestAppState();
    await _pumpApp(tester, state);
    final title = tester.getRect(find.text('Main bareng Bipy'));
    final action = tester.getRect(find.text('Semua hadiah'));
    expect((title.center.dy - action.center.dy).abs(), lessThan(2));
    expect(action.left, greaterThan(title.right));
    expect(action.right, greaterThan(300));
    await _finish(tester, state);
  });

  testWidgets('finding 13: product badges are radius-6 brand badges', (
    tester,
  ) async {
    _usePhone(tester);
    final state = await createTestAppState();
    await _pumpApp(tester, state);
    await _push(tester, const ProductPage(productId: _skintific));

    final scheme = Theme.of(
      tester.element(find.byType(ProductPage)),
    ).colorScheme;
    for (final label in <String>['Original', 'Gratis ongkir (Demo)']) {
      final badge = find.ancestor(
        of: find.text(label),
        matching: find.byType(BrandBadge),
      );
      expect(badge, findsOneWidget);
      final box = tester.widget<DecoratedBox>(
        find.descendant(of: badge, matching: find.byType(DecoratedBox)).first,
      );
      expect(
        (box.decoration as BoxDecoration).borderRadius,
        BorderRadius.circular(6),
      );
    }
    expect(find.byType(StatusPill), findsNothing);
    final ongkir = tester.widget<Text>(find.text('Gratis ongkir (Demo)'));
    expect(ongkir.style!.color, scheme.secondary);
    await _finish(tester, state);
  });

  testWidgets('finding 14: stacked dialog actions put the primary on top', (
    tester,
  ) async {
    _usePhone(tester);
    final state = await createTestAppState();
    state.addToCart(_skintific);
    final order = _place(state);
    await _pumpApp(tester, state);
    await _push(tester, OrderDetailPage(orderId: order.id));
    await _tap(tester, find.text('Pesanan Diterima'));
    final confirm = tester.getRect(find.text('Ya, sudah diterima'));
    final cancel = tester.getRect(find.text('Belum'));
    expect(confirm.top, lessThan(cancel.top));
    expect((confirm.center.dx - cancel.center.dx).abs(), lessThan(2));
    await _finish(tester, state);
  });

  group('finding 17: iOS Reduce Motion', () {
    testWidgets('the wheel settles at once, without petals, and the check-in '
        'bud stops pulsing', (tester) async {
      _usePhone(tester);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(reduceMotion: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final state = await createTestAppState(
        now: () => wibInstant(2026, 11, 28),
        random: ScriptedRandom(<int>[5000, 3]),
      );
      await tester.pumpWidget(
        AppScope(notifier: state, child: const BpediaApp()),
      );
      await tester.pump();
      expect(
        MediaQuery.disableAnimationsOf(tester.element(find.byType(AppShell))),
        isTrue,
      );

      await _push(tester, const WheelPage());
      final spin = find.widgetWithText(FilledButton, 'Putar gratis');
      await tester.ensureVisible(spin);
      await tester.pump();
      await tester.tap(spin);
      await tester.pump();
      expect(find.text('Lewati animasi'), findsNothing);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Yay, Babes! Kamu dapat 3 Kelopak'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_PetalBurstLayer',
        ),
        findsNothing,
      );
      await tester.tap(find.text('Oke'));
      await tester.pumpAndSettle();
      await _pop(tester);

      await _tapTab(tester, 'Hadiah');
      final pulse = find.descendant(
        of: find.byType(CheckInWeekTrack),
        matching: find.byType(ScaleTransition),
      );
      expect(pulse, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.widget<ScaleTransition>(pulse).scale.value, 1.0);
      await _finish(tester, state);
    });

    testWidgets('switching Reduce Motion on while the app runs applies at '
        'once', (tester) async {
      _usePhone(tester);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final state = await createTestAppState();
      await tester.pumpWidget(
        AppScope(notifier: state, child: const BpediaApp()),
      );
      await tester.pump();
      final shell = find.byType(AppShell);
      expect(MediaQuery.disableAnimationsOf(tester.element(shell)), isFalse);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(reduceMotion: true);
      await tester.pump();
      expect(MediaQuery.disableAnimationsOf(tester.element(shell)), isTrue);
      await _finish(tester, state);
    });
  });

  testWidgets('finding 22: the wheel only says "Siap diputar" when it is', (
    tester,
  ) async {
    _usePhone(tester);
    _disableAnimations(tester);
    final semantics = tester.ensureSemantics();
    final state = await createTestAppState();
    await _pumpApp(tester, state);
    await _push(tester, const WheelPage());
    SemanticsNode wheel() =>
        tester.getSemantics(find.byType(SaturdayWheel).first);
    expect(wheel().label, 'Roda Sabtu');
    expect(wheel().value, 'Buka Sabtu, 28 Nov');

    state.setPromoActive(false);
    await tester.pumpAndSettle();
    expect(wheel().value, 'Promo sedang tidak aktif');

    state
      ..setPromoActive(true)
      ..jumpToNextSaturday();
    await tester.pumpAndSettle();
    expect(wheel().value, 'Siap diputar');
    semantics.dispose();
    await _finish(tester, state);
  });

  group('findings 8 and 23: selected chips', () {
    testWidgets('selected filter chips get a Berry border and label', (
      tester,
    ) async {
      _usePhone(tester);
      final state = await createTestAppState();
      state.addToCart(_skintific);
      _place(state);
      await _pumpApp(tester, state);

      Future<void> expectChips(String selected, String other) async {
        final scheme = Theme.of(
          tester.element(find.text(selected)),
        ).colorScheme;
        OutlinedBorder shapeOf(String label) =>
            tester
                    .widget<Material>(
                      find
                          .descendant(
                            of: find.widgetWithText(FilterChip, label),
                            matching: find.byType(Material),
                          )
                          .first,
                    )
                    .shape!
                as OutlinedBorder;
        Color? labelColor(String label) => tester
            .renderObject<RenderParagraph>(find.text(label))
            .text
            .style!
            .color;
        expect(shapeOf(selected).side.color, scheme.secondary);
        expect(shapeOf(selected).side.width, 1.5);
        expect(labelColor(selected), scheme.secondary);
        expect(shapeOf(other).side.color, scheme.outlineVariant);
        expect(labelColor(other), scheme.onSurface);
      }

      await _push(tester, const SearchPage(category: ProductCategory.skincare));
      await expectChips('Skincare', 'Makeup');
      await _pop(tester);

      await _tapTab(tester, 'Transaksi');
      expect(find.byType(OrdersPage), findsOneWidget);
      await expectChips('Semua (1)', 'Selesai (0)');
      await _finish(tester, state);
    });

    test('dark theme: wheel segment fills differ and stay readable', () {
      final dark = buildDarkTheme().colorScheme;
      final light = buildLightTheme().colorScheme;
      expect(dark.secondaryContainer, isNot(dark.primaryContainer));
      expect(dark.secondaryContainer.toARGB32(), 0xFF6A2542);
      expect(light.secondaryContainer.toARGB32(), 0xFFFBCFDB);
      double luminance(Color color) => color.computeLuminance();
      final contrast =
          (luminance(dark.onSecondaryContainer) + 0.05) /
          (luminance(dark.secondaryContainer) + 0.05);
      expect(contrast, greaterThan(4.5));
    });
  });

  testWidgets('finding 30: the 00.00 WIB timer is re-armed on resume after '
      'the phone slept', (tester) async {
    _usePhone(tester);
    _disableAnimations(tester);
    final clock = FakeClock(wibInstant(2026, 11, 27, hour: 8));
    final state = await createTestAppState(
      now: clock.now,
      watchDayChange: true,
    );
    state.claimCheckIn();
    await _pumpApp(tester, state);
    expect(find.text('Ambil 1 Kelopak'), findsNothing);

    clock.advance(const Duration(hours: 4));
    await tester.pump(const Duration(hours: 4));
    // Asleep for 6 hours: the wall clock moves, timers do not.
    clock.advance(const Duration(hours: 6));
    for (final lifecycle in <AppLifecycleState>[
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(lifecycle);
    }
    await tester.pump();
    expect(find.text('Ambil 1 Kelopak'), findsNothing);

    clock.advance(const Duration(hours: 6, seconds: 2));
    await tester.pump(const Duration(hours: 6, seconds: 2));
    await tester.pump();
    expect(state.canCheckIn, isTrue);
    expect(find.text('Ambil 1 Kelopak'), findsOneWidget);
    expect(find.text('Roda Sabtu siap diputar'), findsOneWidget);
    await _finish(tester, state);
  });

  testWidgets('finding 31: a voucher\'s "Pakai" leaves the reward screens, so '
      'the music stops', (tester) async {
    _usePhone(tester);
    _disableAnimations(tester);
    final sound = CountingSoundService();
    final state = await createTestAppState(sound: sound);
    state
      ..claimCheckIn()
      ..addToCart(_skintific);
    state.markOrderReceived(_place(state).id);
    expect(state.activeVouchers, hasLength(1));
    await _pumpApp(tester, state);
    expect(sound.holders, 0);

    await _tapTab(tester, 'Hadiah');
    expect(sound.holders, 1);
    await _tap(tester, find.text('Lihat misi'));
    expect(sound.holders, 2);
    await _tap(tester, find.text('Pakai'));
    expect(find.byType(CartPage), findsOneWidget);
    expect(sound.holders, 0);
    expect(
      ShellScope.of(tester.element(find.byType(CartPage))).currentTab,
      ShellTab.home,
    );
    await _pop(tester);

    await _tapTab(tester, 'Hadiah');
    await _tap(tester, find.text('Buka Hadiahku'));
    expect(find.byType(MyRewardsPage), findsOneWidget);
    await _tap(tester, find.text('Pakai'));
    expect(find.byType(CartPage), findsOneWidget);
    expect(sound.holders, 0);
    await _finish(tester, state);
  });

  group('finding 32: device clock moved back', () {
    testWidgets('check-in copy names the real next date', (tester) async {
      _usePhone(tester);
      _disableAnimations(tester);
      final clock = FakeClock(wibInstant(2026, 11, 30));
      final state = await createTestAppState(now: clock.now);
      state.claimCheckIn();
      clock.current = wibInstant(2026, 11, 25);
      await _pumpApp(tester, state);

      expect(find.textContaining('Kembali besok'), findsNothing);
      expect(
        find.text(
          'Check-in berikutnya 1 Des mulai 00.00 WIB untuk Hari ke-2 '
          '(tanggal perangkat berubah)',
        ),
        findsOneWidget,
      );
      await _push(tester, const CheckInPage());
      expect(find.textContaining('Kembali besok'), findsNothing);
      expect(find.textContaining('Sampai besok'), findsNothing);
      expect(
        find.text(
          'Check-in berikutnya 1 Des mulai 00.00 WIB '
          '(tanggal perangkat berubah).',
        ),
        findsOneWidget,
      );
      await _finish(tester, state);
    });

    testWidgets('wheel copy names the recorded spin and the real next '
        'Saturday', (tester) async {
      _usePhone(tester);
      _disableAnimations(tester);
      final clock = FakeClock(wibInstant(2026, 11, 28));
      final state = await createTestAppState(
        now: clock.now,
        random: ScriptedRandom(<int>[5000, 3]),
      );
      state.spin();
      clock.current = wibInstant(2026, 11, 21);
      await _pumpApp(tester, state);
      await _push(tester, const WheelPage());

      expect(find.text('Sudah diputar Sabtu ini'), findsNothing);
      expect(find.text('Putaran Sabtu 28 Nov sudah tercatat'), findsOneWidget);
      expect(
        find.text('Putaran berikutnya Sabtu, 5 Des · 00.00 WIB, 14 hari lagi.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Putaran Sabtu 28 Nov sudah tercatat. Sampai jumpa Sabtu, 5 Des.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Sabtu, 28 Nov · 00.00 WIB'), findsNothing);
      await _finish(tester, state);
    });
  });

  testWidgets('finding 3: Hadiah claims today in one tap', (tester) async {
    _usePhone(tester);
    _disableAnimations(tester);
    final state = await createTestAppState();
    await _pumpApp(tester, state);
    await _tapTab(tester, 'Hadiah');
    expect(find.text('Check-in sekarang'), findsNothing);
    await _tap(tester, find.widgetWithText(FilledButton, 'Ambil 1 Kelopak'));
    expect(state.balance, 1);
    expect(find.byType(CheckInPage), findsNothing);
    expect(find.text('Yay, Babes! +1 Kelopak masuk'), findsOneWidget);
    await _tap(tester, find.text('Oke'));
    await _tap(tester, find.text('Lihat progres'));
    expect(find.byType(CheckInPage), findsOneWidget);
    await _finish(tester, state);
  });

  testWidgets('cushion order of Rp100.000+ keeps working with the new '
      'mission copy', (tester) async {
    _usePhone(tester);
    final state = await createTestAppState();
    state.addToCart(_cushion);
    await _pumpApp(tester, state);
    await _push(tester, const CartPage());
    expect(
      find.text(
        'Pesanan ini memenuhi syarat Misi Belanja tahap 1 setelah diterima',
      ),
      findsOneWidget,
    );
    await _finish(tester, state);
  });
}
