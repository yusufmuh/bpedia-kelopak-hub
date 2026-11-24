/// App-wide state for the UI: one [ChangeNotifier] that owns the clock, sound,
/// haptics, rewards engine, shop engine and settings, exposed via [AppScope].
///
/// Every mutation notifies listeners and saves the app document in the
/// background (saves never throw to the UI). Operations return result objects
/// instead of throwing for expected situations.
///
/// Saves are revisioned: before writing, the saved document is read again and
/// when another instance (a second browser tab) saved a newer revision, that
/// document is adopted instead of being overwritten.
library;

import 'dart:async';
import 'dart:math';

import 'package:daily_checkin/daily_checkin.dart'
    show dayInMonthCycle, filledInWeek;
import 'package:flutter/material.dart';
import 'package:misi_belanja/misi_belanja.dart'
    show
        MissionStage,
        MissionVoucher,
        RedeemProblem,
        StageStatus,
        redeemProblem,
        stageStatus;
import 'package:roda_sabtu/roda_sabtu.dart'
    show
        SpinConfig,
        SpinEligibility,
        SpinOdds,
        SpinPrize,
        daysUntilSaturday,
        isSaturdayWib;

import '../core/browser.dart';
import '../core/clock.dart';
import '../core/feedback.dart';
import '../core/sound.dart';
import '../data/key_value_store.dart';
import '../data/persistence.dart';
import 'app_settings.dart';
import 'ledger.dart';
import 'rewards_engine.dart';
import 'shop_engine.dart';
import 'spin_opening.dart';

export 'spin_opening.dart' show SpinOpening;

/// Result of [AppState.placeOrder].
sealed class PlaceOrderResult {
  const PlaceOrderResult();
}

/// The order was created (status [OrderStatus.shipped]) and the cart cleared.
final class OrderPlaced extends PlaceOrderResult {
  const OrderPlaced(this.order);

  /// The new order.
  final Order order;
}

/// Nothing changed; re-quote and show the new numbers ([problem] says why).
final class OrderNotPlaced extends PlaceOrderResult {
  const OrderNotPlaced(this.problem);

  /// Why the order was not placed.
  final PlaceOrderProblem problem;
}

/// The app state. Create it with [AppState.load] and provide it with [AppScope].
class AppState extends ChangeNotifier {
  AppState._({
    required KeyValueStore store,
    required this.clock,
    required this.sound,
    required this.haptics,
    required RewardsEngine rewards,
    required AppSettings settings,
    required ShopState shopState,
    required Random random,
    required bool watchDayChange,
    required int revision,
    required bool watchOtherTabs,
  }) : _store = store,
       _rewards = rewards,
       _shop = ShopEngine(shopState, rewards: rewards),
       _settings = settings,
       _random = random,
       _watchDayChange = watchDayChange,
       _revision = revision {
    _lastSeenDay = clock.today;
    _scheduleDayTimer();
    if (watchOtherTabs) {
      _stopWatchingStore = watchBrowserStorageKey(
        appStateStorageKey,
        () => unawaited(syncFromStore()),
      );
    }
  }

  /// Loads the saved document (or a fresh state) and builds the app state.
  ///
  /// * [store]: defaults to shared_preferences; if reading fails the session
  ///   falls back to memory so the unreadable data is never overwritten.
  /// * [now]: injectable clock for tests.
  /// * [sound]: defaults to real audio; pass [SoundService.silent] in tests.
  /// * [random]: defaults to `Random.secure()` (spin roll and landing seed).
  /// * [watchDayChange]: schedules a rebuild at 00.00 WIB; pass false in
  ///   widget tests so no timer stays pending.
  /// * [watchOtherTabs]: on the web, adopts what another tab of the same
  ///   origin saves ([syncFromStore]) as soon as the browser reports it.
  static Future<AppState> load({
    KeyValueStore? store,
    DateTime Function()? now,
    SoundService? sound,
    Random? random,
    bool watchDayChange = true,
    bool watchOtherTabs = true,
  }) async {
    var resolvedStore = store ?? _platformStore();
    AppSnapshot snapshot;
    try {
      snapshot = await AppSnapshot.load(resolvedStore);
    } catch (_) {
      resolvedStore = MemoryKeyValueStore();
      snapshot = AppSnapshot.fresh();
    }
    final settings = snapshot.settings;
    final soundService = sound ?? SoundService();
    soundService
      ..sfxEnabled = settings.sfxEnabled
      ..musicEnabled = settings.musicEnabled;
    final state = AppState._(
      store: resolvedStore,
      clock: AppClock(now: now, demoOffsetDays: snapshot.clockOffsetDays),
      sound: soundService,
      haptics: Haptics(enabled: settings.hapticsEnabled),
      rewards: RewardsEngine(snapshot.rewards),
      settings: settings,
      shopState: snapshot.shop,
      random: random ?? _secureRandom(),
      watchDayChange: watchDayChange,
      revision: snapshot.revision,
      watchOtherTabs: watchOtherTabs,
    );
    unawaited(soundService.init());
    return state;
  }

