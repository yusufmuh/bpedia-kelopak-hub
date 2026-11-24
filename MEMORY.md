# Memori Proyek · Bpedia Preview / Kelopak

Catatan keputusan yang mengikat, dengan tanggal. Aturan ekonomi di bawah hanya boleh diubah dengan persetujuan owner yang dicatat di sini. Angka bertanda **(Demo)** adalah nilai contoh yang belum disetujui bisnis.

Owner: Muhammad Yusuf (Bpedia).

---

## 1. Keputusan owner: aturan bisnis (24 Nov 2026)

| Topik | Keputusan |
|---|---|
| Mata uang | **Kelopak** adalah satu-satunya mata uang hadiah. 1 Kelopak = Rp100. Bilangan bulat, saldo tidak pernah negatif, saldo = jumlah ledger. |
| Hari | Pergantian hari pukul **00.00 WIB** (UTC+7). |
| Check-in Harian | +1 Kelopak per tanggal WIB, sekali per tanggal. Hari ke-7, 14, 21, … beruntun: bonus +3 (7 hari = 10 Kelopak = Rp1.000). Hari ke-30, 60, … beruntun: 1 hak produk gratis. Bolong 1 tanggal: rentetan mulai lagi dari Hari 1; saldo dan hak yang sudah didapat tetap. 30 hari beruntun = 42 Kelopak + 1 produk. |
| Roda Sabtu | Gratis, 1 putaran per akun per Sabtu WIB (00.00–23.59) selama promo aktif. Hadiah produk (sesuai stok) atau Kelopak. Peluang (%), sisa kuota, dan ketentuan ongkir tampil **sebelum** tombol putar. Hasil ditentukan engine/server, bukan animasi. |
| Misi Belanja | Tahap 1: pesanan **Selesai** dengan subtotal barang min. Rp75.000 → voucher Rp10.000 untuk pesanan **lain** berikutnya dengan min. belanja Rp100.000. Tahap berikutnya terbuka setelah voucher tahap sebelumnya terbit. Satu pesanan dihitung sekali. Voucher tidak bisa dipakai di pesanan sumbernya. |
| Repo | 4 repo publik di akun GitHub `yusufmuh`: hub + 3 modul. |

## 2. Keputusan desain v2 (24 Nov 2026)

Dasar: audit UX 16 screenshot owner, brand guideline resmi 38 halaman, dan audit kode v1 (`docs/research/RISET-2026-11-24.md`).

