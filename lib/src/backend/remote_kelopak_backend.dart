/// Kontrak backend server otoritatif.
///
/// Hub tidak membawa paket HTTP: aplikasi induk menyuntikkan
/// [KelopakTransport] (misalnya di atas `package:http` dengan token sesi
/// miliknya). Server menjalankan aturan yang sama dengan `KelopakEngine`
/// (lihat `server/*.php`) dan selalu membalas keadaan terbaru.
///
/// Bentuk balasan setiap aksi:
///
/// ```json
/// { "state": { ...KelopakState.toJson() }, "result": { ...lihat reply_codec.dart } }
/// ```
///
/// `GET /kelopak/state` cukup membalas `{"state": {...}}`.
library;

import '../domain/campaign.dart';
import '../domain/checkout.dart';
import '../domain/outcomes.dart';
import '../domain/state.dart';
import '../storage/json_reader.dart';
import 'kelopak_backend.dart';
import 'reply_codec.dart';

/// Aksi pada kontrak server dan endpoint REST yang disarankan.
///
/// | Aksi | Endpoint | Isi permintaan | `result` |
/// |---|---|---|---|
/// | [read] | `GET /kelopak/state` | - | - |
/// | [checkIn] | `POST /kelopak/check-in` | `today` | `claimed`, `streak`, `dailyKelopak`, `bonusKelopak`, `productEntitled`, `giftId` |
/// | [spin] | `POST /kelopak/wheel/spin` | `today` | `spun`, `wibDay` atau `reason` |
/// | [claimPromo] | `POST /kelopak/vouchers/promo` | `promoId`, `amount`, `minSpend`, `validDays`, `title`, `today` | `claimed`, `voucherId` atau `problem` |
/// | [commit] | `POST /kelopak/orders/commit` | `orderId`, `request`, `token`, `today` | `committed`, `orderId` atau `problem` |
/// | [cancel] | `POST /kelopak/orders/cancel` | `orderId`, `today` | `cancelled`, `kelopakRefunded`, `voucherId`, `giftIds` |
/// | [ship] | `POST /kelopak/orders/ship` | `orderId` | `shipped`, `orderId` |
/// | [complete] | `POST /kelopak/orders/complete` | `orderId`, `today` | `completed`, `issuedStage`, `rejection`, `voucherId`, `giftIds` |
///
/// Server mengundi roda sendiri, menghitung ulang kutipan dari `request`,
/// dan menolak komit dengan `quoteOutdated` bila `token` tidak lagi cocok.
/// `today` hanya petunjuk untuk lingkungan demo; server produksi memakai
/// jam WIB miliknya.
enum KelopakAction {
  /// Membaca keadaan.
  read('GET', '/kelopak/state'),

  /// Klaim Check-in Harian.
  checkIn('POST', '/kelopak/check-in'),

  /// Memutar Roda Sabtu.
  spin('POST', '/kelopak/wheel/spin'),

  /// Klaim voucher promo.
  claimPromo('POST', '/kelopak/vouchers/promo'),

  /// Komit pesanan.
  commit('POST', '/kelopak/orders/commit'),

  /// Batal pesanan.
  cancel('POST', '/kelopak/orders/cancel'),

  /// Pesanan dikirim.
  ship('POST', '/kelopak/orders/ship'),

  /// Pesanan diterima.
  complete('POST', '/kelopak/orders/complete');

  const KelopakAction(this.method, this.path);

  /// Metode HTTP.
  final String method;

  /// Jalur endpoint relatif terhadap alamat dasar API.
  final String path;
}

/// Pengirim permintaan ke server. Implementasi mengurus alamat dasar,
/// autentikasi, dan batas waktu, lalu mengembalikan badan JSON balasan.
///
/// Kegagalan (jaringan, status bukan 2xx) dilempar sebagai galat apa pun;
/// [RemoteKelopakBackend] membungkusnya menjadi [KelopakBackendException].
abstract interface class KelopakTransport {
  /// Mengirim [action] dengan badan [body] (kosong untuk `GET`).
  Future<JsonMap> send(KelopakAction action, JsonMap body);
}

/// [KelopakBackend] di atas server otoritatif.
final class RemoteKelopakBackend implements KelopakBackend {
  RemoteKelopakBackend({
    required KelopakTransport transport,
    required this.campaign,
  }) : _transport = transport;