  /// Largest single step of [advanceDays].
  static const int maxDemoAdvanceDays = 30;

  final KeyValueStore _store;
  final Random _random;
  final bool _watchDayChange;
  RewardsEngine _rewards;
  ShopEngine _shop;
  AppSettings _settings;
  Future<void> _saving = Future<void>.value();
  bool _saveQueued = false;
  Object? _lastSaveError;
  Timer? _dayTimer;
  late int _lastSeenDay;
  bool _disposed = false;
  int _revision;
  int _adoptedUpdates = 0;
  void Function()? _stopWatchingStore;

  // ----------------------------------------------------------------- services

  /// WIB clock with the Mode Demo offset.
  final AppClock clock;

  /// Sound effects and music (already synced with [settings]).
  final SoundService sound;

  /// Vibration (already synced with [settings]).
  final Haptics haptics;

  /// Rewards engine (read-only use; mutate through [AppState] methods).
  RewardsEngine get rewards => _rewards;

  /// Shop engine (read-only use; mutate through [AppState] methods).
  ShopEngine get shop => _shop;

  /// Plays the sound and vibration of [event] (honors the settings).
  void feedback(FeedbackEvent event) {
    sound.play(event.sfx);
    haptics.perform(event.haptic);
  }

  // --------------------------------------------------------------------- time

  /// Current WIB day (days since 1970-01-01 WIB, demo offset included).
  int get today => clock.today;

  /// Mode Demo day offset.
  int get demoOffsetDays => clock.demoOffsetDays;

  /// Whether today is a Saturday (WIB).
  bool get isSaturday => isSaturdayWib(today);

  /// First Saturday after today (next week's when today is Saturday).
  int get nextSaturday => clock.nextSaturday();

  /// Real time left until 00.00 WIB.
  Duration untilNextDay() => clock.untilNextWibMidnight();

  /// Rebuilds listeners when the WIB day changed (call on app resume).
  ///
  /// Also re-arms the 00.00 WIB timer from the wall clock: timers run on a
  /// monotonic clock that stops while the device sleeps, so a deadline armed
  /// before a sleep would fire late.
  void refreshDay() {
    if (_disposed) return;
    _scheduleDayTimer();
    final current = today;
    if (current == _lastSeenDay) return;
    _lastSeenDay = current;
    notifyListeners();
  }

  // ------------------------------------------------------------------ Kelopak

  /// Kelopak balance.
  int get balance => _rewards.balance;

  /// Ledger, oldest first.
  List<LedgerEntry> get ledger => _rewards.ledger;

  /// Ledger with running balance, newest first ("Riwayat Kelopak").
  List<LedgerLine> get ledgerHistory => buildLedgerHistory(_rewards.ledger);

  // ---------------------------------------------------------- Check-in Harian

  /// Streak still alive today (0 when broken or never started).
  int get liveStreak => _rewards.liveStreak(today);

  /// Whether today's check-in is done.
  bool get claimedToday => _rewards.claimedToday(today);

  /// Whether the check-in button is available.
  bool get canCheckIn => !claimedToday;

  /// A streak existed but a day was missed (show the gentle reset note).
  bool get streakBroken => _rewards.streakBroken(today);

  /// Streak day the next claim will be ("Hari ke-4"), today's or tomorrow's.
  int get nextCheckInStreakDay => liveStreak + 1;

