import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelopak_hub/data/key_value_store.dart';
import 'package:kelopak_hub/data/persistence.dart';
import 'package:kelopak_hub/domain/app_state.dart';
import 'package:kelopak_hub/domain/rewards_engine.dart';
import 'package:kelopak_hub/domain/shop_engine.dart';
import 'package:roda_sabtu/roda_sabtu.dart';

import '../support/test_app_state.dart';

void main() {
  final tuesday = wibDayFor(2026, 11, 24);
  final saturday = wibDayFor(2026, 11, 28);

  test('starts fresh on the injected WIB day', () async {
    final state = await createTestAppState();
    addTearDown(state.dispose);

    expect(state.today, tuesday);
    expect(state.balance, 0);
    expect(state.canCheckIn, isTrue);
    expect(state.nextCheckInStreakDay, 1);
    expect(state.isSaturday, isFalse);
    expect(state.nextSaturday, saturday);
    expect(state.daysUntilNextSaturday, 4);
    expect(state.spinEligibility, SpinEligibility.notSaturday);
    expect(state.isCartEmpty, isTrue);
    expect(state.activeMissionStage?.number, 1);
  });

  test('a claim is saved and survives a reload', () async {
    final store = MemoryKeyValueStore();
    final state = await createTestAppState(store: store);
    var notifications = 0;
    state.addListener(() => notifications++);

    final outcome = state.claimCheckIn();
    expect(outcome, isA<CheckInClaimed>());
    expect(state.claimCheckIn(), isA<CheckInAlreadyClaimed>());
    expect(notifications, 1);
    await state.flush();
    expect(store.values.containsKey(appStateStorageKey), isTrue);
    expect(state.lastSaveError, isNull);
    state.dispose();

    final reloaded = await createTestAppState(store: store);
    addTearDown(reloaded.dispose);
    expect(reloaded.balance, 1);
    expect(reloaded.claimedToday, isTrue);
    expect(reloaded.nextCheckInStreakDay, 2);
    expect(reloaded.checkInWeekFilled, 1);
  });

  test('the WIB day turns over at 00.00 WIB', () async {
    final clock = FakeClock(wibInstant(2026, 11, 24, hour: 23, minute: 59));
    final state = await createTestAppState(now: clock.now);
    addTearDown(state.dispose);

    state.claimCheckIn();
    expect(state.canCheckIn, isFalse);
    expect(state.untilNextDay(), const Duration(minutes: 1));

    clock.advance(const Duration(minutes: 2));
    expect(state.today, tuesday + 1);
    expect(state.canCheckIn, isTrue);
    expect(state.liveStreak, 1);
  });

  test('spins with the drawn roll and landing seed on Saturday', () async {
    final state = await createTestAppState(
      random: ScriptedRandom(<int>[0, 123]),
    );
    addTearDown(state.dispose);

    expect(state.spin(), isA<SpinRejected>());
    state.jumpToNextSaturday();
    expect(state.today, saturday);
    expect(state.canSpin, isTrue);
    expect(state.spinOdds.first.percent, 10);

    final outcome = state.spin() as SpinCompleted;
    expect(outcome.record.roll, 0);
    expect(outcome.record.landingSeed, 123);
    expect(outcome.prize.kind, PrizeKind.product);
    expect(state.todaySpin, outcome.record);
    expect(state.prizeFor(outcome.record), outcome.prize);
    expect(state.entitlements, hasLength(1));
    expect(state.productStock, 0);
    expect(state.canSpin, isFalse);

    state.jumpToNextSaturday();
    expect(state.today, saturday + 7);
    expect(state.todaySpin, isNull);
    expect(state.lastSpin, outcome.record);
  });

  test('demo tools validate and move the calendar', () async {
    final state = await createTestAppState();
    addTearDown(state.dispose);

    expect(() => state.advanceDays(0), throwsRangeError);
    expect(
      () => state.advanceDays(AppState.maxDemoAdvanceDays + 1),
      throwsRangeError,
    );
    state.advanceDays(7);
    expect(state.today, tuesday + 7);
    expect(state.demoOffsetDays, 7);

    state.setPromoActive(false);
    expect(state.spinEligibility, SpinEligibility.promoInactive);
    state.setPromoActive(true);
  });

  test(
    'checkout through AppState places, rejects stale quotes and completes',
    () async {
      final state = await createTestAppState();
      addTearDown(state.dispose);

      final empty = state.placeOrder(state.quote());
      expect((empty as OrderNotPlaced).problem, PlaceOrderProblem.emptyCart);

      state
        ..addToCart('gogotales-dusk-thick-mist-lip-glaze-g06')
        ..addToCart('animate-brightening-soap-80g', qty: 4);
      expect(state.cartCount, 5);
      expect(state.missionShortfallFor(state.cartSubtotal), 0);

      final stale = state.quote();
      final removed = state.removeFromCart('animate-brightening-soap-80g')!;
      expect(state.missionShortfallFor(state.cartSubtotal), 40000);
      final outdated = state.placeOrder(stale);
      expect(
        (outdated as OrderNotPlaced).problem,
        PlaceOrderProblem.quoteOutdated,
      );
      state.undoRemoveFromCart(removed);

      final placed = state.placeOrder(state.quote()) as OrderPlaced;
      expect(placed.order.status, OrderStatus.shipped);
      expect(state.isCartEmpty, isTrue);
      expect(state.ordersAwaitingMission, <Order>[placed.order]);
      expect(state.ordersWithStatus(OrderStatus.shipped), hasLength(1));

      final completion = state.markOrderReceived(placed.order.id)!;
      expect(completion.decision.issued, isTrue);
      expect(state.activeVouchers.single.id, completion.voucher!.id);
      expect(state.missionIssuedCount, 1);
      expect(state.ordersAwaitingMission, isEmpty);
      expect(state.ordersWithStatus(OrderStatus.completed), hasLength(1));

      state.addToCart('somethinc-ombrella-lip-totem-tint-ikr');
      expect(state.voucherShortfallForCart(completion.voucher!.id), 29200);

      state.advanceDays(30);
      expect(state.activeVouchers, hasLength(1));
      state.advanceDays(1);
      expect(state.activeVouchers, isEmpty);
      expect(state.vouchers, hasLength(1));
    },
  );

  test('ledger history runs newest first with the running balance', () async {
    final state = await createTestAppState();
    addTearDown(state.dispose);
    for (var day = 0; day < 7; day++) {
      state.claimCheckIn();
      state.advanceDays(1);
    }
    final history = state.ledgerHistory;
    expect(history.first.balanceAfter, 10);
    expect(history.first.entry.amount, 3);
    expect(history.last.balanceAfter, 1);
  });

  test('settings are applied and saved; reset keeps them', () async {
    final store = MemoryKeyValueStore();
    final state = await createTestAppState(store: store);
    state
      ..setSfx(false)
      ..setMusic(true)
      ..setHaptics(false)
      ..setThemeMode(ThemeMode.dark)
      ..claimCheckIn()
      ..advanceDays(3);
    expect(state.sound.sfxEnabled, isFalse);
    expect(state.sound.musicEnabled, isTrue);
    expect(state.haptics.enabled, isFalse);

    state.resetAll();
    expect(state.balance, 0);
    expect(state.demoOffsetDays, 0);
    expect(state.settings.themeMode, ThemeMode.dark);
    await state.flush();
    state.dispose();

    final reloaded = await createTestAppState(store: store);
    addTearDown(reloaded.dispose);
    expect(reloaded.settings.sfxEnabled, isFalse);
    expect(reloaded.settings.musicEnabled, isTrue);
    expect(reloaded.settings.hapticsEnabled, isFalse);
    expect(reloaded.settings.themeMode, ThemeMode.dark);
    expect(reloaded.balance, 0);
  });
}
