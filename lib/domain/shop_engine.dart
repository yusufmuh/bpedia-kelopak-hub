/// Demo shop engine (pure Dart, no Flutter imports): cart, checkout quote,
/// orders and order completion. Vouchers and Kelopak go through
/// [RewardsEngine]; prices come from the demo catalog.
library;

import 'package:daily_checkin/daily_checkin.dart' show wibDateOf;
import 'package:misi_belanja/misi_belanja.dart'
    show MissionDecision, MissionVoucher, RedeemProblem;

import '../data/catalog.dart';
import 'json_reader.dart';
import 'ledger.dart';
import 'rewards_engine.dart';

/// Highest quantity of one product in the cart.
const int cartMaxQty = 99;

/// One product line in the cart.
final class CartLine {
  const CartLine({required this.productId, required this.qty});

  /// Restores a line written by [toJson]; qty must be 1..99.
  factory CartLine.fromJson(Object? source) {
    final json = asJsonMap(source, 'cart line');
    final qty = readInt(json, 'qty');
    if (qty < 1 || qty > cartMaxQty) {
      throw const FormatException('Cart quantity out of range');
    }
    return CartLine(productId: readString(json, 'productId'), qty: qty);
  }

  /// Catalog product id.
  final String productId;

  /// Quantity, 1..99.
  final int qty;

  /// Serializes the line.
  Map<String, Object?> toJson() => <String, Object?>{
    'productId': productId,
    'qty': qty,
  };

  @override
  bool operator ==(Object other) =>
      other is CartLine && other.productId == productId && other.qty == qty;

  @override
  int get hashCode => Object.hash(productId, qty);
}

/// A cart line resolved against the catalog.
final class CartItem {
  const CartItem({required this.product, required this.qty});

  /// Catalog product.
  final Product product;

  /// Quantity, 1..99.
  final int qty;

  /// `price * qty`.
  int get lineTotal => product.price * qty;
}

/// A removed cart line and its former position, for undo.
final class RemovedCartLine {
  const RemovedCartLine({required this.line, required this.index});

  /// The removed line.
  final CartLine line;

  /// Index the line had in the cart.
  final int index;
}

/// Order status shown in "Transaksi".
enum OrderStatus {
  /// On its way; the buyer can confirm with "Pesanan Diterima".
  shipped('Dikirim'),

  /// Received; counted by Misi Belanja.
  completed('Selesai');

  const OrderStatus(this.label);

  /// Indonesian status text.
  final String label;
}

/// Snapshot of one product line at the moment the order was placed.
final class OrderLine {
  const OrderLine({
    required this.productId,
    required this.name,
    required this.price,
    required this.qty,
    required this.imageAsset,
  });

  /// Restores a line written by [toJson].
  factory OrderLine.fromJson(Object? source) {
    final json = asJsonMap(source, 'order line');
    final line = OrderLine(
      productId: readString(json, 'productId'),
      name: readString(json, 'name'),
      price: readInt(json, 'price'),
      qty: readInt(json, 'qty'),
      imageAsset: readString(json, 'imageAsset'),
    );
    if (line.price < 0 || line.qty < 1) {
      throw const FormatException('Invalid order line');
    }
    return line;
  }

  /// Catalog product id.
  final String productId;

  /// Product name at order time.
  final String name;

  /// Unit price at order time.
  final int price;

  /// Quantity.
  final int qty;

  /// Packshot asset path.
  final String imageAsset;

  /// `price * qty`.
  int get lineTotal => price * qty;

  /// Serializes the line.
  Map<String, Object?> toJson() => <String, Object?>{
    'productId': productId,
    'name': name,
    'price': price,
    'qty': qty,
    'imageAsset': imageAsset,
  };
}

/// A placed demo order. Amounts are rupiah.
final class Order {
  const Order({
    required this.id,
    required this.lines,
    required this.subtotal,
    required this.voucherDiscount,
    required this.kelopakUsed,
    required this.total,
    required this.status,
    required this.placedDay,
    this.voucherId,
    this.completedDay,
  });

