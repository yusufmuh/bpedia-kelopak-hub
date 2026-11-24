/// Kelopak rewards engine (pure Dart, no Flutter imports).
///
/// Owns the ledger, Check-in Harian, Roda Sabtu, Misi Belanja vouchers and
/// Kelopak spending. Every business rule is delegated to the module rule
/// functions (`evaluateCheckIn`, `liveStreak`, `resolveSpin`, `effectiveOdds`,
/// `spinEligibility`, `evaluateOrder`, `redeemProblem`); this engine only
/// records their results. It is deterministic: time (`today`) and randomness
/// (`roll`, `landingSeed`) are always passed in.
library;

import 'package:daily_checkin/daily_checkin.dart'
    show CheckInAward, evaluateCheckIn, isClaimedOn;
import 'package:daily_checkin/daily_checkin.dart' as checkin show liveStreak;
import 'package:misi_belanja/misi_belanja.dart'
    show
        MissionDecision,
        MissionStage,
        MissionVoucher,
        RedeemProblem,
        allStagesDone,
        demoMissionStages,
        evaluateOrder,
        redeemProblem;
import 'package:roda_sabtu/roda_sabtu.dart'
    show
        PrizeKind,
        SpinConfig,
        SpinEligibility,
        SpinOdds,
        SpinPrize,
        demoSpinConfig,
        effectiveOdds,
        resolveSpin;
import 'package:roda_sabtu/roda_sabtu.dart' as roda show spinEligibility;

import 'json_reader.dart';
import 'ledger.dart';

/// Maximum share of the payable amount that Kelopak may cover (Demo rule).
const int kelopakMaxDiscountPercent = 50;

/// Product stock of the Roda Sabtu demo campaign (and the value a refill restores).
const int demoSpinProductStock = 1;

/// Where a free-product entitlement came from.
enum EntitlementSource {
  /// Day 30, 60, ... of an unbroken check-in streak.
  checkIn('Check-in 30 hari beruntun'),

  /// Product prize on Roda Sabtu.
  spin('Roda Sabtu');

  const EntitlementSource(this.label);

  /// Indonesian label for "Hadiahku".
  final String label;
}

/// Fulfilment status of a free-product entitlement.
enum EntitlementStatus {
  /// Waiting to be shipped (demo: never ships).
  pending('Menunggu pengiriman (Demo)');

  const EntitlementStatus(this.label);

  /// Indonesian status text.
  final String label;
}

/// A right to one free product.
final class ProductEntitlement {
  const ProductEntitlement({
    required this.id,
    required this.source,
    required this.wibDay,
    this.status = EntitlementStatus.pending,
  });

  /// Restores an entitlement written by [toJson].
  factory ProductEntitlement.fromJson(Object? source) {
    final json = asJsonMap(source, 'entitlement');
    return ProductEntitlement(
      id: readString(json, 'id'),
      source: readEnum(json, 'source', EntitlementSource.values),
      wibDay: readInt(json, 'wibDay'),
      status: readEnum(
        json,
        'status',
        EntitlementStatus.values,
        fallback: EntitlementStatus.pending,
      ),
    );
  }

  /// Unique id, e.g. `HP-0001`.
  final String id;

  /// Origin of the entitlement.
  final EntitlementSource source;

  /// WIB day it was granted.
  final int wibDay;

  /// Fulfilment status.
  final EntitlementStatus status;

  /// Serializes the entitlement.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'source': source.name,
    'wibDay': wibDay,
    'status': status.name,
  };

  @override
  bool operator ==(Object other) =>
      other is ProductEntitlement &&
      other.id == id &&
      other.source == source &&
      other.wibDay == wibDay &&
      other.status == status;

  @override
  int get hashCode => Object.hash(id, source, wibDay, status);
}

/// The persisted result of one Roda Sabtu spin.
///
/// [landingSeed] and [productStockBefore] let the wheel show the same
/// segments and landing angle after a restart.
final class SpinRecord {
  const SpinRecord({
    required this.wibDay,
    required this.prizeId,
    required this.roll,
    required this.landingSeed,
    required this.configVersion,
    this.productStockBefore,
  });

