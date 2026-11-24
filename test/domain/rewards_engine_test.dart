import 'package:flutter_test/flutter_test.dart';
import 'package:kelopak_hub/domain/ledger.dart';
import 'package:kelopak_hub/domain/rewards_engine.dart';
import 'package:roda_sabtu/roda_sabtu.dart';

import '../support/test_app_state.dart';

void main() {
  final tuesday = wibDayFor(2026, 11, 24);
  final saturday = wibDayFor(2026, 11, 28);

  group('Check-in Harian', () {
    test('7 consecutive claims give 10 Kelopak (Rp1.000)', () {
      final engine = RewardsEngine(RewardsState());
      for (var day = 0; day < 7; day++) {
        expect(engine.claimCheckIn(tuesday + day), isA<CheckInClaimed>());
      }
      expect(engine.balance, 10);
      expect(engine.liveStreak(tuesday + 6), 7);
      final bonus = engine.ledger.where(
        (entry) => entry.kind == LedgerKind.checkInBonus,
      );
      expect(bonus.single.amount, 3);
      expect(bonus.single.note, 'Bonus 7 hari beruntun');
    });

    test('day 30 grants exactly one free-product entitlement', () {
      final engine = RewardsEngine(RewardsState());
      ProductEntitlement? granted;
      for (var day = 0; day < 30; day++) {
        final outcome = engine.claimCheckIn(tuesday + day) as CheckInClaimed;
        if (day < 29) expect(outcome.entitlement, isNull);
        granted = outcome.entitlement;
      }
      expect(granted, isNotNull);
      expect(granted!.source, EntitlementSource.checkIn);
      expect(granted.status, EntitlementStatus.pending);
      expect(engine.entitlements, <ProductEntitlement>[granted]);
      expect(engine.balance, 42);
    });

    test('a missed day restarts the streak and keeps the balance', () {
      final engine = RewardsEngine(RewardsState());
      for (var day = 0; day < 3; day++) {
        engine.claimCheckIn(tuesday + day);
      }
      expect(engine.balance, 3);
      final afterGap = tuesday + 4;
      expect(engine.liveStreak(afterGap), 0);
      expect(engine.streakBroken(afterGap), isTrue);

      final outcome = engine.claimCheckIn(afterGap) as CheckInClaimed;
      expect(outcome.award.streak, 1);
      expect(outcome.newBalance, 4);
      expect(engine.balance, 4);
      expect(engine.streakBroken(afterGap), isFalse);
    });

    test('claiming twice on the same day changes nothing', () {
      final engine = RewardsEngine(RewardsState());
      engine.claimCheckIn(tuesday);
      final before = engine.state.toJson();

      expect(engine.claimCheckIn(tuesday), isA<CheckInAlreadyClaimed>());
      expect(engine.state.toJson(), before);
      expect(engine.balance, 1);
      expect(engine.claimedToday(tuesday), isTrue);
      expect(engine.claimedToday(tuesday + 1), isFalse);
    });
  });

  group('Roda Sabtu', () {
    test('spins only on Saturday and only once per Saturday', () {
      final engine = RewardsEngine(RewardsState());

      final weekday = engine.spin(today: tuesday, roll: 5000, landingSeed: 1);
      expect(
        (weekday as SpinRejected).eligibility,
        SpinEligibility.notSaturday,
      );
      expect(engine.spins, isEmpty);

      expect(
        engine.spin(today: saturday, roll: 5000, landingSeed: 1),
        isA<SpinCompleted>(),
      );
      expect(engine.spinEligibility(saturday), SpinEligibility.alreadySpun);
      final again = engine.spin(today: saturday, roll: 5000, landingSeed: 2);
      expect((again as SpinRejected).eligibility, SpinEligibility.alreadySpun);
      expect(engine.spins, hasLength(1));

      final nextSaturday = saturday + 7;
      expect(engine.spinEligibility(nextSaturday), SpinEligibility.available);
      expect(
        engine.spin(today: nextSaturday, roll: 5000, landingSeed: 3),
        isA<SpinCompleted>(),
      );
    });

    test('an inactive promo blocks the spin', () {
      final engine = RewardsEngine(RewardsState())..setPromoActive(false);
      final outcome = engine.spin(today: saturday, roll: 5000, landingSeed: 1);
      expect(
        (outcome as SpinRejected).eligibility,
        SpinEligibility.promoInactive,
      );
    });

    test('a Kelopak prize is credited to the ledger', () {
      final engine = RewardsEngine(RewardsState());
      final outcome =
          engine.spin(today: saturday, roll: 5000, landingSeed: 42)
              as SpinCompleted;

      expect(outcome.prize.kind, PrizeKind.kelopak);
      expect(outcome.entitlement, isNull);
      expect(outcome.newBalance, outcome.prize.kelopak);
      expect(engine.balance, 3);
      expect(engine.ledger.single.kind, LedgerKind.spinPrize);
      expect(engine.ledger.single.amount, 3);
      expect(outcome.record.landingSeed, 42);
      expect(outcome.record.configVersion, engine.spinConfig.version);
      expect(engine.spinOn(saturday), outcome.record);
    });

    test(
      'the product prize uses stock; at stock 0 every roll pays Kelopak',
      () {
        final engine = RewardsEngine(RewardsState());
        expect(engine.productStock, 1);

        final oddsBefore = engine.currentOdds();
        final won =
            engine.spin(today: saturday, roll: 0, landingSeed: 1)
                as SpinCompleted;
        expect(won.prize.kind, PrizeKind.product);
        expect(won.odds, oddsBefore);
        expect(won.odds.first.weight, 1000);
        expect(won.entitlement?.source, EntitlementSource.spin);
        expect(engine.productStock, 0);
        expect(engine.balance, 0);

        final productOdds = engine.currentOdds().firstWhere(
          (odds) => odds.prize.kind == PrizeKind.product,
        );
        expect(productOdds.weight, 0);
        final next =
            engine.spin(today: saturday + 7, roll: 0, landingSeed: 1)
                as SpinCompleted;
        expect(next.prize.kind, PrizeKind.kelopak);
        expect(engine.productStock, 0);

        engine.refillProductStock();
        expect(engine.productStock, demoSpinProductStock);
      },
    );

    test('a saved spin keeps the wheel segments it was spun with', () {
      final engine = RewardsEngine(RewardsState());
      final won =
          engine.spin(today: saturday, roll: 0, landingSeed: 5)
              as SpinCompleted;
      expect(won.record.productStockBefore, 1);
      expect(engine.productStock, 0);
      expect(engine.oddsFor(won.record), won.odds);

      final restored = RewardsEngine(
        RewardsState.fromJson(engine.state.toJson()),
      );
      final record = restored.spinOn(saturday)!;
      expect(record, won.record);
      final product = restored
          .oddsFor(record)
          .firstWhere((odds) => odds.prize.kind == PrizeKind.product);
      expect(product.weight, 1000);
      expect(
        restored
            .currentOdds()
            .firstWhere((odds) => odds.prize.kind == PrizeKind.product)
            .weight,
        0,
      );
    });

    test('records saved without the stock still place a product win', () {
      final engine = RewardsEngine(RewardsState(productStock: 0));
      final legacy = SpinRecord.fromJson(<String, Object?>{
        'wibDay': saturday,
        'prizeId': 'product',
        'roll': 10,
        'landingSeed': 3,
        'configVersion': engine.spinConfig.version,
      });
      expect(legacy.productStockBefore, isNull);
      final product = engine
          .oddsFor(legacy)
          .firstWhere((odds) => odds.prize.kind == PrizeKind.product);
      expect(product.weight, 1000);
    });

    test('rejects rolls outside 0..9999', () {
      final engine = RewardsEngine(RewardsState());
      expect(
        () => engine.spin(today: saturday, roll: 10000, landingSeed: 1),
        throwsRangeError,
      );
    });
  });

  group('Kelopak spending', () {
    test('caps usage at 50% of the payable amount and the balance', () {
      final engine = RewardsEngine(
        RewardsState(
          ledger: <LedgerEntry>[
            LedgerEntry(
              id: 'L000001',
              wibDay: tuesday,
              amount: 500,
              kind: LedgerKind.spinPrize,
              note: 'Saldo uji',
            ),
          ],
          ledgerSeq: 1,
        ),
      );
      expect(engine.maxKelopakFor(10000), 50);
      expect(engine.maxKelopakFor(10099), 50);
      expect(engine.maxKelopakFor(200000), 500);
      expect(engine.maxKelopakFor(0), 0);
      expect(engine.maxKelopakFor(-100), 0);
    });

    test('never lets the balance go negative', () {
      final engine = RewardsEngine(RewardsState());
      engine.claimCheckIn(tuesday);
      expect(() => engine.spendKelopak(2, 'BP-X', tuesday), throwsStateError);
      expect(
        () => engine.spendKelopak(-1, 'BP-X', tuesday),
        throwsArgumentError,
      );
      expect(engine.balance, 1);

      engine.spendKelopak(1, 'BP-20261124-0001', tuesday);
      expect(engine.balance, 0);
      expect(engine.ledger.last.amount, -1);
      expect(engine.ledger.last.kind, LedgerKind.checkoutSpend);
      expect(engine.ledger.last.note, 'Dipakai di pesanan BP-20261124-0001');
    });
  });

  test('state survives a JSON round trip', () {
    final engine = RewardsEngine(RewardsState());
    for (var day = 0; day < 8; day++) {
      engine.claimCheckIn(tuesday + day);
    }
    engine.spin(today: saturday, roll: 0, landingSeed: 9);
    engine.completeOrder(
      orderId: 'BP-20261124-0001',
      eligibleSubtotal: 80000,
      today: tuesday,
    );
    final json = engine.state.toJson();
    expect(RewardsState.fromJson(json).toJson(), json);
  });

  test('rejects a stored state with a negative balance', () {
    final json = RewardsState(
      ledger: <LedgerEntry>[
        LedgerEntry(
          id: 'L000001',
          wibDay: tuesday,
          amount: -5,
          kind: LedgerKind.checkoutSpend,
          note: 'Rusak',
        ),
      ],
    ).toJson();
    expect(() => RewardsState.fromJson(json), throwsFormatException);
  });
}
