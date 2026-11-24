import 'package:flutter/material.dart';

import '../../core/assets.dart';
import '../../core/tokens.dart';
import '../../data/catalog.dart';
import '../widgets/widgets.dart';
import 'cart_button.dart';
import 'shop_layout.dart';
import 'shop_navigation.dart';

/// Product search with category filters. Results update while typing.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.initialQuery, this.category});

  /// Text already in the search field.
  final String? initialQuery;

  /// Category already selected.
  final ProductCategory? category;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final TextEditingController _query = TextEditingController(
    text: widget.initialQuery ?? '',
  );
  late ProductCategory? _category = widget.category;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _reset() {
    _query.clear();
    setState(() => _category = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final category = _category;
    final results = search(_query.text)
        .where((product) => category == null || product.category == category)
        .toList(growable: false);
    final autofocus =
        widget.category == null && (widget.initialQuery ?? '').isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cari produk'),
        actions: const <Widget>[
          CartButton(),
          SizedBox(width: BpSpace.s1),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final pad = browsePadding(constraints.maxWidth);
          return CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: <Widget>[
              SliverPadding(
                padding: EdgeInsets.fromLTRB(pad, BpSpace.s2, pad, 0),
                sliver: SliverToBoxAdapter(
                  child: TextField(
                    controller: _query,
                    autofocus: autofocus,
                    textInputAction: TextInputAction.search,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => FocusScope.of(context).unfocus(),
                    decoration: InputDecoration(
                      hintText: 'Cari skincare, makeup, lashes…',
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(BpSpace.s3),
                        child: BrandIcon(
                          BrandIcons.mono(BrandIcons.search),
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      suffixIcon: _query.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Hapus teks',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => setState(_query.clear),
                            ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.only(top: BpSpace.s3),
                sliver: SliverToBoxAdapter(
                  child: _CategoryFilter(
                    selected: category,
                    padding: pad,
                    onChanged: (value) => setState(() => _category = value),
                  ),
                ),
              ),
              if (results.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: EmptyState(
                      imageAsset: AppImages.bipyNgintip,
                      title: 'Produk tidak ditemukan',
                      body: category == null
                          ? 'Coba kata lain, misalnya "serum" atau "sunscreen".'
                          : 'Belum ada yang cocok di ${category.label}. '
                                'Coba kata lain atau lihat semua kategori.',
                      actionLabel: 'Reset pencarian',
                      onAction: _reset,
                    ),
                  ),
                )
              else ...<Widget>[
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    pad,
                    BpSpace.s4,
                    pad,
                    BpSpace.s3,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        '${results.length} produk',
                        style: theme.textTheme.bodyMedium!.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(pad, 0, pad, BpSpace.s8),
                  sliver: SliverProductGrid(
                    products: results,
                    heroPackshots: true,
                    onTap: (product) => openProduct(context, product.id),
                    onAddToCart: (product) =>
                        addToCartWithFeedback(context, product),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter({
    required this.selected,
    required this.padding,
    required this.onChanged,
  });

  final ProductCategory? selected;
  final double padding;
  final ValueChanged<ProductCategory?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: padding),
      child: Row(
        spacing: BpSpace.s2,
        children: <Widget>[
          FilterChip(
            label: const Text('Semua'),
            selected: selected == null,
            onSelected: (_) => onChanged(null),
          ),
          for (final category in ProductCategory.values)
            FilterChip(
              avatar: BrandIcon(category.iconName, size: 18),
              label: Text(category.label),
              selected: selected == category,
              onSelected: (isSelected) =>
                  onChanged(isSelected ? category : null),
            ),
        ],
      ),
    );
  }
}
