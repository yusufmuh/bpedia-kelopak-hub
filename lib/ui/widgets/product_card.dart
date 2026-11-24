import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/tokens.dart';
import '../../data/catalog.dart';
import 'price_text.dart';

/// Hero tag of a product's packshot, shared by [ProductCard] and the product
/// page so the photo flies from the list into the detail.
///
/// Only the Beranda grid uses it: every product shown on both of two routes
/// with the same tag would fly, so search results and "Produk lain" (which
/// share products with Beranda and with the page under them) do not.
Object productHeroTag(String productId) => 'product-packshot-$productId';

/// Product card: clean 1:1 packshot, UI-rendered discount badge and "Hot"
/// pill, 2-line name, price and a "+ Keranjang" secondary pill button.
///
/// Screen readers and keyboards get two sibling controls: the product
/// ("{name}, Rp…", opens the detail) and "Tambah {name} ke keranjang". The
/// tap target lies above the photo, so its ripple and focus highlight show
/// on it, and a focused card gets a 2 dp Berry outline.
class ProductCard extends StatefulWidget {
  const ProductCard(
    this.product, {
    super.key,
    this.onTap,
    this.onAddToCart,
    this.compact = false,
    this.heroTag,
  });

  /// Product to show.
  final Product product;

  /// Opens the product detail.
  final VoidCallback? onTap;

  /// Adds one item to the cart; the button is hidden when null.
  final VoidCallback? onAddToCart;

  /// Tighter padding for carousels.
  final bool compact;

