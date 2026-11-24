import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/assets.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../core/tokens.dart';
import '../widgets/widgets.dart';
import 'account_widgets.dart';

/// Akun > Tentang aplikasi: version, what this preview is, and the official
/// Bpedia links (opened outside the app, with a hint when that fails).
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Tentang aplikasi')),
      body: AccountListView(
        children: <Widget>[
          const SizedBox(height: BpSpace.s4),
          Center(
            child: Image.asset(
              isDark
                  ? AppImages.logoWordmarkReverse
                  : AppImages.logoWordmarkBipy,
              width: 200,
              fit: BoxFit.contain,
              semanticLabel: 'Logo Bpedia',
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox(width: 200, height: 72),
            ),
          ),
          const SizedBox(height: BpSpace.s3),
          Text(
            'Belanja Bikin Bahagia.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bpTagline.copyWith(
              color: BpColors.of(context).pink500,
            ),
          ),
          const SizedBox(height: BpSpace.s6),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${AppConfig.appName} v${AppConfig.appVersion}',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: BpSpace.s2),
                Text(
                  'Prototipe clean-room aplikasi Bpedia dengan 3 game hadiah '
                  'Kelopak. Semua data adalah data demo yang tersimpan di '
                  'perangkat ini. Bukan aplikasi resmi di Play Store/App '
                  'Store.',
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: BpSpace.s6),
          FilledButton.icon(
            onPressed: () => unawaited(
              _openLink(
                context,
                AppConfig.downloadApp,
                'Tautan belum bisa dibuka. Cari "Bpedia" di Play Store atau '
                'App Store, ya.',
              ),
            ),
            icon: const Icon(Icons.download_rounded),
            label: const Text('Unduh app Bpedia resmi'),
          ),
          const SizedBox(height: BpSpace.s3),
          OutlinedButton.icon(
            onPressed: () => unawaited(
              _openLink(
                context,
                AppConfig.bpediaWeb,
                'Tautan belum bisa dibuka. Buka bpedia.id lewat browser, ya.',
              ),
            ),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Buka bpedia.id'),
          ),
          const SizedBox(height: BpSpace.s4),
          const InfoNote(
            'Tautan dibuka di browser atau toko aplikasi, di luar aplikasi '
            'ini.',
          ),
        ],
      ),
    );
  }

  static Future<void> _openLink(
    BuildContext context,
    String url,
    String failureMessage,
  ) async {
    final opened = await openExternalLink(url);
    if (opened || !context.mounted) return;
    showAccountSnackBar(context, failureMessage);
  }
}
