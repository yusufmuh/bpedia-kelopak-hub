/// `WheelController` modul `roda_sabtu` di atas [KelopakController].
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:roda_sabtu/roda_sabtu.dart' as roda;

import '../controller/kelopak_controller.dart';
import '../domain/outcomes.dart';
import '../domain/state.dart';
import '../host/kelopak_host.dart';
import 'game_link.dart';

/// Roda Sabtu sungguhan: kuota, putaran, dan riwayat dari mesin Kelopak;
/// undian di backend; pengingat lewat `KelopakHost.reminder`.
class KelopakWheelController extends roda.WheelController with KelopakGameLink {
  /// Membuat controller di atas [kelopak]. [onOpenTerms] membuka aturan
  /// lengkap (biasanya lembar "Cara pakai").
  KelopakWheelController(
    KelopakController kelopak, {
    VoidCallback? onOpenTerms,
  }) {
    linkTo(kelopak, onOpenTerms: onOpenTerms);
    unawaited(_loadReminder());
  }

  bool _busy = false;
  bool _reminderOn = false;
  bool _disposed = false;
  roda.WheelViewState? _cached;

  KelopakReminder? get _reminder {
    final reminder = host?.reminder;
    return reminder != null && reminder.isSupported ? reminder : null;
  }

  Future<void> _loadReminder() async {
    final reminder = _reminder;
    if (reminder == null) return;
    final on = await reminder.isEnabled();
    if (_disposed || on == _reminderOn) return;
    _reminderOn = on;
    _cached = null;
    notifyListeners();
  }

  @override
  void onKelopakChanged() => _cached = null;

  @override
  roda.WheelViewState get state => _cached ??= _build();

  roda.WheelViewState _build() {
    final product = _prizeProduct(kelopak.wheelProduct);
    final reminderSupported = _reminder != null;
    if (!kelopak.isLoggedIn) {
      return roda.WheelViewState.guest(
        today: kelopak.today,
        config: kelopak.spinConfig,
        productQuotaLeft: kelopak.wheelQuotaLeft,
        promoActive: kelopak.promoActive,
        product: product,
        reminderSupported: reminderSupported,
        soundOn: hostSoundOn,
      );
    }
    return roda.WheelViewState(
      signedIn: true,
      today: kelopak.today,
      config: kelopak.spinConfig,
      productQuotaLeft: kelopak.wheelQuotaLeft,
      promoActive: kelopak.promoActive,
      lastSpinDay: kelopak.lastSpin?.wibDay,
      balance: kelopak.balance,
      product: product,
      history: <roda.WheelSpinRecord>[
        for (final record in kelopak.view.spins.reversed) ?_historyOf(record),
      ],
      reminderSupported: reminderSupported,
      reminderOn: _reminderOn,
      soundOn: hostSoundOn,
      busy: _busy,
    );
  }

  roda.WheelSpinRecord? _historyOf(SpinRecord record) {
    final prize = kelopak.prizeFor(record);
    if (prize == null) return null;
    return roda.WheelSpinRecord.fromPrize(
      prize,
      day: record.wibDay,
      productName: _giftProduct(record.giftId)?.name,
    );
  }

  KelopakProduct? _giftProduct(String? giftId) {
    if (giftId == null) return null;
    return kelopak.productOf(kelopak.view.giftById(giftId)?.productCode);
  }

  static roda.WheelPrizeProduct? _prizeProduct(KelopakProduct? product) {
    final image = product?.image;
    if (product == null || image == null) return null;
    return roda.WheelPrizeProduct(
      code: product.code,
      name: product.name,
      image: image,
      price: product.price,
      strikePrice: product.strikePrice,
    );
  }

  @override
  DateTime now() => kelopak.clock.instant;

  @override
  Future<void> refresh() async {
    kelopak.refreshDay();
    await kelopak.syncFromStore();
    _cached = null;
    notifyListeners();
  }

  @override
  Future<roda.WheelSpinResult?> spin() async {
    if (_busy || !kelopak.ensureLoggedIn() || !kelopak.canSpin) return null;
    _setBusy(true);
    try {
      final outcome = await kelopak.spin();
      if (outcome is! SpinCompleted) return null;
      final gift = outcome.gift;
      return roda.WheelSpinResult(
        prize: outcome.prize,
        landingSeed: outcome.record.landingSeed,
        balance: outcome.newBalance,
        product: gift == null
            ? null
            : _prizeProduct(kelopak.productOf(gift.productCode)),
      );
    } finally {
      _setBusy(false);
    }
  }

  void _setBusy(bool value) {
    if (_busy == value || _disposed) return;
    _busy = value;
    _cached = null;
    notifyListeners();
  }

  @override
  Future<void> setReminder(bool on) async {
    final reminder = _reminder;
    if (reminder == null) return;
    final result = await reminder.setEnabled(on);
    if (_disposed) return;
    _reminderOn = result;
    _cached = null;
    notifyListeners();
  }

  @override
  void openLogin() => host?.openLogin();

  @override
  void openShop() => host?.openShop();

  @override
  void openCart() => host?.openCart();

  @override
  void openProduct(String code) => host?.openProduct(code);

  @override
  void openTerms() => openTermsSheet();

  @override
  void playCue(roda.GameCue cue) => playCueNamed(cue.name);

  @override
  void setSoundOn(bool value) {
    _cached = null;
    setHostSound(value);
  }

  @override
  void dispose() {
    _disposed = true;
    unlink();
    super.dispose();
  }
}
