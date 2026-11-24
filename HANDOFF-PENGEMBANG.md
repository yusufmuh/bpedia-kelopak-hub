# Handoff Pengembang · Bpedia Preview v2

Untuk pengembang manusia dan agen AI yang melanjutkan **Bpedia Preview**: prototipe clean-room aplikasi belanja Bpedia (Flutter: Android, iOS, web) dengan 3 game hadiah yang memakai satu mata uang, **Kelopak** (1 Kelopak = Rp100).

Dokumen ini tidak berisi rahasia, kata sandi, token, atau alamat email. Jangan menambahkannya.

Ditulis 24 Nov 2026. Bila ada yang bertentangan, urutan acuannya: `PRD.md` → `docs/SPEC-CONTRACT.md` → `docs/SPEC-UIUX.md` (bagian ADDENDUM brand §7 mengalahkan nilai lain) → dokumen ini.

---

## 1. Apa yang sedang dibangun

| Hal | Nilai |
|---|---|
| Nama tampil | **Bpedia Demo**: label launcher Android, nama iOS, judul dan manifest web, `AppConfig.appName` (maks. 12 karakter, ADDENDUM brand). "Bpedia Preview" adalah nama teknis proyek di dokumen. |
| Android `applicationId` / namespace | `id.bpedia.preview` |
| iOS bundle id | `id.bpedia.preview` (tes: `id.bpedia.preview.RunnerTests`) |
| Versi | `2.0.0+20` (`pubspec.yaml`), tampil di Akun > Tentang aplikasi |
| Status | Prototipe **Mode Demo**. Belum dirilis ke toko mana pun. |
| App resmi | Bpedia, Android `com.wot.beautypedia`. Bpedia Preview memakai ID berbeda, jadi bisa dipasang **berdampingan** tanpa menimpa app resmi. |

Prinsip v2:

- **Clean-room.** Dibangun ulang dari brand guideline resmi dan screenshot milik owner. Kode dan aset APK produksi tidak dibongkar dan tidak dipakai. Berkas APK di folder workspace hanya arsip owner.
- **Mode Demo.** Tidak ada login dan tidak ada backend. Semua saldo, pesanan, voucher, dan hadiah dihitung engine lokal dan tersimpan di perangkat. Nilai yang belum disetujui bisnis diberi label "(Demo)".
- **Satu mata uang.** Hanya Kelopak. "Koin Bipy" dan koin bintang dari mockup lama tidak dipakai.

## 2. Workspace dan repo

Empat repo Git harus **bersebelahan** dalam satu folder, karena hub memakai modul lewat path relatif `../bpedia-*`:

```bash
mkdir bpedia-workspace && cd bpedia-workspace
git clone https://github.com/yusufmuh/bpedia-kelopak-hub.git
git clone https://github.com/yusufmuh/bpedia-daily-checkin.git
git clone https://github.com/yusufmuh/bpedia-roda-sabtu.git
git clone https://github.com/yusufmuh/bpedia-misi-belanja.git
```

| Repo | Paket Dart | Isi |
|---|---|---|
| `bpedia-kelopak-hub` | `kelopak_hub` | Aplikasi Bpedia Preview (shell 4 tab, toko demo, layar game, Akun), simulator PHP, semua spesifikasi |
| `bpedia-daily-checkin` | `daily_checkin` | Aturan Check-in Harian (hari WIB, rentetan, bonus, produk hari ke-30) + widget jejak 7 hari, progres 30 hari, tombol klaim + `server/checkin.php` |
| `bpedia-roda-sabtu` | `roda_sabtu` | Jadwal Sabtu WIB, peluang efektif sesuai stok, undian + widget `SaturdayWheel`, `OddsTable` + `server/spin.php` |
| `bpedia-misi-belanja` | `misi_belanja` | Tahap misi, evaluasi pesanan, voucher + widget `MissionLadder`, `VoucherCard`, formatter `rupiah` + `server/missions.php` |

Tiap modul punya `README.md` (cara pakai API) dan `PRD.md` (aturan lengkap). Tag rilis **belum ada** di keempat repo.

