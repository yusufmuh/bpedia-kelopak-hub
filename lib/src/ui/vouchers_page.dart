/// Voucherku (`/hadiah/voucher`): voucher yang bisa dipakai dan riwayatnya.
library;

import 'package:flutter/material.dart';

import '../controller/kelopak_controller.dart';
import '../controller/kelopak_scope.dart';
import '../core/format.dart';
import '../core/paths.dart';
import '../domain/voucher.dart';
import 'hub_actions.dart';
import 'hub_art.dart';
import 'hub_widgets.dart';
import 'kelopak_navigation.dart';

/// Halaman voucher. Membaca `KelopakScope` terdekat.
class VouchersPage extends StatelessWidget {
  /// Membuat halaman; [showHistory] membuka tab riwayat lebih dulu.
  const VouchersPage({super.key, this.showHistory = false});

  /// Buka tab "Riwayat" lebih dulu.
  final bool showHistory;

  @override
  Widget build(BuildContext context) {
    final c = KelopakScope.of(context);
    final tones = HubTones.of(context);
    if (!c.isLoggedIn) {
      return Scaffold(
        backgroundColor: tones.surface,
        appBar: AppBar(title: const Text('Voucherku')),
        body: Center(
          child: SingleChildScrollView(
            child: HubEmptyState(
              image: HubArt.ticket,
              title: 'Masuk dulu, Babes',
              message:
                  'Voucher dari Misi Belanja dan promo tersimpan di akunmu.',
              actionLabel: 'Masuk',
              onAction: c.ensureLoggedIn,
            ),
          ),
        ),
      );
    }
    final usable = c.activeVouchers;
    final history = <KelopakVoucher>[
      for (final voucher in c.vouchers)
        if (!c.isVoucherActive(voucher)) voucher,
    ];
    return DefaultTabController(
      length: 2,
      initialIndex: showHistory ? 1 : 0,
      child: Scaffold(
        backgroundColor: tones.canvas,
        appBar: AppBar(
          title: const Text('Voucherku'),
          bottom: TabBar(
            tabs: <Widget>[
              Tab(text: 'Bisa dipakai (${usable.length})'),
              Tab(text: 'Riwayat (${history.length})'),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            _VoucherList(vouchers: usable, controller: c, usableTab: true),
            _VoucherList(vouchers: history, controller: c, usableTab: false),
          ],
        ),
      ),
    );
  }
}

class _VoucherList extends StatelessWidget {
  const _VoucherList({
    required this.vouchers,
    required this.controller,
    required this.usableTab,
  });

  final List<KelopakVoucher> vouchers;
  final KelopakController controller;
  final bool usableTab;

  @override
  Widget build(BuildContext context) {
    final tones = HubTones.of(context);
    final c = controller;
    final stage = c.activeMissionStage;
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: <Widget>[
        if (usableTab)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: tones.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Voucher dipilih di halaman checkout. Satu pesanan, satu voucher.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 16 / 12,
                      color: tones.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (vouchers.isEmpty)
          ColoredBox(
            color: tones.canvas,
            child: HubEmptyState(
              image: usableTab ? HubArt.ticket : HubArt.bipyHost,
              title: usableTab
                  ? 'Belum ada voucher aktif'
                  : 'Belum ada riwayat voucher',
              message: usableTab
                  ? 'Selesaikan Misi Belanja untuk dapat voucher belanja.'
                  : 'Voucher yang sudah dipakai atau berakhir tampil di sini.',
              actionLabel: usableTab ? 'Lihat Misi Belanja' : null,
              onAction: usableTab
                  ? () => KelopakNavigation.openPath(
                      context,
                      KelopakPaths.mission,
                    )
                  : null,
            ),
          )
        else
          for (final voucher in vouchers)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: VoucherTicket(
                voucher: voucher,
                state: usableTab
                    ? VoucherTicketState.usable
                    : voucher.isUsed
                    ? VoucherTicketState.used
                    : VoucherTicketState.expired,
                onUse: usableTab ? () => useVoucherFromHub(c) : null,
              ),
            ),
        if (usableTab && stage != null && vouchers.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _MoreVouchersCard(
              title: 'Mau voucher lagi?',
              body:
                  '${stage.title} Misi Belanja: belanja produk misi '
                  '${rupiah(stage.minOrderSubtotal)}, dapat voucher '
                  '${rupiah(stage.voucherAmount)}.',
            ),
          ),
      ],
    );
  }
}

class _MoreVouchersCard extends StatelessWidget {
  const _MoreVouchersCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final tones = HubTones.of(context);
    return Material(
      color: tones.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => KelopakNavigation.openPath(context, KelopakPaths.mission),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              const Image(image: HubArt.bag, width: 48, height: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: tones.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: TextStyle(
                        fontSize: 12,
                        height: 16 / 12,
                        color: tones.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: tones.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}
