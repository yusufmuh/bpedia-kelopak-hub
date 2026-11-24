# Panduan Handoff Pengembang · Bpedia Kelopak

Dokumen ini ditujukan untuk **pengembang manusia dan agen AI (Claude, Antigravity, Codex)** yang akan melanjutkan pengembangan, pemeliharaan, atau integrasi Bpedia Kelopak.  
Dokumen ini **tidak mengandung rahasia, token privat, maupun kata sandi**.

---

## 1. Memulai Cepat (5 Menit)

Kloning keempat repositori ke dalam satu folder kerja bersama (bersebelahan):

```bash
mkdir bpedia-workspace && cd bpedia-workspace

# 1. Repositori Pusat & Hub Shell
git clone https://github.com/yusufmuh/bpedia-kelopak-hub.git

# 2. Modul PRD 1: Check-in Harian
git clone https://github.com/yusufmuh/bpedia-daily-checkin.git

# 3. Modul PRD 2: Roda Sabtu (Gacha)
git clone https://github.com/yusufmuh/bpedia-roda-sabtu.git

# 4. Modul PRD 3: Misi Belanja Bertahap (Suf)
git clone https://github.com/yusufmuh/bpedia-misi-belanja.git
```

> **Catatan Struktur Folder:**  
> Keempat folder di atas harus berada dalam **direktori yang sama** (bersebelahan). Saat pengembangan lokal, `bpedia-kelopak-hub` mereferensikan ketiga modul via path relatif `../bpedia-*`.

---

## 2. Kebutuhan Lingkungan Pengembangan

| Perangkat Lunak | Versi Minimal | Fungsi |
|---|---|---|
| **Flutter SDK** | 3.41+ (Dart ≥ 3.11) | Framework antarmuka cross-platform (Android, iOS, Web). |
| **PHP** | 8.2+ dengan modul `pdo_sqlite` | Menjalankan simulator API backend demo lokal. |
| **Android Studio / Xcode** | Versi terbaru | Build native untuk target Android (APK/AAB) dan iOS (IPA). |
| **Git** | 2.40+ | Manajemen versi kode sumber multi-repo. |

---

## 3. Menjalankan Proyek Secara Lokal

### Langkah 1: Menjalankan Simulator API Backend Demo
Buka terminal pertama:
```bash
cd bpedia-kelopak-hub
php -S localhost:8080 -t server
```
*Server demo akan berjalan di `http://localhost:8080` dan secara otomatis membuat database SQLite lokal di folder `../kelopak-demo-data/demo.sqlite`.*

### Langkah 2: Menjalankan Aplikasi Flutter Hub
Buka terminal kedua:
```bash
cd bpedia-kelopak-hub
flutter pub get

# Jalankan pada browser Chrome (Web):
flutter run -d chrome

# Atau jalankan pada emulator Android:
flutter run -d android
```

---

## 4. Cara Integrasi ke Aplikasi Utama Bpedia (Play Store & App Store)

Terdapat dua opsi integrasi ke dalam aplikasi Flutter utama Bpedia:

### Opsi A: Integrasi Paket Flutter Modular (Sangat Direkomendasikan)
Aplikasi utama Bpedia cukup menambahkan dependensi git modul ke dalam `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Modul Check-in Harian
  daily_checkin:
    git:
      url: https://github.com/yusufmuh/bpedia-daily-checkin.git
      ref: v1.0.0

  # Modul Roda Sabtu
  roda_sabtu:
    git:
      url: https://github.com/yusufmuh/bpedia-roda-sabtu.git
      ref: v1.0.0

  # Modul Misi Belanja
  misi_belanja:
    git:
      url: https://github.com/yusufmuh/bpedia-misi-belanja.git
      ref: v1.0.0
```

**Kelebihan Opsi A:**
- Rendering 100% native (60/120 FPS tanpa jeda WebView).
- State terintegrasi langsung dengan state manager aplikasi Bpedia (Bloc/Provider/Riverpod).
- Token autentikasi dan base URL di-inject langsung melalui constructor modul.

### Opsi B: In-App WebView ke Hostinger
Jika tim merilis secara bertahap tanpa perlu menunggu review Play Store / App Store untuk setiap update promo:
1. Deploy build web ke Hostinger (`https://kelopak.gamysuf.fun`).
2. Tampilkan di dalam tab Hadiah aplikasi Bpedia menggunakan paket `webview_flutter`.
3. Kirim sesi user melalui cookie aman atau header HTTP authorization.

---

## 5. Panduan Deployment ke Hostinger

1. **Build Web Flutter**:
   ```bash
   cd bpedia-kelopak-hub
   flutter build web --release
   ```
2. **Struktur Direktori di Hostinger (`public_html`)**:
   - Salin seluruh isi folder `build/web/` langsung ke `public_html/`.
   - Salin folder `server/` ke `public_html/server/`.
   - Pastikan file `.htaccess` mendukung routing SPA Flutter:
     ```apache
     <IfModule mod_rewrite.c>
       RewriteEngine On
       RewriteBase /
       RewriteRule ^index\.html$ - [L]
       RewriteCond %{REQUEST_FILENAME} !-f
       RewriteCond %{REQUEST_FILENAME} !-d
       RewriteRule . /index.html [L]
     </IfModule>
     ```
3. **Penyimpanan Database SQLite**:
   - Skrip PHP otomatis mendeteksi dan menulis database demo ke folder di luar root web (`dirname(__DIR__, 2) . '/kelopak-demo-data'`).
   - Direktori ini terlindung dari akses langsung URL browser.
4. **Otomasi Git Hostinger**:
   - Di hPanel Hostinger: Buka menu **Git**.
   - Masukkan URL Repository: `https://github.com/yusufmuh/bpedia-kelopak-hub.git`.
   - Cabang (*Branch*): `main`.
   - Pasang Webhook Auto-Deploy dari GitHub settings agar setiap push langsung memperbarui web.

---

## 6. Checklist Kepatuhan App Store & Google Play

Sebelum mengajukan rilis update aplikasi Bpedia ke Apple App Store & Google Play:
- [x] **Apple Guideline §5.3**: Roda Sabtu **100% gratis**, tanpa opsi pembelian putaran dengan uang nyata.
- [x] **Transparansi Odds**: Peluang menang numerik (%) dan sisa kuota produk ditampilkan sebelum tombol putar aktif.
- [x] **Disclaimer Wajib**: Teks *"Apple bukan sponsor promosi ini"* dicantumkan pada syarat & ketentuan dalam aplikasi.
- [x] **Aksesibilitas**: Tombol berukuran minimal 48 dp, teks kontras tinggi, mendukung screen reader.
- [x] **Anti-Duplikasi**: Request mutasi saldo menyertakan `Idempotency-Key` untuk mencegah klaim ganda saat jaringan tidak stabil.

---

## 7. Pengujian & Verifikasi Mutu

Sebelum membuat Pull Request atau merilis tag versi baru:
```bash
# 1. Jalankan static analysis (wajib nol peringatan)
flutter analyze

# 2. Jalankan seluruh unit test
flutter test
```

Setiap modul memiliki test case lengkap yang menguji aturan ekonomi (hari ke-7 = +4 Kelopak, hari ke-30 = hak produk gratis, validasi ambang belanja Rp75.000, batas penukaran voucher Rp100.000).

---

## 8. Kontak & Kepemilikan

- **Pemilik Produk (Product Owner)**: Muhammad Yusuf (Bpedia)
- **Akun GitHub Resmi**: `yusufmuh`
- **Pusat Dokumentasi**: `bpedia-kelopak-hub/PRD.md`
