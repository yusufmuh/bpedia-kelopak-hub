import 'dart:async';

import 'package:flutter/material.dart';
import 'package:misi_belanja/misi_belanja.dart'
    show MissionVoucher, RedeemProblem;

import '../../core/format.dart';
import '../../core/tokens.dart';
import '../../domain/app_state.dart';
import '../rewards/missions_page.dart';
import '../widgets/widgets.dart';
import 'shop_navigation.dart';

/// The voucher picked in [showVoucherPicker]; null [voucherId] means none.
final class VoucherChoice {
  const VoucherChoice(this.voucherId);

  /// Chosen voucher, or null for "Tanpa voucher".
  final String? voucherId;
}

/// Why a voucher cannot be used on this cart, in plain words.
String voucherProblemText(RedeemProblem problem, {required int shortfall}) =>
    switch (problem) {
      RedeemProblem.belowMinimum => 'Belanja ${rupiah(shortfall)} lagi',
      RedeemProblem.sameOrder => 'Tidak bisa dipakai di pesanan asal',
      RedeemProblem.alreadyUsed => 'Sudah dipakai',
      RedeemProblem.expired => 'Kedaluwarsa',
    };

/// Id of the most valuable voucher usable on the current cart (earliest
/// expiry on ties), or null.
String? bestUsableVoucherId(AppState app) {
  MissionVoucher? best;
  for (final voucher in app.activeVouchers) {
    if (app.voucherProblemForCart(voucher.id) != null) continue;
    if (best == null ||
        voucher.amount > best.amount ||
        (voucher.amount == best.amount &&
            voucher.expiresDay < best.expiresDay)) {
      best = voucher;
    }
  }
  return best?.id;
}

/// Bottom sheet listing every mission voucher: usable ones can be chosen,
/// the others are greyed out with the reason. Completes with null when
/// dismissed without a choice.
Future<VoucherChoice?> showVoucherPicker(
  BuildContext context, {
  required String? selectedId,
}) {
  return showModalBottomSheet<VoucherChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _VoucherPickerSheet(selectedId: selectedId),
  );
}

typedef _VoucherEntry = ({
  MissionVoucher voucher,
  RedeemProblem? problem,
  int shortfall,
});

class _VoucherPickerSheet extends StatelessWidget {
  const _VoucherPickerSheet({required this.selectedId});

  final String? selectedId;

  static int _rank(_VoucherEntry entry) => switch (entry.problem) {
    null => 0,
    RedeemProblem.belowMinimum => 1,
    RedeemProblem.sameOrder => 2,
    RedeemProblem.alreadyUsed => 3,
    RedeemProblem.expired => 4,
  };

  void _openMissions(BuildContext context) {
    final navigator = Navigator.of(context);
    navigator.pop();
    unawaited(navigator.push<void>(pageRoute(const MissionsPage())));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final entries = <_VoucherEntry>[
      for (final voucher in app.vouchers)
        (
          voucher: voucher,
          problem: app.voucherProblemForCart(voucher.id),
          shortfall: app.voucherShortfallForCart(voucher.id),
        ),
    ];
    entries.sort((a, b) {
      final byRank = _rank(a).compareTo(_rank(b));
      if (byRank != 0) return byRank;
      if (a.problem == RedeemProblem.belowMinimum) {
        return a.shortfall.compareTo(b.shortfall);
      }
      return b.voucher.amount.compareTo(a.voucher.amount);
    });
    final reasonStyle = theme.textTheme.bodyMedium!.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: BpSpace.s6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: BpSpace.s6),
            child: Semantics(
              header: true,
              child: Text('Pilih voucher', style: theme.textTheme.titleLarge),
            ),
          ),
          const SizedBox(height: BpSpace.s1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: BpSpace.s6),
            child: Text(
              'Voucher dari Misi Belanja. Satu voucher untuk satu pesanan.',
              style: reasonStyle,
            ),
          ),
          const SizedBox(height: BpSpace.s3),
          _VoucherOption(
            title: 'Tanpa voucher',
            leading: Icon(
              Icons.do_not_disturb_on_outlined,
              color: scheme.onSurfaceVariant,
            ),
            selected: selectedId == null,
            onTap: () => Navigator.of(context).pop(const VoucherChoice(null)),
          ),
          for (final entry in entries)
            _VoucherOption(
              title: 'Voucher ${rupiah(entry.voucher.amount)}',
              subtitle: _subtitle(entry),
              leading: BrandIcon(
                BrandIcons.voucher,
                color: entry.problem == null ? null : scheme.onSurfaceVariant,
              ),
              selected: entry.voucher.id == selectedId,
              actionLabel: 'Pakai',
              onTap: entry.problem == null
                  ? () => Navigator.of(
                      context,
                    ).pop(VoucherChoice(entry.voucher.id))
                  : null,
            ),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                BpSpace.s6,
                BpSpace.s3,
                BpSpace.s6,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Belum ada voucher. Selesaikan Misi Belanja untuk '
                    'mendapatkannya.',
                    style: reasonStyle,
                  ),
                  const SizedBox(height: BpSpace.s2),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      alignment: AlignmentDirectional.centerStart,
                    ),
                    onPressed: () => _openMissions(context),
                    child: const Text('Lihat Misi Belanja'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _subtitle(_VoucherEntry entry) {
    final problem = entry.problem;
    if (problem != null) {
      return voucherProblemText(problem, shortfall: entry.shortfall);
    }
    final voucher = entry.voucher;
    return 'Min. belanja ${rupiah(voucher.minSpend)} · '
        'berlaku s.d. ${shortDateLabel(voucher.expiresDay)}';
  }
}

/// One choice in the voucher sheet. Tap, Enter or Space picks it and closes
/// the sheet; arrow keys only move focus. A null [onTap] shows the choice
/// greyed out while its [subtitle] (the reason) stays readable.
class _VoucherOption extends StatelessWidget {
  const _VoucherOption({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.leading,
    this.actionLabel,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool selected;
  final VoidCallback? onTap;

  /// Hint shown on choosable, unselected options ("Pakai").
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = onTap != null;
    final detail = subtitle;
    final action = actionLabel;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: BpSpace.s3, vertical: 2),
      child: ListTile(
        enabled: enabled,
        selected: selected,
        onTap: onTap,
        selectedTileColor: scheme.primaryContainer,
        contentPadding: const EdgeInsets.symmetric(horizontal: BpSpace.s3),
        leading: leading,
        title: Text(
          title,
          style: theme.textTheme.bodyLarge!.copyWith(
            color: enabled ? scheme.onSurface : scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: detail == null
            ? null
            : Text(
                detail,
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
        trailing: selected
            ? Icon(
                Icons.check_circle_rounded,
                color: scheme.primary,
                semanticLabel: 'Dipilih',
              )
            : enabled && action != null
            ? Text(
                action,
                style: theme.textTheme.labelLarge!.copyWith(
                  color: scheme.primary,
                ),
              )
            : null,
      ),
    );
  }
}
