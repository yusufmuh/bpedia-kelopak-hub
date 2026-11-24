# Memori Proyek Bpedia Kelopak

Catatan resmi keputusan arsitektur dan bisnis per 24 November 2026.
Dokumen ini merupakan acuan resmi untuk **Claude, Antigravity (Gemini), Codex**, dan tim pengembang aplikasi Bpedia.

---

## 1. Ringkasan Keputusan Inti

| Domain | Keputusan Resmi | Detail & Rasional |
|---|---|---|
| **Mata Uang Loyalitas** | **Kelopak** | Menggunakan istilah **Kelopak** (bukan "koin") agar memiliki identitas unik brand Bpedia dan membedakannya dari Shopee Koin.<br>• **1 Kelopak = Rp100**.<br>• Tipe data: Integer (tanpa pecahan/desimal). Saldo tidak pernah negatif. |
| **PRD 1: Check-in Harian** | **+1 Kelopak harian, +3 bonus mingguan, 1 produk bulanan** | • Check-in harian: **+1 Kelopak** (setara Rp100).<br>• Streak 7 hari berturut-turut tanpa bolong: **Bonus +3 Kelopak** (Total 7 hari: 7 + 3 = 10 Kelopak = **Rp1.000**).<br>• Streak 30 hari penuh (1 bulan) tanpa bolong: **1 Hak Produk Gratis** (*Free Product*).<br>• Jika bolong 1 hari: rentetan (streak) kembali ke hari 1. Saldo dan hak produk yang sudah didapat tetap aman (tidak hangus).<br>• Siklus hari: Berganti pukul **00.00 WIB** (Asia/Jakarta, UTC+7), ditentukan server. |
| **PRD 2: Roda Sabtu (Gacha Roulette)** | **1x putaran gratis per Sabtu WIB selama promo** | • Hanya dapat diputar pada hari **Sabtu** (00.00 – 23.59.59 WIB) selama periode promosi aktif.<br>• **Gratis 1 putaran per akun** per Sabtu (tidak ada pembelian putaran tambahan dengan uang maupun Kelopak).<br>• Hadiah: **Produk Gratis** (sesuai kuota promo) atau **Kelopak** (3 Kelopak pada demo/kampanye).<br>• **Transparansi Wajib**: Peluang (%) tiap hadiah, kuota produk tersedia, dan estimasi ongkir **wajib ditampilkan** sebelum tombol putar dapat disentuh.<br>• Penentu hasil: RNG (Random Number Generator) berada di server secara atomik. Animasi roda hanya visualisasi hasil server.<br>• Kepatuhan: Memenuhi **Apple App Store Review Guidelines §5.3** dan **Google Play Developer Policy** untuk undian/kontes promosi gratis. |
| **PRD 3: Misi Belanja Bertahap (Suf)** | **Voucher berantai berbasis pesanan selesai** | • **Tahap 1**: Selesaikan 1 pesanan minimal **Rp75.000** (subtotal produk selesai) → Dapatkan **Voucher Rp10.000**.<br>• Syarat pakai voucher: Berlaku di pesanan berikutnya dengan **minimal belanja Rp100.000**.<br>• Sistem bertingkat (*tiered / suf*): Setelah hadiah Tahap 1 terbit, **Tahap 2 otomatis terbuka** (misal: pesanan ≥ Rp100.000 → voucher Rp5.000).<br>• Validasi: Hanya pesanan berstatus **SELESAI (Completed)** yang dihitung. Batal, retur, atau pengiriman berjalan tidak memberi hadiah.<br>• Voucher tidak dapat dipakai pada pesanan yang menjadi sumber terbitnya voucher tersebut (*anti-self-loop*). |
| **Distribusi & Arsitektur** | **Multi-Repository Modular + Flutter Hub** | • 4 repositori GitHub mandiri di bawah akun `yusufmuh`.<br>• Dapat diintegrasikan ke APK/IPA Bpedia sebagai **Flutter Git Package** atau melalui **In-App WebView**.<br>• Dapat dijalankan sebagai **Web App mandiri di Hostinger**.<br>• Sinkronisasi terpusat: State saldo, streak, voucher, dan kuota terikat pada **Akun Bpedia yang sama** lintas perangkat (Android, iOS, Web). |

