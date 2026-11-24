# PRD Pusat · Bpedia Kelopak (Game Hadiah Flutter)

**Versi 1.0 (Final & Resmi) · 24 November 2026 · Owner: Muhammad Yusuf (Bpedia)**  
Dokumen ini adalah **sumber kebenaran tunggal (Single Source of Truth)** untuk Claude, Antigravity (Gemini), Codex, dan tim pengembang aplikasi Bpedia.

Jika terdapat perbedaan antara dokumen ini dan PRD modul individu, ketentuan dalam dokumen ini yang berlaku untuk arsitektur, ekonomi, dan aturan lintas fitur.

---

## 1. Visi & Tujuan Produk

Membangun ekosistem loyalitas interaktif bagi pembeli aplikasi Bpedia (tersedia di **Google Play Store**, **Apple App Store**, dan **Web**) yang mendorong:
1. **Retensi Harian (*Daily Habit*)**: Pengguna membuka aplikasi setiap hari untuk mengklaim Kelopak.
2. **Keterlibatan Mingguan (*Weekly Excitement*)**: Pengguna menantikan hari Sabtu untuk memutar Roda Keberuntungan gratis.
3. **Konversi Belanja Berulang (*Repeat Order Driver*)**: Misi belanja bertingkat yang memberikan voucher belanja berikutnya setelah pesanan selesai.

Semua kegiatan bermuara pada satu dompet loyalitas terpadu bernama **Kelopak**.

---

## 2. Mata Uang Loyalitas: Kelopak

| Aturan Bisnis | Nilai & Spesifikasi |
|---|---|
| **Nama Mata Uang** | **Kelopak** (Bukan "koin", untuk membedakan secara unik dari Shopee Koin). |
| **Nilai Tukar** | **1 Kelopak = Rp100** |
| **Tipe Data** | **Integer**. Tidak ada pecahan atau desimal. Saldo tidak boleh negatif. |
| **Penyimpanan Data** | Ledger append-only di server pusat Bpedia. `Saldo = SUM(kredit) - SUM(debit)`. Klien dilarang menghitung atau memanipulasi saldo sendiri. |
| **Penggunaan** | Dapat digunakan sebagai potongan langsung pada saat checkout belanja di aplikasi Bpedia sesuai batas ketentuan program. |

---

## 3. Rincian Tiga Modul Utama

### PRD 1 · Check-in Harian (Repo: `bpedia-daily-checkin`)
- **Klaim Harian**: Setiap hari pengguna berhak mengklaim **+1 Kelopak** (= Rp100).
- **Streak 7 Hari (1 Minggu Tanpa Bolong)**: Mendapatkan **bonus +3 Kelopak**.  
  *Total perolehan 7 hari berturut-turut: 7 harian + 3 bonus = 10 Kelopak = **Rp1.000**.*
- **Streak 30 Hari (1 Bulan Tanpa Bolong)**: Mendapatkan **1 Hak Produk Gratis** (*Free Product Voucher/Claim*).
- **Aturan Reset Rentetan (Streak)**: Jika terlewat 1 hari tanpa check-in, rentetan kembali ke Hari 1. Saldo Kelopak dan hak produk yang telah diperoleh sebelumnya **tidak pernah hangus**.
- **Waktu Server**: Hari berganti tepat pukul **00.00 WIB** (Asia/Jakarta, UTC+7), ditentukan oleh server, bukan jam lokal perangkat pengguna.
- **Beban Anggaran Maksimal**: 30 hari berturut-turut per pengguna = 30 harian + 4×3 bonus = 42 Kelopak (Rp4.200) + 1 unit produk promosi + subsidi ongkir.

### PRD 2 · Roda Sabtu / Gacha Roulette (Repo: `bpedia-roda-sabtu`)
- **Frekuensi**: Hanya dapat diputar **1 kali seminggu pada hari Sabtu** (Sabtu 00.00 – 23.59.59 WIB) selama periode promosi aktif.
- **Biaya**: **100% Gratis**. Tidak ada opsi pembelian putaran tambahan dengan uang maupun Kelopak.
- **Hadiah**:
  1. **Produk Gratis**: Sesuai kuota stok promosi yang tersedia secara riil.
  2. **Kelopak**: Hadiah alternatif (misal: 3 Kelopak senilai Rp300).
