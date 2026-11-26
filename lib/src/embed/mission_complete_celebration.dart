/// Perayaan "Misi tuntas" saat pesanan misi diterima di luar halaman misi
/// (biasanya dari detail pesanan host).
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../controller/kelopak_controller.dart';
import '../controller/kelopak_event.dart';
import '../controller/kelopak_scope.dart';
import '../core/format.dart';
import '../core/paths.dart';
import '../domain/voucher.dart';
import '../kit/kit.dart';
import '../ui/hub_art.dart';
import '../ui/hub_widgets.dart' show wibShortDate;
import '../ui/kelopak_navigation.dart';

/// Membuka lembar hasil "Misi tuntas" untuk [voucher] yang baru terbit.
/// [onViewVouchers] mengganti aksi bawaan (membuka `/hadiah/voucher`).
///
/// Tiap voucher dirayakan sekali: bila halaman Misi Belanja yang sedang
/// tampil sudah merayakannya (`KelopakController.claimMissionCelebration`),
/// lembar ini tidak dibuka lagi.
Future<void> showMissionCompleteCelebration(
  BuildContext context, {
  required KelopakVoucher voucher,
  int? stageNumber,
  VoidCallback? onViewVouchers,
}) {
  final controller = KelopakScope.maybeRead(context);
  if (controller != null && !controller.claimMissionCelebration(voucher.id)) {
    return Future<void>.value();
  }
  final stage = stageNumber ?? voucher.stageNumber ?? 1;
  return showResultSheet<void>(
    context,
    builder: (sheet) => ResultSheet(
      ribbon: 'Misi tuntas!',
      title: 'Tahap $stage Misi Belanja selesai',
      pill: 'Voucher belanja',
      art: const SizedBox(
        width: 150,
        height: 110,
        child: Image(image: HubArt.ticket, fit: BoxFit.contain),
      ),
      companion: const SizedBox(
        width: 70,
        height: 110,
        child: Bobbing(
          amplitude: 4,
          child: Image(image: HubArt.bipyCheer, fit: BoxFit.contain),
        ),
      ),
      amount: voucher.amount,
      amountPrefix: 'Rp',
      caption:
          'Min. belanja ${rupiah(voucher.minSpend)} · berlaku s.d. '
          '${wibShortDate(voucher.expiresDay)}',
      message:
          'Voucher sudah masuk ke Voucherku. Pakai di pesanan berikutnya, Babes.',
      primaryLabel: 'Lihat voucher',
      onPrimary: () {
        Navigator.of(sheet).pop();
        if (onViewVouchers != null) {
          onViewVouchers();
        } else {
          KelopakNavigation.openPath(context, KelopakPaths.vouchers);
        }
      },
      secondaryLabel: 'Nanti saja',
      onSecondary: () => Navigator.of(sheet).pop(),
    ),
  );
}

/// Mendengarkan `MissionCompletedEvent` dari `KelopakScope` terdekat dan
/// menampilkan [showMissionCompleteCelebration]. Pasang di bawah navigator
/// host (atau beri [navigatorKey]). Bila halaman Misi Belanja sedang tampil
/// paling atas, perayaan halaman itu yang muncul dan lembar ini diam.
class MissionCompleteCelebration extends StatefulWidget {
  /// Membungkus [child].
  const MissionCompleteCelebration({
    super.key,
    required this.child,
    this.navigatorKey,
    this.enabled = true,
  });

  /// Isi aplikasi.
  final Widget child;

  /// Navigator tempat lembar dibuka; null memakai konteks widget ini.
  final GlobalKey<NavigatorState>? navigatorKey;

  /// False menahan perayaan.
  final bool enabled;

  @override
  State<MissionCompleteCelebration> createState() =>
      _MissionCompleteCelebrationState();
}

class _MissionCompleteCelebrationState
    extends State<MissionCompleteCelebration> {
  KelopakController? _controller;
  StreamSubscription<KelopakEvent>? _events;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = KelopakScope.maybeRead(context);
    if (identical(controller, _controller)) return;
    unawaited(_events?.cancel());
    _controller = controller;
    _events = controller?.events.listen(_onEvent);
  }

  void _onEvent(KelopakEvent event) {
    if (event is! MissionCompletedEvent || !widget.enabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = widget.navigatorKey?.currentContext ?? context;
      unawaited(
        showMissionCompleteCelebration(
          target,
          voucher: event.voucher,
          stageNumber: event.stageNumber,
        ),
      );
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
