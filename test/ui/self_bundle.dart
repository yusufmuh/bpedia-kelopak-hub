import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Di tes paket ini, aset sendiri dibundel tanpa awalan `packages/kelopak_hub/`.
/// Bundle ini membuang awalan itu supaya `AssetImage(package: 'kelopak_hub')`
/// terbaca seperti di aplikasi induk.
class SelfPackageBundle extends CachingAssetBundle {
  static const String _prefix = 'packages/kelopak_hub/';

  String _strip(String key) =>
      key.startsWith(_prefix) ? key.substring(_prefix.length) : key;

  @override
  Future<ByteData> load(String key) => rootBundle.load(_strip(key));

  @override
  Future<ImmutableBuffer> loadBuffer(String key) =>
      rootBundle.loadBuffer(_strip(key));
}

/// Membungkus [child] dengan [SelfPackageBundle].
Widget withSelfBundle(Widget child) =>
    DefaultAssetBundle(bundle: SelfPackageBundle(), child: child);
