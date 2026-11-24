# PRD Pusat · Bpedia Preview (Kelopak)

**Versi 2.0 · 24 November 2026 · Owner: Muhammad Yusuf (Bpedia)**

Dokumen ini adalah sumber kebenaran untuk produk Bpedia Preview: aplikasi belanja Bpedia yang dibangun ulang (clean-room) dengan tiga game hadiah yang memakai satu mata uang, **Kelopak**. Berlaku untuk pengembang manusia dan agen AI (Claude, Codex, Gemini/Antigravity).

Urutan acuan bila ada perbedaan: dokumen ini → `docs/SPEC-CONTRACT.md` (aturan persis dan API modul) → `docs/SPEC-UIUX.md` (layar dan copy; ADDENDUM brand §7 mengalahkan nilai gaya lain) → PRD modul (`../bpedia-daily-checkin/PRD.md`, `../bpedia-roda-sabtu/PRD.md`, `../bpedia-misi-belanja/PRD.md`) → `HANDOFF-PENGEMBANG.md`.

Dokumen ini tidak memuat rahasia, kata sandi, token, atau alamat email. Angka bertanda **(Demo)** adalah nilai contoh yang belum disetujui bisnis.

---

## 0. Ringkasan

| Hal | Nilai |
|---|---|
| Nama tampil | **Bpedia Demo** (label launcher maks. 12 karakter, aturan brand). "Bpedia Preview" adalah nama teknis proyek. |
| ID app | Android `id.bpedia.preview`, iOS `id.bpedia.preview`. Bisa dipasang berdampingan dengan app resmi Bpedia (`com.wot.beautypedia`). |
| Platform | Flutter 3.41.7 / Dart 3.11.5: Android (APK), iOS, web |
| Versi | 2.0.0 (build 20) |
| Status | Prototipe **Mode Demo**: tanpa login dan tanpa backend; semua data di perangkat. Belum dirilis ke toko. |
| Isi | Toko demo (19 produk) + **Check-in Harian**, **Roda Sabtu**, **Misi Belanja**, Hadiahku, Riwayat Kelopak |
| Tautan resmi | `https://bpedia.id` dan unduh app resmi (App Store/Google Play) `https://beautypediaofc.onelink.me/hebt/9fer7r7y`. Root `beautypediaofc.onelink.me/` membalas 403, jadi tidak dipakai. |
| Batas clean-room | Kode dan aset APK produksi tidak dibongkar dan tidak dipakai. UI dibangun dari brand guideline resmi dan screenshot milik owner. |

## 1. Latar belakang

App resmi "Bpedia" (versi 2.0.24, 2 Okt 2026) dan mockup hadiahnya diaudit pada 24 Nov 2026 dari sumber publik, 16 screenshot owner, brand guideline 38 halaman, dan kode v1 (rincian: `docs/research/RISET-2026-11-24.md`). Masalah utama:

| Keparahan | Masalah | Keputusan v2 |
|---|---|---|
| Kritis | Dua sampai tiga mata uang ("Koin Bipy", "Kelopak", koin bintang); mockup menjanjikan produk tiap 10 hari | **Kelopak satu-satunya mata uang** di semua label, ikon, dan copy |
| Tinggi | Pintu masuk tumpang-tindih (Check-in vs Kebun Bipy; tile Gacha vs pop-up); tile tanpa status | Satu pintu per fitur, tile dan kartu selalu menampilkan status |
| Tinggi | Gacha tanpa jadwal, peluang, atau S&K; 2 dari 6 segmen "Produk gratis" | **Roda Sabtu**: segmen sebanding peluang, peluang + kuota + ongkir tampil sebelum tombol |
| Tinggi | Beranda lemah untuk menemukan produk | Cari, kategori, Hot Item, grid produk |
| Sedang | Kartu produk ramai, tanpa tombol keranjang; kontras rendah; bahasa campur; pop-up interstisial | Packshot bersih + badge dari UI, tombol "+ Keranjang", kontras min. 4,5:1, glosarium tunggal, tanpa pop-up |
| Rendah | Format uang/satuan tidak konsisten, typo | Satu formatter: `Rp10.000`; satuan `20 ml` |

