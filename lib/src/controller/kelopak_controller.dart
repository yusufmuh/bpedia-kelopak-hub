/// Keadaan Kelopak untuk UI: satu [ChangeNotifier] di atas [KelopakBackend].
///
/// Memuat data, meneruskan aksi ke backend, memberi tahu pendengar saat data
/// berubah, dan memancarkan [KelopakEvent]. Keadaan yang wajar (sudah klaim,
/// bukan Sabtu, kutipan basi) datang sebagai hasil; hanya kegagalan backend
/// yang dilempar sebagai [KelopakBackendException].
library;

import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:misi_belanja/misi_belanja.dart'
    show MissionProgress, MissionStage, RedeemProblem, StageStatus, stageStatus;
import 'package:roda_sabtu/roda_sabtu.dart'
    show
        SpinConfig,
        SpinEligibility,
        SpinOdds,
        SpinPrize,
        WheelOpening,
        isSaturdayWib,
        wheelOpening;

import '../backend/kelopak_backend.dart';
import '../core/wib_clock.dart';
import '../domain/campaign.dart';
import '../domain/checkout.dart';
import '../domain/engine.dart';
import '../domain/gifts.dart';
import '../domain/ledger.dart';
import '../domain/outcomes.dart';
import '../domain/state.dart';
import '../domain/voucher.dart';
import '../host/kelopak_host.dart';
import 'kelopak_event.dart';

/// Controller sistem Kelopak. Buat dengan [KelopakController.open], lalu
/// sediakan ke pohon widget lewat `KelopakScope`.
class KelopakController extends ChangeNotifier {
  /// Membuat controller yang belum memuat data; panggil [load] sebelum
  /// dipakai. [watchDayChange] menjadwalkan pembaruan pada 00.00 WIB; beri
  /// false di tes widget supaya tidak ada timer tertunda.
  KelopakController({
    required this.backend,
    WibClock? clock,
    this.host,
    bool watchDayChange = true,
  }) : clock = clock ?? WibClock(),
       _watchDayChange = watchDayChange,
       _view = KelopakView(KelopakState(), campaign: backend.campaign) {
    _lastSeenDay = this.clock.today;
    host?.changes?.addListener(_hostChanged);
  }

  /// Membuat controller dan memuat datanya.
  static Future<KelopakController> open({
    required KelopakBackend backend,
    WibClock? clock,
    KelopakHost? host,
    bool watchDayChange = true,
  }) async {
    final controller = KelopakController(
      backend: backend,
      clock: clock,
      host: host,
      watchDayChange: watchDayChange,
    );
    await controller.load();
    return controller;
  }

  static const int _quoteCacheSize = 12;

  /// Sumber dan pencatat data.
  final KelopakBackend backend;

  /// Jam WIB dengan geseran hari Mode Demo.
  final WibClock clock;

  /// Aplikasi induk; null di tes mesin dan contoh tanpa host.
  final KelopakHost? host;

  final bool _watchDayChange;
  final StreamController<KelopakEvent> _events =
      StreamController<KelopakEvent>.broadcast(sync: true);
  final LinkedHashMap<String, CheckoutQuote> _recentQuotes =
      LinkedHashMap<String, CheckoutQuote>();
  KelopakView _view;
  Timer? _dayTimer;
  late int _lastSeenDay;
  bool _loaded = false;
  bool _disposed = false;
  int _adoptedUpdates = 0;
  KelopakBackendException? _lastError;

  // ------------------------------------------------------------------- dasar

  /// Kampanye yang berlaku.
  KelopakCampaign get campaign => backend.campaign;

  /// Apakah [load] sudah selesai.
  bool get isLoaded => _loaded;

  /// Potret data saat ini.
  KelopakState get state => _view.state;

  /// Pembacaan lengkap atas [state] (semua kueri mesin, tanpa mutasi).
  KelopakView get view => _view;

