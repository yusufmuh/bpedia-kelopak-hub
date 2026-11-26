# kelopak_hub · sistem Kelopak dan zona Hadiah (Bpedia Demo v3)

Paket Flutter murni (tanpa plugin) untuk poin **Kelopak** Bpedia (1 Kelopak = Rp100) dan tiga game hadiahnya:

- **Check-in Harian**: +1 Kelopak per hari WIB, bonus +3 tiap hari ke-7 beruntun, produk gratis di hari ke-30.
- **Roda Sabtu**: 1 putaran gratis tiap Sabtu WIB; hadiah produk (kuota) atau Kelopak, peluang tampil sebelum memutar.
- **Misi Belanja**: belanja produk misi dalam satu pesanan yang diterima, dapat voucher untuk pesanan berikutnya; bertahap.

Isi paket: mesin aturan, buku besar, kutipan checkout (Kelopak memotong harga, K16), hadiah menunggu yang ikut pesanan berikutnya (K17), backend lokal + kontrak server, **zona Hadiah** (`/hadiah/*`), controller sungguhan untuk halaman tiga modul game, dan widget tanam untuk Beranda aplikasi. Dipakai oleh `bpedia-app`.

| | |
|---|---|
| Versi | 3.0.0 |
| Dependensi | Flutter SDK, `daily_checkin`, `roda_sabtu`, `misi_belanja` (ikut terpasang otomatis) |
| Lisensi | Belum ditetapkan pemilik (Muhammad Yusuf, Bpedia); belum boleh dipakai di luar proyek Bpedia |
| Flutter | 3.41.7 / Dart 3.11.5 |

## Tangkapan layar

| Zona Hadiah (terang) | Zona Hadiah (gelap) | Widget tanam Beranda |
|---|---|---|
| ![](docs/shots/hub_terang.jpg) | ![](docs/shots/hub_gelap.jpg) | ![](docs/shots/tanam_terang.jpg) |

| Hadiahku | Voucherku | Riwayat Kelopak | Misi tuntas |
|---|---|---|---|
| ![](docs/shots/hadiahku_terang.jpg) | ![](docs/shots/voucher_terang.jpg) | ![](docs/shots/riwayat_gelap.jpg) | ![](docs/shots/perayaan_misi_terang.jpg) |

Semua tangkapan dibuat ulang dengan `flutter test test/shots` (PNG di `build/shots/`, terang dan gelap).

## Pasang

Tambahkan ke `pubspec.yaml` aplikasi:

```yaml
dependencies:
  kelopak_hub:
    git:
      url: https://github.com/yusufmuh/bpedia-kelopak-hub.git
      ref: v3.0.0
```

Ketiga modul game (`daily_checkin`, `roda_sabtu`, `misi_belanja`) ikut terpasang sebagai dependensi hub; aplikasi tidak perlu mendaftarkannya sendiri. Selama pengembangan lokal (lima repo bersebelahan di satu folder) hub memakai dependensi `path:` ke modul.

Urutan rilis v3.0.0 (dikerjakan pemilik rilis):

1. Tag `v3.0.0` di `bpedia-daily-checkin`, `bpedia-roda-sabtu`, `bpedia-misi-belanja`.
2. Ganti tiga dependensi `path:` di `pubspec.yaml` hub menjadi `git:` (url repo modul, `ref: v3.0.0`); simpan varian `path:` untuk kerja lokal di `pubspec_overrides.yaml` yang tidak di-commit. Jalankan `flutter pub get` dan gerbang mutu.
3. Tag `v3.0.0` di hub.
4. Ganti dependensi hub di `bpedia-app` ke `git:` `ref: v3.0.0`, `flutter pub get`, uji, lalu rilis app.

## Pakai

```dart
import 'package:kelopak_hub/kelopak_hub.dart';

final controller = await KelopakController.open(
  backend: LocalKelopakBackend(store: MemoryKeyValueStore(), campaign: myCampaign),
  host: myHost, // implements KelopakHost (+ KelopakGameActions opsional)
);

runApp(KelopakScope(
  controller: controller,
  child: MaterialApp(
    routes: kelopakRoutes, // /hadiah, /hadiah/checkin, /hadiah/roda, /hadiah/misi, /hadiah/hadiahku, /hadiah/voucher, /hadiah/riwayat
    home: const MyHome(),  // KelopakWalletStrip(), KelopakGameStrip() di Beranda
  ),
));
```

### Tab Hadiah dan `KelopakNavigation`

