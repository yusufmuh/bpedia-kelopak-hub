/// Backend demo: mesin murni di perangkat, disimpan sebagai satu dokumen
/// ber-revisi di [KeyValueStore].
library;

import 'dart:math';

import '../domain/campaign.dart';
import '../domain/checkout.dart';
import '../domain/engine.dart';
import '../domain/outcomes.dart';
import '../domain/state.dart';
import '../storage/kelopak_document.dart';
import '../storage/key_value_store.dart';
import '../storage/migrate_v2.dart';
import '../storage/revisioned_document.dart';
import 'kelopak_backend.dart';

/// Asal data setelah [LocalKelopakBackend.load].
enum KelopakOrigin {
  /// Belum dimuat.
  notLoaded,

  /// Tidak ada dokumen: pemakaian pertama.
  fresh,

  /// Dokumen v3 dibaca.
  loaded,

  /// Tidak ada dokumen v3; data Kelopak dibawa dari dokumen app v2.
  migratedV2,

  /// Dokumen v3 rusak atau berskema lain: mulai bersih, lalu ditimpa saat
  /// penyimpanan berikutnya.
  corrupt,

  /// Penyimpanan perangkat gagal dibaca: sesi ini memakai memori supaya data
  /// yang tidak terbaca tidak pernah ditimpa.
  unreadable,
}

/// [KelopakBackend] lokal untuk demo, `example/`, dan tes.
///
/// Tiap aksi berjalan berurutan: dokumen tersimpan dibaca dulu (bila tab lain
/// menyimpan revisi lebih baru, datanya dipakai), aksi dijalankan mesin, lalu
/// hasilnya ditulis. Gagal menulis tidak pernah menggagalkan aksi; galatnya
/// ada di [lastSaveError].
final class LocalKelopakBackend implements KelopakBackend, KelopakDemoTools {
  LocalKelopakBackend({
    required KeyValueStore store,
    this.campaign = KelopakCampaign.demo,
    Random? random,
  }) : _document = KelopakDocument.storage(store),
       _random = random ?? _secureRandom(),
       _engine = KelopakEngine(KelopakState(), campaign: campaign);

  @override
  final KelopakCampaign campaign;

  final RevisionedDocument<KelopakState> _document;
  final Random _random;
  KelopakEngine _engine;
  Future<void> _queue = Future<void>.value();
  KelopakOrigin _origin = KelopakOrigin.notLoaded;
  int _adoptedUpdates = 0;
  Object? _lastSaveError;

  /// Dari mana data sesi ini berasal.
  KelopakOrigin get origin => _origin;

  /// Revisi dokumen yang terakhir dibaca atau ditulis.
  int get revision => _document.revision;

  /// Berapa kali data diganti dokumen lebih baru dari instans lain.
  int get adoptedUpdates => _adoptedUpdates;

  /// Galat penyimpanan terakhir; null setelah penyimpanan berhasil.
  Object? get lastSaveError => _lastSaveError;

  @override
  KelopakDemoTools get demoTools => this;

  @override
  Future<KelopakState> load() => _enqueue(() async {
    KelopakState state;
    try {
      final raw = await _document.readRaw();
      final snapshot = await _document.load();
      if (snapshot != null) {
        state = snapshot.value;
        _origin = KelopakOrigin.loaded;
      } else if (raw != null && raw.isNotEmpty) {
        state = KelopakState();
        _origin = KelopakOrigin.corrupt;
      } else {
        final migrated = migrateV2Kelopak(
          await _document.store.read(v2DocumentKey),
          campaign: campaign,
        );
        state = migrated ?? KelopakState();
        _origin = migrated == null
            ? KelopakOrigin.fresh
            : KelopakOrigin.migratedV2;
      }
    } catch (_) {
      _document.useMemoryFallback();
      state = KelopakState();
      _origin = KelopakOrigin.unreadable;
    }
    _engine = KelopakEngine(state, campaign: campaign);
    if (_origin == KelopakOrigin.migratedV2) await _write();
    return _engine.state;
  });