  /// Restores a record written by [toJson].
  factory SpinRecord.fromJson(Object? source) {
    final json = asJsonMap(source, 'spin record');
    return SpinRecord(
      wibDay: readInt(json, 'wibDay'),
      prizeId: readString(json, 'prizeId'),
      roll: readInt(json, 'roll'),
      landingSeed: readInt(json, 'landingSeed'),
      configVersion: readString(json, 'configVersion'),
      productStockBefore: readOptionalInt(json, 'productStockBefore'),
    );
  }

  /// WIB day (a Saturday) of the spin.
  final int wibDay;

  /// Id of the [SpinPrize] that was won.
  final String prizeId;

  /// Random roll 0..9999 that decided the prize.
  final int roll;

  /// Seed for the wheel's landing position inside the winning segment.
  final int landingSeed;

  /// [SpinConfig.version] used for the spin.
  final String configVersion;

  /// Product stock right before the spin, which decided the wheel segments.
  /// Null only in documents saved before this field existed.
  final int? productStockBefore;

  /// Serializes the record.
  Map<String, Object?> toJson() => <String, Object?>{
    'wibDay': wibDay,
    'prizeId': prizeId,
    'roll': roll,
    'landingSeed': landingSeed,
    'configVersion': configVersion,
    'productStockBefore': productStockBefore,
  };

  @override
  bool operator ==(Object other) =>
      other is SpinRecord &&
      other.wibDay == wibDay &&
      other.prizeId == prizeId &&
      other.roll == roll &&
      other.landingSeed == landingSeed &&
      other.configVersion == configVersion &&
      other.productStockBefore == productStockBefore;

  @override
  int get hashCode => Object.hash(
    wibDay,
    prizeId,
    roll,
    landingSeed,
    configVersion,
    productStockBefore,
  );
}

/// Immutable snapshot of all reward data. Collections are unmodifiable.
final class RewardsState {
  RewardsState({
    List<LedgerEntry> ledger = const <LedgerEntry>[],
    this.streak = 0,
    this.lastClaimDay,
    List<ProductEntitlement> entitlements = const <ProductEntitlement>[],
    List<SpinRecord> spins = const <SpinRecord>[],
    this.promoActive = true,
    this.productStock = demoSpinProductStock,
    this.missionIssuedCount = 0,
    Set<String> countedOrderIds = const <String>{},
    List<MissionVoucher> vouchers = const <MissionVoucher>[],
    this.ledgerSeq = 0,
    this.entitlementSeq = 0,
    this.voucherSeq = 0,
  }) : ledger = List<LedgerEntry>.unmodifiable(ledger),
       entitlements = List<ProductEntitlement>.unmodifiable(entitlements),
       spins = List<SpinRecord>.unmodifiable(spins),
       countedOrderIds = Set<String>.unmodifiable(countedOrderIds),
       vouchers = List<MissionVoucher>.unmodifiable(vouchers);

  /// Restores a state written by [toJson].
  ///
  /// Throws [FormatException] on wrong types, negative counters or a negative
  /// ledger balance. Missing keys use the defaults of a fresh state.
  factory RewardsState.fromJson(Object? source) {
    final json = asJsonMap(source, 'rewards');
    final state = RewardsState(
      ledger: readList(json, 'ledger', LedgerEntry.fromJson),
      streak: readInt(json, 'streak', fallback: 0),
      lastClaimDay: readOptionalInt(json, 'lastClaimDay'),
      entitlements: readList(json, 'entitlements', ProductEntitlement.fromJson),
      spins: readList(json, 'spins', SpinRecord.fromJson),
      promoActive: readBool(json, 'promoActive', fallback: true),
      productStock: readInt(
        json,
        'productStock',
        fallback: demoSpinProductStock,
      ),
      missionIssuedCount: readInt(json, 'missionIssuedCount', fallback: 0),
      countedOrderIds: readStringList(json, 'countedOrderIds').toSet(),
      vouchers: readList(
        json,
        'vouchers',
        (item) => MissionVoucher.fromJson(asJsonMap(item, 'voucher')),
      ),
      ledgerSeq: readInt(json, 'ledgerSeq', fallback: 0),
      entitlementSeq: readInt(json, 'entitlementSeq', fallback: 0),
      voucherSeq: readInt(json, 'voucherSeq', fallback: 0),
    );
    final counters = <int>[
      state.streak,
      state.productStock,
      state.missionIssuedCount,
      state.ledgerSeq,
      state.entitlementSeq,
      state.voucherSeq,
    ];
    if (counters.any((value) => value < 0)) {
      throw const FormatException('Negative counter in rewards state');
    }
    if (ledgerBalance(state.ledger) < 0) {
      throw const FormatException('Negative Kelopak balance');
    }
    return state;
  }

