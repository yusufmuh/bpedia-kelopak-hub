# PRD Pusat · Bpedia Kelopak (Game Hadiah Flutter)

**Versi 0.2 · 24 November 2026 · Owner: Muhammad Yusuf (Bpedia)**
Dokumen ini adalah **sumber kebenaran tunggal** untuk Claude, Antigravity (Gemini), Codex, dan pengembang manusia.
Kalau ada konflik antara dokumen ini dan PRD modul, dokumen ini yang berlaku untuk aturan lintas fitur; PRD modul berlaku untuk detail fitur itu sendiri.

| Dokumen | Isi |
|---|---|
| `PRD.md` (file ini) | Visi, ekonomi Kelopak, arsitektur, kontrak API, repositori, rilis |
| `MEMORY.md` | Keputusan pemilik produk + asumsi yang masih menunggu keputusan |
| `GAMBARAN.md` | Alur pengguna, diagram, arah visual |
| `HANDOFF-PENGEMBANG.md` | Cara setup, kerja, dan kirim perubahan (untuk dibagikan ke developer lain) |
| PRD modul | `bpedia-daily-checkin/PRD.md`, `bpedia-roda-sabtu/PRD.md`, `bpedia-misi-belanja/PRD.md` |

---

## 1. Tujuan

Membuat pengguna aplikasi Bpedia (Play Store, App Store, dan web) **kembali setiap hari** dan **belanja ulang**, lewat tiga kegiatan ringan yang semuanya bermuara pada satu dompet poin bernama **Kelopak**.

Ukuran keberhasilan (target diisi tim bisnis setelah baseline ada, **jangan mengarang angka**):
- % pengguna aktif yang check-in per hari, retensi hari ke-7 dan ke-30.
- % pengguna yang memutar Roda Sabtu dari yang memenuhi syarat.
- % voucher Misi Belanja yang ditukar dan rasio pesanan ulang.
- Biaya hadiah per pengguna aktif vs. kenaikan GMV.

## 2. Mata uang: Kelopak

| Aturan | Nilai |
|---|---|
| Nama | **Kelopak** (bukan "koin", agar beda dari Shopee) |
| Nilai | 1 Kelopak = Rp100 |
| Tipe data | Integer. Tidak ada pecahan. Saldo tidak boleh negatif. |
| Penyimpanan | Ledger append-only di server Bpedia. Saldo = jumlah entri ledger. Klien tidak pernah menghitung saldo sendiri. |
| Perlu keputusan bisnis | Cara penukaran di checkout, batas pemakaian per pesanan, masa kedaluwarsa, perlakuan saat retur |

## 3. Tiga modul (ringkasan — detail di PRD modul)

### PRD 1 · Check-in Harian — repo `bpedia-daily-checkin`
- Setiap check-in harian: **+1 Kelopak** (Rp100).
- 7 hari berturut-turut tanpa bolong: **bonus +3 Kelopak**. Total 7 hari = 10 Kelopak = **Rp1.000**.
- 30 hari berturut-turut tanpa bolong ("1 bulan"): **1 produk gratis**.
- Bolong 1 hari: rentetan mulai lagi dari hari 1. Saldo dan hak produk yang sudah didapat tidak hilang.
- Hari dihitung WIB (Asia/Jakarta, 00.00) oleh server, bukan jam perangkat.
- Biaya maksimal per pengguna per 30 hari: 30 + 4×3 = 42 Kelopak (Rp4.200) + 1 produk + ongkir.

### PRD 2 · Roda Sabtu (Gacha) — repo `bpedia-roda-sabtu`
- **1 putaran gratis per akun, hanya hari Sabtu** (Sabtu 00.00 – Minggu 00.00 WIB), selama periode promo aktif.
- Hadiah: produk gratis (sesuai kuota stok) atau Kelopak.
- **Sebelum memutar**, pengguna wajib melihat peluang (%) tiap hadiah, sisa kuota, dan ketentuan ongkir.
- Hasil ditentukan server (RNG server) lalu animasi roda hanya "menampilkan" hasil itu.
- Tidak ada pembelian putaran. Putaran gratis saja (penting untuk kebijakan Apple §5.3 dan Google Play).

### PRD 3 · Misi Belanja Bertahap — repo `bpedia-misi-belanja`
- Tahap 1: selesaikan 1 pesanan **≥ Rp75.000** → voucher **Rp10.000**, berlaku di pesanan berikutnya dengan **min. belanja Rp100.000**.
- Setelah hadiah tahap 1 terbit, **tahap 2 terbuka**, dan seterusnya (berantai seperti "suf"/level).
- Contoh tahap 2 (demo, menunggu persetujuan bisnis): pesanan ≥ Rp100.000 → voucher Rp5.000.
- Hanya pesanan berstatus **selesai** yang dihitung. Batal/retur tidak memberi hadiah.

