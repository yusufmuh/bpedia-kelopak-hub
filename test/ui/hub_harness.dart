import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelopak_hub/kelopak_hub.dart';
import 'package:roda_sabtu/roda_sabtu.dart' show demoSpinConfig;
import 'package:misi_belanja/misi_belanja.dart' show demoMissionStages;

import 'self_bundle.dart';

/// Produk demo (harga katalog Bpedia, potret 25 Nov 2026).
const List<(String, String, int, int?)>
demoProductRows = <(String, String, int, int?)>[
  ('P39A06S01000021', 'Animate Brightening Facial Wash 100 ml', 17800, null),
  ('P39A06S01000044', 'Animate Glowing Barrier Day Cream 10 g', 24800, null),
  ('P39A06S01000089', 'Animate Whitening Day Cream 10 g', 19900, null),
  ('P39A06S01000003', 'Animate Acne Care Serum 20 ml', 20500, null),
  ('P39A06S01000007', 'Animate Acne Solution Night Cream 10 g', 26000, null),
  ('P39A06S01000032', 'Animate Facial Essence 60 Kapsul', 16000, null),
  (
    'P39A06S01000046',
    'Animate Glowing Barrier Facial Wash 100 ml',
    22200,
    null,
  ),
  ('P39A06S01000090', 'Animate Whitening Facial Serum 20 ml', 20500, null),
  ('P21P03C01000082', 'Pinkflash Duo Lipgloss Pf-L13 - D02', 23230, null),
  (
    'P21F02C01000031',
    'Focallure Air Fit Matte Liquid Lipstick Or01',
    49091,
    null,
  ),
  (
    'P21P03C01000171',
    'Pinkflash L02 Lasting Glossy Lipgloss - G03',
    11439,
    null,
  ),
  (
    'P21P03C01000189',
    'Pinkflash Lasting Moist Lipbalm Pf-L03 - #4',
    14000,
    null,
  ),
];

/// Kode produk misi tahap 1 (demo).
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

/// Kode produk misi tahap 2 (demo: Pinkflash dan Focallure).
const List<String> stageTwoCodes = <String>[
  'P21P03C01000082',
  'P21F02C01000031',
  'P21P03C01000171',
  'P21P03C01000189',
];

/// Katalog demo dengan foto dari `example/assets/products/`.
Map<String, KelopakProduct> demoCatalog() => <String, KelopakProduct>{
  for (final (code, name, price, strike) in demoProductRows)
    code: KelopakProduct(
      code: code,
      name: name,
      price: price,
      strikePrice: strike,
      image: FileImage(File('example/assets/products/$code.webp')),
    ),
};

/// Kampanye mirip `demo_campaign.dart` app.
KelopakCampaign demoCampaign() => KelopakCampaign(
  wheel: demoSpinConfig,
  wheelProductCodes: const <String>[
    'P21P03C01000082',
    'P21F02C01000031',
    'P21P03C01000171',
    'P21P03C01000189',
  ],
  missionStages: <MissionStage>[
    for (final stage in demoMissionStages)
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
);

/// Saat [hour] WIB pada tanggal WIB itu.
DateTime wibAt(int year, int month, int day, {int hour = 10}) =>
    DateTime.utc(year, month, day, hour - 7);

/// [Random] berurutan supaya hasil roda bisa ditebak.
class ScriptedRandom implements Random {
  ScriptedRandom(this.values);

  final List<int> values;
  int _index = 0;

  @override
  int nextInt(int max) => values[_index++ % values.length] % max;

  @override
  double nextDouble() => 0.5;

  @override
  bool nextBool() => false;
}

/// Hub siap uji: controller, host memori, dan jam yang bisa digeser.
class HubFixture {
  HubFixture(this.controller, this.host);

  final KelopakController controller;
  final MemoryKelopakHost host;

  /// Menggeser hari demo dan memberi tahu pendengar.
  void shiftDays(int days) {
    controller.clock.demoOffsetDays += days;
    controller.refreshDay();
  }
}

/// Membuka controller hub dengan jam tetap [now] (bawaan Kamis 26 Nov 2026
/// 10.00 WIB). Panggil dari dalam `tester.runAsync` di tes widget.
Future<HubFixture> openHub({
  bool loggedIn = true,
  DateTime? now,
  List<int> rolls = const <int>[9000],
}) async {
  final host = MemoryKelopakHost(products: demoCatalog(), loggedIn: loggedIn);
  final instant = now ?? wibAt(2026, 11, 26);
  final controller = await KelopakController.open(
    backend: LocalKelopakBackend(
      store: MemoryKeyValueStore(),
      campaign: demoCampaign(),
      random: ScriptedRandom(rolls),
    ),
    clock: WibClock(now: () => instant),
    host: host,
    watchDayChange: false,
  );
  return HubFixture(controller, host);
}

/// Riwayat kaya untuk tangkap layar: 30 hari check-in sejak 27 Okt (hadiah
/// produk hari ke-30), putaran Sabtu (satu produk), satu pesanan misi yang
/// diterima (voucher tahap 1), satu voucher promo, satu pesanan memakai
/// Kelopak. Hari ini Kamis 26 Nov 2026 belum check-in.
Future<HubFixture> openRichHub() async {
  final fixture = await openHub(
    now: wibAt(2026, 10, 26),
    rolls: const <int>[9000, 9000, 100, 9000, 5000],
  );
  final c = fixture.controller;
  final start = c.today;
  for (var day = 0; day < 31; day++) {
    c.clock.demoOffsetDays = day;
    await c.claimCheckIn();
    if (c.isSaturday && c.canSpin) await c.spin();
    if (day == 12) {
      await c.commitOrder(
        'BP-261107-0003',
        c.quote(
          CheckoutRequest(
            lines: const <CheckoutLine>[
              CheckoutLine(
                productCode: 'P21P03C01000171',
                unitPrice: 11439,
                quantity: 1,
              ),
            ],
            shippingFee: 9000,
          ),
        ),
      );
      await c.shipOrder('BP-261107-0003');
      await c.completeOrder('BP-261107-0003');
    }
    if (day == 25) {
      await c.commitOrder(
        'BP-261120-0001',
        c.quote(
          CheckoutRequest(
            lines: const <CheckoutLine>[
              CheckoutLine(
                productCode: 'P39A06S01000007',
                unitPrice: 26000,
                quantity: 2,
              ),
              CheckoutLine(
                productCode: 'P39A06S01000044',
                unitPrice: 24800,
                quantity: 1,
              ),
            ],
            shippingFee: 12000,
            useKelopak: false,
          ),
        ),
      );
      await c.shipOrder('BP-261120-0001');
      await c.completeOrder('BP-261120-0001');
      await c.claimPromoVoucher(
        promoId: 'black-friday',
        amount: 12000,
        minSpend: 120000,
        validDays: 7,
        title: 'Voucher Black Friday',
      );
    }
  }
  c.clock.demoOffsetDays = 31;
  c.refreshDay();
  assert(c.today == start + 31, 'Hari uji harus Kamis 26 Nov 2026');
  return fixture;
}

/// App uji bertema Bpedia dengan rute zona Hadiah.
Widget hubApp(
  HubFixture fixture, {
  Widget? home,
  Brightness brightness = Brightness.light,
  String initialRoute = KelopakPaths.rewards,
  double textScale = 1,
}) {
  return withSelfBundle(
    KelopakScope(
      controller: fixture.controller,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: kelopakPreviewTheme(brightness),
        home: home,
        initialRoute: home == null ? initialRoute : null,
        routes: kelopakRoutes,
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (context) => Scaffold(body: Text('rute ${settings.name}')),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
}
