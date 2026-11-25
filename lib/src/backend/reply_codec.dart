/// Bentuk JSON hasil tiap aksi pada kontrak server (`"result"` di balasan).
///
/// `encode*` dipakai server (dan server tiruan di tes); `decode*` dipakai
/// `RemoteKelopakBackend`. Hasil hanya menyebut ID: objeknya (hadiah, voucher,
/// pesanan, catatan putaran) dibaca dari keadaan di balasan yang sama, supaya
/// tidak ada dua sumber kebenaran.
library;

import 'package:daily_checkin/daily_checkin.dart' show CheckInAward;
import 'package:misi_belanja/misi_belanja.dart'
    show MissionDecision, OrderRejection;
import 'package:roda_sabtu/roda_sabtu.dart' show SpinEligibility, effectiveOdds;

import '../domain/campaign.dart';
import '../domain/checkout.dart';
import '../domain/engine.dart';
import '../domain/gifts.dart';
import '../domain/outcomes.dart';
import '../domain/state.dart';
import '../storage/json_reader.dart';

/// Hasil klaim check-in.
JsonMap encodeCheckInOutcome(CheckInOutcome outcome) => switch (outcome) {
  CheckInClaimed(:final award, :final gift) => <String, Object?>{
    'claimed': true,
    'streak': award.streak,
    'dailyKelopak': award.dailyKelopak,
    'bonusKelopak': award.bonusKelopak,
    'productEntitled': award.productEntitled,
    'giftId': gift?.id,
  },
  CheckInAlreadyClaimed() => <String, Object?>{'claimed': false},
};

/// Kebalikan [encodeCheckInOutcome]; [state] adalah keadaan di balasan.
CheckInOutcome decodeCheckInOutcome(JsonMap json, KelopakState state) {
  if (!readBool(json, 'claimed')) return const CheckInAlreadyClaimed();
  return CheckInClaimed(
    award: CheckInAward(
      streak: readInt(json, 'streak'),
      dailyKelopak: readInt(json, 'dailyKelopak'),
      bonusKelopak: readInt(json, 'bonusKelopak'),
      productEntitled: readBool(json, 'productEntitled'),
    ),
    newBalance: state.balance,
    gift: _giftOrNull(state, readOptionalString(json, 'giftId')),
  );
}

/// Hasil memutar roda.
JsonMap encodeSpinOutcome(SpinOutcome outcome) => switch (outcome) {
  SpinCompleted(:final record) => <String, Object?>{
    'spun': true,
    'wibDay': record.wibDay,
  },
  SpinRejected(:final eligibility) => <String, Object?>{
    'spun': false,
    'reason': eligibility.name,
  },
};

/// Kebalikan [encodeSpinOutcome]. Hadiah dan peluang dihitung ulang dari
/// catatan putaran di [state] dan [campaign].
SpinOutcome decodeSpinOutcome(
  JsonMap json,
  KelopakState state,
  KelopakCampaign campaign,
) {
  if (!readBool(json, 'spun')) {
    final reason = readEnum(json, 'reason', SpinEligibility.values);
    if (reason == SpinEligibility.available) {
      throw const FormatException('A rejected spin cannot be "available"');
    }
    return SpinRejected(reason);
  }
  final view = KelopakView(state, campaign: campaign);
  final record = view.spinOn(readInt(json, 'wibDay'));
  final prize = record == null ? null : view.prizeById(record.prizeId);
  if (record == null || prize == null) {
    throw const FormatException('Spin result does not match the state');
  }
  return SpinCompleted(
    record: record,
    prize: prize,
    odds: effectiveOdds(campaign.wheel, productStock: view.stockFor(record)),
    newBalance: state.balance,
    gift: _giftOrNull(state, record.giftId),
  );
}

/// Hasil klaim voucher promo.
JsonMap encodePromoClaimOutcome(PromoClaimOutcome outcome) => switch (outcome) {
  PromoVoucherClaimed(:final voucher) => <String, Object?>{
    'claimed': true,
    'voucherId': voucher.id,
  },
  PromoVoucherNotClaimed(:final problem) => <String, Object?>{
    'claimed': false,
    'problem': problem.name,
  },
};

/// Kebalikan [encodePromoClaimOutcome].
PromoClaimOutcome decodePromoClaimOutcome(JsonMap json, KelopakState state) {
  if (!readBool(json, 'claimed')) {
    return PromoVoucherNotClaimed(
      readEnum(json, 'problem', PromoClaimProblem.values),
    );
  }
  final voucher = KelopakView(state).voucherById(readString(json, 'voucherId'));
  if (voucher == null) {
    throw const FormatException('Claimed voucher is not in the state');
  }
  return PromoVoucherClaimed(voucher);
}