## 3. Prasyarat

| Perangkat lunak | Versi | Untuk |
|---|---|---|
| Flutter / Dart | 3.41.7 / 3.11.5 (versi yang dipakai dan diverifikasi) | semua build dan tes |
| Android SDK | sesuai `flutter doctor` | APK |
| Xcode | sesuai `flutter doctor` (hanya di macOS) | iOS |
| Chrome | terbaru | `flutter run -d chrome` |
| PHP | 8.2+ dengan `pdo_sqlite` (diuji dengan 8.4) | simulator server opsional |

Versi paket dikunci di `pubspec.yaml` dan sudah dicek resolve di SDK ini: audioplayers 6.7.1, shared_preferences 2.5.6, flutter_svg 2.3.4, url_launcher 6.3.3 (dev: flutter_launcher_icons 0.14.4, flutter_native_splash 2.4.7, flutter_lints 6.0.0). Versi lebih baru beberapa paket tersebut tidak resolve di Flutter 3.41.7 (lihat `docs/research/RISET-2026-11-24.md` §6).

## 4. Menjalankan

```bash
cd bpedia-kelopak-hub
flutter pub get

flutter run -d chrome        # web
flutter devices              # cari ID perangkat Android/emulator
flutter run -d <id-perangkat>
```

Catatan web: suara baru bisa diputar setelah ada sentuhan/klik pertama (aturan autoplay browser), getar tidak ada, dan data tersimpan di localStorage per origin.

## 5. Mode Demo

- **Penyimpanan:** satu dokumen JSON di shared_preferences, kunci `bpedia_preview_state_v1`, `"schema": 1` (Android: DataStore, iOS: NSUserDefaults, web: localStorage). Dokumen rusak atau skema tak dikenal: app mulai dari data baru tanpa crash. Pengaturan suara dan tema ikut tersimpan.
- **Jam:** hari dihitung dalam WIB (UTC+7) dari jam perangkat, ditambah offset Mode Demo. App membangun ulang tampilan tepat pukul 00.00 WIB dan saat kembali dari latar belakang.
- **Alat QA:** **Akun > Mode Demo (QA)**
  - tanggal simulasi saat ini + selisih dari tanggal asli;
  - tombol **+1 hari**, **+7 hari**, **Lompat ke Sabtu berikutnya** (kalender demo hanya bisa maju);
  - switch **Promo Roda Sabtu aktif** dan tombol **Isi ulang stok produk roda**;
  - **Reset semua data** (dengan konfirmasi): menghapus Kelopak, riwayat, voucher, hak produk, keranjang, pesanan, dan offset tanggal; pengaturan tetap.
- **Skenario uji cepat:**
  1. Check-in, lalu **+1 hari** dan check-in lagi sampai hari ke-7 (bonus +3 Kelopak).
  2. **Lompat ke Sabtu berikutnya**, putar Roda Sabtu, lihat hasilnya tetap tertulis setelah app dibuka ulang.
  3. Belanja min. Rp75.000, checkout, buka Transaksi, ketuk **Pesanan Diterima**: voucher Rp10.000 masuk ke Hadiahku.
  4. Pakai voucher itu di pesanan lain dengan belanja min. Rp100.000.

## 6. Arsitektur kode hub

```
lib/
  main.dart, app.dart        bootstrap: AppState.load(), AppScope, tema, ShellScope
  core/                      tokens brand, tema Material 3, format (rupiah, Kelopak, tanggal WIB),
                             jam WIB + offset, suara (AudioPool), getar, tautan resmi, path aset
  data/                      katalog demo 19 produk, penyimpanan key-value, dokumen persist
  domain/                    AppState (ChangeNotifier), RewardsEngine, ShopEngine, ledger, pengaturan
  ui/
    shell.dart               NavigationBar 4 tab: Beranda, Hadiah, Transaksi, Akun
    widgets/                 komponen bersama (ProductCard, KelopakAmount, SoftCard, PetalBurst, ...)
    home/  shop/             Beranda, cari, detail produk, keranjang, checkout
    rewards/                 tab Hadiah, Check-in Harian, Roda Sabtu, Misi Belanja, Hadiahku, Riwayat Kelopak
    orders/                  Transaksi dan detail pesanan
    account/                 Akun, Suara & getar, Mode Demo (QA), Syarat & Ketentuan, Tentang aplikasi
test/                        tes engine, persistensi, katalog, dan widget (test/support = helper AppState uji)
server/                      simulator API demo PHP (lihat §9)
docs/                        SPEC-CONTRACT, SPEC-UIUX, research/RISET-2026-11-24
```

