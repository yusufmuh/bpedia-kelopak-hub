/// Demo catalog (pure Dart): 19 products from the bpedia.id snapshot of
/// 24 Nov 2026 with clean illustration packshots. Prices are Demo values.
library;

/// Product category with its Indonesian label and brand icon.
enum ProductCategory {
  skincare('Skincare', 'bpedia-ikon-skincare'),
  bodycare('Bodycare', 'bpedia-ikon-bodycare'),
  makeup('Makeup', 'bpedia-ikon-makeup'),
  haircare('Haircare', 'bpedia-ikon-haircare'),
  fragrance('Fragrance', 'bpedia-ikon-fragrance'),
  lashesTools('Lashes & Tools', 'bpedia-ikon-lashes');

  const ProductCategory(this.label, this.iconName);

  /// Label shown on chips and filters.
  final String label;

  /// Brand icon base name for `BrandIcon` (append `-mono` for the outline variant).
  final String iconName;

  /// Full asset path of the color icon.
  String get iconAsset => 'assets/icons/$iconName.svg';
}

/// A sellable demo product. [price] is the final price; [strikePrice] the
/// original price when discounted.
final class Product {
  const Product({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    required this.price,
    required this.imageAsset,
    this.strikePrice,
    this.isHot = false,
  });

  /// Stable id used in carts and orders.
  final String id;

  /// Full product name.
  final String name;

  /// Brand name.
  final String brand;

  /// Category for filters.
  final ProductCategory category;

  /// Final price in rupiah.
  final int price;

  /// Original price in rupiah (only when higher than [price]).
  final int? strikePrice;

  /// Packshot asset path (`assets/images/...webp`, illustration).
  final String imageAsset;

  /// Listed under "Hot Item".
  final bool isHot;

  /// Whole-percent discount (rounded down so it never overstates), or null.
  int? get discountPercent {
    final original = strikePrice;
    if (original == null || original <= price) return null;
    return (original - price) * 100 ~/ original;
  }
}

