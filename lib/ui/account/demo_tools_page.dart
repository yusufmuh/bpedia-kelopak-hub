import 'package:flutter/material.dart';
import 'package:roda_sabtu/roda_sabtu.dart' show SpinEligibility;

import '../../core/format.dart';
import '../../core/tokens.dart';
import '../../domain/app_state.dart';
import '../../domain/rewards_engine.dart' show demoSpinProductStock;
import '../widgets/widgets.dart';
import 'account_widgets.dart';

/// Akun > Mode Demo (QA): move the simulated WIB calendar forward, control
/// the Roda Sabtu promo and its product stock, and reset all demo data.
///
/// Every action confirms what happened in a snack bar.
class DemoToolsPage extends StatelessWidget {
  const DemoToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Mode Demo (QA)')),
      body: AccountListView(
        children: <Widget>[
          const InfoNote(
            'Alat uji untuk mencoba hadiah tanpa menunggu hari berganti. '
            'Semua perubahan hanya berlaku di perangkat ini.',
            icon: Icons.science_outlined,
          ),
          const SizedBox(height: BpSpace.s6),
          const SectionHeader('Tanggal simulasi'),
          const SizedBox(height: BpSpace.s2),
          _CalendarCard(app: app),
          const SizedBox(height: BpSpace.s6),
          const SectionHeader('Roda Sabtu'),
          const SizedBox(height: BpSpace.s2),
          _WheelCard(app: app),
          const SizedBox(height: BpSpace.s6),
          const SectionHeader('Data demo'),
          const SizedBox(height: BpSpace.s2),
          const _ResetCard(),
        ],
      ),
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium!.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final offset = app.demoOffsetDays;
    final saturdayHint = app.isSaturday
        ? 'Hari ini Sabtu, Roda Sabtu buka sampai 23.59 WIB.'
        : 'Sabtu berikutnya ${shortDateLabel(app.nextSaturday)}, '
              '${app.daysUntilNextSaturday} hari lagi.';
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            wibDateLabel(app.today),
            style: theme.textTheme.titleLarge,
            semanticsLabel: 'Tanggal simulasi ${wibDateLabel(app.today)}',
          ),
          const SizedBox(height: BpSpace.s1),
          Text(
            offset == 0
                ? 'Sama dengan tanggal asli (WIB)'
                : 'Maju $offset hari dari tanggal asli (WIB)',
            style: muted,
          ),
          const SizedBox(height: BpSpace.s1),
          Text(saturdayHint, style: muted),
          const SizedBox(height: BpSpace.s4),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _advance(context, 1),
                  child: const Text('+1 hari'),
                ),
              ),
              const SizedBox(width: BpSpace.s3),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _advance(context, 7),
                  child: const Text('+7 hari'),
                ),
              ),
            ],
          ),
          const SizedBox(height: BpSpace.s3),
          OutlinedButton.icon(
            onPressed: () => _jumpToSaturday(context),
            icon: const Icon(Icons.event_available_outlined),
            label: const Text('Lompat ke Sabtu berikutnya'),
          ),
          const SizedBox(height: BpSpace.s4),
          const InfoNote(
            'Kalender demo hanya bisa maju. Untuk kembali ke tanggal asli, '
            'pakai Reset semua data.',
          ),
        ],
      ),
    );
  }

  void _advance(BuildContext context, int days) {
    final state = AppScope.read(context)..advanceDays(days);
    showAccountSnackBar(
      context,
      'Tanggal simulasi maju $days hari: ${wibDateLabel(state.today)}.',
    );
  }

  void _jumpToSaturday(BuildContext context) {
    final state = AppScope.read(context)..jumpToNextSaturday();
    final wheel = switch (state.spinEligibility) {
      SpinEligibility.available => 'Roda Sabtu siap diputar.',
      SpinEligibility.promoInactive => 'Promo Roda Sabtu sedang nonaktif.',
      SpinEligibility.alreadySpun => 'Roda Sabtu ini sudah diputar.',
      SpinEligibility.notSaturday => 'Roda Sabtu belum buka.',
    };
    showAccountSnackBar(
      context,
      'Sekarang ${wibDateLabel(state.today)}. $wheel',
    );
  }
}

class _WheelCard extends StatelessWidget {
  const _WheelCard({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stock = app.productStock;
    final stockFull = stock >= demoSpinProductStock;
    return SettingsGroup(
      children: <Widget>[
        SwitchListTile(
          shape: const RoundedRectangleBorder(),
          secondary: const Icon(Icons.campaign_outlined),
          title: const Text('Promo Roda Sabtu aktif'),
          subtitle: Text(
            app.promoActive
                ? 'Roda bisa diputar setiap Sabtu'
                : 'Roda tidak bisa diputar sampai promo aktif lagi',
          ),
          value: app.promoActive,
          onChanged: (active) {
            AppScope.read(context).setPromoActive(active);
            showAccountSnackBar(
              context,
              active
                  ? 'Promo Roda Sabtu aktif.'
                  : 'Promo Roda Sabtu dinonaktifkan.',
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            BpSpace.s4,
            BpSpace.s3,
            BpSpace.s4,
            BpSpace.s4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Stok produk roda: $stock dari $demoSpinProductStock',
                style: theme.textTheme.bodyLarge!.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: BpSpace.s1),
              Text(
                stockFull
                    ? 'Stok masih penuh, belum perlu diisi ulang.'
                    : 'Stok habis: peluang produk 0% sampai diisi ulang.',
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: BpSpace.s3),
              OutlinedButton.icon(
                onPressed: stockFull ? null : () => _refill(context),
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Isi ulang stok produk roda'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _refill(BuildContext context) {
    final state = AppScope.read(context)..refillProductStock();
    showAccountSnackBar(
      context,
      'Stok produk roda diisi ulang: ${state.productStock} produk.',
    );
  }
}

class _ResetCard extends StatelessWidget {
  const _ResetCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = theme.colorScheme.error;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Hapus saldo Kelopak, riwayat, voucher, hadiah produk, keranjang, '
            'pesanan, dan tanggal simulasi. Pengaturan suara dan tampilan '
            'tetap tersimpan.',
            style: theme.textTheme.bodyMedium!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: BpSpace.s4),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: error,
              side: BorderSide(color: error, width: 1.5),
            ),
            onPressed: () => _confirmReset(context),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Reset semua data'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          scrollable: true,
          icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
          title: const Text('Reset semua data?'),
          content: const Text(
            'Saldo Kelopak, riwayat, voucher, hadiah produk, keranjang, '
            'pesanan, dan tanggal simulasi akan dihapus dari perangkat ini. '
            'Tindakan ini tidak bisa dibatalkan.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Reset data'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;
    AppScope.read(context).resetAll();
    showAccountSnackBar(
      context,
      'Semua data demo dihapus. Kamu mulai lagi dari awal.',
    );
  }
}