  /// Restores an order written by [toJson].
  factory Order.fromJson(Object? source) {
    final json = asJsonMap(source, 'order');
    final order = Order(
      id: readString(json, 'id'),
      lines: List<OrderLine>.unmodifiable(
        readList(json, 'lines', OrderLine.fromJson),
      ),
      subtotal: readInt(json, 'subtotal'),
      voucherId: readOptionalString(json, 'voucherId'),
      voucherDiscount: readInt(json, 'voucherDiscount', fallback: 0),
      kelopakUsed: readInt(json, 'kelopakUsed', fallback: 0),
      total: readInt(json, 'total'),
      status: readEnum(json, 'status', OrderStatus.values),
      placedDay: readInt(json, 'placedDay'),
      completedDay: readOptionalInt(json, 'completedDay'),
    );
    final amounts = <int>[
      order.subtotal,
      order.voucherDiscount,
      order.kelopakUsed,
      order.total,
    ];
    if (order.lines.isEmpty || amounts.any((value) => value < 0)) {
      throw const FormatException('Invalid order');
    }
    return order;
  }

  /// Order number `BP-YYYYMMDD-NNNN` (WIB date + running number).
  final String id;

  /// Product lines at order time.
  final List<OrderLine> lines;

  /// Sum of line totals (the amount Misi Belanja counts).
  final int subtotal;

  /// Applied mission voucher, if any.
  final String? voucherId;

  /// Rupiah discount from the voucher.
  final int voucherDiscount;

  /// Kelopak spent on this order.
  final int kelopakUsed;

  /// Amount paid: subtotal - voucher - Kelopak.
  final int total;

  /// Current status.
  final OrderStatus status;

  /// WIB day the order was placed.
  final int placedDay;

  /// WIB day the buyer confirmed receipt.
  final int? completedDay;

  /// Rupiah discount from Kelopak (`kelopakUsed * Rp100`).
  int get kelopakDiscount => kelopakUsed * rupiahPerKelopak;

  /// Total number of items.
  int get itemCount {
    var count = 0;
    for (final line in lines) {
      count += line.qty;
    }
    return count;
  }

  /// Copy marked as received on [day].
  Order completedOn(int day) => Order(
    id: id,
    lines: lines,
    subtotal: subtotal,
    voucherId: voucherId,
    voucherDiscount: voucherDiscount,
    kelopakUsed: kelopakUsed,
    total: total,
    status: OrderStatus.completed,
    placedDay: placedDay,
    completedDay: day,
  );

  /// Serializes the order.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'lines': lines.map((line) => line.toJson()).toList(),
    'subtotal': subtotal,
    'voucherId': voucherId,
    'voucherDiscount': voucherDiscount,
    'kelopakUsed': kelopakUsed,
    'total': total,
    'status': status.name,
    'placedDay': placedDay,
    'completedDay': completedDay,
  };
}

/// Immutable cart and order history.
final class ShopState {
  ShopState({
    List<CartLine> cart = const <CartLine>[],
    List<Order> orders = const <Order>[],
    this.orderSeq = 0,
  }) : cart = List<CartLine>.unmodifiable(cart),
       orders = List<Order>.unmodifiable(orders);

  /// Restores a state written by [toJson].
  factory ShopState.fromJson(Object? source) {
    final json = asJsonMap(source, 'shop');
    final state = ShopState(
      cart: readList(json, 'cart', CartLine.fromJson),
      orders: readList(json, 'orders', Order.fromJson),
      orderSeq: readInt(json, 'orderSeq', fallback: 0),
    );
    if (state.orderSeq < 0) {
      throw const FormatException('Negative order sequence');
    }
    return state;
  }

  /// Cart lines in the order they were added.
  final List<CartLine> cart;

  /// Orders, newest first.
  final List<Order> orders;

  /// Last used order number.
  final int orderSeq;

  /// Returns a copy with the given fields replaced.
  ShopState copyWith({
    List<CartLine>? cart,
    List<Order>? orders,
    int? orderSeq,
  }) {
    return ShopState(
      cart: cart ?? this.cart,
      orders: orders ?? this.orders,
      orderSeq: orderSeq ?? this.orderSeq,
    );
  }

  /// Serializes the state.
  Map<String, Object?> toJson() => <String, Object?>{
    'cart': cart.map((line) => line.toJson()).toList(),
    'orders': orders.map((order) => order.toJson()).toList(),
    'orderSeq': orderSeq,
  };
}