- **Transparansi Mutlak (Kepatuhan Toko)**:
  - Sebelum pengguna dapat menekan tombol putar, antarmuka **wajib menampilkan**:
    1. Persentase peluang menang (*odds*) tiap hadiah (misal: Produk Gratis 10%, 3 Kelopak 90%).
    2. Sisa kuota produk promosi yang tersedia secara langsung (*real-time*).
    3. Ketentuan dan perkiraan ongkir (pada masa promo: Subsidi Ongkir Rp0).
- **Integritas Putaran (Anti-Kecurangan)**: Hasil putaran ditentukan oleh RNG (Random Number Generator) di sisi server secara atomik. Animasi roda pada klien hanyalah representasi visual yang berhenti pada sektor hasil yang telah ditetapkan server.

### PRD 3 · Misi Belanja Bertahap / Suf (Repo: `bpedia-misi-belanja`)
- **Misi Berantai (*Tiered Missions / Suf*)**:
  - **Tahap 1**: Selesaikan 1 pesanan dengan subtotal minimal **Rp75.000** → Dapatkan **Voucher Rp10.000**.
  - **Syarat Penukaran Voucher Tahap 1**: Dapat digunakan pada pesanan berikutnya dengan **minimal belanja Rp100.000**.
  - **Pembukaan Tahap 2**: Segera setelah voucher Tahap 1 berhasil diterbitkan ke akun, **Tahap 2 otomatis terbuka** (contoh: pesanan selesai ≥ Rp100.000 → voucher Rp5.000 min. belanja Rp100.000).
- **Validasi Transaksi Ketat**:
  - Hanya pesanan dengan status **Selesai (*Completed*)** yang dihitung.
  - Pesanan dalam proses pembayaran, pengiriman, dibatalkan, atau diretur tidak berhak atas reward.
  - Perhitungan subtotal mengacu pada harga barang sebelum ongkos kirim dan sebelum diskon voucher misi ini.
  - **Anti-Self-Loop**: Voucher tidak dapat digunakan pada nomor pesanan yang menghasilkan voucher tersebut.

---

## 4. Pengalaman Visual & Standar Rekayasa (Design & UX)

- **Identitas Visual Resmi Bpedia**:
  - Latar Belakang: Pearl `#FFFDFD`
  - Panel & Kartu: Blush `#F9F0EF`, Highlight hari tercapai `#F6CFDA`
  - Aksen Utama (Tombol & Icon): Berry `#982149`
  - Tipografi: Plum `#4B1C2E`
  - Aksen Emas (Hadiah Spesial): Gold `#EAA023`
  - Maskot: **Bipy** (lebah resmi Bpedia dengan tas ikonik) menyambut di bagian atas aplikasi.
- **Anti-Bug & Ketahanan Transaksi**:
  - Tombol aksi otomatis *disabled* dan menampilkan indikator loading saat permintaan sedang diproses untuk mencegah *double-tap*.
  - Dukungan *Idempotency-Key* di setiap mutasi server: jika koneksi internet terputus saat request dikirim, pengulangan request tidak menduplikasi saldo atau voucher.
  - State pemulihan otomatis: Klien memuat ulang data resmi dari server saat aplikasi kembali dari background.
- **Aksesibilitas (A11y)**:
  - Target sentuh minimal **48 × 48 dp**.
  - Dukungan penuh pembaca layar (`Semantics` TalkBack di Android dan VoiceOver di iOS).
  - Mendukung preferensi sistem **Reduce Motion**: Animasi putaran roulette dapat dilewati atau ditiadakan secara otomatis.

---

## 5. Arsitektur Sinkronisasi Lintas Platform (Android, iOS, Web)

```
┌────────────────────────────────────────────────────────────────────────┐
│                        APLIKASI BPEDIA PUSAT                           │
│     (Tersedia di Google Play Store, Apple App Store, dan Web)          │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │
      ┌────────────────────────────┴─────────────────────────────┐
      ▼                                                          ▼
[Opsi 1: Rekomendasi Utama]                                [Opsi 2: Webview Staging]
Integrasi Paket Flutter Modular                            In-App WebView ke Hostinger
- pubspec.yaml: daily_checkin, roda_sabtu, misi_belanja    - URL: https://kelopak.gamysuf.fun
- Native rendering, performa 60 FPS, offline cache UI      - Cepat diuji coba di tahap staging
                                   │
                                   ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        API HADIAH BPEDIA PUSAT                         │
│                    (Single Source of Truth, JWT Auth)                  │
├────────────────────────────────────────────────────────────────────────┤
│ • Ledger Kelopak Terpusat (+1 harian, +3 bonus mingguan, klaim roda)   │
│ • State Synchronizer (Streak harian, status putaran Sabtu)             │
│ • Dompet Voucher (Voucher belanja Rp10.000 aktif lintas perangkat)     │
│ • Order Webhook Consumer (Mendeteksi pesanan selesai ≥ Rp75.000)       │
└────────────────────────────────────────────────────────────────────────┘
```