  /// WIB day on which the next check-in opens: today while it is open,
  /// otherwise the day after the last claim. That is tomorrow, or later when
  /// the last claim is dated after today (the device clock was moved back).
  int get nextCheckInDay {
    final last = _rewards.lastClaimDay;
    return last != null && last >= today ? last + 1 : today;
  }

  /// Filled slots of the 7-day track (module `filledInWeek`).
  int get checkInWeekFilled =>
      filledInWeek(liveStreak: liveStreak, claimedToday: claimedToday);

  /// Progress 0..30 toward the free product (module `dayInMonthCycle`).
  int get checkInMonthDay =>
      dayInMonthCycle(liveStreak: liveStreak, claimedToday: claimedToday);

  /// Claims today's check-in. Notifies and saves only when something was booked.
  CheckInOutcome claimCheckIn() {
    final outcome = _rewards.claimCheckIn(today);
    if (outcome is CheckInClaimed) _changed();
    return outcome;
  }

  // --------------------------------------------------------------- Roda Sabtu

  /// Campaign configuration (prizes, version, shipping note).
  SpinConfig get spinConfig => _rewards.spinConfig;

  /// Whether a spin is possible today, and if not, why.
  SpinEligibility get spinEligibility => _rewards.spinEligibility(today);

  /// Whether the "Putar gratis" button is enabled.
  bool get canSpin => spinEligibility == SpinEligibility.available;

  /// Odds for the current stock (show before the spin button).
  List<SpinOdds> get spinOdds => _rewards.currentOdds();

  /// Remaining product prizes.
  int get productStock => _rewards.productStock;

  /// Whether the promo runs.
  bool get promoActive => _rewards.promoActive;

  /// Today's spin, if any (keep showing its result after a restart).
  SpinRecord? get todaySpin => _rewards.spinOn(today);

  /// Most recent spin.
  SpinRecord? get lastSpin => _rewards.lastSpin;

  /// Prize of [record], or null when the campaign no longer has it.
  SpinPrize? prizeFor(SpinRecord record) => _rewards.prizeById(record.prizeId);

  /// Wheel segments for [record]: the odds at spin time, not today's stock.
  List<SpinOdds> oddsForSpin(SpinRecord record) => _rewards.oddsFor(record);

  /// Product stock [record] was spun with (the stock behind [oddsForSpin]).
  int stockForSpin(SpinRecord record) => _rewards.stockFor(record);

  /// First Saturday after today on which a spin is still possible: normally
  /// [nextSaturday]; later when the last spin is dated today or after (a spin
  /// today, or the device clock was moved back after a spin).
  int get nextSpinSaturday {
    final last = lastSpin?.wibDay;
    final from = last != null && last >= today ? last : today;
    final days = daysUntilSaturday(from);
    return from + (days == 0 ? 7 : days);
  }

  /// Opening of Roda Sabtu on [saturday], a WIB day after today.
  SpinOpening spinOpeningOn(int saturday) {
    final daysLeft = saturday - today;
    return SpinOpening(
      day: saturday,
      daysLeft: daysLeft,
      timeLeft: daysLeft <= 0
          ? Duration.zero
          : untilNextDay() + Duration(days: daysLeft - 1),
    );
  }

  /// The next Roda Sabtu opening ([nextSpinSaturday], 00.00 WIB). Every
  /// screen that tells when the wheel opens uses this, so they agree.
  SpinOpening get nextSpinOpening => spinOpeningOn(nextSpinSaturday);

  /// Spins once with a secure random roll (0..9999) and landing seed.
  ///
  /// The result is final before any animation; feed `record.prizeId` and
  /// `record.landingSeed` to the wheel.
  SpinOutcome spin() {
    final outcome = _rewards.spin(
      today: today,
      roll: _random.nextInt(10000),
      landingSeed: _random.nextInt(1 << 31),
    );
    if (outcome is SpinCompleted) _changed();
    return outcome;
  }

  // ------------------------------------------------------------ Misi Belanja

  /// Mission stages in order.
  List<MissionStage> get missionStages => _rewards.missionStages;

  /// Vouchers issued so far (= completed stages).
  int get missionIssuedCount => _rewards.missionIssuedCount;

  /// Stage the next qualifying order completes, or null when all are done.
  MissionStage? get activeMissionStage => _rewards.activeStage;