  @override
  Future<KelopakState?> refresh() =>
      _enqueue(() async => await _adoptNewer() ? _engine.state : null);

  @override
  Future<KelopakReply<CheckInOutcome>> claimCheckIn({required int today}) =>
      _run((engine) => engine.claimCheckIn(today));

  @override
  Future<KelopakReply<SpinOutcome>> spin({required int today}) => _run(
    (engine) => engine.spin(
      today: today,
      roll: _random.nextInt(10000),
      landingSeed: _random.nextInt(1 << 31),
    ),
  );

  @override
  Future<KelopakReply<PromoClaimOutcome>> claimPromoVoucher({
    required String promoId,
    required int amount,
    required int minSpend,
    required int validDays,
    required String title,
    required int today,
  }) => _run(
    (engine) => engine.claimPromoVoucher(
      promoId: promoId,
      amount: amount,
      minSpend: minSpend,
      validDays: validDays,
      title: title,
      today: today,
    ),
  );

  @override
  Future<KelopakReply<CommitOutcome>> commitOrder({
    required String orderId,
    required CheckoutQuote quote,
    required int today,
  }) => _run(
    (engine) =>
        engine.commitOrder(orderId: orderId, quote: quote, today: today),
  );

  @override
  Future<KelopakReply<OrderCancellation?>> cancelOrder({
    required String orderId,
    required int today,
  }) => _run((engine) => engine.cancelOrder(orderId, today));

  @override
  Future<KelopakReply<KelopakOrder?>> shipOrder({required String orderId}) =>
      _run((engine) => engine.shipOrder(orderId));

  @override
  Future<KelopakReply<OrderCompletion?>> completeOrder({
    required String orderId,
    required int today,
  }) => _run((engine) => engine.completeOrder(orderId, today));

  @override
  Future<void> flush() => _queue;

  // ---------------------------------------------------------------- Mode Demo

  @override
  Future<KelopakState> setPromoActive(bool active) =>
      _mutate((engine) => engine.setPromoActive(active));

  @override
  Future<KelopakState> setWheelQuotaLeft(int left, {required int today}) =>
      _mutate((engine) => engine.setWheelQuotaLeft(left, today));

  @override
  Future<KelopakState> grantKelopak(int amount, {required int today}) =>
      _mutate((engine) => engine.grantKelopak(amount, today));

  @override
  Future<KelopakState> reset() => _enqueue(() async {
    await _adoptNewer();
    _engine = KelopakEngine(KelopakState(), campaign: campaign);
    await _write();
    return _engine.state;
  });

  // ------------------------------------------------------------------ helpers

  Future<KelopakState> _mutate(void Function(KelopakEngine engine) change) =>
      _run<void>(change).then((reply) => reply.state);

  Future<KelopakReply<T>> _run<T>(T Function(KelopakEngine engine) action) =>
      _enqueue(() async {
        await _adoptNewer();
        final before = _engine.state;
        final value = action(_engine);
        if (!identical(_engine.state, before)) await _write();
        return KelopakReply<T>(state: _engine.state, value: value);
      });

  Future<T> _enqueue<T>(Future<T> Function() task) {
    final result = _queue.then((_) => task());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  /// Memakai dokumen tersimpan bila instans lain menyimpan revisi lebih baru.
  Future<bool> _adoptNewer() async {
    try {
      final newer = await _document.readNewer();
      if (newer == null) return false;
      _adopt(newer.value);
      return true;
    } catch (_) {
      // Tidak terbaca saat ini: pertahankan data; aksi berikutnya mencoba lagi.
      return false;
    }
  }

  Future<void> _write() async {
    try {
      final saved = await _document.save(_engine.state);
      if (saved is DocumentSuperseded<KelopakState>) _adopt(saved.newer.value);
      _lastSaveError = null;
    } catch (error) {
      _lastSaveError = error;
    }
  }

  void _adopt(KelopakState state) {
    _engine = KelopakEngine(state, campaign: campaign);
    _adoptedUpdates++;
  }

  static Random _secureRandom() {
    try {
      return Random.secure();
    } on UnsupportedError {
      return Random();
    }
  }
}