Audit kode v1 juga menemukan dokumen lama yang tidak akurat (Bipy disebut lebah, palet `#982149`, domain yang belum aktif, auto-deploy yang tidak bisa memublikasikan build web). Semuanya sudah dikoreksi di v2.

## 2. Tujuan, non-tujuan, ukuran keberhasilan

**Tujuan**

1. **Kebiasaan harian:** membuka app tiap hari untuk satu ketukan "Ambil 1 Kelopak".
2. **Momen mingguan:** menantikan satu putaran gratis Roda Sabtu.
3. **Belanja berulang:** Misi Belanja memberi voucher untuk pesanan berikutnya.
4. **Tidak membingungkan:** setiap layar menjawab *saya di mana, apa yang bisa saya lakukan sekarang, apa yang terjadi setelahnya*.
5. **Jujur dan patuh toko:** peluang, kuota, ongkir, dan S&K terlihat sebelum ikut; nilai yang belum disetujui diberi label "(Demo)".

**Non-tujuan v2:** login, pembayaran sungguhan, stok dan kuota nyata, server produksi, rilis ke toko, serta memakai kode atau aset dari APK produksi.

**Ukuran keberhasilan.** Prototipe tidak mengumpulkan analitik. Setelah server otoritatif ada, ukur: persentase pengguna aktif harian yang check-in, panjang rentetan rata-rata, partisipasi Roda Sabtu per Sabtu, konversi voucher misi menjadi pesanan kedua, dan tiket bantuan terkait hadiah. Target angka ditetapkan owner; dokumen ini tidak mengarang angka.

## 3. Aturan bisnis (wajib persis)

Aturan hanya hidup di tiga modul; hub memanggil fungsi modul dan mencatat hasilnya. Mengubah aturan ekonomi butuh persetujuan owner yang dicatat di `MEMORY.md`.

| Fitur | Aturan |
|---|---|
| **Kelopak** | 1 Kelopak = Rp100. Bilangan bulat, saldo tidak pernah negatif, saldo = jumlah ledger. Ditulis bersama nilai rupiahnya: "10 Kelopak (Rp1.000)". |
| **Hari** | Tanggal WIB (UTC+7, tanpa DST). `wibDay = (utcMillis + 7*3600*1000) ~/ 86400000`; Sabtu bila `((wibDay + 3) % 7) + 1 == 6` (hari 0 = Kamis 1 Jan 1970). Hari berganti 00.00 WIB. |
| **Check-in Harian** | +1 Kelopak per tanggal WIB, sekali per tanggal. Hari ke-7, 14, 21, … beruntun: bonus +3 (7 hari = 10 Kelopak = Rp1.000). Hari ke-30, 60, … beruntun: 1 hak produk gratis (30 hari = 42 Kelopak + 1 produk). Bolong satu tanggal: rentetan mulai lagi dari Hari 1; saldo dan hak yang sudah didapat tetap. |
| **Roda Sabtu** | Gratis, 1 putaran per akun per Sabtu WIB (00.00–23.59) selama promo aktif. Hadiah produk (sesuai stok) atau Kelopak. Peluang (%), sisa kuota, dan ketentuan ongkir tampil **sebelum** tombol putar. Hasil ditentukan engine dengan roll acak 0..9999 sebelum animasi. (Demo) produk 10% dengan stok 1, 3 Kelopak 90%; stok 0: produk 0%, Kelopak 100%; "Gratis ongkir (Demo)". |
| **Misi Belanja** | Tahap 1: pesanan **Selesai** dengan subtotal barang min. Rp75.000 → voucher Rp10.000 untuk pesanan **lain** dengan min. belanja Rp100.000. Tahap N+1 terbuka setelah voucher tahap N terbit. (Demo) tahap 2: min. Rp100.000 → voucher Rp5.000 (min. Rp100.000); sesudahnya "Tahap berikutnya menunggu kampanye". Satu pesanan dihitung sekali; voucher tidak berlaku di pesanan sumbernya; satu voucher misi per pesanan; berlaku 30 hari (Demo), sampai akhir hari ke-30 setelah terbit. |
| **Pakai Kelopak** (Demo) | Potongan di checkout maks. 50% dari total setelah voucher, dibatasi saldo. Tercatat sebagai debit ledger. Menunggu keputusan bisnis. |

