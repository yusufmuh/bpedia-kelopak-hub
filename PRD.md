# PRD Pusat · Bpedia Demo v3 (sistem Kelopak)

**Versi 3.0 · 26 November 2026 · Owner: Muhammad Yusuf (Bpedia)**

Sumber kebenaran produk untuk sistem poin **Kelopak** dan tiga game hadiahnya di Bpedia Demo v3. Berlaku untuk pengembang manusia dan agen AI.

Urutan acuan bila berbeda: aturan bisnis `bpedia-asset-build/v3/KEPUTUSAN-V3.md` → desain `SPEC-V3.md` → dokumen ini → `docs/SPEC-CONTRACT.md` (kontrak data dan API) → PRD modul (`../bpedia-daily-checkin/PRD.md`, `../bpedia-roda-sabtu/PRD.md`, `../bpedia-misi-belanja/PRD.md`) → `HANDOFF-PENGEMBANG.md`.

Tidak ada rahasia di dokumen ini. Angka bertanda **(demo)** adalah nilai contoh yang belum disetujui bisnis.

---

## 0. Ringkasan

| Hal | Nilai |
|---|---|
| Produk | Aplikasi belanja **Bpedia Demo** + tiga game hadiah (Check-in Harian, Roda Sabtu, Misi Belanja) dengan satu mata uang, Kelopak (1 Kelopak = Rp100) |
| Repo | 5 repo: `bpedia-daily-checkin`, `bpedia-roda-sabtu`, `bpedia-misi-belanja` (modul game), `bpedia-kelopak-hub` (paket ini), `bpedia-app` (aplikasi; satu-satunya yang memakai plugin) |
| Paket ini | `kelopak_hub` 3.0.0: mesin dan data Kelopak, kutipan checkout, hadiah menunggu, kontrak backend, zona Hadiah, controller sungguhan tiga game, widget tanam Beranda, PRD pusat |
| Platform | Flutter 3.41.7 / Dart 3.11.5; Android, iOS, web (lewat `bpedia_app`) |
| Status | Prototipe demo: backend lokal di perangkat (`LocalKelopakBackend`); kontrak server otoritatif sudah bertipe (`RemoteKelopakBackend`) |

## 1. Latar belakang v3

Owner menolak v2 karena tampilan membosankan dan tidak terasa seperti marketplace Indonesia (BRIEF-V3 K1–K3, K12). v3 merombak tampilan (kanvas putih/gelap, pink sebagai aksen, zona game meriah bernuansa 3D, Bipy bergerak) dan menambah aturan: Kelopak memotong harga di checkout (K16), produk gratis menjadi hadiah menunggu yang ikut pesanan berikutnya (K17), Misi Belanja punya daftar produk misi (K4). Pola tata letak dipelajari dari tangkapan layar marketplace Indonesia milik owner (`riset/REF-ECOM-A.md`, `REF-ECOM-B.md`) dan rancangan Figma desainer owner; aset dan logo pihak lain tidak dipakai.

## 2. Tujuan dan ukuran

| Tujuan | Ukuran selesai |
|---|---|
| Pelanggan paham nilai Kelopak dalam sekali lihat | Saldo selalu tampil bersama nilai rupiah ("senilai Rp3.100") di zona Hadiah, strip dompet, dan riwayat |
| Ada alasan kembali tiap hari | Kartu game menampilkan status hari ini dan titik merah bila ada yang bisa diambil |
| Hadiah mendorong belanja | Produk gratis tampil di keranjang sebagai Rp0 dan hanya ikut pesanan berbayar; voucher misi untuk pesanan berikutnya |
| Jujur | Peluang roda, kuota, dan syarat tampil sebelum bermain; tidak ada hitung mundur palsu atau metrik karangan |
| Nyaman | Teks 200% pada lebar 360 tanpa luapan, target sentuh 48, kurangi gerak dihormati |

## 3. Aturan bisnis (ringkas; rinci di KEPUTUSAN-V3)

- **Check-in Harian**: +1 Kelopak per hari WIB; hari ke-7 beruntun bonus +3; hari ke-30 tanpa putus = 1 produk gratis (hadiah menunggu).
- **Roda Sabtu**: 1 putaran gratis tiap Sabtu WIB selama promo. Hadiah (demo): produk gratis 5% (kuota 3/minggu, bergilir), 10 Kelopak 5%, 5 Kelopak 15%, 3 Kelopak 30%, 1 Kelopak 45%; kuota habis → peluang produk pindah ke 1 Kelopak.
- **Misi Belanja**: tahap 1 belanja produk misi Rp75.000 dalam satu pesanan yang diterima → voucher Rp10.000 (min. Rp100.000, 30 hari); tahap 2 Rp100.000 → voucher Rp15.000 (min. Rp150.000, 30 hari). Produk misi (demo) diatur `demo_campaign.dart` aplikasi.
- **Checkout (K16)**: voucher dulu, lalu Kelopak otomatis (bisa dimatikan) sampai `redeemShareBp` (demo 100%) harga barang setelah voucher; ongkir tetap dibayar; total tidak negatif.
- **Hadiah menunggu (K17)**: tampil di keranjang sebagai Rp0, ikut pesanan berikutnya yang berisi minimal 1 produk berbayar.
- **Batal**: Kelopak, voucher, dan hadiah kembali.

## 4. Fitur zona Hadiah (paket ini)

