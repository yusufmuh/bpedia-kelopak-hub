/// Voucherku (`/hadiah/voucher`): semua voucher, yang bisa dipakai, voucher
/// event yang akan datang, riwayat, cara dapat voucher, dan ketentuannya.
library;

import 'package:flutter/material.dart';

import '../controller/kelopak_controller.dart';
import '../controller/kelopak_scope.dart';
import '../core/format.dart';
import '../core/paths.dart';
import '../domain/campaign.dart';
import '../domain/voucher.dart';
import '../kit/kit.dart';
import 'hub_actions.dart';
import 'hub_art.dart';
import 'hub_widgets.dart';
import 'kelopak_navigation.dart';
import 'rewards_hub_page.dart' show MiniProgressBar;

/// Tab Voucherku.
enum VoucherTab {
  /// Bisa dipakai dan akan datang.
  all,

  /// Hanya yang bisa dipakai.
  usable,

  /// Voucher event yang belum dibuka.
  upcoming,

  /// Sudah dipakai atau berakhir.
  history,
}

/// Halaman voucher. Membaca `KelopakScope` terdekat.
class VouchersPage extends StatelessWidget {
  /// Membuat halaman; [showHistory] membuka tab riwayat lebih dulu,
  /// [initialTab] memilih tab lain.
  const VouchersPage({
    super.key,
    this.showHistory = false,
    this.initialTab = VoucherTab.all,
  });

  /// Buka tab "Riwayat" lebih dulu (mengalahkan [initialTab]).
  final bool showHistory;

  /// Tab awal.
  final VoucherTab initialTab;

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
    final upcoming = c.upcomingVouchers;
    final history = <KelopakVoucher>[
      for (final voucher in c.vouchers)
        if (!c.isVoucherActive(voucher)) voucher,
    ];
    final tab = showHistory ? VoucherTab.history : initialTab;
    return DefaultTabController(
      length: VoucherTab.values.length,
      initialIndex: tab.index,
      child: Scaffold(
        backgroundColor: tones.canvas,
        appBar: AppBar(
          title: const Text('Voucherku'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: <Widget>[
              Tab(text: 'Semua (${usable.length + upcoming.length})'),
              Tab(text: 'Bisa dipakai (${usable.length})'),
              Tab(text: 'Akan datang (${upcoming.length})'),
              Tab(text: 'Riwayat (${history.length})'),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            _VoucherList(
              controller: c,
              usable: usable,
              upcoming: upcoming,
              grouped: true,
            ),
            _VoucherList(controller: c, usable: usable),
            _VoucherList(controller: c, upcoming: upcoming),
            _HistoryList(controller: c, vouchers: history),
          ],
        ),
      ),
    );
  }
}

class _VoucherList extends StatelessWidget {
  const _VoucherList({
    required this.controller,
    this.usable = const <KelopakVoucher>[],
    this.upcoming = const <KelopakVoucherTeaser>[],
    this.grouped = false,
  });

