/// Routes of the shopping flow, the way into the reward games, and the
/// shared "add to cart" action.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/catalog.dart';
import '../../domain/app_state.dart';
import '../../domain/shop_engine.dart';
import '../orders/order_detail_page.dart';
import '../rewards/checkin_page.dart';
import '../rewards/missions_page.dart';
import '../rewards/wheel_page.dart';
import '../shell.dart';
import 'cart_page.dart';
import 'checkout_page.dart';
import 'product_page.dart';
import 'search_page.dart';
import 'shop_layout.dart';

/// Standard page route of the app.
Route<void> pageRoute(Widget page) =>
    MaterialPageRoute<void>(builder: (context) => page);

void _push(BuildContext context, Route<void> route) {
  unawaited(Navigator.of(context).push<void>(route));
}

/// Opens the detail of [productId].
void openProduct(BuildContext context, String productId) =>
    _push(context, pageRoute(ProductPage(productId: productId)));

/// Opens search, optionally with a query or a category already chosen.
void openSearch(
  BuildContext context, {
  String? initialQuery,
  ProductCategory? category,
}) => _push(
  context,
  pageRoute(SearchPage(initialQuery: initialQuery, category: category)),
);

/// Opens the cart.
void openCart(BuildContext context) =>
    _push(context, pageRoute(const CartPage()));

/// Opens checkout for the current cart.
void openCheckout(BuildContext context) =>
    _push(context, pageRoute(const CheckoutPage()));

/// Opens the detail of order [orderId] on top of the current page.
void openOrder(BuildContext context, String orderId) =>
    _push(context, pageRoute(OrderDetailPage(orderId: orderId)));

/// Opens Check-in Harian (the game pages hold the background music themselves).
void openCheckIn(BuildContext context) =>
    _push(context, pageRoute(const CheckInPage()));

/// Opens Roda Sabtu.
void openWheel(BuildContext context) =>
    _push(context, pageRoute(const WheelPage()));

/// Opens Misi Belanja.
void openMissions(BuildContext context) =>
    _push(context, pageRoute(const MissionsPage()));

/// Closes every pushed page, selects Transaksi and opens order [orderId].
void showOrderInTransactions(BuildContext context, String orderId) {
  final shell = ShellScope.of(context);
  shell.switchTab(ShellTab.orders);
  unawaited(
    shell.navigatorKey.currentState?.push<void>(
      pageRoute(OrderDetailPage(orderId: orderId)),
    ),
  );
}

/// Adds [qty] of [product] to the cart with a light click and a snack bar
/// whose "Lihat" action opens the cart. Says so when the 99 limit capped it.
void addToCartWithFeedback(
  BuildContext context,
  Product product, {
  int qty = 1,
}) {
  final app = AppScope.read(context);
  final navigator = Navigator.of(context);
  final before = app.quantityInCart(product.id);
  final after = app.addToCart(product.id, qty: qty);
  app.haptics.selection();
  final added = after - before;
  final String message;
  if (added <= 0) {
    message = 'Sudah $cartMaxQty di keranjang, jumlah maksimal per produk';
  } else if (added < qty) {
    message = 'Ditambahkan $added. Maksimal $cartMaxQty per produk';
  } else {
    message = 'Ditambahkan ke keranjang';
  }
  showShopSnackBar(
    context,
    message,
    actionLabel: 'Lihat',
    onAction: () =>
        unawaited(navigator.push<void>(pageRoute(const CartPage()))),
  );
}
