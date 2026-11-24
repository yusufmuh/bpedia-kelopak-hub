import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelopak_hub/app.dart';
import 'package:kelopak_hub/data/catalog.dart';
import 'package:kelopak_hub/domain/app_state.dart';
import 'package:kelopak_hub/domain/shop_engine.dart';
import 'package:kelopak_hub/ui/home/home_page.dart';
import 'package:kelopak_hub/ui/orders/order_detail_page.dart';
import 'package:kelopak_hub/ui/shop/cart_page.dart';
import 'package:kelopak_hub/ui/shop/checkout_page.dart';
import 'package:kelopak_hub/ui/shop/order_success_page.dart';
import 'package:kelopak_hub/ui/shop/product_page.dart';
import 'package:kelopak_hub/ui/shop/search_page.dart';
import 'package:kelopak_hub/ui/widgets/widgets.dart';

import '../support/navigation.dart';
import '../support/test_app_state.dart';

const String _skintific = 'skintific-matte-fit-serum-spf50';
const String _soap = 'animate-brightening-soap-80g';
const String _acneSerum = 'animate-acne-care-serum-20ml';
const String _cushion = 'somethinc-copy-paste-cushion-nina';
const String _faceWash = 'wardah-face-wash-hydra-rose';

Future<void> _loadBrandFonts() async {
  final poppins = FontLoader('Poppins');
  for (final weight in <int>[400, 500, 600, 700, 800]) {
    poppins.addFont(rootBundle.load('assets/fonts/Poppins-$weight.ttf'));
  }
  await poppins.load();
}