Subtotal misi = harga barang sebelum ongkir dan sebelum potongan voucher/Kelopak. Pesanan yang dibayar, dikirim, dibatalkan, atau diretur tidak dihitung; hanya status Selesai.

## 4. Fitur dan alur

Detail layar, keadaan, dan copy: `docs/SPEC-UIUX.md` §3. Alur bergambar: `GAMBARAN.md`.

### 4.1 Navigasi

Empat tab dengan label selalu tampil: **Beranda, Hadiah, Transaksi, Akun**. Keranjang di kanan atas Beranda dengan badge jumlah. Tidak ada tab "Menu", ikon notifikasi, atau pop-up saat app dibuka. Titik di tab Hadiah muncul bila check-in hari ini belum diambil atau Roda Sabtu siap diputar. Tombol kembali Android di tab selain Beranda kembali ke Beranda.

### 4.2 Belanja (Mode Demo)

- **Beranda:** cari, kartu "Kelopak hari ini" (ambil langsung dari Beranda), "Main bareng Bipy" (3 tile dengan status), kategori, Hot Item, grid produk (2 kolom; 3 di atas 600 dp; 4 di atas 900 dp).
- **Katalog:** 19 produk dari snapshot bpedia.id 24 Nov 2026 ±20.50 WIB; harga bisa berubah; foto adalah ilustrasi dan ditandai "Foto ilustrasi · Mode Demo".
- **Detail produk:** foto (beranimasi dari kartu ke detail), harga Berry + harga coret, badge Original, info misi aktif, "Produk lain"; bar bawah stepper + "Tambah ke keranjang".
- **Keranjang:** stepper (maks. 99 per produk), hapus dengan "Urungkan", progres misi ("Tambah Rp12.000 lagi …").
- **Checkout:** alamat demo, "Gratis ongkir (Demo)", voucher (voucher paling bernilai yang bisa dipakai dipilih otomatis; yang belum memenuhi tampil abu-abu dengan alasan "Belanja Rp8.000 lagi"), switch Pakai Kelopak, rincian harga, "Bayar sekarang (simulasi)".
- **Pesanan:** nomor `BP-YYYYMMDD-NNNN`, status **Dikirim** → tombol "Pesanan Diterima" (dengan konfirmasi) → **Selesai** → Misi Belanja dinilai, hasil tampil di lembar hasil (voucher terbit atau alasan, mis. "Subtotal Rp60.000, belum mencapai min. Rp75.000").

### 4.3 Hadiah

Header saldo besar "12 Kelopak", "Setara Rp1.200", tautan Riwayat. Empat kartu berstatus: Check-in Harian, Roda Sabtu, Misi Belanja, Hadiahku. Hanya satu kartu yang memegang tombol utama (check-in bila tersedia, kalau tidak roda bila tersedia). Footer "Cara kerja Kelopak".

### 4.4 Check-in Harian

Jejak 7 hari bergaya tulip (Kebun Bipy dilebur di sini: kuncup = belum, mekar = sudah, slot hari ini berdenyut halus, slot 7 = kado bonus +3), satu tombol "Ambil 1 Kelopak", progres 30 hari menuju produk gratis, peringatan lembut bila rentetan putus, dan "Cara kerja" dengan tabel contoh (hari 1 = 1, hari 7 = 10, hari 14 = 20, hari 30 = 42 + produk). Setelah klaim: ledakan kelopak, suara dan getar sesuai tingkat hadiah, lembar hasil, langkah berikutnya "Kembali besok mulai 00.00 WIB · Hari ke-N".

