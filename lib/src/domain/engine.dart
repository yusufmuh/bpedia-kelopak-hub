/// Mesin Kelopak (Dart murni, tanpa widget).
///
/// Memegang buku besar, Check-in Harian, Roda Sabtu, Misi Belanja, voucher,
/// hadiah menunggu, dan pesanan. Setiap aturan bisnis diserahkan ke fungsi
/// aturan modul (`evaluateCheckIn`, `liveStreak`, `resolveSpin`,
/// `effectiveOdds`, `spinEligibility`, `evaluateOrderLines`, `redeemProblem`);
/// mesin hanya mencatat hasilnya. Deterministik: waktu (`today`) dan acak
/// (`roll`, `landingSeed`) selalu diberikan dari luar.
library;

import 'package:daily_checkin/daily_checkin.dart'
    show dayInMonthCycle, evaluateCheckIn, filledInWeek, isClaimedOn;
import 'package:daily_checkin/daily_checkin.dart' as checkin show liveStreak;
import 'package:misi_belanja/misi_belanja.dart'
    show
        MissionProgress,
        MissionStage,
        RedeemProblem,
        allStagesDone,
        evaluateOrderLines,
        missionProgress,
        missionSubtotal;
import 'package:roda_sabtu/roda_sabtu.dart'
    show
        PrizeKind,
        SpinConfig,
        SpinEligibility,
        SpinOdds,
        SpinPrize,
        effectiveOdds,
        resolveSpin;
import 'package:roda_sabtu/roda_sabtu.dart'
    as roda
    show nextSpinSaturday, spinEligibility;

import 'campaign.dart';
import 'checkout.dart';
import 'gifts.dart';
import 'ledger.dart';
import 'outcomes.dart';
import 'state.dart';
import 'voucher.dart';

