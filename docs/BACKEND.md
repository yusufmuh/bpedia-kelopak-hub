# Kontrak backend Kelopak v3

Untuk tim backend yang membangun server otoritatif di belakang `RemoteKelopakBackend`. Ringkasan endpoint ada di `docs/SPEC-CONTRACT.md` §3; dokumen ini adalah rinciannya. Server acuan yang menjalankan kontrak ini ada di `server/` (PHP 8.2+, tanpa dependensi).

## 1. Server acuan

| Berkas | Isi |
|---|---|
| `server/index.php` | Front controller HTTP (Apache lewat `.htaccess`, atau `php -S`) |
| `server/kelopak_http.php` | Rute, token sesi, idempotensi, penyimpanan per pengguna, galat `application/problem+json` |
| `server/kelopak.php` | Mesin Kelopak: cermin `KelopakEngine` + `computeCheckoutQuote` (Dart) |
| `server/checkin.php`, `spin.php`, `missions.php` | Aturan tiap game, salinan identik dari `bpedia-daily-checkin/server`, `bpedia-roda-sabtu/server`, `bpedia-misi-belanja/server`. Ubah di repo modul lalu salin ulang. |
| `server/campaign.bpedia-demo.json` | Kampanye demo (tahap misi, produk roda, promo 12.12) |
| `server/selftest.php` | Swa-uji mesin + HTTP + penyimpanan berkas, ikut menjalankan swa-uji tiga modul |

```bash
php server/selftest.php                                       # wajib 0 gagal
BPEDIA_KELOPAK_DEMO=1 php -S 127.0.0.1:8787 server/index.php  # coba lokal
curl -H "Authorization: Bearer token-uji-0000000001" http://127.0.0.1:8787/kelopak/state
```

| Variabel lingkungan | Arti |
|---|---|
| `BPEDIA_KELOPAK_CAMPAIGN` | Berkas kampanye JSON; bawaan `server/campaign.bpedia-demo.json` |
| `BPEDIA_KELOPAK_DATA` | Folder dokumen per pengguna; bawaan `server/data/` (di luar git, dikunci `.htaccess`) |
| `BPEDIA_KELOPAK_DEMO=1` | Mode Demo: `today` dari klien diterima, app boleh memanggil `ship`/`complete` |
| `BPEDIA_KELOPAK_SERVICE_KEY` | Kunci sistem pesanan untuk `ship`/`complete` di luar Mode Demo; isi dari konfigurasi server, jangan di repo |

Kecocokan dengan klien sudah diuji ujung ke ujung: `RemoteKelopakBackend` di atas `dart:io` lawan `php -S` menjalankan check-in, klaim promo, komit (dua kali), kirim, terima, komit kedua, dan batal; keadaan akhirnya sama persis (JSON) dengan `LocalKelopakBackend` untuk urutan yang sama, dan roda yang diundi server terbaca klien.

## 2. Aturan HTTP

**Alamat.** Jalur di bawah alamat dasar API, misalnya `https://api.bpedia.id/v1/kelopak/state`. Server acuan menerima awalan apa pun sebelum `/kelopak/` dan garis miring akhir.

**Token sesi.** Setiap permintaan wajib `Authorization: Bearer <token sesi app>`; tanpa itu 401. Server menurunkan ID pelanggan dari token (verifikasi sesi milik backend Bpedia) dan tidak pernah membaca ID pengguna dari badan permintaan. Server acuan memperlakukan tiap token (16-512 karakter) sebagai akun sendiri; ganti `kelopakUserIdFromToken()` dengan verifikasi sesi sungguhan. `KelopakTransport` di app yang menempelkan token, alamat dasar, dan batas waktu.

**Badan.** `POST` memakai `Content-Type: application/json` berisi objek JSON (maks. 64 KiB). `GET` tanpa badan.

**Balasan sukses.** Status 200, `Content-Type: application/json`, `Cache-Control: no-store`, header `X-Kelopak-Revision` (nomor revisi dokumen pengguna), badan:

```json
{ "state": { ...KelopakState.toJson() }, "result": { ... } }
```