Aturan penting:

- **Aturan bisnis hanya di modul.** `RewardsEngine` dan `ShopEngine` memanggil fungsi modul (`evaluateCheckIn`, `liveStreak`, `effectiveOdds`, `resolveSpin`, `spinEligibility`, `evaluateOrder`, `redeemProblem`) dan hanya mencatat hasilnya. Engine murni dan deterministik: `today`, `roll`, dan `landingSeed` selalu disuntik.
- **UI hanya lewat `AppState`.** Baca dengan `AppScope.of(context)` (ikut rebuild) atau `AppScope.read(context)` (di callback). Semua mutasi menyimpan dokumen di latar belakang; kegagalan simpan tidak pernah dilempar ke UI.
- **Acak:** `Random.secure()` untuk `roll` 0..9999 dan `landingSeed`. Hasil roda sudah final sebelum animasi; roda hanya menampilkannya.
- **Warna dan teks** hanya dari `Theme.of(context)` atau token di `lib/core/tokens.dart`. Uang selalu lewat `rupiah()` ("Rp10.000", tanpa spasi).
- **Umpan balik:** `AppState.feedback(FeedbackEvent.x)` memutar suara + getar sesuai pengaturan; visual (`PetalBurst`, `showRewardResultSheet`) di layar. Musik latar hanya di tab Hadiah dan layar game (`BgmScope`), bawaan mati.
- **Bahasa:** `MaterialApp` memakai locale tunggal `id` dengan `GlobalMaterialLocalizations.delegates` (`BpediaApp.locale`, `BpediaApp.localizationsDelegates`), jadi tooltip dan label bawaan juga berbahasa Indonesia ("Kembali", "Tutup"). Di tes widget pakai `tester.tapBack()` dari `test/support/navigation.dart`, bukan `tester.pageBack()` yang mencari tooltip Inggris "Back".
- **Tema:** tombol berbentuk pil (52 dp, padding 24); Berry Night memakai pink-200 gelap untuk `primaryContainer` dan isian `surfaceContainer` di atas kartu, karena token blush gelap sama dengan warna kartu. Jangan menambal warna per layar.
- **Roda tersimpan:** `SpinRecord` menyimpan `productStockBefore`; `AppState.oddsForSpin(record)` memberi segmen roda saat putaran itu, sehingga hasil tetap di bawah jarum setelah app dibuka ulang meskipun produk terakhir sudah dimenangkan.

## 7. Spesifikasi

| Dokumen | Isi |
|---|---|
| `PRD.md` | PRD pusat v2 |
| `docs/SPEC-CONTRACT.md` | Aturan bisnis persis, API publik tiap modul, keputusan teknis hub, pemetaan ColorScheme dan tipografi |
| `docs/SPEC-UIUX.md` | Prinsip UX, keputusan dari audit app lama, arsitektur informasi, tiap layar, tabel umpan balik, copy, ADDENDUM brand §7 |
| `docs/research/RISET-2026-11-24.md` | Audit app lama (sumber publik + screenshot owner), katalog demo, versi paket dan API terverifikasi, temuan audit kode v1 |
| `MEMORY.md` | Keputusan owner dan desain beserta tanggalnya |
| `GAMBARAN.md` | Alur (mermaid), daftar layar, arah visual |

## 8. Build

### APK Android

```bash
cd bpedia-kelopak-hub
flutter build apk --release
# hasil: build/app/outputs/flutter-apk/app-release.apk (universal, semua arsitektur)

flutter build apk --release --split-per-abi   # opsional: satu APK lebih kecil per arsitektur
```

