import 'package:daily_checkin/daily_checkin.dart' as checkin;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelopak_hub/kelopak_hub.dart';
import 'package:misi_belanja/misi_belanja.dart' as misi;
import 'package:roda_sabtu/roda_sabtu.dart' as roda;

import 'hub_harness.dart';

class _Reminder implements KelopakReminder {
  bool on = false;

  @override
  bool get isSupported => true;

  @override
  Future<bool> isEnabled() async => on;

  @override
  Future<bool> setEnabled(bool enabled) async => on = enabled;
}

class _ActionsHost extends MemoryKelopakHost implements KelopakGameActions {
  _ActionsHost() : super(products: demoCatalog(), reminder: _Reminder());

  final List<String> actions = <String>[];
  bool sound = true;

  @override
  void openCheckout() => actions.add('checkout');

  @override
  void openOrder(String orderId) => actions.add('order:$orderId');

  @override
  Future<bool> setCartQuantity(String productCode, int quantity) async {
    actions.add('qty:$productCode:$quantity');
    return true;
  }

  @override
  bool? get soundOn => sound;

  @override
  void setSoundOn(bool value) => sound = value;
}

Future<KelopakController> _open(KelopakHost host, DateTime now) =>
    KelopakController.open(
      backend: LocalKelopakBackend(
        store: MemoryKeyValueStore(),
        campaign: demoCampaign(),
        random: ScriptedRandom(const <int>[0]),
      ),
      clock: WibClock(now: () => now),
      host: host,
      watchDayChange: false,
    );