`GET /kelopak/state` hanya membalas `state`. Penolakan aturan bisnis (sudah check-in, bukan Sabtu, promo sudah diklaim, kutipan basi, pesanan tidak ada) **bukan** galat HTTP: tetap 200 dengan `result` berisi `claimed: false`, `spun: false`, `problem`, dan sejenisnya, supaya UI tetap menerima keadaan terbaru.

**Galat.** Selain 200, badan berupa RFC 9457 `application/problem+json`:

```json
{
  "type": "urn:bpedia:kelopak:problem:unauthorized",
  "title": "Butuh login",
  "status": 401,
  "detail": "Butuh header Authorization: Bearer <token sesi>.",
  "code": "unauthorized"
}
```

| Status | `code` | Kapan |
|---|---|---|
| 400 | `invalidRequest` | JSON rusak, bukan objek, field wajib hilang atau salah bentuk, `Idempotency-Key` tidak sah, `today` di luar rentang Mode Demo |
| 401 | `unauthorized` | Header `Authorization` hilang atau token tidak sah; disertai `WWW-Authenticate: Bearer` |
| 403 | `forbidden` | `ship`/`complete` tanpa `X-Kelopak-Service-Key` yang benar di luar Mode Demo |
| 404 | `notFound` | Jalur tidak dikenal |
| 405 | `methodNotAllowed` | Metode salah; disertai header `Allow` |
| 409 | `idempotencyKeyReused` | `Idempotency-Key` sama dipakai untuk aksi atau badan berbeda |
| 413 | `payloadTooLarge` | Badan lebih dari 64 KiB |
| 415 | `unsupportedMediaType` | `POST` berbadan tanpa `Content-Type: application/json` |
| 500 | `internal` | Galat tak terduga; detail hanya di log server |

`RemoteKelopakBackend` memperlakukan setiap kegagalan transport (jaringan, status bukan 2xx) sebagai `KelopakBackendException` dengan pesan "Belum bisa terhubung. Coba lagi sebentar, ya."; transport cukup melempar galat untuk status bukan 2xx. Bila app ingin menampilkan pesan khusus (misalnya 401 → minta login ulang), transport dapat membaca `code` sebelum melempar.

**Idempotensi.** Ada dua lapis:

1. Header opsional `Idempotency-Key` (8-128 karakter `[A-Za-z0-9_.:-]`) pada aksi yang mengubah keadaan. Kunci yang sama dengan aksi dan badan yang sama membalas `result` yang tersimpan beserta keadaan terkini, header `Idempotency-Replayed: true`, tanpa menjalankan aksi lagi. Kunci sama dengan isi berbeda = 409. Server acuan menyimpan 200 kunci terakhir per pengguna; produksi sebaiknya menyimpan minimal 24 jam. Kunci diabaikan untuk `read`, `gifts`, `quote`.
2. Idempotensi alami tiap aksi, tanpa header: check-in kedua di hari WIB sama = `claimed: false`; putaran kedua di Sabtu yang sama = `spun: false, reason: alreadySpun`; promo kedua = `alreadyClaimed`; komit ulang `orderId` dengan `token` sama = `committed: true` tanpa memotong apa pun lagi, `token` beda = `duplicateOrder`; batal/kirim/terima yang sudah terjadi = `cancelled|shipped|completed: false`. Mengulang permintaan setelah batas waktu jaringan selalu aman.

**Hari WIB dan `today`.** Hari WIB = `floor((unix detik + 25200) / 86400)`. Produksi selalu memakai jam server dan mengabaikan `today` dari klien. Mode Demo menerima `today` dalam ±400 hari dari jam server (Mode Demo app memajukan hari).

**Konkurensi.** Setiap aksi membaca, mengubah, dan menulis dokumen satu pengguna secara eksklusif (server acuan: `flock` per berkas). Produksi: satu baris per pengguna dengan `SELECT ... FOR UPDATE` dalam satu transaksi, atau tabel buku besar dengan kunci unik per aksi.

## 3. Endpoint

Kolom "Badan" adalah field yang dibaca server. Field lain diabaikan.