APK berisi paket `id.bpedia.preview`, label "Bpedia Demo", `versionCode` 20 / `versionName` 2.0.0, minSdk 24 (Android 7.0+), targetSdk 36 (dicek dengan `aapt dump badging` pada build 24 Nov 2026).

Penandatanganan rilis membaca `android/key.properties` bila berkas itu ada. Tanpa berkas itu, build rilis memakai **kunci debug** mesin yang membangun: cukup untuk uji internal, tetapi APK dari mesin lain tidak bisa dipasang sebagai pembaruan (tanda tangan beda; hapus app dulu) dan tidak bisa diunggah ke Play Store.

Kunci preview yang stabil (opsional):

```bash
keytool -genkey -v -keystore <folder-aman>/bpedia-preview.jks -keyalg RSA -keysize 2048 -validity 10000 -alias bpedia-preview
```

Lalu buat `android/key.properties`:

```properties
storePassword=<kata sandi keystore>
keyPassword=<kata sandi kunci>
keyAlias=bpedia-preview
storeFile=<path ke bpedia-preview.jks, absolut atau relatif terhadap android/app>
```

`key.properties`, `*.jks`, dan `*.keystore` sudah ada di `android/.gitignore`. **Jangan pernah commit atau membagikan berkas ini.** Simpan cadangan keystore di pengelola kata sandi owner. Kunci yang sama wajib dipakai untuk setiap APK berikutnya agar bisa dipasang sebagai pembaruan.

### Ikon launcher dan splash

Sumber ada di `assets/launcher/` (ikon dengan pita "DEMO", latar adaptif, logo splash terang/gelap); konfigurasi di `pubspec.yaml` (`flutter_launcher_icons`, `flutter_native_splash`). Setelah mengganti berkas sumber:

```bash
dart run flutter_launcher_icons            # Android (adaptif), iOS, ikon web + manifest
dart run flutter_native_splash:create      # splash Android (termasuk Android 12), iOS, web
```

Generator splash menulis ulang bagian splash di `web/index.html`; pastikan listener `flutter-first-frame` yang memanggil `removeSplashFromWeb()` tetap ada, lalu cek build web di browser.

### Web

```bash
flutter build web --release                     # hasil: build/web, untuk root domain
MSYS_NO_PATHCONV=1 flutter build web --release --base-href /kelopak/   # subfolder, dari Git Bash
```

Git Bash mengubah argumen berbentuk `/x/` menjadi path Windows; `MSYS_NO_PATHCONV=1` mencegahnya (tidak perlu di PowerShell/cmd). App memakai URL hash bawaan Flutter, jadi hosting statis cukup menyajikan isi `build/web` tanpa aturan rewrite. Folder `build/` di-ignore Git: auto-deploy dari repo tidak akan memublikasikan build web, unggah isi `build/web` secara manual atau lewat CI. Subdomain `kelopak.gamysuf.fun` hanya kandidat dan **belum aktif** (tidak terdaftar di DNS saat dicek 24 Nov 2026).

**Setelah menambah atau menghapus plugin** (mengubah `dependencies` di `pubspec.yaml`), jalankan `flutter clean` lalu `flutter pub get` sebelum `flutter build web`. Flutter 3.41.7 tidak membuat ulang `web_plugin_registrant.dart` di cache `.dart_tool/flutter_build/` selama konfigurasi build sama, sehingga plugin web baru tidak terdaftar: suara diam, tautan "Buka bpedia.id" gagal, dan console menampilkan `MissingPluginException`. Cek cepat setelah build: `grep -c "Setting global AudioContext is not supported on Web" build/web/main.dart.js` harus lebih dari 0.

### iOS

`flutter build ipa` butuh macOS + Xcode dan akun Apple Developer owner. Bundle id sudah `id.bpedia.preview`; tim signing (`DEVELOPMENT_TEAM`) belum diisi.

## 9. Simulator server PHP (opsional)

