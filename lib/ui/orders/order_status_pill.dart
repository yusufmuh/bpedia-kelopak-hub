import 'package:flutter/material.dart';

import '../../domain/shop_engine.dart';
import '../widgets/widgets.dart';

/// Order status as icon + text: "Dikirim" (truck, info) or "Selesai" (check, success).
class OrderStatusPill extends StatelessWidget {
  const OrderStatusPill(this.status, {super.key});

  /// Status to show.
  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      OrderStatus.shipped => StatusPill(
        Icons.local_shipping_outlined,
        status.label,
        tone: StatusTone.info,
      ),
      OrderStatus.completed => StatusPill(
        Icons.check_circle_rounded,
        status.label,
        tone: StatusTone.success,
      ),
    };
  }
}
