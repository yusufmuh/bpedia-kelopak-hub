import 'package:flutter/material.dart';

import '../../core/assets.dart';
import '../../core/tokens.dart';
import '../../data/catalog.dart';
import '../shell.dart';
import '../shop/cart_button.dart';
import '../shop/shop_layout.dart';
import '../shop/shop_navigation.dart';
import '../widgets/widgets.dart';
import 'game_tiles.dart';
import 'kelopak_today_card.dart';

/// Beranda: search, today's Kelopak, "Main bareng Bipy", categories,
/// Hot Item and every product. No pop-ups; one primary action at most
/// (the check-in button while today's Kelopak is waiting).
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final pad = browsePadding(constraints.maxWidth);
          final inset = EdgeInsets.symmetric(horizontal: pad);

          Widget block(Widget child, {double top = BpSpace.s8}) =>
              SliverPadding(
                padding: inset.copyWith(top: top),
                sliver: SliverToBoxAdapter(child: child),
              );

          return CustomScrollView(
            slivers: <Widget>[
              SliverAppBar(
                pinned: true,
                titleSpacing: pad,
                title: const _HomeLogo(),
                actions: <Widget>[
                  const CartButton(),
                  SizedBox(width: pad - BpSpace.s3),
                ],
              ),
              block(const _SearchEntry(), top: BpSpace.s2),
              block(const KelopakTodayCard(), top: BpSpace.s4),
              block(
                SectionHeader(
                  'Main bareng Bipy',
                  actionLabel: 'Semua hadiah',
                  onAction: () =>
                      ShellScope.of(context).switchTab(ShellTab.rewards),
                ),
              ),
              block(const GameTiles(), top: BpSpace.s3),
              block(const SectionHeader('Kategori')),
              SliverPadding(
                padding: const EdgeInsets.only(top: BpSpace.s3),
                sliver: SliverToBoxAdapter(
                  child: _CategoryChips(padding: inset),
                ),
              ),
              block(const SectionHeader('Hot Item')),
              SliverPadding(
                padding: const EdgeInsets.only(top: BpSpace.s3),
                sliver: SliverToBoxAdapter(
                  child: ProductCarousel(
                    products: hotProducts,
                    padding: inset,
                    onTap: (product) => openProduct(context, product.id),
                    onAddToCart: (product) =>
                        addToCartWithFeedback(context, product),
                  ),
                ),
              ),
              block(const SectionHeader('Produk')),
              SliverPadding(
                padding: inset.copyWith(top: BpSpace.s3, bottom: BpSpace.s8),
                sliver: SliverProductGrid(
                  products: _gridProducts,
                  heroPackshots: true,
                  onTap: (product) => openProduct(context, product.id),
                  onAddToCart: (product) =>
                      addToCartWithFeedback(context, product),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Every product, with the Hot Items last so the grid does not open with
/// the same cards as the carousel right above it.
final List<Product> _gridProducts = List<Product>.unmodifiable(<Product>[
  ...demoCatalog.where((product) => !product.isHot),
  ...demoCatalog.where((product) => product.isHot),
]);

/// Wordmark with Bipy (reverse version on Berry Night).
class _HomeLogo extends StatelessWidget {
  const _HomeLogo();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Image.asset(
      dark ? AppImages.logoWordmarkReverse : AppImages.logoWordmarkBipy,
      height: 32,
      fit: BoxFit.contain,
      semanticLabel: 'Bpedia',
      errorBuilder: (context, error, stackTrace) => Text(
        'Bpedia',
        style: Theme.of(context).textTheme.titleLarge!.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Looks like a search field; opens the search page.
class _SearchEntry extends StatelessWidget {
  const _SearchEntry();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(BpRadius.md),
      side: BorderSide(color: scheme.outlineVariant),
    );
    // The InkWell gives this node its tap action and keyboard focus; only
    // the look-alike field text is hidden from screen readers.
    return Semantics(
      container: true,
      button: true,
      label: 'Cari produk',
      child: Material(
        color: scheme.surfaceContainerLowest,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openSearch(context),
          child: ExcludeSemantics(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: BpSpace.s4,
                  vertical: BpSpace.s3,
                ),
                child: Row(
                  children: <Widget>[
                    BrandIcon(
                      BrandIcons.mono(BrandIcons.search),
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: BpSpace.s3),
                    Expanded(
                      child: Text(
                        'Cari skincare, makeup, lashes…',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge!.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Category pills with brand icons; each opens search filtered to it.
///
/// They navigate, so they are buttons (named by their label) styled like the
/// brand's inactive chip, not chips: a chip reads as an unchecked checkbox.
class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.padding});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = OutlinedButton.styleFrom(
      minimumSize: const Size(0, BpSize.touchTarget),
      padding: const EdgeInsets.symmetric(horizontal: BpSpace.s3),
      foregroundColor: scheme.onSurface,
      side: BorderSide(color: scheme.outlineVariant),
      textStyle: theme.textTheme.bodyMedium!.copyWith(
        fontWeight: FontWeight.w500,
      ),
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        spacing: BpSpace.s2,
        children: <Widget>[
          for (final category in ProductCategory.values)
            OutlinedButton.icon(
              style: style,
              onPressed: () => openSearch(context, category: category),
              icon: BrandIcon(category.iconName, size: 18),
              label: Text(category.label),
            ),
        ],
      ),
    );
  }
}