/// Price breakdown for the current cart. Recompute it whenever the cart,
/// voucher choice or Kelopak switch changes; [ShopEngine.placeOrder] only
/// accepts a quote that still matches the current state.
final class CheckoutQuote {
  const CheckoutQuote({
    required this.day,
    required this.orderId,
    required this.subtotal,
    required this.voucherId,
    required this.voucherDiscount,
    required this.voucherProblem,
    required this.useKelopak,
    required this.maxKelopak,
    required this.kelopakUsed,
    required this.total,
  });

  /// WIB day the quote was made for.
  final int day;

  /// Number the order will get when placed now.
  final String orderId;

  /// Sum of cart line totals.
  final int subtotal;

  /// Requested voucher (null when none was chosen or the id is unknown).
  final String? voucherId;

  /// Rupiah discount from the voucher (0 when it has a problem).
  final int voucherDiscount;

  /// Why the requested voucher cannot be used, or null.
  final RedeemProblem? voucherProblem;

  /// Whether the "Pakai Kelopak" switch is on.
  final bool useKelopak;

  /// Kelopak that could be used on this cart (max. 50% of the payable amount).
  final int maxKelopak;

  /// Kelopak actually used (0 when [useKelopak] is off).
  final int kelopakUsed;

  /// Amount to pay.
  final int total;

  /// Whether the requested voucher is applied.
  bool get voucherApplied => voucherId != null && voucherProblem == null;

  /// Rupiah discount from Kelopak.
  int get kelopakDiscount => kelopakUsed * rupiahPerKelopak;

  /// Subtotal minus the voucher discount.
  int get payableAfterVoucher => subtotal - voucherDiscount;

  @override
  bool operator ==(Object other) =>
      other is CheckoutQuote &&
      other.day == day &&
      other.orderId == orderId &&
      other.subtotal == subtotal &&
      other.voucherId == voucherId &&
      other.voucherDiscount == voucherDiscount &&
      other.voucherProblem == voucherProblem &&
      other.useKelopak == useKelopak &&
      other.maxKelopak == maxKelopak &&
      other.kelopakUsed == kelopakUsed &&
      other.total == total;

  @override
  int get hashCode => Object.hash(
    day,
    orderId,
    subtotal,
    voucherId,
    voucherDiscount,
    voucherProblem,
    useKelopak,
    maxKelopak,
    kelopakUsed,
    total,
  );
}

/// Why an order could not be placed.
enum PlaceOrderProblem {
  /// The cart is empty.
  emptyCart,

  /// The cart, vouchers, balance or date changed since the quote was made.
  quoteOutdated,
}

/// Result of confirming receipt of an order.
final class OrderCompletion {
  const OrderCompletion({
    required this.order,
    required this.decision,
    this.voucher,
  });

  /// The order, now [OrderStatus.completed].
  final Order order;

  /// Misi Belanja decision for this order.
  final MissionDecision decision;

  /// Voucher issued by this order, if any.
  final MissionVoucher? voucher;
}

/// Mutable façade over [ShopState]; every operation replaces [state].
final class ShopEngine {
  ShopEngine(ShopState state, {required RewardsEngine rewards})
    : _rewards = rewards,
      _state = _sanitize(state);

  final RewardsEngine _rewards;
  ShopState _state;

  /// Current immutable snapshot (persist this).
  ShopState get state => _state;

  // --------------------------------------------------------------------- cart

  /// Cart lines in the order they were added.
  List<CartLine> get cart => _state.cart;

  /// Cart lines resolved to products.
  List<CartItem> get cartItems => <CartItem>[
    for (final line in _state.cart)
      CartItem(product: productById(line.productId)!, qty: line.qty),
  ];

  /// Whether the cart has no lines.
  bool get isCartEmpty => _state.cart.isEmpty;

  /// Total number of items in the cart.
  int get cartCount {
    var count = 0;
    for (final line in _state.cart) {
      count += line.qty;
    }
    return count;
  }

  /// Sum of cart line totals in rupiah.
  int get cartSubtotal {
    var total = 0;
    for (final item in cartItems) {
      total += item.lineTotal;
    }
    return total;
  }

  /// Quantity of [productId] in the cart (0 when absent).
  int quantityOf(String productId) {
    for (final line in _state.cart) {
      if (line.productId == productId) return line.qty;
    }
    return 0;
  }