## 4. Pengalaman & visual (wajib)

- Palet: latar Pearl, panel Blush `#F9F0EF`, aksen Berry `#982149`, teks Plum. Maskot **Bipy** di area atas (aset di folder induk: `maskot pose hai.png`, `bipy-tas-*.png`).
- Satu tombol utama per layar. Area sentuh ≥ 48 dp. Teks bisa diperbesar tanpa terpotong.
- Semua nominal, syarat, dan hasil berupa **teks** yang terbaca pembaca layar. Status tidak bergantung warna.
- Animasi roda bisa dilewati, dan otomatis disederhanakan jika "kurangi gerakan" aktif. Suara opsional, default mengikuti mode senyap.
- Setiap aksi punya 4 keadaan yang didesain: memuat, sukses, gagal (dengan tombol coba lagi), sudah diklaim.
- Anti bug: tombol klaim terkunci selama permintaan berjalan. Setelah putus jaringan, muat ulang status dari server, jangan menebak.

## 5. Arsitektur & sinkron dengan aplikasi Bpedia

```
Aplikasi Bpedia (Flutter, Play Store + App Store)
   └── menu "Hadiah" ──► paket Flutter: daily_checkin, roda_sabtu, misi_belanja
                         (git dependency dari 3 repo modul)
Web (Hostinger)       ──► build web dari bpedia-kelopak-hub (hub + 3 modul)
                              │
                              ▼
                     API Hadiah Bpedia (satu backend, satu akun)
                     ├── ledger Kelopak
                     ├── klaim check-in / putaran / misi
                     ├── voucher (dipakai checkout Bpedia)
                     └── event pesanan selesai (dari order service Bpedia)
```

**Prinsip sinkron:** semua state ada di server dan terikat ke **akun Bpedia yang sama**. Check-in dari iPhone langsung terlihat di Android dan web. Klien tidak menyimpan saldo/progres kecuali sebagai cache tampilan.

**Integrasi ke APK/IPA Bpedia** (pilih satu, rekomendasi pertama):
1. **Paket Flutter** — app Bpedia menambah di `pubspec.yaml`:
   ```yaml
   daily_checkin:
     git: { url: https://github.com/yusufmuh/bpedia-daily-checkin.git, ref: v0.1.0 }
   ```
   App Bpedia menyuplai token sesi dan base URL API. Paling mulus, tanpa WebView.
2. **WebView** ke build web di Hostinger — cepat dipasang, tapi pengalaman dan login kurang mulus.

## 6. Kontrak API (v1)

Semua `POST`, JSON, header `Authorization: Bearer <token sesi Bpedia>` dan `Idempotency-Key: <uuid>`. Identitas akun diambil dari token, **tidak pernah** dari body.

| Endpoint | Body | Respons inti |
|---|---|---|
| `/v1/rewards/state` | `{}` | `balance, streak, lastDay, nextClaimAt, products[], spin{}, missions[], vouchers[]` |
| `/v1/checkin/claim` | `{}` | `receiptId, awarded, bonus, streak, balance, productEntitlement?` |
| `/v1/spin/terms` | `{}` | `configVersion, opensAt, closesAt, prizes[{id,label,probability,quota}], shipping` |
| `/v1/spin/commit` | `{configVersion}` | `receiptId, prize, balance` atau `409 odds_changed` |
| `/v1/missions/state` | `{}` | `stages[{stage,threshold,reward,minSpend,status}]` |
| Webhook `/v1/orders/completed` | dari order service (bertanda tangan) | — |

Kode galat bersama: `401 unauthenticated`, `409 already_claimed | odds_changed | state_changed`, `422 not_eligible`, `429 rate_limited`, `503 retry_later`.

**Status saat ini:** server di tiap repo (`server/*.php`) adalah **simulator demo** (SQLite, sesi anonim, kalender bisa dimajukan). Bukan backend produksi. Backend produksi dibangun/dipasang oleh tim backend Bpedia mengikuti kontrak di atas.

## 7. Repositori