`server/` berisi simulator API demo: router `index.php` (POST JSON, sesi `X-Demo-Session`, SQLite) dan aturan `checkin.php`, `spin.php`, `missions.php`. Ketiga berkas aturan adalah **salinan persis** dari repo modul (`../bpedia-*/server/`); setelah aturan modul berubah, salin ulang dan jalankan `php -l`. **App Flutter tidak memanggil simulator ini**; Mode Demo app sepenuhnya lokal. Simulator adalah contoh perilaku server untuk tim backend.

```bash
cd bpedia-kelopak-hub
php -S localhost:8080 -t server      # bila pdo_sqlite sudah aktif di php.ini

# Windows tanpa php.ini (mis. PHP dari winget): aktifkan pdo_sqlite lewat argumen
php -d extension_dir="<folder-php>/ext" -d extension=pdo_sqlite -S localhost:8080 -t server

# cek
curl -s -X POST http://localhost:8080/ -d '{"action":"open"}'
```

Tanpa `pdo_sqlite`, semua permintaan dibalas 503 "Layanan demo sementara tidak tersedia". `open` membuat sesi baru (dibalas `session` + `state`). Aksi lain wajib mengirim header `X-Demo-Session: <session>`; aksi yang mengubah data juga wajib mengirim `revision` dan `day` terbaru (kalau beda: 409 + state terbaru).

| Aksi | Body tambahan | Aturan |
|---|---|---|
| `read` | – | state saja |
| `checkin` | – | `claimDay` (`checkin.php`); klaim ganda 422 |
| `spin` | – | `claimSaturdaySpin` dengan `random_int(0, RODA_TOTAL_WEIGHT - 1)`; bukan Sabtu, sudah memutar, atau promo nonaktif 422 |
| `order` | `subtotal`, `order` | pesanan selesai untuk Misi Belanja (`recordDemoOrder` dengan hari demo) |
| `redeem` | `stage` (0 = voucher Tahap 1), `subtotal`, `order` | `useDemoVoucher` dengan hari demo; satu voucher misi per pesanan |
| `advance` | `step` 1..7 | kalender demo maju, maks. 365 hari |
| `promo` | `active` (bool) | promo Roda Sabtu aktif/jeda |
| `refill` | – | stok produk roda kembali 1 |

Setiap respons `state` berisi data tersimpan ditambah tampilan turunan: `day`, `date`, `weekday`, `checkin` (rentetan hidup, sudah klaim, slot 7 hari, progres 30 hari), `wheel` (kelayakan, peluang efektif basis 10000, stok, ongkir), dan `mission` (tahap + status, voucher + status). Data SQLite disimpan di `KELOPAK_DATA_DIR` bila diset; kalau tidak, di folder `kelopak-demo-data/` di samping folder repo hub (di hosting: di samping `public_html`, jadi tidak bisa diunduh lewat URL). Sesi kedaluwarsa setelah 7 hari tanpa aktivitas.

Sumber aturan PHP ada di repo modul (`server/checkin.php`, `server/spin.php`, `server/missions.php`); salinan di hub identik. Cek sintaks dengan `php -l server/<berkas>.php`; `php server/checkin.php` (di hub atau repo check-in) menjalankan swa-uji aturan check-in.

## 10. Gerbang mutu

Jalankan di hub dan di tiap modul sebelum PR atau rilis:

```bash
flutter analyze      # wajib "No issues found!"
flutter test         # wajib semua lulus
```

- Analisis memakai `strict-casts`, `strict-inference`, `strict-raw-types` dan lint tambahan (`analysis_options.yaml`).
- Dilarang: `print`/`debugPrint`, TODO/FIXME/placeholder, delay palsu, kode yang dikomentari, `dynamic` implisit.
- API deprecated yang dihindari: `withOpacity` (pakai `withValues(alpha:)`), `SemanticsService.announce` (pakai `sendAnnouncement`), `WillPopScope` (pakai `PopScope`), `MaterialStateProperty` (pakai `WidgetStateProperty`).
- UI: target sentuh min. 48 dp, label Semantics, teks sampai 200% tanpa terpotong, mode gelap, hormati `MediaQuery.disableAnimationsOf`. Font brand tidak punya glyph `≥ → ✓ ★ ♥`: tulis "min." atau pakai ikon.
- Sebelum rilis web: buka build di browser dan pastikan console tanpa error.