| # | Keputusan | Alasan |
|---|---|---|
| 1 | Bangun ulang **clean-room** sebagai **Bpedia Preview** (`id.bpedia.preview`), terpisah dari app resmi `com.wot.beautypedia`. APK produksi tidak dibongkar. | Tidak memakai kode/aset milik pihak lain; bisa dipasang berdampingan untuk demo. |
| 2 | **Kelopak satu-satunya mata uang** di semua label, ikon, dan copy. "Koin Bipy" dan koin bintang dihapus. | Mockup lama memakai 2–3 mata uang yang membingungkan. |
| 3 | **Kebun Bipy dilebur ke Check-in Harian** sebagai visual: 7 tulip yang mekar per hari check-in. Satu tombol check-in saja. | Kebun Bipy lama hanya progress bar dengan tombol check-in kedua. |
| 4 | Nama fitur **Roda Sabtu** (bukan "Gacha Bipy"). Satu pintu masuk, segmen roda sebanding peluang, tanpa pop-up. | Roda lama: 2 dari 6 segmen "Produk gratis" tanpa peluang, jadwal, atau S&K. |
| 5 | Navigasi 4 tab: **Beranda, Hadiah, Transaksi, Akun**. Tab "Menu" dan ikon notifikasi dihapus. Keranjang di kanan atas Beranda. | Tab "Menu" ambigu; notifikasi tanpa fitur = jalan buntu. |
| 6 | Tanpa pop-up saat app dibuka. Ajakan check-in cukup satu kartu di Beranda. | Pop-up interstisial menutup Beranda. |
| 7 | Glosarium tunggal: Check-in Harian, Roda Sabtu, Misi Belanja, Kelopak, Hadiahku, Voucher. Sentence case. "Sign In" tidak dipakai. Uang selalu "Rp10.000". | Bahasa campur dan satu fitur punya banyak nama. |
| 8 | **Mode Demo**: tanpa login dan backend; data di perangkat; alat uji di Akun > Mode Demo (QA). | Prototipe harus bisa dicoba penuh tanpa server. |
| 9 | Visual mengikuti **token brand**: pink-600 `#D81F57` (tombol), berry-700 `#B3164B` (harga), plum-900 `#45122B` (teks), ink-700 `#6E4556` (teks sekunder), pearl-50 `#FFF7F8` (latar), blush-100 `#FDE7EC` (panel), honey-400 `#F5B83D` (aksen). Tema gelap "Berry Night". Palet lama `#982149` tidak dipakai. | Palet v1 bukan palet brand. |
| 10 | **Bipy** adalah maskot gadis chibi bertudung tulip pink (bukan lebah). Pakai render resmi saja, satu Bipy per layar, pose sesuai pesan. Tidak membuat varian Bipy dengan AI; file 2D `cha1 1.png` dan `maskot pose hai.png` tidak dipakai. | Aturan brand guideline. |
| 11 | Tipografi Poppins 400–800; Fraunces italic hanya untuk tagline "Belanja Bikin Bahagia.". Glyph `≥ → ✓` tidak dipakai di UI karena tidak ada di font brand. | Font brand adalah subset Latin. |
| 12 | Umpan balik: animasi kelopak + suara + getar ringan + lembar hasil. Musik latar bawaan **mati** dan hanya di tab Hadiah/layar game. Suara tidak memotong musik app lain. Animasi dilewati bila "kurangi gerakan" aktif. | Terasa memuaskan tanpa mengganggu. |
| 13 | Aksesibilitas: target sentuh 48 dp, label Semantics, teks sampai 200% tanpa terpotong, status selalu teks + ikon. | Standar brand dan toko. |
| 14 | Tema terang/gelap/ikuti sistem bisa dipilih di Akun > Tampilan. | Hormati preferensi pengguna. |
| 15 | Nama tampil **"Bpedia Demo"** di Android, iOS, web, dan Tentang; "Bpedia Preview" hanya nama teknis. `applicationId` tetap `id.bpedia.preview`. | ADDENDUM brand: label di bawah ikon maks. 12 karakter. |
| 16 | Tombol berbentuk pil (52 dp). Di Berry Night, isian di atas kartu (`primaryContainer`, `surfaceContainer`) memakai pink-200 gelap, bukan blush gelap. | UI kit brand; token blush gelap sama dengan warna kartu sehingga chip, pill, dan segmen terpilih hilang. |
| 17 | Widget bawaan Flutter memakai bahasa Indonesia (locale `id`). | Tidak ada teks Inggris yang tersisa ("Back", "Dismiss"). |
| 18 | Tab Transaksi memakai ikon struk bergaya set brand (grid 24, stroke 1,8), bukan ikon tas. | Ikon tas sudah dipakai tombol keranjang; satu ikon untuk dua fitur membingungkan. |

## 2b. Keputusan hasil review (25 Nov 2026)

| # | Keputusan | Alasan |
|---|---|---|
| 19 | Waktu buka Roda Sabtu ditulis sama di semua layar lewat satu helper (`SpinOpening`): "Sabtu, 28 Nov · 00.00 WIB" + "3 hari lagi" (hari kalender), pada hari Jumat "22 jam 40 menit lagi". | Permintaan owner: Beranda menulis "3 hari lagi" sementara Hadiah menulis "2 hari 22 jam lagi" pada saat yang sama. |
| 20 | Batas Kelopak di checkout tertulis "Maks. 50% dari total setelah voucher (Demo)" di checkout, Cara kerja, dan S&K (`kelopakCapRule`), sama dengan engine. | Tiga teks sebelumnya menyebut dua dasar berbeda. |
| 21 | Janji voucher Misi Belanja hanya untuk pesanan yang pasti menyelesaikan tahap (satu-satunya yang menunggu); bila ada beberapa, teks menyebut yang lebih dulu diterima. | Satu pesanan menyelesaikan satu tahap; pesanan kedua tidak mendapat voucher tahap yang sama. |
| 22 | "Unduh app Bpedia resmi" membuka halaman App Store/Google Play langsung, bukan OneLink AppsFlyer (pid=Blog, c=hot_sale). | Demo tidak melacak penggunanya. OneLink khusus demo bisa dipakai bila marketing membuatnya. |
| 23 | Dokumen simpan punya `revision`; tab browser yang tertinggal mengadopsi data terbaru, tidak menimpanya. | Tab kedua sempat menghapus pesanan dan check-in tab pertama. |

