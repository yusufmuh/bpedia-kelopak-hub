import 'package:flutter/material.dart';
import 'package:misi_belanja/misi_belanja.dart' show VoucherCard;

import '../../core/assets.dart';
import '../../core/format.dart';
import '../../core/tokens.dart';
import '../../domain/app_state.dart';
import '../../domain/rewards_engine.dart';
import '../shop/cart_page.dart';
import '../widgets/widgets.dart';
import 'checkin_page.dart';
import 'missions_page.dart';
import 'rewards_widgets.dart';

/// Tabs of [MyRewardsPage].
enum MyRewardsTab { vouchers, products }

/// Hadiahku: mission vouchers (newest first) and free-product rights from
/// Check-in Harian and Roda Sabtu.
class MyRewardsPage extends StatelessWidget {
  const MyRewardsPage({super.key, this.initialTab = MyRewardsTab.vouchers});

  /// Tab shown first.
  final MyRewardsTab initialTab;

  @override
  Widget build(BuildContext context) {
    final largeText = isLargeText(context);
    final tabBar = TabBar(
      isScrollable: largeText,
      tabAlignment: largeText ? TabAlignment.start : TabAlignment.fill,
      tabs: const <Widget>[
        Tab(text: 'Voucher'),
        Tab(text: 'Produk gratis'),
      ],
    );
    return DefaultTabController(
      length: MyRewardsTab.values.length,
      initialIndex: initialTab.index,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Hadiahku'),
          actions: demoAppBarActions,
          bottom: PreferredSize(
            preferredSize: tabBar.preferredSize,
            child: ContentWidth(child: tabBar),
          ),
        ),
        body: const SafeArea(
          top: false,
          child: TabBarView(children: <Widget>[_VoucherTab(), _ProductTab()]),
        ),
      ),
    );
  }
}

class _VoucherTab extends StatelessWidget {
  const _VoucherTab();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final vouchers = app.vouchers;
    if (vouchers.isEmpty) {
      return ScrollableCenter(
        child: EmptyState(
          imageAsset: AppImages.bipyNgintip,
          title: 'Belum ada voucher',
          body:
              'Selesaikan Misi Belanja untuk dapat voucher belanja '
              'berikutnya.',
          actionLabel: 'Lihat Misi Belanja',
          onAction: () => openRewardsPage(context, const MissionsPage()),
        ),
      );
    }
    final active = app.activeVouchers.length;
    return ListView.builder(
      padding: rewardsPagePadding.copyWith(top: BpSpace.s4),
      itemCount: vouchers.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return RewardsContent(
            child: Padding(
              padding: const EdgeInsets.only(bottom: BpSpace.s3),
              child: Text(
                active == 0
                    ? 'Belum ada voucher aktif. Voucher terpakai dan '
                          'kedaluwarsa tetap tercatat di sini.'
                    : '$active voucher aktif. Pilih voucher saat checkout.',
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }
        return RewardsContent(
          child: Padding(
            padding: const EdgeInsets.only(bottom: BpSpace.s3),
            child: VoucherCard(
              voucher: vouchers[index - 1],
              today: app.today,
              onUse: () => openRewardsPage(context, const CartPage()),
            ),
          ),
        );
      },
    );
  }
}

class _ProductTab extends StatelessWidget {
  const _ProductTab();

  @override
  Widget build(BuildContext context) {
    final entitlements = AppScope.of(context).entitlements;
    if (entitlements.isEmpty) {
      return ScrollableCenter(
        child: EmptyState(
          imageAsset: AppImages.bipyNgintip,
          title: 'Belum ada produk gratis',
          body:
              'Check-in 30 hari beruntun atau coba Roda Sabtu untuk dapat '
              'produk gratis.',
          actionLabel: 'Ke Check-in Harian',
          onAction: () => openRewardsPage(context, const CheckInPage()),
        ),
      );
    }
    return ListView.builder(
      padding: rewardsPagePadding.copyWith(top: BpSpace.s4),
      itemCount: entitlements.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return const RewardsContent(
            child: Padding(
              padding: EdgeInsets.only(bottom: BpSpace.s3),
              child: StatusBanner(
                icon: Icons.local_shipping_outlined,
                tone: StatusTone.info,
                title: 'Produk gratis dikirim tim Bpedia',
                detail: Text(
                  'Di Mode Demo, statusnya tetap menunggu pengiriman.',
                ),
              ),
            ),
          );
        }
        return RewardsContent(
          child: Padding(
            padding: const EdgeInsets.only(bottom: BpSpace.s3),
            child: _EntitlementTile(entitlement: entitlements[index - 1]),
          ),
        );
      },
    );
  }
}

class _EntitlementTile extends StatelessWidget {
  const _EntitlementTile({required this.entitlement});

  final ProductEntitlement entitlement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SoftCard(
      child: MergeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const RewardIconBadge(child: GiftArt(size: 30)),
            const SizedBox(width: BpSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('1 produk gratis', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    '${entitlement.source.label} · '
                    '${wibDateLabel(entitlement.wibDay)}',
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: BpSpace.s2),
                  StatusPill(
                    Icons.schedule_rounded,
                    entitlement.status.label,
                    tone: StatusTone.info,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