/// A 360 x 740 dp phone.
void _usePhone(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(1080, 2220)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _pumpApp(WidgetTester tester, AppState state) async {
  await tester.pumpWidget(AppScope(notifier: state, child: const BpediaApp()));
  await tester.pumpAndSettle();
}

/// Unmounts the app before the state is disposed.
Future<void> _finish(WidgetTester tester, AppState state) async {
  await tester.pumpWidget(const SizedBox.shrink());
  state.dispose();
}

/// Scrolls every scrollable around [finder] so it sits mid-screen (clear of
/// pinned app bars), then settles.
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  final done = Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
  await done;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _reveal(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapText(WidgetTester tester, String text) =>
    _tap(tester, find.text(text));

Future<void> _push(WidgetTester tester, Widget page) async {
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
  unawaited(
    navigator.push<void>(MaterialPageRoute<void>(builder: (context) => page)),
  );
  await tester.pumpAndSettle();
}

/// Drags the page's main scroll view down to its end, building every part.
Future<void> _scrollThrough(WidgetTester tester) async {
  final scrollable = find.byType(Scrollable).first;
  for (var i = 0; i < 14; i++) {
    await tester.drag(scrollable, const Offset(0, -420), warnIfMissed: false);
    await tester.pumpAndSettle();
  }
}

Order _place(AppState state, CheckoutQuote quote) {
  final result = state.placeOrder(quote);
  expect(result, isA<OrderPlaced>());
  return (result as OrderPlaced).order;
}

void main() {
  setUpAll(_loadBrandFonts);

  testWidgets(
    'an order of min. Rp75.000 earns the voucher, which then follows its '
    'minimum spend at checkout',
    (tester) async {
      _usePhone(tester);
      final state = await createTestAppState();
      await _pumpApp(tester, state);

      // Beranda: today's Kelopak straight from the card.
      expect(find.text('Kelopak hari ini'), findsOneWidget);
      expect(find.text('Hari ke-1: +1 Kelopak'), findsOneWidget);
      await _tapText(tester, 'Ambil 1 Kelopak');
      expect(find.text('Yay, Babes! +1 Kelopak masuk'), findsOneWidget);
      await _tapText(tester, 'Oke');
      expect(state.balance, 1);
      expect(
        find.textContaining('Sudah check-in · Hari ke-1 beruntun'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Buka Sabtu, 28 Nov · 4 hari lagi'),
        findsOneWidget,
      );

      // Search, open the product, add it and jump to the cart.
      await _tapText(tester, 'Cari skincare, makeup, lashes…');
      expect(find.byType(SearchPage), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'skintific');
      await tester.pumpAndSettle();
      expect(find.text('1 produk'), findsOneWidget);
      await _tapText(tester, 'Skintific Matte Fit Serum SPF 50+++');
      expect(find.byType(ProductPage), findsOneWidget);
      expect(find.textContaining('Foto ilustrasi · Mode Demo'), findsOneWidget);
      expect(
        find.text('Selesaikan pesanan min. Rp75.000, dapat voucher Rp10.000'),
        findsOneWidget,
      );
      await _tapText(tester, 'Tambah ke keranjang');
      expect(find.text('Ditambahkan ke keranjang'), findsOneWidget);
      expect(state.quantityInCart(_skintific), 1);
      await _tapText(tester, 'Lihat');
      expect(find.byType(CartPage), findsOneWidget);
      expect(
        find.text(
          'Pesanan ini memenuhi syarat Misi Belanja tahap 1 setelah diterima',
        ),
        findsOneWidget,
      );

      // Back to Beranda and add a Hot Item from its card.
      await tester.tapBack();
      await tester.pumpAndSettle();
      await tester.tapBack();
      await tester.pumpAndSettle();
      await tester.tapBack();
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);
      final homeScroll = find
          .descendant(
            of: find.byType(HomePage),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Hot Item'),
        240,
        scrollable: homeScroll,
      );
      await _tap(
        tester,
        find
            .descendant(
              of: find.byType(ProductCarousel),
              matching: find.text('Keranjang'),
            )
            .first,
      );
      expect(find.text('Ditambahkan ke keranjang'), findsOneWidget);
      expect(find.byTooltip('Keranjang, 2 barang'), findsOneWidget);
      await _tapText(tester, 'Lihat');
      expect(find.text('Keranjang (2)'), findsOneWidget);
      expect(find.text('Rp88.795'), findsOneWidget);

      // Checkout without voucher (none yet) and without Kelopak.
      await _tapText(tester, 'Checkout');
      expect(find.byType(CheckoutPage), findsOneWidget);
      expect(
        find.text('Belum ada voucher. Dapatkan dari Misi Belanja.'),
        findsOneWidget,
      );
      expect(find.text('Pakai 1 Kelopak · hemat Rp100'), findsOneWidget);
      expect(find.text('Gratis ongkir (Demo)'), findsOneWidget);
      await _tapText(tester, 'Bayar sekarang (simulasi)');

      expect(find.byType(OrderSuccessPage), findsOneWidget);
      expect(find.text('Pesanan dibuat'), findsOneWidget);
      expect(find.text('BP-20261124-0001'), findsOneWidget);
      expect(state.isCartEmpty, isTrue);
      expect(state.orders.single.status, OrderStatus.shipped);

      // Lihat pesanan: Transaksi tab with the order detail on top.
      await _tapText(tester, 'Lihat pesanan');
      expect(find.byType(OrderDetailPage), findsOneWidget);
      await _tapText(tester, 'Pesanan Diterima');
      expect(find.text('Pesanan sudah diterima?'), findsOneWidget);
      await _tapText(tester, 'Ya, sudah diterima');
      expect(find.text('Misi tahap 1 selesai!'), findsOneWidget);
      expect(
        find.text('Voucher Rp10.000 sudah masuk ke Hadiahku'),
        findsOneWidget,
      );
      expect(
        find.text('Berlaku untuk belanja berikutnya min. Rp100.000'),
        findsOneWidget,
      );
      await _tapText(tester, 'Oke');
      expect(state.orders.single.status, OrderStatus.completed);
      expect(state.vouchers, hasLength(1));
      expect(find.text('Pesanan Diterima'), findsNothing);
      expect(find.text('Selesai'), findsWidgets);

      // A cart below the voucher minimum: the voucher is shown but blocked.
      state.addToCart(_acneSerum);
      await tester.tapBack();
      await tester.pumpAndSettle();
      expect(find.text('Transaksi'), findsWidgets);
      await _tapText(tester, 'Beranda');
      await _tap(tester, find.byTooltip('Keranjang, 1 barang'));
      expect(
        find.text('Belanja Rp79.500 lagi untuk pakai voucher Rp10.000'),
        findsOneWidget,
      );
      await _tapText(tester, 'Checkout');
      expect(find.text('1 voucher belum bisa dipakai'), findsOneWidget);
      await _tapText(tester, '1 voucher belum bisa dipakai');
      expect(find.text('Pilih voucher'), findsOneWidget);
      final blocked = tester.widget<ListTile>(
        find.ancestor(
          of: find.text('Belanja Rp79.500 lagi'),
          matching: find.byType(ListTile),
        ),
      );
      expect(blocked.enabled, isFalse);
      await _tapText(tester, 'Tanpa voucher');
      expect(find.text('Pilih voucher'), findsNothing);
      expect(find.text('-Rp10.000'), findsNothing);
      expect(find.text('Rp20.500'), findsWidgets);

      // Min. Rp100.000: the voucher is applied automatically.
      await tester.tapBack();
      await tester.pumpAndSettle();
      state.addToCart(_cushion);
      await tester.pumpAndSettle();
      expect(find.text('Voucher Rp10.000 bisa dipakai'), findsOneWidget);
      await _tapText(tester, 'Checkout');
      expect(find.text('Voucher Rp10.000 dipakai'), findsOneWidget);
      expect(find.text('-Rp10.000'), findsOneWidget);
      expect(find.text('Rp143.010'), findsWidgets);
      await _tapText(tester, 'Pakai 1 Kelopak · hemat Rp100');
      expect(find.text('-Rp100'), findsOneWidget);
      expect(find.text('Rp142.910'), findsWidgets);
      await _tapText(tester, 'Bayar sekarang (simulasi)');

      expect(find.text('BP-20261124-0002'), findsOneWidget);
      final second = state.orders.first;
      expect(second.subtotal, 153010);
      expect(second.voucherDiscount, 10000);
      expect(second.kelopakUsed, 1);
      expect(second.total, 142910);
      expect(state.vouchers.single.isUsed, isTrue);
      expect(state.balance, 0);

      await _finish(tester, state);
    },
  );

  testWidgets('cart removal can be undone and an empty search can be reset', (
    tester,
  ) async {
    _usePhone(tester);
    final state = await createTestAppState();
    state
      ..addToCart(_soap, qty: 2)
      ..addToCart(_faceWash);
    await _pumpApp(tester, state);

    await _push(tester, const CartPage());
    expect(find.text('Keranjang (3)'), findsOneWidget);
    expect(
      find.text(
        'Tambah Rp14.392 lagi agar pesanan ini ikut Misi Belanja '
        'tahap 1',
      ),
      findsOneWidget,
    );
    await _tap(tester, find.byTooltip('Hapus dari keranjang').first);
    expect(find.text('Produk dihapus dari keranjang'), findsOneWidget);
    expect(state.cartItems, hasLength(1));
    await _tapText(tester, 'Urungkan');
    expect(state.cartItems.map((item) => item.product.id), <String>[
      _soap,
      _faceWash,
    ]);

    await _tap(tester, find.byTooltip('Hapus dari keranjang').first);
    await _tap(tester, find.byTooltip('Hapus dari keranjang').first);
    expect(find.text('Keranjangmu masih kosong'), findsOneWidget);
    await _tapText(tester, 'Mulai belanja');
    expect(find.byType(CartPage), findsNothing);
    expect(find.byType(HomePage), findsOneWidget);

    await _push(tester, const SearchPage());
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Produk tidak ditemukan'), findsOneWidget);
    await _tapText(tester, 'Reset pencarian');
    expect(find.text('19 produk'), findsOneWidget);

    await _push(tester, const ProductPage(productId: 'tidak-ada'));
    expect(find.text('Produk tidak ditemukan'), findsOneWidget);
    await _push(tester, const OrderDetailPage(orderId: 'BP-00000000-0000'));
    expect(find.text('Pesanan tidak ditemukan'), findsOneWidget);

    await _finish(tester, state);
  });

  testWidgets('day 7 claimed from Beranda with reduced motion shows the '
      'bonus', (tester) async {
    _usePhone(tester);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final clock = FakeClock(defaultTestNow);
    final state = await createTestAppState(now: clock.now);
    for (var day = 1; day <= 6; day++) {
      state.claimCheckIn();
      clock.advance(const Duration(days: 1));
    }
    await _pumpApp(tester, state);

    expect(
      find.text('Hari ke-7: +1 Kelopak + bonus 3 Kelopak'),
      findsOneWidget,
    );
    await _tapText(tester, 'Ambil 1 Kelopak');
    expect(find.text('Yay, Babes! Bonus 7 hari beruntun'), findsOneWidget);
    expect(find.text('+1 Kelopak + bonus 3 Kelopak'), findsOneWidget);
    expect(find.text('Saldo sekarang 10 Kelopak (Rp1.000)'), findsOneWidget);
    await _tap(
      tester,
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Lihat hadiah'),
      ),
    );
    expect(state.balance, 10);
    expect(find.byType(HomePage), findsNothing);

    await _finish(tester, state);
  });

  testWidgets('shop screens meet the tap target, label and contrast '
      'guidelines in light and dark', (tester) async {
    tester.view
      ..physicalSize = const Size(360, 740)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final semantics = tester.ensureSemantics();
    final state = await createTestAppState();
    state
      ..addToCart(_skintific)
      ..addToCart(_soap, qty: 2);
    final completed = _place(state, state.quote());
    state.markOrderReceived(completed.id);
    state.addToCart(_cushion);
    final shipped = _place(state, state.quote());
    state.addToCart(_faceWash);
    await _pumpApp(tester, state);

    Future<void> expectGuidelines() async {
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    }

    for (final brightness in Brightness.values) {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      await tester.pumpAndSettle();
      await expectGuidelines();
      for (final page in <Widget>[
        const SearchPage(category: ProductCategory.skincare),
        const ProductPage(productId: _skintific),
        const CartPage(),
        const CheckoutPage(),
        OrderSuccessPage(orderId: shipped.id),
        OrderDetailPage(orderId: shipped.id),
        OrderDetailPage(orderId: completed.id),
      ]) {
        await _push(tester, page);
        await expectGuidelines();
        tester.state<NavigatorState>(find.byType(Navigator).first).pop();
        await tester.pumpAndSettle();
      }
      await _tap(
        tester,
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Transaksi'),
        ),
      );
      await expectGuidelines();
      await _tap(
        tester,
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Beranda'),
        ),
      );
    }

    semantics.dispose();
    await _finish(tester, state);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'shop screens fit 360 x 740 at 200% text (${brightness.name})',
      (tester) async {
        _usePhone(tester);
        tester.platformDispatcher
          ..textScaleFactorTestValue = 2
          ..platformBrightnessTestValue = brightness;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

        final state = await createTestAppState();
        state
          ..claimCheckIn()
          ..addToCart(_skintific)
          ..addToCart(_soap, qty: 2);
        final completed = _place(state, state.quote());
        state.markOrderReceived(completed.id);
        state.addToCart(_cushion);
        final shipped = _place(
          state,
          state.quote(voucherId: state.vouchers.single.id, useKelopak: true),
        );
        state
          ..addToCart(_faceWash)
          ..addToCart(_acneSerum, qty: 3);
        await _pumpApp(tester, state);
        expect(
          Theme.of(tester.element(find.byType(HomePage))).brightness,
          brightness,
        );

        await _scrollThrough(tester);

        await _push(tester, const SearchPage());
        await _scrollThrough(tester);
        await tester.tapBack();
        await tester.pumpAndSettle();

        await _push(tester, const ProductPage(productId: _skintific));
        await _scrollThrough(tester);
        await tester.tapBack();
        await tester.pumpAndSettle();

        await _push(tester, const CartPage());
        await _scrollThrough(tester);
        await _tapText(tester, 'Checkout');
        await _scrollThrough(tester);
        await _tap(tester, find.text('Voucher'));
        expect(find.text('Pilih voucher'), findsOneWidget);
        Navigator.of(tester.element(find.text('Pilih voucher'))).pop();
        await tester.pumpAndSettle();
        await tester.tapBack();
        await tester.pumpAndSettle();
        await tester.tapBack();
        await tester.pumpAndSettle();

        await _tap(
          tester,
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Transaksi'),
          ),
        );
        await _scrollThrough(tester);

        await _push(tester, OrderDetailPage(orderId: shipped.id));
        await _scrollThrough(tester);
        await tester.tapBack();
        await tester.pumpAndSettle();
        await _push(tester, OrderDetailPage(orderId: completed.id));
        await _scrollThrough(tester);
        await tester.tapBack();
        await tester.pumpAndSettle();

        await _push(tester, OrderSuccessPage(orderId: shipped.id));
        await _scrollThrough(tester);

        await _finish(tester, state);
      },
    );
  }
}