### 4.5 Roda Sabtu

Status di atas roda (Siap diputar / Buka Sabtu, tanggal · 00.00 WIB dengan hitung mundur / Sudah diputar Sabtu ini / Promo tidak aktif). Segmen sebanding peluang. **Tabel peluang di atas tombol** (peluang %, sisa kuota produk, ongkir). "Putar gratis" hanya aktif bila tersedia; selama berputar menjadi "Lewati animasi". Hasil tetap tertulis di kartu "Hasil Sabtu ini" setelah app dibuka ulang, dengan segmen roda yang sama seperti saat diputar (stok sebelum putaran ikut disimpan). S&K lengkap termasuk "Apple bukan sponsor dan tidak terlibat dalam promosi ini." dan kalimat yang sama untuk Google.

### 4.6 Misi Belanja

Tangga misi vertikal (Selesai / Aktif / Terkunci, lalu "Tahap berikutnya menunggu kampanye"), pesanan Dikirim yang akan memenuhi syarat tampil "menunggu diterima", tombol "Belanja sekarang", dan "Voucher saya" (Aktif / Terpakai / Kedaluwarsa).

### 4.7 Hadiahku dan Riwayat Kelopak

Hadiahku: tab Voucher dan Produk gratis (hak dari check-in hari ke-30 dan roda; status "Menunggu pengiriman (Demo)"). Riwayat: ledger dikelompokkan per tanggal WIB, +/− dan saldo berjalan; kosong = Bipy ngintip + "Ambil Kelopak pertamamu".

### 4.8 Akun dan Mode Demo (QA)

Profil "Pengguna Demo", Hadiahku, Riwayat Kelopak, Suara & getar (efek suara, musik latar bawaan mati, getar), Tampilan (Ikuti sistem / Terang / Gelap), **Mode Demo (QA)**: tanggal WIB simulasi, +1 hari, +7 hari, Lompat ke Sabtu berikutnya, promo Roda aktif, isi ulang stok produk roda, Reset semua data (dengan konfirmasi; pengaturan tetap). Syarat & Ketentuan Program memakai angka dari konfigurasi yang sama dengan undian. Tentang aplikasi: versi, "Prototipe clean-room Bpedia, data demo di perangkat", "Unduh app Bpedia resmi", "Buka bpedia.id".

## 5. UX, brand, dan aksesibilitas

**Prinsip** (`docs/SPEC-UIUX.md` §1): satu tombol utama per layar; bahasa sederhana ("Ambil 1 Kelopak", "Putar gratis", "Pakai voucher"); angka selalu lengkap; status selalu teks + ikon; selalu ada langkah berikutnya; aturan bisa dibuka di tempat ("Cara kerja"); tanpa pop-up paksa; umpan balik terasa; hormati preferensi; jujur soal demo (chip "DEMO" di layar Hadiah dan Checkout).

**Glosarium tunggal:** Check-in Harian, Roda Sabtu, Misi Belanja, Kelopak, Hadiahku, Voucher. Sentence case. "Sign In", "klaim", "redeem", dan "entitlement" tidak dipakai di UI.

**Brand** (ADDENDUM `docs/SPEC-UIUX.md` §7):

