import 'package:flutter_test/flutter_test.dart';
import 'package:kelopak_hub/data/key_value_store.dart';
import 'package:kelopak_hub/data/persistence.dart';
import 'package:kelopak_hub/domain/app_state.dart';
import 'package:kelopak_hub/domain/rewards_engine.dart';
import 'package:kelopak_hub/domain/shop_engine.dart';
import 'package:misi_belanja/misi_belanja.dart' show OrderRejection;
import 'package:roda_sabtu/roda_sabtu.dart' show SpinEligibility;

import '../support/test_app_state.dart';

const String _skintific = 'skintific-matte-fit-serum-spf50';

Order _place(AppState state) {
  final result = state.placeOrder(state.quote());
  expect(result, isA<OrderPlaced>());
  return (result as OrderPlaced).order;
}

void main() {
  group('two app instances on one saved document (second browser tab)', () {
    test('a stale instance adopts the newer document instead of '
        'overwriting it', () async {
      final store = MemoryKeyValueStore();
      final tabA = await createTestAppState(store: store);
      final tabB = await createTestAppState(store: store);
      addTearDown(tabA.dispose);
      addTearDown(tabB.dispose);

      tabA
        ..claimCheckIn()
        ..addToCart(_skintific);
      final first = _place(tabA);
      await tabA.flush();
      expect(tabA.revision, greaterThan(0));

      // Tab B still shows the old data and changes a setting.
      expect(tabB.orders, isEmpty);
      tabB.setHaptics(false);
      await tabB.flush();

      final saved = AppSnapshot.decode(store.values[appStateStorageKey]);
      expect(saved.shop.orders.single.id, first.id);
      expect(saved.rewards.ledger, hasLength(1));
      expect(saved.shop.orderSeq, 1);

      // B now has A's data, so the same day cannot be claimed twice and the
      // next order number continues instead of being reused.
      expect(tabB.adoptedUpdates, 1);
      expect(tabB.orders.single.id, first.id);
      expect(tabB.balance, 1);
      expect(tabB.claimCheckIn(), isA<CheckInAlreadyClaimed>());
      tabB.addToCart(_skintific);
      final second = _place(tabB);
      expect(second.id, isNot(first.id));
      expect(second.id, endsWith('-0002'));
      await tabB.flush();
      final latest = AppSnapshot.decode(store.values[appStateStorageKey]);
      expect(latest.shop.orders, hasLength(2));
      expect(latest.revision, greaterThan(saved.revision));
    });

    test('syncFromStore picks up a newer save once', () async {
      final store = MemoryKeyValueStore();
      final tabA = await createTestAppState(store: store);
      final tabB = await createTestAppState(store: store);
      addTearDown(tabA.dispose);
      addTearDown(tabB.dispose);
      var notified = 0;
      tabB.addListener(() => notified++);

      expect(await tabB.syncFromStore(), isFalse);
      tabA.claimCheckIn();
      await tabA.flush();

      expect(await tabB.syncFromStore(), isTrue);
      expect(tabB.balance, 1);
      expect(tabB.claimedToday, isTrue);
      expect(notified, 1);
      expect(await tabB.syncFromStore(), isFalse);
    });

    test('the revision survives a reload and keeps growing', () async {
      final store = MemoryKeyValueStore();
      final first = await createTestAppState(store: store);
      first.claimCheckIn();
      await first.flush();
      final saved = first.revision;
      first.dispose();

      final reloaded = await createTestAppState(store: store);
      addTearDown(reloaded.dispose);
      expect(reloaded.revision, saved);
      reloaded.setSfx(false);
      await reloaded.flush();
      expect(reloaded.revision, saved + 1);
      expect(reloaded.adoptedUpdates, 0);
    });
  });

  group('Misi Belanja: one order completes one stage', () {
    test(
      'only the single waiting order is certain to issue the voucher',
      () async {
        final state = await createTestAppState();
        addTearDown(state.dispose);
        state.addToCart(_skintific);
        final a = _place(state);
        expect(state.isOnlyOrderAwaitingMission(a), isTrue);

        state.addToCart(_skintific);
        expect(state.missionShortfallFor(state.cartSubtotal), 0);
        final b = _place(state);
        expect(state.ordersAwaitingMission, hasLength(2));
        expect(state.isOnlyOrderAwaitingMission(a), isFalse);
        expect(state.isOnlyOrderAwaitingMission(b), isFalse);

        final firstReceived = state.markOrderReceived(a.id)!;
        expect(firstReceived.decision.issued, isTrue);
        final secondReceived = state.markOrderReceived(b.id)!;
        expect(secondReceived.decision.issued, isFalse);
        expect(
          secondReceived.decision.rejection,
          OrderRejection.belowThreshold,
        );
        expect(state.vouchers, hasLength(1));
      },
    );
  });

  group('Roda Sabtu opening: one wording everywhere', () {
    test('whole calendar days until the day before, then clock time', () async {
      final clock = FakeClock(wibInstant(2026, 11, 25, hour: 2));
      final state = await createTestAppState(now: clock.now);
      addTearDown(state.dispose);

      var opening = state.nextSpinOpening;
      expect(opening.day, wibDayFor(2026, 11, 28));
      expect(opening.daysLeft, 3);
      expect(opening.remainingLabel, '3 hari lagi');
      expect(opening.opensAtLabel, 'Sabtu, 28 Nov · 00.00 WIB');
      expect(opening.dayLabel, 'Sabtu, 28 Nov');

      clock.current = wibInstant(2026, 11, 27, hour: 1, minute: 20);
      opening = state.nextSpinOpening;
      expect(opening.daysLeft, 1);
      expect(opening.remainingLabel, '22 jam 40 menit lagi');
      expect(opening.countsClockTime, isTrue);

      clock.current = wibInstant(2026, 11, 27, hour: 23, minute: 30);
      expect(state.nextSpinOpening.remainingLabel, '30 menit lagi');

      clock.current = wibInstant(2026, 11, 27, hour: 23, minute: 59);
      expect(state.nextSpinOpening.remainingLabel, '1 menit lagi');
      clock.advance(const Duration(seconds: 30));
      expect(state.nextSpinOpening.remainingLabel, 'kurang dari 1 menit lagi');

      clock.current = wibInstant(2026, 12, 7, hour: 1, minute: 20);
      expect(state.nextSpinOpening.remainingLabel, '5 hari lagi');
    });
  });

  group('device clock moved back', () {
    test('the next check-in is the day after the future-dated claim', () async {
      final clock = FakeClock(wibInstant(2026, 11, 30));
      final state = await createTestAppState(now: clock.now);
      addTearDown(state.dispose);
      expect(state.nextCheckInDay, state.today);
      state.claimCheckIn();
      expect(state.nextCheckInDay, wibDayFor(2026, 12, 1));

      clock.current = wibInstant(2026, 11, 25);
      expect(state.canCheckIn, isFalse);
      expect(state.nextCheckInDay, wibDayFor(2026, 12, 1));
      clock.current = wibInstant(2026, 11, 26);
      expect(state.canCheckIn, isFalse);
      clock.current = wibInstant(2026, 12, 1);
      expect(state.canCheckIn, isTrue);
    });

    test('the next spin Saturday comes after the future-dated spin', () async {
      final clock = FakeClock(wibInstant(2026, 11, 28));
      final state = await createTestAppState(
        now: clock.now,
        random: ScriptedRandom(<int>[5000, 1]),
      );
      addTearDown(state.dispose);
      expect(state.spin(), isA<SpinCompleted>());
      expect(state.nextSpinSaturday, wibDayFor(2026, 12, 5));

      clock.current = wibInstant(2026, 11, 21);
      expect(state.spinEligibility, SpinEligibility.alreadySpun);
      expect(state.nextSaturday, wibDayFor(2026, 11, 28));
      expect(state.nextSpinSaturday, wibDayFor(2026, 12, 5));
      expect(state.nextSpinOpening.remainingLabel, '14 hari lagi');

      clock.current = wibInstant(2026, 11, 25);
      expect(state.spinEligibility, SpinEligibility.notSaturday);
      expect(state.nextSpinSaturday, wibDayFor(2026, 12, 5));

      clock.current = wibInstant(2026, 11, 28);
      expect(state.spinEligibility, SpinEligibility.alreadySpun);
      expect(state.nextSpinSaturday, wibDayFor(2026, 12, 5));
    });
  });

  test('stockForSpin is the stock the wheel was spun with', () async {
    final state = await createTestAppState(
      now: () => wibInstant(2026, 11, 28),
      random: ScriptedRandom(<int>[0, 7]),
    );
    addTearDown(state.dispose);
    final outcome = state.spin() as SpinCompleted;
    expect(state.productStock, 0);
    expect(state.stockForSpin(outcome.record), 1);
    expect(state.oddsForSpin(outcome.record).first.weight, 1000);
  });
}
