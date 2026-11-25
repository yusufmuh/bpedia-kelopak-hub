import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelopak_hub/kelopak_hub.dart';

import '../backend/fake_server.dart';
import '../domain/fixtures.dart';

const KelopakProduct missionProduct = KelopakProduct(
  code: 'P39A06S01000021',
  name: 'Animate Serum (uji)',
  price: 45000,
);
const KelopakProduct otherProduct = KelopakProduct(
  code: otherCode,
  name: 'Pinkflash Lip (uji)',
  price: 25000,
);

MemoryKelopakHost testHost({bool loggedIn = true}) => MemoryKelopakHost(
  products: <String, KelopakProduct>{
    missionProduct.code: missionProduct,
    otherProduct.code: otherProduct,
  },
  loggedIn: loggedIn,
);

Future<KelopakController> openController({
  KeyValueStore? store,
  DateTime Function()? now,
  WibClock? clock,
  List<int>? rolls,
  KelopakHost? host,
}) => KelopakController.open(
  backend: LocalKelopakBackend(
    store: store ?? MemoryKeyValueStore(),
    campaign: testCampaign(),
    random: ScriptedRandom(rolls ?? <int>[5000, 1]),
  ),
  clock: clock ?? WibClock(now: now ?? () => wibInstant(2026, 11, 24)),
  host: host,
  watchDayChange: false,
);