/// Hasil komit pesanan.
JsonMap encodeCommitOutcome(CommitOutcome outcome) => switch (outcome) {
  OrderCommitted(:final order) => <String, Object?>{
    'committed': true,
    'orderId': order.id,
  },
  OrderNotCommitted(:final problem) => <String, Object?>{
    'committed': false,
    'problem': problem.name,
  },
};

/// Kebalikan [encodeCommitOutcome].
CommitOutcome decodeCommitOutcome(JsonMap json, KelopakState state) {
  if (!readBool(json, 'committed')) {
    return OrderNotCommitted(readEnum(json, 'problem', CheckoutProblem.values));
  }
  return OrderCommitted(_order(state, readString(json, 'orderId')));
}

/// Hasil batal pesanan (null = tidak ada yang dibatalkan).
JsonMap encodeCancellation(OrderCancellation? cancellation) =>
    cancellation == null
    ? <String, Object?>{'cancelled': false}
    : <String, Object?>{
        'cancelled': true,
        'orderId': cancellation.order.id,
        'kelopakRefunded': cancellation.kelopakRefunded,
        'voucherId': cancellation.voucher?.id,
        'giftIds': <String>[for (final gift in cancellation.gifts) gift.id],
      };

/// Kebalikan [encodeCancellation].
OrderCancellation? decodeCancellation(JsonMap json, KelopakState state) {
  if (!readBool(json, 'cancelled')) return null;
  final view = KelopakView(state);
  final voucherId = readOptionalString(json, 'voucherId');
  return OrderCancellation(
    order: _order(state, readString(json, 'orderId')),
    kelopakRefunded: readInt(json, 'kelopakRefunded'),
    voucher: voucherId == null ? null : view.voucherById(voucherId),
    gifts: _gifts(state, readStringList(json, 'giftIds')),
  );
}

/// Hasil kirim pesanan (null = tidak ada pesanan yang cocok).
JsonMap encodeShipment(KelopakOrder? order) => order == null
    ? <String, Object?>{'shipped': false}
    : <String, Object?>{'shipped': true, 'orderId': order.id};

/// Kebalikan [encodeShipment].
KelopakOrder? decodeShipment(JsonMap json, KelopakState state) =>
    readBool(json, 'shipped')
    ? _order(state, readString(json, 'orderId'))
    : null;

/// Hasil "Pesanan Diterima" (null = tidak ada pesanan yang masih berjalan).
JsonMap encodeCompletion(OrderCompletion? completion) => completion == null
    ? <String, Object?>{'completed': false}
    : <String, Object?>{
        'completed': true,
        'orderId': completion.order.id,
        'issuedStage': completion.decision.issuedStage?.number,
        'rejection': completion.decision.rejection?.name,
        'voucherId': completion.voucher?.id,
        'giftIds': <String>[for (final gift in completion.gifts) gift.id],
      };

/// Kebalikan [encodeCompletion]; tahap dicari di [campaign].
OrderCompletion? decodeCompletion(
  JsonMap json,
  KelopakState state,
  KelopakCampaign campaign,
) {
  if (!readBool(json, 'completed')) return null;
  final stageNumber = readOptionalInt(json, 'issuedStage');
  final MissionDecision decision;
  if (stageNumber != null) {
    final stages = campaign.missionStages.where(
      (stage) => stage.number == stageNumber,
    );
    if (stages.isEmpty) {
      throw const FormatException('Unknown mission stage in the result');
    }
    decision = MissionDecision.issued(stages.first);
  } else {
    decision = MissionDecision.rejected(
      readEnum(json, 'rejection', OrderRejection.values),
    );
  }
  final voucherId = readOptionalString(json, 'voucherId');
  return OrderCompletion(
    order: _order(state, readString(json, 'orderId')),
    decision: decision,
    voucher: voucherId == null
        ? null
        : KelopakView(state).voucherById(voucherId),
    gifts: _gifts(state, readStringList(json, 'giftIds')),
  );
}

KelopakOrder _order(KelopakState state, String orderId) {
  final order = KelopakView(state).orderById(orderId);
  if (order == null) {
    throw FormatException('Order $orderId is not in the state');
  }
  return order;
}

PendingGift? _giftOrNull(KelopakState state, String? giftId) =>
    giftId == null ? null : KelopakView(state).giftById(giftId);

List<PendingGift> _gifts(KelopakState state, List<String> ids) {
  final view = KelopakView(state);
  return <PendingGift>[for (final id in ids) ?view.giftById(id)];
}
