import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelopak_hub/app.dart';
import 'package:kelopak_hub/core/theme.dart';
import 'package:kelopak_hub/domain/app_state.dart';
import 'package:kelopak_hub/ui/rewards/checkin_page.dart';
import 'package:kelopak_hub/ui/rewards/ledger_page.dart';
import 'package:kelopak_hub/ui/rewards/missions_page.dart';
import 'package:kelopak_hub/ui/rewards/my_rewards_page.dart';
import 'package:kelopak_hub/ui/rewards/rewards_hub_page.dart';
import 'package:kelopak_hub/ui/rewards/wheel_page.dart';
import 'package:kelopak_hub/ui/shell.dart';

import '../support/navigation.dart';
import '../support/test_app_state.dart';

void main() {
  testWidgets('Hadiah: check-in sampai hari ke-7, lalu putar Roda Sabtu', (
    tester,
  ) async {
    _usePhone(tester);
    final state = await createTestAppState(
      now: () => wibInstant(2026, 11, 23),
      random: ScriptedRandom(<int>[5000, 4242]),
    );

    await tester.pumpWidget(
      AppScope(notifier: state, child: const BpediaApp()),
    );
    await tester.pump();

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Hadiah'),
      ),
    );
    await _pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.byType(RewardsHubPage), findsOneWidget);
    expect(find.text('Siap diambil'), findsOneWidget);

    await tester.ensureVisible(find.text('Check-in sekarang'));
    await tester.pump();
    await tester.tap(find.text('Check-in sekarang'));
    await _pumpFor(tester, const Duration(milliseconds: 800));
    expect(find.byType(CheckInPage), findsOneWidget);
    expect(find.text('Mulai rentetan baru hari ini'), findsOneWidget);

    await _claimAndClose(tester, expectedLine: 'Hari ke-1 beruntun');
    expect(state.balance, 1);
    expect(
      _inPage<CheckInPage>(find.text('Sudah check-in hari ini')),
      findsOneWidget,
    );
    expect(_claimButton(tester).onPressed, isNull);

    for (var day = 2; day <= 7; day++) {
      state.advanceDays(1);
      await tester.pump();
      expect(_claimButton(tester).onPressed, isNotNull);
      await _claimAndClose(
        tester,
        expectedLine: day == 7
            ? 'Bonus 7 hari +3 Kelopak'
            : 'Hari ke-$day beruntun',
      );
    }
    expect(state.balance, 10);
    expect(state.liveStreak, 7);
    expect(find.text('Hari ke-7 beruntun'), findsOneWidget);

    await tester.tapBack();
    await _pumpFor(tester, const Duration(milliseconds: 800));
    expect(find.byType(RewardsHubPage), findsOneWidget);

    state.jumpToNextSaturday();
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpAndSettle();
    expect(find.text('Siap diputar'), findsOneWidget);

    await tester.ensureVisible(find.text('Lihat roda'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lihat roda'));
    await tester.pumpAndSettle();
    expect(find.byType(WheelPage), findsOneWidget);

    final spinButton = find.widgetWithText(FilledButton, 'Putar gratis');
    expect(tester.widget<FilledButton>(spinButton).onPressed, isNotNull);
    expect(find.text('Peluang & ketentuan'), findsOneWidget);
    await tester.ensureVisible(spinButton);
    await tester.pumpAndSettle();
    await tester.tap(spinButton);
    await tester.pumpAndSettle();

    expect(
      _inSheet(find.text('Yay, Babes! Kamu dapat 3 Kelopak')),
      findsOneWidget,
    );
    expect(_inSheet(find.text('Saldo: 13 Kelopak (Rp1.300)')), findsOneWidget);
    await tester.tap(_inSheet(find.text('Oke')));
    await tester.pumpAndSettle();

    expect(state.balance, 13);
    expect(find.text('Hasil Sabtu ini: 3 Kelopak'), findsOneWidget);
    expect(find.text('Sudah diputar Sabtu ini'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Putar gratis'),
          )
          .onPressed,
      isNull,
    );

    await tester.tapBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Lihat roda'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lihat roda'));
    await tester.pumpAndSettle();
    expect(find.text('Hasil Sabtu ini: 3 Kelopak'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('Roda Sabtu: hasil tidak bocor sebelum roda berhenti', (
    tester,
  ) async {
    _usePhone(tester);
    final state = await createTestAppState(
      now: () => wibInstant(2026, 11, 28),
      random: ScriptedRandom(<int>[0, 7]),
    );
    await tester.pumpWidget(_Harness(state: state, home: const WheelPage()));
    await _pumpFor(tester, const Duration(milliseconds: 300));

    final spinButton = find.widgetWithText(FilledButton, 'Putar gratis');
    await tester.ensureVisible(spinButton);
    await _pumpFor(tester, const Duration(milliseconds: 300));
    await tester.tap(spinButton);
    await _pumpFor(tester, const Duration(milliseconds: 500));

    expect(state.productStock, 0, reason: 'the prize is decided and saved');
    expect(find.text('Roda sedang berputar'), findsOneWidget);
    expect(find.textContaining('Hasil Sabtu ini'), findsNothing);
    expect(find.text('Sisa kuota: 1'), findsOneWidget);
    expect(find.text('Lewati animasi'), findsOneWidget);

    await tester.tap(find.text('Lewati animasi'));
    await _pumpFor(tester, const Duration(milliseconds: 1500));
    expect(
      _inSheet(find.text('Yay, Babes! Kamu dapat produk gratis')),
      findsOneWidget,
    );

    await tester.tap(_inSheet(find.text('Lihat Hadiahku')));
    await _pumpFor(tester, const Duration(milliseconds: 1000));
    expect(find.byType(MyRewardsPage), findsOneWidget);
    expect(find.text('1 produk gratis'), findsOneWidget);
    expect(find.text('Menunggu pengiriman (Demo)'), findsOneWidget);

    await tester.tapBack();
    await _pumpFor(tester, const Duration(milliseconds: 800));
    expect(find.text('Hasil Sabtu ini: Produk gratis'), findsOneWidget);
    expect(find.text('Kuota habis'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('Riwayat kosong mengajak check-in, lalu mencatat Kelopak', (
    tester,
  ) async {
    _usePhone(tester);
    final state = await createTestAppState();
    await tester.pumpWidget(_Harness(state: state, home: const LedgerPage()));
    await _pumpFor(tester, const Duration(milliseconds: 300));
    expect(find.text('Belum ada Kelopak'), findsOneWidget);

    await tester.tap(find.text('Ambil Kelopak pertamamu'));
    await _pumpFor(tester, const Duration(milliseconds: 800));
    await _claimAndClose(tester, expectedLine: 'Hari ke-1 beruntun');

    await tester.tapBack();
    await _pumpFor(tester, const Duration(milliseconds: 800));
    expect(find.text('Check-in hari ke-1'), findsOneWidget);
    expect(find.text('+1 Kelopak'), findsOneWidget);
    expect(find.text('Selasa, 24 Nov 2026'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('Misi Belanja: voucher terbit dan Belanja sekarang ke Beranda', (
    tester,
  ) async {
    _usePhone(tester);
    final state = await _richState();
    final shell = ShellController(ShellTab.rewards);
    addTearDown(shell.dispose);
    await tester.pumpWidget(
      _Harness(state: state, shell: shell, home: const MissionsPage()),
    );
    await _pumpFor(tester, const Duration(milliseconds: 300));

    expect(
      find.textContaining('1 pesanan Rp132.510 menunggu diterima'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Voucher saya'));
    await _pumpFor(tester, const Duration(milliseconds: 300));
    expect(find.text('Aktif'), findsWidgets);

    await tester.ensureVisible(find.text('Belanja sekarang'));
    await _pumpFor(tester, const Duration(milliseconds: 300));
    await tester.tap(find.text('Belanja sekarang'));
    await _pumpFor(tester, const Duration(milliseconds: 300));
    expect(shell.value, ShellTab.home);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  group('Tata letak 360 dp dengan teks 200%', () {
    final pages = <String, Widget>{
      'hub': const RewardsHubPage(),
      'check-in': const CheckInPage(),
      'roda': const WheelPage(),
      'misi': const MissionsPage(),
      'voucher': const MyRewardsPage(),
      'produk': const MyRewardsPage(initialTab: MyRewardsTab.products),
      'riwayat': const LedgerPage(),
    };
    for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      for (final rich in <bool>[false, true]) {
        final label = '${mode.name}, ${rich ? 'berisi data' : 'kosong'}';
        testWidgets('semua halaman Hadiah muat tanpa overflow ($label)', (
          tester,
        ) async {
          _usePhone(tester, height: 2600);
          tester.platformDispatcher
            ..textScaleFactorTestValue = 2
            ..accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
              disableAnimations: true,
            );
          addTearDown(tester.platformDispatcher.clearAllTestValues);
          final state = rich ? await _richState() : await createTestAppState();

          var index = 0;
          for (final entry in pages.entries) {
            await tester.pumpWidget(
              _Harness(
                key: ValueKey<int>(index++),
                state: state,
                mode: mode,
                home: entry.value,
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: entry.key);
          }

          await tester.pumpWidget(const SizedBox.shrink());
          state.dispose();
        });
      }
    }
  });
}

/// 360 x [height] logical pixels at 3x, like a common Android phone.
void _usePhone(WidgetTester tester, {double height = 740}) {
  tester.view
    ..physicalSize = Size(360 * 3, height * 3)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Pumps frames for [duration]. The today slot of the week track pulses
/// forever while a check-in is open, so pumpAndSettle cannot be used there.
Future<void> _pumpFor(WidgetTester tester, Duration duration) async {
  const step = Duration(milliseconds: 50);
  for (var elapsed = Duration.zero; elapsed < duration; elapsed += step) {
    await tester.pump(step);
  }
}

Finder _inPage<T extends Widget>(Finder finder) =>
    find.descendant(of: find.byType(T), matching: finder);

Finder _inSheet(Finder finder) =>
    find.descendant(of: find.byType(BottomSheet), matching: finder);

FilledButton _claimButton(WidgetTester tester) => tester.widget<FilledButton>(
  _inPage<CheckInPage>(
    find.byWidgetPredicate((widget) => widget is FilledButton),
  ),
);

/// Taps "Ambil 1 Kelopak", checks the result sheet and closes it with "Oke".
Future<void> _claimAndClose(
  WidgetTester tester, {
  required String expectedLine,
}) async {
  final claim = find.text('Ambil 1 Kelopak');
  await tester.ensureVisible(claim);
  await tester.pump();
  await tester.tap(claim);
  await _pumpFor(tester, const Duration(milliseconds: 1200));
  expect(_inSheet(find.text(expectedLine)), findsOneWidget);
  await tester.tap(_inSheet(find.text('Oke')));
  await _pumpFor(tester, const Duration(milliseconds: 600));
  expect(find.text('Oke'), findsNothing);
}

/// A state with a broken streak, a ledger with bonus and checkout spend, a
/// product won on the wheel today (Saturday), an issued voucher and a shipped
/// order that waits for Misi Belanja stage 2.
Future<AppState> _richState() async {
  final state = await createTestAppState(
    now: () => wibInstant(2026, 11, 23),
    random: ScriptedRandom(<int>[0, 99]),
  );
  for (var day = 0; day < 8; day++) {
    if (day > 0) state.advanceDays(1);
    state.claimCheckIn();
  }
  state
    ..jumpToNextSaturday()
    ..spin()
    ..addToCart('skintific-matte-fit-serum-spf50');
  final first = state.placeOrder(state.quote(useKelopak: true));
  if (first is OrderPlaced) state.markOrderReceived(first.order.id);
  state.addToCart('somethinc-copy-paste-cushion-nina');
  state.placeOrder(state.quote());
  return state;
}

/// The app's themes and scopes around a single page.
class _Harness extends StatefulWidget {
  const _Harness({
    super.key,
    required this.state,
    required this.home,
    this.mode = ThemeMode.light,
    this.shell,
  });

  final AppState state;
  final Widget home;
  final ThemeMode mode;
  final ShellController? shell;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final ShellController _ownShell = ShellController(ShellTab.rewards);

  @override
  void dispose() {
    _ownShell.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      notifier: widget.state,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        locale: BpediaApp.locale,
        supportedLocales: BpediaApp.supportedLocales,
        localizationsDelegates: BpediaApp.localizationsDelegates,
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: widget.mode,
        home: widget.home,
        builder: (context, child) => ShellScope(
          controller: widget.shell ?? _ownShell,
          navigatorKey: _navigatorKey,
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 2,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
