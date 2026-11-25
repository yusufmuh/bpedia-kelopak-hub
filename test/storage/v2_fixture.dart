import 'package:misi_belanja/misi_belanja.dart' show MissionVoucher;

import '../domain/fixtures.dart';

/// Dokumen app v2 (`bpedia_preview_state_v1`) seperti yang ditulis
/// `AppSnapshot.encode` v2.
Map<String, Object?> v2Document({
  Map<String, Object?>? rewards,
}) => <String, Object?>{
  'schema': 1,
  'revision': 7,
  'clockOffsetDays': 0,
  'settings': <String, Object?>{'sfxEnabled': true},
  'shop': <String, Object?>{
    'cart': <Object?>[
      <String, Object?>{'productId': 'animate-brightening-soap-80g', 'qty': 1},
    ],
    'orders': <Object?>[],
    'orderSeq': 1,
  },
  'rewards': rewards ?? v2Rewards(),
};

Map<String, Object?> v2Rewards() => <String, Object?>{
  'ledger': <Object?>[
    <String, Object?>{
      'id': 'L000001',
      'wibDay': tuesday,
      'amount': 1,
      'kind': 'checkIn',
      'note': 'Check-in hari ke-1',
    },
    <String, Object?>{
      'id': 'L000002',
      'wibDay': saturday,
      'amount': 10,
      'kind': 'spinPrize',
      'note': 'Roda Sabtu: 10 Kelopak',
    },
    <String, Object?>{
      'id': 'L000003',
      'wibDay': saturday,
      'amount': -4,
      'kind': 'checkoutSpend',
      'note': 'Dipakai di pesanan BP-20261128-0001',
    },
  ],
  'streak': 1,
  'lastClaimDay': tuesday,
  'entitlements': <Object?>[
    <String, Object?>{
      'id': 'HP-0001',
      'source': 'spin',
      'wibDay': saturday + 7,
      'status': 'pending',
    },
    <String, Object?>{
      'id': 'HP-0002',
      'source': 'checkIn',
      'wibDay': saturday + 9,
      'status': 'pending',
    },
  ],
  'spins': <Object?>[
    <String, Object?>{
      'wibDay': saturday,
      'prizeId': 'kelopak-10',
      'roll': 1500,
      'landingSeed': 11,
      'configVersion': 'demo-2026-11',
      'productStockBefore': 1,
    },
    <String, Object?>{
      'wibDay': saturday + 7,
      'prizeId': 'product',
      'roll': 20,
      'landingSeed': 12,
      'configVersion': 'demo-2026-11',
      'productStockBefore': 1,
    },
  ],
  'promoActive': true,
  'productStock': 0,
  'missionIssuedCount': 1,
  'countedOrderIds': <String>['BP-20261124-0001'],
  'vouchers': <Object?>[
    MissionVoucher(
      id: 'VM-0001',
      stageNumber: 1,
      sourceOrderId: 'BP-20261124-0001',
      amount: 10000,
      minSpend: 100000,
      issuedDay: tuesday,
      expiresDay: tuesday + 30,
    ).toJson(),
  ],
  'ledgerSeq': 3,
  'entitlementSeq': 2,
  'voucherSeq': 1,
};