- Warna token brand: pink-600 `#D81F57` (tombol utama), berry-700 `#B3164B` (harga, tombol sekunder dan tersier), plum-900 `#45122B` (teks), ink-700 `#6E4556` (teks sekunder), pearl-50 `#FFF7F8` (latar), blush-100 `#FDE7EC` (panel), honey-400 `#F5B83D` (aksen hadiah). Tema gelap "Berry Night" mengikuti token gelap brand; karena panel blush dan kartu bernilai sama di Berry Night, isian di atas kartu (chip aktif, pill, segmen terpilih) memakai pink-200 gelap `#5A1A36`.
- Tombol berbentuk **pil**, tinggi 52, padding horizontal 24, label Poppins 16 w600. Primer: isi pink-600. Sekunder: isi putih, garis dan label Berry (mis. "+ Keranjang"). Tersier: teks Berry.
- Poppins 400–800 untuk semua UI; Fraunces italic hanya untuk tagline "Belanja Bikin Bahagia.". Glyph `≥ → ✓ ★ ♥` tidak ada di font brand, jadi tidak dipakai di UI.
- Logo AppBar: wordmark + Bipy (`logo_wordmark_bipy.webp`, gelap `logo_wordmark_reverse.webp`).
- Ikon: set SVG brand (grid 24, stroke 1,8; mono untuk tab bar, berwarna untuk konten). Ikon Transaksi berupa struk digambar dengan aturan grid dan warna yang sama, supaya tidak memakai ikon tas yang sama dengan keranjang.
- **Bipy** adalah gadis chibi bertudung tulip pink (bukan lebah). Hanya render resmi di `assets/images`, satu Bipy per layar, pose sesuai pesan; file 2D `cha1 1.png` dan `maskot pose hai.png` tidak dipakai; tidak ada varian buatan AI.
- Voice: hangat, ceria, jujur; sapa "Babes" di momen sapaan dan sukses; tanpa hard-sell, tanpa klaim "memutihkan/menyembuhkan/permanen/100%", tanpa emoji.

**Umpan balik** (`docs/SPEC-UIUX.md` §4): check-in `claim` + getar ringan; bonus `bonus` + getar sedang; produk gratis `win_product` + getar kuat; roda `spin_start`, `tick` per pasak (maks. 25/detik) dan klik getar (maks. 12/detik); voucher terbit `unlock`; gagal `soft_error`. Efek suara tidak memotong musik app lain (Android tanpa audio focus, iOS ambient). Musik latar hanya di tab Hadiah dan layar game, bawaan mati.

**Aksesibilitas:** target sentuh min. 48 dp; label Semantics di setiap kontrol; teks sampai 200% tanpa terpotong (layar 360 dp); kontras teks min. 4,5:1; status tidak hanya warna; animasi dilewati bila "kurangi gerakan" aktif; tooltip dan label bawaan Material berbahasa Indonesia ("Kembali", "Tutup").

## 6. Server dan kontrak API

### 6.1 Saat ini

App tidak memanggil server. `server/` berisi **simulator PHP** (contoh perilaku untuk tim backend) yang memakai berkas aturan modul tanpa diubah (`checkin.php`, `spin.php`, `missions.php`) lewat router `index.php`: aksi `open`, `read`, `checkin`, `spin` (roll 0..9999), `order`, `redeem`, `advance`, `promo`, `refill`, sesi `X-Demo-Session`, cek `revision` + `day` (409 bila basi), SQLite di luar web root. Cara menjalankan: `HANDOFF-PENGEMBANG.md` §9.

### 6.2 Usulan kontrak produksi (belum dibangun)

Semua endpoint `HTTPS POST`, JSON, `Authorization: Bearer <sesi Bpedia>`, dan `Idempotency-Key: <uuid>` di setiap mutasi (pengulangan tidak menggandakan saldo, voucher, atau putaran). State terikat **akun Bpedia**, bukan perangkat, sehingga sama di Android, iOS, dan web.

