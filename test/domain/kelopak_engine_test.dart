import 'package:flutter_test/flutter_test.dart';
import 'package:kelopak_hub/kelopak_hub.dart';

import 'fixtures.dart';

void main() {
  group('Check-in Harian', () {
    test('7 consecutive claims give 10 Kelopak (Rp1.000)', () {
      final engine = KelopakEngine(KelopakState());
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

    test('day 30 grants exactly one pending free-product gift', () {
      final engine = KelopakEngine(KelopakState(), campaign: testCampaign());
      PendingGift? granted;
      for (var day = 0; day < 30; day++) {
        final outcome = engine.claimCheckIn(tuesday + day) as CheckInClaimed;
        if (day < 29) expect(outcome.gift, isNull);
        granted = outcome.gift;
      }
      expect(granted, isNotNull);
      expect(granted!.source, GiftSource.checkIn30);
      expect(granted.status, GiftStatus.pending);
      expect(granted.productCode, checkIn30Code);
      expect(granted.wonDay, tuesday + 29);
      expect(engine.gifts, <PendingGift>[granted]);
      expect(engine.pendingGifts, <PendingGift>[granted]);
      expect(engine.balance, 42);
    });

    test('a missed day restarts the streak and keeps the balance', () {
      final engine = KelopakEngine(KelopakState());
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
      final engine = KelopakEngine(KelopakState());
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
      final engine = KelopakEngine(KelopakState());

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
      final engine = KelopakEngine(KelopakState())..setPromoActive(false);
      final outcome = engine.spin(today: saturday, roll: 5000, landingSeed: 1);
      expect(
        (outcome as SpinRejected).eligibility,
        SpinEligibility.promoInactive,
      );
    });

    test('a Kelopak prize is credited to the ledger', () {
      final engine = KelopakEngine(KelopakState());
      final outcome =
          engine.spin(today: saturday, roll: 5000, landingSeed: 42)
              as SpinCompleted;

      expect(outcome.prize.kind, PrizeKind.kelopak);
      expect(outcome.gift, isNull);
      expect(outcome.newBalance, outcome.prize.kelopak);
      expect(engine.balance, 3);
      expect(engine.ledger.single.kind, LedgerKind.spinPrize);
      expect(engine.ledger.single.amount, 3);
      expect(outcome.record.landingSeed, 42);
      expect(outcome.record.configVersion, engine.spinConfig.version);
      expect(engine.spinOn(saturday), outcome.record);
    });

    test(
      'the product prize uses the quota; at 0 the fallback pays Kelopak',
      () {
        final engine = KelopakEngine(
          KelopakState(),
          campaign: testCampaign(wheelQuota: 1),
        );
        expect(engine.wheelQuotaLeft(saturday), 1);

        final oddsBefore = engine.currentOdds(saturday);
        final won =
            engine.spin(today: saturday, roll: 0, landingSeed: 1)
                as SpinCompleted;
        expect(won.prize.kind, PrizeKind.product);
        expect(won.odds, oddsBefore);
        expect(won.odds.first.weight, 500);
        expect(won.gift?.source, GiftSource.wheel);
        expect(won.gift?.productCode, isIn(wheelCodes));
        expect(won.record.giftId, won.gift?.id);
        expect(engine.wheelQuotaLeft(saturday), 0);
        expect(engine.balance, 0);

        final productOdds = engine
            .currentOdds(saturday)
            .firstWhere((odds) => odds.prize.kind == PrizeKind.product);
        expect(productOdds.weight, 0);
        final next =
            engine.spin(today: saturday + 7, roll: 0, landingSeed: 1)
                as SpinCompleted;
        expect(next.prize.kind, PrizeKind.product);
        expect(engine.wheelQuotaLeft(saturday + 7), 0);

        final noRefill = KelopakEngine(
          KelopakState(),
          campaign: const KelopakCampaign(
            wheelQuota: 1,
            wheelQuotaRefillsWeekly: false,
            wheelProductCodes: wheelCodes,
          ),
        );
        noRefill.spin(today: saturday, roll: 0, landingSeed: 1);
        final fallback =
            noRefill.spin(today: saturday + 7, roll: 0, landingSeed: 1)
                as SpinCompleted;
        expect(fallback.prize.kind, PrizeKind.kelopak);
        expect(
          fallback.odds
              .firstWhere((odds) => odds.prize.id == 'kelopak-1')
              .weight,
          5000,
        );
        expect(noRefill.wheelQuotaLeft(saturday + 7), 0);

        noRefill.refillWheelQuota(saturday + 7);
        expect(noRefill.wheelQuotaLeft(saturday + 7), 1);
      },
    );

    test('a saved spin keeps the wheel segments it was spun with', () {
      final engine = KelopakEngine(
        KelopakState(),
        campaign: testCampaign(wheelQuota: 1),
      );
      final won =
          engine.spin(today: saturday, roll: 0, landingSeed: 5)
              as SpinCompleted;
      expect(won.record.productStockBefore, 1);
      expect(engine.wheelQuotaLeft(saturday), 0);
      expect(engine.oddsFor(won.record), won.odds);

      final restored = KelopakEngine(
        KelopakState.fromJson(engine.state.toJson()),
        campaign: testCampaign(wheelQuota: 1),
      );
      final record = restored.spinOn(saturday)!;
      expect(record, won.record);
      final product = restored
          .oddsFor(record)
          .firstWhere((odds) => odds.prize.kind == PrizeKind.product);
      expect(product.weight, 500);
      expect(
        restored
            .currentOdds(saturday)
            .firstWhere((odds) => odds.prize.kind == PrizeKind.product)
            .weight,
        0,
      );
    });

    test('records saved without the stock still place a product win', () {
      final engine = KelopakEngine(
        KelopakState(
          wheelQuotaUsed: 3,
          wheelQuotaWeek: KelopakCampaign.weekOf(saturday),
        ),
      );
      expect(engine.wheelQuotaLeft(saturday), 0);
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
      expect(product.weight, 500);
    });

    test('rejects rolls outside 0..9999', () {
      final engine = KelopakEngine(KelopakState());
      expect(
        () => engine.spin(today: saturday, roll: 10000, landingSeed: 1),
        throwsRangeError,
      );
    });

    test('the weekly quota refills on Monday and rotates the product', () {
      final engine = KelopakEngine(KelopakState(), campaign: testCampaign());
      final first =
          engine.spin(today: saturday, roll: 0, landingSeed: 1)
              as SpinCompleted;
      expect(engine.wheelQuotaLeft(saturday), 2);
      expect(engine.wheelQuotaLeft(saturday + 2), 3);
      final second =
          engine.spin(today: saturday + 7, roll: 0, landingSeed: 1)
              as SpinCompleted;
      expect(first.gift!.productCode, isNot(second.gift!.productCode));
      expect(
        second.gift!.productCode,
        testCampaign().wheelProductCodeOn(saturday + 7),
      );
    });
  });

  group('Kelopak spending', () {
    test('never lets the balance go negative', () {
      final engine = KelopakEngine(KelopakState());
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
      expect(engine.ledger.last.orderId, 'BP-20261124-0001');
    });

    test('demo grants must be positive and are booked as demo', () {
      final engine = KelopakEngine(KelopakState())..grantKelopak(500, tuesday);
      expect(engine.balance, 500);
      expect(engine.ledger.single.kind, LedgerKind.demoGrant);
      expect(() => engine.grantKelopak(0, tuesday), throwsArgumentError);
    });
  });

  group('Misi Belanja on completion', () {
    test('Rp74.999 does not qualify, Rp75.000 does', () {
      final engine = KelopakEngine(KelopakState(), campaign: testCampaign());
      place(engine, 'BP-20261124-0002', <CheckoutLine>[
        line(missionCodes[0], 75000),
      ], today: tuesday);
      place(engine, 'BP-20261124-0001', <CheckoutLine>[
        line(missionCodes[0], 74999),
      ], today: tuesday);

      final below = engine.completeOrder('BP-20261124-0001', tuesday)!;
      expect(below.order.status, KelopakOrderStatus.completed);
      expect(below.order.closedDay, tuesday);
      expect(below.decision.issued, isFalse);
      expect(below.decision.rejection, OrderRejection.belowThreshold);
      expect(below.voucher, isNull);
      expect(engine.missionIssuedCount, 0);

      final exact = engine.completeOrder('BP-20261124-0002', tuesday)!;
      expect(exact.decision.issued, isTrue);
      expect(exact.decision.issuedStage?.number, 1);
      final voucher = exact.voucher!;
      expect(voucher.amount, 10000);
      expect(voucher.minSpend, 100000);
      expect(voucher.sourceOrderId, 'BP-20261124-0002');
      expect(voucher.expiresDay, tuesday + 30);
      expect(engine.missionIssuedCount, 1);

      expect(engine.completeOrder('BP-20261124-0002', tuesday), isNull);
      expect(engine.completeOrder('BP-unknown', tuesday), isNull);
    });

    test(
      'voucher 1 unlocks stage 2; after the last stage orders are not counted',
      () {
        final engine = KelopakEngine(KelopakState(), campaign: testCampaign());
        place(engine, 'BP-C', <CheckoutLine>[
          line(otherCode, 120000),
        ], today: tuesday);
        place(engine, 'BP-B', <CheckoutLine>[
          line(otherCode, 100000),
        ], today: tuesday);
        place(engine, 'BP-A', <CheckoutLine>[
          line(missionCodes[1], 80000),
        ], today: tuesday);
        expect(engine.activeStage?.number, 1);

        engine.completeOrder('BP-A', tuesday);
        expect(engine.activeStage?.number, 2);
        expect(engine.allMissionStagesDone, isFalse);

        final second = engine.completeOrder('BP-B', tuesday + 1)!;
        expect(second.decision.issuedStage?.number, 2);
        expect(second.voucher?.amount, 15000);
        expect(second.voucher?.minSpend, 150000);
        expect(engine.allMissionStagesDone, isTrue);
        expect(engine.activeStage, isNull);

        final third = engine.completeOrder('BP-C', tuesday + 2)!;
        expect(third.decision.rejection, OrderRejection.allStagesDone);
        expect(third.voucher, isNull);
        expect(engine.vouchers, hasLength(2));
        expect(engine.countedOrderIds, <String>{'BP-A', 'BP-B', 'BP-C'});
      },
    );

    test('only the single waiting order is certain to issue the voucher', () {
      final engine = KelopakEngine(KelopakState(), campaign: testCampaign());
      final a = place(engine, 'BP-A', <CheckoutLine>[
        line(missionCodes[0], 80000),
      ], today: tuesday);
      expect(engine.isOnlyOrderAwaitingMission(a.id), isTrue);

      final b = place(engine, 'BP-B', <CheckoutLine>[
        line(missionCodes[0], 80000),
      ], today: tuesday);
      expect(engine.ordersAwaitingMission, hasLength(2));
      expect(engine.isOnlyOrderAwaitingMission(a.id), isFalse);
      expect(engine.isOnlyOrderAwaitingMission(b.id), isFalse);

      final firstReceived = engine.completeOrder(a.id, tuesday)!;
      expect(firstReceived.decision.issued, isTrue);
      final secondReceived = engine.completeOrder(b.id, tuesday)!;
      expect(secondReceived.decision.issued, isFalse);
      expect(secondReceived.decision.rejection, OrderRejection.belowThreshold);
      expect(engine.vouchers, hasLength(1));
    });

    test('K4: only mission products count, and one order completes one '
        'stage', () {
      final engine = KelopakEngine(KelopakState(), campaign: testCampaign());
      final mixed = <CheckoutLine>[
        line(missionCodes[0], 45000),
        line(otherCode, 200000),
      ];
      expect(engine.missionProductCodes, missionCodes.toSet());
      final progress = engine.missionProgressFor(mixed)!;
      expect(progress.current, 45000);
      expect(progress.reached, isFalse);
      expect(progress.remaining, 30000);

      place(engine, 'BP-MIX', mixed, today: tuesday);
      expect(engine.ordersAwaitingMission, isEmpty);
      final mixedDone = engine.completeOrder('BP-MIX', tuesday)!;
      expect(mixedDone.decision.rejection, OrderRejection.belowThreshold);

      final big = <CheckoutLine>[
        line(missionCodes[0], 45000, quantity: 2),
        line(missionCodes[2], 160000),
      ];
      place(engine, 'BP-BIG', big, today: tuesday);
      final bigDone = engine.completeOrder('BP-BIG', tuesday)!;
      expect(bigDone.decision.issuedStage?.number, 1);
      expect(engine.missionIssuedCount, 1);
      expect(engine.activeStage?.number, 2);
      expect(engine.vouchers, hasLength(1));
      expect(engine.missionProductCodes, isEmpty);
    });

    test('a cancelled order never counts for the mission', () {
      final engine = KelopakEngine(KelopakState(), campaign: testCampaign());
      place(engine, 'BP-A', <CheckoutLine>[
        line(missionCodes[0], 80000),
      ], today: tuesday);
      expect(engine.cancelOrder('BP-A', tuesday), isNotNull);
      expect(engine.ordersAwaitingMission, isEmpty);
      expect(engine.completeOrder('BP-A', tuesday), isNull);
      expect(engine.missionIssuedCount, 0);
    });
  });

  group('stored state', () {
    test('state survives a JSON round trip', () {
      final engine = KelopakEngine(KelopakState(), campaign: testCampaign());
      for (var day = 0; day < 8; day++) {
        engine.claimCheckIn(tuesday + day);
      }
      engine.spin(today: saturday, roll: 0, landingSeed: 9);
      place(engine, 'BP-20261124-0001', <CheckoutLine>[
        line(missionCodes[0], 80000),
      ], today: tuesday + 7);
      engine.completeOrder('BP-20261124-0001', tuesday + 8);
      engine.claimPromoVoucher(
        promoId: 'payday',
        amount: 5000,
        minSpend: 50000,
        validDays: 7,
        today: tuesday + 8,
      );
      final json = engine.state.toJson();
      expect(json['orders'], hasLength(1));
      expect(json['gifts'], hasLength(1));
      expect(KelopakState.fromJson(json).toJson(), json);
    });

    test('rejects a stored state with a negative balance', () {
      final json = KelopakState(
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
      expect(() => KelopakState.fromJson(json), throwsFormatException);
    });

    test('rejects duplicate ids and gifts whose status contradicts the '
        'order', () {
      final entry = LedgerEntry(
        id: 'L000001',
        wibDay: tuesday,
        amount: 5,
        kind: LedgerKind.checkIn,
        note: 'x',
      );
      final duplicate = KelopakState(
        ledger: <LedgerEntry>[entry, entry],
      ).toJson();
      expect(() => KelopakState.fromJson(duplicate), throwsFormatException);

      final gift = <String, Object?>{
        'id': 'HG-0001',
        'source': 'wheel',
        'wonDay': saturday,
        'status': 'attached',
        'orderId': null,
      };
      expect(() => PendingGift.fromJson(gift), throwsFormatException);
    });
  });

  group('promo voucher', () {
    test('is claimed once per promo and validates its terms', () {
      final engine = KelopakEngine(KelopakState());
      expect(engine.canClaimPromoVoucher('payday'), isTrue);
      final claimed =
          engine.claimPromoVoucher(
                promoId: 'payday',
                amount: 20000,
                minSpend: 150000,
                validDays: 7,
                today: tuesday,
                title: 'Voucher Payday',
              )
              as PromoVoucherClaimed;
      expect(claimed.voucher.kind, VoucherKind.promo);
      expect(claimed.voucher.id, 'VP-0001');
      expect(claimed.voucher.expiresDay, tuesday + 7);
      expect(engine.canClaimPromoVoucher('payday'), isFalse);

      final again =
          engine.claimPromoVoucher(
                promoId: 'payday',
                amount: 20000,
                minSpend: 150000,
                validDays: 7,
                today: tuesday,
              )
              as PromoVoucherNotClaimed;
      expect(again.problem, PromoClaimProblem.alreadyClaimed);
      final invalid =
          engine.claimPromoVoucher(
                promoId: 'flash',
                amount: 0,
                minSpend: 0,
                validDays: 7,
                today: tuesday,
              )
              as PromoVoucherNotClaimed;
      expect(invalid.problem, PromoClaimProblem.invalidTerms);
      expect(engine.activeVouchers(tuesday + 7), hasLength(1));
      expect(engine.activeVouchers(tuesday + 8), isEmpty);
    });
  });
}