| Aksi | Metode dan jalur | Badan | `result` |
|---|---|---|---|
| `read` | `GET /kelopak/state` | - | tidak ada |
| `checkIn` | `POST /kelopak/check-in` | `today` (demo) | `claimed`, `streak`, `dailyKelopak`, `bonusKelopak`, `productEntitled`, `giftId` |
| `spin` | `POST /kelopak/wheel/spin` | `today` (demo) | `spun: true, wibDay` atau `spun: false, reason` (`alreadySpun`, `notSaturday`, `promoInactive`) |
| `claimPromo` | `POST /kelopak/vouchers/promo` | `promoId`, `today` (demo) | `claimed: true, voucherId` atau `claimed: false, problem` (`alreadyClaimed`, `invalidTerms`) |
| `quote` | `POST /kelopak/orders/quote` | `request` (`CheckoutRequest`), `today` (demo) | kutipan server (lihat §5) |
| `commit` | `POST /kelopak/orders/commit` | `orderId`, `request`, `token`, `today` (demo) | `committed: true, orderId` atau `committed: false, problem` (`noPaidItems`, `quoteOutdated`, `duplicateOrder`) |
| `cancel` | `POST /kelopak/orders/cancel` | `orderId`, `today` (demo) | `cancelled`, `orderId`, `kelopakRefunded`, `voucherId`, `giftIds` |
| `ship` | `POST /kelopak/orders/ship` | `orderId` | `shipped`, `orderId` |
| `complete` | `POST /kelopak/orders/complete` | `orderId`, `today` (demo) | `completed`, `orderId`, `issuedStage`, `rejection`, `voucherId`, `giftIds` |
| `gifts` | `GET /kelopak/gifts` | - | `pending`, `attached`, `shipped`, `received` (daftar ID hadiah) |

`read` sampai `complete` adalah `KelopakAction` yang dipanggil `RemoteKelopakBackend`; bentuk `result` sama dengan `encode*()` di `lib/src/backend/reply_codec.dart`. `quote` dan `gifts` tambahan untuk sistem lain (halaman pembayaran web, gudang); app menghitung kutipan sendiri lewat `KelopakView.quote` dengan aturan yang sama.

`orderId` dan `promoId`: 1-64 karakter `[A-Za-z0-9._:-]`. `CheckoutRequest`:

```json
{
  "lines": [{ "productCode": "P21F02C01000031", "unitPrice": 89000, "quantity": 1 }],
  "shippingFee": 10000,
  "voucherId": "VP-0001",
  "useKelopak": true
}
```

## 4. Server otoritatif: nilai dari server, bukan dari klien

| Hal | Sumber kebenaran |
|---|---|
| Voucher promo (nilai, minimal belanja, masa berlaku, judul, hari klaim) | Katalog `promos` kampanye server, dicari dengan `promoId` |
| Hadiah roda | Undian server dari `wheel` kampanye dan kuota mingguan |
| Hadiah check-in, voucher Misi Belanja | Aturan modul + `missionStages` kampanye |
| Potongan voucher dan Kelopak, total | Dihitung ulang dari `request` + keadaan server |
| Harga barang | Katalog harga backend (`prices` kampanye pada server acuan); bila diisi, harga baris yang tidak cocok = `quoteOutdated` |
| Hari | Jam WIB server (kecuali Mode Demo) |

**Klaim promo.** Klien cukup mengirim `promoId` (dan `today` untuk demo). Server mencari promo di katalognya; promo tidak dikenal atau di luar jendela klaim = `invalidTerms`. Antarmuka `KelopakBackend.claimPromoVoucher` di Dart masih menerima `amount`, `minSpend`, `validDays`, dan `title` (dipakai `LocalKelopakBackend` dalam Mode Demo), dan `RemoteKelopakBackend` saat ini masih mengirimnya. Server **wajib mengabaikan** field itu: server acuan tidak membacanya, dan swa-uji `HTTP R1-10` memastikan permintaan `amount: 999999` tetap menerbitkan voucher Rp12.000 dari katalog.

**Kirim dan terima.** Di produksi transisi pesanan datang dari sistem pesanan (webhook gudang/kurir) dengan header `X-Kelopak-Service-Key` dan token sesi pelanggan pemilik pesanan; app tidak memanggil `shipOrder`/`completeOrder` (jawabannya 403). Di Mode Demo panel demo app boleh memanggilnya. `cancel` boleh dari app selama pesanan belum dikirim.

## 5. Kutipan dan token

