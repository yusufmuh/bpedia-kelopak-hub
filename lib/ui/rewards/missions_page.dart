import 'package:flutter/material.dart';
import 'package:misi_belanja/misi_belanja.dart' show MissionLadder, VoucherCard;

import '../../core/assets.dart';
import '../../core/format.dart';
import '../../core/tokens.dart';
import '../../domain/app_state.dart';
import '../shell.dart';
import '../shop/shop_navigation.dart' show openCartFromRewards;
import '../widgets/widgets.dart';
import 'rewards_sheets.dart';
import 'rewards_widgets.dart';

/// Misi Belanja: the stage ladder, the next step ("Belanja sekarang") and the
/// vouchers it issued.
class MissionsPage extends StatelessWidget {
  const MissionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final vouchers = app.vouchers;
    final stage = app.activeMissionStage;
    const title = 'Misi Belanja';
    return BgmScope(
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: pageToolbarHeight(context, title),
          title: const PageTitle(title),
          actions: demoAppBarActions(context),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: rewardsPagePadding,
            children: <Widget>[
              RewardsContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const DemoBodyChip(),
                    const _MissionIntro(),
                    const SizedBox(height: BpSpace.s6),
                    const SectionHeader('Tahapan misi'),
                    const SizedBox(height: BpSpace.s3),
                    MissionLadder(
                      stages: app.missionStages,
                      issuedCount: app.missionIssuedCount,
                      pendingNote: _pendingNote(app),
                    ),
                    const SizedBox(height: BpSpace.s6),
                    FilledButton(
                      onPressed: () => _goShopping(context),
                      child: const Text('Belanja sekarang'),
                    ),
                    const SizedBox(height: BpSpace.s8),
                    const SectionHeader('Voucher saya'),
                    const SizedBox(height: BpSpace.s3),
                    if (vouchers.isEmpty)
                      SoftCard(
                        child: EmptyState(
                          imageAsset: AppImages.giftBox3d,
                          title: 'Belum ada voucher',
                          body: stage == null
                              ? 'Voucher dari misi akan tampil di sini.'
                              : 'Selesaikan Tahap ${stage.number} untuk dapat '
                                    'voucher ${rupiah(stage.voucherAmount)}.',
                        ),
                      )
                    else
                      for (final voucher in vouchers)
                        Padding(
                          padding: const EdgeInsets.only(bottom: BpSpace.s3),
                          child: VoucherCard(
                            voucher: voucher,
                            today: app.today,
                            onUse: () => openCartFromRewards(context),
                          ),
                        ),
                    const SizedBox(height: BpSpace.s3),
                    Center(
                      child: TextButton.icon(
                        onPressed: () => showMissionTermsSheet(context),
                        icon: const Icon(Icons.description_outlined),
                        label: const Text('Syarat & ketentuan'),
                      ),
                    ),
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

class _MissionIntro extends StatelessWidget {
  const _MissionIntro();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heading = Semantics(
      header: true,
      child: Text(
        'Selesaikan misi, dapat voucher untuk belanja berikutnya',
        style: theme.textTheme.titleLarge,
      ),
    );
    final lead = Text(
      'Pesanan dihitung setelah kamu tekan Pesanan Diterima di Transaksi.',
      style: theme.textTheme.bodyMedium!.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    if (isLargeText(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          heading,
          const SizedBox(height: BpSpace.s2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(child: lead),
              const SizedBox(width: BpSpace.s3),
              const _IntroBipy(height: 88),
            ],
          ),
        ],
      );
    }
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              heading,
              const SizedBox(height: BpSpace.s2),
              lead,
            ],
          ),
        ),
        const SizedBox(width: BpSpace.s3),
        const _IntroBipy(height: 112),
      ],
    );
  }
}

class _IntroBipy extends StatelessWidget {
  const _IntroBipy({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppImages.bipyTasHati,
      height: height,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      errorBuilder: (context, error, stackTrace) => SizedBox(height: height),
    );
  }
}

/// Shipped orders that qualify for the active stage once received. Only the
/// first one received completes it, so with several the note says so.
String? _pendingNote(AppState app) {
  final waiting = app.ordersAwaitingMission;
  final stage = app.activeMissionStage;
  if (waiting.isEmpty || stage == null) return null;
  final summary = waiting.length == 1
      ? '1 pesanan ${rupiah(waiting.first.subtotal)} menunggu diterima.'
      : '${waiting.length} pesanan memenuhi syarat menunggu diterima. Yang '
            'lebih dulu diterima menyelesaikan Tahap ${stage.number}.';
  return '$summary Tekan Pesanan Diterima di Transaksi setelah paket sampai.';
}

/// Back to the shell, on Beranda.
void _goShopping(BuildContext context) {
  final shell = ShellScope.maybeOf(context);
  if (shell != null) {
    shell.switchTab(ShellTab.home);
    return;
  }
  Navigator.of(context).popUntil((route) => route.isFirst);
}