## 11. Integrasi ke app Bpedia resmi

Framework app resmi belum diverifikasi (APK produksi sengaja tidak dibongkar). Jalur yang disiapkan:

1. **Bila app resmi memakai Flutter:** tambahkan modul sebagai dependensi Git yang dikunci ke tag rilis.

   ```yaml
   dependencies:
     daily_checkin:
       git:
         url: https://github.com/yusufmuh/bpedia-daily-checkin.git
         ref: v2.0.0
     roda_sabtu:
       git:
         url: https://github.com/yusufmuh/bpedia-roda-sabtu.git
         ref: v2.0.0
     misi_belanja:
       git:
         url: https://github.com/yusufmuh/bpedia-misi-belanja.git
         ref: v2.0.0
   ```

   **Tag `v2.0.0` belum ada.** Tag dibuat saat rilis; sampai saat itu kunci `ref` ke hash commit tertentu, jangan ke `main`.
2. **Bila bukan Flutter:** pakai modul lewat Flutter add-to-app, atau implementasikan ulang dari `docs/SPEC-CONTRACT.md` dengan tes yang sama.

Yang wajib ada di sisi server sebelum dipakai pengguna sungguhan (belum dibangun):

- server otoritatif untuk ledger Kelopak, rentetan check-in, undian roda (RNG server, kuota produk nyata), dan voucher; klien hanya menampilkan;
- header `Idempotency-Key` di setiap mutasi agar ketukan ganda atau jaringan putus tidak menggandakan saldo;
- webhook pesanan selesai dari layanan pesanan, ditandatangani HMAC, sebagai satu-satunya pemicu Misi Belanja;
- satu akun Bpedia lintas perangkat (state terikat akun, bukan perangkat).

## 12. Kepatuhan toko

| Syarat | Status di Bpedia Preview |
|---|---|
| Apple 5.3: undian/kontes gratis, tanpa pembelian, aturan resmi tampil di app | Roda Sabtu gratis, tanpa pembelian; aturan lengkap di **Akun > Syarat & Ketentuan Program** |
| Apple 5.3: jelas bahwa Apple bukan sponsor | Kalimat "Apple bukan sponsor dan tidak terlibat dalam promosi ini." ada di S&K |
| Google Play: aturan promosi jelas | S&K memuat periode, kelayakan, peluang, kuota, ongkir, dan "Google bukan sponsor dan tidak terlibat dalam promosi ini." |
| Peluang tampil sebelum ikut | `OddsTable` (peluang %, sisa kuota, ongkir) tampil di atas tombol "Putar gratis" (`lib/ui/rewards/wheel_page.dart`); S&K memakai angka dari konfigurasi yang sama dengan undian |
| Apple 5.3: kontes disponsori pengembang app | **Perlu keputusan owner:** nama pengembang di App Store dan Google Play berbeda (lihat RISET §1). Penyelenggara di S&K produksi harus entitas pengembang di toko |

Temuan riset yang harus diperbaiki owner di listing app **resmi** sebelum pembaruan berikutnya:

- tautan kebijakan privasi di kedua toko mengarah ke `web.indobeauty.id`, kebijakan privasi app lain;
- App Store: rating usia 18+ dan bahasa hanya "English" untuk app berbahasa Indonesia.

## 13. Catatan terbuka

- Server otoritatif, kuota promo nyata, dan pengiriman produk gratis belum ada (lihat §11 dan `PRD.md` §6, §13).
- Entitas penyelenggara Roda Sabtu dan perbaikan listing app resmi menunggu owner (lihat §12).
- Tim signing iOS dan hosting web preview belum ditentukan.

## 14. Kepemilikan

- Owner produk: Muhammad Yusuf (Bpedia)
- GitHub: `yusufmuh`
- Kebijakan: jangan simpan secret di repo atau dokumen; jangan login ke akun owner memakai kata sandi.