  /// Adds [qty] of [productId] (capped at 99) and returns the new quantity.
  ///
  /// Throws [ArgumentError] for an unknown product or a qty below 1.
  int add(String productId, {int qty = 1}) {
    if (productById(productId) == null) {
      throw ArgumentError.value(productId, 'productId', 'not in the catalog');
    }
    if (qty < 1) throw ArgumentError.value(qty, 'qty', 'must be at least 1');
    final lines = <CartLine>[..._state.cart];
    final index = lines.indexWhere((line) => line.productId == productId);
    final current = index < 0 ? 0 : lines[index].qty;
    final updated = CartLine(
      productId: productId,
      qty: _clampQty(current + qty),
    );
    if (index < 0) {
      lines.add(updated);
    } else {
      lines[index] = updated;
    }
    _state = _state.copyWith(cart: lines);
    return updated.qty;
  }

  /// Sets the quantity of [productId]: below 1 removes the line, above 99 is capped.
  void setQty(String productId, int qty) {
    if (qty < 1) {
      remove(productId);
      return;
    }
    final index = _state.cart.indexWhere((line) => line.productId == productId);
    if (index < 0) {
      add(productId, qty: qty);
      return;
    }
    final lines = <CartLine>[..._state.cart];
    lines[index] = CartLine(productId: productId, qty: _clampQty(qty));
    _state = _state.copyWith(cart: lines);
  }

  /// Removes [productId]; returns what was removed (for undo) or null.
  RemovedCartLine? remove(String productId) {
    final index = _state.cart.indexWhere((line) => line.productId == productId);
    if (index < 0) return null;
    final lines = <CartLine>[..._state.cart];
    final line = lines.removeAt(index);
    _state = _state.copyWith(cart: lines);
    return RemovedCartLine(line: line, index: index);
  }

  /// Puts a removed line back at its old position (merges if re-added meanwhile).
  void restore(RemovedCartLine removed) {
    final productId = removed.line.productId;
    if (productById(productId) == null) return;
    if (quantityOf(productId) > 0) {
      add(productId, qty: removed.line.qty);
      return;
    }
    final lines = <CartLine>[..._state.cart];
    final index = removed.index.clamp(0, lines.length);
    lines.insert(index, removed.line);
    _state = _state.copyWith(cart: lines);
  }

  /// Empties the cart.
  void clearCart() {
    _state = _state.copyWith(cart: const <CartLine>[]);
  }

  // ----------------------------------------------------------------- checkout

  /// Number the next order placed on [today] will get.
  String nextOrderId(int today) => orderIdFor(today, _state.orderSeq + 1);