Halaman hub berpindah jalur lewat `KelopakNavigation.openPath(context, '/hadiah/...')`. Tanpa `KelopakNavigation` di atasnya, hub memakai `Navigator.pushNamed` dengan `kelopakRoutes`. Bila `/hadiah` adalah tab di bilah bawah app, bungkus pohon app dengan `KelopakNavigation` supaya `/hadiah` memilih tab (bukan menumpuk halaman baru) dan jalur lain (`/hadiah/roda`, `/hadiah/voucher`, ...) ditumpuk oleh router app:

```dart
KelopakNavigation(
  open: (context, location) => location == KelopakPaths.rewards
      ? appShell.selectTab(AppTab.hadiah)
      : appRouter.push(location),
  child: child,
)
```

Kepala Zona Hadiah menerima aksi host, mis. Notifikasi dan Keranjang berlencana: `RewardsHubPage(actions: <Widget>[...])` (ikon putih 24 dp, tampil sebelum ikon bantuan).

API lengkap, bentuk data, dan endpoint backend: `docs/SPEC-CONTRACT.md`; kontrak HTTP rinci untuk tim backend dan server acuan PHP: `docs/BACKEND.md`, `server/`. Langkah integrasi: `HANDOFF-PENGEMBANG.md`. Produk: `PRD.md`. Riwayat versi: `CHANGELOG.md`.

## API publik utama

| Kelompok | Nama |
|---|---|
| Inti | `KelopakController`, `KelopakScope`, `KelopakHost`, `KelopakGameActions`, `KelopakEvent`, `KelopakCampaign`, `KelopakPolicy`, `KelopakProduct`, `WibClock` |
| Backend | `KelopakBackend`, `LocalKelopakBackend`, `RemoteKelopakBackend`, `KelopakTransport`, `KelopakAction` |
| Checkout | `CheckoutRequest`, `CheckoutLine`, `CheckoutQuote`, `CheckoutProblem`, `KelopakOrder` |
| Halaman | `RewardsHubPage`, `MyGiftsPage`, `VouchersPage`, `LedgerPage`, `showKelopakHowTo`, `kelopakRoutes`, `kelopakRouteFor`, `KelopakNavigation`, `KelopakPaths` |
| Game | `KelopakCheckInScreen`, `KelopakWheelScreen`, `KelopakMissionScreen`, `KelopakCheckInController`, `KelopakWheelController`, `KelopakMissionController`, `KelopakGameStatus` |
| Tanam | `KelopakWalletStrip`, `KelopakGameStrip`, `MissionCompleteCelebration`, `showMissionCompleteCelebration` |
| Komponen | `VoucherTicket`, `VoucherTeaserTicket`, `LedgerTile`, `GiftLedgerTile`, `GiftProductImage`, `GiftStatusChip`, `HubArt`, `kelopakPreviewTheme` |
| Kit | `package:kelopak_hub/kit.dart`: kit pesta (`CandyButton`, `GameScaffold`, `ResultSheet`, konfeti, koin terbang, sprite) + `BipySprite`, `BipySprites` |

## Contoh

`example/` menjalankan Beranda tiruan (strip dompet + "Main bareng Bipy"), zona Hadiah, tiga game, toko dan keranjang sederhana, dan panel demo (masuk/tamu, tema, kurangi gerak, geser hari, ke Sabtu, isi saldo, kuota roda, pesanan, atur ulang).

Runner `example/android` dan `example/web` ikut repo.

```bash
cd example
flutter run -d chrome
```

## Gerbang mutu

```bash
flutter analyze
flutter test --concurrency=3
cd example && flutter test
php server/selftest.php     # server acuan, PHP 8.2+
```

## Struktur

```
lib/
  kelopak_hub.dart          barel publik
  kit.dart                  kit pesta + BipySprite
  src/core, domain, storage, backend, controller, host   mesin dan data (H1)
  src/games                 controller tiga game di atas KelopakController
  src/ui                    zona Hadiah dan halaman turunannya
  src/embed                 widget tanam untuk host
  src/kit                   salinan kit pesta (jangan diubah di sini)
assets/art, bipy, fx        seni 3D, Bipy, stiker
example/                    app contoh (runner android + web)
test/                       domain, storage, backend, controller, ui, shots
docs/                       kontrak, riset, tangkapan layar
server/                     server acuan PHP v3 (kontrak docs/BACKEND.md, swa-uji php server/selftest.php)
```