  /// Peristiwa Kelopak (siaran sinkron). Peristiwa yang sama juga dikirim ke
  /// `KelopakHost.onEvent`.
  Stream<KelopakEvent> get events => _events.stream;

  /// Kegagalan backend terakhir; null setelah aksi berikutnya berhasil.
  KelopakBackendException? get lastError => _lastError;

  /// Berapa kali data diganti keadaan lebih baru dari luar (tab lain).
  int get adoptedUpdates => _adoptedUpdates;

  /// Memuat data dari backend. Aman dipanggil ulang.
  Future<void> load() async {
    final state = await _guard(backend.load);
    _loaded = true;
    _scheduleDayTimer();
    _apply(state, force: true);
  }

  /// Membaca ulang backend dan memakai keadaan yang lebih baru (tab lain
  /// menyimpan, atau server berubah). Mengembalikan apakah ada yang dipakai.
  Future<bool> syncFromStore() async {
    final newer = await _guard(backend.refresh);
    if (newer == null || _disposed) return false;
    _adoptedUpdates++;
    _apply(newer, force: true);
    return true;
  }

  /// Selesai saat semua penulisan tertunda sudah tersimpan.
  Future<void> flush() => backend.flush();

  // ------------------------------------------------------------- tamu / masuk

  /// Apakah pengguna sudah masuk (tanpa host dianggap sudah).
  bool get isLoggedIn => host?.isLoggedIn ?? true;

  /// True bila sudah masuk. Bila tamu: membuka halaman Masuk host dan
  /// mengembalikan false. Panggil di awal aksi yang wajib masuk.
  bool ensureLoggedIn() {
    if (isLoggedIn) return true;
    host?.openLogin();
    return false;
  }

  // -------------------------------------------------------------------- waktu

  /// Hari WIB saat ini (termasuk geseran demo).
  int get today => clock.today;

  /// Apakah hari ini Sabtu (WIB).
  bool get isSaturday => isSaturdayWib(today);

  /// Sabtu pertama setelah hari ini.
  int get nextSaturday => clock.nextSaturday();

  /// Waktu nyata sampai 00.00 WIB.
  Duration untilNextDay() => clock.untilNextWibMidnight();

  /// Memberi tahu pendengar bila hari WIB berganti (panggil saat aplikasi
  /// kembali ke depan, dan setelah Mode Demo menggeser hari). Juga menyetel
  /// ulang timer 00.00 WIB dari jam dinding.
  void refreshDay() {
    if (_disposed) return;
    _scheduleDayTimer();
    final current = today;
    if (current == _lastSeenDay) return;
    _lastSeenDay = current;
    notifyListeners();
  }

  // ------------------------------------------------------------------ Kelopak

  /// Saldo Kelopak.
  int get balance => _view.balance;

  /// Buku besar, terlama lebih dulu.
  List<LedgerEntry> get ledger => _view.ledger;

  /// Buku besar dengan saldo berjalan, terbaru lebih dulu.
  List<LedgerLine> get ledgerHistory => _view.ledgerHistory;

  // ---------------------------------------------------------- Check-in Harian

  /// Rentetan yang masih hidup hari ini.
  int get liveStreak => _view.liveStreak(today);

  /// Apakah check-in hari ini sudah diklaim.
  bool get claimedToday => _view.claimedToday(today);

  /// Apakah tombol check-in tersedia.
  bool get canCheckIn => !claimedToday;

  /// Pernah ada rentetan tetapi ada hari terlewat.
  bool get streakBroken => _view.streakBroken(today);

  /// Hari rentetan klaim berikutnya ("Hari ke-4").
  int get nextCheckInStreakDay => liveStreak + 1;

  /// Hari WIB check-in berikutnya dibuka.
  int get nextCheckInDay => _view.nextCheckInDay(today);

  /// Slot terisi di lintasan 7 hari.
  int get checkInWeekFilled => _view.checkInWeekFilled(today);

  /// Kemajuan 0..30 menuju produk gratis.
  int get checkInMonthDay => _view.checkInMonthDay(today);

