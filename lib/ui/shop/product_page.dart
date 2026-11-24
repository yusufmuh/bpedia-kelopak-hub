import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:misi_belanja/misi_belanja.dart' show MissionStage;

import '../../core/assets.dart';
import '../../core/format.dart';
import '../../core/tokens.dart';
import '../../data/catalog.dart';
import '../../domain/app_state.dart';
import '../../domain/shop_engine.dart';
import '../shell.dart';
import '../widgets/widgets.dart';
import 'cart_button.dart';
import 'shop_layout.dart';
import 'shop_navigation.dart';

/// Most products listed under "Produk lain".
const int _maxOtherProducts = 8;

/// Product detail: packshot, price, badges, description, the active
/// Misi Belanja goal, other products, and a bar with quantity and
/// "Tambah ke keranjang".
class ProductPage extends StatefulWidget {
  const ProductPage({super.key, required this.productId});

  /// Catalog id of the product.
  final String productId;

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  int _qty = 1;

  void _add(Product product, int qty) {
    addToCartWithFeedback(context, product, qty: qty);
    setState(() => _qty = 1);
  }

  @override
  Widget build(BuildContext context) {
    final product = productById(widget.productId);
    if (product == null) return const _MissingProductPage();
    final app = AppScope.of(context);
    final inCart = app.quantityInCart(product.id);
    final room = cartMaxQty - inCart;
    final maxQty = room < 1 ? 1 : room;
    final qty = _qty.clamp(1, maxQty);
    final others = _otherProducts(product);
    final stage = app.activeMissionStage;
    final large = isLargeText(context);
    final stepper = QuantityStepper(
      value: qty,
      max: maxQty,
      onChanged: room > 0 ? (value) => setState(() => _qty = value) : null,
    );

    const title = 'Detail produk';
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: pageToolbarHeight(
          context,
          title,
          actionsWidth: BpSize.touchTarget + BpSpace.s1,
        ),
        title: const PageTitle(title),
        actions: const <Widget>[
          CartButton(),
          SizedBox(width: BpSpace.s1),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final inset = EdgeInsets.symmetric(
            horizontal: math.max(
              BpSpace.s4,
              (constraints.maxWidth - BpSize.contentMaxWidth) / 2 + BpSpace.s4,
            ),
          );
          // The page (including "Produk lain") comes before the bar's
          // "Tambah ke keranjang" in keyboard order.
          return FocusTraversalGroup(
            child: ListView(
              padding: const EdgeInsets.only(bottom: BpSpace.s8),
              children: <Widget>[
                CenteredWidth(
                  child: _ProductDetails(
                    product: product,
                    inCart: inCart,
                    stage: stage,
                    quantity: large ? stepper : null,
                  ),
                ),
                if (others.isNotEmpty) ...<Widget>[
                  const SizedBox(height: BpSpace.s8),
                  Padding(
                    padding: inset,
                    child: const SectionHeader('Produk lain'),
                  ),
                  const SizedBox(height: BpSpace.s3),
                  ProductCarousel(
                    products: others,
                    padding: inset,
                    onTap: (other) => openProduct(context, other.id),
                    onAddToCart: (other) =>
                        addToCartWithFeedback(context, other),
                  ),
                ],
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: BottomActionBar(
        child: _AddToCartBar(
          stepper: large ? null : stepper,
          canAdd: room > 0,
          onAdd: () => _add(product, qty),
        ),
      ),
    );
  }

  /// Same category first (catalog order), then the rest; never [product].
  static List<Product> _otherProducts(Product product) {
    final sameCategory = <Product>[];
    final rest = <Product>[];
    for (final candidate in demoCatalog) {
      if (candidate.id == product.id) continue;
      (candidate.category == product.category ? sameCategory : rest).add(
        candidate,
      );
    }
    return <Product>[
      ...sameCategory,
      ...rest,
    ].take(_maxOtherProducts).toList(growable: false);
  }
}

class _ProductDetails extends StatelessWidget {
  const _ProductDetails({
    required this.product,
    required this.inCart,
    required this.stage,
    required this.quantity,
  });

  final Product product;
  final int inCart;
  final MissionStage? stage;

  /// Quantity stepper shown in the page (large text) instead of the bar.
  final Widget? quantity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final activeStage = stage;
    final quantityStepper = quantity;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            BpSpace.s4,
            BpSpace.s2,
            BpSpace.s4,
            0,
          ),
          child: Hero(
            tag: productHeroTag(product.id),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(BpRadius.lg),
              child: ColoredBox(
                color: scheme.surfaceContainer,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.asset(
                    product.imageAsset,
                    fit: BoxFit.cover,
                    semanticLabel: 'Foto ilustrasi ${product.name}',
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.image_outlined,
                      size: 48,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            BpSpace.s4,
            BpSpace.s2,
            BpSpace.s4,
            0,
          ),
          child: Semantics(
            container: true,
            child: IconText(
              Icons.photo_camera_outlined,
              'Foto ilustrasi · Mode Demo',
              style: text.labelMedium!.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            BpSpace.s4,
            BpSpace.s4,
            BpSpace.s4,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Brand, name and price as one item; badges as another.
              MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      product.brand,
                      style: text.bodyMedium!.copyWith(
                        color: scheme.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: BpSpace.s1),
                    Text(product.name, style: text.titleLarge),
                    const SizedBox(height: BpSpace.s2),
                    PriceText(product.price, product.strikePrice),
                  ],
                ),
              ),
              const SizedBox(height: BpSpace.s3),
              Semantics(
                container: true,
                child: Wrap(
                  spacing: BpSpace.s2,
                  runSpacing: BpSpace.s2,
                  children: <Widget>[
                    BrandBadge(
                      icon: BrandIcons.original,
                      label: 'Original',
                      foreground: BpColors.of(context).success700,
                      background: BpColors.of(context).success100,
                    ),
                    BrandBadge(
                      icon: BrandIcons.ongkir,
                      label: 'Gratis ongkir (Demo)',
                      foreground: scheme.secondary,
                      background: scheme.primaryContainer,
                    ),
                    if (product.isHot) const HotPill(),
                    if (inCart > 0)
                      StatusPill(
                        Icons.shopping_bag_outlined,
                        '$inCart di keranjang',
                      ),
                  ],
                ),
              ),
              if (quantityStepper != null) ...<Widget>[
                const SizedBox(height: BpSpace.s4),
                Wrap(
                  spacing: BpSpace.s3,
                  runSpacing: BpSpace.s2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Semantics(
                      container: true,
                      child: Text('Jumlah', style: text.titleSmall),
                    ),
                    quantityStepper,
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: BpSpace.s6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: BpSpace.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SectionHeader('Deskripsi'),
              const SizedBox(height: BpSpace.s2),
              Semantics(
                container: true,
                child: Text(
                  '${product.category.label} dari ${product.brand}. '
                  'Nama & harga mengikuti bpedia.id per 24 Nov 2026 untuk '
                  'keperluan demo.',
                  style: text.bodyLarge!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (activeStage != null) ...<Widget>[
          const SizedBox(height: BpSpace.s6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: BpSpace.s4),
            child: _MissionGoalCard(stage: activeStage),
          ),
        ],
      ],
    );
  }
}

/// "Selesaikan pesanan min. Rp75.000, dapat voucher Rp10.000"; opens Misi Belanja.
class _MissionGoalCard extends StatelessWidget {
  const _MissionGoalCard({required this.stage});

  final MissionStage stage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = 'Misi Belanja tahap ${stage.number}';
    final body =
        'Selesaikan pesanan min. ${rupiah(stage.minOrderSubtotal)}, '
        'dapat voucher ${rupiah(stage.voucherAmount)}';
    return Semantics(
      container: true,
      button: true,
      label: '$title. $body',
      hint: 'Buka Misi Belanja',
      child: SoftCard(
        onTap: () => openMissions(context),
        child: ExcludeSemantics(
          child: Row(
            children: <Widget>[
              const IconWell(child: BrandIcon(BrandIcons.voucher, size: 26)),
              const SizedBox(width: BpSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: BpSpace.s2),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddToCartBar extends StatelessWidget {
  const _AddToCartBar({
    required this.stepper,
    required this.canAdd,
    required this.onAdd,
  });

  /// Quantity stepper, or null when it is shown in the page (large text).
  final Widget? stepper;
  final bool canAdd;
  final VoidCallback onAdd;

  /// Width of [QuantityStepper]: two 48 dp buttons, a 32 dp value, a border.
  static const double _stepperWidth = 2 * BpSize.touchTarget + 32 + 2;

  @override
  Widget build(BuildContext context) {
    final label = canAdd
        ? 'Tambah ke keranjang'
        : 'Sudah $cartMaxQty di keranjang';
    final button = FilledButton(
      onPressed: canAdd ? onAdd : null,
      child: Text(label, textAlign: TextAlign.center),
    );
    final quantity = stepper;
    if (quantity == null) return button;
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(
            text: label,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        final labelWidth = painter.width;
        painter.dispose();
        final room =
            constraints.maxWidth - _stepperWidth - BpSpace.s3 - 2 * BpSpace.s6;
        if (labelWidth <= room) {
          return Row(
            children: <Widget>[
              quantity,
              const SizedBox(width: BpSpace.s3),
              Expanded(child: button),
            ],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Jumlah',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                quantity,
              ],
            ),
            const SizedBox(height: BpSpace.s2),
            button,
          ],
        );
      },
    );
  }
}

class _MissingProductPage extends StatelessWidget {
  const _MissingProductPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail produk')),
      body: Center(
        child: SingleChildScrollView(
          child: EmptyState(
            imageAsset: AppImages.bipyNgintip,
            title: 'Produk tidak ditemukan',
            body:
                'Produk ini sudah tidak ada di katalog demo. '
                'Yuk, lihat produk lainnya.',
            actionLabel: 'Kembali ke Beranda',
            onAction: () => ShellScope.of(context).switchTab(ShellTab.home),
          ),
        ),
      ),
    );
  }
}
