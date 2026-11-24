/// App identity and official Bpedia links.
library;

import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:url_launcher/url_launcher.dart';

/// Static app configuration.
abstract final class AppConfig {
  /// Display name (launcher label max. 12 characters, brand guideline).
  /// "Bpedia Preview" is only the technical project name in the docs.
  static const String appName = 'Bpedia Demo';

  /// Version shown in Akun > Tentang (matches pubspec `version`).
  static const String appVersion = '2.0.0';

  /// Official Bpedia website.
  static const String bpediaWeb = 'https://bpedia.id';

  /// Official Google Play listing of the Bpedia app.
  static const String playStoreListing =
      'https://play.google.com/store/apps/details?id=com.wot.beautypedia';

  /// Official App Store listing of the Bpedia app.
  static const String appStoreListing =
      'https://apps.apple.com/app/id6751265630';

  /// Where "Unduh app Bpedia resmi" leads on [platform]: the plain store
  /// listing (App Store on iPhone, iPad and Mac, Google Play elsewhere). No
  /// attribution or campaign link: the demo does not track its users. On the
  /// web, Flutter reports the browser's platform, so iPhone browsers also
  /// get the App Store.
  static String downloadAppFor(TargetPlatform platform) => switch (platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => appStoreListing,
    TargetPlatform.android ||
    TargetPlatform.fuchsia ||
    TargetPlatform.linux ||
    TargetPlatform.windows => playStoreListing,
  };
}

/// Opens [url] outside the app (browser or store). Returns false when it
/// could not be opened; never throws. Call it straight from a tap handler so
/// browsers allow the new tab on web.
Future<bool> openExternalLink(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
