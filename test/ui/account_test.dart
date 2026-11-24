import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelopak_hub/app.dart';
import 'package:kelopak_hub/core/config.dart';
import 'package:kelopak_hub/core/format.dart';
import 'package:kelopak_hub/core/theme.dart';
import 'package:kelopak_hub/data/catalog.dart';
import 'package:kelopak_hub/data/key_value_store.dart';
import 'package:kelopak_hub/data/persistence.dart';
import 'package:kelopak_hub/domain/app_state.dart';
import 'package:kelopak_hub/ui/account/about_page.dart';
import 'package:kelopak_hub/ui/account/account_page.dart';
import 'package:kelopak_hub/ui/account/demo_tools_page.dart';
import 'package:kelopak_hub/ui/account/sound_settings_page.dart';
import 'package:kelopak_hub/ui/account/terms_page.dart';
import 'package:kelopak_hub/ui/rewards/ledger_page.dart';
import 'package:kelopak_hub/ui/rewards/my_rewards_page.dart';
import 'package:kelopak_hub/ui/shell.dart';

import '../support/navigation.dart';
import '../support/test_app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadBrandFonts);

  testWidgets('Efek suara switch is saved in the app settings', (tester) async {
    final store = MemoryKeyValueStore();
    final state = await createTestAppState(store: store);
    addTearDown(state.dispose);
    await tester.pumpWidget(_TestApp(state: state));

    await _openRow(tester, 'Suara & getar');
    expect(find.byType(SoundSettingsPage), findsOneWidget);
    expect(state.settings.sfxEnabled, isTrue);

    await tester.tap(find.widgetWithText(SwitchListTile, 'Efek suara'));
    await tester.pumpAndSettle();
    expect(state.settings.sfxEnabled, isFalse);
    expect(state.sound.sfxEnabled, isFalse);

    await state.flush();
    final saved = await AppSnapshot.load(store);
    expect(saved.settings.sfxEnabled, isFalse);
    expect(saved.settings.musicEnabled, isFalse);
    expect(saved.settings.hapticsEnabled, isTrue);

    await tester.tap(find.widgetWithText(SwitchListTile, 'Efek suara'));
    await tester.pumpAndSettle();
    expect(state.settings.sfxEnabled, isTrue);
  });

  testWidgets('Musik latar and Getar switches update the settings', (
    tester,
  ) async {
    final state = await createTestAppState();
    addTearDown(state.dispose);
    await tester.pumpWidget(
      _TestApp(state: state, home: const SoundSettingsPage()),
    );

    await tester.tap(find.widgetWithText(SwitchListTile, 'Musik latar'));
    await tester.pumpAndSettle();
    expect(state.settings.musicEnabled, isTrue);
    expect(state.sound.musicEnabled, isTrue);

    await tester.tap(find.widgetWithText(SwitchListTile, 'Getar'));
    await tester.pumpAndSettle();
    expect(state.settings.hapticsEnabled, isFalse);
    expect(state.haptics.enabled, isFalse);
  });

  testWidgets('Tampilan switches the app theme', (tester) async {
    final state = await createTestAppState();
    addTearDown(state.dispose);
    await tester.pumpWidget(_TestApp(state: state));
    expect(state.settings.themeMode, ThemeMode.system);

    final dark = find.text('Gelap');
    await _scrollTo(tester, dark);
    await tester.tap(dark);
    await tester.pumpAndSettle();

    expect(state.settings.themeMode, ThemeMode.dark);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(
      Theme.of(tester.element(find.byType(AccountPage))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('Mode Demo "+1 hari" and "+7 hari" move the simulated date', (
    tester,
  ) async {
    final state = await createTestAppState();
    addTearDown(state.dispose);
    final start = state.today;
    await tester.pumpWidget(_TestApp(state: state));

    await _openRow(tester, 'Mode Demo (QA)');
    expect(find.byType(DemoToolsPage), findsOneWidget);
    expect(find.text(wibDateLabel(start)), findsOneWidget);

    await tester.tap(find.text('+1 hari'));
    await tester.pumpAndSettle();
    expect(state.today, start + 1);
    expect(state.demoOffsetDays, 1);
    expect(find.text(wibDateLabel(start + 1)), findsOneWidget);
    expect(
      find.text('Tanggal simulasi maju 1 hari: ${wibDateLabel(start + 1)}.'),
      findsOneWidget,
    );

    await tester.tap(find.text('+7 hari'));
    await tester.pumpAndSettle();
    expect(state.today, start + 8);
    expect(state.demoOffsetDays, 8);
  });

  testWidgets('Mode Demo jumps to Saturday and controls the wheel promo', (
    tester,
  ) async {
    final state = await createTestAppState();
    addTearDown(state.dispose);
    await tester.pumpWidget(
      _TestApp(state: state, home: const DemoToolsPage()),
    );

    await tester.tap(find.text('Lompat ke Sabtu berikutnya'));
    await tester.pumpAndSettle();
    expect(state.isSaturday, isTrue);
    expect(state.canSpin, isTrue);
    expect(
      find.text(
        'Sekarang ${wibDateLabel(state.today)}. Roda Sabtu siap diputar.',
      ),
      findsOneWidget,
    );

    final promo = find.widgetWithText(SwitchListTile, 'Promo Roda Sabtu aktif');
    await tester.ensureVisible(promo);
    await tester.pumpAndSettle();
    await tester.tap(promo);
    await tester.pumpAndSettle();
    expect(state.promoActive, isFalse);
    expect(state.canSpin, isFalse);

    final refill = find.widgetWithText(
      OutlinedButton,
      'Isi ulang stok produk roda',
    );
    expect(tester.widget<OutlinedButton>(refill).onPressed, isNull);
  });

  testWidgets('Reset semua data clears Kelopak and orders after confirming', (
    tester,
  ) async {
    final state = await createTestAppState();
    addTearDown(state.dispose);
    state.claimCheckIn();
    state.addToCart(demoCatalog.first.id);
    expect(state.placeOrder(state.quote()), isA<OrderPlaced>());
    state.advanceDays(2);
    expect(state.balance, 1);
    expect(state.orders, hasLength(1));

    await tester.pumpWidget(_TestApp(state: state));
    await _openRow(tester, 'Mode Demo (QA)');

    final reset = find.text('Reset semua data');
    await _scrollTo(tester, reset);
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(find.text('Reset semua data?'), findsOneWidget);

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(state.balance, 1);
    expect(state.orders, hasLength(1));

    await tester.tap(reset);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset data'));
    await tester.pumpAndSettle();

    expect(state.balance, 0);
    expect(state.ledger, isEmpty);
    expect(state.orders, isEmpty);
    expect(state.isCartEmpty, isTrue);
    expect(state.demoOffsetDays, 0);
    expect(
      find.text('Semua data demo dihapus. Kamu mulai lagi dari awal.'),
      findsOneWidget,
    );
  });

  testWidgets('Hadiahku and Riwayat Kelopak open the reward pages', (
    tester,
  ) async {
    final state = await createTestAppState();
    addTearDown(state.dispose);
    await tester.pumpWidget(_TestApp(state: state));

    await _openRow(tester, 'Hadiahku');
    expect(find.byType(MyRewardsPage), findsOneWidget);
    await tester.tapBack();
    await tester.pumpAndSettle();

    await _openRow(tester, 'Riwayat Kelopak');
    expect(find.byType(LedgerPage), findsOneWidget);
  });

  testWidgets('Tentang shows the version and a hint when a link cannot open', (
    tester,
  ) async {
    final state = await createTestAppState();
    addTearDown(state.dispose);
    await tester.pumpWidget(_TestApp(state: state, home: const AboutPage()));

    expect(
      find.text('${AppConfig.appName} v${AppConfig.appVersion}'),
      findsOneWidget,
    );
    final web = find.text('Buka bpedia.id');
    await _scrollTo(tester, web);
    await tester.tap(web);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Tautan belum bisa dibuka. Buka bpedia.id lewat browser, ya.'),
      findsOneWidget,
    );
  });

  testWidgets('Syarat & Ketentuan follows the live wheel odds and stock', (
    tester,
  ) async {
    final state = await createTestAppState(random: ScriptedRandom(<int>[0]));
    addTearDown(state.dispose);
    await tester.pumpWidget(_TestApp(state: state, home: const TermsPage()));

    final odds = find.text(
      'Peluang saat ini: Produk gratis 10%, 3 Kelopak 90%.',
    );
    await _scrollTo(tester, odds);
    expect(odds, findsOneWidget);
    expect(find.text('Sisa kuota produk: 1.'), findsOneWidget);
    expect(
      find.text('Apple bukan sponsor dan tidak terlibat dalam promosi ini.'),
      findsOneWidget,
    );

    state
      ..jumpToNextSaturday()
      ..spin();
    await tester.pumpAndSettle();
    expect(state.productStock, 0);
    expect(
      find.text('Peluang saat ini: Produk gratis 0%, 3 Kelopak 100%.'),
      findsOneWidget,
    );
    expect(find.text('Sisa kuota produk: 0.'), findsOneWidget);
  });

  testWidgets('Akun pages meet the tap target, label and contrast guidelines', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(412, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    final state = await createTestAppState();
    addTearDown(state.dispose);

    for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      state.setThemeMode(mode);
      for (final page in _accountPages) {
        await tester.pumpWidget(
          _TestApp(key: UniqueKey(), state: state, home: page),
        );
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      }
    }
    semantics.dispose();
  });

  testWidgets('Akun pages fit 360x740 at 200% text in light and dark', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(360, 740)
      ..devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final state = await createTestAppState(random: ScriptedRandom(<int>[0]));
    addTearDown(state.dispose);
    state
      ..claimCheckIn()
      ..jumpToNextSaturday()
      ..spin()
      ..advanceDays(3);

    for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      state.setThemeMode(mode);
      for (final page in _accountPages) {
        await tester.pumpWidget(
          _TestApp(key: UniqueKey(), state: state, home: page),
        );
        await tester.pumpAndSettle();
        await _scrollThrough(tester);
        expect(tester.takeException(), isNull);
      }
    }

    final reset = find.text('Reset semua data');
    await tester.pumpWidget(
      _TestApp(key: UniqueKey(), state: state, home: const DemoToolsPage()),
    );
    await tester.pumpAndSettle();
    await _scrollTo(tester, reset);
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(find.text('Reset semua data?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

const List<Widget> _accountPages = <Widget>[
  AccountPage(),
  SoundSettingsPage(),
  DemoToolsPage(),
  TermsPage(),
  AboutPage(),
];

/// The app's themes and [ShellScope] around [home], like `BpediaApp`.
class _TestApp extends StatefulWidget {
  const _TestApp({
    super.key,
    required this.state,
    this.home = const AccountPage(),
  });

  final AppState state;
  final Widget home;

  @override
  State<_TestApp> createState() => _TestAppState();
}

class _TestAppState extends State<_TestApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final ShellController _shell = ShellController(ShellTab.account);

  @override
  void dispose() {
    _shell.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      notifier: widget.state,
      child: Builder(
        builder: (context) => MaterialApp(
          navigatorKey: _navigatorKey,
          locale: BpediaApp.locale,
          supportedLocales: BpediaApp.supportedLocales,
          localizationsDelegates: BpediaApp.localizationsDelegates,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: AppScope.of(context).settings.themeMode,
          home: widget.home,
          builder: (context, child) => ShellScope(
            controller: _shell,
            navigatorKey: _navigatorKey,
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 2,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _loadBrandFonts() async {
  final poppins = FontLoader('Poppins');
  for (final weight in <int>[400, 500, 600, 700, 800]) {
    poppins.addFont(rootBundle.load('assets/fonts/Poppins-$weight.ttf'));
  }
  await poppins.load();
  final fraunces = FontLoader('Fraunces')
    ..addFont(rootBundle.load('assets/fonts/Fraunces-Italic-Variable.ttf'));
  await fraunces.load();
}

/// Scrolls the page list until [finder] is built and visible.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

/// Scrolls [label]'s row into view on the Akun page and opens it.
Future<void> _openRow(WidgetTester tester, String label) async {
  final row = find.widgetWithText(ListTile, label);
  await _scrollTo(tester, row);
  await tester.tap(row);
  await tester.pumpAndSettle();
}

/// Drags the page list to its end so every row gets built and laid out.
Future<void> _scrollThrough(WidgetTester tester) async {
  final list = find.byType(Scrollable).first;
  for (var step = 0; step < 30; step++) {
    final position = tester.state<ScrollableState>(list).position;
    if (position.pixels >= position.maxScrollExtent) return;
    await tester.drag(list, const Offset(0, -400));
    await tester.pumpAndSettle();
  }
}