  /// Pesan bawaan saat server tidak bisa dihubungi.
  static const String offlineMessage =
      'Belum bisa terhubung. Coba lagi sebentar, ya.';

  @override
  final KelopakCampaign campaign;

  final KelopakTransport _transport;
  String? _lastStateText;

  @override
  KelopakDemoTools? get demoTools => null;

  @override
  Future<KelopakState> load() async {
    final reply = await _call(KelopakAction.read, const <String, Object?>{});
    return reply.state;
  }

  @override
  Future<KelopakState?> refresh() async {
    final before = _lastStateText;
    final reply = await _call(KelopakAction.read, const <String, Object?>{});
    return _lastStateText == before ? null : reply.state;
  }

  @override
  Future<KelopakReply<CheckInOutcome>> claimCheckIn({
    required int today,
  }) async {
    final reply = await _call(KelopakAction.checkIn, <String, Object?>{
      'today': today,
    });
    return _decode(reply, (json) => decodeCheckInOutcome(json, reply.state));
  }

  @override
  Future<KelopakReply<SpinOutcome>> spin({required int today}) async {
    final reply = await _call(KelopakAction.spin, <String, Object?>{
      'today': today,
    });
    return _decode(
      reply,
      (json) => decodeSpinOutcome(json, reply.state, campaign),
    );
  }

  @override
  Future<KelopakReply<PromoClaimOutcome>> claimPromoVoucher({
    required String promoId,
    required int amount,
    required int minSpend,
    required int validDays,
    required String title,
    required int today,
  }) async {
    final reply = await _call(KelopakAction.claimPromo, <String, Object?>{
      'promoId': promoId,
      'amount': amount,
      'minSpend': minSpend,
      'validDays': validDays,
      'title': title,
      'today': today,
    });
    return _decode(reply, (json) => decodePromoClaimOutcome(json, reply.state));
  }

  @override
  Future<KelopakReply<CommitOutcome>> commitOrder({
    required String orderId,
    required CheckoutQuote quote,
    required int today,
  }) async {
    final reply = await _call(KelopakAction.commit, <String, Object?>{
      'orderId': orderId,
      'request': quote.request.toJson(),
      'token': quote.token,
      'today': today,
    });
    return _decode(reply, (json) => decodeCommitOutcome(json, reply.state));
  }

  @override
  Future<KelopakReply<OrderCancellation?>> cancelOrder({
    required String orderId,
    required int today,
  }) async {
    final reply = await _call(KelopakAction.cancel, <String, Object?>{
      'orderId': orderId,
      'today': today,
    });
    return _decode(reply, (json) => decodeCancellation(json, reply.state));
  }

  @override
  Future<KelopakReply<KelopakOrder?>> shipOrder({
    required String orderId,
  }) async {
    final reply = await _call(KelopakAction.ship, <String, Object?>{
      'orderId': orderId,
    });
    return _decode(reply, (json) => decodeShipment(json, reply.state));
  }

  @override
  Future<KelopakReply<OrderCompletion?>> completeOrder({
    required String orderId,
    required int today,
  }) async {
    final reply = await _call(KelopakAction.complete, <String, Object?>{
      'orderId': orderId,
      'today': today,
    });
    return _decode(
      reply,
      (json) => decodeCompletion(json, reply.state, campaign),
    );
  }

  @override
  Future<void> flush() async {}

  Future<({KelopakState state, JsonMap result})> _call(
    KelopakAction action,
    JsonMap body,
  ) async {
    final JsonMap response;
    try {
      response = await _transport.send(action, body);
    } catch (error) {
      throw KelopakBackendException(offlineMessage, cause: error);
    }
    try {
      final state = KelopakState.fromJson(response['state']);
      _lastStateText = state.toJson().toString();
      final result = response['result'];
      return (
        state: state,
        result: result == null
            ? const <String, Object?>{}
            : asJsonMap(result, 'result'),
      );
    } on FormatException catch (error) {
      throw KelopakBackendException(
        'Balasan server tidak bisa dibaca.',
        cause: error,
      );
    }
  }

  KelopakReply<T> _decode<T>(
    ({KelopakState state, JsonMap result}) reply,
    T Function(JsonMap json) decode,
  ) {
    try {
      return KelopakReply<T>(state: reply.state, value: decode(reply.result));
    } on FormatException catch (error) {
      throw KelopakBackendException(
        'Balasan server tidak bisa dibaca.',
        cause: error,
      );
    }
  }
}