  final KelopakController controller;
  final List<KelopakVoucher> usable;
  final List<KelopakVoucherTeaser> upcoming;
  final bool grouped;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final empty = usable.isEmpty && upcoming.isEmpty;
    Widget ticket(KelopakVoucher voucher) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: VoucherTicket(
        voucher: voucher,
        state: VoucherTicketState.usable,
        today: c.today,
        onUse: () => useVoucherFromHub(c),
      ),
    );
    Widget teaser(KelopakVoucherTeaser teaser) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: VoucherTeaserTicket(teaser: teaser),
    );
    return ListView(
      padding: const EdgeInsets.only(top: 12, bottom: 32),
      children: <Widget>[
        if (empty)
          HubEmptyState(
            image: HubArt.ticket,
            title: grouped ? 'Belum ada voucher' : 'Belum ada voucher aktif',
            message: 'Selesaikan Misi Belanja untuk dapat voucher belanja.',
            actionLabel: 'Lihat Misi Belanja',
            onAction: () =>
                KelopakNavigation.openPath(context, KelopakPaths.mission),
          )
        else ...<Widget>[
          if (usable.isNotEmpty) ...<Widget>[
            const _GroupLabel(
              label: 'Bisa dipakai',
              hint: 'Dipilih otomatis di checkout',
            ),
            for (final voucher in usable) ticket(voucher),
          ],
          if (upcoming.isNotEmpty) ...<Widget>[
            if (usable.isNotEmpty) const SizedBox(height: 6),
            const _GroupLabel(
              label: 'Akan datang',
              hint: 'Klaim pada tanggal event',
            ),
            for (final item in upcoming) teaser(item),
          ],
        ],
        const SizedBox(height: 6),
        _HowToGet(controller: c),
        const _Terms(),
      ],
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.controller, required this.vouchers});

  final KelopakController controller;
  final List<KelopakVoucher> vouchers;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 12, bottom: 32),
      children: <Widget>[
        if (vouchers.isEmpty)
          HubEmptyState(
            image: HubArt.bipyHost,
            title: 'Belum ada riwayat voucher',
            message: 'Voucher yang sudah dipakai atau berakhir tampil di sini.',
            actionLabel: 'Lihat Misi Belanja',
            onAction: () =>
                KelopakNavigation.openPath(context, KelopakPaths.mission),
          )
        else
          for (final voucher in vouchers)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: VoucherTicket(
                voucher: voucher,
                today: controller.today,
                state: voucher.isUsed
                    ? VoucherTicketState.used
                    : VoucherTicketState.expired,
              ),
            ),
      ],
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.label, required this.hint});

  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final tones = HubTones.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: tones.brand,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(4),
                right: Radius.circular(10),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              child: Semantics(
                header: true,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    height: 16 / 12,
                    fontWeight: FontWeight.w700,
                    color: tones.scheme.onPrimary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: tones.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _HowToGet extends StatelessWidget {
  const _HowToGet({required this.controller});

  final KelopakController controller;

  @override
  Widget build(BuildContext context) {
    final tones = HubTones.of(context);
    final c = controller;
    final stage = c.activeMissionStage;
    final progress = c.cartMissionProgress;
    final String body;
    if (stage == null) {
      body =
          'Semua tahap Misi Belanja sudah selesai. Pantau event promo '
          'berikutnya.';
    } else if (progress == null || progress.current == 0) {
      body =
          'Belanja produk misi ${rupiah(stage.minOrderSubtotal)}, dapat '
          'voucher ${rupiah(stage.voucherAmount)}';
    } else if (progress.reached) {
      body =
          'Target tercapai. Checkout untuk dapat voucher '
          '${rupiah(stage.voucherAmount)}';
    } else {
      body =
          '${rupiah(progress.remaining)} lagi dapat voucher '
          '${rupiah(stage.voucherAmount)}';
    }
    void open() => KelopakNavigation.openPath(context, KelopakPaths.mission);
    return ColoredBox(
      color: tones.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                'Cara dapat voucher',
                style: TextStyle(
                  fontSize: 18,
                  height: 24 / 18,
                  fontWeight: FontWeight.w700,
                  color: tones.text,
                ),
              ),
            ),
            Text(
              'Tuntaskan misi dan ikuti event promo',
              style: TextStyle(fontSize: 13, color: tones.textMuted),
            ),
            const SizedBox(height: 12),
            Pressable(
              onTap: open,
              semanticLabel:
                  '${stage == null ? 'Misi Belanja' : 'Misi Belanja tahap ${stage.number}'}. $body',
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: tones.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: tones.line),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 72,
                        height: 72,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: tones.goldTint,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Image(image: HubArt.bag),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              stage == null
                                  ? 'Misi Belanja'
                                  : 'Misi Belanja tahap ${stage.number}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                height: 22 / 16,
                                fontWeight: FontWeight.w700,
                                color: tones.text,
                              ),
                            ),
                            const SizedBox(height: 6),
                            MiniProgressBar(
                              value: stage == null
                                  ? 1
                                  : progress?.fraction ?? 0,
                              height: 4,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              body,
                              style: TextStyle(
                                fontSize: 13,
                                height: 17 / 13,
                                color: tones.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      CandyButton(
                        label: 'Lihat',
                        expand: false,
                        height: 40,
                        shine: false,
                        variant: CandyVariant.tonal,
                        semanticLabel: 'Lihat Misi Belanja',
                        onPressed: open,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Terms extends StatelessWidget {
  const _Terms();

  static const List<String> _items = <String>[
    'Satu voucher per pesanan.',
    'Syarat minimal belanja dihitung dari harga barang sebelum potongan '
        'Kelopak.',
    'Pesanan dibatalkan sebelum selesai, voucher kembali ke Voucherku '
        'selama masa berlaku.',
  ];

  @override
  Widget build(BuildContext context) {
    final tones = HubTones.of(context);
    final style = TextStyle(fontSize: 13, height: 19 / 13, color: tones.text);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ColoredBox(
        color: tones.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  'Ketentuan voucher',
                  style: TextStyle(
                    fontSize: 18,
                    height: 24 / 18,
                    fontWeight: FontWeight.w700,
                    color: tones.text,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              for (final item in _items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('•  ', style: style),
                      Expanded(child: Text(item, style: style)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
