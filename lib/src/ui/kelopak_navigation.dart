/// Cara halaman hub membuka jalur `/hadiah/*`.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

/// Membuka [location] (mis. `/hadiah/roda`) dari [context].
typedef KelopakPathOpener =
    void Function(BuildContext context, String location);

/// Menentukan bagaimana halaman hub berpindah ke jalur lain. Host yang punya
/// router sendiri (tab, tumpukan) membungkus pohonnya dengan widget ini;
/// tanpa itu halaman memakai `Navigator.pushNamed`.
class KelopakNavigation extends InheritedWidget {
  /// Memasang [open] untuk subpohon [child].
  const KelopakNavigation({
    super.key,
    required this.open,
    required super.child,
  });

  /// Pembuka jalur milik host.
  final KelopakPathOpener open;

  /// Membuka [location] lewat pembuka host terdekat, atau
  /// `Navigator.pushNamed` bila tidak ada.
  static void openPath(BuildContext context, String location) {
    final scope = context
        .getElementForInheritedWidgetOfExactType<KelopakNavigation>()
        ?.widget;
    if (scope is KelopakNavigation) {
      scope.open(context, location);
      return;
    }
    unawaited(Navigator.of(context).pushNamed<void>(location));
  }

  @override
  bool updateShouldNotify(KelopakNavigation oldWidget) =>
      oldWidget.open != open;
}
