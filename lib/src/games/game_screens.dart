/// Halaman tiga game yang siap dipasang host: membuat controller hub dari
/// `KelopakScope` terdekat dan membuangnya saat halaman ditutup.
library;

import 'dart:async';

import 'package:daily_checkin/daily_checkin.dart' show CheckInPage;
import 'package:flutter/widgets.dart';
import 'package:misi_belanja/misi_belanja.dart' show MissionsPage;
import 'package:roda_sabtu/roda_sabtu.dart' show WheelPage;

import '../controller/kelopak_scope.dart';
import '../ui/how_to_sheet.dart';
import '../ui/kelopak_navigation.dart';
import 'game_actions.dart';
import 'kelopak_check_in_controller.dart';
import 'kelopak_mission_controller.dart';
import 'kelopak_wheel_controller.dart';

/// Halaman Check-in Harian (`/hadiah/checkin`).
class KelopakCheckInScreen extends StatefulWidget {
  /// Membuat halaman. [onBack] mengganti tombol kembali bawaan.
  const KelopakCheckInScreen({super.key, this.onBack});

  /// Pengganti `Navigator.maybePop`.
  final VoidCallback? onBack;

  @override
  State<KelopakCheckInScreen> createState() => _KelopakCheckInScreenState();
}

class _KelopakCheckInScreenState extends State<KelopakCheckInScreen> {
  KelopakCheckInController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= KelopakCheckInController(
      KelopakScope.read(context),
      onOpenTerms: () =>
          unawaited(showKelopakHowTo(context, focus: KelopakGame.checkIn)),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      CheckInPage(controller: _controller!, onBack: widget.onBack);
}

/// Halaman Roda Sabtu (`/hadiah/roda`).
class KelopakWheelScreen extends StatefulWidget {
  /// Membuat halaman. [onBack] mengganti tombol kembali bawaan.
  const KelopakWheelScreen({super.key, this.onBack});

  /// Pengganti `Navigator.maybePop`.
  final VoidCallback? onBack;

  @override
  State<KelopakWheelScreen> createState() => _KelopakWheelScreenState();
}

class _KelopakWheelScreenState extends State<KelopakWheelScreen> {
  KelopakWheelController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= KelopakWheelController(
      KelopakScope.read(context),
      onOpenTerms: () =>
          unawaited(showKelopakHowTo(context, focus: KelopakGame.wheel)),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      WheelPage(controller: _controller!, onBack: widget.onBack);
}

/// Halaman Misi Belanja (`/hadiah/misi`).
class KelopakMissionScreen extends StatefulWidget {
  /// Membuat halaman. [onBack] mengganti tombol kembali bawaan.
  const KelopakMissionScreen({super.key, this.onBack});

  /// Pengganti `Navigator.maybePop`.
  final VoidCallback? onBack;

  @override
  State<KelopakMissionScreen> createState() => _KelopakMissionScreenState();
}

class _KelopakMissionScreenState extends State<KelopakMissionScreen> {
  KelopakMissionController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= KelopakMissionController(
      KelopakScope.read(context),
      onOpenPath: (path) => KelopakNavigation.openPath(context, path),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller!
      ..visible = ModalRoute.isCurrentOf(context) ?? true;
    return MissionsPage(controller: controller, onBack: widget.onBack);
  }
}