void main() {
  group('KelopakCheckInController', () {
    test('reads the engine and claims through the backend', () async {
      final fixture = await openHub();
      final c = fixture.controller;
      final game = KelopakCheckInController(c);
      addTearDown(() {
        game.dispose();
        c.dispose();
      });

      expect(game.state.signedIn, isTrue);
      expect(game.state.claimedToday, isFalse);
      expect(game.state.rewardProduct?.code, 'P39A06S01000089');
      expect(game.state.soundOn, isNull);

      var notified = 0;
      game.addListener(() => notified++);
      final result = await game.claim();

      expect(result, isNotNull);
      expect(result!.award.totalKelopak, 1);
      expect(result.balance, 1);
      expect(game.state.claimedToday, isTrue);
      expect(game.state.balance, 1);
      expect(c.balance, 1);
      expect(notified, greaterThan(0));
      expect(await game.claim(), isNull);
    });

    test('a guest is sent to login and nothing is claimed', () async {
      final fixture = await openHub(loggedIn: false);
      final game = KelopakCheckInController(fixture.controller);
      addTearDown(() {
        game.dispose();
        fixture.controller.dispose();
      });

      expect(game.state.signedIn, isFalse);
      expect(await game.claim(), isNull);
      expect(fixture.host.navigations, <String>['login']);
      expect(fixture.controller.balance, 0);
    });

    test(
      'module cues reach the host as hub cues, terms open the sheet',
      () async {
        final fixture = await openHub();
        var terms = 0;
        final game = KelopakCheckInController(
          fixture.controller,
          onOpenTerms: () => terms++,
        );
        addTearDown(() {
          game.dispose();
          fixture.controller.dispose();
        });

        game
          ..playCue(checkin.GameCue.claim)
          ..playCue(checkin.GameCue.bonus)
          ..openCart()
          ..openProduct('P39A06S01000089')
          ..openTerms();

        expect(fixture.host.cues, <GameCue>[GameCue.claim, GameCue.bonus]);
        expect(fixture.host.navigations, <String>[
          'cart',
          'product:P39A06S01000089',
        ]);
        expect(terms, 1);
      },
    );

    test('day 30 returns the gift product', () async {
      final fixture = await openHub(now: wibAt(2026, 10, 27));
      final c = fixture.controller;
      final game = KelopakCheckInController(c);
      addTearDown(() {
        game.dispose();
        c.dispose();
      });
      checkin.CheckInClaimResult? last;
      for (var day = 0; day < 30; day++) {
        c.clock.demoOffsetDays = day;
        last = await game.claim();
      }
      expect(last!.award.productEntitled, isTrue);
      expect(last.product?.code, 'P39A06S01000089');
      expect(c.pendingGifts, hasLength(1));
    });
  });

  group('KelopakWheelController', () {
    test('is closed on Thursday and spins on Saturday', () async {
      final fixture = await openHub(rolls: const <int>[0]);
      final c = fixture.controller;
      final game = KelopakWheelController(c);
      addTearDown(() {
        game.dispose();
        c.dispose();
      });

      expect(game.state.eligibility, roda.SpinEligibility.notSaturday);
      expect(await game.spin(), isNull);
      expect(game.state.reminderSupported, isFalse);

      fixture.shiftDays(2);
      expect(game.state.eligibility, roda.SpinEligibility.available);
      expect(game.now().difference(c.clock.now()).inDays, 2);

      final result = await game.spin();
      expect(result, isNotNull);
      expect(result!.prize.kind, roda.PrizeKind.product);
      expect(result.product?.code, isNotNull);
      expect(game.state.history, hasLength(1));
      expect(game.state.history.single.productName, result.product!.name);
      expect(game.state.eligibility, roda.SpinEligibility.alreadySpun);
      expect(c.pendingGifts, hasLength(1));
    });

    test('the reminder goes through KelopakHost.reminder', () async {
      final host = _ActionsHost();
      final c = await _open(host, wibAt(2026, 11, 26));
      final game = KelopakWheelController(c);
      addTearDown(() {
        game.dispose();
        c.dispose();
      });
      await Future<void>.delayed(Duration.zero);

      expect(game.state.reminderSupported, isTrue);
      expect(game.state.reminderOn, isFalse);
      await game.setReminder(true);
      expect(game.state.reminderOn, isTrue);
      expect(game.state.soundOn, isTrue);
      game.setSoundOn(false);
      expect(host.sound, isFalse);
      expect(game.state.soundOn, isFalse);
      game.playCue(roda.GameCue.winProduct);
      expect(host.cues, <GameCue>[GameCue.winProduct]);
    });
  });

  group('KelopakMissionController', () {
    test('shows campaign products and the host cart', () async {
      final fixture = await openHub();
      final game = KelopakMissionController(fixture.controller);
      addTearDown(() {
        game.dispose();
        fixture.controller.dispose();
      });

      expect(game.state.products.map((product) => product.code), stageOneCodes);
      expect(game.state.phase, misi.MissionPhase.notStarted);

      expect(await game.addToCart('P39A06S01000007'), isTrue);
      await game.setQuantity('P39A06S01000007', 3);
      expect(game.state.quantityOf('P39A06S01000007'), 3);
      expect(game.state.progress!.current, 78000);
      expect(game.state.phase, misi.MissionPhase.ready);

      await game.setQuantity('P39A06S01000007', 1);
      expect(fixture.host.navigations.last, 'cart');
    });

    test(
      'a hidden mission page leaves the celebration to whoever shows it first',
      () async {
        final fixture = await openHub();
        final c = fixture.controller;
        final game = KelopakMissionController(c)..visible = false;
        addTearDown(() {
          game.dispose();
          c.dispose();
        });
        Future<void> completeMission(
          String orderId,
          String code,
          int price,
          int quantity,
        ) async {
          final quote = c.quote(
            CheckoutRequest(
              lines: <CheckoutLine>[
                CheckoutLine(
                  productCode: code,
                  unitPrice: price,
                  quantity: quantity,
                ),
              ],
              shippingFee: 9000,
              useKelopak: false,
            ),
          );
          await c.commitOrder(orderId, quote);
          await c.completeOrder(orderId);
          await Future<void>.delayed(Duration.zero);
        }

        await completeMission('BP-1', 'P39A06S01000007', 26000, 3);
        expect(game.state.celebration, isNull);
        final first = c.vouchers.single;
        expect(c.claimMissionCelebration(first.id), isTrue);
        game.visible = true;
        expect(game.state.celebration, isNull);

        game.visible = false;
        await completeMission('BP-2', 'P21F02C01000031', 49091, 3);
        expect(game.state.celebration, isNull);
        game.visible = true;
        expect(game.state.celebration?.stage.number, 2);
        final second = c.vouchers.firstWhere((v) => v.id != first.id);
        expect(c.claimMissionCelebration(second.id), isFalse);
      },
    );

    test('an order completed elsewhere raises the celebration once', () async {
      final fixture = await openHub();
      final c = fixture.controller;
      final paths = <String>[];
      final game = KelopakMissionController(c, onOpenPath: paths.add);
      addTearDown(() {
        game.dispose();
        c.dispose();
      });

      final quote = c.quote(
        CheckoutRequest(
          lines: const <CheckoutLine>[
            CheckoutLine(
              productCode: 'P39A06S01000007',
              unitPrice: 26000,
              quantity: 3,
            ),
          ],
          shippingFee: 9000,
          useKelopak: false,
        ),
      );
      await c.commitOrder('BP-1', quote);
      expect(game.state.pendingOrder?.orderId, 'BP-1');
      expect(game.state.pendingOrder?.missionSubtotal, 78000);
      expect(game.state.phase, misi.MissionPhase.awaitingCompletion);

      await c.completeOrder('BP-1');
      expect(game.state.celebration?.stage.number, 1);
      expect(game.state.celebration?.nextStage?.number, 2);
      expect(game.state.vouchers, hasLength(1));
      expect(game.state.issuedCount, 1);

      game.acknowledgeCelebration();
      expect(game.state.celebration, isNull);

      game
        ..openVouchers()
        ..useVoucher(game.state.vouchers.single.id)
        ..openOrder('BP-1');
      expect(paths, <String>[KelopakPaths.vouchers]);
      expect(fixture.host.navigations, <String>['cart', 'cart']);
    });

    test(
      'a host with KelopakGameActions gets checkout, order and quantity',
      () async {
        final host = _ActionsHost();
        final c = await _open(host, wibAt(2026, 11, 26));
        final game = KelopakMissionController(c);
        addTearDown(() {
          game.dispose();
          c.dispose();
        });

        game
          ..openCheckout()
          ..openOrder('BP-9');
        await game.setQuantity('P39A06S01000021', 2);
        expect(host.actions, <String>[
          'checkout',
          'order:BP-9',
          'qty:P39A06S01000021:2',
        ]);
        game.playCue(misi.GameCue.missionDone);
        expect(host.cues, <GameCue>[GameCue.missionDone]);
      },
    );

    test(
      'guests fill the cart without login but get no mission progress',
      () async {
        final fixture = await openHub(loggedIn: false);
        final game = KelopakMissionController(fixture.controller);
        addTearDown(() {
          game.dispose();
          fixture.controller.dispose();
        });

        expect(game.state.signedIn, isFalse);
        expect(game.state.products, isNotEmpty);
        expect(await game.addToCart('P39A06S01000007'), isTrue);
        await game.setQuantity('P39A06S01000007', 2);
        expect(fixture.host.navigations, isEmpty);
        expect(
          fixture.host.cartLines.single,
          isA<CheckoutLine>()
              .having((line) => line.productCode, 'code', 'P39A06S01000007')
              .having((line) => line.quantity, 'quantity', 2),
        );
        expect(game.state.signedIn, isFalse);
        expect(fixture.controller.vouchers, isEmpty);
        expect(fixture.controller.missionIssuedCount, 0);
      },
    );
  });

  test('the controllers stop listening after dispose', () async {
    final fixture = await openHub();
    final c = fixture.controller;
    final games = <ChangeNotifier>[
      KelopakCheckInController(c),
      KelopakWheelController(c),
      KelopakMissionController(c),
    ];
    for (final game in games) {
      game.dispose();
    }
    await c.claimCheckIn();
    expect(c.balance, 1);
    c.dispose();
  });
}