  /// Wraps the packshot in a [Hero] with this tag (see [productHeroTag]).
  /// Only for screens where the product appears once: two heroes with the
  /// same tag on one route are an error.
  final Object? heroTag;

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final product = widget.product;
    final onTap = widget.onTap;
    final onAddToCart = widget.onAddToCart;
    final percent = product.discountPercent;
    final Widget packshot = ColoredBox(
      color: scheme.surfaceContainer,
      child: Image.asset(
        product.imageAsset,
        fit: BoxFit.cover,
        cacheWidth: 600,
        excludeFromSemantics: true,
        errorBuilder: (context, error, stackTrace) =>
            Icon(Icons.image_outlined, color: scheme.onSurfaceVariant),
      ),
    );
    final tag = widget.heroTag;
    final padding = widget.compact ? BpSpace.s2 + 2 : BpSpace.s3;
    final summary = StringBuffer(product.name)
      ..write(', ${rupiah(product.price)}');
    if (percent != null) summary.write(', diskon $percent%');
    if (product.isHot) summary.write(', Hot Item');

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AspectRatio(
          aspectRatio: 1,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (tag == null) packshot else Hero(tag: tag, child: packshot),
              if (percent != null || product.isHot)
                Positioned(
                  top: BpSpace.s2,
                  left: BpSpace.s2,
                  right: BpSpace.s2,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      if (percent != null) DiscountBadge(percent: percent),
                      if (product.isHot) const HotPill(),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(padding, padding, padding, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: BpSpace.s1),
              PriceText(
                product.price,
                product.strikePrice,
                compact: true,
                showDiscount: false,
              ),
              SizedBox(height: onAddToCart == null ? padding : 0),
            ],
          ),
        ),
      ],
    );

    // The InkWell sits on a transparent Material above the photo, so its ink
    // and focus highlight are not hidden under the opaque packshot. It also
    // gives the product node its tap action and focusability.
    final Widget details = Semantics(
      container: true,
      button: onTap != null,
      label: summary.toString(),
      child: Stack(
        children: <Widget>[
          ExcludeSemantics(child: content),
          if (onTap != null)
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onTap,
                  onFocusChange: (focused) {
                    if (focused != _focused) {
                      setState(() => _focused = focused);
                    }
                  },
                ),
              ),
            ),
        ],
      ),
    );

    final cardShape = theme.cardTheme.shape;
    return FocusTraversalGroup(
      child: Card(
        shape: _focused
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(BpRadius.md),
                side: BorderSide(color: scheme.secondary, width: 2),
              )
            : cardShape,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            details,
            if (onAddToCart != null)
              Padding(
                padding: EdgeInsets.all(padding),
                child: OutlinedButton.icon(
                  onPressed: onAddToCart,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: BpSpace.s2),
                    textStyle: theme.textTheme.titleSmall,
                    iconSize: 18,
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(
                    'Keranjang',
                    semanticsLabel: 'Tambah ${product.name} ke keranjang',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Hot" badge (night on honey, radius 6 like every brand badge) for Hot
/// Item products.
class HotPill extends StatelessWidget {
  const HotPill({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = BpColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.honey400,
        borderRadius: BorderRadius.circular(BpRadius.xs),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 2, 8, 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.local_fire_department_rounded,
              size: 14,
              color: BpColors.light.night950,
            ),
            const SizedBox(width: 2),
            Text(
              'Hot',
              style: Theme.of(context).textTheme.labelMedium!.copyWith(
                color: BpColors.light.night950,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal row of equal-height [ProductCard]s that grows with the text size instead of clipping.
class ProductCarousel extends StatelessWidget {
  const ProductCarousel({
    super.key,
    required this.products,
    this.onTap,
    this.onAddToCart,
    this.cardWidth = 168,
    this.padding = const EdgeInsets.symmetric(horizontal: BpSpace.s4),
    this.heroPackshots = false,
  });

  /// Products in display order.
  final List<Product> products;

  /// Opens a product.
  final ValueChanged<Product>? onTap;

  /// Adds a product to the cart.
  final ValueChanged<Product>? onAddToCart;

  /// Width of each card.
  final double cardWidth;

  /// Outer padding of the scroll view.
  final EdgeInsetsGeometry padding;

  /// Gives each packshot its [productHeroTag]. Only when every product is
  /// shown once on the route.
  final bool heroPackshots;

  @override
  Widget build(BuildContext context) {
    final tap = onTap;
    final add = onAddToCart;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: BpSpace.s3,
          children: <Widget>[
            for (final product in products)
              SizedBox(
                width: cardWidth,
                child: ProductCard(
                  product,
                  compact: true,
                  heroTag: heroPackshots ? productHeroTag(product.id) : null,
                  onTap: tap == null ? null : () => tap(product),
                  onAddToCart: add == null ? null : () => add(product),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Columns for a product grid of [width]: 2 up to 600 dp, 3 up to 900 dp, then 4.
int productGridColumns(double width) {
  if (width > 900) return 4;
  if (width > 600) return 3;
  return 2;
}

/// Sliver grid of [ProductCard]s whose rows size to their content (safe at 200% text).
class SliverProductGrid extends StatelessWidget {
  const SliverProductGrid({
    super.key,
    required this.products,
    this.onTap,
    this.onAddToCart,
    this.heroPackshots = false,
  });

  /// Products in display order.
  final List<Product> products;

  /// Opens a product.
  final ValueChanged<Product>? onTap;

  /// Adds a product to the cart.
  final ValueChanged<Product>? onAddToCart;

  /// Gives each packshot its [productHeroTag]. Only when every product is
  /// shown once on the route.
  final bool heroPackshots;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final columns = productGridColumns(constraints.crossAxisExtent);
        final rows = (products.length + columns - 1) ~/ columns;
        return SliverList.separated(
          itemCount: rows,
          separatorBuilder: (context, index) =>
              const SizedBox(height: BpSpace.s3),
          itemBuilder: (context, row) => _ProductRow(
            products: products,
            start: row * columns,
            columns: columns,
            onTap: onTap,
            onAddToCart: onAddToCart,
            heroPackshots: heroPackshots,
          ),
        );
      },
    );
  }
}

/// Box version of [SliverProductGrid] for non-sliver layouts.
class ProductGrid extends StatelessWidget {
  const ProductGrid({
    super.key,
    required this.products,
    this.onTap,
    this.onAddToCart,
    this.heroPackshots = false,
  });

  /// Products in display order.
  final List<Product> products;

  /// Opens a product.
  final ValueChanged<Product>? onTap;

  /// Adds a product to the cart.
  final ValueChanged<Product>? onAddToCart;

  /// Gives each packshot its [productHeroTag]. Only when every product is
  /// shown once on the route.
  final bool heroPackshots;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = productGridColumns(constraints.maxWidth);
        final rows = (products.length + columns - 1) ~/ columns;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: BpSpace.s3,
          children: <Widget>[
            for (var row = 0; row < rows; row++)
              _ProductRow(
                products: products,
                start: row * columns,
                columns: columns,
                onTap: onTap,
                onAddToCart: onAddToCart,
                heroPackshots: heroPackshots,
              ),
          ],
        );
      },
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.products,
    required this.start,
    required this.columns,
    required this.onTap,
    required this.onAddToCart,
    required this.heroPackshots,
  });

  final List<Product> products;
  final int start;
  final int columns;
  final ValueChanged<Product>? onTap;
  final ValueChanged<Product>? onAddToCart;
  final bool heroPackshots;

  @override
  Widget build(BuildContext context) {
    final tap = onTap;
    final add = onAddToCart;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BpSpace.s3,
        children: <Widget>[
          for (var i = start; i < start + columns; i++)
            Expanded(
              child: i < products.length
                  ? ProductCard(
                      products[i],
                      heroTag: heroPackshots
                          ? productHeroTag(products[i].id)
                          : null,
                      onTap: tap == null ? null : () => tap(products[i]),
                      onAddToCart: add == null ? null : () => add(products[i]),
                    )
                  : const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}