Urutan hitung K16: subtotal barang berbayar → voucher (bila memenuhi minimal belanja dan masih berlaku) → Kelopak (maks. `redeemShareBp` dari harga setelah voucher, kelipatan `rupiahPerKelopak` ke bawah, tidak melebihi saldo) → + ongkir. Hadiah produk yang menunggu ikut pesanan bila ada barang berbayar.

Token kutipan sama persis dengan `CheckoutQuote.token` di Dart:

```
kq1|<hari>|<kode*harga*jumlah,...>|<ongkir>|<voucherId atau ->|<potongan voucher>|<Kelopak dipakai>|<id hadiah,...>|<total>
```

Komit menghitung ulang kutipan dari `request` pada keadaan saat itu dan menolak dengan `quoteOutdated` bila token berbeda (saldo berubah, voucher kedaluwarsa, hari berganti, hadiah baru, harga dimanipulasi). Hasil `quote` dari server: `day`, `goodsSubtotal`, `shippingFee`, `voucherId`, `voucherApplied`, `voucherAmount`, `voucherProblem` (`alreadyUsed`, `expired`, `sameOrder`, `belowMinimum`), `kelopakBalance`, `kelopakMax`, `kelopakUsed`, `kelopakValue`, `giftIds`, `waitingGiftCount`, `total`, `token`.

## 6. Keadaan dan penyimpanan

`state` berbentuk persis `KelopakState.toJson()`: `ledger`, `streak`, `lastClaimDay`, `gifts`, `spins`, `promoActive`, `wheelQuotaUsed`, `wheelQuotaWeek`, `missionIssuedCount`, `countedOrderIds`, `vouchers`, `orders`, `ledgerSeq`, `giftSeq`, `voucherSeq` (rincian tiap entri: SPEC-CONTRACT §2). ID entri (`L000001`, `HG-0001`, `VP-0001`, `VM-0001`) dibuat server dari penghitung `*Seq` dengan pola yang sama dengan `LocalKelopakBackend`. Saldo = jumlah `amount` buku besar dan tidak pernah negatif.

Server acuan menyimpan satu dokumen per pengguna `{schema: 1, revision, state, idempotency}`; `revision` naik setiap keadaan berubah.

## 7. Kampanye

`campaign.bpedia-demo.json` (kunci yang tidak ada memakai nilai bawaan = `KelopakCampaign.demo`):

| Kunci | Isi |
|---|---|
| `policy` | `rupiahPerKelopak` (100), `redeemShareBp` (10000 = 100%) |
| `wheel` | Konfigurasi roda modul (`version`, `prizes` berbobot, `wheelLayout`); bawaan `rodaDemoConfig()` |
| `wheelQuota`, `wheelQuotaRefillsWeekly` | Kuota hadiah produk per minggu (Senin awal minggu) |
| `wheelProductCodes`, `checkIn30ProductCode` | Kode produk hadiah roda (bergilir per minggu) dan hadiah check-in hari ke-30 |
| `missionStages` | `number`, `title`, `minOrderSubtotal`, `voucherAmount`, `voucherMinSpend`, `voucherValidDays`, `productCodes` |
| `promos` | `id`, `title`, `amount`, `minSpend`, `validDays`, `claimFrom`, `claimUntil` (tanggal WIB `Y-m-d`, opsional) |
| `prices` | Peta kode produk → harga rupiah, atau `null` (harga dari klien diterima apa adanya; hanya untuk demo) |

Kampanye server dan `KelopakCampaign` di app harus sama nilainya (tahap misi, produk roda), karena app memakai kampanye untuk menampilkan peluang dan menerjemahkan `issuedStage`.

## 8. Daftar periksa produksi

- [ ] `kelopakUserIdFromToken()` diganti verifikasi sesi Bpedia; token tidak pernah dicatat di log.
- [ ] Penyimpanan berkas diganti basis data bertransaksi (antarmuka `KelopakStore::transact`).
- [ ] `BPEDIA_KELOPAK_DEMO` mati; `BPEDIA_KELOPAK_SERVICE_KEY` diisi dari rahasia server; sistem pesanan memanggil `ship`/`complete`.
- [ ] `prices` diisi atau harga dicek ke katalog produk backend.
- [ ] HTTPS saja, batas laju per pengguna untuk `POST`, log galat 500.
- [ ] `php server/selftest.php` (atau padanannya) dijalankan di CI tiap perubahan aturan.
