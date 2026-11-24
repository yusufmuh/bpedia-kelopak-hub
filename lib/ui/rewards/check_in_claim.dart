import 'dart:async';

import 'package:daily_checkin/daily_checkin.dart' show CheckInAward;
import 'package:flutter/material.dart';

import '../../core/assets.dart';
import '../../core/feedback.dart';
import '../../core/format.dart';
import '../../domain/app_state.dart';
import '../../domain/rewards_engine.dart';
import '../shell.dart';
import '../shop/shop_layout.dart' show globalCenterOf, showShopSnackBar;
import '../widgets/widgets.dart';
import 'reward_copy.dart';

/// Claims today's check-in in one tap from the "Ambil 1 Kelopak" button
/// behind [buttonContext] (Beranda and the Hadiah tab), with the full
/// celebration: sound and vibration for the reward tier, the result sheet,
/// and petals bursting from the button.
///
/// [showRewardsLink] adds "Lihat hadiah" (switch to the Hadiah tab) to the
/// sheet; leave it off where the user already is on that tab.
void claimTodayWithCelebration(
  BuildContext buttonContext, {
  bool showRewardsLink = true,
}) {
  final app = AppScope.read(buttonContext);
  final shell = ShellScope.maybeOf(buttonContext);
  final origin = globalCenterOf(buttonContext);
  final outcome = app.claimCheckIn();
  switch (outcome) {
    case CheckInClaimed(:final award, :final newBalance):
      final productWon = award.productEntitled;
      final bonus = award.bonusKelopak > 0;
      app.feedback(
        productWon
            ? FeedbackEvent.productWon
            : bonus
            ? FeedbackEvent.bonus
            : FeedbackEvent.checkIn,
      );
      final rewardsLink = showRewardsLink && shell != null;
      unawaited(
        showRewardResultSheet(
          buttonContext,
          title: _claimTitle(award),
          lines: _claimLines(award, newBalance),
          imageAsset: productWon
              ? AppImages.giftBox3d
              : AppImages.kelopakToken3d,
          primaryLabel: 'Oke',
          secondaryLabel: rewardsLink ? 'Lihat hadiah' : null,
          onSecondary: rewardsLink
              ? () => shell.switchTab(ShellTab.rewards)
              : null,
        ),
      );
      // Started after the sheet is pushed so the petals draw above it.
      PetalBurst.play(
        buttonContext,
        globalOrigin: origin,
        count: productWon ? 48 : (bonus ? 36 : 26),
      );
    case CheckInAlreadyClaimed():
      app.feedback(FeedbackEvent.softError);
      showShopSnackBar(buttonContext, checkInClosedMessage(app));
  }
}

String _claimTitle(CheckInAward award) {
  if (award.productEntitled) return 'Yay, Babes! Produk gratis untukmu';
  if (award.bonusKelopak > 0) {
    return 'Yay, Babes! Bonus ${award.streak} hari beruntun';
  }
  return 'Yay, Babes! +${kelopakLabel(award.dailyKelopak)} masuk';
}

List<String> _claimLines(CheckInAward award, int newBalance) {
  final parts = <String>[
    '+${kelopakLabel(award.dailyKelopak)}',
    if (award.bonusKelopak > 0) 'bonus ${kelopakLabel(award.bonusKelopak)}',
    if (award.productEntitled) '1 produk gratis',
  ];
  return <String>[
    if (parts.length > 1) parts.join(' + '),
    'Hari ke-${award.streak} beruntun',
    if (award.productEntitled)
      'Produk gratis tercatat di Hadiahku: ${EntitlementStatus.pending.label}',
    'Saldo sekarang ${kelopakWithRupiah(newBalance)}',
  ];
}
