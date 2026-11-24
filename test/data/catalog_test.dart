import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kelopak_hub/data/catalog.dart';

void main() {
  test('has 19 products with unique ids and existing images', () {
    expect(demoCatalog, hasLength(19));
    expect(demoCatalog.map((product) => product.id).toSet(), hasLength(19));
    for (final product in demoCatalog) {
      expect(
        File(product.imageAsset).existsSync(),
        isTrue,
        reason: '${product.id} -> ${product.imageAsset}',
      );
      expect(product.price, greaterThan(0));
    }
  });

  test('every category has a brand icon file and products', () {
    var total = 0;
    for (final category in ProductCategory.values) {
      expect(File(category.iconAsset).existsSync(), isTrue);
      expect(
        File('assets/icons/${category.iconName}-mono.svg').existsSync(),
        isTrue,
      );
      final products = byCategory(category);
      expect(products, isNotEmpty, reason: category.label);
      total += products.length;
    }
    expect(total, demoCatalog.length);
  });

  test('the three discounted soaps are the Hot Items', () {
    expect(hotProducts.map((product) => product.discountPercent), <int>[
      39,
      50,
      55,
    ]);
    expect(
      demoCatalog
          .where((product) => !product.isHot)
          .map((p) => p.discountPercent),
      everyElement(isNull),
    );
  });

  test('looks products up and searches name and brand case-insensitively', () {
    expect(
      productById('satto-millenium-black-tonic-shampoo-200ml')?.price,
      65690,
    );
    expect(productById('missing'), isNull);
    expect(search('SOMETHINC'), hasLength(2));
    expect(
      search('somethinc tint').single.id,
      'somethinc-ombrella-lip-totem-tint-ikr',
    );
    expect(search('gogo tales'), hasLength(2));
    expect(search('   '), hasLength(19));
    expect(search('tidak ada'), isEmpty);
  });
}
