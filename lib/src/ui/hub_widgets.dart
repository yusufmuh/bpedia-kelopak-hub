/// Komponen bersama halaman zona Hadiah: kepala seksi, keadaan kosong,
/// tiket voucher, baris riwayat, dan kartu hadiah.
library;

import 'package:daily_checkin/daily_checkin.dart' show wibDateOf;
import 'package:flutter/material.dart';

import '../core/format.dart';
import '../controller/kelopak_scope.dart';
import '../domain/campaign.dart';
import '../domain/gifts.dart';
import '../domain/ledger.dart';
import '../domain/voucher.dart';
import '../host/kelopak_host.dart';
import '../kit/kit.dart';
import 'hub_art.dart';

/// Warna turunan tema host untuk halaman hub.
@immutable
final class HubTones {
  const HubTones._(this.scheme);

  /// Warna dari tema [context].
  factory HubTones.of(BuildContext context) =>
      HubTones._(Theme.of(context).colorScheme);

  /// Skema warna host.
  final ColorScheme scheme;

  /// Apakah tema gelap.
  bool get dark => scheme.brightness == Brightness.dark;

  /// Latar halaman (celah antarseksi).
  Color get canvas => scheme.surfaceDim;

  /// Permukaan seksi dan kartu.
  Color get surface => scheme.surface;

  /// Permukaan redup (kerangka gambar, chip netral).
  Color get muted => scheme.surfaceContainerHighest;

  /// Garis 1 px.
  Color get line => scheme.outlineVariant;

  /// Teks utama.
  Color get text => scheme.onSurface;

  /// Teks sekunder.
  Color get textMuted => scheme.onSurfaceVariant;

  /// Teks samar.
  Color get textFaint => scheme.outline;

  /// Warna merek (tombol, tautan).
  Color get brand => scheme.primary;

  /// Teks aksen merek (harga, angka penting).
  Color get brandStrong => scheme.onPrimaryContainer;

  /// Latar lembut merek.
  Color get brandTint => scheme.primaryContainer;

  /// Garis merek lembut (tepi kupon, chip aktif).
  Color get brandLine =>
      dark ? const Color(0xFF5A1A36) : const Color(0xFFF7C6D4);

  /// Latar lembut emas.
  Color get goldTint => scheme.tertiaryContainer;

  /// Teks di atas [goldTint].
  Color get onGoldTint => scheme.onTertiaryContainer;

  /// Hijau berhasil (kredit Kelopak).
  Color get success => dark ? const Color(0xFF5FD3A0) : const Color(0xFF1E7A55);

  /// Latar hijau lembut.
  Color get successTint =>
      dark ? const Color(0xFF12301F) : const Color(0xFFE9F7F0);

  /// Merah galat.
  Color get danger => scheme.error;
}

/// "27 Nov 2026" untuk hari WIB [wibDay].
String wibShortDate(int wibDay) =>
    '${shortDateLabel(wibDay)} ${wibDateOf(wibDay).year}';

/// Gaya angka uang dan saldo (angka tabular).
const List<FontFeature> tabularFigures = <FontFeature>[
  FontFeature.tabularFigures(),
];

