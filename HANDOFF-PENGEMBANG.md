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
| `server/` | Server acuan PHP v3: semua `KelopakAction` + `quote`/`gifts`, token sesi, idempotensi, galat problem+json, swa-uji (`docs/BACKEND.md`) |

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
2. **Rute dan tab Hadiah**: daftarkan `kelopakRoutes` (atau `kelopakRouteFor(location)`) di router app. Semua perpindahan di dalam hub lewat `KelopakNavigation.openPath`; tanpa `KelopakNavigation` hub memakai `Navigator.pushNamed`. Bila `/hadiah` adalah tab bilah bawah, bungkus pohon app dengan `KelopakNavigation(open: (context, location) => router.go(context, parseAppRoute(location)), child: ...)`: `/hadiah` memilih tab Hadiah (tidak menumpuk Zona Hadiah kedua), jalur lain (`/hadiah/checkin`, `/hadiah/voucher`, ...) ditumpuk di atas tab. Pasang `KelopakNavigation` di bawah `KelopakScope` dan di atas navigator agar halaman game dan lembar Cara pakai ikut memakainya.
   Di tab Hadiah, beri kepala aksi host yang sama dengan Beranda: `RewardsHubPage(showBack: false, actions: [notifikasiBerlencana, keranjangBerlencana])`.
3. **Beranda**: `KelopakWalletStrip()` (strip dompet) dan `KelopakGameStrip()` ("Main bareng Bipy").
4. **Pesanan**: di checkout `controller.quote(...)` → `commitOrder(orderId, quote)`; transisi pesanan memanggil `shipOrder`, `completeOrder`, `cancelOrder`. Setelah `completeOrder` yang menerbitkan voucher, tampilkan `showMissionCompleteCelebration(context, voucher: completion.voucher!)` atau pasang `MissionCompleteCelebration` global. Tiap voucher dirayakan sekali (`KelopakController.claimMissionCelebration`): bila halaman Misi Belanja sedang tampil, perayaan halaman itu yang muncul; bila halaman misi tertutup halaman lain, lembar host yang muncul dan halaman misi tidak mengulanginya.
   Tamu boleh menambah produk misi ke keranjang dari halaman Misi (KEPUTUSAN §5); progres dan voucher misi tetap menunggu masuk.
5. **Peristiwa**: petakan `KelopakEvent.analyticsName/parameters` ke analitik dan `notice` ke kotak masuk.
6. **Suara**: `GameCue` dari hub sama nama dengan cue modul; host memetakan ke berkas audio.

Hal yang perlu diingat:
- Tes app yang memakai aset paket ini memuatnya sebagai `packages/kelopak_hub/...` (otomatis). Di tes paket ini sendiri, `test/ui/self_bundle.dart` membuang awalan itu.
- Bila tes gagal memuat aset modul ("Unable to load asset packages/roda_sabtu/..."), hapus `build/unit_test_assets` (cache basi).

## 3. Backend produksi

Ganti `LocalKelopakBackend` dengan `RemoteKelopakBackend(transport: MyTransport(), campaign: ...)`. `KelopakTransport.send(action, body)` mengirim ke `action.method` + `action.path` dan mengembalikan badan JSON `{state, result}`. Endpoint, isi permintaan, dan bentuk `result`: `docs/SPEC-CONTRACT.md` §3. Server wajib mengundi roda sendiri, memakai jam WIB server, menghitung ulang kutipan (tolak `quoteOutdated` bila token tidak cocok), dan mengambil nilai voucher promo dari katalognya sendiri (abaikan `amount`/`minSpend`/`validDays`/`title` dari klien).

Untuk tim backend: kontrak HTTP lengkap (token `Authorization: Bearer`, `Idempotency-Key`, galat `application/problem+json`, kutipan dan token, kampanye, daftar periksa produksi) ada di `docs/BACKEND.md`. Server acuan PHP di `server/` menjalankan kontrak itu dan bisa dipakai sebagai lawan uji:

```bash
php server/selftest.php                                       # swa-uji, wajib 0 gagal
BPEDIA_KELOPAK_DEMO=1 php -S 127.0.0.1:8787 server/index.php  # lawan uji lokal untuk RemoteKelopakBackend
```

Di produksi `shipOrder`/`completeOrder` dipanggil sistem pesanan (header `X-Kelopak-Service-Key`), bukan app.

## 4. Menjalankan contoh

Runner `example/android` dan `example/web` ikut repo.

```bash
cd example
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

- `RemoteKelopakBackend.claimPromoVoucher` masih mengirim `amount`, `minSpend`, `validDays`, `title`; server mengabaikannya (cukup `promoId`).
- Teks putih kecil di hero memakai bayangan tipis (`heroTextShadow`) agar tetap terbaca di bagian paling terang `FestivePalette.hero`.
- Judul bilah `GameScaffold` baru muncul setelah hero tergulir; Zona Hadiah tidak punya judul hero sehingga judul "Zona Hadiah" di bilah baru tampil saat digulir (perlu opsi kit).
- Voucher event "Akan datang" berasal dari `KelopakCampaign.upcomingVouchers` (`KelopakVoucherTeaser`); app mengisinya di konfigurasi kampanye.
- Lisensi paket belum ditetapkan pemilik.
- Nilai kampanye (peluang, kuota, voucher, produk misi) adalah (demo).
