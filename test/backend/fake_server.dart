import 'dart:convert';

import 'package:kelopak_hub/kelopak_hub.dart';

import '../domain/fixtures.dart';

/// Server tiruan: menjalankan [KelopakEngine] dan membalas lewat kodek yang
/// sama dengan kontrak, melewati teks JSON seperti jaringan sungguhan.
class FakeServer implements KelopakTransport {
  FakeServer({this.roll = 0});

  final KelopakEngine engine = KelopakEngine(
    KelopakState(),
    campaign: testCampaign(),
  );
  final List<KelopakAction> actions = <KelopakAction>[];
  final List<JsonMap> bodies = <JsonMap>[];
  int roll;
  Object? failure;
  JsonMap? cannedReply;

  @override
  Future<JsonMap> send(KelopakAction action, JsonMap body) async {
    actions.add(action);
    bodies.add(body);
    final error = failure;
    if (error != null) throw error;
    final canned = cannedReply;
    if (canned != null) return canned;
    final today = body['today'] as int? ?? tuesday;
    final orderId = body['orderId'] as String? ?? '';
    final JsonMap? result = switch (action) {
      KelopakAction.read => null,
      KelopakAction.checkIn => encodeCheckInOutcome(engine.claimCheckIn(today)),
      KelopakAction.spin => encodeSpinOutcome(
        engine.spin(today: today, roll: roll, landingSeed: 77),
      ),
      KelopakAction.claimPromo => encodePromoClaimOutcome(
        engine.claimPromoVoucher(
          promoId: body['promoId']! as String,
          amount: body['amount']! as int,
          minSpend: body['minSpend']! as int,
          validDays: body['validDays']! as int,
          title: body['title']! as String,
          today: today,
        ),
      ),
      KelopakAction.commit => _commit(body, orderId, today),
      KelopakAction.cancel => encodeCancellation(
        engine.cancelOrder(orderId, today),
      ),
      KelopakAction.ship => encodeShipment(engine.shipOrder(orderId)),
      KelopakAction.complete => encodeCompletion(
        engine.completeOrder(orderId, today),
      ),
    };
    final text = jsonEncode(<String, Object?>{
      'state': engine.state.toJson(),
      'result': ?result,
    });
    return jsonDecode(text) as JsonMap;
  }

  JsonMap _commit(JsonMap body, String orderId, int today) {
    final quote = engine.quote(
      CheckoutRequest.fromJson(body['request']),
      today: today,
    );
    if (quote.token != body['token']) {
      return encodeCommitOutcome(
        const OrderNotCommitted(CheckoutProblem.quoteOutdated),
      );
    }
    return encodeCommitOutcome(
      engine.commitOrder(orderId: orderId, quote: quote, today: today),
    );
  }
}
