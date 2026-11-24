import 'package:flutter_test/flutter_test.dart';
import 'package:kelopak_hub/domain/ledger.dart';
import 'package:kelopak_hub/domain/rewards_engine.dart';
import 'package:kelopak_hub/domain/shop_engine.dart';
import 'package:misi_belanja/misi_belanja.dart';

import '../support/test_app_state.dart';

const String soap = 'animate-brightening-soap-80g'; // Rp10.000
const String lipGlaze = 'gogotales-dusk-thick-mist-lip-glaze-g06'; // Rp35.000
const String palette = 'gogotales-crystal-slipper-palette-g03'; // Rp60.000
const String lipTint = 'somethinc-ombrella-lip-totem-tint-ikr'; // Rp70.800
const String cushion = 'somethinc-copy-paste-cushion-nina'; // Rp132.510

Order shippedOrder(String id, int subtotal, int day) => Order(
  id: id,
  lines: <OrderLine>[
    OrderLine(
      productId: soap,
      name: 'Produk uji',
      price: subtotal,
      qty: 1,
      imageAsset: 'assets/images/produk_bodysoap.webp',
    ),
  ],
  subtotal: subtotal,
  voucherDiscount: 0,
  kelopakUsed: 0,
  total: subtotal,
  status: OrderStatus.shipped,
  placedDay: day,
);

RewardsState stateWithBalance(int kelopak, int day) => RewardsState(
  ledger: <LedgerEntry>[
    LedgerEntry(
      id: 'L000001',
      wibDay: day,
      amount: kelopak,
      kind: LedgerKind.spinPrize,
      note: 'Saldo uji',
    ),
  ],
  ledgerSeq: 1,
);