  /// Produk hadiah hari ke-30, bila kampanye dan katalog menyebutnya.
  KelopakProduct? get checkIn30Product =>
      productOf(campaign.checkIn30ProductCode);

  /// Mengklaim check-in hari ini.
  Future<CheckInOutcome> claimCheckIn() async {
    final reply = await _guard(() => backend.claimCheckIn(today: today));
    final outcome = reply.value;
    _apply(
      reply.state,
      events: <KelopakEvent>[
        if (outcome is CheckInClaimed)
          CheckInClaimedEvent(
            streak: outcome.award.streak,
            kelopak: outcome.award.totalKelopak,
            gift: outcome.gift,
          ),
      ],
    );
    return outcome;
  }

  // --------------------------------------------------------------- Roda Sabtu

  /// Konfigurasi roda.
  SpinConfig get spinConfig => _view.spinConfig;

  /// Apakah boleh memutar hari ini, dan bila tidak, mengapa.
  SpinEligibility get spinEligibility => _view.spinEligibility(today);

  /// Apakah tombol putar menyala.
  bool get canSpin => spinEligibility == SpinEligibility.available;

  /// Peluang untuk sisa kuota hari ini (tampilkan sebelum tombol putar).
  List<SpinOdds> get spinOdds => _view.currentOdds(today);

  /// Sisa kuota hadiah produk.
  int get wheelQuotaLeft => _view.wheelQuotaLeft(today);

  /// Apakah promo berjalan.
  bool get promoActive => _view.promoActive;

  /// Putaran hari ini, bila ada (hasilnya tetap tampil setelah buka ulang).
  SpinRecord? get todaySpin => _view.spinOn(today);

  /// Putaran terakhir.
  SpinRecord? get lastSpin => _view.lastSpin;

  /// Hadiah [record], atau null bila kampanye tidak lagi memilikinya.
  SpinPrize? prizeFor(SpinRecord record) => _view.prizeById(record.prizeId);

  /// Peluang saat [record] diputar (irisan roda untuk memutar ulang).
  List<SpinOdds> oddsForSpin(SpinRecord record) => _view.oddsFor(record);

  /// Sisa kuota saat [record] diputar.
  int stockForSpin(SpinRecord record) => _view.stockFor(record);

  /// Sabtu berikutnya yang putarannya masih bisa dipakai.
  int get nextSpinSaturday => _view.nextSpinSaturday(today);

  /// Pembukaan roda pada [saturday] dilihat dari sekarang.
  WheelOpening wheelOpeningOn(int saturday) =>
      wheelOpening(saturday: saturday, now: clock.instant);

  /// Pembukaan roda berikutnya; semua layar memakai ini supaya kalimatnya
  /// sama.
  WheelOpening get nextWheelOpening => wheelOpeningOn(nextSpinSaturday);

  /// Produk hadiah roda pekan ini, bila kampanye dan katalog menyebutnya.
  KelopakProduct? get wheelProduct =>
      productOf(campaign.wheelProductCodeOn(today));

  /// Memutar sekali; backend yang mengundi. Hasil sudah final sebelum
  /// animasi: berikan `record.prizeId` dan `record.landingSeed` ke roda.
  Future<SpinOutcome> spin() async {
    final reply = await _guard(() => backend.spin(today: today));
    final outcome = reply.value;
    _apply(
      reply.state,
      events: <KelopakEvent>[
        if (outcome is SpinCompleted)
          WheelSpunEvent(
            prizeId: outcome.prize.id,
            kelopak: outcome.prize.kelopak,
            gift: outcome.gift,
          ),
      ],
    );
    return outcome;
  }

  // ------------------------------------------------------------ Misi Belanja

  /// Tahap misi berurutan.
  List<MissionStage> get missionStages => _view.missionStages;

  /// Voucher misi yang sudah terbit (= tahap selesai).
  int get missionIssuedCount => _view.missionIssuedCount;