  /// Chronological ledger (oldest first).
  final List<LedgerEntry> ledger;

  /// Stored check-in streak (see [RewardsEngine.liveStreak] for the live value).
  final int streak;

  /// WIB day of the last check-in, null before the first one.
  final int? lastClaimDay;

  /// Free-product rights, oldest first.
  final List<ProductEntitlement> entitlements;

  /// Spin history, oldest first.
  final List<SpinRecord> spins;

  /// Whether the Roda Sabtu promo runs (Mode Demo switch).
  final bool promoActive;

  /// Remaining product prizes on Roda Sabtu.
  final int productStock;

  /// Number of mission vouchers issued (= completed mission stages).
  final int missionIssuedCount;

  /// Orders already evaluated by Misi Belanja.
  final Set<String> countedOrderIds;

  /// Mission vouchers, oldest first.
  final List<MissionVoucher> vouchers;

  /// Last used ledger sequence number.
  final int ledgerSeq;

  /// Last used entitlement sequence number.
  final int entitlementSeq;

  /// Last used voucher sequence number.
  final int voucherSeq;

  /// Returns a copy with the given fields replaced.
  RewardsState copyWith({
    List<LedgerEntry>? ledger,
    int? streak,
    int? lastClaimDay,
    List<ProductEntitlement>? entitlements,
    List<SpinRecord>? spins,
    bool? promoActive,
    int? productStock,
    int? missionIssuedCount,
    Set<String>? countedOrderIds,
    List<MissionVoucher>? vouchers,
    int? ledgerSeq,
    int? entitlementSeq,
    int? voucherSeq,
  }) {
    return RewardsState(
      ledger: ledger ?? this.ledger,
      streak: streak ?? this.streak,
      lastClaimDay: lastClaimDay ?? this.lastClaimDay,
      entitlements: entitlements ?? this.entitlements,
      spins: spins ?? this.spins,
      promoActive: promoActive ?? this.promoActive,
      productStock: productStock ?? this.productStock,
      missionIssuedCount: missionIssuedCount ?? this.missionIssuedCount,
      countedOrderIds: countedOrderIds ?? this.countedOrderIds,
      vouchers: vouchers ?? this.vouchers,
      ledgerSeq: ledgerSeq ?? this.ledgerSeq,
      entitlementSeq: entitlementSeq ?? this.entitlementSeq,
      voucherSeq: voucherSeq ?? this.voucherSeq,
    );
  }

  /// Serializes the state (order ids sorted for a stable document).
  Map<String, Object?> toJson() => <String, Object?>{
    'ledger': ledger.map((entry) => entry.toJson()).toList(),
    'streak': streak,
    'lastClaimDay': lastClaimDay,
    'entitlements': entitlements.map((item) => item.toJson()).toList(),
    'spins': spins.map((record) => record.toJson()).toList(),
    'promoActive': promoActive,
    'productStock': productStock,
    'missionIssuedCount': missionIssuedCount,
    'countedOrderIds': countedOrderIds.toList()..sort(),
    'vouchers': vouchers.map((voucher) => voucher.toJson()).toList(),
    'ledgerSeq': ledgerSeq,
    'entitlementSeq': entitlementSeq,
    'voucherSeq': voucherSeq,
  };
}

/// Result of [RewardsEngine.claimCheckIn].
sealed class CheckInOutcome {
  const CheckInOutcome();
}

/// Check-in booked: [award] from the module, the balance after it and the
/// free-product entitlement granted on day 30, 60, ...
final class CheckInClaimed extends CheckInOutcome {
  const CheckInClaimed({
    required this.award,
    required this.newBalance,
    this.entitlement,
  });

  /// Module award (streak, daily, bonus, productEntitled, totalKelopak).
  final CheckInAward award;

  /// Kelopak balance after the claim.
  final int newBalance;