/// Pembacaan atas [KelopakState] dengan aturan [campaign]. Tidak mengubah apa
/// pun; controller memberikannya ke UI.
base class KelopakView {
  KelopakView(KelopakState state, {this.campaign = KelopakCampaign.demo})
    : _state = state;

  KelopakState _state;

  /// Konfigurasi kampanye.
  final KelopakCampaign campaign;

  /// Potret tak-berubah saat ini (inilah yang disimpan).
  KelopakState get state => _state;

  // ---------------------------------------------------------------- Kelopak

  /// Saldo Kelopak (jumlah buku besar, tidak pernah negatif).
  int get balance => _state.balance;

  /// Buku besar berurutan waktu (terlama lebih dulu).
  List<LedgerEntry> get ledger => _state.ledger;

  /// Buku besar dengan saldo berjalan, terbaru lebih dulu.
  List<LedgerLine> get ledgerHistory => buildLedgerHistory(_state.ledger);

  // ---------------------------------------------------------- Check-in Harian

  /// Rentetan tersimpan (nilai mentah, lihat [liveStreak]).
  int get storedStreak => _state.streak;

  /// Hari WIB check-in terakhir, null sebelum yang pertama.
  int? get lastClaimDay => _state.lastClaimDay;

  /// Rentetan yang masih hidup pada [today] (0 bila putus).
  int liveStreak(int today) => checkin.liveStreak(
    today: today,
    lastClaimDay: _state.lastClaimDay,
    streak: _state.streak,
  );

  /// Apakah [today] sudah diklaim.
  bool claimedToday(int today) =>
      isClaimedOn(today: today, lastClaimDay: _state.lastClaimDay);

  /// True bila pernah ada rentetan tetapi ada hari terlewat.
  bool streakBroken(int today) {
    final last = _state.lastClaimDay;
    return _state.streak > 0 && last != null && last < today - 1;
  }

  /// Hari WIB check-in berikutnya dibuka: [today] selama masih bisa, selain
  /// itu sehari setelah klaim terakhir (bisa lebih dari besok bila jam
  /// perangkat dimundurkan).
  int nextCheckInDay(int today) {
    final last = _state.lastClaimDay;
    return last != null && last >= today ? last + 1 : today;
  }

  /// Slot terisi di lintasan 7 hari (aturan modul `filledInWeek`).
  int checkInWeekFilled(int today) => filledInWeek(
    liveStreak: liveStreak(today),
    claimedToday: claimedToday(today),
  );

  /// Kemajuan 0..30 menuju produk gratis (aturan modul `dayInMonthCycle`).
  int checkInMonthDay(int today) => dayInMonthCycle(
    liveStreak: liveStreak(today),
    claimedToday: claimedToday(today),
  );

  // --------------------------------------------------------------- Roda Sabtu

  /// Konfigurasi roda kampanye.
  SpinConfig get spinConfig => campaign.wheel;

  /// Riwayat putaran, terlama lebih dulu.
  List<SpinRecord> get spins => _state.spins;

  /// Putaran terakhir, bila ada.
  SpinRecord? get lastSpin => _state.spins.isEmpty ? null : _state.spins.last;

  /// Putaran pada [day], bila ada.
  SpinRecord? spinOn(int day) {
    for (final record in _state.spins.reversed) {
      if (record.wibDay == day) return record;
    }
    return null;
  }

  /// Apakah promo berjalan.
  bool get promoActive => _state.promoActive;

  /// Sisa kuota hadiah produk roda pada [today].
  int wheelQuotaLeft(int today) {
    final left = campaign.wheelQuota - _quotaUsedOn(today);
    return left > 0 ? left : 0;
  }

  /// Apakah boleh memutar pada [today] (aturan modul).
  SpinEligibility spinEligibility(int today) => roda.spinEligibility(
    today: today,
    lastSpinDay: lastSpin?.wibDay,
    promoActive: _state.promoActive,
  );

  /// Peluang untuk sisa kuota pada [today] (produk 0% saat kuota habis).
  List<SpinOdds> currentOdds(int today) =>
      effectiveOdds(spinConfig, productStock: wheelQuotaLeft(today));

  /// Peluang saat [record] diputar, dari kuota yang disimpan bersamanya,
  /// supaya hasil tetap di bawah penunjuk setelah aplikasi dibuka ulang.
  List<SpinOdds> oddsFor(SpinRecord record) =>
      effectiveOdds(spinConfig, productStock: stockFor(record));

  /// Sisa kuota tepat sebelum [record] diputar. Catatan lama tanpa nilai itu
  /// dianggap masih punya kuota bila hasilnya produk.
  int stockFor(SpinRecord record) {
    final saved = record.productStockBefore;
    if (saved != null) return saved;
    final current = wheelQuotaLeft(record.wibDay);
    return prizeById(record.prizeId)?.kind == PrizeKind.product && current < 1
        ? 1
        : current;
  }

  /// Hadiah ber-[id] di [spinConfig], atau null.
  SpinPrize? prizeById(String id) => spinConfig.prizeById(id);

  /// Sabtu pertama setelah [today] yang putarannya masih bisa dipakai.
  int nextSpinSaturday(int today) =>
      roda.nextSpinSaturday(today: today, lastSpinDay: lastSpin?.wibDay);

  // ------------------------------------------------------------ Misi Belanja

  /// Tahap misi berurutan.
  List<MissionStage> get missionStages => campaign.missionStages;

  /// Voucher misi yang sudah terbit (= tahap selesai).
  int get missionIssuedCount => _state.missionIssuedCount;

  /// Tahap yang diselesaikan pesanan memenuhi syarat berikutnya, atau null
  /// bila semua selesai.
  MissionStage? get activeStage {
    final index = _state.missionIssuedCount;
    return index < missionStages.length ? missionStages[index] : null;
  }

  /// Apakah semua tahap selesai (aturan modul).
  bool get allMissionStagesDone => allStagesDone(
    stages: missionStages,
    issuedCount: _state.missionIssuedCount,
  );

  /// Pesanan yang sudah dievaluasi misi.
  Set<String> get countedOrderIds => _state.countedOrderIds;

  /// Kode produk misi tahap aktif. Kosong berarti semua produk dihitung (atau
  /// tidak ada tahap aktif).
  Set<String> get missionProductCodes =>
      activeStage?.productCodes.toSet() ?? const <String>{};

  /// Kemajuan tahap aktif bila [lines] dipesan dalam satu pesanan; null bila
  /// semua tahap selesai.
  MissionProgress? missionProgressFor(Iterable<CheckoutLine> lines) {
    final stage = activeStage;
    if (stage == null) return null;
    return missionProgress(stage, lines.map((line) => line.asMissionLine));
  }

  /// Pesanan berjalan yang memenuhi tahap aktif begitu diterima. Hanya yang
  /// pertama diterima yang menyelesaikannya (satu pesanan, satu tahap).
  List<KelopakOrder> get ordersAwaitingMission {
    final stage = activeStage;
    if (stage == null) return const <KelopakOrder>[];
    return _state.orders
        .where(
          (order) =>
              order.isOpen &&
              missionSubtotal(
                    stage,
                    order.lines.map((line) => line.asMissionLine),
                  ) >=
                  stage.minOrderSubtotal,
        )
        .toList(growable: false);
  }

  /// Apakah [orderId] satu-satunya pesanan berjalan yang memenuhi tahap
  /// aktif, sehingga menerimanya pasti menerbitkan voucher tahap itu.
  bool isOnlyOrderAwaitingMission(String orderId) {
    final waiting = ordersAwaitingMission;
    return waiting.length == 1 && waiting.single.id == orderId;
  }

  // ----------------------------------------------------------------- Voucher

  /// Semua voucher, terlama lebih dulu.
  List<KelopakVoucher> get vouchers => _state.vouchers;

  /// Voucher yang belum dipakai dan belum kedaluwarsa, terbaru lebih dulu.
  List<KelopakVoucher> activeVouchers(int today) => _state.vouchers.reversed
      .where((voucher) => voucher.isActiveOn(today))
      .toList(growable: false);

  /// Voucher ber-[id], atau null.
  KelopakVoucher? voucherById(String id) {
    for (final voucher in _state.vouchers) {
      if (voucher.id == id) return voucher;
    }
    return null;
  }

  /// Voucher misi yang terbit dari [orderId], atau null.
  KelopakVoucher? voucherFromOrder(String orderId) {
    for (final voucher in _state.vouchers) {
      if (voucher.sourceOrderId == orderId) return voucher;
    }
    return null;
  }

  /// Mengapa [voucherId] tidak bisa dipakai di [orderId] bersubtotal barang
  /// [subtotal] (aturan modul), atau null bila bisa. Melempar [ArgumentError]
  /// untuk voucher tak dikenal.
  RedeemProblem? voucherProblem({
    required String voucherId,
    required int subtotal,
    required int today,
    String orderId = '',
  }) {
    final voucher = voucherById(voucherId);
    if (voucher == null) {
      throw ArgumentError.value(voucherId, 'voucherId', 'unknown voucher');
    }
    return voucher.problemFor(
      orderId: orderId,
      subtotal: subtotal,
      today: today,
    );
  }

  /// Apakah voucher promo [promoId] belum pernah diklaim.
  bool canClaimPromoVoucher(String promoId) =>
      promoId.isNotEmpty &&
      !_state.vouchers.any((voucher) => voucher.promoId == promoId);

  // ---------------------------------------------------------- Hadiah menunggu

  /// Semua hadiah produk gratis, terlama lebih dulu.
  List<PendingGift> get gifts => _state.gifts;

  /// Hadiah yang masih menunggu pesanan berikutnya (tampil di keranjang).
  List<PendingGift> get pendingGifts =>
      _state.gifts.where((gift) => gift.isPending).toList(growable: false);

  /// Hadiah ber-[id], atau null.
  PendingGift? giftById(String id) {
    for (final gift in _state.gifts) {
      if (gift.id == id) return gift;
    }
    return null;
  }

  /// Hadiah yang ikut pesanan [orderId].
  List<PendingGift> giftsOfOrder(String orderId) => _state.gifts
      .where((gift) => gift.orderId == orderId)
      .toList(growable: false);

  // ----------------------------------------------------------------- Pesanan

  /// Pesanan yang dikomit, terlama lebih dulu.
  List<KelopakOrder> get orders => _state.orders;

  /// Pesanan ber-[orderId], atau null.
  KelopakOrder? orderById(String orderId) {
    for (final order in _state.orders) {
      if (order.id == orderId) return order;
    }
    return null;
  }

  /// Rincian harga [request] pada [today] (murah; boleh dipanggil di build).
  CheckoutQuote quote(
    CheckoutRequest request, {
    required int today,
    String orderId = '',
  }) {
    final voucherId = request.voucherId;
    return computeCheckoutQuote(
      policy: campaign.policy,
      request: request,
      balance: balance,
      voucher: voucherId == null ? null : voucherById(voucherId),
      pendingGifts: _state.gifts,
      today: today,
      orderId: orderId,
    );
  }

  /// Mengapa [quote] tidak bisa dikomit pada [today], atau null bila bisa.
  CheckoutProblem? problemWith(
    CheckoutQuote quote, {
    required int today,
    String orderId = '',
  }) {
    if (!quote.hasPaidItems) return CheckoutProblem.noPaidItems;
    if (quote.day != today) return CheckoutProblem.quoteOutdated;
    final fresh = this.quote(quote.request, today: today, orderId: orderId);
    return fresh.token == quote.token ? null : CheckoutProblem.quoteOutdated;
  }

  int _quotaUsedOn(int today) =>
      campaign.wheelQuotaRefillsWeekly &&
          _state.wheelQuotaWeek != KelopakCampaign.weekOf(today)
      ? 0
      : _state.wheelQuotaUsed;
}

