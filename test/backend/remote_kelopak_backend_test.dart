import 'package:flutter_test/flutter_test.dart';
import 'package:kelopak_hub/kelopak_hub.dart';

import '../domain/fixtures.dart';
import 'fake_server.dart';

void main() {
  late FakeServer server;
  late RemoteKelopakBackend backend;

  setUp(() {
    server = FakeServer();
    backend = RemoteKelopakBackend(transport: server, campaign: testCampaign());
  });

  test('every action maps to one documented endpoint', () {
    expect(
      <String>[
        for (final action in KelopakAction.values)
          '${action.method} ${action.path}',
      ],
      <String>[
        'GET /kelopak/state',
        'POST /kelopak/check-in',
        'POST /kelopak/wheel/spin',
        'POST /kelopak/vouchers/promo',
        'POST /kelopak/orders/commit',
        'POST /kelopak/orders/cancel',
        'POST /kelopak/orders/ship',
        'POST /kelopak/orders/complete',
      ],
    );
    expect(backend.demoTools, isNull);
  });

  test('load, check-in and refresh follow the server state', () async {
    expect((await backend.load()).balance, 0);
    expect(await backend.refresh(), isNull);

    final reply = await backend.claimCheckIn(today: tuesday);
    final claimed = reply.value as CheckInClaimed;
    expect(claimed.award.streak, 1);
    expect(claimed.newBalance, 1);
    expect(reply.state.balance, 1);
    expect(server.bodies.last, <String, Object?>{'today': tuesday});

    final again = await backend.claimCheckIn(today: tuesday);
    expect(again.value, isA<CheckInAlreadyClaimed>());

    server.engine.grantKelopak(5, tuesday);
    expect((await backend.refresh())?.balance, 6);
    expect(await backend.refresh(), isNull);
  });

  test('a spin result is rebuilt from the state in the reply', () async {
    final weekday = await backend.spin(today: tuesday);
    expect(
      (weekday.value as SpinRejected).eligibility,
      SpinEligibility.notSaturday,
    );
    final reply = await backend.spin(today: saturday);
    final outcome = reply.value as SpinCompleted;
    expect(outcome.prize.kind, PrizeKind.product);
    expect(outcome.record.landingSeed, 77);
    expect(outcome.gift?.id, reply.state.gifts.single.id);
    expect(outcome.odds.first.weight, 500);
  });

  test('promo voucher, commit, ship and complete round trip', () async {
    final promo = await backend.claimPromoVoucher(
      promoId: 'payday',
      amount: 5000,
      minSpend: 20000,
      validDays: 7,
      title: 'Voucher Payday',
      today: tuesday,
    );
    final voucher = (promo.value as PromoVoucherClaimed).voucher;
    expect(voucher.title, 'Voucher Payday');
    final repeat = await backend.claimPromoVoucher(
      promoId: 'payday',
      amount: 5000,
      minSpend: 20000,
      validDays: 7,
      title: 'Voucher Payday',
      today: tuesday,
    );
    expect(
      (repeat.value as PromoVoucherNotClaimed).problem,
      PromoClaimProblem.alreadyClaimed,
    );

    await backend.spin(today: saturday);
    final state = await backend.load();
    final quote = KelopakView(state, campaign: backend.campaign).quote(
      request(<CheckoutLine>[
        line(missionCodes[0], 80000),
      ], voucherId: voucher.id),
      today: saturday,
    );
    final committed = await backend.commitOrder(
      orderId: 'BP-1',
      quote: quote,
      today: saturday,
    );
    final order = (committed.value as OrderCommitted).order;
    expect(order.voucherAmount, 5000);
    expect(order.giftIds, hasLength(1));
    expect(server.bodies.last['token'], quote.token);

    final shipped = await backend.shipOrder(orderId: 'BP-1');
    expect(shipped.value?.status, KelopakOrderStatus.shipped);
    final completed = await backend.completeOrder(
      orderId: 'BP-1',
      today: saturday + 3,
    );
    final completion = completed.value!;
    expect(completion.decision.issuedStage?.number, 1);
    expect(completion.voucher?.kind, VoucherKind.mission);
    expect(completion.gifts.single.status, GiftStatus.received);

    final none = await backend.completeOrder(orderId: 'BP-1', today: saturday);
    expect(none.value, isNull);
    expect((await backend.shipOrder(orderId: 'BP-9')).value, isNull);
  });

  test('a stale quote is refused and cancel returns everything', () async {
    server.engine.grantKelopak(100, tuesday);
    final state = await backend.load();
    final view = KelopakView(state, campaign: backend.campaign);
    final quote = view.quote(
      request(<CheckoutLine>[line(otherCode, 25000)]),
      today: tuesday,
    );
    server.engine.grantKelopak(1, tuesday);
    final refused = await backend.commitOrder(
      orderId: 'BP-1',
      quote: quote,
      today: tuesday,
    );
    expect(
      (refused.value as OrderNotCommitted).problem,
      CheckoutProblem.quoteOutdated,
    );

    final fresh = KelopakView(
      refused.state,
      campaign: backend.campaign,
    ).quote(quote.request, today: tuesday);
    final committed = await backend.commitOrder(
      orderId: 'BP-1',
      quote: fresh,
      today: tuesday,
    );
    expect(committed.value, isA<OrderCommitted>());
    expect(committed.state.balance, 0);

    final cancelled = await backend.cancelOrder(
      orderId: 'BP-1',
      today: tuesday,
    );
    expect(cancelled.value?.kelopakRefunded, 101);
    expect(cancelled.state.balance, 101);
    expect(
      (await backend.cancelOrder(orderId: 'BP-1', today: tuesday)).value,
      isNull,
    );
  });

  test('transport failures and unreadable replies become '
      'KelopakBackendException', () async {
    server.failure = StateError('offline');
    await expectLater(
      backend.load(),
      throwsA(
        isA<KelopakBackendException>()
            .having(
              (error) => error.message,
              'message',
              RemoteKelopakBackend.offlineMessage,
            )
            .having((error) => error.cause, 'cause', isA<StateError>()),
      ),
    );

    server
      ..failure = null
      ..cannedReply = <String, Object?>{'state': 'broken'};
    await expectLater(
      backend.claimCheckIn(today: tuesday),
      throwsA(isA<KelopakBackendException>()),
    );

    server.cannedReply = <String, Object?>{
      'state': KelopakState().toJson(),
      'result': <String, Object?>{'spun': true, 'wibDay': saturday},
    };
    await expectLater(
      backend.spin(today: saturday),
      throwsA(
        isA<KelopakBackendException>().having(
          (error) => error.message,
          'message',
          'Balasan server tidak bisa dibaca.',
        ),
      ),
    );

    server.cannedReply = <String, Object?>{
      'state': KelopakState().toJson(),
      'result': <String, Object?>{'spun': false, 'reason': 'available'},
    };
    await expectLater(
      backend.spin(today: saturday),
      throwsA(isA<KelopakBackendException>()),
    );
  });
}
