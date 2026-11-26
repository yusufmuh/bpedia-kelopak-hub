# Progres perbaikan HUB (fase tinjau v3)

Lingkup: repo ini kecuali `lib/src/kit`, `test/support/shot.dart`, dan `server/`.
Commit hanya berkas sendiri (`git add <berkas>`); agen HUB-SERVER bekerja di `server/`.

## Temuan

- [x] P1-06 strip "Main bareng Bipy": subjudul, ubin rata kiri, nilai ringkas, bar progres Misi
- [x] P1-20 strip dompet: nilai warna teks utama, ikon kiri, keterangan huruf kecil
- [x] P3-05 kepala Zona Hadiah menerima `actions`
- [x] P3-06 hero Zona Hadiah: akhiran Kelopak, pil senilai, strip 7 hari, pil Riwayat
- [x] P3-07 Hadiahku: spanduk pink "N hadiah menunggu", tanpa bahasa spesifikasi
- [x] P3-08 Voucherku: tab Semua/Bisa dipakai/Akan datang, Cara dapat voucher, Ketentuan
- [x] P3-09 tiket voucher: label Diskon, hierarki sumber/min. belanja/sisa/berlaku
- [x] P3-10 panel "Main hari ini": judul 20, sub, pita "N siap", panel brandTint, kartu 2 baris
- [x] P3-11 Riwayat Kelopak: hero pink, ubin tint, filter Hadiah, label Masuk, ikon Kelopak
- [x] P3-12 Hadiahku: seksi Riwayat kiriman dengan stepper
- [x] B1-05 catatan buku besar "pesanan #..."
- [x] B1-06 tamu boleh tambah ke keranjang di Misi
- [x] R1-01 dilewati (urusan rilis orkestrator: git ber-tag, repository:, pubspec_overrides); README bagian Pasang menulis urutan rilis
- [x] R1-07 runner web+android di example/
- [x] R1-08 CHANGELOG 3.0.0 + bagian Pasang di README (LICENSE dilewati: keputusan owner; README menyebut belum ditetapkan)

## Backlog

- [x] Perayaan misi tidak tampil dua kali
- [x] Kontras teks putih kecil di hero terang
- [x] README dan HANDOFF menjelaskan KelopakNavigation untuk tab Hadiah

## Akhir

- [x] Tangkapan layar diperbarui dan dibandingkan dengan Figma (2 putaran)
- [x] flutter analyze bersih
- [x] flutter test lolos
- [x] Commit

Catatan:
- Tes: `flutter test --concurrency=3` di hub 147 lolos; `example/` 1 lolos; analyze 0 isu.
- Banding Figma: 3 putaran (r1 hadiah+hadiahku, r1 strip/voucher/riwayat, r2 strip+hadiah+hadiahku, r3 gelap).
- Di luar lingkup: app `kelopak_integration.dart` harus mengirim `actions` (Notifikasi, Keranjang berlencana) ke `RewardsHubPage`; server PHP perlu catatan '#'.
