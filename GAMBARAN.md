# Gambaran Arsitektur & Pengalaman Pengguna Bpedia Kelopak

Dokumen visual dan arsitektur resmi per 24 November 2026.
Dibaca bersama `PRD.md` dan `MEMORY.md` untuk memahami alur pengguna, sinkronisasi lintas platform, dan desain visual.

---

## 1. Perjalanan Pengguna (User Journey)

Pengguna masuk melalui menu **"Hadiah"** di aplikasi Bpedia (Play Store, App Store, maupun Web).
Satu dompet poin **Kelopak** menaungi ketiga kegiatan yang saling melengkapi:

```mermaid
flowchart TD
    User([Pengguna Bpedia]) --> Entry[Buka Tab Hadiah di App / Web]
    Entry --> Wallet[Tampilan Saldo Kelopak\n1 Kelopak = Rp100]
    
    Wallet --> Mod1[PRD 1 · Check-in Harian\nAlasan kembali tiap hari]
    Wallet --> Mod2[PRD 2 · Roda Sabtu\nMomen keberuntungan mingguan]
    Wallet --> Mod3[PRD 3 · Misi Belanja\nReward transaksi nyata]
    
    Mod1 --> StateServer[Backend Hadiah Bpedia API]
    Mod2 --> StateServer
    Mod3 --> StateServer
    
    StateServer --> Ledger[(Ledger Saldo Kelopak)]
    StateServer --> VoucherStore[(Dompet Voucher Bpedia)]
    StateServer --> ProductClaim[(Reservasi & Stok Produk)]
    
    Ledger --> Checkout[Digunakan di Checkout Bpedia]
    VoucherStore --> Checkout
```

---

## 2. Rincian Tiga Modul Utama

| Modul | Pengalaman Pengguna | Mekanisme & Syarat | Hasil & Bukti |
|---|---|---|---|
| **PRD 1: Check-in Harian** | • Melihat jejak 7 hari dan progres bulanan 30 hari.<br>• Tombol satu ketuk: *"Ambil 1 Kelopak"*.<br>• Berubah menjadi *"Sudah check-in hari ini"* jika sudah diklaim. | • Harian: +1 Kelopak (Rp100).<br>• Hari ke-7 tanpa bolong: Bonus +3 Kelopak (Total 10 Kelopak = Rp1.000).<br>• Hari ke-30 tanpa bolong: 1 Produk Gratis.<br>• Bolong: reset ke hari 1. | Saldo Kelopak langsung bertambah di ledger server, nomor receipt tersimpan, progres bulanan tercatat. |
| **PRD 2: Roda Sabtu (Gacha)** | • Hanya aktif pada hari Sabtu WIB.<br>• Pengguna melihat tabel peluang (%) dan kuota stok secara transparan sebelum memutar.<br>• Tombol *"Putar Gratis"* (1x per Sabtu). | • Hadiah: Produk Gratis atau Kelopak (3 Kelopak).<br>• Kuota stok riil.<br>• Ongkir dicantumkan jelas (Rp0 pada promo/demo). | Hasil diputuskan server (RNG server), animasi roda berputar dan berhenti sesuai hasil server. Anti-kecurangan. |
| **PRD 3: Misi Belanja (Suf)** | • Melihat daftar misi belanja bertingkat.<br>• Tahap 1 aktif: *"Selesaikan 1 pesanan ≥ Rp75.000"*; Tahap 2 terkunci.<br>• Notifikasi voucher terbit setelah pesanan selesai. | • Belanja ≥ Rp75.000 (status selesai) → Voucher Rp10.000.<br>• Syarat pakai voucher: Min. belanja Rp100.000 di pesanan berikutnya.<br>• Setelah Tahap 1 selesai → Tahap 2 otomatis terbuka. | Voucher personal diterbitkan ke akun pengguna, siap dipasang saat checkout pesanan berikutnya. |

---

## 3. Arsitektur Sinkronisasi Lintas Platform

Semua status disimpan secara terpusat di server backend Bpedia. Perangkat pengguna (iPhone, Android, dan Browser Web) hanya berfungsi sebagai *presentation layer*.

```mermaid
sequenceDiagram
    autonumber
    actor User as Pengguna (iOS / Android / Web)
    participant Client as Flutter Module (UI)
    participant API as Bpedia Rewards API
    participant DB as Central Database (Ledger)
    participant Order as Bpedia Order Service

    Note over User,Client: Pengguna Membuka Halaman Hadiah
    Client->>API: POST /v1/rewards/state (Bearer Token)
    API->>DB: Query saldo, streak, status putaran, & voucher
    DB-->>API: Data Akun Terkini
    API-->>Client: 200 OK (balance, streak, spinStatus, missions)
    Client-->>User: Tampilkan Saldo Kelopak & Status Misi

    Note over User,Client: Check-in Harian
    User->>Client: Ketuk "Ambil 1 Kelopak"
    Client->>API: POST /v1/checkin/claim (Idempotency-Key: UUID)
    API->>DB: Lock Akun & Validasi Hari WIB (Asia/Jakarta)
    API->>DB: Insert Ledger Entry (+1 / +3 Kelopak / Hak Produk)
    DB-->>API: Commit Sukses
    API-->>Client: 200 OK (newBalance, streak, receiptId)
    Client-->>User: Animasi Sukses & Saldo Terkini

    Note over Order,API: Event Pesanan Selesai (Misi Belanja)
    Order->>API: Webhook: order.completed (orderId, amount: 75000, userId)
    API->>DB: Validasi Threshold Tahap 1 (≥ Rp75.000)
    API->>DB: Terbitkan Voucher Rp10.000 & Buka Tahap 2
    DB-->>API: Voucher Saved
```

---

## 4. Panduan Desain & Aksesibilitas (Design System)

| Elemen | Nilai / Kode Warna | Peruntukan |
|---|---|---|
| **Pearl** | `#FFFDFD` | Warna latar belakang utama (bersih, luas, ramah mata). |
| **Blush** | `#F9F0EF` | Warna panel kartu, container modul, dan penanda hari yang belum aktif. |
| **Blush Soft** | `#F6CFDA` | Penanda hari check-in yang sudah berhasil dicapai. |
| **Berry (Primary)** | `#982149` | Tombol aksi utama (CTA), ikon aktif, dan sorotan progres. |
| **Plum (Text)** | `#4B1C2E` | Teks judul dan tulisan utama (kontras tinggi, terbaca jelas). |
| **Gold / Ochre** | `#EAA023` | Aksen hadiah spesial (kado hari ke-7, ikon produk gratis). |
| **Maskot Bipy** | Maskot lebah resmi Bpedia | Menyambut di bagian header atas dengan pose ramah (`maskot pose hai.png`). |

### Aturan Aksesibilitas Wajib:
1. **Target Sentuh**: Semua tombol dan area interaktif memiliki ukuran minimal **48 × 48 dp**.
2. **Pembaca Layar (Screen Reader)**: Setiap komponen membungkus informasinya dengan widget `Semantics` sehingga tuna netra pengguna TalkBack/VoiceOver mendapatkan deskripsi teks yang jelas (misal: *"Hari 1, tercapai"*, *"Peluang produk gratis 10 persen"*).
3. **Mode Kurangi Gerakan (*Reduce Motion*)**: Saat sistem operasi mengaktifkan fitur *Reduce Motion*, animasi putaran roda roulette otomatis ditiadakan dan langsung menampilkan hasil akhir.
4. **Respon Galat Mandiri**: Jika koneksi jaringan terputus, sediakan tombol *"Coba Lagi"* yang memuat ulang status dari server secara aman tanpa risiko duplikasi transaksi.