## 3. Nilai Demo (menunggu keputusan bisnis)

| Nilai | Demo |
|---|---|
| Pakai Kelopak di checkout | Maks. 50% dari total setelah voucher, dibatasi saldo |
| Roda Sabtu | Produk gratis 10% (stok 1) / 3 Kelopak 90%; stok habis: produk 0%, Kelopak 100%; "Gratis ongkir (Demo)" |
| Misi tahap 2 | Pesanan selesai min. Rp100.000 → voucher Rp5.000 (min. belanja Rp100.000); sesudahnya "Tahap berikutnya menunggu kampanye" |
| Masa berlaku voucher misi | 30 hari setelah terbit |
| Katalog | 19 produk dari snapshot bpedia.id 24 Nov 2026 ±20.50 WIB; harga dan stok bisa berubah; gambar adalah ilustrasi |

## 4. Fakta yang sudah dicek (24 Nov 2026)

- App resmi: "Bpedia", Android `com.wot.beautypedia`, versi 2.0.24 di kedua toko (sumber publik).
- Tautan resmi yang dipakai app: `https://bpedia.id`, App Store `https://apps.apple.com/app/id6751265630`, dan Google Play `https://play.google.com/store/apps/details?id=com.wot.beautypedia` (keduanya dicek 25 Nov 2026: halaman app "Bpedia"). OneLink resmi `beautypediaofc.onelink.me/hebt/9fer7r7y` adalah redirect atribusi AppsFlyer (pid=Blog, c=hot_sale, deep link Hot Sale), jadi tidak dipakai demo.
- `kelopak.gamysuf.fun` **belum aktif** (tidak ada di DNS); hanya kandidat hosting web preview.
- Belum ada tag rilis di keempat repo.

## 5. Perlu keputusan owner

1. Server otoritatif (ledger, undian dengan RNG server, kuota produk nyata, voucher), `Idempotency-Key`, dan webhook pesanan selesai ber-HMAC: kapan dan oleh siapa dibangun.
2. Apakah Kelopak boleh dipakai di checkout, dan batasnya.
3. Nilai roda, tahap misi 2 dan seterusnya, serta masa berlaku voucher untuk produksi.
4. Entitas penyelenggara di S&K Roda Sabtu: Apple 5.3 mensyaratkan kontes disponsori pengembang app, sedangkan nama pengembang di App Store dan Google Play berbeda.
5. Listing app resmi: tautan kebijakan privasi mengarah ke `web.indobeauty.id` (app lain); App Store mencantumkan rating 18+ dan bahasa "English" saja.
6. Hosting web preview dan domainnya.

## 6. Riwayat

| Tanggal | Peristiwa |
|---|---|
| 24 Nov 2026 | v1: PRD pusat dan tiga PRD modul, logika awal, simulator PHP. |
| 24 Nov 2026 | Riset dan audit (sumber publik, 16 screenshot owner, brand guideline, kode v1): 39 temuan; dokumen lama tidak akurat (Bipy disebut lebah, palet `#982149`, tag yang belum ada, checklist kepatuhan yang belum diverifikasi, domain yang belum aktif). |
| 24 Nov 2026 | v2 dimulai: Bpedia Preview clean-room, spesifikasi `docs/SPEC-CONTRACT.md`, `docs/SPEC-UIUX.md`, keputusan desain di atas. |
| 24 Nov 2026 | v2 terintegrasi: modul 2.0.0, hub (toko demo, Hadiah, Transaksi, Akun), PRD pusat 2.0, keputusan 15–18, simulator PHP memakai berkas aturan modul. APK rilis dan build web dibuat dari kode ini. |
| 25 Nov 2026 | Review 40 temuan diperbaiki (keputusan 19–23, aksesibilitas, ikon, lokalisasi iOS, batas simulator). APK `Bpedia-Demo-v2.0.0-universal.apk` dan `Bpedia-Demo-v2.0.0-arm64.apk` dibangun dari kode ini. Push ke GitHub dan tag `v2.0.0` belum dilakukan: menunggu persetujuan owner. |
