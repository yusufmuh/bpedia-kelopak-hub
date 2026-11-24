import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelopak_hub/app.dart';
import 'package:kelopak_hub/data/catalog.dart';
import 'package:kelopak_hub/domain/app_state.dart';
import 'package:kelopak_hub/ui/shop/product_page.dart';
import 'package:kelopak_hub/ui/widgets/widgets.dart';

import '../support/navigation.dart';
import '../support/test_app_state.dart';

void main() {
  testWidgets(
    'grid packshots fly into the product page; the Hot Item carousel has none',
    (tester) async {
      tester.view
        ..physicalSize = const Size(1080, 2220)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final state = await createTestAppState();
      await tester.pumpWidget(
        AppScope(notifier: state, child: const BpediaApp()),
      );
      await tester.pumpAndSettle();
      final home = find.byType(Scrollable).first;

      final carousel = find.byType(ProductCarousel);
      await tester.scrollUntilVisible(carousel, 300, scrollable: home);
      expect(
        find.descendant(of: carousel, matching: find.byType(Hero)),
        findsNothing,
      );

      final product = demoCatalog.firstWhere((product) => !product.isHot);
      final tag = productHeroTag(product.id);
      final gridCard = find.byWidgetPredicate(
        (widget) => widget is ProductCard && widget.heroTag == tag,
      );
      await tester.scrollUntilVisible(gridCard, 300, scrollable: home);
      await tester.pumpAndSettle();
      final tags = tester
          .widgetList<Hero>(find.byType(Hero))
          .map((hero) => hero.tag)
          .toList();
      expect(tags, contains(tag));
      expect(tags.toSet(), hasLength(tags.length));

      await tester.tap(
        find.descendant(of: gridCard, matching: find.text(product.name)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ProductPage), findsOneWidget);
      expect(
        find.byWidgetPredicate((widget) => widget is Hero && widget.tag == tag),
        findsOneWidget,
      );

      await tester.tapBack();
      await tester.pumpAndSettle();
      expect(find.byType(ProductPage), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    },
  );
}
