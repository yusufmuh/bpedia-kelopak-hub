# Bpedia Preview · bpedia-kelopak-hub

Prototipe **clean-room** aplikasi belanja Bpedia (Flutter: Android, iOS, web) dengan 3 game hadiah yang memakai satu mata uang, **Kelopak** (1 Kelopak = Rp100):

- **Check-in Harian**: +1 Kelopak per tanggal WIB, bonus +3 tiap hari ke-7 beruntun, 1 hak produk gratis tiap hari ke-30 beruntun.
- **Roda Sabtu**: 1 putaran gratis tiap Sabtu WIB; peluang, sisa kuota, dan ongkir tampil sebelum tombol putar.
- **Misi Belanja**: pesanan selesai min. Rp75.000 memberi voucher Rp10.000 untuk pesanan berikutnya min. Rp100.000; tahap berikutnya terbuka bertahap.

| | |
|---|---|
| Nama tampil | Bpedia Demo (nama teknis proyek: Bpedia Preview) |
| Android `applicationId` | `id.bpedia.preview`: bisa dipasang berdampingan dengan app resmi `com.wot.beautypedia` |
| iOS bundle id | `id.bpedia.preview` |
| Versi | 2.0.0 (build 20) |
| Status | Mode Demo: tanpa login dan tanpa backend; semua data tersimpan di perangkat. Belum dirilis ke toko. |

Kode dan aset APK produksi tidak dibongkar dan tidak dipakai. UI dibangun ulang dari brand guideline resmi dan screenshot milik owner.

## Mulai cepat

Empat repo harus bersebelahan dalam satu folder:

```bash
git clone https://github.com/yusufmuh/bpedia-kelopak-hub.git
git clone https://github.com/yusufmuh/bpedia-daily-checkin.git
git clone https://github.com/yusufmuh/bpedia-roda-sabtu.git
git clone https://github.com/yusufmuh/bpedia-misi-belanja.git

cd bpedia-kelopak-hub
flutter pub get
flutter run -d chrome          # atau: flutter devices, lalu flutter run -d <id-perangkat>
```

Butuh Flutter 3.41.7 / Dart 3.11.5 (versi yang dipakai dan diverifikasi).

## Isi app

| Tab | Isi |
|---|---|
| Beranda | Cari, kartu Kelopak hari ini, "Main bareng Bipy" (3 game), kategori, Hot Item, produk; keranjang di kanan atas |
| Hadiah | Saldo Kelopak, kartu Check-in Harian, Roda Sabtu, Misi Belanja, Hadiahku, Riwayat Kelopak |
| Transaksi | Pesanan Dikirim/Selesai, detail, tombol "Pesanan Diterima" yang menjalankan Misi Belanja |
| Akun | Profil demo, Hadiahku, Riwayat Kelopak, Suara & getar, Tampilan, Mode Demo (QA), Syarat & Ketentuan, Tentang |

**Mode Demo (QA)** di tab Akun: tanggal simulasi WIB, +1 hari, +7 hari, lompat ke Sabtu berikutnya, promo Roda Sabtu aktif/nonaktif, isi ulang stok produk roda, reset semua data.

## Struktur

```
lib/core      token brand, tema, format rupiah/Kelopak/tanggal WIB, jam, suara, getar, tautan resmi
lib/data      katalog demo, penyimpanan, dokumen persist (shared_preferences)
lib/domain    AppState, RewardsEngine, ShopEngine, ledger Kelopak, pengaturan
lib/ui        shell 4 tab, widget bersama, home, shop, rewards, orders, account
server/       simulator API demo PHP (opsional; app tidak memanggilnya)
docs/         spesifikasi dan riset
```

Aturan bisnis ada di tiga modul ([daily_checkin](https://github.com/yusufmuh/bpedia-daily-checkin), [roda_sabtu](https://github.com/yusufmuh/bpedia-roda-sabtu), [misi_belanja](https://github.com/yusufmuh/bpedia-misi-belanja)); hub hanya memanggil dan mencatat hasilnya.

## Dokumen

| Dokumen | Untuk |
|---|---|
| [PRD.md](PRD.md) | PRD pusat (sumber kebenaran) |
| [docs/SPEC-CONTRACT.md](docs/SPEC-CONTRACT.md) | Aturan bisnis persis, API publik modul, keputusan teknis, warna dan tipografi |
| [docs/SPEC-UIUX.md](docs/SPEC-UIUX.md) | Prinsip UX, arsitektur informasi, tiap layar, umpan balik, copy, aturan brand |
| [docs/research/RISET-2026-11-24.md](docs/research/RISET-2026-11-24.md) | Audit app lama, katalog demo, versi paket terverifikasi |
| [HANDOFF-PENGEMBANG.md](HANDOFF-PENGEMBANG.md) | Setup, Mode Demo, arsitektur, build, simulator, integrasi, kepatuhan toko |
| [MEMORY.md](MEMORY.md) | Keputusan owner dan desain beserta tanggal |
| [GAMBARAN.md](GAMBARAN.md) | Alur pengguna (mermaid), daftar layar, arah visual |
| [AGENTS.md](AGENTS.md) | Aturan kerja untuk agen AI |

## Build

```bash
flutter build apk --release      # build/app/outputs/flutter-apk/app-release.apk
flutter build web --release      # build/web
MSYS_NO_PATHCONV=1 flutter build web --release --base-href /kelopak/   # subfolder, dari Git Bash
```

`android/key.properties` (opsional, **jangan pernah di-commit**) memberi kunci rilis preview yang stabil; tanpa berkas itu build rilis ditandatangani kunci debug mesin yang membangun. Langkah lengkap: [HANDOFF-PENGEMBANG.md §8](HANDOFF-PENGEMBANG.md#8-build).

## Simulator PHP (opsional)

```bash
php -S localhost:8080 -t server
```

Butuh ekstensi `pdo_sqlite`. Di Windows tanpa `php.ini`: `php -d extension_dir="<folder-php>/ext" -d extension=pdo_sqlite -S localhost:8080 -t server`. Detail: [HANDOFF-PENGEMBANG.md §9](HANDOFF-PENGEMBANG.md#9-simulator-server-php-opsional).

## Gerbang mutu

```bash
flutter analyze    # wajib bersih, di hub dan di tiap modul
flutter test       # wajib lulus
```

## Integrasi ke app resmi

Modul dipasang sebagai dependensi Git yang dikunci ke tag rilis. **Belum ada tag**: tag dibuat saat rilis, sampai saat itu kunci ke hash commit. Sebelum dipakai pengguna sungguhan, server otoritatif (ledger, undian, kuota, voucher), `Idempotency-Key`, dan webhook pesanan ber-HMAC harus dibangun. Lihat [HANDOFF-PENGEMBANG.md §11](HANDOFF-PENGEMBANG.md#11-integrasi-ke-app-bpedia-resmi).

## Kepatuhan toko

Roda Sabtu gratis tanpa pembelian, peluang tampil sebelum tombol putar, dan S&K di app memuat "Apple bukan sponsor dan tidak terlibat dalam promosi ini." serta kalimat yang sama untuk Google (Apple Review Guideline 5.3). Riset menemukan listing app **resmi** menautkan kebijakan privasi app lain (`web.indobeauty.id`) dan App Store mencantumkan rating 18+ dengan bahasa "English" saja: perlu diperbaiki owner. Lihat [HANDOFF-PENGEMBANG.md §12](HANDOFF-PENGEMBANG.md#12-kepatuhan-toko).

Owner: Muhammad Yusuf (Bpedia) · GitHub `yusufmuh`