| Endpoint | Isi |
|---|---|
| `POST /v1/rewards/state` | Saldo; check-in (`liveStreak`, `claimedToday`, `filledInWeek`, `dayInMonthCycle`, `nextClaimAt` 00.00 WIB); roda (`eligibility`, `configVersion`, peluang efektif dalam basis poin total 10000, sisa stok, catatan ongkir, hasil Sabtu ini); misi (tahap + status, voucher + status); hak produk. Bentuknya sama dengan respons `read` simulator. |
| `POST /v1/checkin/claim` | Mengembalikan award modul (`streak`, `dailyKelopak`, `bonusKelopak`, `productEntitled`, `totalKelopak`), `newBalance`, `receiptId`. Klaim kedua di tanggal WIB yang sama: tanpa mutasi, pesan "Kamu sudah check-in hari ini. Kembali besok mulai 00.00 WIB." |
| `POST /v1/spin/commit` | Body `configVersion`. Server mengecek kelayakan, mengambil roll 0..9999 dari RNG server, mengurangi kuota secara atomik, lalu mengembalikan `prizeId`, `prizeKind`, `prizeLabel`, `kelopak`, `landingSeed`, peluang saat putaran, `newBalance`, `receiptId`. Klien hanya menganimasikan ke `prizeId`. Versi konfigurasi basi: 409 + konfigurasi terbaru. |
| `POST /v1/orders/completed` | Webhook dari layanan pesanan, ditandatangani HMAC: `eventId`, `userId`, `orderId`, `completedAt`, `eligibleSubtotal`. Satu-satunya pemicu Misi Belanja; idempoten per `eventId` dan `orderId`. |
| `POST /v1/checkout/rewards` | Saat checkout: validasi voucher (`redeemProblem`) dan batas Kelopak, lalu kunci voucher/Kelopak sampai pesanan dibayar atau batal. |

Pesan galat memakai bahasa UI yang sama dengan app. Detail per modul: PRD modul masing-masing.

## 7. Arsitektur aplikasi

| Bagian | Isi |
|---|---|
| Repo | `bpedia-kelopak-hub` (paket `kelopak_hub`, app) + modul `bpedia-daily-checkin` (`daily_checkin`), `bpedia-roda-sabtu` (`roda_sabtu`), `bpedia-misi-belanja` (`misi_belanja`), semuanya bersebelahan; hub memakai modul lewat path `../bpedia-*`. |
| Modul | Fungsi aturan murni + widget yang hanya memakai `Theme.of(context)`: `CheckInWeekTrack`, `CheckInMonthProgress`, `CheckInClaimButton`; `SaturdayWheel`, `OddsTable`; `MissionLadder`, `VoucherCard`, `rupiah()`. API persis: `docs/SPEC-CONTRACT.md` §2. |
| Hub | `AppState` (ChangeNotifier lewat `AppScope`) memegang jam WIB + offset demo, `RewardsEngine` (ledger, check-in, roda, voucher, hak produk), `ShopEngine` (keranjang, checkout, pesanan), pengaturan, suara, dan getar. Engine deterministik: `today`, `roll`, dan `landingSeed` selalu disuntik; acak dari `Random.secure()`. |
| Penyimpanan | Satu dokumen JSON di shared_preferences (`SharedPreferencesAsync`), kunci `bpedia_preview_state_v1`, `"schema": 1`. Dokumen rusak atau skema tak dikenal: mulai baru tanpa crash; gagal baca tidak pernah menimpa data. Simpan berjalan di latar dan berurutan. |
| Paket | audioplayers 6.7.1, shared_preferences 2.5.6, flutter_svg 2.3.4, url_launcher 6.3.3, flutter_localizations (SDK); dev: flutter_launcher_icons 0.14.4, flutter_native_splash 2.4.7, flutter_lints 6.0.0. Versi lebih baru beberapa paket tidak resolve di Flutter 3.41.7. |
| Bahasa | Locale tunggal `id` dengan delegasi Material, Cupertino, dan Widgets. |

## 8. Data, privasi, dan keamanan

- Tidak ada akun, login, lokasi, kontak, atau data pribadi. Profil "Pengguna Demo". Data demo hanya di perangkat (Android DataStore, iOS NSUserDefaults, web localStorage per origin).
- Tidak ada analitik atau pelacak.
- Tautan keluar hanya ke `bpedia.id` dan tautan unduh resmi, dibuka di aplikasi luar.
- Kunci rilis Android dibaca dari `android/key.properties` (diabaikan Git, tidak pernah di-commit atau ditampilkan). Repo publik: jangan menulis secret, kata sandi, token, atau alamat email ke kode maupun dokumen.

