import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kelopak_hub/kelopak_hub.dart';

import '../domain/fixtures.dart';
import 'v2_fixture.dart';

void main() {
  test('migrates balance, streak, spins, vouchers and product rights', () {
    final state = migrateV2Kelopak(
      jsonEncode(v2Document()),
      campaign: testCampaign(),
    )!;

    expect(state.balance, 7);
    expect(state.ledger, hasLength(3));
    expect(state.ledger.last.orderId, 'BP-20261128-0001');
    expect(state.ledger.first.orderId, isNull);
    expect(state.ledgerSeq, 3);
    expect(state.streak, 1);
    expect(state.lastClaimDay, tuesday);

    expect(state.gifts.map((gift) => gift.id), <String>['HG-0001', 'HG-0002']);
    final wheelGift = state.gifts.first;
    expect(wheelGift.source, GiftSource.wheel);
    expect(wheelGift.status, GiftStatus.pending);
    expect(wheelGift.wonDay, saturday + 7);
    expect(
      wheelGift.productCode,
      testCampaign().wheelProductCodeOn(saturday + 7),
    );
    expect(state.gifts.last.source, GiftSource.checkIn30);
    expect(state.gifts.last.productCode, checkIn30Code);
    expect(state.giftSeq, 2);

    expect(state.spins, hasLength(2));
    expect(state.spins.first.giftId, isNull);
    expect(state.spins.last.giftId, 'HG-0001');
    expect(state.wheelQuotaUsed, 1);
    expect(state.wheelQuotaWeek, KelopakCampaign.weekOf(saturday + 7));

    expect(state.missionIssuedCount, 1);
    expect(state.countedOrderIds, <String>{'BP-20261124-0001'});
    final voucher = state.vouchers.single;
    expect(voucher.kind, VoucherKind.mission);
    expect(voucher.stageNumber, 1);
    expect(voucher.amount, 10000);
    expect(voucher.expiresDay, tuesday + 30);
    expect(state.voucherSeq, 1);
    expect(state.orders, isEmpty);

    final engine = KelopakEngine(state, campaign: testCampaign());
    expect(engine.pendingGifts, hasLength(2));
    expect(engine.wheelQuotaLeft(saturday + 7), 2);
    expect(engine.activeStage?.number, 2);
  });

  test('the migrated state survives its own JSON round trip', () {
    final state = migrateV2Kelopak(jsonEncode(v2Document()))!;
    final json = state.toJson();
    expect(KelopakState.fromJson(json).toJson(), json);
  });

  test('a v2 document without rewards, or an empty one, gives null', () {
    expect(migrateV2Kelopak(null), isNull);
    expect(migrateV2Kelopak(''), isNull);
    final noRewards = v2Document()..remove('rewards');
    expect(migrateV2Kelopak(jsonEncode(noRewards)), isNull);
  });

  test('a corrupt or impossible v2 document gives null', () {
    final negative = v2Rewards()
      ..['ledger'] = <Object?>[
        <String, Object?>{
          'id': 'L000001',
          'wibDay': tuesday,
          'amount': -5,
          'kind': 'checkoutSpend',
          'note': 'Rusak',
        },
      ];
    final unknownSource = v2Rewards()
      ..['entitlements'] = <Object?>[
        <String, Object?>{'id': 'HP-0001', 'source': 'lottery', 'wibDay': 1},
      ];
    final variants = <String>[
      'not json',
      '[]',
      jsonEncode(<String, Object?>{...v2Document(), 'schema': 2}),
      jsonEncode(v2Document(rewards: negative)),
      jsonEncode(v2Document(rewards: unknownSource)),
      jsonEncode(v2Document(rewards: v2Rewards()..['streak'] = 'three')),
    ];
    for (final raw in variants) {
      expect(migrateV2Kelopak(raw), isNull, reason: raw);
    }
  });

  test('without product wins the wheel quota stays untouched', () {
    final rewards = v2Rewards()
      ..['spins'] = <Object?>[]
      ..['entitlements'] = <Object?>[]
      ..['productStock'] = 1;
    final state = migrateV2Kelopak(jsonEncode(v2Document(rewards: rewards)))!;
    expect(state.wheelQuotaUsed, 0);
    expect(state.wheelQuotaWeek, isNull);
    expect(state.gifts, isEmpty);
  });
}