  /// Tahap aktif, atau null bila semua selesai.
  MissionStage? get activeMissionStage => _view.activeStage;

  /// Apakah semua tahap selesai.
  bool get allMissionStagesDone => _view.allMissionStagesDone;

  /// Status tahap ke-[stageIndex] (aturan modul).
  StageStatus missionStageStatus(int stageIndex) =>
      stageStatus(stageIndex: stageIndex, issuedCount: missionIssuedCount);

  /// Kode produk misi tahap aktif (kosong = semua produk dihitung).
  Set<String> get missionProductCodes => _view.missionProductCodes;

  /// Produk misi tahap aktif yang ada di katalog host.
  List<KelopakProduct> get missionProducts => <KelopakProduct>[
    for (final code in activeMissionStage?.productCodes ?? const <String>[])
      ?productOf(code),
  ];

  /// Kemajuan tahap aktif bila [lines] dipesan sekaligus; null bila semua
  /// tahap selesai.
  MissionProgress? missionProgressFor(Iterable<CheckoutLine> lines) =>
      _view.missionProgressFor(lines);

  /// Kemajuan tahap aktif untuk isi keranjang host saat ini.
  MissionProgress? get cartMissionProgress =>
      missionProgressFor(host?.cartLines ?? const <CheckoutLine>[]);

  // ------------------------------------------------------ voucher dan hadiah

  /// Semua voucher, terbaru lebih dulu.
  List<KelopakVoucher> get vouchers =>
      _view.vouchers.reversed.toList(growable: false);

  /// Voucher yang belum dipakai dan belum kedaluwarsa, terbaru lebih dulu.
  List<KelopakVoucher> get activeVouchers => _view.activeVouchers(today);

  /// Apakah [voucher] belum dipakai dan belum kedaluwarsa hari ini.
  bool isVoucherActive(KelopakVoucher voucher) => voucher.isActiveOn(today);

  /// Mengapa [voucher] tidak bisa dipakai untuk subtotal barang
  /// [goodsSubtotal] hari ini, atau null bila bisa.
  RedeemProblem? voucherProblemFor(KelopakVoucher voucher, int goodsSubtotal) =>
      voucher.problemFor(orderId: '', subtotal: goodsSubtotal, today: today);

  final Set<String> _celebratedMissionVouchers = <String>{};

  /// Menandai perayaan "Misi tuntas" untuk voucher [voucherId] sudah tampil.
  /// True hanya untuk pemanggil pertama, sehingga halaman Misi Belanja dan
  /// `showMissionCompleteCelebration` tidak merayakan voucher yang sama dua
  /// kali.
  bool claimMissionCelebration(String voucherId) =>
      _celebratedMissionVouchers.add(voucherId);

  /// Voucher event yang belum dibuka hari ini dan belum pernah diklaim,
  /// urut tanggal buka.
  List<KelopakVoucherTeaser> get upcomingVouchers {
    final claimed = <String>{for (final voucher in vouchers) ?voucher.promoId};
    return campaign.upcomingVouchers
        .where(
          (teaser) =>
              teaser.opensDay > today && !claimed.contains(teaser.promoId),
        )
        .toList(growable: false)
      ..sort((a, b) => a.opensDay.compareTo(b.opensDay));
  }

  /// Apakah voucher promo [promoId] belum pernah diklaim.
  bool canClaimPromoVoucher(String promoId) =>
      _view.canClaimPromoVoucher(promoId);

  /// Mengklaim voucher promo (sekali per promo).
  Future<PromoClaimOutcome> claimPromoVoucher({
    required String promoId,
    required int amount,
    required int minSpend,
    required int validDays,
    String title = 'Voucher promo',
  }) async {
    final reply = await _guard(
      () => backend.claimPromoVoucher(
        promoId: promoId,
        amount: amount,
        minSpend: minSpend,
        validDays: validDays,
        title: title,
        today: today,
      ),
    );
    final outcome = reply.value;
    _apply(
      reply.state,
      events: <KelopakEvent>[
        if (outcome is PromoVoucherClaimed)
          PromoVoucherClaimedEvent(outcome.voucher),
      ],
    );
    return outcome;
  }