---

## 2. Struktur Repositori & Hak Akses

| Nama Repositori | URL GitHub | Peran |
|---|---|---|
| **bpedia-kelopak-hub** | `https://github.com/yusufmuh/bpedia-kelopak-hub.git` | **Pusat**: PRD induk, Handoff, Shell UI Flutter (Android/iOS/Web), Router API demo PHP. |
| **bpedia-daily-checkin** | `https://github.com/yusufmuh/bpedia-daily-checkin.git` | **Modul PRD 1**: Widget check-in 7 hari & progres 30 hari + logika verifikasi backend checkin. |
| **bpedia-roda-sabtu** | `https://github.com/yusufmuh/bpedia-roda-sabtu.git` | **Modul PRD 2**: Widget roda putar interaktif + tampilan peluang/ongkir + logika RNG server. |
| **bpedia-misi-belanja** | `https://github.com/yusufmuh/bpedia-misi-belanja.git` | **Modul PRD 3**: Widget kartu misi bertahap (suf) + verifikasi pesanan & integrasi voucher. |

Setiap pengembang atau agen AI cukup menyalin (*copy-paste*) tautan repositori di atas dan mengikuti panduan di `HANDOFF-PENGEMBANG.md`.

---

## 3. Infrastruktur & Hosting (Hostinger)

1. **Lingkungan Server**:
   - Akun Hostinger: PHP 8.2+ dengan ekstensi `pdo_sqlite` aktif.
   - Domain produksi/staging: `gamysuf.fun` (subdomain rekomendasi: `kelopak.gamysuf.fun`) atau target staging `silent-mediumseagreen-lemur-77.hostingersite.com`.
2. **Skema Deployment**:
   - Kompilasi Web: `flutter build web --release`.
   - File statis build diletakkan di `public_html/`.
   - Script backend demo diletakkan di `public_html/server/index.php`.
   - Basis data SQLite diletakkan di luar root web (`../kelopak-demo-data/demo.sqlite`) dengan izin `0700` agar tidak dapat diunduh publik.
3. **Otomasi Git**:
   - Webhook Git Hostinger dikonfigurasi ke cabang `main` repo `yusufmuh/bpedia-kelopak-hub`. Setiap `git push origin main` otomatis memperbarui build staging web.

---

## 4. Kepatuhan Toko Aplikasi (Store Guidelines)

1. **Apple App Store (Guideline §5.3 - Gaming, Gambling, and Lotteries)**:
   - Partisipasi Roda Sabtu **100% gratis** tanpa prasyarat transaksi berbayar.
   - Peluang probabilitas (*odds*) setiap hadiah dan kuota ditampilkan secara transparan sebelum roda diputar.
   - Ketentuan resmi dicantumkan jelas di dalam aplikasi beserta penegasan: *"Apple bukan sponsor dan tidak terlibat dalam kegiatan promosi ini."*
2. **Google Play Store**:
   - Memenuhi kebijakan Promosi & Kontes: Aturan partisipasi, periode berlaku, dan syarat pemenuhan hadiah (*fulfillment*) tercantum gamblang.

---

## 5. Standar Rekayasa & Anti-Bug

- **Server-Authoritative**: Klien Flutter dilarang menghitung saldo, menentukan RNG putaran roda, atau memvalidasi kelayakan pesanan sendiri.
- **Idempotensi**: Setiap aksi klaim menyertakan header `Idempotency-Key: <UUID>`. Request ganda (misal akibat koneksi tidak stabil atau ketukan ganda) dijamin hanya memicu satu mutasi data di server.
- **Aksesibilitas & Tampilan**: Area sentuh minimal 48×48 dp, teks kontras tinggi, mendukung mode *Reduce Motion* (menonaktifkan animasi putaran bagi pengguna sensitif), dan label *Semantics* lengkap untuk pembaca layar (TalkBack / VoiceOver).