void main() {
  test('starts fresh on the injected WIB day', () async {
    final controller = await openController();
    addTearDown(controller.dispose);

    expect(controller.isLoaded, isTrue);
    expect(controller.today, tuesday);
    expect(controller.balance, 0);
    expect(controller.canCheckIn, isTrue);
    expect(controller.nextCheckInStreakDay, 1);
    expect(controller.isSaturday, isFalse);
    expect(controller.nextSaturday, saturday);
    expect(controller.nextSpinSaturday, saturday);
    expect(controller.nextWheelOpening.daysLeft, 4);
    expect(controller.nextWheelOpening.remainingLabel, '4 hari lagi');
    expect(
      controller.nextWheelOpening.opensAtLabel,
      'Sabtu, 28 Nov · 00.00 WIB',
    );
    expect(controller.spinEligibility, SpinEligibility.notSaturday);
    expect(controller.pendingGifts, isEmpty);
    expect(controller.activeMissionStage?.number, 1);
    expect(controller.isLoggedIn, isTrue);
  });

  test('a claim is saved and survives a reload', () async {
    final store = MemoryKeyValueStore();
    final controller = await openController(store: store);
    var notifications = 0;
    controller.addListener(() => notifications++);

    expect(await controller.claimCheckIn(), isA<CheckInClaimed>());
    expect(await controller.claimCheckIn(), isA<CheckInAlreadyClaimed>());
    expect(notifications, 1);
    await controller.flush();
    expect(store.values.containsKey(kelopakDocumentKey), isTrue);
    controller.dispose();

    final reloaded = await openController(store: store);
    addTearDown(reloaded.dispose);
    expect(reloaded.balance, 1);
    expect(reloaded.claimedToday, isTrue);
    expect(reloaded.nextCheckInStreakDay, 2);
    expect(reloaded.checkInWeekFilled, 1);
  });

  test('the WIB day turns over at 00.00 WIB', () async {
    final clock = FakeClock(wibInstant(2026, 11, 24, hour: 23, minute: 59));
    final controller = await openController(now: clock.now);
    addTearDown(controller.dispose);
    var notifications = 0;

    await controller.claimCheckIn();
    expect(controller.canCheckIn, isFalse);
    expect(controller.untilNextDay(), const Duration(minutes: 1));

    controller.addListener(() => notifications++);
    clock.advance(const Duration(minutes: 2));
    expect(controller.today, tuesday + 1);
    expect(controller.canCheckIn, isTrue);
    expect(controller.liveStreak, 1);
    controller.refreshDay();
    expect(notifications, 1);
    controller.refreshDay();
    expect(notifications, 1);
  });

  test('spins with the drawn roll and landing seed on Saturday', () async {
    final clock = WibClock(now: () => wibInstant(2026, 11, 24));
    final controller = await openController(clock: clock, rolls: <int>[0, 123]);
    addTearDown(controller.dispose);

    expect(await controller.spin(), isA<SpinRejected>());
    clock.demoOffsetDays = 4;
    expect(controller.today, saturday);
    expect(controller.canSpin, isTrue);
    expect(controller.spinOdds.first.percent, 5);

    final outcome = await controller.spin() as SpinCompleted;
    expect(outcome.record.roll, 0);
    expect(outcome.record.landingSeed, 123);
    expect(outcome.prize.kind, PrizeKind.product);
    expect(controller.todaySpin, outcome.record);
    expect(controller.prizeFor(outcome.record), outcome.prize);
    expect(controller.pendingGifts, hasLength(1));
    expect(controller.wheelQuotaLeft, 2);
    expect(controller.canSpin, isFalse);

    clock.demoOffsetDays = 11;
    expect(controller.today, saturday + 7);
    expect(controller.todaySpin, isNull);
    expect(controller.lastSpin, outcome.record);
  });

  test('demo tools need a backend that has them', () async {
    final controller = await openController();
    addTearDown(controller.dispose);

    expect(controller.hasDemoTools, isTrue);
    expect(await controller.setPromoActive(false), isTrue);
    expect(controller.spinEligibility, SpinEligibility.promoInactive);
    expect(await controller.setPromoActive(true), isTrue);
    expect(await controller.grantKelopak(500), isTrue);
    expect(controller.balance, 500);
    expect(await controller.setWheelQuotaLeft(0), isTrue);
    expect(controller.wheelQuotaLeft, 0);
    expect(await controller.refillWheelQuota(), isTrue);
    expect(controller.wheelQuotaLeft, 3);
    expect(await controller.resetAll(), isTrue);
    expect(controller.balance, 0);

    final remote = KelopakController(
      backend: RemoteKelopakBackend(
        transport: FakeServer(),
        campaign: testCampaign(),
      ),
      watchDayChange: false,
    );
    addTearDown(remote.dispose);
    await remote.load();
    expect(remote.hasDemoTools, isFalse);
    expect(await remote.grantKelopak(5), isFalse);
  });

  test('checkout commits, rejects stale quotes and completes the '
      'mission', () async {
    final clock = WibClock(now: () => wibInstant(2026, 11, 24));
    final host = testHost();
    final controller = await openController(clock: clock, host: host);
    addTearDown(controller.dispose);

    final empty = await controller.commitOrder(
      'BP-0',
      controller.quote(request(const <CheckoutLine>[])),
    );
    expect((empty as OrderNotCommitted).problem, CheckoutProblem.noPaidItems);

    await host.addToCart(missionProduct.code, quantity: 2);
    expect(controller.cartMissionProgress?.reached, isTrue);
    final stale = controller.quote(request(host.cartLines));
    expect(controller.quoteByToken(stale.token), same(stale));
    await controller.grantKelopak(10);
    expect(controller.problemWith(stale), CheckoutProblem.quoteOutdated);
    final outdated = await controller.commitOrder('BP-1', stale);
    expect(
      (outdated as OrderNotCommitted).problem,
      CheckoutProblem.quoteOutdated,
    );

    final placed =
        await controller.commitOrder(
              'BP-1',
              controller.quote(request(host.cartLines)),
            )
            as OrderCommitted;
    expect(placed.order.kelopakUsed, 10);
    expect(controller.view.ordersAwaitingMission, <KelopakOrder>[placed.order]);

    final completion = (await controller.completeOrder('BP-1'))!;
    expect(completion.decision.issued, isTrue);
    expect(controller.activeVouchers.single.id, completion.voucher!.id);
    expect(controller.missionIssuedCount, 1);
    expect(controller.view.ordersAwaitingMission, isEmpty);
    expect(
      controller.voucherProblemFor(completion.voucher!, 70800),
      RedeemProblem.belowMinimum,
    );

    clock.demoOffsetDays = 30;
    expect(controller.activeVouchers, hasLength(1));
    clock.demoOffsetDays = 31;
    expect(controller.activeVouchers, isEmpty);
    expect(controller.vouchers, hasLength(1));
  });

  test('ledger history runs newest first with the running balance', () async {
    final clock = WibClock(now: () => wibInstant(2026, 11, 24));
    final controller = await openController(clock: clock);
    addTearDown(controller.dispose);
    for (var day = 0; day < 7; day++) {
      await controller.claimCheckIn();
      clock.demoOffsetDays++;
    }
    final history = controller.ledgerHistory;
    expect(history.first.balanceAfter, 10);
    expect(history.first.entry.amount, 3);
    expect(history.last.balanceAfter, 1);
  });

  test('syncFromStore picks up a newer save once', () async {
    final store = MemoryKeyValueStore();
    final tabA = await openController(store: store);
    final tabB = await openController(store: store);
    addTearDown(tabA.dispose);
    addTearDown(tabB.dispose);
    var notified = 0;
    tabB.addListener(() => notified++);

    expect(await tabB.syncFromStore(), isFalse);
    await tabA.claimCheckIn();
    await tabA.flush();

    expect(await tabB.syncFromStore(), isTrue);
    expect(tabB.balance, 1);
    expect(tabB.claimedToday, isTrue);
    expect(tabB.adoptedUpdates, 1);
    expect(notified, 1);
    expect(await tabB.syncFromStore(), isFalse);
  });

  test('a stale tab cannot claim the same day twice', () async {
    final store = MemoryKeyValueStore();
    final tabA = await openController(store: store);
    final tabB = await openController(store: store);
    addTearDown(tabA.dispose);
    addTearDown(tabB.dispose);

    await tabA.claimCheckIn();
    expect(await tabB.claimCheckIn(), isA<CheckInAlreadyClaimed>());
    expect(tabB.balance, 1);
  });

  group('Roda Sabtu opening: one wording everywhere', () {
    test('whole calendar days until the day before, then clock time', () async {
      final clock = FakeClock(wibInstant(2026, 11, 25, hour: 2));
      final controller = await openController(now: clock.now);
      addTearDown(controller.dispose);

      var opening = controller.nextWheelOpening;
      expect(opening.day, saturday);
      expect(opening.daysLeft, 3);
      expect(opening.remainingLabel, '3 hari lagi');
      expect(opening.opensAtLabel, 'Sabtu, 28 Nov · 00.00 WIB');
      expect(opening.dayLabel, 'Sabtu, 28 Nov');

      clock.current = wibInstant(2026, 11, 27, hour: 1, minute: 20);
      opening = controller.nextWheelOpening;
      expect(opening.daysLeft, 1);
      expect(opening.remainingLabel, '22 jam 40 menit lagi');
      expect(opening.countsClockTime, isTrue);

      clock.current = wibInstant(2026, 11, 27, hour: 23, minute: 30);
      expect(controller.nextWheelOpening.remainingLabel, '30 menit lagi');

      clock.current = wibInstant(2026, 11, 27, hour: 23, minute: 59);
      expect(controller.nextWheelOpening.remainingLabel, '1 menit lagi');
      clock.advance(const Duration(seconds: 30));
      expect(
        controller.nextWheelOpening.remainingLabel,
        'kurang dari 1 menit lagi',
      );

      clock.current = wibInstant(2026, 12, 7, hour: 1, minute: 20);
      expect(controller.nextWheelOpening.remainingLabel, '5 hari lagi');
    });
  });

  group('device clock moved back', () {
    test('the next check-in is the day after the future-dated claim', () async {
      final clock = FakeClock(wibInstant(2026, 11, 30));
      final controller = await openController(now: clock.now);
      addTearDown(controller.dispose);
      expect(controller.nextCheckInDay, controller.today);
      await controller.claimCheckIn();
      expect(controller.nextCheckInDay, wibDayFor(2026, 12, 1));

      clock.current = wibInstant(2026, 11, 25);
      expect(controller.canCheckIn, isFalse);
      expect(controller.nextCheckInDay, wibDayFor(2026, 12, 1));
      clock.current = wibInstant(2026, 11, 26);
      expect(controller.canCheckIn, isFalse);
      clock.current = wibInstant(2026, 12, 1);
      expect(controller.canCheckIn, isTrue);
    });

    test('the next spin Saturday comes after the future-dated spin', () async {
      final clock = FakeClock(wibInstant(2026, 11, 28));
      final controller = await openController(
        now: clock.now,
        rolls: <int>[5000, 1],
      );
      addTearDown(controller.dispose);
      expect(await controller.spin(), isA<SpinCompleted>());
      expect(controller.nextSpinSaturday, wibDayFor(2026, 12, 5));

      clock.current = wibInstant(2026, 11, 21);
      expect(controller.spinEligibility, SpinEligibility.alreadySpun);
      expect(controller.nextSaturday, saturday);
      expect(controller.nextSpinSaturday, wibDayFor(2026, 12, 5));
      expect(controller.nextWheelOpening.remainingLabel, '14 hari lagi');

      clock.current = wibInstant(2026, 11, 25);
      expect(controller.spinEligibility, SpinEligibility.notSaturday);
      expect(controller.nextSpinSaturday, wibDayFor(2026, 12, 5));

      clock.current = wibInstant(2026, 11, 28);
      expect(controller.spinEligibility, SpinEligibility.alreadySpun);
      expect(controller.nextSpinSaturday, wibDayFor(2026, 12, 5));
    });
  });

  test('stockForSpin is the quota the wheel was spun with', () async {
    final controller = await openController(
      now: () => wibInstant(2026, 11, 28),
      rolls: <int>[0, 7],
    );
    addTearDown(controller.dispose);
    final outcome = await controller.spin() as SpinCompleted;
    expect(controller.wheelQuotaLeft, 2);
    expect(controller.stockForSpin(outcome.record), 3);
    expect(controller.oddsForSpin(outcome.record).first.weight, 500);
  });

  group('events', () {
    test('every reward action emits one event to the stream and the '
        'host', () async {
      final clock = WibClock(now: () => wibInstant(2026, 11, 28));
      final host = testHost();
      final controller = await openController(
        clock: clock,
        host: host,
        rolls: <int>[0, 9],
      );
      addTearDown(controller.dispose);
      final events = <KelopakEvent>[];
      controller.events.listen(events.add);

      await controller.claimCheckIn();
      final spun = await controller.spin() as SpinCompleted;
      await controller.claimPromoVoucher(
        promoId: 'payday',
        amount: 5000,
        minSpend: 20000,
        validDays: 7,
      );
      await host.addToCart(missionProduct.code, quantity: 2);
      final quote = controller.quote(
        request(host.cartLines, voucherId: controller.activeVouchers.single.id),
      );
      await controller.commitOrder('BP-1', quote);
      await controller.commitOrder('BP-1', quote);
      await controller.shipOrder('BP-1');
      await controller.completeOrder('BP-1');

      expect(events.map((event) => event.runtimeType), <Type>[
        CheckInClaimedEvent,
        WheelSpunEvent,
        PromoVoucherClaimedEvent,
        VoucherRedeemedEvent,
        KelopakRedeemedEvent,
        GiftAttachedEvent,
        GiftsShippedEvent,
        GiftsReceivedEvent,
        MissionCompletedEvent,
      ]);
      expect(host.events, events);
      expect(
        events.map((event) => event.analyticsName).whereType<String>(),
        <String>[
          'bp_checkin_claim',
          'bp_wheel_spin',
          'bp_voucher_redeem',
          'bp_kelopak_redeem',
          'bp_gift_attached',
          'bp_mission_complete',
        ],
      );
      expect((events[1] as WheelSpunEvent).gift?.id, spun.gift?.id);
      final redeemed = events[4] as KelopakRedeemedEvent;
      expect(redeemed.parameters, <String, Object>{
        'order_id': 'BP-1',
        'kelopak': 1,
        'value': 100,
      });
      final mission = events.last as MissionCompletedEvent;
      expect(mission.stageNumber, 1);
      expect(mission.notice.route, KelopakPaths.vouchers);
      expect(mission.notice.title, 'Misi Belanja tahap 1 tuntas');
    });

    test('cancel emits a refund with Kelopak, voucher and gifts', () async {
      final host = testHost();
      final controller = await openController(
        now: () => wibInstant(2026, 11, 28),
        host: host,
        rolls: <int>[0, 9],
      );
      addTearDown(controller.dispose);
      await controller.spin();
      await controller.grantKelopak(50);
      await host.addToCart(otherProduct.code);
      await controller.commitOrder(
        'BP-1',
        controller.quote(request(host.cartLines)),
      );
      expect(controller.balance, 0);
      expect(controller.pendingGifts, isEmpty);

      final events = <KelopakEvent>[];
      controller.events.listen(events.add);
      final cancellation = (await controller.cancelOrder('BP-1'))!;
      final refund = events.single as OrderRefundedEvent;
      expect(refund.kelopak, 50);
      expect(refund.gifts, cancellation.gifts);
      expect(refund.hasRefund, isTrue);
      expect(controller.balance, 50);
      expect(controller.pendingGifts, hasLength(1));
      expect(await controller.cancelOrder('BP-1'), isNull);
      expect(events, hasLength(1));
    });
  });

  group('host', () {
    test('guests are sent to login and the host cart drives the '
        'mission bar', () async {
      final host = testHost(loggedIn: false);
      final controller = await openController(host: host);
      addTearDown(controller.dispose);
      var notified = 0;
      controller.addListener(() => notified++);

      expect(controller.isLoggedIn, isFalse);
      expect(controller.ensureLoggedIn(), isFalse);
      expect(host.navigations, <String>['login']);
      host.isLoggedIn = true;
      expect(notified, 1);
      expect(controller.ensureLoggedIn(), isTrue);

      expect(controller.missionProducts, <KelopakProduct>[missionProduct]);
      expect(controller.productOf(otherCode), otherProduct);
      expect(controller.productOf(null), isNull);
      expect(controller.checkIn30Product, isNull);
      expect(controller.cartMissionProgress?.current, 0);
      await host.addToCart(otherProduct.code);
      expect(controller.cartMissionProgress?.current, 0);
      await host.addToCart(missionProduct.code);
      expect(controller.cartMissionProgress?.current, 45000);
      expect(controller.cartMissionProgress?.remaining, 30000);
      expect(notified, 3);
      expect(await host.addToCart('unknown'), isFalse);
    });

    test('a backend failure is kept as lastError and rethrown', () async {
      final server = FakeServer();
      final controller = KelopakController(
        backend: RemoteKelopakBackend(
          transport: server,
          campaign: testCampaign(),
        ),
        clock: WibClock(now: () => wibInstant(2026, 11, 24)),
        watchDayChange: false,
      );
      addTearDown(controller.dispose);
      await controller.load();
      server.failure = StateError('offline');
      await expectLater(
        controller.claimCheckIn(),
        throwsA(isA<KelopakBackendException>()),
      );
      expect(
        controller.lastError?.message,
        RemoteKelopakBackend.offlineMessage,
      );
      server.failure = null;
      await controller.claimCheckIn();
      expect(controller.lastError, isNull);
      expect(controller.balance, 1);
    });
  });

  testWidgets('KelopakScope rebuilds dependents and reads without '
      'listening', (tester) async {
    final controller = await tester.runAsync(openController);
    addTearDown(controller!.dispose);
    var builds = 0;

    await tester.pumpWidget(
      KelopakScope(
        controller: controller,
        child: Builder(
          builder: (context) {
            builds++;
            final balance = KelopakScope.of(context).balance;
            expect(KelopakScope.read(context), same(controller));
            return Text('$balance', textDirection: TextDirection.ltr);
          },
        ),
      ),
    );
    expect(find.text('0'), findsOneWidget);
    await tester.runAsync(() => controller.grantKelopak(7));
    await tester.pump();
    expect(find.text('7'), findsOneWidget);
    expect(builds, 2);

    await tester.pumpWidget(
      Builder(
        builder: (context) {
          expect(KelopakScope.maybeRead(context), isNull);
          expect(() => KelopakScope.of(context), throwsFlutterError);
          return const SizedBox();
        },
      ),
    );
  });
}