void main() {
  final today = wibDayFor(2026, 11, 24);

  group('cart', () {
    test('adds, caps at 99, updates and removes with undo', () {
      final rewards = RewardsEngine(RewardsState());
      final shop = ShopEngine(ShopState(), rewards: rewards);

      expect(shop.add(soap), 1);
      expect(shop.add(lipGlaze, qty: 2), 2);
      expect(shop.cartCount, 3);
      expect(shop.cartSubtotal, 80000);

      expect(shop.add(soap, qty: 200), cartMaxQty);
      shop.setQty(soap, 3);
      expect(shop.quantityOf(soap), 3);

      final removed = shop.remove(soap)!;
      expect(removed.index, 0);
      expect(shop.quantityOf(soap), 0);
      shop.restore(removed);
      expect(shop.cart.first, const CartLine(productId: soap, qty: 3));

      shop.setQty(lipGlaze, 0);
      expect(shop.quantityOf(lipGlaze), 0);
      expect(() => shop.add('not-in-catalog'), throwsArgumentError);
    });

    test('drops stored lines whose product left the catalog', () {
      final rewards = RewardsEngine(RewardsState());
      final shop = ShopEngine(
        ShopState(
          cart: const <CartLine>[
            CartLine(productId: 'retired-product', qty: 2),
            CartLine(productId: soap, qty: 1),
          ],
        ),
        rewards: rewards,
      );
      expect(shop.cart, const <CartLine>[CartLine(productId: soap, qty: 1)]);
    });
  });

  group('Misi Belanja via markReceived', () {
    test('Rp74.999 does not qualify, Rp75.000 does', () {
      final rewards = RewardsEngine(RewardsState());
      final shop = ShopEngine(
        ShopState(
          orders: <Order>[
            shippedOrder('BP-20261124-0002', 75000, today),
            shippedOrder('BP-20261124-0001', 74999, today),
          ],
          orderSeq: 2,
        ),
        rewards: rewards,
      );

      final below = shop.markReceived('BP-20261124-0001', today)!;
      expect(below.order.status, OrderStatus.completed);
      expect(below.order.completedDay, today);
      expect(below.decision.issued, isFalse);
      expect(below.decision.rejection, OrderRejection.belowThreshold);
      expect(below.voucher, isNull);
      expect(rewards.missionIssuedCount, 0);

      final exact = shop.markReceived('BP-20261124-0002', today)!;
      expect(exact.decision.issued, isTrue);
      expect(exact.decision.issuedStage?.number, 1);
      final voucher = exact.voucher!;
      expect(voucher.amount, 10000);
      expect(voucher.minSpend, 100000);
      expect(voucher.sourceOrderId, 'BP-20261124-0002');
      expect(voucher.expiresDay, today + 30);
      expect(rewards.missionIssuedCount, 1);

      expect(shop.markReceived('BP-20261124-0002', today), isNull);
      expect(shop.markReceived('BP-unknown', today), isNull);
    });

    test(
      'voucher 1 unlocks stage 2; after the last stage orders are not counted',
      () {
        final rewards = RewardsEngine(RewardsState());
        final shop = ShopEngine(
          ShopState(
            orders: <Order>[
              shippedOrder('BP-C', 120000, today),
              shippedOrder('BP-B', 100000, today),
              shippedOrder('BP-A', 80000, today),
            ],
            orderSeq: 3,
          ),
          rewards: rewards,
        );
        expect(rewards.activeStage?.number, 1);

        shop.markReceived('BP-A', today);
        expect(rewards.activeStage?.number, 2);
        expect(rewards.allMissionStagesDone, isFalse);

        final second = shop.markReceived('BP-B', today + 1)!;
        expect(second.decision.issuedStage?.number, 2);
        expect(second.voucher?.amount, 5000);
        expect(second.voucher?.minSpend, 100000);
        expect(rewards.allMissionStagesDone, isTrue);
        expect(rewards.activeStage, isNull);

        final third = shop.markReceived('BP-C', today + 2)!;
        expect(third.decision.rejection, OrderRejection.allStagesDone);
        expect(third.voucher, isNull);
        expect(rewards.vouchers, hasLength(2));
        expect(rewards.countedOrderIds, <String>{'BP-A', 'BP-B', 'BP-C'});
      },
    );
  });

  group('checkout', () {
    test('voucher needs min. Rp100.000, never on its own order, used once', () {
      final rewards = RewardsEngine(RewardsState());
      final shop = ShopEngine(ShopState(), rewards: rewards);

      shop
        ..add(lipGlaze)
        ..add(soap, qty: 4);
      final first = shop.placeOrder(shop.quote(today: today));
      expect(first.id, 'BP-20261124-0001');
      expect(first.subtotal, 75000);
      expect(shop.isCartEmpty, isTrue);
      final voucher = shop.markReceived(first.id, today)!.voucher!;

      shop.add(lipTint);
      final below = shop.quote(voucherId: voucher.id, today: today);
      expect(below.voucherProblem, RedeemProblem.belowMinimum);
      expect(below.voucherApplied, isFalse);
      expect(below.voucherDiscount, 0);
      expect(below.total, 70800);

      expect(
        rewards.voucherProblem(
          voucherId: voucher.id,
          orderId: first.id,
          subtotal: 150000,
          today: today,
        ),
        RedeemProblem.sameOrder,
      );

      shop.add(palette);
      final ok = shop.quote(voucherId: voucher.id, today: today);
      expect(ok.subtotal, 130800);
      expect(ok.voucherApplied, isTrue);
      expect(ok.voucherDiscount, 10000);
      expect(ok.total, 120800);
      final second = shop.placeOrder(ok);
      expect(second.voucherId, voucher.id);
      expect(second.voucherDiscount, 10000);
      expect(second.total, 120800);
      expect(rewards.voucherById(voucher.id)?.usedOnOrderId, second.id);

      shop.add(cushion);
      final reused = shop.quote(voucherId: voucher.id, today: today);
      expect(reused.voucherProblem, RedeemProblem.alreadyUsed);
      expect(reused.voucherDiscount, 0);
      expect(reused.total, 132510);
    });

    test('Kelopak covers at most 50% and is booked as a debit', () {
      final rewards = RewardsEngine(stateWithBalance(500, today));
      final shop = ShopEngine(ShopState(), rewards: rewards);

      shop.add(soap);
      final quote = shop.quote(useKelopak: true, today: today);
      expect(quote.maxKelopak, 50);
      expect(quote.kelopakUsed, 50);
      expect(quote.kelopakDiscount, 5000);
      expect(quote.total, 5000);
      expect(quote.total * 2, quote.subtotal);

      final order = shop.placeOrder(quote);
      expect(order.kelopakUsed, 50);
      expect(order.kelopakDiscount, 5000);
      expect(rewards.balance, 450);
      expect(rewards.ledger.last.amount, -50);
      expect(rewards.ledger.last.kind, LedgerKind.checkoutSpend);
    });

    test(
      'a small balance is used fully and the total never drops below 50%',
      () {
        final rewards = RewardsEngine(stateWithBalance(10, today));
        final shop = ShopEngine(ShopState(), rewards: rewards)..add(soap);

        final quote = shop.quote(useKelopak: true, today: today);
        expect(quote.kelopakUsed, 10);
        expect(quote.total, 9000);
        expect(shop.quote(today: today).kelopakUsed, 0);

        shop.placeOrder(quote);
        expect(rewards.balance, 0);
        shop.add(soap);
        final empty = shop.quote(useKelopak: true, today: today);
        expect(empty.kelopakUsed, 0);
        expect(empty.total, 10000);
      },
    );

    test('an outdated or empty quote cannot be placed', () {
      final rewards = RewardsEngine(RewardsState());
      final shop = ShopEngine(ShopState(), rewards: rewards);

      final empty = shop.quote(today: today);
      expect(
        shop.problemWith(empty, today: today),
        PlaceOrderProblem.emptyCart,
      );
      expect(() => shop.placeOrder(empty), throwsStateError);

      shop.add(soap);
      final quote = shop.quote(today: today);
      shop.add(soap);
      expect(
        shop.problemWith(quote, today: today),
        PlaceOrderProblem.quoteOutdated,
      );
      expect(() => shop.placeOrder(quote), throwsStateError);
      final fresh = shop.quote(today: today);
      expect(
        shop.problemWith(fresh, today: today + 1),
        PlaceOrderProblem.quoteOutdated,
      );
      expect(shop.problemWith(fresh, today: today), isNull);
    });

    test('order numbers use the WIB date and a running number', () {
      expect(ShopEngine.orderIdFor(today, 7), 'BP-20261124-0007');
      expect(
        ShopEngine.orderIdFor(wibDayFor(2027, 1, 2), 12345),
        'BP-20270102-12345',
      );
    });

    test('shop state survives a JSON round trip', () {
      final rewards = RewardsEngine(RewardsState());
      final shop = ShopEngine(ShopState(), rewards: rewards)
        ..add(lipGlaze)
        ..add(soap, qty: 4);
      final order = shop.placeOrder(shop.quote(today: today));
      shop
        ..markReceived(order.id, today + 1)
        ..add(palette);
      final json = shop.state.toJson();
      expect(ShopState.fromJson(json).toJson(), json);
    });
  });
}