  /// Whether every stage is done ("Tahap berikutnya menunggu kampanye").
  bool get allMissionStagesDone => _rewards.allMissionStagesDone;

  /// Status of the stage at [stageIndex] (module rule).
  StageStatus missionStageStatus(int stageIndex) =>
      stageStatus(stageIndex: stageIndex, issuedCount: missionIssuedCount);

  /// Rupiah still missing for [subtotal] to qualify for the active stage (0 when enough or none).
  int missionShortfallFor(int subtotal) {
    final stage = activeMissionStage;
    if (stage == null) return 0;
    final missing = stage.minOrderSubtotal - subtotal;
    return missing > 0 ? missing : 0;
  }

  /// Shipped orders that qualify for the active stage once received. Only
  /// the first of them to be received completes it (one order, one stage).
  List<Order> get ordersAwaitingMission {
    final stage = activeMissionStage;
    if (stage == null) return const <Order>[];
    return _shop.orders
        .where(
          (order) =>
              order.status == OrderStatus.shipped &&
              order.subtotal >= stage.minOrderSubtotal,
        )
        .toList(growable: false);
  }

  /// Whether [order] is the only shipped order that qualifies for the active
  /// stage, so receiving it certainly issues that stage's voucher.
  bool isOnlyOrderAwaitingMission(Order order) {
    final waiting = ordersAwaitingMission;
    return waiting.length == 1 && waiting.single.id == order.id;
  }

  // ----------------------------------------------------- vouchers & products

  /// All mission vouchers, newest first.
  List<MissionVoucher> get vouchers =>
      _rewards.vouchers.reversed.toList(growable: false);

  /// Vouchers that are neither used nor expired, newest first.
  List<MissionVoucher> get activeVouchers =>
      vouchers.where(isVoucherActive).toList(growable: false);

  /// Whether [voucher] is unused and not expired today (module rule).
  bool isVoucherActive(MissionVoucher voucher) {
    final problem = redeemProblem(
      voucher: voucher,
      orderId: _shop.nextOrderId(today),
      subtotal: voucher.minSpend,
      today: today,
    );
    return problem != RedeemProblem.expired &&
        problem != RedeemProblem.alreadyUsed;
  }

  /// Why [voucherId] cannot be used on the current cart, or null when it can.
  RedeemProblem? voucherProblemForCart(String voucherId) =>
      _rewards.voucherProblem(
        voucherId: voucherId,
        orderId: _shop.nextOrderId(today),
        subtotal: cartSubtotal,
        today: today,
      );

  /// Rupiah the cart still needs for [voucherId]'s minimum spend ("Belanja Rp8.000 lagi").
  int voucherShortfallForCart(String voucherId) {
    final voucher = _rewards.voucherById(voucherId);
    if (voucher == null) return 0;
    final missing = voucher.minSpend - cartSubtotal;
    return missing > 0 ? missing : 0;
  }

  /// Free-product rights, newest first.
  List<ProductEntitlement> get entitlements =>
      _rewards.entitlements.reversed.toList(growable: false);

  // --------------------------------------------------------------------- cart

  /// Cart lines with their products, in the order added.
  List<CartItem> get cartItems => _shop.cartItems;

  /// Number of items in the cart (badge).
  int get cartCount => _shop.cartCount;

  /// Sum of cart line totals.
  int get cartSubtotal => _shop.cartSubtotal;

  /// Whether the cart is empty.
  bool get isCartEmpty => _shop.isCartEmpty;

  /// Quantity of [productId] in the cart.
  int quantityInCart(String productId) => _shop.quantityOf(productId);

  /// Adds [qty] (default 1, capped at 99 per product); returns the new quantity.
  int addToCart(String productId, {int qty = 1}) {
    final result = _shop.add(productId, qty: qty);
    _changed();
    return result;
  }

  /// Sets a quantity (below 1 removes the line, above 99 is capped).
  void setQty(String productId, int qty) {
    _shop.setQty(productId, qty);
    _changed();
  }

  /// Removes a line; keep the result to offer "Urungkan" via [undoRemoveFromCart].
  RemovedCartLine? removeFromCart(String productId) {
    final removed = _shop.remove(productId);
    if (removed != null) _changed();
    return removed;
  }