/// Judul seksi dengan tautan "Lihat semua" di kanan.
class HubSectionHeader extends StatelessWidget {
  /// Membuat kepala seksi.
  const HubSectionHeader({
    super.key,
    required this.title,
    this.art,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 8, 8),
  });

  /// Judul seksi.
  final String title;

  /// Seni kecil di kiri judul.
  final ImageProvider? art;

  /// Label tautan kanan.
  final String? actionLabel;

  /// Aksi tautan kanan.
  final VoidCallback? onAction;

  /// Jarak luar.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final tones = HubTones.of(context);
    final label = actionLabel;
    final art = this.art;
    return Padding(
      padding: padding,
      child: Row(
        children: <Widget>[
          if (art != null) ...<Widget>[
            Image(image: art, width: 26, height: 26),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  height: 22 / 16,
                  fontWeight: FontWeight.w700,
                  color: tones.text,
                ),
              ),
            ),
          ),
          if (label != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: tones.brand,
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(label),
                  const Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Keadaan kosong: pose Bipy, judul, isi, dan satu aksi.
class HubEmptyState extends StatelessWidget {
  /// Membuat keadaan kosong.
  const HubEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.image = HubArt.bipyHost,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  /// Judul.
  final String title;

  /// Penjelasan singkat.
  final String message;

  /// Gambar (bawaan Bipy melambai).
  final ImageProvider image;

  /// Label tombol.
  final String? actionLabel;

  /// Aksi tombol.
  final VoidCallback? onAction;

  /// Versi baris (di dalam seksi), bukan halaman penuh.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tones = HubTones.of(context);
    final label = actionLabel;
    final titleStyle = TextStyle(
      fontSize: compact ? 14 : 16,
      fontWeight: FontWeight.w700,
      color: tones.text,
    );
    final bodyStyle = TextStyle(
      fontSize: 13,
      height: 18 / 13,
      color: tones.textMuted,
    );
    if (compact) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tones.muted,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: <Widget>[
                Bobbing(
                  amplitude: 3,
                  child: Image(image: image, width: 48, height: 48),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: titleStyle),
                      const SizedBox(height: 2),
                      Text(message, style: bodyStyle),
                      if (label != null && onAction != null)
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton(
                            onPressed: onAction,
                            style: TextButton.styleFrom(
                              foregroundColor: tones.brand,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(48, 40),
                            ),
                            child: Text(
                              label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Bobbing(amplitude: 5, child: Image(image: image, height: 150)),
          const SizedBox(height: 16),
          Text(title, style: titleStyle, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(message, style: bodyStyle, textAlign: TextAlign.center),
          if (label != null && onAction != null) ...<Widget>[
            const SizedBox(height: 20),
            CandyButton(
              label: label,
              expand: false,
              height: 48,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}

/// Status tampil sebuah voucher.
enum VoucherTicketState {
  /// Bisa dipakai.
  usable,

  /// Sudah dipakai di sebuah pesanan.
  used,

  /// Lewat masa berlaku.
  expired,
}

/// Voucher berbentuk tiket: stub "Diskon" bernilai besar, garis putus,
/// nama sumber, syarat, sisa hari, masa berlaku, dan tombol "Pakai".
class VoucherTicket extends StatelessWidget {
  /// Membuat tiket [voucher].
  const VoucherTicket({
    super.key,
    required this.voucher,
    required this.state,
    this.onUse,
    this.today,
  });

  /// Voucher yang ditampilkan.
  final KelopakVoucher voucher;

  /// Bisa dipakai, terpakai, atau kedaluwarsa.
  final VoucherTicketState state;

  /// Aksi "Pakai".
  final VoidCallback? onUse;

  /// Hari WIB acuan "Sisa N hari". Null: hari `KelopakScope` terdekat, atau
  /// baris sisa hari disembunyikan bila tidak ada scope.
  final int? today;

  /// Batas hari yang membuat "Sisa N hari" tampil.
  static const int remainingDaysShown = 30;

  @override
  Widget build(BuildContext context) {
    final active = state == VoucherTicketState.usable;
    final origin = voucher.kind == VoucherKind.mission
        ? 'Voucher Misi Belanja tahap ${voucher.stageNumber ?? 1}'
        : voucher.title;
    final day = today ?? KelopakScope.maybeRead(context)?.today;
    final left = day == null ? null : voucher.expiresDay - day + 1;
    final String validity = switch (state) {
      VoucherTicketState.usable =>
        'Berlaku s.d. ${wibShortDate(voucher.expiresDay)}',
      VoucherTicketState.used => 'Sudah dipakai',
      VoucherTicketState.expired =>
        'Berakhir ${wibShortDate(voucher.expiresDay)}',
    };
    final remaining = active && left != null && left <= remainingDaysShown
        ? (left <= 1 ? 'Berakhir hari ini' : 'Sisa $left hari')
        : null;
    return _VoucherTicketLayout(
      active: active,
      amount: voucher.amount,
      title: origin,
      minSpend: voucher.minSpend,
      highlight: remaining,
      footnote: validity,
      semanticPrefix: 'Voucher diskon',
      trailing: active && onUse != null
          ? _SmallPill(label: 'Pakai', onTap: onUse!)
          : _StatusTag(
              label: state == VoucherTicketState.used
                  ? 'Terpakai'
                  : state == VoucherTicketState.expired
                  ? 'Berakhir'
                  : 'Siap',
            ),
    );
  }
}

/// Tiket voucher event yang belum dibuka ("Akan datang"): redup, aksi
/// "Segera", dan tanggal mulai klaim.
class VoucherTeaserTicket extends StatelessWidget {
  /// Membuat tiket [teaser].
  const VoucherTeaserTicket({super.key, required this.teaser});

  /// Voucher event yang diumumkan.
  final KelopakVoucherTeaser teaser;

  @override
  Widget build(BuildContext context) {
    return _VoucherTicketLayout(
      active: false,
      amount: teaser.amount,
      title: teaser.title,
      minSpend: teaser.minSpend,
      footnote: 'Klaim mulai ${wibShortDate(teaser.opensDay)}',
      semanticPrefix: 'Voucher akan datang, diskon',
      trailing: const _StatusTag(label: 'Segera'),
    );
  }
}

class _VoucherTicketLayout extends StatelessWidget {
  const _VoucherTicketLayout({
    required this.active,
    required this.amount,
    required this.title,
    required this.minSpend,
    required this.footnote,
    required this.semanticPrefix,
    required this.trailing,
    this.highlight,
  });

  /// Bisa dipakai (berwarna) atau redup.
  final bool active;

  /// Potongan rupiah.
  final int amount;

  /// Nama sumber voucher.
  final String title;

  /// Minimal belanja.
  final int minSpend;

  /// Baris amber ("Sisa 20 hari"), opsional.
  final String? highlight;

  /// Baris terakhir ("Berlaku s.d. ...").
  final String footnote;

  /// Awal label pembaca layar.
  final String semanticPrefix;

  /// Tombol atau label status di kanan.
  final Widget trailing;

  static const double _stubWidth = 104;

  @override
  Widget build(BuildContext context) {
    final tones = HubTones.of(context);
    final stubColor = active ? tones.brandTint : tones.muted;
    final accent = active ? tones.brandStrong : tones.textMuted;
    final highlight = this.highlight;
    return Semantics(
      container: true,
      label:
          '$semanticPrefix ${rupiah(amount)}, $title, min. belanja '
          '${rupiah(minSpend)}. ${highlight == null ? '' : '$highlight. '}'
          '$footnote',
      child: CustomPaint(
        painter: _TicketPainter(
          stubWidth: _stubWidth,
          stubColor: stubColor,
          bodyColor: tones.surface,
          border: active ? tones.brandLine : tones.line,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                width: _stubWidth,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        'Diskon',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          rupiah(amount),
                          style: TextStyle(
                            fontSize: 22,
                            height: 28 / 22,
                            fontWeight: FontWeight.w800,
                            color: accent,
                            fontFeatures: tabularFigures,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                height: 19 / 14,
                                fontWeight: FontWeight.w600,
                                color: active ? tones.text : tones.textMuted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Min. belanja ${rupiah(minSpend)}',
                              style: TextStyle(
                                fontSize: 12,
                                height: 16 / 12,
                                color: tones.textMuted,
                                fontFeatures: tabularFigures,
                              ),
                            ),
                            if (highlight != null)
                              Text(
                                highlight,
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 15 / 11,
                                  fontWeight: FontWeight.w700,
                                  color: tones.onGoldTint,
                                ),
                              ),
                            Text(
                              footnote,
                              style: TextStyle(
                                fontSize: 11,
                                height: 15 / 11,
                                color: tones.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      trailing,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketPainter extends CustomPainter {
  const _TicketPainter({
    required this.stubWidth,
    required this.stubColor,
    required this.bodyColor,
    required this.border,
  });

  final double stubWidth;
  final Color stubColor;
  final Color bodyColor;
  final Color border;

  static const double _radius = 10;
  static const double _notch = 7;

  Path _outline(Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(_radius),
    );
    final notches = Path()
      ..addOval(Rect.fromCircle(center: Offset(stubWidth, 0), radius: _notch))
      ..addOval(
        Rect.fromCircle(center: Offset(stubWidth, size.height), radius: _notch),
      );
    return Path.combine(
      PathOperation.difference,
      Path()..addRRect(rect),
      notches,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final outline = _outline(size);
    canvas
      ..save()
      ..clipPath(outline)
      ..drawRect(Offset.zero & size, Paint()..color = bodyColor)
      ..drawRect(
        Rect.fromLTWH(0, 0, stubWidth, size.height),
        Paint()..color = stubColor,
      )
      ..restore();
    canvas.drawPath(
      outline,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final dash = Paint()
      ..color = border
      ..strokeWidth = 1.2;
    for (var y = _notch + 4; y < size.height - _notch - 4; y += 7) {
      canvas.drawLine(
        Offset(stubWidth, y),
        Offset(stubWidth, (y + 3.5).clamp(0, size.height - _notch - 4)),
        dash,
      );
    }
  }

  @override
  bool shouldRepaint(_TicketPainter oldDelegate) =>
      oldDelegate.stubWidth != stubWidth ||
      oldDelegate.stubColor != stubColor ||
      oldDelegate.bodyColor != bodyColor ||
      oldDelegate.border != border;
}

class _SmallPill extends StatelessWidget {
  const _SmallPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tones = HubTones.of(context);
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: tones.brand,
        foregroundColor: tones.scheme.onPrimary,
        minimumSize: const Size(64, 36),
        tapTargetSize: MaterialTapTargetSize.padded,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: const StadiumBorder(),
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Text(label),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tones = HubTones.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tones.muted,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: tones.textMuted,
          ),
        ),
      ),
    );
  }
}

/// Seni 3D untuk sumber entri buku besar.
ImageProvider ledgerArt(LedgerKind kind) => switch (kind) {
  LedgerKind.checkIn || LedgerKind.checkInBonus => HubArt.calendar,
  LedgerKind.spinPrize => HubArt.wheel,
  LedgerKind.checkoutSpend || LedgerKind.checkoutRefund => HubArt.bag,
  LedgerKind.demoGrant => HubArt.coin,
};

/// Satu baris riwayat Kelopak: seni sumber, keterangan, tanggal, jumlah.
class LedgerTile extends StatelessWidget {
  /// Membuat baris [line].
  const LedgerTile({super.key, required this.line, this.showBalance = false});

  /// Baris buku besar dengan saldo berjalan.
  final LedgerLine line;

  /// Tampilkan saldo setelah entri ini.
  final bool showBalance;

  @override
  Widget build(BuildContext context) {
    final tones = HubTones.of(context);
    final entry = line.entry;
    final credit = entry.isCredit;
    final note = entry.note.trim();
    final title = note.isEmpty ? entry.kind.label : note;
    final orderId = entry.orderId;
    final sub = <String>[
      wibDateLabel(entry.wibDay),
      if (orderId != null && !title.contains(orderId)) 'Pesanan #$orderId',
    ].join(' · ');
    return Semantics(
      container: true,
      label:
          '${entry.kind.label}, ${signedKelopakLabel(entry.amount)}, '
          '${wibDateLabel(entry.wibDay)}',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: <Widget>[
              LedgerArtTile(image: ledgerArt(entry.kind)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: tones.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      style: TextStyle(fontSize: 12, color: tones.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        credit
                            ? '+${groupThousands(entry.amount)}'
                            : '−${groupThousands(-entry.amount)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: credit ? tones.success : tones.danger,
                          fontFeatures: tabularFigures,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Image(image: HubArt.coin, width: 14, height: 14),
                    ],
                  ),
                  if (showBalance)
                    Text(
                      'Saldo ${groupThousands(line.balanceAfter)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: tones.textFaint,
                        fontFeatures: tabularFigures,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kotak seni 40 dp berlatar redup untuk baris riwayat.
class LedgerArtTile extends StatelessWidget {
  /// Membuat kotak berisi [image].
  const LedgerArtTile({super.key, required this.image});

  /// Seni 3D sumber entri.
  final ImageProvider image;

  @override
  Widget build(BuildContext context) {
    final tones = HubTones.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tones.muted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Image(image: image, width: 30, height: 30),
      ),
    );
  }
}

/// Baris riwayat untuk hadiah produk (bukan Kelopak): sumber, tanggal, dan
/// lencana "Hadiah produk".
class GiftLedgerTile extends StatelessWidget {
  /// Membuat baris [gift].
  const GiftLedgerTile({super.key, required this.gift});

  /// Hadiah produk.
  final PendingGift gift;

  @override
  Widget build(BuildContext context) {
    final tones = HubTones.of(context);
    final title = '${gift.source.label}: produk gratis';
    return Semantics(
      container: true,
      label: '$title, hadiah produk, ${wibDateLabel(gift.wonDay)}',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: <Widget>[
              LedgerArtTile(
                image: gift.source == GiftSource.wheel
                    ? HubArt.wheel
                    : HubArt.calendar,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: tones.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      wibDateLabel(gift.wonDay),
                      style: TextStyle(fontSize: 12, color: tones.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: tones.goldTint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    'Hadiah produk',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: tones.onGoldTint,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Foto produk hadiah dengan kerangka saat gambar tidak ada.
class GiftProductImage extends StatelessWidget {
  /// Membuat gambar [product] berukuran [size].
  const GiftProductImage({super.key, required this.product, this.size = 72});

  /// Produk; null memakai seni kado.
  final KelopakProduct? product;

  /// Sisi gambar.
  final double size;

  @override
  Widget build(BuildContext context) {
    final tones = HubTones.of(context);
    final image = product?.image;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: ColoredBox(
        color: tones.muted,
        child: SizedBox.square(
          dimension: size,
          child: image == null
              ? Padding(
                  padding: EdgeInsets.all(size * 0.14),
                  child: const Image(image: HubArt.gift),
                )
              : Image(
                  image: image,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Padding(
                    padding: EdgeInsets.all(size * 0.14),
                    child: const Image(image: HubArt.gift),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Pita kecil "Ikut pesanan berikutnya" dan kawan-kawan.
class GiftStatusChip extends StatelessWidget {
  /// Membuat chip status [status].
  const GiftStatusChip({super.key, required this.status});

  /// Status hadiah.
  final GiftStatus status;

  @override
  Widget build(BuildContext context) {
    final tones = HubTones.of(context);
    final (Color bg, Color fg, String label) = switch (status) {
      GiftStatus.pending => (
        tones.goldTint,
        tones.onGoldTint,
        'Ikut pesanan berikutnya',
      ),
      GiftStatus.attached => (tones.brandTint, tones.brandStrong, status.label),
      GiftStatus.shipped => (tones.muted, tones.textMuted, 'Sedang dikirim'),
      GiftStatus.received => (tones.successTint, tones.success, status.label),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            height: 14 / 11,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }
}

/// Titik merah "bisa diklaim".
class ReadyDot extends StatelessWidget {
  /// Membuat titik berdiameter [size].
  const ReadyDot({super.key, this.size = 10});

  /// Diameter.
  final double size;

  @override
  Widget build(BuildContext context) {
    final tones = HubTones.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tones.dark ? const Color(0xFFFF5C7A) : const Color(0xFFE5173F),
        shape: BoxShape.circle,
        border: Border.all(color: tones.surface, width: 1.5),
      ),
    );
  }
}