/// Mesin yang bisa berubah di atas [KelopakState]; tiap operasi mengganti
/// [state] dengan potret baru.
final class KelopakEngine extends KelopakView {
  KelopakEngine(super.state, {super.campaign});

  // ---------------------------------------------------------------- Kelopak

  /// Membukukan debit checkout [amount] Kelopak untuk [orderId].
  ///
  /// Melempar [ArgumentError] untuk jumlah negatif dan [StateError] bila
  /// saldo kurang. Nol tidak mengubah apa pun.
  void spendKelopak(int amount, String orderId, int today) {
    if (amount < 0) {
      throw ArgumentError.value(amount, 'amount', 'must not be negative');
    }
    if (amount == 0) return;
    if (amount > balance) {
      throw StateError('Not enough Kelopak: need $amount, have $balance');
    }
    _state = _withLedgerEntry(
      _state,
      wibDay: today,
      amount: -amount,
      kind: LedgerKind.checkoutSpend,
      note: 'Dipakai di pesanan #$orderId',
      orderId: orderId,
    );
  }

  /// Mode Demo: menambah [amount] Kelopak ke saldo.
  void grantKelopak(int amount, int today, {String note = 'Isi saldo demo'}) {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'must be positive');
    }
    _state = _withLedgerEntry(
      _state,
      wibDay: today,
      amount: amount,
      kind: LedgerKind.demoGrant,
      note: note,
    );
  }

  // ---------------------------------------------------------- Check-in Harian

  /// Mengklaim check-in hari ini.
  CheckInOutcome claimCheckIn(int today) {
    final award = evaluateCheckIn(
      today: today,
      lastClaimDay: _state.lastClaimDay,
      streak: _state.streak,
    );
    if (award == null) return const CheckInAlreadyClaimed();
    var next = _withLedgerEntry(
      _state,
      wibDay: today,
      amount: award.dailyKelopak,
      kind: LedgerKind.checkIn,
      note: 'Check-in hari ke-${award.streak}',
    );
    if (award.bonusKelopak > 0) {
      next = _withLedgerEntry(
        next,
        wibDay: today,
        amount: award.bonusKelopak,
        kind: LedgerKind.checkInBonus,
        note: 'Bonus ${award.streak} hari beruntun',
      );
    }
    PendingGift? gift;
    if (award.productEntitled) {
      final granted = _withGift(
        next,
        source: GiftSource.checkIn30,
        wonDay: today,
        productCode: campaign.checkIn30ProductCode,
      );
      next = granted.state;
      gift = granted.gift;
    }
    _state = next.copyWith(streak: award.streak, lastClaimDay: today);
    return CheckInClaimed(award: award, newBalance: balance, gift: gift);
  }

  // --------------------------------------------------------------- Roda Sabtu

  /// Memutar sekali. [roll] harus 0..9999; [landingSeed] disimpan untuk
  /// memutar ulang animasi.
  SpinOutcome spin({
    required int today,
    required int roll,
    required int landingSeed,
  }) {
    RangeError.checkValueInInterval(roll, 0, 9999, 'roll');
    final eligibility = spinEligibility(today);
    if (eligibility != SpinEligibility.available) {
      return SpinRejected(eligibility);
    }
    final stock = wheelQuotaLeft(today);
    final odds = currentOdds(today);
    final prize = resolveSpin(spinConfig, productStock: stock, roll: roll);
    var next = _state;
    PendingGift? gift;
    switch (prize.kind) {
      case PrizeKind.product:
        final granted = _withGift(
          next,
          source: GiftSource.wheel,
          wonDay: today,
          productCode: campaign.wheelProductCodeFor(prize, today),
        );
        gift = granted.gift;
        next = granted.state.copyWith(
          wheelQuotaUsed: _quotaUsedOn(today) + 1,
          wheelQuotaWeek: KelopakCampaign.weekOf(today),
        );
      case PrizeKind.kelopak:
        if (prize.kelopak > 0) {
          next = _withLedgerEntry(
            next,
            wibDay: today,
            amount: prize.kelopak,
            kind: LedgerKind.spinPrize,
            note: 'Roda Sabtu: ${prize.label}',
          );
        }
    }
    final record = SpinRecord(
      wibDay: today,
      prizeId: prize.id,
      roll: roll,
      landingSeed: landingSeed,
      configVersion: spinConfig.version,
      productStockBefore: stock,
      giftId: gift?.id,
    );
    _state = next.copyWith(spins: <SpinRecord>[...next.spins, record]);
    return SpinCompleted(
      record: record,
      prize: prize,
      odds: odds,
      newBalance: balance,
      gift: gift,
    );
  }

  /// Menyalakan atau mematikan promo Roda Sabtu (Mode Demo).
  void setPromoActive(bool active) {
    _state = _state.copyWith(promoActive: active);
  }

  /// Mode Demo: mengatur sisa kuota hadiah produk roda pada [today] menjadi
  /// [left] (dibatasi 0..`wheelQuota`).
  void setWheelQuotaLeft(int left, int today) {
    final clamped = left.clamp(0, campaign.wheelQuota);
    _state = _state.copyWith(
      wheelQuotaUsed: campaign.wheelQuota - clamped,
      wheelQuotaWeek: KelopakCampaign.weekOf(today),
    );
  }

  /// Mode Demo: mengisi penuh kuota hadiah produk roda.
  void refillWheelQuota(int today) =>
      setWheelQuotaLeft(campaign.wheelQuota, today);

  // ----------------------------------------------------------------- Voucher

  /// Mengklaim voucher promo [promoId] satu kali per pengguna. Berlaku
  /// sampai `today + validDays`.
  PromoClaimOutcome claimPromoVoucher({
    required String promoId,
    required int amount,
    required int minSpend,
    required int validDays,
    required int today,
    String title = 'Voucher promo',
  }) {
    if (promoId.isEmpty || amount <= 0 || minSpend < 0 || validDays <= 0) {
      return const PromoVoucherNotClaimed(PromoClaimProblem.invalidTerms);
    }
    if (!canClaimPromoVoucher(promoId)) {
      return const PromoVoucherNotClaimed(PromoClaimProblem.alreadyClaimed);
    }
    final seq = _state.voucherSeq + 1;
    final voucher = KelopakVoucher(
      id: 'VP-${seq.toString().padLeft(4, '0')}',
      kind: VoucherKind.promo,
      title: title,
      amount: amount,
      minSpend: minSpend,
      issuedDay: today,
      expiresDay: today + validDays,
      promoId: promoId,
    );
    _state = _state.copyWith(
      vouchers: <KelopakVoucher>[..._state.vouchers, voucher],
      voucherSeq: seq,
    );
    return PromoVoucherClaimed(voucher);
  }

  // ----------------------------------------------------------------- Pesanan

  /// Mengikat [quote] ke pesanan [orderId]: voucher ditandai terpakai,
  /// Kelopak didebit, hadiah menunggu terlampir.
  ///
  /// Komit ulang dengan kutipan yang sama mengembalikan pesanan yang sudah
  /// tercatat tanpa mendebit lagi.
  CommitOutcome commitOrder({
    required String orderId,
    required CheckoutQuote quote,
    required int today,
  }) {
    if (orderId.isEmpty) {
      throw ArgumentError.value(orderId, 'orderId', 'must not be empty');
    }
    final existing = orderById(orderId);
    if (existing != null) {
      return existing.quoteToken == quote.token
          ? OrderCommitted(existing)
          : const OrderNotCommitted(CheckoutProblem.duplicateOrder);
    }
    final problem = problemWith(quote, today: today, orderId: orderId);
    if (problem != null) return OrderNotCommitted(problem);

    final voucherId = quote.voucherApplied ? quote.voucherId : null;
    if (voucherId != null) {
      _state = _state.copyWith(
        vouchers: <KelopakVoucher>[
          for (final voucher in _state.vouchers)
            voucher.id == voucherId ? voucher.markUsed(orderId) : voucher,
        ],
      );
    }
    spendKelopak(quote.kelopakUsed, orderId, today);
    final giftIds = <String>{for (final gift in quote.gifts) gift.id};
    final order = KelopakOrder(
      id: orderId,
      placedDay: today,
      lines: quote.request.lines,
      goodsSubtotal: quote.goodsSubtotal,
      shippingFee: quote.shippingFee,
      voucherId: voucherId,
      voucherAmount: quote.voucherAmount,
      kelopakUsed: quote.kelopakUsed,
      kelopakValue: quote.kelopakValue,
      giftIds: giftIds.toList(growable: false),
      total: quote.total,
      quoteToken: quote.token,
    );
    _state = _state.copyWith(
      gifts: <PendingGift>[
        for (final gift in _state.gifts)
          giftIds.contains(gift.id)
              ? gift.withStatus(GiftStatus.attached, orderId: orderId)
              : gift,
      ],
      orders: <KelopakOrder>[..._state.orders, order],
    );
    return OrderCommitted(order);
  }

  /// Membatalkan pesanan yang belum dikirim: Kelopak dikembalikan, voucher
  /// kembali bisa dipakai, hadiah kembali menunggu.
  ///
  /// Null bila tidak ada pesanan [orderId] yang masih bisa dibatalkan.
  OrderCancellation? cancelOrder(String orderId, int today) {
    final order = orderById(orderId);
    if (order == null || order.status != KelopakOrderStatus.placed) return null;
    var next = _state;
    if (order.kelopakUsed > 0) {
      next = _withLedgerEntry(
        next,
        wibDay: today,
        amount: order.kelopakUsed,
        kind: LedgerKind.checkoutRefund,
        note: 'Dikembalikan dari pesanan #$orderId',
        orderId: orderId,
      );
    }
    KelopakVoucher? released;
    final voucherId = order.voucherId;
    if (voucherId != null) {
      final vouchers = <KelopakVoucher>[];
      for (final voucher in next.vouchers) {
        if (voucher.id == voucherId && voucher.usedOnOrderId == orderId) {
          released = voucher.release();
          vouchers.add(released);
        } else {
          vouchers.add(voucher);
        }
      }
      next = next.copyWith(vouchers: vouchers);
    }
    final returned = <PendingGift>[];
    final gifts = <PendingGift>[];
    for (final gift in next.gifts) {
      if (gift.orderId == orderId) {
        final pending = gift.withStatus(GiftStatus.pending);
        returned.add(pending);
        gifts.add(pending);
      } else {
        gifts.add(gift);
      }
    }
    final cancelled = order.withStatus(
      KelopakOrderStatus.cancelled,
      closedDay: today,
    );
    _state = _replaceOrder(next.copyWith(gifts: gifts), cancelled);
    return OrderCancellation(
      order: cancelled,
      kelopakRefunded: order.kelopakUsed,
      voucher: released,
      gifts: returned,
    );
  }

  /// Menandai pesanan dikirim; hadiah terlampir ikut dikirim.
  ///
  /// Null bila tidak ada pesanan [orderId] berstatus `placed`.
  KelopakOrder? shipOrder(String orderId) {
    final order = orderById(orderId);
    if (order == null || order.status != KelopakOrderStatus.placed) return null;
    final shipped = order.withStatus(KelopakOrderStatus.shipped);
    _state = _replaceOrder(
      _withGiftStatus(_state, orderId, GiftStatus.shipped),
      shipped,
    );
    return shipped;
  }

  /// "Pesanan Diterima": hadiah terlampir diterima dan Misi Belanja menilai
  /// subtotal produk misi dari baris yang disimpan saat komit. Voucher tahap
  /// berlaku sampai `today + voucherValidDays`.
  ///
  /// Null bila tidak ada pesanan [orderId] yang masih berjalan.
  OrderCompletion? completeOrder(String orderId, int today) {
    final order = orderById(orderId);
    if (order == null || !order.isOpen) return null;
    final completed = order.withStatus(
      KelopakOrderStatus.completed,
      closedDay: today,
    );
    var next = _replaceOrder(
      _withGiftStatus(_state, orderId, GiftStatus.received),
      completed,
    );
    final decision = evaluateOrderLines(
      stages: missionStages,
      issuedCount: next.missionIssuedCount,
      countedOrderIds: next.countedOrderIds,
      orderId: orderId,
      lines: order.lines.map((line) => line.asMissionLine),
      completed: true,
    );
    next = next.copyWith(
      countedOrderIds: <String>{...next.countedOrderIds, orderId},
    );
    KelopakVoucher? voucher;
    final stage = decision.issuedStage;
    if (stage != null) {
      final seq = next.voucherSeq + 1;
      voucher = KelopakVoucher.mission(
        id: 'VM-${seq.toString().padLeft(4, '0')}',
        stage: stage,
        sourceOrderId: orderId,
        issuedDay: today,
      );
      next = next.copyWith(
        vouchers: <KelopakVoucher>[...next.vouchers, voucher],
        voucherSeq: seq,
        missionIssuedCount: next.missionIssuedCount + 1,
      );
    }
    _state = next;
    return OrderCompletion(
      order: completed,
      decision: decision,
      voucher: voucher,
      gifts: giftsOfOrder(orderId),
    );
  }

  // ------------------------------------------------------------------ helpers

  static KelopakState _withLedgerEntry(
    KelopakState state, {
    required int wibDay,
    required int amount,
    required LedgerKind kind,
    required String note,
    String? orderId,
  }) {
    final seq = state.ledgerSeq + 1;
    final entry = LedgerEntry(
      id: 'L${seq.toString().padLeft(6, '0')}',
      wibDay: wibDay,
      amount: amount,
      kind: kind,
      note: note,
      orderId: orderId,
    );
    return state.copyWith(
      ledger: <LedgerEntry>[...state.ledger, entry],
      ledgerSeq: seq,
    );
  }

  static ({KelopakState state, PendingGift gift}) _withGift(
    KelopakState state, {
    required GiftSource source,
    required int wonDay,
    required String? productCode,
  }) {
    final seq = state.giftSeq + 1;
    final gift = PendingGift(
      id: 'HG-${seq.toString().padLeft(4, '0')}',
      source: source,
      wonDay: wonDay,
      productCode: productCode,
    );
    return (
      state: state.copyWith(
        gifts: <PendingGift>[...state.gifts, gift],
        giftSeq: seq,
      ),
      gift: gift,
    );
  }

  static KelopakState _withGiftStatus(
    KelopakState state,
    String orderId,
    GiftStatus status,
  ) => state.copyWith(
    gifts: <PendingGift>[
      for (final gift in state.gifts)
        gift.orderId == orderId ? gift.withStatus(status) : gift,
    ],
  );

  static KelopakState _replaceOrder(KelopakState state, KelopakOrder order) =>
      state.copyWith(
        orders: <KelopakOrder>[
          for (final existing in state.orders)
            existing.id == order.id ? order : existing,
        ],
      );
}
