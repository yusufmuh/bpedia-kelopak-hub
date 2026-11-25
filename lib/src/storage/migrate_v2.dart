/// Migrasi sekali jalan data Kelopak dari dokumen app v2
/// (`bpedia_preview_state_v1`). Kunci lama tidak dihapus.
///
/// Yang dibawa: buku besar (saldo), rentetan check-in, riwayat putaran,
/// voucher misi, kemajuan misi, dan hak produk gratis yang menjadi hadiah
/// menunggu. Keranjang dan pengaturan dimigrasikan aplikasi induk; pesanan v2
/// tidak dibawa.
library;

import 'dart:convert';

import 'package:misi_belanja/misi_belanja.dart' show MissionVoucher;

import '../domain/campaign.dart';
import '../domain/gifts.dart';
import '../domain/ledger.dart';
import '../domain/state.dart';
import '../domain/voucher.dart';
import 'json_reader.dart';

/// Kunci penyimpanan dokumen app v2.
const String v2DocumentKey = 'bpedia_preview_state_v1';

/// Kuota hadiah produk roda pada kampanye demo v2.
const int _v2WheelStock = 1;

const String _v2SpendNotePrefix = 'Dipakai di pesanan ';
const String _v2ProductPrizeId = 'product';

/// Mengubah teks dokumen v2 menjadi [KelopakState], atau null bila [raw]
/// kosong, rusak, bukan skema 1, atau isinya mustahil. Kode produk hadiah
/// diambil dari [campaign] karena v2 belum menyimpannya.
KelopakState? migrateV2Kelopak(
  String? raw, {
  KelopakCampaign campaign = KelopakCampaign.demo,
}) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final document = asJsonMap(jsonDecode(raw), 'v2 document');
    if (readInt(document, 'schema') != 1) return null;
    final rewardsJson = document['rewards'];
    if (rewardsJson == null) return null;
    final rewards = asJsonMap(rewardsJson, 'rewards');

    final gifts = readList(
      rewards,
      'entitlements',
      (item) => _giftOf(item, campaign),
    );
    final wheelGiftByDay = <int, String>{
      for (final gift in gifts)
        if (gift.source == GiftSource.wheel) gift.wonDay: gift.id,
    };
    final spins = <SpinRecord>[
      for (final record in readList(rewards, 'spins', SpinRecord.fromJson))
        record.prizeId == _v2ProductPrizeId
            ? SpinRecord(
                wibDay: record.wibDay,
                prizeId: record.prizeId,
                roll: record.roll,
                landingSeed: record.landingSeed,
                configVersion: record.configVersion,
                productStockBefore: record.productStockBefore,
                giftId: wheelGiftByDay[record.wibDay],
              )
            : record,
    ];
    final stockLeft = readInt(rewards, 'productStock', fallback: _v2WheelStock);
    int? lastProductDay;
    for (final record in spins) {
      if (record.prizeId == _v2ProductPrizeId) lastProductDay = record.wibDay;
    }
    final used = (_v2WheelStock - stockLeft).clamp(0, campaign.wheelQuota);

    final state = KelopakState(
      ledger: readList(rewards, 'ledger', _ledgerEntryOf),
      streak: readInt(rewards, 'streak', fallback: 0),
      lastClaimDay: readOptionalInt(rewards, 'lastClaimDay'),
      gifts: gifts,
      spins: spins,
      promoActive: readBool(rewards, 'promoActive', fallback: true),
      wheelQuotaUsed: lastProductDay == null ? 0 : used,
      wheelQuotaWeek: lastProductDay == null
          ? null
          : KelopakCampaign.weekOf(lastProductDay),
      missionIssuedCount: readInt(rewards, 'missionIssuedCount', fallback: 0),
      countedOrderIds: readStringList(rewards, 'countedOrderIds').toSet(),
      vouchers: readList(
        rewards,
        'vouchers',
        (item) => KelopakVoucher.fromMissionVoucher(
          MissionVoucher.fromJson(asJsonMap(item, 'voucher')),
        ),
      ),
      ledgerSeq: readInt(rewards, 'ledgerSeq', fallback: 0),
      giftSeq: readInt(rewards, 'entitlementSeq', fallback: 0),
      voucherSeq: readInt(rewards, 'voucherSeq', fallback: 0),
    );
    state.validate();
    return state;
  } catch (_) {
    // Dokumen lama yang tidak bisa dibaca utuh tidak dipakai sama sekali.
    return null;
  }
}

LedgerEntry _ledgerEntryOf(Object? source) {
  final entry = LedgerEntry.fromJson(source);
  if (entry.kind != LedgerKind.checkoutSpend ||
      !entry.note.startsWith(_v2SpendNotePrefix)) {
    return entry;
  }
  return LedgerEntry(
    id: entry.id,
    wibDay: entry.wibDay,
    amount: entry.amount,
    kind: entry.kind,
    note: entry.note,
    orderId: entry.note.substring(_v2SpendNotePrefix.length),
  );
}

PendingGift _giftOf(Object? source, KelopakCampaign campaign) {
  final json = asJsonMap(source, 'entitlement');
  final wonDay = readInt(json, 'wibDay');
  final fromWheel = switch (readString(json, 'source')) {
    'spin' => true,
    'checkIn' => false,
    _ => throw const FormatException('Unknown entitlement source'),
  };
  return PendingGift(
    id: readString(json, 'id').replaceFirst('HP-', 'HG-'),
    source: fromWheel ? GiftSource.wheel : GiftSource.checkIn30,
    wonDay: wonDay,
    productCode: fromWheel
        ? campaign.wheelProductCodeOn(wonDay)
        : campaign.checkIn30ProductCode,
  );
}
