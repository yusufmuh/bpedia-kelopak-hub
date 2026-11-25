import 'dart:math';

import 'package:kelopak_hub/kelopak_hub.dart';
import 'package:roda_sabtu/roda_sabtu.dart' show demoSpinConfig;

/// Hari WIB sebuah tanggal kalender WIB, mis. `wibDayFor(2026, 11, 28)` (Sabtu).
int wibDayFor(int year, int month, int day) =>
    DateTime.utc(year, month, day).difference(DateTime.utc(1970)).inDays;

/// Saat [hour]:[minute] WIB pada tanggal WIB itu.
DateTime wibInstant(
  int year,
  int month,
  int day, {
  int hour = 10,
  int minute = 0,
}) => DateTime.utc(year, month, day, hour - 7, minute);

/// Selasa 24 Nov 2026.
final int tuesday = wibDayFor(2026, 11, 24);

/// Sabtu 28 Nov 2026.
final int saturday = wibDayFor(2026, 11, 28);

/// Jam yang bisa digeser tes.
class FakeClock {
  FakeClock(this.current);

  DateTime current;

  DateTime now() => current;

  void advance(Duration duration) => current = current.add(duration);
}

/// [Random] yang mengembalikan nilai berurutan (dimodulo `max`).
class ScriptedRandom implements Random {
  ScriptedRandom(this.values) : assert(values.isNotEmpty);

  final List<int> values;
  int _index = 0;

  @override
  int nextInt(int max) => values[_index++ % values.length] % max;

  @override
  double nextDouble() => 0.5;

  @override
  bool nextBool() => false;
}

/// Kode produk misi tahap 1 kampanye uji (Animate skincare).
const List<String> missionCodes = <String>[
  'P39A06S01000021',
  'P39A06S01000044',
  'P39A06S01000089',
];

/// Produk di luar misi tahap 1.
const String otherCode = 'P21P03C01000082';

/// Hadiah roda bergilir kampanye uji.
const List<String> wheelCodes = <String>[
  'P21P03C01000082',
  'P21F02C01000031',
  'P21P03C01000171',
  'P21P03C01000189',
];

/// Hadiah check-in hari ke-30 kampanye uji.
const String checkIn30Code = 'P39A06S01000089';

/// Kampanye mirip `demo_campaign.dart` app: misi tahap 1 hanya menghitung
/// [missionCodes], tahap 2 menghitung semua produk.
KelopakCampaign testCampaign({int wheelQuota = 3, int redeemShareBp = 10000}) =>
    KelopakCampaign(
      policy: KelopakPolicy(redeemShareBp: redeemShareBp),
      wheel: demoSpinConfig,
      wheelQuota: wheelQuota,
      wheelProductCodes: wheelCodes,
      checkIn30ProductCode: checkIn30Code,
      missionStages: const <MissionStage>[
        MissionStage(
          number: 1,
          minOrderSubtotal: 75000,
          voucherAmount: 10000,
          voucherMinSpend: 100000,
          voucherValidDays: 30,
          productCodes: missionCodes,
        ),
        MissionStage(
          number: 2,
          minOrderSubtotal: 100000,
          voucherAmount: 15000,
          voucherMinSpend: 150000,
          voucherValidDays: 30,
        ),
      ],
    );

/// Keadaan dengan saldo awal [kelopak].
KelopakState stateWithBalance(int kelopak, int day) => KelopakState(
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

/// Satu baris barang.
CheckoutLine line(String code, int unitPrice, {int quantity = 1}) =>
    CheckoutLine(productCode: code, unitPrice: unitPrice, quantity: quantity);

/// Permintaan checkout tanpa ongkir kecuali disebut.
CheckoutRequest request(
  List<CheckoutLine> lines, {
  int shippingFee = 0,
  String? voucherId,
  bool useKelopak = true,
}) => CheckoutRequest(
  lines: lines,
  shippingFee: shippingFee,
  voucherId: voucherId,
  useKelopak: useKelopak,
);

/// Mengutip lalu mengomit [lines] sebagai [orderId]; gagal tes bila ditolak.
KelopakOrder place(
  KelopakEngine engine,
  String orderId,
  List<CheckoutLine> lines, {
  required int today,
  String? voucherId,
  bool useKelopak = true,
  int shippingFee = 0,
}) {
  final quote = engine.quote(
    request(
      lines,
      voucherId: voucherId,
      useKelopak: useKelopak,
      shippingFee: shippingFee,
    ),
    today: today,
  );
  final outcome = engine.commitOrder(
    orderId: orderId,
    quote: quote,
    today: today,
  );
  if (outcome is! OrderCommitted) {
    throw StateError('Order $orderId not committed: $outcome');
  }
  return outcome.order;
}