  /// Semua hadiah produk gratis, terbaru lebih dulu.
  List<PendingGift> get gifts => _view.gifts.reversed.toList(growable: false);

  /// Hadiah yang menunggu pesanan berikutnya (baris Rp0 di keranjang).
  List<PendingGift> get pendingGifts => _view.pendingGifts;

  /// Data tampilan produk [code] dari host; null bila [code] null, tidak ada
  /// host, atau produk tidak ada di katalog.
  KelopakProduct? productOf(String? code) =>
      code == null ? null : host?.productOf(code);

  // ----------------------------------------------------------------- checkout

  /// Rincian harga [request] hari ini (murah; boleh dipanggil di build).
  /// Kutipan diingat supaya bisa diambil lagi dengan [quoteByToken].
  CheckoutQuote quote(CheckoutRequest request) {
    final quote = _view.quote(request, today: today);
    final token = quote.token;
    _recentQuotes
      ..remove(token)
      ..[token] = quote;
    while (_recentQuotes.length > _quoteCacheSize) {
      _recentQuotes.remove(_recentQuotes.keys.first);
    }
    return quote;
  }

  /// Kutipan terakhir ber-[token] (untuk adaptor yang hanya menyimpan token).
  CheckoutQuote? quoteByToken(String token) => _recentQuotes[token];

  /// Mengapa [quote] tidak bisa dikomit sekarang, atau null bila bisa.
  CheckoutProblem? problemWith(CheckoutQuote quote) =>
      _view.problemWith(quote, today: today);

  /// Mengikat [quote] ke pesanan [orderId]: Kelopak didebit, voucher
  /// ditandai, hadiah terlampir. Kutipan basi ditolak tanpa mengubah apa pun.
  Future<CommitOutcome> commitOrder(String orderId, CheckoutQuote quote) async {
    final repeat = _view.orderById(orderId) != null;
    final reply = await _guard(
      () => backend.commitOrder(orderId: orderId, quote: quote, today: today),
    );
    final outcome = reply.value;
    final events = <KelopakEvent>[];
    if (outcome is OrderCommitted && !repeat) {
      final order = outcome.order;
      final voucherId = order.voucherId;
      if (voucherId != null) {
        events.add(
          VoucherRedeemedEvent(
            orderId: orderId,
            voucherId: voucherId,
            amount: order.voucherAmount,
          ),
        );
      }
      if (order.kelopakUsed > 0) {
        events.add(
          KelopakRedeemedEvent(
            orderId: orderId,
            kelopak: order.kelopakUsed,
            value: order.kelopakValue,
          ),
        );
      }
      if (order.giftIds.isNotEmpty) {
        events.add(
          GiftAttachedEvent(
            orderId: orderId,
            gifts: KelopakView(reply.state).giftsOfOrder(orderId),
          ),
        );
      }
    }
    _apply(reply.state, events: events);
    return outcome;
  }

  /// Membatalkan pesanan: Kelopak, voucher, dan hadiah kembali. Null bila
  /// pesanan tidak dikenal atau sudah tidak bisa dibatalkan.
  Future<OrderCancellation?> cancelOrder(String orderId) async {
    final reply = await _guard(
      () => backend.cancelOrder(orderId: orderId, today: today),
    );
    final cancellation = reply.value;
    _apply(
      reply.state,
      events: <KelopakEvent>[
        if (cancellation != null)
          OrderRefundedEvent(
            orderId: orderId,
            kelopak: cancellation.kelopakRefunded,
            voucher: cancellation.voucher,
            gifts: cancellation.gifts,
          ),
      ],
    );
    return cancellation;
  }

