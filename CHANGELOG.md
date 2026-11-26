# Changelog

Semua perubahan berarti pada paket `kelopak_hub`. Tanggal memakai WIB.

## 3.0.0 · 26 Nov 2026

Rombakan v3 (Bpedia Demo v3). Hub berubah dari aplikasi menjadi paket Flutter murni yang dipasang `bpedia-app`.

### Baru

- **Paket murni tanpa plugin**: mesin aturan Kelopak, buku besar, kutipan checkout, hadiah menunggu, dan penyimpanan berversi di `lib/src/core`, `domain`, `storage`. Backend lokal (`LocalKelopakBackend`) dan kontrak server (`RemoteKelopakBackend`, `KelopakTransport`, `KelopakAction`); server acuan PHP di `server/`.
- **`KelopakController` dan `KelopakScope`**: satu sumber keadaan untuk app, zona Hadiah, dan tiga game; peristiwa `KelopakEvent` untuk analitik, kotak masuk, dan perayaan.
- **Zona Hadiah** (`/hadiah/*`): `RewardsHubPage` (hero saldo dengan strip check-in 7 hari, panel "Main hari ini", hadiah menunggu, Voucherku, Riwayat Kelopak, cara kerja), `MyGiftsPage` (spanduk hadiah menunggu, riwayat kiriman bertahap), `VouchersPage` (Semua, Bisa dipakai, Akan datang, Riwayat, cara dapat voucher, ketentuan), `LedgerPage` (hero saldo, saring Semua/Masuk/Dipakai/Hadiah), lembar Cara pakai, `kelopakRoutes`, `KelopakNavigation` untuk host yang menjadikan `/hadiah` sebuah tab.
- **Controller game**: `KelopakCheckInController`, `KelopakWheelController`, `KelopakMissionController` di atas `KelopakController`, plus layar siap pakai `KelopakCheckInScreen`, `KelopakWheelScreen`, `KelopakMissionScreen`.
- **Widget tanam Beranda**: `KelopakWalletStrip` (saldo, voucher, hadiah) dan `KelopakGameStrip` ("Main bareng Bipy" dengan nilai ringkas tiap game); `MissionCompleteCelebration` dan `showMissionCompleteCelebration`.
- **Voucher event "Akan datang"**: `KelopakCampaign.upcomingVouchers` (`KelopakVoucherTeaser`) dan `KelopakController.upcomingVouchers`.
- **Kit pesta** (`package:kelopak_hub/kit.dart`): `GameScaffold`, `CandyButton`, `ResultSheet`, konfeti, koin terbang, sprite Bipy.
- Runner `example/android` dan `example/web` ikut repo.

### Aturan bisnis

- K4: Misi Belanja punya daftar produk misi per tahap (`MissionStage.productCodes`).
- K16: Kelopak yang dimiliki otomatis memotong harga barang di checkout (bisa dimatikan), tanpa membuat total negatif; batas pemakaian dari `KelopakPolicy`.
- Tamu boleh melihat zona Hadiah dan halaman game serta mengisi keranjang dari halaman Misi (KEPUTUSAN §5); progres, klaim, dan voucher menunggu masuk.
- K17: hadiah produk menunggu dan ikut pesanan berikutnya yang berisi minimal 1 produk berbayar, tanpa ongkir tambahan.
- Catatan buku besar memakai nomor pesanan bertanda pagar: "Dipakai di pesanan #BP-...", "Dikembalikan dari pesanan #BP-...".
- Tiap voucher misi dirayakan sekali (`KelopakController.claimMissionCelebration`).

### Perubahan yang memutus kompatibilitas dari 2.x

- Hub bukan lagi aplikasi: runner `android/`, `ios/`, `web/` di akar dipindah ke `bpedia-app`; hub dipasang sebagai dependensi.
- Keadaan v2 dibaca sekali lewat `migrateV2Kelopak` (`v2DocumentKey`); catatan lama "Dipakai di pesanan BP-..." tetap diterima dan dinormalkan ke format bertanda pagar.
- Halaman, controller, dan widget memakai nama baru (`RewardsHubPage`, `Kelopak*Controller`, `Kelopak*Screen`, `KelopakWalletStrip`, `KelopakGameStrip`); API v2 tidak dipertahankan.
- `LedgerFilter.earned` berlabel "Masuk" dan ada saringan baru `LedgerFilter.gifts`; `VouchersPage` punya empat tab (`VoucherTab`).
- `KelopakGameStatus` menambah `value` (nilai ringkas satu baris) dan judul misi memuat tahap ("Tahap 1 · Rp40.000 lagi").

## 2.0.0 · 24-25 Nov 2026

Bpedia Preview v2: aplikasi belanja clean-room dan tiga game Kelopak dalam satu shell, lalu perbaikan hasil review adversarial.

## 1.0.0 · 23 Nov 2026

Hub v1: shell Flutter terpadu, PRD, dan handoff pengembang.
