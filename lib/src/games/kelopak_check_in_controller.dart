/// `CheckInController` modul `daily_checkin` di atas [KelopakController].
library;

import 'package:daily_checkin/daily_checkin.dart' as checkin;
import 'package:flutter/foundation.dart';

import '../controller/kelopak_controller.dart';
import '../domain/outcomes.dart';
import '../host/kelopak_host.dart';
import 'game_link.dart';

/// Check-in Harian sungguhan: keadaan dari mesin Kelopak, klaim lewat
/// backend, navigasi dan suara lewat `KelopakHost`.
class KelopakCheckInController extends checkin.CheckInController
    with KelopakGameLink {
  /// Membuat controller di atas [kelopak]. [onOpenTerms] membuka aturan
  /// lengkap (biasanya lembar "Cara pakai").
  KelopakCheckInController(
    KelopakController kelopak, {
    VoidCallback? onOpenTerms,
  }) {
    linkTo(kelopak, onOpenTerms: onOpenTerms);
  }

  bool _busy = false;
  checkin.CheckInViewState? _cached;

  @override
  void onKelopakChanged() => _cached = null;

  @override
  checkin.CheckInViewState get state => _cached ??= _build();

  checkin.CheckInViewState _build() {
    final reward = _rewardProduct(kelopak.checkIn30Product);
    final soundOn = hostSoundOn;
    if (!kelopak.isLoggedIn) {
      return checkin.CheckInViewState.guest(
        rewardProduct: reward,
        soundOn: soundOn,
      );
    }
    final view = kelopak.view;
    final nextRealDay = kelopak.clock.realToday + 1;
    return checkin.CheckInViewState.fromProgress(
      today: kelopak.today,
      lastClaimDay: view.lastClaimDay,
      storedStreak: view.storedStreak,
      balance: kelopak.balance,
      nextResetAt: DateTime.fromMillisecondsSinceEpoch(
        nextRealDay * Duration.millisecondsPerDay -
            7 * Duration.millisecondsPerHour,
        isUtc: true,
      ),
      rewardProduct: reward,
      soundOn: soundOn,
      busy: _busy,
    );
  }

  static checkin.CheckInRewardProduct? _rewardProduct(KelopakProduct? product) {
    final image = product?.image;
    if (product == null || image == null) return null;
    return checkin.CheckInRewardProduct(
      code: product.code,
      name: product.name,
      image: image,
      price: product.price,
      strikePrice: product.strikePrice,
    );
  }

  @override
  DateTime now() => kelopak.clock.now();

  @override
  Future<void> refresh() async {
    kelopak.refreshDay();
    await kelopak.syncFromStore();
    _cached = null;
    notifyListeners();
  }

  @override
  Future<checkin.CheckInClaimResult?> claim() async {
    if (_busy || !kelopak.ensureLoggedIn()) return null;
    _setBusy(true);
    try {
      final outcome = await kelopak.claimCheckIn();
      if (outcome is! CheckInClaimed) return null;
      return checkin.CheckInClaimResult(
        award: outcome.award,
        balance: outcome.newBalance,
        product: outcome.gift == null
            ? null
            : _rewardProduct(kelopak.productOf(outcome.gift!.productCode)),
      );
    } finally {
      _setBusy(false);
    }
  }

  void _setBusy(bool value) {
    if (_busy == value) return;
    _busy = value;
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
  void playCue(checkin.GameCue cue) => playCueNamed(cue.name);

  @override
  void setSoundOn(bool value) {
    _cached = null;
    setHostSound(value);
  }

  @override
  void dispose() {
    unlink();
    super.dispose();
  }
}
