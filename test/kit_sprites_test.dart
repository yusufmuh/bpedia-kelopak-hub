import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelopak_hub/kit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('grid setiap lembar Bipy memuat seluruh frame', () {
    for (final SpriteSheetSpec spec in BipySprites.values) {
      expect(spec.package, BipySprites.package);
      expect(spec.frameCount, lessThanOrEqualTo(spec.columns * spec.rows), reason: spec.asset);
      expect(spec.frameCount, greaterThan((spec.rows - 1) * spec.columns), reason: spec.asset);
    }
  });

  test('aset lembar Bipy terdaftar di paket', () async {
    for (final SpriteSheetSpec spec in BipySprites.values) {
      final ByteData data = await rootBundle.load(spec.asset);
      expect(data.lengthInBytes, greaterThan(50000), reason: spec.asset);
    }
  });

  testWidgets('BipySprite tampil setinggi yang diminta', (WidgetTester tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: BipySprite(BipySprites.idle, height: 120, semanticLabel: 'Bipy')),
      ),
    );
    expect(tester.getSize(find.byType(BipySprite)).height, closeTo(120, 0.01));
    expect(find.bySemanticsLabel('Bipy'), findsOneWidget);
  });
}