| Layar / komponen | Isi | Rute |
|---|---|---|
| Zona Hadiah `RewardsHubPage` | Hero pesta (saldo besar dengan koin 3D dan nilai rupiah, chip Riwayat dan Cara pakai, Bipy bernapas yang menyapa saat diketuk, koin dan stiker melayang); "Main hari ini" tiga kartu game dengan seni 3D bergerak, status, titik streak 7 hari atau bar misi, tombol permen; hadiah menunggu; Voucherku (2 tiket); Riwayat Kelopak (3 baris); Cara kerja tiga langkah | `/hadiah` |
| Hadiahku `MyGiftsPage` | Hadiah dikelompokkan: menunggu, ikut pesanan, diterima; Rp0 dengan harga coret; cara dapat produk gratis; bar bawah Keranjang/Belanja | `/hadiah/hadiahku` |
| Voucherku `VouchersPage` | Tab Bisa dipakai / Riwayat; tiket berlubang dengan nilai besar, syarat, masa berlaku, tombol Pakai (ke checkout host) | `/hadiah/voucher` |
| Riwayat Kelopak `LedgerPage` | Ringkasan saldo, total didapat/dipakai, saring Semua/Didapat/Dipakai, kelompok per bulan, saldo berjalan | `/hadiah/riwayat` |
| Cara pakai `showKelopakHowTo` | Nilai Kelopak, aturan tiga game dengan peluang dan tahap yang berlaku | lembar |
| Tiga game | Halaman modul dengan controller hub (`Kelopak*Screen`) | `/hadiah/checkin`, `/hadiah/roda`, `/hadiah/misi` |
| Widget tanam | `KelopakWalletStrip`, `KelopakGameStrip` ("Main bareng Bipy"), `MissionCompleteCelebration` | Beranda / global host |

Tamu melihat semua halaman; aksi utama berubah menjadi "Masuk", dan halaman dompet meminta masuk.

## 5. UX, brand, aksesibilitas

- Kanvas netral (putih/gelap), pink untuk aksen; hanya hero zona Hadiah, strip "Main bareng Bipy", dan halaman game yang memakai gradasi pesta.
- Seni 3D paket: koin, kalender, roda mini, tas, kado, tiket; pose Bipy `host` dan `rayakan`; sprite `diam`, `sapa`, `tas`, `jalan`; stiker kilau, bintang, hati.
- Teks Indonesia, sapaan "Babes", tanpa emoji, uang `Rp10.000`, tanggal "27 Nov 2026".
- Aksesibilitas: kartu game satu tombol berlabel lengkap; Bipy berlabel; target sentuh 48; pasangan warna teks lulus 4,5:1 di kedua tema (diuji); teks 200% pada 360 dp tanpa luapan (diuji); kurangi gerak menghentikan semua animasi berulang (diuji).

## 6. Arsitektur

```
bpedia_app ──> kelopak_hub ──> daily_checkin, roda_sabtu, misi_belanja
               (mesin, backend, controller, zona Hadiah, widget tanam)
```

- Modul game: aturan murni → `*ViewState` → `*Controller` abstrak → halaman. Hub mengisi controller dari `KelopakController` (`lib/src/games/`).
- Hub tidak mengenal login, katalog, keranjang, suara, notifikasi: semuanya lewat `KelopakHost` (+ `KelopakGameActions` opsional).
- Data: satu dokumen `bpedia_kelopak_v3` ber-`revision`; migrasi dari v2 sekali jalan.
- Server: `RemoteKelopakBackend` + `KelopakTransport` (lihat `docs/SPEC-CONTRACT.md` §3).

## 7. Data, privasi, keamanan

Hub tidak menyimpan data pribadi: hanya ID pesanan, kode produk, angka Kelopak, voucher, dan hari WIB. Tidak ada kunci atau token di repo. Di produksi, server yang mengundi roda dan menghitung ulang kutipan.

## 8. Kualitas dan definisi selesai

- `flutter analyze` 0 isu untuk seluruh paket (termasuk `example/`).
- `flutter test --concurrency=3` lolos: domain/data (H1), controller tiga game, halaman, widget tanam, aksesibilitas, tangkap layar.
- Tangkap layar terang dan gelap tiap halaman di `build/shots/` (dibuat `flutter test test/shots`), dinilai dua putaran.

## 9. Risiko dan keputusan terbuka

| Hal | Status |
|---|---|
| Peluang roda, kuota, nilai voucher, `redeemShareBp` | Nilai (demo); perlu keputusan bisnis |
| Aksi pesanan di simulator PHP (`server/`) | Belum ada; kontrak ada di `KelopakAction` |
| Hero pesta: teks putih di atas gradasi pink muda | Kontras di bagian paling terang gradasi di bawah 4,5:1; teks besar/tebal dipakai untuk saldo, label kecil tetap perlu dinilai ulang bersama kit |
| Produk misi tahap 2 | Diisi `demo_campaign.dart` aplikasi |

## 10. Riwayat

| Versi | Tanggal | Isi |
|---|---|---|
| 1.0 | 23 Nov 2026 | Hub v1 |
| 2.0 | 24–25 Nov 2026 | Bpedia Preview v2 (app + 3 game), review adversarial |
| 3.0 | 25–26 Nov 2026 | Rombakan v3: hub menjadi paket murni; zona Hadiah baru, controller sungguhan, widget tanam, K16/K17/K4 |