  /// Restores a line removed with [removeFromCart].
  void undoRemoveFromCart(RemovedCartLine removed) {
    _shop.restore(removed);
    _changed();
  }

  /// Empties the cart.
  void clearCart() {
    _shop.clearCart();
    _changed();
  }

  // ----------------------------------------------------------------- checkout

  /// Price breakdown for the current cart (cheap; call it in build).
  CheckoutQuote quote({String? voucherId, bool useKelopak = false}) =>
      _shop.quote(voucherId: voucherId, useKelopak: useKelopak, today: today);

  /// Places [quote] if it still matches the current state.
  PlaceOrderResult placeOrder(CheckoutQuote quote) {
    final problem = _shop.problemWith(quote, today: today);
    if (problem != null) return OrderNotPlaced(problem);
    final order = _shop.placeOrder(quote);
    _changed();
    return OrderPlaced(order);
  }

  // ------------------------------------------------------------------- orders

  /// Orders, newest first.
  List<Order> get orders => _shop.orders;

  /// Orders with [status], newest first; null gives all orders.
  List<Order> ordersWithStatus(OrderStatus? status) => status == null
      ? _shop.orders
      : _shop.orders
            .where((order) => order.status == status)
            .toList(growable: false);

  /// Order with [orderId], or null.
  Order? orderById(String orderId) => _shop.orderById(orderId);

  /// "Pesanan Diterima": completes a shipped order and runs Misi Belanja.
  ///
  /// Returns null when no shipped order has [orderId].
  OrderCompletion? markOrderReceived(String orderId) {
    final completion = _shop.markReceived(orderId, today);
    if (completion != null) _changed();
    return completion;
  }

  // ----------------------------------------------------------------- settings

  /// User preferences.
  AppSettings get settings => _settings;

  /// Sound effects on/off.
  void setSfx(bool enabled) {
    _settings = _settings.copyWith(sfxEnabled: enabled);
    sound.sfxEnabled = enabled;
    _changed();
  }

  /// Background music on/off (plays only on Hadiah and game screens).
  void setMusic(bool enabled) {
    _settings = _settings.copyWith(musicEnabled: enabled);
    sound.musicEnabled = enabled;
    _changed();
  }

  /// Vibration on/off.
  void setHaptics(bool enabled) {
    _settings = _settings.copyWith(hapticsEnabled: enabled);
    haptics.enabled = enabled;
    _changed();
  }

  /// Ikuti sistem / Terang / Gelap.
  void setThemeMode(ThemeMode mode) {
    _settings = _settings.copyWith(themeMode: mode);
    _changed();
  }

  // --------------------------------------------------------- Mode Demo (QA)

  /// Moves the demo calendar forward by [days] (1..30).
  void advanceDays(int days) {
    RangeError.checkValueInInterval(days, 1, maxDemoAdvanceDays, 'days');
    clock.demoOffsetDays += days;
    _lastSeenDay = today;
    _changed();
  }

  /// Moves the demo calendar to the next Saturday.
  void jumpToNextSaturday() {
    clock.demoOffsetDays += nextSaturday - today;
    _lastSeenDay = today;
    _changed();
  }

  /// Turns the Roda Sabtu promo on or off.
  void setPromoActive(bool active) {
    _rewards.setPromoActive(active);
    _changed();
  }

  /// Restores the wheel's product stock.
  void refillProductStock() {
    _rewards.refillProductStock();
    _changed();
  }

  /// Clears rewards, cart, orders and the demo calendar (settings are kept).
  void resetAll() {
    final rewards = RewardsEngine(
      RewardsState(),
      spinConfig: _rewards.spinConfig,
      missionStages: _rewards.missionStages,
    );
    _rewards = rewards;
    _shop = ShopEngine(ShopState(), rewards: rewards);
    clock.demoOffsetDays = 0;
    _lastSeenDay = today;
    _changed();
  }

  // -------------------------------------------------------------- persistence

  /// Error of the last failed save, null after a successful one.
  Object? get lastSaveError => _lastSaveError;

  /// Completes when every pending save has been written.
  Future<void> flush() => _saving;

  /// Revision of the document this state was loaded from or last saved as.
  int get revision => _revision;

  /// How often this state replaced its data with a newer document saved by
  /// another instance (a second browser tab). The shell tells the user each
  /// time it grows.
  int get adoptedUpdates => _adoptedUpdates;

