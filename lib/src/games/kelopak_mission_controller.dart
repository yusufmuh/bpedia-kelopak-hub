/// `MissionController` modul `misi_belanja` di atas [KelopakController].
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:misi_belanja/misi_belanja.dart' as misi;

import '../controller/kelopak_controller.dart';
import '../controller/kelopak_event.dart';
import '../core/paths.dart';
import '../domain/checkout.dart';
import '../domain/voucher.dart';
import '../host/kelopak_host.dart';
import '../ui/hub_art.dart';
import 'game_link.dart';

/// Misi Belanja sungguhan: tahap, voucher, dan pesanan berjalan dari mesin
/// Kelopak; produk misi dan isi keranjang dari `KelopakHost`.
class KelopakMissionController extends misi.MissionController
    with KelopakGameLink {
  /// Membuat controller di atas [kelopak]. [onOpenPath] membuka jalur hub
  /// (mis. halaman voucher).
  KelopakMissionController(
    KelopakController kelopak, {
    ValueChanged<String>? onOpenPath,
  }) {
    linkTo(kelopak, onOpenPath: onOpenPath);
    _events = kelopak.events.listen(_onEvent);
  }

  late final StreamSubscription<KelopakEvent> _events;
  misi.MissionCelebration? _celebration;
  (String, misi.MissionCelebration)? _waitingCelebration;
  bool _visible = true;
  bool _busy = false;
  misi.MissionViewState? _cached;

  void _onEvent(KelopakEvent event) {
    if (event is! MissionCompletedEvent) return;
    final stages = kelopak.missionStages;
    final index = event.stageNumber - 1;
    if (index < 0 || index >= stages.length) return;
    _waitingCelebration = (
      event.voucher.id,
      misi.MissionCelebration(
        stage: stages[index],
        voucher: event.voucher.asMissionVoucher,
        nextStage: index + 1 < stages.length ? stages[index + 1] : null,
      ),
    );
    _takeCelebration();
    _cached = null;
  }

  /// Halaman misi sedang tampil paling atas (diatur `KelopakMissionScreen`).
  /// Saat tersembunyi, perayaan ditahan; bila lembar "Misi tuntas" lain
  /// sudah tampil lebih dulu, perayaan halaman ini dibuang.
  bool get visible => _visible;

  set visible(bool value) {
    if (_visible == value) return;
    _visible = value;
    _cached = null;
  }

  void _takeCelebration() {
    final waiting = _waitingCelebration;
    if (waiting == null || !_visible) return;
    _waitingCelebration = null;
    if (kelopak.claimMissionCelebration(waiting.$1)) {
      _celebration = waiting.$2;
    }
  }

  @override
  void onKelopakChanged() => _cached = null;

  @override
  misi.MissionViewState get state => _cached ??= _build();

  misi.MissionViewState _build() {
    _takeCelebration();
    final products = <misi.MissionProduct>[
      for (final product in kelopak.missionProducts) _missionProduct(product),
    ];
    final cartLines = <misi.MissionOrderLine>[
      for (final line in host?.cartLines ?? const <CheckoutLine>[])
        line.asMissionLine,
    ];
    if (!kelopak.isLoggedIn) {
      return misi.MissionViewState.guest(
        stages: kelopak.missionStages,
        today: kelopak.today,
        products: products,
        cartLines: cartLines,
        soundOn: hostSoundOn,
      );
    }
    return misi.MissionViewState(
      signedIn: true,
      stages: kelopak.missionStages,
      issuedCount: kelopak.missionIssuedCount,
      today: kelopak.today,
      products: products,
      cartLines: cartLines,
      vouchers: <misi.MissionVoucher>[
        for (final voucher in kelopak.vouchers)
          if (voucher.kind == VoucherKind.mission) voucher.asMissionVoucher,
      ],
      pendingOrder: _pendingOrder(),
      celebration: _celebration,
      soundOn: hostSoundOn,
      busy: _busy,
    );
  }

  misi.MissionPendingOrder? _pendingOrder() {
    final stage = kelopak.activeMissionStage;
    final waiting = kelopak.view.ordersAwaitingMission;
    if (stage == null || waiting.isEmpty) return null;
    final order = waiting.first;
    return misi.MissionPendingOrder(
      orderId: order.id,
      missionSubtotal: misi.missionSubtotal(
        stage,
        order.lines.map((line) => line.asMissionLine),
      ),
      statusLabel: order.status == KelopakOrderStatus.shipped
          ? 'Sedang dikirim'
          : 'Sedang diproses',
    );
  }

  static misi.MissionProduct _missionProduct(KelopakProduct product) =>
      misi.MissionProduct(
        code: product.code,
        name: product.name,
        image: product.image ?? HubArt.bag,
        price: product.price,
        strikePrice: product.strikePrice,
      );

  @override
  Future<void> refresh() async {
    kelopak.refreshDay();
    await kelopak.syncFromStore();
    _cached = null;
    notifyListeners();
  }

  /// Tamu boleh mengisi keranjang (KEPUTUSAN-V3 §5); progres dan voucher
  /// misi tetap menunggu masuk, dan halaman misi menampilkan ajakannya.
  @override
  Future<bool> addToCart(String code) async {
    final current = host;
    if (current == null) return false;
    _setBusy(true);
    try {
      return await current.addToCart(code);
    } finally {
      _setBusy(false);
    }
  }

  @override
  Future<void> setQuantity(String code, int quantity) async {
    final current = host;
    if (current == null) return;
    final actions = gameActions;
    if (actions != null) {
      await actions.setCartQuantity(code, quantity);
      return;
    }
    final have = state.quantityOf(code);
    if (quantity > have) {
      await current.addToCart(code, quantity: quantity - have);
    } else if (quantity < have) {
      current.openCart();
    }
  }

  void _setBusy(bool value) {
    if (_busy == value) return;
    _busy = value;
    _cached = null;
    notifyListeners();
  }

  @override
  void acknowledgeCelebration() {
    if (_celebration == null) return;
    _celebration = null;
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
  void openCheckout() {
    final actions = gameActions;
    if (actions != null) {
      actions.openCheckout();
    } else {
      host?.openCart();
    }
  }

  @override
  void openProduct(String code) => host?.openProduct(code);

  @override
  void openOrder(String orderId) {
    final actions = gameActions;
    if (actions != null) {
      actions.openOrder(orderId);
    } else {
      host?.openCart();
    }
  }

  @override
  void openVouchers() => openHubPath(KelopakPaths.vouchers);

  @override
  void useVoucher(String voucherId) => openCheckout();

  @override
  void setSoundOn(bool on) {
    _cached = null;
    setHostSound(on);
  }

  @override
  void playCue(misi.GameCue cue) => playCueNamed(cue.name);

  @override
  void dispose() {
    unawaited(_events.cancel());
    unlink();
    super.dispose();
  }
}