  /// Entitlement granted by this claim, if any.
  final ProductEntitlement? entitlement;
}

/// Today was already claimed; nothing changed.
final class CheckInAlreadyClaimed extends CheckInOutcome {
  const CheckInAlreadyClaimed();
}

/// Result of [RewardsEngine.spin].
sealed class SpinOutcome {
  const SpinOutcome();
}

/// Spin booked. Kelopak prizes are already credited; product prizes created
/// [entitlement] and used one unit of stock.
final class SpinCompleted extends SpinOutcome {
  const SpinCompleted({
    required this.record,
    required this.prize,
    required this.odds,
    required this.newBalance,
    this.entitlement,
  });

  /// Persisted record (feed `record.prizeId` and `record.landingSeed` to the wheel).
  final SpinRecord record;

  /// The prize that was won.
  final SpinPrize prize;

  /// Odds the spin was resolved with. Keep showing these on the wheel until it
  /// settles: the current odds may already differ (product 0% after the last unit).
  final List<SpinOdds> odds;

  /// Kelopak balance after the spin.
  final int newBalance;

  /// Entitlement for a product prize.
  final ProductEntitlement? entitlement;
}

/// Spin not allowed right now; [eligibility] says why.
final class SpinRejected extends SpinOutcome {
  const SpinRejected(this.eligibility);

  /// Why the spin was refused (never [SpinEligibility.available]).
  final SpinEligibility eligibility;
}

/// Mutable façade over [RewardsState]; every operation replaces [state].
final class RewardsEngine {
  RewardsEngine(
    RewardsState state, {
    this.spinConfig = demoSpinConfig,
    this.missionStages = demoMissionStages,
  }) : _state = state;

  RewardsState _state;

  /// Roda Sabtu campaign configuration.
  final SpinConfig spinConfig;

  /// Misi Belanja stages, in order.
  final List<MissionStage> missionStages;

  /// Current immutable snapshot (persist this).
  RewardsState get state => _state;

  // ---------------------------------------------------------------- Kelopak

  /// Kelopak balance (sum of the ledger, never negative).
  int get balance => ledgerBalance(_state.ledger);

  /// Chronological ledger (oldest first).
  List<LedgerEntry> get ledger => _state.ledger;

  /// Most Kelopak usable on a payable amount after voucher:
  /// `min(balance, floor(payable * 50% / Rp100))`.
  int maxKelopakFor(int payableAfterVoucher) {
    if (payableAfterVoucher <= 0) return 0;
    final cap =
        payableAfterVoucher *
        kelopakMaxDiscountPercent ~/
        100 ~/
        rupiahPerKelopak;
    return cap < balance ? cap : balance;
  }