/// All demo products in display order.
const List<Product> demoCatalog = <Product>[
  Product(
    id: 'animate-brightening-soap-80g',
    name: 'Animate Brightening Face & Body Soap 80 g',
    brand: 'Animate',
    category: ProductCategory.bodycare,
    price: 10000,
    strikePrice: 16500,
    imageAsset: 'assets/images/produk_bodysoap.webp',
    isHot: true,
  ),
  Product(
    id: 'salsa-body-glow-serum-symphony',
    name: 'Salsa Bleach Body Glow Serum Symphony',
    brand: 'Salsa',
    category: ProductCategory.bodycare,
    price: 10000,
    strikePrice: 20000,
    imageAsset: 'assets/images/produk_bodyserum.webp',
    isHot: true,
  ),
  Product(
    id: 'brighty-glow-bright-bar-soap',
    name: 'Brighty Glow & Bright Bar Soap',
    brand: 'Brighty',
    category: ProductCategory.bodycare,
    price: 10000,
    strikePrice: 22500,
    imageAsset: 'assets/images/produk_barsoap.webp',
    isHot: true,
  ),
  Product(
    id: 'animate-acne-care-serum-20ml',
    name: 'Animate Acne Care Serum 20 ml',
    brand: 'Animate',
    category: ProductCategory.skincare,
    price: 20500,
    imageAsset: 'assets/images/produk_serum.webp',
  ),
  Product(
    id: 'animate-whitening-day-cream-10g',
    name: 'Animate Whitening Day Cream 10 g',
    brand: 'Animate',
    category: ProductCategory.skincare,
    price: 19900,
    imageAsset: 'assets/images/produk_cream.webp',
  ),
  Product(
    id: 'originote-hyalu-c-serum',
    name: 'The Originote Hyalu-C Serum',
    brand: 'The Originote',
    category: ProductCategory.skincare,
    price: 28000,
    imageAsset: 'assets/images/produk_serum2.webp',
  ),
  Product(
    id: 'originote-ceramella-sunscreen',
    name: 'The Originote Ceramella Sunscreen',
    brand: 'The Originote',
    category: ProductCategory.skincare,
    price: 32000,
    imageAsset: 'assets/images/produk_sunscreen_tube.webp',
  ),
  Product(
    id: 'wardah-face-wash-hydra-rose',
    name: 'Wardah Face Wash Hydra Rose',
    brand: 'Wardah',
    category: ProductCategory.skincare,
    price: 40608,
    imageAsset: 'assets/images/produk_facialwash.webp',
  ),
  Product(
    id: 'skintific-matte-fit-serum-spf50',
    name: 'Skintific Matte Fit Serum SPF 50+++',
    brand: 'Skintific',
    category: ProductCategory.skincare,
    price: 78795,
    imageAsset: 'assets/images/produk_sunscreen_bottle.webp',
  ),
  Product(
    id: 'azarine-hydrasoothe-sunscreen-gel-50ml',
    name: 'Azarine Hydrasoothe Sunscreen Gel 50 ml',
    brand: 'Azarine',
    category: ProductCategory.skincare,
    price: 49000,
    imageAsset: 'assets/images/produk_sunscreen_gel.webp',
  ),
  Product(
    id: 'emina-sun-battle-sunscreen',
    name: 'Emina Sun Battle Sunscreen',
    brand: 'Emina',
    category: ProductCategory.skincare,
    price: 36565,
    imageAsset: 'assets/images/produk_sunscreen_tube2.webp',
  ),
  Product(
    id: 'somethinc-copy-paste-cushion-nina',
    name: 'Somethinc Copy Paste Cushion – Nina',
    brand: 'Somethinc',
    category: ProductCategory.makeup,
    price: 132510,
    imageAsset: 'assets/images/produk_cushion.webp',
  ),
  Product(
    id: 'somethinc-ombrella-lip-totem-tint-ikr',
    name: 'Somethinc Ombrella Lip Totem Tint – Ikr',
    brand: 'Somethinc',
    category: ProductCategory.makeup,
    price: 70800,
    imageAsset: 'assets/images/produk_liptint.webp',
  ),
  Product(
    id: 'gogotales-crystal-slipper-palette-g03',
    name: 'Gogotales Crystal Slipper Eyeshadow Palette G03',
    brand: 'Gogo Tales',
    category: ProductCategory.makeup,
    price: 60000,
    imageAsset: 'assets/images/produk_eyeshadow.webp',
  ),
  Product(
    id: 'gogotales-dusk-thick-mist-lip-glaze-g06',
    name: 'Gogotales Dusk Thick Mist Lip Glaze G06',
    brand: 'Gogo Tales',
    category: ProductCategory.makeup,
    price: 35000,
    imageAsset: 'assets/images/produk_lipglaze.webp',
  ),
  Product(
    id: 'salsa-vinylash-premium-lilac',
    name: 'Salsa Vinylash Premium Color Lilac',
    brand: 'Salsa',
    category: ProductCategory.lashesTools,
    price: 12000,
    imageAsset: 'assets/images/produk_vinylash_lilac.webp',
  ),
  Product(
    id: 'scarlett-whitening-edp-30ml',
    name: 'Scarlett Whitening Eau De Parfum 30 ml',
    brand: 'Scarlett',
    category: ProductCategory.fragrance,
    price: 64375,
    imageAsset: 'assets/images/produk_perfume.webp',
  ),
  Product(
    id: 'scarlett-niacinamide-body-serum-170ml',
    name: 'Scarlett Niacinamide Brightening Body Serum 170 ml',
    brand: 'Scarlett',
    category: ProductCategory.bodycare,
    price: 40170,
    imageAsset: 'assets/images/produk_bodyserum2.webp',
  ),
  Product(
    id: 'satto-millenium-black-tonic-shampoo-200ml',
    name: 'Satto Millenium Black Tonic Shampoo 200 ml',
    brand: 'Satto',
    category: ProductCategory.haircare,
    price: 65690,
    imageAsset: 'assets/images/produk_shampoo.webp',
  ),
];

/// Product with [id], or null when it is not in the catalog.
Product? productById(String id) {
  for (final product in demoCatalog) {
    if (product.id == id) return product;
  }
  return null;
}

/// Products shown under "Hot Item".
List<Product> get hotProducts =>
    demoCatalog.where((product) => product.isHot).toList(growable: false);

/// Products in [category], catalog order.
List<Product> byCategory(ProductCategory category) => demoCatalog
    .where((product) => product.category == category)
    .toList(growable: false);

/// Case-insensitive search over name and brand.
///
/// Every word of [query] must match; a blank query returns the whole catalog.
List<Product> search(String query) {
  final terms = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((term) => term.isNotEmpty)
      .toList(growable: false);
  if (terms.isEmpty) return List<Product>.unmodifiable(demoCatalog);
  return demoCatalog
      .where((product) {
        final haystack = '${product.name} ${product.brand}'.toLowerCase();
        return terms.every(haystack.contains);
      })
      .toList(growable: false);
}