| Repo | Isi | Dipakai oleh |
|---|---|---|
| `github.com/yusufmuh/bpedia-kelopak-hub` | **Pusat**: PRD ini, MEMORY, GAMBARAN, handoff, app Flutter hub (Android/iOS/web), router PHP demo | Web Hostinger, demo APK |
| `github.com/yusufmuh/bpedia-daily-checkin` | Paket Flutter + logika server check-in + PRD 1 | Hub & app Bpedia |
| `github.com/yusufmuh/bpedia-roda-sabtu` | Paket Flutter + logika server roda + PRD 2 | Hub & app Bpedia |
| `github.com/yusufmuh/bpedia-misi-belanja` | Paket Flutter + logika server misi + PRD 3 | Hub & app Bpedia |

Orang lain cukup `git clone <link repo>` lalu ikuti `HANDOFF-PENGEMBANG.md`. Perubahan masuk lewat branch + Pull Request ke `main`, bukan push langsung.

## 8. Hosting (Hostinger)

- Akun Hostinger berisi beberapa situs (gamysuf.fun, thrilogic.site, ciptavara.site, dll.). Akses untuk agen AI lewat **Hostinger API/MCP**, bukan login password.
- Kandidat target demo web: `silent-mediumseagreen-lemur-77.hostingersite.com` (dibuat 24 Nov 2026, saat ini hanya halaman "Segera hadir"). Disarankan memasang subdomain seperti `kelopak.gamysuf.fun` sebelum dibagikan.
- Isi deploy: hasil `flutter build web` + folder `server/` (router PHP + 3 file logika modul). Data demo SQLite disimpan **di luar** `public_html` (`KELOPAK_DATA_DIR`).
- Pola yang sudah terbukti di gamysuf.fun: push ke `main` → auto-deploy Git Hostinger. Bisa diterapkan juga di hub.

## 9. Pipeline aset (AI generatif)

| Kebutuhan | Alat | Aturan |
|---|---|---|
| Ikon, ilustrasi hadiah, latar | ComfyUI (skill `comfyui-game-assets`) | Wajib konsisten dengan Bipy & palet. Ekspor PNG/WebP ≤ 200 KB. |
| Musik latar loop | AudioCraft MusicGen (`audiocraft-game-music`) | ≤ 30 detik, loop mulus, default **mati** |
| SFX klik, klaim, putaran | Stable Audio (`stable-audio-sfx`) | ≤ 1 detik, OGG + M4A (iOS) |
| Video promo | Generator video pilihan tim | Bukan bagian build app |

Semua aset hasil AI dicek manual (lisensi, kemiripan merek lain) sebelum masuk `assets/`.

## 10. Kualitas & definisi selesai

Setiap PR wajib lulus:
1. `flutter analyze` tanpa peringatan, `flutter test` hijau.
2. Unit test aturan ekonomi: hari 7 = +4, total 7 hari = 10; hari 30 = hak produk; bolong = reset; Sabtu WIB batas Jumat 23.59/Minggu 00.00; Rp74.999 gagal, Rp75.000 lolos; voucher tidak bisa dipakai di order asal; Rp99.999 gagal tukar.
3. Uji klaim ganda (dua perangkat serentak) = satu perubahan saldo.
4. Cek manual di web (Chrome mobile 375 px) tanpa error di console, dan di 1 perangkat Android.

## 11. Rilis bertahap

| Tahap | Isi | Syarat lanjut |
|---|---|---|
| 0 · Dokumen | PRD, memory, gambaran, repo (**sekarang**) | Owner setuju PRD |
| 1 · Demo web | Hub Flutter lengkap 3 modul + simulator PHP di Hostinger | QA §10 lulus |
| 2 · Integrasi | Paket masuk app Bpedia, backend produksi sesuai §6, staging | Uji lintas perangkat & checkout |
| 3 · Rilis store | Update Bpedia di Play Store & App Store, aturan promo resmi di dalam app | Review Legal (aturan undian/promosi Indonesia, Apple §5.3) |

## 12. Keputusan yang masih terbuka (owner)

1. "1 bulan" = 30 hari berturut-turut? (asumsi saat ini: ya, berulang tiap kelipatan 30)
2. SKU produk gratis check-in & roda, kuota per Sabtu, siapa yang menanggung ongkir.
3. Isi hadiah Kelopak di roda dan peluang masing-masing.
4. Jumlah tahap Misi Belanja dan hadiahnya setelah tahap 1; masa berlaku voucher.
5. Cara Kelopak dipakai di checkout (potongan langsung? batas maksimal?) dan masa kedaluwarsa.
6. Domain demo web final.

## Riwayat
- 0.2 · 24 Nov 2026 · PRD pusat dibuat; konsolidasi 3 PRD modul, kontrak API, repo, hosting.
- 0.1 · 24 Nov 2026 · Memory, gambaran, PRD modul.
