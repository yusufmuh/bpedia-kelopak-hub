import 'dart:async';
import 'dart:ui' show CheckedState, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelopak_hub/app.dart';
import 'package:kelopak_hub/data/catalog.dart';
import 'package:kelopak_hub/domain/app_state.dart';
import 'package:kelopak_hub/domain/shop_engine.dart';
import 'package:kelopak_hub/ui/account/terms_page.dart';
import 'package:kelopak_hub/ui/home/game_tiles.dart';
import 'package:kelopak_hub/ui/orders/order_detail_page.dart';
import 'package:kelopak_hub/ui/rewards/checkin_page.dart';
import 'package:kelopak_hub/ui/rewards/ledger_page.dart';
import 'package:kelopak_hub/ui/rewards/missions_page.dart';
import 'package:kelopak_hub/ui/rewards/my_rewards_page.dart';
import 'package:kelopak_hub/ui/rewards/wheel_page.dart';
import 'package:kelopak_hub/ui/shop/cart_page.dart';
import 'package:kelopak_hub/ui/shop/checkout_page.dart';
import 'package:kelopak_hub/ui/shop/product_page.dart';
import 'package:kelopak_hub/ui/widgets/widgets.dart';

import '../support/test_app_state.dart';

const String _skintific = 'skintific-matte-fit-serum-spf50';
const String _soap = 'animate-brightening-soap-80g';
const String _cushion = 'somethinc-copy-paste-cushion-nina';
const String _shampoo = 'satto-millenium-black-tonic-shampoo-200ml';

Future<void> _loadBrandFonts() async {
  final poppins = FontLoader('Poppins');
  for (final weight in <int>[400, 500, 600, 700, 800]) {
    poppins.addFont(rootBundle.load('assets/fonts/Poppins-$weight.ttf'));
  }
  await poppins.load();
}

