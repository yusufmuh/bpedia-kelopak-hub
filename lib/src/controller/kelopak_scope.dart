/// Menyediakan [KelopakController] ke pohon widget.
library;

import 'package:flutter/widgets.dart';

import 'kelopak_controller.dart';

/// Pembungkus zona Hadiah dan widget tanam: semua halaman hub membaca
/// controller dari sini.
class KelopakScope extends InheritedNotifier<KelopakController> {
  const KelopakScope({
    super.key,
    required KelopakController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Controller, dan membangun ulang pemanggil setiap ada perubahan.
  static KelopakController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<KelopakScope>();
    if (scope == null) throw _missingScope();
    return scope.notifier!;
  }

  /// Controller tanpa berlangganan (untuk callback dan `initState`).
  static KelopakController read(BuildContext context) {
    final controller = maybeRead(context);
    if (controller == null) throw _missingScope();
    return controller;
  }

  /// Seperti [read], tetapi null bila tidak ada [KelopakScope] di atasnya.
  static KelopakController? maybeRead(BuildContext context) {
    final widget = context
        .getElementForInheritedWidgetOfExactType<KelopakScope>()
        ?.widget;
    return widget is KelopakScope ? widget.notifier : null;
  }

  static FlutterError _missingScope() => FlutterError(
    'KelopakScope tidak ditemukan. Bungkus aplikasi dengan '
    'KelopakScope(controller: controller, child: ...).',
  );
}