## 9. Kepatuhan toko

| Syarat | Status |
|---|---|
| Apple 5.3 / Google Play: undian gratis tanpa pembelian, aturan resmi di app | Roda Sabtu gratis; tidak ada pembelian putaran dengan uang atau Kelopak; S&K di Akun > Syarat & Ketentuan Program dan di layar roda |
| Peluang dan kuota sebelum ikut | `OddsTable` di atas tombol "Putar gratis"; angka dari konfigurasi yang sama dengan undian |
| Apple dan Google bukan sponsor | Kalimat tercantum di S&K |
| Penyelenggara = pengembang app di toko | **Perlu keputusan owner**: nama pengembang di App Store dan Google Play berbeda |
| Listing app resmi | **Perlu diperbaiki owner**: tautan kebijakan privasi kedua toko mengarah ke `web.indobeauty.id` (app lain); App Store mencantumkan rating 18+ dan bahasa "English" saja |

## 10. Aset dan pipeline kreatif

- Aset di `assets/`: font brand (Poppins, Fraunces), render resmi Bipy dan logo, foto ilustrasi produk katalog demo, token Kelopak 3D, kado 3D, latar header Hadiah, 24 ikon SVG brand (versi mono dan berwarna) ditambah ikon Transaksi, 10 audio (`claim` dengan motif brand "Bi-py" E6 → A6, `bonus`, `win_product`, `spin_start`, `tick`, `unlock`, `soft_error`, `tap`, `brand_notifikasi`, `bgm_jingle`), ikon launcher dengan pita "DEMO", dan splash terang/gelap.
- Alat generatif (gambar, musik, efek suara, 3D, video) boleh dipakai untuk aset **non-Bipy** dengan syarat: palet dan gaya brand, efek suara maks. 2,5 detik, musik loop mulus dan bawaan mati, gambar WebP ringan, dan dicek manusia sebelum masuk repo. Bipy tidak pernah dibuat ulang atau divariasikan dengan AI.
- Ikon launcher dan splash dibuat ulang dengan `dart run flutter_launcher_icons` dan `dart run flutter_native_splash:create` dari berkas di `assets/launcher/`.

## 11. Kualitas dan definisi selesai

Wajib di hub dan di setiap modul yang disentuh, sebelum merge atau rilis:

1. `flutter analyze` → "No issues found!" (strict-casts, strict-inference, strict-raw-types, lint tambahan).
2. `flutter test` → semua lulus.
3. Tanpa `print`/`debugPrint`, TODO/FIXME/placeholder, delay palsu, kode yang dikomentari, API deprecated (`withOpacity`, `SemanticsService.announce`, `WillPopScope`, `MaterialStateProperty`).
4. Perubahan UI dicek di terang, gelap, dan teks 200%; build web dibuka di browser tanpa error console.

Uji penerimaan bisnis (otomatis di modul dan hub):