  /// Order number for [wibDay] and running number [seq]: `BP-YYYYMMDD-NNNN`.
  static String orderIdFor(int wibDay, int seq) {
    final date = wibDateOf(wibDay);
    final yyyy = date.year.toString().padLeft(4, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return 'BP-$yyyy$mm$dd-${seq.toString().padLeft(4, '0')}';
  }

  /// Price breakdown for the current cart.
  ///
  /// The voucher is checked with the module rule against [nextOrderId];
  /// Kelopak covers at most 50% of the amount left after the voucher.
  CheckoutQuote quote({
    String? voucherId,
    bool useKelopak = false,
    required int today,
  }) {
    final subtotal = cartSubtotal;
    final orderId = nextOrderId(today);
    MissionVoucher? voucher;
    if (voucherId != null) voucher = _rewards.voucherById(voucherId);
    RedeemProblem? problem;
    var voucherDiscount = 0;
    if (voucher != null) {
      problem = _rewards.voucherProblem(
        voucherId: voucher.id,
        orderId: orderId,
        subtotal: subtotal,
        today: today,
      );
      if (problem == null) {
        voucherDiscount = voucher.amount < subtotal ? voucher.amount : subtotal;
      }
    }
    final payable = subtotal - voucherDiscount;
    final maxKelopak = _rewards.maxKelopakFor(payable);
    final kelopakUsed = useKelopak ? maxKelopak : 0;
    return CheckoutQuote(
      day: today,
      orderId: orderId,
      subtotal: subtotal,
      voucherId: voucher?.id,
      voucherDiscount: voucherDiscount,
      voucherProblem: problem,
      useKelopak: useKelopak,
      maxKelopak: maxKelopak,
      kelopakUsed: kelopakUsed,
      total: payable - kelopakUsed * rupiahPerKelopak,
    );
  }

  /// Why [quote] cannot be placed on [today], or null when it can.
  PlaceOrderProblem? problemWith(CheckoutQuote quote, {required int today}) {
    if (_state.cart.isEmpty) return PlaceOrderProblem.emptyCart;
    if (quote.day != today) return PlaceOrderProblem.quoteOutdated;
    final fresh = this.quote(
      voucherId: quote.voucherId,
      useKelopak: quote.useKelopak,
      today: today,
    );
    return fresh == quote ? null : PlaceOrderProblem.quoteOutdated;
  }

  /// Places [quote] as a [OrderStatus.shipped] order: marks the voucher used,
  /// books the Kelopak debit and clears the cart.
  ///
  /// Throws [StateError] when [problemWith] reports a problem.
  Order placeOrder(CheckoutQuote quote) {
    final problem = problemWith(quote, today: quote.day);
    if (problem != null) {
      throw StateError('Cannot place order: ${problem.name}');
    }
    final seq = _state.orderSeq + 1;
    final id = orderIdFor(quote.day, seq);
    final lines = List<OrderLine>.unmodifiable(<OrderLine>[
      for (final item in cartItems)
        OrderLine(
          productId: item.product.id,
          name: item.product.name,
          price: item.product.price,
          qty: item.qty,
          imageAsset: item.product.imageAsset,
        ),
    ]);
    final voucherId = quote.voucherApplied ? quote.voucherId : null;
    if (voucherId != null) _rewards.markVoucherUsed(voucherId, id);
    if (quote.kelopakUsed > 0) {
      _rewards.spendKelopak(quote.kelopakUsed, id, quote.day);
    }
    final order = Order(
      id: id,
      lines: lines,
      subtotal: quote.subtotal,
      voucherId: voucherId,
      voucherDiscount: quote.voucherDiscount,
      kelopakUsed: quote.kelopakUsed,
      total: quote.total,
      status: OrderStatus.shipped,
      placedDay: quote.day,
    );
    _state = ShopState(orders: <Order>[order, ..._state.orders], orderSeq: seq);
    return order;
  }

  // ------------------------------------------------------------------- orders

  /// Orders, newest first.
  List<Order> get orders => _state.orders;

  /// Order with [orderId], or null.
  Order? orderById(String orderId) {
    for (final order in _state.orders) {
      if (order.id == orderId) return order;
    }
    return null;
  }

  /// Confirms receipt of a shipped order on [today] and runs Misi Belanja with
  /// `eligibleSubtotal = order.subtotal`.
  ///
  /// Returns null when no shipped order has [orderId] (unknown or already completed).
  OrderCompletion? markReceived(String orderId, int today) {
    final index = _state.orders.indexWhere((order) => order.id == orderId);
    if (index < 0) return null;
    final order = _state.orders[index];
    if (order.status != OrderStatus.shipped) return null;
    final completed = order.completedOn(today);
    final orders = <Order>[..._state.orders];
    orders[index] = completed;
    _state = _state.copyWith(orders: orders);
    final decision = _rewards.completeOrder(
      orderId: orderId,
      eligibleSubtotal: completed.subtotal,
      today: today,
    );
    return OrderCompletion(
      order: completed,
      decision: decision,
      voucher: decision.issued ? _rewards.voucherFromOrder(orderId) : null,
    );
  }

  // ------------------------------------------------------------------ helpers

  static int _clampQty(int qty) => qty > cartMaxQty ? cartMaxQty : qty;

  /// Drops lines whose product left the catalog and merges duplicates.
  static ShopState _sanitize(ShopState state) {
    final merged = <String, int>{};
    for (final line in state.cart) {
      if (productById(line.productId) == null) continue;
      merged[line.productId] = _clampQty(
        (merged[line.productId] ?? 0) + line.qty,
      );
    }
    final lines = <CartLine>[
      for (final entry in merged.entries)
        CartLine(productId: entry.key, qty: entry.value),
    ];
    var unchanged = lines.length == state.cart.length;
    for (var i = 0; unchanged && i < lines.length; i++) {
      unchanged = lines[i] == state.cart[i];
    }
    return unchanged ? state : state.copyWith(cart: lines);
  }
}
