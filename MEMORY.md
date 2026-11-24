# Memori proyek Bpedia Kelopak

Catatan produk per 24 November 2026. Baca bersama GAMBARAN.md. Dokumen ini merekam keputusan pemilik produk sebagai acuan untuk Claude, Antigravity, Codex, dan pengembang.

| Fitur | Keputusan dari brief |
|---|---|
| Dompet | Nama penggunaannya **Kelopak**. Satu Kelopak bernilai Rp100 dalam program Bpedia. |
| Check-in | Setiap hari yang diklaim memberi 1 Kelopak. Setiap tujuh hari berurutan memberi tambahan 3 Kelopak. Tujuh hari pertama menghasilkan 10 Kelopak senilai Rp1.000. Satu bulan penuh berurutan memberi produk gratis. |
| Roda Sabtu | Saat promo aktif, satu akun mendapat satu putaran gratis pada hari Sabtu. Hasil berupa produk sesuai kuota atau Kelopak. Peluang dan ketentuan ongkir terlihat sebelum putaran. |
| Misi Belanja | Satu pesanan selesai senilai sedikitnya Rp75.000 memberi satu voucher Rp10.000. Voucher berlaku untuk pesanan berikutnya dengan minimal Rp100.000. Setelah hadiah terbit, tahap selanjutnya terbuka sesuai konfigurasi kampanye. |
| Distribusi | Tiga repositori fitur terpisah, satu acuan lintas fitur, Flutter untuk Android, iOS dan web. Saldo, progres dan riwayat produksi mengikuti akun Bpedia yang sama. |

## Asumsi kerja yang perlu keputusan bisnis

- Hari mengikuti WIB. Contoh bulanan menggunakan 30 hari berjalan dan milestone setiap kelipatan 30. Siklus tujuh hari berjalan independen.
- Saldo adalah manfaat loyalitas belanja. Penukaran, batas penggunaan, kedaluwarsa dan perlakuan pengembalian perlu keputusan pemilik program.
- Besaran Kelopak roda, jumlah produk, peluang, ongkir, tahapan misi lanjutan dan masa berlaku voucher menunggu konfigurasi kampanye. Nilai simulasi perlu label **Demo**.
- Aplikasi produksi memerlukan identitas akun resmi, sumber pesanan, transaksi dompet, checkout voucher dan pemenuhan stok dari tim Bpedia. Store listing tidak menyediakan akses tersebut.

## Cara memperbarui

Ubah keputusan lintas fitur di sini dahulu. Catat tanggal dan pemilik persetujuan. Perubahan satu fitur masuk ke PRD dan tes di repositori fitur terkait. Perubahan kontrak bersama perlu nomor versi dan migrasi bagi klien lama. Kredensial dikelola di luar berkas proyek.