| ID | Kriteria |
|---|---|
| AT-K1 | 7 klaim beruntun = 10 Kelopak (Rp1.000); hari ke-14 = 20 |
| AT-K2 | Hari ke-30 = 42 Kelopak + tepat 1 hak produk |
| AT-K3 | Bolong satu tanggal: rentetan kembali ke 1, saldo dan hak tetap; klaim ganda dan jam mundur ditolak |
| AT-R1 | Roda hanya Sabtu WIB (batas Jumat 23.59 / Sabtu 00.00 dan Sabtu 23.59 / Minggu 00.00), sekali per Sabtu, tidak saat promo nonaktif |
| AT-R2 | Peluang efektif selalu total 10000; stok 0 → produk 0%, Kelopak 100%; roll di luar 0..9999 ditolak |
| AT-R3 | Tabel peluang, kuota, dan ongkir tampil sebelum tombol; hasil sama dengan engine dan tetap tampil setelah app dibuka ulang |
| AT-M1 | Pesanan Rp74.999 tidak memenuhi tahap 1; Rp75.000 menerbitkan voucher Rp10.000; satu pesanan dihitung sekali |
| AT-M2 | Voucher ditolak di bawah Rp100.000, di pesanan sumbernya, setelah dipakai, dan setelah kedaluwarsa (hari ke-30 masih berlaku) |
| AT-C1 | Potongan Kelopak maks. 50% dari total setelah voucher dan tidak melebihi saldo; tercatat sebagai debit |
| AT-U1 | Semua layar muat di 360 × 740 dengan teks 200% di terang dan gelap tanpa overflow |
| AT-U2 | Target sentuh, label, dan kontras teks lolos pedoman di terang dan gelap |

## 12. Repo, build, dan rilis

| Repo | URL |
|---|---|
| Hub | `https://github.com/yusufmuh/bpedia-kelopak-hub` |
| Check-in Harian | `https://github.com/yusufmuh/bpedia-daily-checkin` |
| Roda Sabtu | `https://github.com/yusufmuh/bpedia-roda-sabtu` |
| Misi Belanja | `https://github.com/yusufmuh/bpedia-misi-belanja` |

- APK: `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk` (minSdk 24 / Android 7.0+, targetSdk 36). Ditandatangani kunci preview bila `android/key.properties` ada; tanpa berkas itu memakai kunci debug mesin pembangun.
- Web: `flutter build web --release` → `build/web`. Folder `build/` diabaikan Git, jadi hosting statis diisi manual atau lewat CI; domain hosting belum diputuskan.
- iOS: butuh macOS, Xcode, dan akun Apple Developer owner; tim signing belum diisi.
- Tag rilis belum ada di keempat repo. Integrasi ke app resmi mengunci modul ke tag rilis (sampai tag ada, ke hash commit). Langkah lengkap: `HANDOFF-PENGEMBANG.md` §8 dan §11.

## 13. Risiko dan keputusan terbuka

1. **Server otoritatif** (ledger, undian dengan RNG server, kuota nyata, voucher, idempotensi, webhook ber-HMAC): kapan dan oleh siapa dibangun. Tanpa ini, angka di perangkat bisa dimanipulasi dan tidak boleh dipakai untuk hadiah sungguhan.
2. Apakah Kelopak boleh dipakai di checkout, dan batasnya.
3. Nilai roda, tahap misi 2 dan seterusnya, dan masa berlaku voucher untuk produksi.
4. Entitas penyelenggara di S&K Roda Sabtu (lihat §9).
5. Perbaikan listing app resmi (kebijakan privasi, rating usia, bahasa).
6. Pemenuhan produk gratis: stok, pengiriman, dan subsidi ongkir.
7. Hosting web preview dan domainnya.

## 14. Riwayat

| Versi | Tanggal | Perubahan |
|---|---|---|
| 1.0 | 24 Nov 2026 | PRD pusat pertama: aturan Kelopak, tiga modul, sketsa API, simulator PHP. |
| 2.0 | 24 Nov 2026 | Rombak total berdasarkan riset dan audit UX: Bpedia Preview clean-room dengan Mode Demo, toko demo + tiga game, IA 4 tab, brand resmi, aksesibilitas, `docs/SPEC-CONTRACT.md` dan `docs/SPEC-UIUX.md`. Klaim v1 yang keliru dihapus (Bipy sebagai lebah, palet `#982149`, domain dan auto-deploy yang belum ada, alamat email). Integrasi: nama tampil "Bpedia Demo", tombol pil, Berry Night dengan isian yang terlihat di atas kartu, bahasa Indonesia untuk widget bawaan, ikon Transaksi sendiri, foto produk beranimasi ke detail, segmen roda tersimpan bersama putaran, simulator PHP memakai berkas aturan modul. |