  /// Books a checkout debit of [amount] Kelopak for [orderId].
  ///
  /// Throws [ArgumentError] for a negative amount and [StateError] when the
  /// balance is too low. Zero is a no-op.
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
      note: 'Dipakai di pesanan $orderId',
    );
  }

  // ---------------------------------------------------------- Check-in Harian

  /// Stored streak and last claim day (raw values, see [liveStreak]).
  int get storedStreak => _state.streak;

  /// WIB day of the last check-in, null before the first one.
  int? get lastClaimDay => _state.lastClaimDay;

  /// Streak that is still alive on [today] (0 when broken).
  int liveStreak(int today) => checkin.liveStreak(
    today: today,
    lastClaimDay: _state.lastClaimDay,
    streak: _state.streak,
  );

  /// Whether [today] is already claimed.
  bool claimedToday(int today) =>
      isClaimedOn(today: today, lastClaimDay: _state.lastClaimDay);

  /// True when a streak existed but a day was missed (show the gentle reset note).
  bool streakBroken(int today) {
    final last = _state.lastClaimDay;
    return _state.streak > 0 && last != null && last < today - 1;
  }

  /// Claims today's check-in.
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
    ProductEntitlement? entitlement;
    if (award.productEntitled) {
      final granted = _withEntitlement(next, EntitlementSource.checkIn, today);
      next = granted.state;
      entitlement = granted.entitlement;
    }
    _state = next.copyWith(streak: award.streak, lastClaimDay: today);
    return CheckInClaimed(
      award: award,
      newBalance: balance,
      entitlement: entitlement,
    );
  }

  // --------------------------------------------------------------- Roda Sabtu

  /// Spin history, oldest first.
  List<SpinRecord> get spins => _state.spins;

  /// Most recent spin, if any.
  SpinRecord? get lastSpin => _state.spins.isEmpty ? null : _state.spins.last;

  /// Spin made on [day], if any.
  SpinRecord? spinOn(int day) {
    for (final record in _state.spins.reversed) {
      if (record.wibDay == day) return record;
    }
    return null;
  }

  /// Whether the promo is running.
  bool get promoActive => _state.promoActive;

  /// Remaining product prizes.
  int get productStock => _state.productStock;

  /// Whether a spin is allowed on [today] (module rule).
  SpinEligibility spinEligibility(int today) => roda.spinEligibility(
    today: today,
    lastSpinDay: lastSpin?.wibDay,
    promoActive: _state.promoActive,
  );

  /// Odds for the current stock (product 0% when out of stock).
  List<SpinOdds> currentOdds() =>
      effectiveOdds(spinConfig, productStock: _state.productStock);

  /// Odds the wheel was spun with for [record], from the stock saved with it,
  /// so the result stays under the pointer after a restart, even when that
  /// spin took the last product. Older records without the stock assume
  /// stock for a product win and the current stock otherwise.
  List<SpinOdds> oddsFor(SpinRecord record) {
    final current = _state.productStock;
    final stock =
        record.productStockBefore ??
        (prizeById(record.prizeId)?.kind == PrizeKind.product && current < 1
            ? 1
            : current);
    return effectiveOdds(spinConfig, productStock: stock);
  }

  /// Prize with [id] in [spinConfig], or null when unknown.
  SpinPrize? prizeById(String id) {
    for (final prize in spinConfig.prizes) {
      if (prize.id == id) return prize;
    }
    return null;
  }

  /// Spins once. [roll] must be 0..9999; [landingSeed] is stored for replay.
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
    final odds = currentOdds();
    final prize = resolveSpin(
      spinConfig,
      productStock: _state.productStock,
      roll: roll,
    );
    final record = SpinRecord(
      wibDay: today,
      prizeId: prize.id,
      roll: roll,
      landingSeed: landingSeed,
      configVersion: spinConfig.version,
      productStockBefore: _state.productStock,
    );
    var next = _state.copyWith(spins: <SpinRecord>[..._state.spins, record]);
    ProductEntitlement? entitlement;
    switch (prize.kind) {
      case PrizeKind.product:
        final granted = _withEntitlement(next, EntitlementSource.spin, today);
        entitlement = granted.entitlement;
        final stock = granted.state.productStock;
        next = granted.state.copyWith(productStock: stock > 0 ? stock - 1 : 0);
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
    _state = next;
    return SpinCompleted(
      record: record,
      prize: prize,
      odds: odds,
      newBalance: balance,
      entitlement: entitlement,
    );
  }

  /// Turns the Roda Sabtu promo on or off (Mode Demo).
  void setPromoActive(bool active) {
    _state = _state.copyWith(promoActive: active);
  }

  /// Restores the product stock to [demoSpinProductStock] (Mode Demo).
  void refillProductStock() {
    _state = _state.copyWith(productStock: demoSpinProductStock);
  }

  // ------------------------------------------------------------ Misi Belanja

  /// Vouchers issued so far (= completed stages).
  int get missionIssuedCount => _state.missionIssuedCount;

  /// Stage that the next qualifying order would complete, or null when all are done.
  MissionStage? get activeStage {
    final index = _state.missionIssuedCount;
    return index < missionStages.length ? missionStages[index] : null;
  }

  /// Whether every configured stage is done (module rule).
  bool get allMissionStagesDone => allStagesDone(
    stages: missionStages,
    issuedCount: _state.missionIssuedCount,
  );

  /// Orders already evaluated by the mission.
  Set<String> get countedOrderIds => _state.countedOrderIds;

  /// Evaluates a completed order once and issues the stage voucher when it
  /// qualifies. The voucher expires on `today + stage.voucherValidDays`.
  MissionDecision completeOrder({
    required String orderId,
    required int eligibleSubtotal,
    required int today,
  }) {
    final decision = evaluateOrder(
      stages: missionStages,
      issuedCount: _state.missionIssuedCount,
      countedOrderIds: _state.countedOrderIds,
      orderId: orderId,
      eligibleSubtotal: eligibleSubtotal,
      completed: true,
    );
    if (_state.countedOrderIds.contains(orderId)) return decision;
    var next = _state.copyWith(
      countedOrderIds: <String>{..._state.countedOrderIds, orderId},
    );
    final stage = decision.issuedStage;
    if (decision.issued && stage != null) {
      final seq = next.voucherSeq + 1;
      final voucher = MissionVoucher.issue(
        id: 'VM-${seq.toString().padLeft(4, '0')}',
        stage: stage,
        sourceOrderId: orderId,
        issuedDay: today,
      );
      next = next.copyWith(
        vouchers: <MissionVoucher>[...next.vouchers, voucher],
        voucherSeq: seq,
        missionIssuedCount: next.missionIssuedCount + 1,
      );
    }
    _state = next;
    return decision;
  }

  // ----------------------------------------------------------------- Vouchers

  /// All mission vouchers, oldest first.
  List<MissionVoucher> get vouchers => _state.vouchers;

  /// Voucher with [id], or null.
  MissionVoucher? voucherById(String id) {
    for (final voucher in _state.vouchers) {
      if (voucher.id == id) return voucher;
    }
    return null;
  }

  /// Voucher issued for [orderId], or null.
  MissionVoucher? voucherFromOrder(String orderId) {
    for (final voucher in _state.vouchers) {
      if (voucher.sourceOrderId == orderId) return voucher;
    }
    return null;
  }

  /// Why [voucherId] cannot be used on [orderId] with [subtotal] (module rule),
  /// or null when it can. Throws [ArgumentError] for an unknown voucher.
  RedeemProblem? voucherProblem({
    required String voucherId,
    required String orderId,
    required int subtotal,
    required int today,
  }) {
    final voucher = voucherById(voucherId);
    if (voucher == null) {
      throw ArgumentError.value(voucherId, 'voucherId', 'unknown voucher');
    }
    return redeemProblem(
      voucher: voucher,
      orderId: orderId,
      subtotal: subtotal,
      today: today,
    );
  }

  /// Marks [voucherId] as used on [orderId].
  ///
  /// Throws [ArgumentError] for an unknown voucher and [StateError] when it was used already.
  void markVoucherUsed(String voucherId, String orderId) {
    final index = _state.vouchers.indexWhere((v) => v.id == voucherId);
    if (index < 0) {
      throw ArgumentError.value(voucherId, 'voucherId', 'unknown voucher');
    }
    final voucher = _state.vouchers[index];
    if (voucher.usedOnOrderId != null) {
      throw StateError('Voucher $voucherId was already used');
    }
    final vouchers = <MissionVoucher>[..._state.vouchers];
    vouchers[index] = voucher.markUsed(orderId);
    _state = _state.copyWith(vouchers: vouchers);
  }

  // ------------------------------------------------------------ Entitlements

  /// Free-product rights, oldest first.
  List<ProductEntitlement> get entitlements => _state.entitlements;

  // ------------------------------------------------------------------ helpers

  static RewardsState _withLedgerEntry(
    RewardsState state, {
    required int wibDay,
    required int amount,
    required LedgerKind kind,
    required String note,
  }) {
    final seq = state.ledgerSeq + 1;
    final entry = LedgerEntry(
      id: 'L${seq.toString().padLeft(6, '0')}',
      wibDay: wibDay,
      amount: amount,
      kind: kind,
      note: note,
    );
    return state.copyWith(
      ledger: <LedgerEntry>[...state.ledger, entry],
      ledgerSeq: seq,
    );
  }

  static ({RewardsState state, ProductEntitlement entitlement})
  _withEntitlement(RewardsState state, EntitlementSource source, int wibDay) {
    final seq = state.entitlementSeq + 1;
    final entitlement = ProductEntitlement(
      id: 'HP-${seq.toString().padLeft(4, '0')}',
      source: source,
      wibDay: wibDay,
    );
    return (
      state: state.copyWith(
        entitlements: <ProductEntitlement>[...state.entitlements, entitlement],
        entitlementSeq: seq,
      ),
      entitlement: entitlement,
    );
  }
}