void _useScreen(WidgetTester tester, double width, double height) {
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

Future<void> _push(WidgetTester tester, Widget page) async {
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
  unawaited(
    navigator.push<void>(MaterialPageRoute<void>(builder: (context) => page)),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

String _name(String productId) => productById(productId)!.name;

Order _place(AppState state) {
  final result = state.placeOrder(state.quote());
  expect(result, isA<OrderPlaced>());
  return (result as OrderPlaced).order;
}

SemanticsNode _single(SemanticsFinder finder) => finder.evaluate().single;

bool _hasTap(SemanticsNode node) =>
    node.getSemanticsData().hasAction(SemanticsAction.tap);

Matcher _labelled(bool Function(String label) test, String description) =>
    predicate<SemanticsNode>((node) => test(node.label), description);

/// Presses Tab until [done] or [limit] presses; returns how many were needed.
Future<int> _tabUntil(
  WidgetTester tester,
  bool Function() done, {
  int limit = 120,
}) async {
  for (var press = 1; press <= limit; press++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    if (done()) return press;
  }
  return -1;
}

void main() {
  setUpAll(_loadBrandFonts);

  testWidgets('finding 15: checkout reads as separate items, the voucher row '
      'is one button', (tester) async {
    _useScreen(tester, 412, 2600);
    final semantics = tester.ensureSemantics();
    final state = await createTestAppState();
    state
      ..addToCart(_skintific)
      ..addToCart(_soap);
    await _pumpApp(tester, state);
    await _push(tester, const CheckoutPage());

    final voucher = _single(find.semantics.byHint('Pilih voucher'));
    expect(
      voucher.label,
      'Voucher, Belum ada voucher. Dapatkan dari Misi Belanja.',
    );
    expect(_hasTap(voucher), isTrue);
    expect(voucher.getSemanticsData().flagsCollection.isButton, isTrue);
    expect(voucher.rect.height, lessThan(200));

    final address = _single(
      find.semantics.byLabel(RegExp('^Alamat pengiriman')),
    );
    expect(_hasTap(address), isFalse);
    expect(
      address.label,
      'Alamat pengiriman: Pengguna Demo, Alamat demo, '
      'Jakarta',
    );

    expect(
      tester.semantics.simulatedAccessibilityTraversal(),
      containsAllInOrder(<Matcher>[
        isSemantics(
          label:
              'Alamat pengiriman: Pengguna Demo, Alamat demo, '
              'Jakarta',
        ),
        isSemantics(label: 'Rincian harga', isHeader: true),
        _labelled((label) => label.startsWith('Subtotal'), 'Subtotal row'),
        _labelled((label) => label.startsWith('Total bayar'), 'Total row'),
      ]),
    );
    final names = <String>[_name(_skintific), _name(_soap)];
    for (final node in tester.semantics.simulatedAccessibilityTraversal()) {
      final count = names.where(node.label.contains).length;
      expect(count, lessThanOrEqualTo(1), reason: node.label);
    }
    semantics.dispose();
    await _finish(tester, state);
  });

  testWidgets('finding 15: product and order detail are not one big button', (
    tester,
  ) async {
    _useScreen(tester, 412, 2600);
    final semantics = tester.ensureSemantics();
    final state = await createTestAppState();
    state.addToCart(_skintific);
    final order = _place(state);
    await _pumpApp(tester, state);

    await _push(tester, const ProductPage(productId: _skintific));
    final mission = _single(find.semantics.byHint('Buka Misi Belanja'));
    expect(
      mission.label,
      'Misi Belanja tahap 1. Selesaikan pesanan min. Rp75.000, dapat voucher '
      'Rp10.000',
    );
    expect(mission.rect.height, lessThan(200));
    for (final node in tester.semantics.simulatedAccessibilityTraversal()) {
      final flags = node.getSemanticsData().flagsCollection;
      if (flags.isHeader) {
        expect(node.label.contains('Harga'), isFalse, reason: node.label);
      }
    }
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();

    await _push(tester, OrderDetailPage(orderId: order.id));
    final line = _single(find.semantics.byHint('Lihat produk'));
    expect(line.label, '${_name(_skintific)}, 1 barang, Rp78.795');
    expect(line.rect.height, lessThan(200));
    expect(_hasTap(line), isTrue);
    semantics.dispose();
    await _finish(tester, state);
  });

  testWidgets('finding 16: Tab focus reaches the game tiles and screen '
      'readers see it', (tester) async {
    _useScreen(tester, 412, 915);
    final semantics = tester.ensureSemantics();
    final state = await createTestAppState();
    await _pumpApp(tester, state);

    final tile = find.semantics.byLabel('Check-in Harian, Siap diambil');
    final presses = await _tabUntil(tester, () {
      final nodes = tile.evaluate();
      return nodes.isNotEmpty &&
          nodes.single.getSemanticsData().flagsCollection.isFocused ==
              Tristate.isTrue;
    }, limit: 20);
    expect(presses, greaterThan(0), reason: 'the tile never got focus');
    final node = _single(tile);
    expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
    expect(_hasTap(node), isTrue);
    expect(
      node.getSemanticsData().flagsCollection.isFocused,
      isNot(Tristate.none),
    );
    final focused = FocusManager.instance.primaryFocus!.context!;
    expect(focused.findAncestorWidgetOfExactType<GameTiles>(), isNotNull);

    // Finding 28: the focused tile shows a 2 dp Berry outline.
    final scheme = Theme.of(focused).colorScheme;
    final material = focused.findAncestorWidgetOfExactType<Material>()!;
    final side = (material.shape! as RoundedRectangleBorder).side;
    expect(side.color, scheme.secondary);
    expect(side.width, 2);
    semantics.dispose();
    await _finish(tester, state);
  });

  testWidgets('finding 18: the navigation bar comes after the page, all four '
      'together', (tester) async {
    _useScreen(tester, 412, 915);
    final state = await createTestAppState();
    await _pumpApp(tester, state);

    final visited = <String>[];
    for (var press = 0; press < 160; press++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final context = FocusManager.instance.primaryFocus?.context;
      final destination = context
          ?.findAncestorWidgetOfExactType<NavigationDestination>();
      visited.add(destination == null ? 'page' : 'nav:${destination.label}');
    }
    final firstNav = visited.indexWhere((entry) => entry.startsWith('nav:'));
    expect(firstNav, greaterThan(30), reason: 'nav reached too early');
    expect(visited.sublist(firstNav, firstNav + 4), <String>[
      'nav:Beranda',
      'nav:Hadiah',
      'nav:Transaksi',
      'nav:Akun',
    ]);
    // Every visit to the bar is one unbroken run of all four tabs.
    var run = 0;
    for (var index = 0; index < visited.length; index++) {
      if (visited[index].startsWith('nav:')) {
        run++;
      } else {
        expect(run == 0 || run == 4, isTrue, reason: 'interleaved at $index');
        run = 0;
      }
    }
    await _finish(tester, state);
  });

  testWidgets('finding 19: "+ Keranjang" is a sibling of the product button, '
      'not inside it', (tester) async {
    _useScreen(tester, 412, 915);
    final semantics = tester.ensureSemantics();
    final state = await createTestAppState();
    await _pumpApp(tester, state);
    final product = demoCatalog.firstWhere((item) => !item.isHot);
    final add = find.semantics.byLabel('Tambah ${product.name} ke keranjang');
    await tester.scrollUntilVisible(
      find.text(product.name),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final addNode = add.evaluate().first;
    expect(_hasTap(addNode), isTrue);
    expect(_hasTap(addNode.parent!), isFalse);
    final card = find.semantics.byLabel(
      RegExp('^${RegExp.escape(product.name)}, Rp'),
    );
    final cardNode = card.evaluate().first;
    expect(_hasTap(cardNode), isTrue);
    expect(
      cardNode.getSemanticsData().flagsCollection.isFocused,
      isNot(Tristate.none),
    );
    expect(identical(cardNode.parent, addNode.parent), isTrue);
    semantics.dispose();
    await _finish(tester, state);
  });

  testWidgets('finding 20: "Suara & getar" is only its own row', (
    tester,
  ) async {
    _useScreen(tester, 412, 915);
    final semantics = tester.ensureSemantics();
    final state = await createTestAppState();
    await _pumpApp(tester, state);
    await _tapTab(tester, 'Akun');
    final sound = _single(find.semantics.byLabel(RegExp('^Suara & getar')));
    expect(sound.label.contains('Tampilan'), isFalse);
    expect(_hasTap(sound), isTrue);
    expect(sound.childrenCount, 0);
    final appearance = _single(find.semantics.byLabel(RegExp('^Tampilan')));
    expect(appearance.label, contains('Pilih tema terang, gelap, atau ikuti'));
    expect(_hasTap(appearance), isFalse);
    semantics.dispose();
    await _finish(tester, state);
  });

  testWidgets('finding 21: Check-in, Roda Sabtu and Keranjang read in page '
      'order', (tester) async {
    _useScreen(tester, 412, 2600);
    _disableAnimations(tester);
    final semantics = tester.ensureSemantics();
    final state = await createTestAppState(now: () => wibInstant(2026, 11, 28));
    state
      ..addToCart(_skintific)
      ..addToCart(_soap);
    await _pumpApp(tester, state);

    await _push(tester, const CheckInPage());
    expect(
      tester.semantics.simulatedAccessibilityTraversal(),
      containsAllInOrder(<Matcher>[
        isSemantics(label: 'Mulai rentetan baru hari ini', isHeader: true),
        isSemantics(
          label: 'Ambil 1 Kelopak hari ini, tulip pertamamu langsung mekar.',
        ),
        _labelled((label) => label.startsWith('Saldo kamu'), 'saldo'),
        isSemantics(label: 'Rentetan 7 hari', isHeader: true),
        _labelled(
          (label) => label.startsWith('Tiap check-in, satu tulip mekar.'),
          'week description',
        ),
        _labelled((label) => label.startsWith('Hari 1,'), 'day 1 slot'),
        _labelled((label) => label.startsWith('Hari 7,'), 'day 7 slot'),
        _labelled((label) => label.contains('Ambil 1 Kelopak'), 'claim'),
        isSemantics(
          label: 'Check-in 30 hari lagi tanpa bolong untuk 1 produk gratis.',
        ),
      ]),
    );
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();

    await _push(tester, const WheelPage());
    expect(
      tester.semantics.simulatedAccessibilityTraversal(),
      containsAllInOrder(<Matcher>[
        _labelled((label) => label.startsWith('Siap diputar'), 'status'),
        isSemantics(label: 'Roda Sabtu', value: 'Siap diputar'),
        isSemantics(label: 'Peluang & ketentuan', isHeader: true),
        _labelled((label) => label.startsWith('Produk gratis'), 'odds row'),
        isSemantics(
          label: 'Hasil ditentukan sistem secara acak sesuai peluang di atas.',
        ),
        isSemantics(label: 'Peluang: Produk gratis 10% · 3 Kelopak 90%'),
        _labelled((label) => label == 'Putar gratis', 'spin button'),
      ]),
    );
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();

    await _push(tester, const CartPage());
    final soapLine = _single(
      find.semantics.byLabel(RegExp('^${RegExp.escape(_name(_soap))}')),
    );
    expect(soapLine.label, contains('Harga Rp'));
    expect(soapLine.label.contains(_name(_skintific)), isFalse);
    expect(soapLine.childrenCount, greaterThanOrEqualTo(3));
    semantics.dispose();
    await _finish(tester, state);
  });

  testWidgets('finding 24: Beranda categories are plain buttons named once', (
    tester,
  ) async {
    _useScreen(tester, 412, 915);
    final semantics = tester.ensureSemantics();
    final state = await createTestAppState();
    await _pumpApp(tester, state);
    await tester.scrollUntilVisible(
      find.text('Kategori'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    final skincare = _single(find.semantics.byLabel('Skincare'));
    final flags = skincare.getSemanticsData().flagsCollection;
    expect(flags.isButton, isTrue);
    expect(flags.isChecked, CheckedState.none);
    expect(_hasTap(skincare), isTrue);
    expect(find.byTooltip('Lihat Skincare'), findsNothing);
    expect(find.byType(ActionChip), findsNothing);
    semantics.dispose();
    await _finish(tester, state);
  });

  testWidgets('finding 25: full product names at 200% text on 360 dp', (
    tester,
  ) async {
    _useScreen(tester, 360, 740);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final state = await createTestAppState();
    state.addToCart(_cushion);
    final order = _place(state);
    state
      ..addToCart(_cushion)
      ..addToCart(_shampoo);
    await _pumpApp(tester, state);

    void expectWhole(String name) {
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text(name).first,
      );
      expect(paragraph.maxLines, isNull, reason: name);
      expect(paragraph.didExceedMaxLines, isFalse, reason: name);
    }

    await _push(tester, const CartPage());
    expectWhole(_name(_cushion));
    expectWhole(_name(_shampoo));
    await _push(tester, const CheckoutPage());
    expectWhole(_name(_cushion));
    expectWhole(_name(_shampoo));
    tester.state<NavigatorState>(find.byType(Navigator).first)
      ..pop()
      ..pop();
    await tester.pumpAndSettle();
    await _tapTab(tester, 'Transaksi');
    expect(order.lines.single.name, _name(_cushion));
    expectWhole(_name(_cushion));
    await _finish(tester, state);
  });

  for (final width in <double>[360, 320]) {
    testWidgets('finding 27: page titles are never cut off at 200% text '
        '($width dp)', (tester) async {
      _useScreen(tester, width, 740);
      _disableAnimations(tester);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final state = await createTestAppState();
      await _pumpApp(tester, state);
      final pages = <String, Widget>{
        'Check-in Harian': const CheckInPage(),
        'Riwayat Kelopak': const LedgerPage(),
        'Roda Sabtu': const WheelPage(),
        'Misi Belanja': const MissionsPage(),
        'Hadiahku': const MyRewardsPage(),
        'Syarat & Ketentuan': const TermsPage(),
      };
      for (final entry in pages.entries) {
        await _push(tester, entry.value);
        final title = find.descendant(
          of: find.byType(AppBar),
          matching: find.text(entry.key),
        );
        final paragraph = tester.renderObject<RenderParagraph>(title);
        expect(paragraph.didExceedMaxLines, isFalse, reason: entry.key);
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.byType(DemoChip),
          ),
          findsNothing,
          reason: '${entry.key}: the DEMO chip moves into the page',
        );
        expect(tester.takeException(), isNull, reason: entry.key);
        tester.state<NavigatorState>(find.byType(Navigator).first).pop();
        await tester.pumpAndSettle();
      }
      await _finish(tester, state);
    });
  }

  testWidgets('finding 28: a focused product card gets a Berry outline', (
    tester,
  ) async {
    _useScreen(tester, 412, 915);
    final state = await createTestAppState();
    await _pumpApp(tester, state);
    final presses = await _tabUntil(tester, () {
      final context = FocusManager.instance.primaryFocus?.context;
      return context?.findAncestorWidgetOfExactType<ProductCard>() != null &&
          context?.findAncestorWidgetOfExactType<OutlinedButton>() == null;
    });
    expect(presses, greaterThan(0));
    final focused = FocusManager.instance.primaryFocus!.context!;
    final cardElement = focused.findAncestorStateOfType<State<ProductCard>>()!;
    final card = tester.widget<Card>(
      find.descendant(
        of: find.byWidget(cardElement.widget),
        matching: find.byType(Card),
      ),
    );
    final side = (card.shape! as RoundedRectangleBorder).side;
    final scheme = Theme.of(focused).colorScheme;
    expect(side.color, scheme.secondary);
    expect(side.width, 2);
    expect(
      Theme.of(focused).focusColor,
      scheme.secondary.withValues(alpha: 0.16),
    );
    await _finish(tester, state);
  });
}
