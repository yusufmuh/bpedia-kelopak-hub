import 'package:flutter_test/flutter_test.dart';
import 'package:kelopak_hub/kelopak_hub.dart';

import 'fixtures.dart';

void main() {
  group('voucher', () {
    test('needs min. Rp100.000, never on its own order, used once', () {
      final engine = KelopakEngine(KelopakState(), campaign: testCampaign());

      final first = place(engine, 'BP-20261124-0001', <CheckoutLine>[
        line(missionCodes[0], 35000),
        line(missionCodes[1], 10000, quantity: 4),
      ], today: tuesday);
      expect(first.goodsSubtotal, 75000);
      final voucher = engine.completeOrder(first.id, tuesday)!.voucher!;

      final below = engine.quote(
        request(<CheckoutLine>[line(otherCode, 70800)], voucherId: voucher.id),
        today: tuesday,
      );
      expect(below.voucherProblem, RedeemProblem.belowMinimum);
      expect(below.voucherApplied, isFalse);
      expect(below.voucherAmount, 0);
      expect(below.total, 70800);

      expect(
        engine.voucherProblem(
          voucherId: voucher.id,
          orderId: first.id,
          subtotal: 150000,
          today: tuesday,
        ),
        RedeemProblem.sameOrder,
      );

      final okLines = <CheckoutLine>[
        line(otherCode, 70800),
        line(missionCodes[2], 60000),
      ];
      final ok = engine.quote(
        request(okLines, voucherId: voucher.id),
        today: tuesday,
      );
      expect(ok.goodsSubtotal, 130800);
      expect(ok.voucherApplied, isTrue);
      expect(ok.voucherAmount, 10000);
      expect(ok.total, 120800);
      final second =
          (engine.commitOrder(orderId: 'BP-2', quote: ok, today: tuesday)
                  as OrderCommitted)
              .order;
      expect(second.voucherId, voucher.id);
      expect(second.voucherAmount, 10000);
      expect(second.total, 120800);
      expect(engine.voucherById(voucher.id)?.usedOnOrderId, second.id);

      final reused = engine.quote(
        request(<CheckoutLine>[line(otherCode, 132510)], voucherId: voucher.id),
        today: tuesday,
      );
      expect(reused.voucherProblem, RedeemProblem.alreadyUsed);
      expect(reused.voucherAmount, 0);
      expect(reused.total, 132510);
    });

    test('an expired voucher is refused and an unknown id is ignored', () {
      final engine = KelopakEngine(KelopakState());
      engine.claimPromoVoucher(
        promoId: 'payday',
        amount: 5000,
        minSpend: 0,
        validDays: 1,
        today: tuesday,
      );
      final lines = <CheckoutLine>[line(otherCode, 20000)];
      final late = engine.quote(
        request(lines, voucherId: 'VP-0001'),
        today: tuesday + 2,
      );
      expect(late.voucherProblem, RedeemProblem.expired);
      expect(late.total, 20000);
      final unknown = engine.quote(
        request(lines, voucherId: 'VP-9999'),
        today: tuesday,
      );
      expect(unknown.voucherId, isNull);
      expect(unknown.voucherApplied, isFalse);
      expect(unknown.total, 20000);
    });
  });

  group('K16: Kelopak at checkout', () {
    test('a small balance is used fully and only when switched on', () {
      final engine = KelopakEngine(stateWithBalance(10, tuesday));
      final lines = <CheckoutLine>[line(otherCode, 10000)];

      final quote = engine.quote(request(lines), today: tuesday);
      expect(quote.useKelopak, isTrue);
      expect(quote.kelopakUsed, 10);
      expect(quote.total, 9000);
      final off = engine.quote(
        request(lines, useKelopak: false),
        today: tuesday,
      );
      expect(off.kelopakUsed, 0);
      expect(off.kelopakMax, 10);
      expect(off.total, 10000);

      engine.commitOrder(orderId: 'BP-1', quote: quote, today: tuesday);
      expect(engine.balance, 0);
      final empty = engine.quote(request(lines), today: tuesday);
      expect(empty.kelopakUsed, 0);
      expect(empty.total, 10000);
    });

    test('order: voucher first, then Kelopak on the rest, shipping last', () {
      final engine = KelopakEngine(stateWithBalance(5000, tuesday));
      engine.claimPromoVoucher(
        promoId: 'payday',
        amount: 20000,
        minSpend: 100000,
        validDays: 7,
        today: tuesday,
      );
      final quote = engine.quote(
        request(
          <CheckoutLine>[line(otherCode, 120000)],
          voucherId: 'VP-0001',
          shippingFee: 12000,
        ),
        today: tuesday,
      );
      expect(quote.goodsSubtotal, 120000);
      expect(quote.voucherAmount, 20000);
      expect(quote.goodsAfterVoucher, 100000);
      expect(quote.kelopakMax, 1000);
      expect(quote.kelopakUsed, 1000);
      expect(quote.kelopakValue, 100000);
      expect(quote.shippingFee, 12000);
      expect(quote.total, 12000);
      expect(quote.isFullyCovered, isFalse);
    });

    test('Kelopak never pays shipping and fractions under Rp100 stay '
        'payable', () {
      final engine = KelopakEngine(stateWithBalance(1000, tuesday));
      final quote = engine.quote(
        request(<CheckoutLine>[line(otherCode, 12345)], shippingFee: 9000),
        today: tuesday,
      );
      expect(quote.kelopakUsed, 123);
      expect(quote.kelopakValue, 12300);
      expect(quote.total, 45 + 9000);
    });

    test('the share cap follows KelopakPolicy.redeemShareBp', () {
      const half = KelopakPolicy(redeemShareBp: 5000);
      expect(half.maxKelopakFor(10000), 50);
      expect(half.maxKelopakFor(10099), 50);
      expect(half.maxKelopakFor(0), 0);
      expect(half.maxKelopakFor(-100), 0);
      const full = KelopakPolicy();
      expect(full.redeemShareBp, 10000);
      expect(full.maxKelopakFor(10099), 100);
      expect(full.rupiahOf(12), 1200);

      final engine = KelopakEngine(
        stateWithBalance(500, tuesday),
        campaign: testCampaign(redeemShareBp: 5000),
      );
      final quote = engine.quote(
        request(<CheckoutLine>[line(otherCode, 10000)]),
        today: tuesday,
      );
      expect(quote.kelopakUsed, 50);
      expect(quote.total, 5000);
    });

    test('total Rp0 is fully covered and booked as one debit', () {
      final engine = KelopakEngine(stateWithBalance(500, tuesday));
      final quote = engine.quote(
        request(<CheckoutLine>[line(otherCode, 10000)]),
        today: tuesday,
      );
      expect(quote.kelopakUsed, 100);
      expect(quote.total, 0);
      expect(quote.isFullyCovered, isTrue);

      final order =
          (engine.commitOrder(orderId: 'BP-1', quote: quote, today: tuesday)
                  as OrderCommitted)
              .order;
      expect(order.kelopakUsed, 100);
      expect(order.kelopakValue, 10000);
      expect(order.total, 0);
      expect(engine.balance, 400);
      expect(engine.ledger.last.amount, -100);
      expect(engine.ledger.last.kind, LedgerKind.checkoutSpend);
      expect(engine.ledger.last.note, 'Dipakai di pesanan #BP-1');
    });

    test('voucher minimum is checked before the Kelopak discount', () {
      final engine = KelopakEngine(stateWithBalance(2000, tuesday));
      engine.claimPromoVoucher(
        promoId: 'payday',
        amount: 10000,
        minSpend: 100000,
        validDays: 7,
        today: tuesday,
      );
      final quote = engine.quote(
        request(<CheckoutLine>[line(otherCode, 100000)], voucherId: 'VP-0001'),
        today: tuesday,
      );
      expect(quote.voucherApplied, isTrue);
      expect(quote.kelopakUsed, 900);
      expect(quote.total, 0);
    });
  });

  group('K17: pending gifts ride with the next order', () {
    KelopakEngine engineWithGift() {
      final engine = KelopakEngine(KelopakState(), campaign: testCampaign());
      engine.spin(today: saturday, roll: 0, landingSeed: 1);
      expect(engine.pendingGifts, hasLength(1));
      return engine;
    }

    test('a gift needs at least one paid item', () {
      final engine = engineWithGift();
      final empty = engine.quote(
        request(const <CheckoutLine>[]),
        today: saturday,
      );
      expect(empty.hasPaidItems, isFalse);
      expect(empty.gifts, isEmpty);
      expect(empty.waitingGiftCount, 1);
      expect(empty.giftsBlocked, isTrue);
      expect(
        engine.problemWith(empty, today: saturday),
        CheckoutProblem.noPaidItems,
      );
      expect(
        (engine.commitOrder(orderId: 'BP-0', quote: empty, today: saturday)
                as OrderNotCommitted)
            .problem,
        CheckoutProblem.noPaidItems,
      );

      final paid = engine.quote(
        request(<CheckoutLine>[line(otherCode, 25000)], shippingFee: 9000),
        today: saturday,
      );
      expect(paid.giftsBlocked, isFalse);
      expect(paid.gifts.single.id, engine.pendingGifts.single.id);
      expect(paid.total, 34000);
    });

    test('commit attaches, ship ships, complete receives', () {
      final engine = engineWithGift();
      final gift = engine.pendingGifts.single;
      final order = place(engine, 'BP-1', <CheckoutLine>[
        line(otherCode, 25000),
      ], today: saturday);
      expect(order.giftIds, <String>[gift.id]);
      expect(engine.pendingGifts, isEmpty);
      expect(engine.giftById(gift.id)?.status, GiftStatus.attached);
      expect(engine.giftById(gift.id)?.orderId, 'BP-1');

      expect(engine.shipOrder('BP-1')?.status, KelopakOrderStatus.shipped);
      expect(engine.giftById(gift.id)?.status, GiftStatus.shipped);
      expect(engine.shipOrder('BP-1'), isNull);
      expect(engine.cancelOrder('BP-1', saturday), isNull);

      final done = engine.completeOrder('BP-1', saturday + 2)!;
      expect(done.gifts.single.status, GiftStatus.received);
      expect(engine.giftsOfOrder('BP-1').single.status, GiftStatus.received);
    });

    test('cancel returns Kelopak, voucher and gifts', () {
      final engine = engineWithGift()..grantKelopak(300, saturday);
      engine.claimPromoVoucher(
        promoId: 'payday',
        amount: 5000,
        minSpend: 20000,
        validDays: 7,
        today: saturday,
      );
      final order = place(
        engine,
        'BP-1',
        <CheckoutLine>[line(otherCode, 25000)],
        today: saturday,
        voucherId: 'VP-0001',
      );
      expect(order.voucherAmount, 5000);
      expect(order.kelopakUsed, 200);
      expect(engine.balance, 100);

      final cancellation = engine.cancelOrder('BP-1', saturday + 1)!;
      expect(cancellation.order.status, KelopakOrderStatus.cancelled);
      expect(cancellation.order.closedDay, saturday + 1);
      expect(cancellation.kelopakRefunded, 200);
      expect(cancellation.voucher?.id, 'VP-0001');
      expect(cancellation.voucher?.isUsed, isFalse);
      expect(cancellation.gifts.single.status, GiftStatus.pending);
      expect(engine.balance, 300);
      expect(engine.ledger.last.kind, LedgerKind.checkoutRefund);
      expect(engine.ledger.last.note, 'Dikembalikan dari pesanan #BP-1');
      expect(engine.ledger.last.orderId, 'BP-1');
      expect(engine.activeVouchers(saturday + 1), hasLength(1));
      expect(engine.pendingGifts, hasLength(1));
      expect(engine.cancelOrder('BP-1', saturday + 1), isNull);

      final again = place(
        engine,
        'BP-2',
        <CheckoutLine>[line(otherCode, 25000)],
        today: saturday + 1,
        voucherId: 'VP-0001',
      );
      expect(again.giftIds, hasLength(1));
      expect(again.voucherId, 'VP-0001');
    });

    test('a cancelled order without Kelopak books no refund line', () {
      final engine = KelopakEngine(KelopakState());
      place(engine, 'BP-1', <CheckoutLine>[
        line(otherCode, 25000),
      ], today: tuesday);
      final cancellation = engine.cancelOrder('BP-1', tuesday)!;
      expect(cancellation.kelopakRefunded, 0);
      expect(cancellation.voucher, isNull);
      expect(cancellation.gifts, isEmpty);
      expect(engine.ledger, isEmpty);
    });
  });

  group('commit', () {
    test('an outdated or empty quote cannot be committed', () {
      final engine = KelopakEngine(stateWithBalance(50, tuesday));

      final empty = engine.quote(
        request(const <CheckoutLine>[]),
        today: tuesday,
      );
      expect(
        engine.problemWith(empty, today: tuesday),
        CheckoutProblem.noPaidItems,
      );

      final quote = engine.quote(
        request(<CheckoutLine>[line(otherCode, 10000)]),
        today: tuesday,
      );
      engine.grantKelopak(100, tuesday);
      expect(
        engine.problemWith(quote, today: tuesday),
        CheckoutProblem.quoteOutdated,
      );
      final outcome = engine.commitOrder(
        orderId: 'BP-1',
        quote: quote,
        today: tuesday,
      );
      expect(
        (outcome as OrderNotCommitted).problem,
        CheckoutProblem.quoteOutdated,
      );
      expect(engine.orders, isEmpty);
      final fresh = engine.quote(quote.request, today: tuesday);
      expect(
        engine.problemWith(fresh, today: tuesday + 1),
        CheckoutProblem.quoteOutdated,
      );
      expect(engine.problemWith(fresh, today: tuesday), isNull);
    });

    test('committing the same quote twice is idempotent; another quote on '
        'the same id is a duplicate', () {
      final engine = KelopakEngine(stateWithBalance(50, tuesday));
      final quote = engine.quote(
        request(<CheckoutLine>[line(otherCode, 10000)]),
        today: tuesday,
      );
      final first =
          engine.commitOrder(orderId: 'BP-1', quote: quote, today: tuesday)
              as OrderCommitted;
      final repeat =
          engine.commitOrder(orderId: 'BP-1', quote: quote, today: tuesday)
              as OrderCommitted;
      expect(repeat.order, same(first.order));
      expect(engine.balance, 0);
      expect(engine.ledger, hasLength(2));

      final other = engine.quote(
        request(<CheckoutLine>[line(otherCode, 20000)]),
        today: tuesday,
      );
      expect(
        (engine.commitOrder(orderId: 'BP-1', quote: other, today: tuesday)
                as OrderNotCommitted)
            .problem,
        CheckoutProblem.duplicateOrder,
      );
      expect(
        () => engine.commitOrder(orderId: '', quote: other, today: tuesday),
        throwsArgumentError,
      );
    });

    test('orders and requests survive a JSON round trip', () {
      final engine = KelopakEngine(stateWithBalance(50, tuesday));
      final order = place(
        engine,
        'BP-1',
        <CheckoutLine>[line(otherCode, 10000, quantity: 2)],
        today: tuesday,
        shippingFee: 9000,
      );
      final json = order.toJson();
      expect(KelopakOrder.fromJson(json).toJson(), json);

      final original = request(
        <CheckoutLine>[line(otherCode, 10000)],
        shippingFee: 9000,
        voucherId: 'VP-0001',
        useKelopak: false,
      );
      final copy = CheckoutRequest.fromJson(original.toJson());
      expect(copy.toJson(), original.toJson());
      expect(copy.lines.single, original.lines.single);

      expect(
        () => KelopakOrder.fromJson(<String, Object?>{...json, 'total': -1}),
        throwsFormatException,
      );
      expect(
        () => CheckoutLine.fromJson(<String, Object?>{
          'productCode': 'x',
          'unitPrice': 1000,
          'quantity': 0,
        }),
        throwsFormatException,
      );
      expect(
        () => CheckoutRequest(lines: const <CheckoutLine>[], shippingFee: -1),
        throwsArgumentError,
      );
    });

    test('the token changes with every number that matters', () {
      final engine = KelopakEngine(stateWithBalance(50, tuesday));
      final base = request(<CheckoutLine>[line(otherCode, 10000)]);
      final token = engine.quote(base, today: tuesday).token;
      expect(engine.quote(base, today: tuesday).token, token);
      expect(engine.quote(base, today: tuesday + 1).token, isNot(token));
      expect(
        engine
            .quote(
              request(<CheckoutLine>[line(otherCode, 10000)], shippingFee: 1),
              today: tuesday,
            )
            .token,
        isNot(token),
      );
      expect(
        engine
            .quote(
              request(<CheckoutLine>[
                line(otherCode, 10000),
              ], useKelopak: false),
              today: tuesday,
            )
            .token,
        isNot(token),
      );
    });
  });
}