**Aturan Sinkronisasi:**
Semua state terikat pada **ID Akun Pengguna Bpedia**. Pengguna yang check-in melalui iPhone di pagi hari akan langsung melihat status "Sudah check-in hari ini" saat membuka aplikasi melalui ponsel Android atau browser Web di siang hari.

---

## 6. Kontrak Antarmuka Pemrograman Aplikasi (API Contracts v1)

Semua endpoint menggunakan protokol `HTTPS POST`, format payload `application/json`, header autentikasi `Authorization: Bearer <token_sesi_bpedia>`, dan header pencegah duplikasi `Idempotency-Key: <uuid>`.

### 1. Ambil State Lengkap: `POST /v1/rewards/state`
**Respons (200 OK):**
```json
{
  "balance": 10,
  "streak": 7,
  "lastDay": 20781,
  "claimedToday": true,
  "nextClaimAt": "2026-11-25T00:00:00+07:00",
  "products": 0,
  "spin": {
    "available": false,
    "spun": true,
    "lastResult": "3 Kelopak",
    "remainingStock": 1
  },
  "missions": [
    {
      "stage": 1,
      "threshold": 75000,
      "reward": 10000,
      "minSpend": 100000,
      "status": "completed"
    },
    {
      "stage": 2,
      "threshold": 100000,
      "reward": 5000,
      "minSpend": 100000,
      "status": "active"
    }
  ],
  "vouchers": [
    {
      "id": "vch-001",
      "amount": 10000,
      "minimum": 100000,
      "isUsed": false
    }
  ]
}
```

### 2. Klaim Check-in Harian: `POST /v1/checkin/claim`
**Respons (200 OK):**
```json
{
  "receiptId": "chk-9a8f2",
  "awarded": 4,
  "isBonus": true,
  "streak": 7,
  "newBalance": 10,
  "productEntitled": false
}
```

### 3. Putar Roda Sabtu: `POST /v1/spin/commit`
**Payload:**
```json
{ "configVersion": "2026-w47" }
```
**Respons (200 OK):**
```json
{
  "receiptId": "spn-77c1b",
  "prizeType": "kelopak",
  "prizeLabel": "3 Kelopak",
  "awardedAmount": 3,
  "newBalance": 13
}
```

### 4. Webhook Pesanan Selesai: `POST /v1/orders/completed`
**Payload (dari Order Service Bpedia ber-signature HMAC):**
```json
{
  "eventId": "evt-88123",
  "userId": "usr-bpedia-12345",
  "orderId": "ORD-20261124-001",
  "completedAt": "2026-11-24T18:30:00+07:00",
  "eligibleSubtotal": 85000
}
```

---

## 7. Ekosistem Multi-Repository

| Repositori GitHub | Fungsi & Komponen | Tautan Kloning |
|---|---|---|
| **`bpedia-kelopak-hub`** | Pusat arsitektur, shell aplikasi Flutter terpadu, simulator server PHP, dokumentasi lengkap. | `https://github.com/yusufmuh/bpedia-kelopak-hub.git` |
| **`bpedia-daily-checkin`** | Paket modul Flutter Check-in Harian + UI 7 hari & progres 30 hari + unit logic checkin. | `https://github.com/yusufmuh/bpedia-daily-checkin.git` |
| **`bpedia-roda-sabtu`** | Paket modul Flutter Roda Sabtu + UI CustomPainter Dial & Animasi + unit logic RNG spin. | `https://github.com/yusufmuh/bpedia-roda-sabtu.git` |
| **`bpedia-misi-belanja`** | Paket modul Flutter Misi Belanja + UI Kartu Bertingkat (suf) + verifikasi pesanan. | `https://github.com/yusufmuh/bpedia-misi-belanja.git` |

---

## 8. Spesifikasi Hosting & Deployment (Hostinger)

