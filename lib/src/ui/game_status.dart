/// Status hari ini tiap game, dipakai kartu zona Hadiah dan strip Beranda.
library;

import 'package:daily_checkin/daily_checkin.dart' show CheckInRules;
import 'package:flutter/foundation.dart';
import 'package:misi_belanja/misi_belanja.dart' show MissionProgress;
import 'package:roda_sabtu/roda_sabtu.dart' show PrizeKind, SpinEligibility;

import '../controller/kelopak_controller.dart';
import '../core/format.dart';
import '../core/paths.dart';
import '../games/game_actions.dart';

/// Ringkasan satu game pada hari ini: kalimat status, label tombol, dan
/// apakah ada yang bisa diambil sekarang (titik merah).
@immutable
final class KelopakGameStatus {
  /// Membuat ringkasan.
  const KelopakGameStatus({
    required this.game,
    required this.headline,
    required this.detail,
    required this.actionLabel,
    required this.ready,
    this.progress,
    this.streakFilled,
  });

  /// Ringkasan Check-in Harian.
  factory KelopakGameStatus.checkIn(KelopakController c) {
    final filled = c.checkInWeekFilled;
    final monthDay = c.checkInMonthDay;
    final toProduct = CheckInRules.productEvery - monthDay;
    if (!c.isLoggedIn) {
      return const KelopakGameStatus(
        game: KelopakGame.checkIn,
        headline: '+1 Kelopak tiap hari',
        detail: 'Hari ke-7 bonus +3, hari ke-30 produk gratis',
        actionLabel: 'Lihat',
        ready: false,
        streakFilled: 0,
      );
    }
    if (c.claimedToday) {
      return KelopakGameStatus(
        game: KelopakGame.checkIn,
        headline: 'Sudah klaim hari ini',
        detail: toProduct > 0
            ? 'Lanjut besok · produk gratis $toProduct hari lagi'
            : 'Lanjut besok, jaga rentetanmu',
        actionLabel: 'Lihat',
        ready: false,
        streakFilled: filled,
      );
    }
    final bonus = c.nextCheckInStreakDay % CheckInRules.bonusEvery == 0;
    final amount =
        CheckInRules.dailyKelopak + (bonus ? CheckInRules.bonusKelopak : 0);
    return KelopakGameStatus(
      game: KelopakGame.checkIn,
      headline: bonus ? 'Hari bonus! Klaim +$amount' : 'Klaim +$amount Kelopak',
      detail:
          'Hari ke-${c.nextCheckInStreakDay} · $monthDay/30 ke produk gratis',
      actionLabel: 'Klaim',
      ready: true,
      streakFilled: filled,
    );
  }

  /// Ringkasan Roda Sabtu.
  factory KelopakGameStatus.wheel(KelopakController c) {
    final opening = c.nextWheelOpening;
    final hasProduct =
        c.wheelQuotaLeft > 0 &&
        c.spinConfig.prizes.any((prize) => prize.kind == PrizeKind.product);
    final prizeLine = hasProduct
        ? 'Hadiah produk gratis dan Kelopak'
        : 'Hadiah Kelopak sampai ${_maxWheelKelopak(c)}';
    switch (c.spinEligibility) {
      case SpinEligibility.available:
        return KelopakGameStatus(
          game: KelopakGame.wheel,
          headline: c.isLoggedIn ? 'Putar gratis hari ini' : 'Sabtu ini dibuka',
          detail: prizeLine,
          actionLabel: c.isLoggedIn ? 'Putar' : 'Lihat',
          ready: c.isLoggedIn,
        );
      case SpinEligibility.alreadySpun:
        return KelopakGameStatus(
          game: KelopakGame.wheel,
          headline: 'Sudah diputar minggu ini',
          detail: 'Dibuka lagi ${opening.dayLabel}',
          actionLabel: 'Lihat',
          ready: false,
        );
      case SpinEligibility.notSaturday:
        return KelopakGameStatus(
          game: KelopakGame.wheel,
          headline: 'Buka Sabtu · ${opening.remainingLabel}',
          detail: prizeLine,
          actionLabel: 'Lihat',
          ready: false,
        );
      case SpinEligibility.promoInactive:
        return const KelopakGameStatus(
          game: KelopakGame.wheel,
          headline: 'Promo roda sedang libur',
          detail: 'Pantau info promo berikutnya',
          actionLabel: 'Lihat',
          ready: false,
        );
    }
  }

