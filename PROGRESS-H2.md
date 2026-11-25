# PROGRESS-H2 · bpedia-kelopak-hub (agen H2, Zona Hadiah)

Lingkup: `lib/src/{ui,games,embed}/**`, `lib/kelopak_hub.dart` (ekspor tambahan, baris `src/core/kelopak_api.dart` tetap), `example/`, `test/ui/**`, `test/shots/**`, aset hub, `README.md`, `PRD.md`, `docs/SPEC-CONTRACT.md`, `HANDOFF-PENGEMBANG.md`, berkas ini.

## Tonggak

- [x] 0. Baca RENCANA, BRIEF, SPEC §2/§5/§6/§7/§8/§10/§11, PROGRESS-H1, kontrak tiga modul, rujukan visual (Blibli #19, Tokopedia #23, Figma owner)
- [x] 1. `lib/src/games/`: `KelopakCheckInController`, `KelopakWheelController`, `KelopakMissionController`, `KelopakGameActions`, layar pembungkus + tes
- [x] 2. `lib/src/ui/`: aset hub, navigasi, `RewardsHubPage`, `MyGiftsPage`, `VouchersPage`, `LedgerPage`, lembar "Cara pakai"
- [x] 3. `lib/src/embed/`: `KelopakWalletStrip`, `KelopakGameStrip`, `MissionCompleteCelebration`; `kelopakRoutes`
- [x] 4. Tes UI (aksesibilitas, 200% lebar 360, tamu, alur) + tangkap layar terang/gelap, dua putaran lihat-perbaiki
- [x] 5. `example/` (hub + tiga game, backend lokal, panel demo)
- [x] 6. Dokumen: README, PRD v3, docs/SPEC-CONTRACT v3, HANDOFF-PENGEMBANG v3
- [x] 7. `flutter analyze` bersih, `flutter test` lolos, commit lokal

## Keputusan

- Tiga modul membawa salinan kit sendiri, jadi `GameCue` modul dan `GameCue` hub adalah tipe berbeda: dipetakan lewat `name`.
- Aksi yang tidak ada di `KelopakHost` (milik H1, tidak diubah) lewat antarmuka opsional `KelopakGameActions` yang boleh diimplementasikan host: `openCheckout`, `openOrder`, `setCartQuantity`, `soundOn`, `setSoundOn`. Tanpa itu: checkout/pesanan membuka keranjang, ubah jumlah menambah selisih atau membuka keranjang, tombol suara disembunyikan.
- Navigasi antarhalaman hub lewat `KelopakNavigation` (InheritedWidget, `open(context, path)`); bawaan `Navigator.pushNamed`.

## Catatan 26 Nov (lanjutan)

- Kode tonggak 1-3 ada dan `flutter analyze lib test` bersih. Tangkap layar putaran 1 dinilai: perbaikan font tombol (gaya teks dari tema), tanggal pendek di tiket, judul riwayat dari catatan, sel dompet bertumpuk, kartu mini sama tinggi, kartu hadiah lebar bila satu hadiah, tombol bawah Hadiahku dipendekkan, seksi "Cara dapat produk gratis".
- Tes: aset paket sendiri dimuat lewat `test/ui/self_bundle.dart` (di tes paket akar, aset tidak berawalan `packages/kelopak_hub/`). Bila aset modul gagal dimuat di tes, hapus `build/unit_test_assets` (cache basi).
- Data uji kaya: `openRichHub()` di `test/ui/hub_harness.dart` (31 hari check-in, roda, pesanan misi selesai, voucher promo).

## Hasil akhir (26 Nov 2026)

- `flutter analyze` (paket + example): 0 isu. `flutter test --concurrency=3`: 143 lolos (89 H1 + 54 H2). `example/`: 1 tes lolos.
- Tangkap layar dinilai dua putaran (hub terang/gelap/tamu/baru, Hadiahku, Voucherku + riwayat, Riwayat Kelopak, Cara pakai, widget tanam, Misi tuntas, tiga game lewat controller hub). Pilihan JPG di `docs/shots/`.
- Kontras: pasangan warna teks hub diuji dari token (sampling `textContrastGuideline` tidak stabil di halaman bergambar). Hero pesta (milik kit) belum diuji kontras.
- Runner `example/` tidak dibuat (jangan build); README memuat `flutter create --platforms=web,android .`.

## Cara melanjutkan

Lihat tonggak yang belum dicentang. Tes per folder: `flutter test --concurrency=3 test/ui`, tangkap layar `flutter test --concurrency=3 test/shots` lalu buka `build/shots/*.png`.