  /// Menandai pesanan dikirim; hadiah terlampir ikut dikirim.
  Future<KelopakOrder?> shipOrder(String orderId) async {
    final reply = await _guard(() => backend.shipOrder(orderId: orderId));
    final order = reply.value;
    final gifts = KelopakView(reply.state).giftsOfOrder(orderId);
    _apply(
      reply.state,
      events: <KelopakEvent>[
        if (order != null && gifts.isNotEmpty)
          GiftsShippedEvent(orderId: orderId, gifts: gifts),
      ],
    );
    return order;
  }

  /// "Pesanan Diterima": hadiah diterima dan Misi Belanja dievaluasi. Null
  /// bila pesanan tidak dikenal atau sudah selesai.
  Future<OrderCompletion?> completeOrder(String orderId) async {
    final reply = await _guard(
      () => backend.completeOrder(orderId: orderId, today: today),
    );
    final completion = reply.value;
    final voucher = completion?.voucher;
    _apply(
      reply.state,
      events: <KelopakEvent>[
        if (completion != null && completion.gifts.isNotEmpty)
          GiftsReceivedEvent(orderId: orderId, gifts: completion.gifts),
        if (completion != null && voucher != null)
          MissionCompletedEvent(
            orderId: orderId,
            stageNumber:
                completion.decision.issuedStage?.number ??
                voucher.stageNumber ??
                0,
            voucher: voucher,
          ),
      ],
    );
    return completion;
  }

  // ---------------------------------------------------------- Mode Demo (QA)

  /// Apakah backend menyediakan alat Mode Demo.
  bool get hasDemoTools => backend.demoTools != null;

  /// Menyalakan atau mematikan promo Roda Sabtu. False bila backend tidak
  /// menyediakan alat demo.
  Future<bool> setPromoActive(bool active) =>
      _demo((tools) => tools.setPromoActive(active));

  /// Mengatur sisa kuota hadiah produk roda.
  Future<bool> setWheelQuotaLeft(int left) =>
      _demo((tools) => tools.setWheelQuotaLeft(left, today: today));

  /// Mengisi penuh kuota hadiah produk roda.
  Future<bool> refillWheelQuota() => setWheelQuotaLeft(campaign.wheelQuota);

  /// Menambah [amount] Kelopak ke saldo.
  Future<bool> grantKelopak(int amount) =>
      _demo((tools) => tools.grantKelopak(amount, today: today));

  /// Menghapus seluruh data hadiah.
  Future<bool> resetAll() => _demo((tools) => tools.reset());

  @override
  void dispose() {
    _disposed = true;
    _dayTimer?.cancel();
    host?.changes?.removeListener(_hostChanged);
    unawaited(_events.close());
    super.dispose();
  }

  // ------------------------------------------------------------------ helpers

  Future<bool> _demo(
    Future<KelopakState> Function(KelopakDemoTools tools) change,
  ) async {
    final tools = backend.demoTools;
    if (tools == null) return false;
    _apply(await _guard(() => change(tools)));
    return true;
  }

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      final result = await call();
      _lastError = null;
      return result;
    } on KelopakBackendException catch (error) {
      _lastError = error;
      rethrow;
    }
  }

  void _apply(
    KelopakState state, {
    List<KelopakEvent> events = const <KelopakEvent>[],
    bool force = false,
  }) {
    if (_disposed) return;
    final changed = force || !identical(state, _view.state);
    if (changed) {
      _view = KelopakView(state, campaign: campaign);
      _lastSeenDay = today;
      notifyListeners();
    }
    for (final event in events) {
      _events.add(event);
      host?.onEvent(event);
    }
  }

  void _hostChanged() {
    if (!_disposed) notifyListeners();
  }

  void _scheduleDayTimer() {
    _dayTimer?.cancel();
    if (!_watchDayChange || _disposed) return;
    _dayTimer = Timer(
      clock.untilNextWibMidnight() + const Duration(seconds: 1),
      refreshDay,
    );
  }
}
