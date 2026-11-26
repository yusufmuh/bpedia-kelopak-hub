import 'package:flutter/widgets.dart';
import 'package:kelopak_hub/kelopak_hub.dart';

/// Produk demo: nama dan harga dari katalog Bpedia, potret 25 Nov 2026.
const List<(String, String, int)> _rows = <(String, String, int)>[
  ('P39A06S01000021', 'Animate Brightening Facial Wash 100 ml', 17800),
  ('P39A06S01000044', 'Animate Glowing Barrier Day Cream 10 g', 24800),
  ('P39A06S01000089', 'Animate Whitening Day Cream 10 g', 19900),
  ('P39A06S01000003', 'Animate Acne Care Serum 20 ml', 20500),
  ('P39A06S01000007', 'Animate Acne Solution Night Cream 10 g', 26000),
  ('P39A06S01000032', 'Animate Facial Essence 60 Kapsul', 16000),
  ('P39A06S01000046', 'Animate Glowing Barrier Facial Wash 100 ml', 22200),
  ('P39A06S01000090', 'Animate Whitening Facial Serum 20 ml', 20500),
  ('P21F02S01000024', 'Focallure Acne Pimple Patch Fa186 - 1', 10000),
  (
    'P21F02C01000026',
    'Focallure Air Fit Matte Liquid Lipstick Fa417 - 001',
    49091,
  ),
  ('P21F02C01000536', 'Focallure Volumizing Mascara Fa44', 28000),
  ('P21P03C01000082', 'Pinkflash Duo Lipgloss Pf-L13 - D02', 23230),
  ('P21P03C01000149', 'Pinkflash L01 Lasting Matte Lipcream - N01', 11439),
  ('P21P03C01000171', 'Pinkflash L02 Lasting Glossy Lipgloss - G03', 11439),
  (
    'P21P03C01000184',
    'Pinkflash Lasting Matte Loose Pressed Powder - 000',
    37240,
  ),
  ('P21P03C01000189', 'Pinkflash Lasting Moist Lipbalm Pf-L03 - #4', 14000),
  (
    'P21P03M01000068',
    'Pinkflash Double Head Eyeshadow Brush Pf-T04 #02',
    19720,
  ),
  ('P21F02C01000031', 'Focallure Air Fit Matte Liquid Lipstick Or01', 49091),
];

/// Katalog demo untuk `DemoHost`.
final Map<String, KelopakProduct> demoProducts = <String, KelopakProduct>{
  for (final (code, name, price) in _rows)
    code: KelopakProduct(
      code: code,
      name: name,
      price: price,
      image: AssetImage('assets/products/$code.webp'),
    ),
};

/// Misi tahap 1 (demo): Animate skincare.
const List<String> stageOneCodes = <String>[
  'P39A06S01000021',
  'P39A06S01000044',
  'P39A06S01000089',
  'P39A06S01000003',
  'P39A06S01000007',
  'P39A06S01000032',
  'P39A06S01000046',
  'P39A06S01000090',
];

/// Misi tahap 2 (demo): Pinkflash dan Focallure.
const List<String> stageTwoCodes = <String>[
  'P21F02S01000024',
  'P21F02C01000026',
  'P21F02C01000536',
  'P21P03C01000082',
  'P21P03C01000149',
  'P21P03C01000171',
  'P21P03C01000184',
  'P21P03C01000189',
  'P21P03M01000068',
  'P21F02C01000031',
];

/// Kampanye demo, sama dengan `demo_campaign.dart` aplikasi Bpedia. Semua
/// nilai bertanda (demo).
final KelopakCampaign demoCampaign = KelopakCampaign(
  wheelProductCodes: const <String>[
    'P21P03C01000082',
    'P21F02C01000031',
    'P21P03C01000171',
    'P21P03C01000189',
  ],
  missionStages: <MissionStage>[
    for (final stage in KelopakCampaign.demo.missionStages)
      MissionStage(
        number: stage.number,
        minOrderSubtotal: stage.minOrderSubtotal,
        voucherAmount: stage.voucherAmount,
        voucherMinSpend: stage.voucherMinSpend,
        voucherValidDays: stage.voucherValidDays,
        productCodes: stage.number == 1 ? stageOneCodes : stageTwoCodes,
      ),
  ],
  checkIn30ProductCode: 'P39A06S01000089',
  upcomingVouchers: <KelopakVoucherTeaser>[
    KelopakVoucherTeaser(
      promoId: 'tanggal-kembar-1212',
      title: 'Tanggal Kembar 12.12',
      amount: 12000,
      minSpend: 120000,
      opensDay: DateTime.utc(
        2026,
        12,
        12,
      ).difference(DateTime.utc(1970)).inDays,
    ),
  ],
);