- **Akun Hosting**: Hostinger Cloud/Shared Environment (`yusuf.consultan@gmail.com`).
- **Target Domain**: Subdomain `kelopak.gamysuf.fun` atau staging `silent-mediumseagreen-lemur-77.hostingersite.com`.
- **Runtime Server**: PHP 8.2+ dengan modul `pdo_sqlite` aktif.
- **Isi Direktori `public_html/`**:
  - File statis hasil kompilasi `flutter build web --release`.
  - Folder `server/` berisi `index.php`, `checkin.php`, `spin.php`, dan `missions.php`.
- **Keamanan Basis Data**: Direktori data demo SQLite disimpan di luar web root publik (`../kelopak-demo-data/demo.sqlite`) dengan hak akses `0700` sehingga data tidak dapat dibaca dari URL browser.
- **Otomasi Git Hostinger**: Mengaitkan repositori `yusufmuh/bpedia-kelopak-hub` cabang `main` ke fitur Git Deployment di hPanel Hostinger untuk pembaruan otomatis setiap commit baru.

---

## 9. Pipeline Aset Generatif Berbasis AI

| Kategori Aset | Alat / Engine AI | Panduan Standar Mutu |
|---|---|---|
| **Ikon & Ilustrasi Maskot Bipy** | ComfyUI / Stable Diffusion (`comfyui-game-assets`) | Wajib menggunakan palet warna Blush/Berry, menjaga proporsi Bipy resmi, format WebP transparan ≤ 150 KB. |
| **Musik Latar (BGM) Looping** | Meta AudioCraft MusicGen (`audiocraft-game-music`) | Musik santai ceria bertema belanja, durasi 15-30 detik dengan transisi looping mulus, default dalam keadaan senyap (*muted by default*). |
| **Sound Effects (SFX)** | Stability AI Stable Audio (`stable-audio-sfx`) | SFX klik tombol lembut (40ms), SFX putaran roda (mekanikal klik ritmis), dan SFX fanfare perolehan reward (maks. 1.2 detik). Format OGG & M4A (iOS). |
| **Video Promo / Trailer Mini** | Google Gemini Video / Motion Graphics | Trailer teaser peluncuran program loyalitas Bpedia Kelopak untuk banner carousel aplikasi dan media sosial. |

---

## 10. Kepatuhan Toko Aplikasi (App Store & Play Store Compliance)

1. **Apple App Store Review Guidelines §5.3 (Gaming, Gambling, and Lotteries)**:
   - Fitur Roda Sabtu bersifat promosi cuma-cuma (*free sweepstakes/promotional spin*). Tidak ada pembelian koin dalam aplikasi (*In-App Purchase*) untuk membeli tiket putaran.
   - Tabel peluang hadiah dan kuota stok dicantumkan eksplisit sebelum pengguna berpartisipasi.
   - Syarat & Ketentuan mencantumkan klausul resmi:  
     > *"Apple Inc. bukan sponsor dan tidak terlibat dengan cara apa pun dalam kegiatan promosi, kontes, atau pembagian hadiah Bpedia Kelopak."*
2. **Google Play Store Developer Policy**:
   - Mematuhi pedoman promosi dan hadiah: Penyelenggara resmi adalah PT Bpedia, kriteria kelayakan peserta tertera jelas, dan pemenuhan produk gratis dijamin sesuai stok promosi.

---

## 11. Kriteria Kualitas & Definisi Selesai (Definition of Done)

Sebelum kode di-merge ke branch `main`:
1. `flutter analyze` menghasilkan nol error dan nol peringatan (*zero warnings*).
2. `flutter test` lulus 100% pada seluruh pengujian unit logika:
   - Klaim hari ke-7 memberikan bonus +3 (total 10 Kelopak = Rp1.000).
   - Klaim hari ke-30 memberikan 1 hak produk gratis.
   - Terlewat satu hari mereset streak ke hari ke-1 tanpa menghapus saldo.
   - Roda hanya dapat diputar pada hari Sabtu WIB.
   - Pesanan Rp74.999 ditolak dari misi tahap 1; pesanan Rp75.000 menerbitkan voucher Rp10.000.
   - Voucher Rp10.000 ditolak jika belanja berikutnya di bawah Rp100.000.
3. Permintaan konkuren ganda (*concurrent requests*) menghasilkan tepat satu mutasi saldo (teruji via header idempotency).
4. Responsif dan mulus di layar smartphone Android, iPhone, dan Browser Desktop/Mobile.
