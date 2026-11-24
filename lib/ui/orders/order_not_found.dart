import 'package:flutter/material.dart';

import '../../core/assets.dart';
import '../shell.dart';
import '../widgets/widgets.dart';

/// Shown when a route points at an order that no longer exists (for example
/// after "Reset semua data"). Leads back to Transaksi.
class OrderNotFoundPage extends StatelessWidget {
  const OrderNotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pesanan')),
      body: Center(
        child: SingleChildScrollView(
          child: EmptyState(
            imageAsset: AppImages.bipyNgintip,
            title: 'Pesanan tidak ditemukan',
            body: 'Pesanan ini sudah tidak ada di perangkat ini.',
            actionLabel: 'Ke Transaksi',
            onAction: () => ShellScope.of(context).switchTab(ShellTab.orders),
          ),
        ),
      ),
    );
  }
}
