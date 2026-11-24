import 'package:flutter/material.dart';

import '../../core/assets.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/tokens.dart';
import '../../domain/app_settings.dart';
import '../../domain/app_state.dart';
import '../rewards/ledger_page.dart';
import '../rewards/my_rewards_page.dart';
import '../widgets/widgets.dart';
import 'about_page.dart';
import 'account_widgets.dart';
import 'demo_tools_page.dart';
import 'sound_settings_page.dart';
import 'terms_page.dart';
import 'theme_mode_selector.dart';

/// Akun tab: the demo profile with its Kelopak balance, shortcuts to
/// Hadiahku and Riwayat Kelopak, sound and theme settings, Mode Demo (QA),
/// the program terms and the about page.
class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final settings = app.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Akun')),
      body: AccountListView(
        children: <Widget>[
          _ProfileCard(balance: app.balance),
          const SizedBox(height: BpSpace.s6),
          const SectionHeader('Hadiah'),
          const SizedBox(height: BpSpace.s2),
          SettingsGroup(
            children: <Widget>[
              SettingsNavTile(
                icon: BrandIcon(
                  BrandIcons.mono(BrandIcons.reward),
                  color: scheme.secondary,
                ),
                title: 'Hadiahku',
                subtitle: _rewardsSummary(app),
                onTap: () => pushAccountPage(context, const MyRewardsPage()),
              ),
              SettingsNavTile(
                icon: const Icon(Icons.history_rounded),
                title: 'Riwayat Kelopak',
                subtitle: 'Kelopak yang masuk dan terpakai',
                onTap: () => pushAccountPage(context, const LedgerPage()),
              ),
            ],
          ),
          const SizedBox(height: BpSpace.s6),
          const SectionHeader('Pengaturan'),
          const SizedBox(height: BpSpace.s2),
          SettingsGroup(
            children: <Widget>[
              SettingsNavTile(
                icon: const Icon(Icons.volume_up_outlined),
                title: 'Suara & getar',
                subtitle: _soundSummary(settings),
                onTap: () =>
                    pushAccountPage(context, const SoundSettingsPage()),
              ),
              _AppearanceBlock(
                mode: settings.themeMode,
                onChanged: app.setThemeMode,
              ),
            ],
          ),
          const SizedBox(height: BpSpace.s6),
          const SectionHeader('Lainnya'),
          const SizedBox(height: BpSpace.s2),
          SettingsGroup(
            children: <Widget>[
              SettingsNavTile(
                icon: const Icon(Icons.science_outlined),
                title: 'Mode Demo (QA)',
                subtitle: app.demoOffsetDays == 0
                    ? 'Atur tanggal simulasi dan data demo'
                    : 'Tanggal simulasi: ${wibDateLabel(app.today)}',
                onTap: () => pushAccountPage(context, const DemoToolsPage()),
              ),
              SettingsNavTile(
                icon: const Icon(Icons.article_outlined),
                title: 'Syarat & Ketentuan Program',
                subtitle: 'Kelopak, Check-in, Roda Sabtu, Misi Belanja',
                onTap: () => pushAccountPage(context, const TermsPage()),
              ),
              SettingsNavTile(
                icon: const Icon(Icons.info_outline_rounded),
                title: 'Tentang aplikasi',
                subtitle: '${AppConfig.appName} v${AppConfig.appVersion}',
                onTap: () => pushAccountPage(context, const AboutPage()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _rewardsSummary(AppState app) {
    final vouchers = app.activeVouchers.length;
    final products = app.entitlements.length;
    if (vouchers == 0 && products == 0) {
      return 'Belum ada voucher atau produk gratis';
    }
    return <String>[
      if (vouchers > 0) '$vouchers voucher aktif',
      if (products > 0) '$products produk gratis',
    ].join(' · ');
  }

  static String _soundSummary(AppSettings settings) {
    String state(bool on) => on ? 'aktif' : 'mati';
    return 'Efek suara ${state(settings.sfxEnabled)}, '
        'musik ${state(settings.musicEnabled)}, '
        'getar ${state(settings.hapticsEnabled)}';
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return SoftCard(
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 28,
            backgroundColor: scheme.primary,
            child: Image.asset(
              isDark ? AppImages.monogramPlum : AppImages.monogramPutih,
              width: 28,
              height: 28,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
              errorBuilder: (context, error, stackTrace) =>
                  Icon(Icons.person_outline_rounded, color: scheme.onPrimary),
            ),
          ),
          const SizedBox(width: BpSpace.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Pengguna Demo', style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  'Data tersimpan di perangkat ini',
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: BpSpace.s2),
                KelopakAmount(balance, size: KelopakAmountSize.small),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Tampilan" row inside the settings card: title, hint and the picker.
class _AppearanceBlock extends StatelessWidget {
  const _AppearanceBlock({required this.mode, required this.onChanged});

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tileTheme = theme.listTileTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BpSpace.s4,
        BpSpace.s3,
        BpSpace.s4,
        BpSpace.s4,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.palette_outlined, color: tileTheme.iconColor),
          const SizedBox(width: BpSpace.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text('Tampilan', style: tileTheme.titleTextStyle),
                Text(
                  'Pilih tema terang, gelap, atau ikuti ponsel',
                  style: tileTheme.subtitleTextStyle,
                ),
                const SizedBox(height: BpSpace.s3),
                ThemeModeSelector(value: mode, onChanged: onChanged),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
