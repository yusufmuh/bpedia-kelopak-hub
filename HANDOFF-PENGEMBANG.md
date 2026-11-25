# Handoff Pengembang · kelopak_hub v3

Untuk pengembang Flutter dan backend yang memasang sistem Kelopak (poin, hadiah, tiga game) ke aplikasi Bpedia. Produk: `PRD.md`. Kontrak data dan API: `docs/SPEC-CONTRACT.md`.

## 1. Isi paket

| Folder | Isi |
|---|---|
| `lib/src/core`, `domain`, `storage` | Jam WIB, format, aturan murni Kelopak (`KelopakEngine`, `KelopakView`), kutipan checkout, hadiah menunggu, voucher, dokumen tersimpan + migrasi v2 |
| `lib/src/backend` | `KelopakBackend`, `LocalKelopakBackend`, `RemoteKelopakBackend` + `KelopakTransport` |
| `lib/src/controller`, `host` | `KelopakController`, `KelopakEvent`, `KelopakScope`, `KelopakHost`, `MemoryKelopakHost` |
| `lib/src/games` | `KelopakCheckInController`, `KelopakWheelController`, `KelopakMissionController`, `KelopakGameActions`, layar `Kelopak*Screen` |
| `lib/src/ui` | `RewardsHubPage`, `MyGiftsPage`, `VouchersPage`, `LedgerPage`, lembar Cara pakai, `kelopakRoutes`, `KelopakNavigation`, `HubArt`, `kelopakPreviewTheme` |
| `lib/src/embed` | `KelopakWalletStrip`, `KelopakGameStrip`, `MissionCompleteCelebration` |
| `lib/src/kit`, `lib/kit.dart` | Kit pesta (salinan identik dari `v3/kit_src`; jangan diubah di sini) + `BipySprite` |
| `assets/` | `art/` (seni 3D 512 px), `bipy/` (sprite + pose), `fx/` (stiker) |
| `example/` | App contoh: Beranda tiruan dengan widget tanam, zona Hadiah, tiga game, toko dan keranjang sederhana, panel demo |
| `server/` | Simulator PHP v2 (aksi pesanan v3 belum ada) |

## 2. Memasang di aplikasi

```dart
import 'package:kelopak_hub/kelopak_hub.dart'
    hide CheckoutQuote, CheckoutRequest, v2DocumentKey; // di bpedia_app
import 'package:kelopak_hub/kelopak_hub.dart' as hub;   // tipe yang bentrok

final controller = await KelopakController.open(
  backend: LocalKelopakBackend(store: appStore, campaign: demoCampaign),
  clock: services.clock,          // WibClock bersama, geseran hari Mode Demo
  host: BpediaKelopakHost(...),   // implements KelopakHost, KelopakGameActions
);

KelopakScope(
  controller: controller,
  child: MaterialApp(...),        // scope di atas navigator
);
```

1. **Host**: implementasikan `KelopakHost` (login, katalog `productOf`, keranjang `cartLines`/`addToCart`, `openShop/Cart/Product/Login`, `playCue`, `reminder`, `onEvent`) dan sebaiknya `KelopakGameActions` (`openCheckout`, `openOrder`, `setCartQuantity`, `soundOn`, `setSoundOn`). Beri tahu perubahan login/keranjang lewat `changes`.
2. **Rute**: daftarkan `kelopakRoutes` (atau `kelopakRouteFor(location)`) di router app. Bila `/hadiah` adalah tab, bungkus pohon dengan `KelopakNavigation(open: (context, location) => router.go(context, parseAppRoute(location)), child: ...)` supaya `/hadiah` memilih tab dan jalur lain ditumpuk.
3. **Beranda**: `KelopakWalletStrip()` (strip dompet) dan `KelopakGameStrip()` ("Main bareng Bipy").
4. **Pesanan**: di checkout `controller.quote(...)` → `commitOrder(orderId, quote)`; transisi pesanan memanggil `shipOrder`, `completeOrder`, `cancelOrder`. Setelah `completeOrder` yang menerbitkan voucher, tampilkan `showMissionCompleteCelebration(context, voucher: completion.voucher!)` atau pasang `MissionCompleteCelebration` global.
5. **Peristiwa**: petakan `KelopakEvent.analyticsName/parameters` ke analitik dan `notice` ke kotak masuk.
6. **Suara**: `GameCue` dari hub sama nama dengan cue modul; host memetakan ke berkas audio.

Hal yang perlu diingat:
- Tes app yang memakai aset paket ini memuatnya sebagai `packages/kelopak_hub/...` (otomatis). Di tes paket ini sendiri, `test/ui/self_bundle.dart` membuang awalan itu.
- Bila tes gagal memuat aset modul ("Unable to load asset packages/roda_sabtu/..."), hapus `build/unit_test_assets` (cache basi).

## 3. Backend produksi

Ganti `LocalKelopakBackend` dengan `RemoteKelopakBackend(transport: MyTransport(), campaign: ...)`. `KelopakTransport.send(action, body)` mengirim ke `action.method` + `action.path` dan mengembalikan badan JSON `{state, result}`. Endpoint, isi permintaan, dan bentuk `result`: `docs/SPEC-CONTRACT.md` §3. Server wajib mengundi roda sendiri, memakai jam WIB server, dan menghitung ulang kutipan (tolak `quoteOutdated` bila token tidak cocok).

## 4. Menjalankan contoh

```bash
cd example
flutter create --platforms=web,android .   # sekali, membuat runner (tidak dibawa repo)
flutter run -d chrome
```

Panel demo (ikon setel di Beranda contoh): masuk/tamu, tema gelap, kurangi gerak, promo roda, +1/+7 hari, ke Sabtu, isi 50 Kelopak, kuota roda penuh, daftar pesanan (kirim, diterima, batal), atur ulang, catatan suara dan peristiwa.

## 5. Gerbang mutu

```bash
flutter analyze                                   # paket + example, 0 isu
flutter test --concurrency=3                      # semua tes
flutter test --concurrency=3 test/shots           # tangkap layar ke build/shots/
cd example && flutter test
```

Tes UI ada di `test/ui/` (controller game, halaman, widget tanam, aksesibilitas); data uji kaya `openRichHub()` di `test/ui/hub_harness.dart`.

## 6. Catatan terbuka

- Aksi pesanan v3 di `server/*.php` belum dibuat.
- Kontras teks putih kecil di bagian paling terang hero pesta perlu dinilai bersama kit (`FestivePalette.hero`).
- Nilai kampanye (peluang, kuota, voucher, produk misi) adalah (demo).