  /// Ringkasan Misi Belanja.
  factory KelopakGameStatus.mission(KelopakController c) {
    final stage = c.activeMissionStage;
    final activeMissionVouchers = c.activeVouchers.where(
      (voucher) => voucher.stageNumber != null,
    );
    if (stage == null) {
      return KelopakGameStatus(
        game: KelopakGame.mission,
        headline: 'Semua tahap selesai',
        detail: activeMissionVouchers.isEmpty
            ? 'Tunggu misi berikutnya, Babes'
            : 'Voucher siap dipakai',
        actionLabel: 'Lihat',
        ready: false,
        progress: 1,
      );
    }
    final MissionProgress progress =
        c.cartMissionProgress ??
        MissionProgress(current: 0, target: stage.minOrderSubtotal);
    final awaiting = c.isLoggedIn && c.view.ordersAwaitingMission.isNotEmpty;
    final reward = 'voucher ${rupiah(stage.voucherAmount)}';
    final String headline;
    if (awaiting) {
      headline = 'Pesanan misi sedang berjalan';
    } else if (activeMissionVouchers.isNotEmpty && progress.current == 0) {
      headline = 'Voucher siap dipakai';
    } else if (progress.reached) {
      headline = 'Target tercapai, checkout sekarang';
    } else {
      headline = '${rupiah(progress.remaining)} lagi';
    }
    return KelopakGameStatus(
      game: KelopakGame.mission,
      headline: headline,
      detail: awaiting
          ? 'Terima pesanan untuk dapat $reward'
          : '${stage.title} · belanja ${rupiah(stage.minOrderSubtotal)}, dapat $reward',
      actionLabel: progress.reached && !awaiting ? 'Checkout' : 'Lihat',
      ready: progress.reached && !awaiting && c.isLoggedIn,
      progress: awaiting ? 1 : progress.fraction,
    );
  }

  static int _maxWheelKelopak(KelopakController c) {
    var best = 0;
    for (final prize in c.spinConfig.prizes) {
      if (prize.kelopak > best) best = prize.kelopak;
    }
    return best;
  }

  /// Ketiga ringkasan, urut seperti kartu di zona Hadiah.
  static List<KelopakGameStatus> all(KelopakController c) =>
      <KelopakGameStatus>[
        KelopakGameStatus.checkIn(c),
        KelopakGameStatus.wheel(c),
        KelopakGameStatus.mission(c),
      ];

  /// Game yang diringkas.
  final KelopakGame game;

  /// Kalimat utama ("Klaim +1 Kelopak").
  final String headline;

  /// Kalimat pendukung satu baris.
  final String detail;

  /// Label tombol kecil.
  final String actionLabel;

  /// Ada yang bisa diambil sekarang (titik merah, tombol berdenyut).
  final bool ready;

  /// Kemajuan 0..1 (Misi Belanja).
  final double? progress;

  /// Titik terisi di strip 7 hari (Check-in Harian).
  final int? streakFilled;

  /// Jalur game.
  String get path => pathOf(game);

  /// Jalur [game] di zona Hadiah.
  static String pathOf(KelopakGame game) => switch (game) {
    KelopakGame.checkIn => KelopakPaths.checkIn,
    KelopakGame.wheel => KelopakPaths.wheel,
    KelopakGame.mission => KelopakPaths.mission,
  };
}
