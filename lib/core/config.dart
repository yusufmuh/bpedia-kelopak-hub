/// App identity and official Bpedia links.
library;

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

  /// Official download link for the Bpedia app (App Store and Google Play).
  static const String downloadApp =
      'https://beautypediaofc.onelink.me/hebt/9fer7r7y';
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