  /// Snapshot of everything that is persisted.
  AppSnapshot snapshot() => AppSnapshot(
    settings: _settings,
    clockOffsetDays: clock.demoOffsetDays,
    rewards: _rewards.state,
    shop: _shop.state,
    revision: _revision,
  );

  /// Re-reads the saved document and adopts it when another instance saved
  /// a newer revision. Runs after pending saves; returns whether it adopted.
  Future<bool> syncFromStore() {
    final adopted = _saving.then((_) => _adoptNewerSaved());
    _saving = adopted.then<void>((_) {});
    return adopted;
  }

  @override
  void dispose() {
    _disposed = true;
    _dayTimer?.cancel();
    _stopWatchingStore?.call();
    unawaited(sound.dispose());
    super.dispose();
  }

  // ------------------------------------------------------------------ helpers

  void _changed() {
    if (_disposed) return;
    notifyListeners();
    _persist();
  }

  /// Queues one save. A save first reads the stored revision: when another
  /// instance saved after this one last read or wrote, its document wins and
  /// is adopted (this state's newer change is dropped, the shell says so);
  /// otherwise this state is written with the next revision.
  void _persist() {
    if (_saveQueued) return;
    _saveQueued = true;
    _saving = _saving.then((_) async {
      _saveQueued = false;
      try {
        final stored = AppSnapshot.decode(
          await _store.read(appStateStorageKey),
        );
        if (stored.revision > _revision) {
          if (!_disposed) _adopt(stored);
          _lastSaveError = null;
          return;
        }
        final next = max(stored.revision, _revision) + 1;
        await snapshot().withRevision(next).save(_store);
        _revision = next;
        _lastSaveError = null;
      } catch (error) {
        _lastSaveError = error;
      }
    });
  }

  Future<bool> _adoptNewerSaved() async {
    if (_disposed) return false;
    final AppSnapshot stored;
    try {
      stored = AppSnapshot.decode(await _store.read(appStateStorageKey));
    } catch (_) {
      // Unreadable right now: keep the current data; the next save retries.
      return false;
    }
    if (_disposed || stored.revision <= _revision) return false;
    _adopt(stored);
    return true;
  }

  /// Replaces every piece of data with [saved] and notifies listeners.
  void _adopt(AppSnapshot saved) {
    final rewards = RewardsEngine(
      saved.rewards,
      spinConfig: _rewards.spinConfig,
      missionStages: _rewards.missionStages,
    );
    _rewards = rewards;
    _shop = ShopEngine(saved.shop, rewards: rewards);
    _settings = saved.settings;
    clock.demoOffsetDays = saved.clockOffsetDays;
    sound
      ..sfxEnabled = _settings.sfxEnabled
      ..musicEnabled = _settings.musicEnabled;
    haptics.enabled = _settings.hapticsEnabled;
    _lastSeenDay = today;
    _revision = saved.revision;
    _adoptedUpdates++;
    notifyListeners();
  }

  void _scheduleDayTimer() {
    _dayTimer?.cancel();
    if (!_watchDayChange || _disposed) return;
    _dayTimer = Timer(
      clock.untilNextWibMidnight() + const Duration(seconds: 1),
      refreshDay,
    );
  }

  static KeyValueStore _platformStore() {
    try {
      return SharedPreferencesKeyValueStore();
    } on StateError {
      return MemoryKeyValueStore();
    }
  }

  static Random _secureRandom() {
    try {
      return Random.secure();
    } on UnsupportedError {
      return Random();
    }
  }
}

/// Provides [AppState] to the widget tree.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState notifier, required super.child})
    : super(notifier: notifier);

  /// The state, rebuilding the caller on every change.
  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    if (scope == null) throw _missingScope();
    return scope.notifier!;
  }

  /// The state without subscribing (use in callbacks and initState).
  static AppState read(BuildContext context) {
    final widget = context
        .getElementForInheritedWidgetOfExactType<AppScope>()
        ?.widget;
    if (widget is! AppScope) throw _missingScope();
    return widget.notifier!;
  }

  static FlutterError _missingScope() => FlutterError(
    'AppScope not found. Wrap the app in AppScope(notifier: state, child: ...).',
  );
}
