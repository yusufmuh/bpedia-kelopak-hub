# PROGRESS-H1 · bpedia-kelopak-hub (agen H1, mesin dan data Kelopak)

Lingkup: `lib/src/{core,domain,storage,backend,controller,host}/**`, `test/{domain,storage,backend,controller}/**`, `pubspec.yaml`, berkas ini. Tanpa UI.

## Tonggak

- [x] 0. Baca RENCANA, BRIEF, KEPUTUSAN, ARSITEKTUR §0/§1.4/§1.5, kode v2 hub, aturan murni tiga modul
- [x] 1. `core/format.dart` tanpa duplikat (ekspor ulang `weekdayName`, `shortDateLabel`, `countdownLabel` dari `roda_sabtu`)
- [x] 2. Domain: `ledger`, `policy`, `campaign`, `gifts`, `voucher`, `orders`, `checkout`, `state`, `engine`
- [x] 3. Storage: `revisioned_document`, `kelopak_document`, `migrate_v2`
- [x] 4. Host: `KelopakHost`, `KelopakProduct`, `KelopakReminder`, `MemoryKelopakHost`
- [x] 5. Backend: `KelopakBackend`, `LocalKelopakBackend`, `RemoteKelopakBackend` + `KelopakTransport` + kodek balasan
- [x] 6. Controller: `KelopakController`, `KelopakEvent`, `KelopakScope`
- [x] 7. Hapus bahan v2 (`lib/{core,data,domain,ui}`, `lib/app.dart`, `lib/main.dart`, `android/`, `ios/`, `web/`, tes v2) dan rapikan `pubspec.yaml` (tanpa plugin)
- [x] 8. Tes: kasus v2 dibawa satu-satu + kasus baru K16/K17/K4, migrasi, dokumen rusak, transport palsu
- [x] 9. `flutter analyze` bersih, `flutter test` lolos, commit lokal

## Keputusan

- Lanjutan 26 Nov: kode tonggak 1-6 sudah ada di disk dan `flutter analyze` pada folder H1 bersih (2 info null-aware diperbaiki).
- `KelopakPolicy.redeemShareBp` (demo 10000) + `computeCheckoutQuote` (voucher -> Kelopak -> ongkir), hadiah hanya terlampir bila ada barang berbayar.
- Pesanan Kelopak (`KelopakOrder`) menyimpan baris saat komit; misi dinilai saat `completeOrder` dari baris itu (satu pesanan satu tahap).
- Komit ulang dengan token sama idempoten; token beda untuk ID yang sama = `duplicateOrder`.
- Migrasi v2: hak produk `HP-` -> hadiah `HG-` berstatus menunggu, kode produk dari kampanye; ledger `checkoutSpend` v2 diberi `orderId` dari catatan.

## Cara melanjutkan

Lihat tonggak yang belum dicentang. Barel API milik H1: `lib/src/core/kelopak_api.dart`.

## Catatan tonggak 7

- Bahan v2 dihapus dengan `git rm` (cadangan di `v3/scratch_audit/bpedia-kelopak-hub`). Sisa lokal tak terlacak di `android/` dan `ios/` (cache gradle, berkas hasil generate, dan `android/key.properties` yang TIDAK dibaca/dihapus) diabaikan lewat `.gitignore`; app sudah punya `key.properties` sendiri. Pemilik boleh menghapus folder itu manual.
- `pubspec.yaml` 3.0.0: hanya Flutter SDK + tiga modul; aset hub: images, bipy, art, fx. Fon Poppins tetap di disk (`assets/fonts`) untuk `test/support/shot.dart`, tidak dideklarasikan.
- `lib/kelopak_hub.dart` mengekspor `src/core/kelopak_api.dart` (H2 menambah ekspor UI di sana).

## Tonggak 8-9: tes (26 Nov 2026)

`flutter analyze` (seluruh paket) bersih; `flutter test --concurrency=3`: 89 lolos, 0 gagal (88 milik H1 + 1 kit).

Berkas: `test/domain/{kelopak_engine_test,checkout_test}.dart`, `test/storage/{kelopak_document_test,migrate_v2_test}.dart`, `test/backend/{local_kelopak_backend_test,remote_kelopak_backend_test}.dart`, `test/controller/kelopak_controller_test.dart`; pendukung `test/domain/fixtures.dart`, `test/storage/v2_fixture.dart`, `test/backend/fake_server.dart`.

### Peta 47 kasus domain/data v2 (45 dibawa + 2 diganti K16)

| # | Kasus v2 | Rumah v3 |
|---|---|---|
| 1-7, 9-11, 13, 15 | rewards_engine: check-in (4), roda (6), saldo negatif, state negatif | `kelopak_engine_test` nama sama |
| 8 | product prize uses stock | `kelopak_engine_test` "the product prize uses the quota; at 0 the fallback pays Kelopak" (nilai demo v3: bobot 500, kuota mingguan, cadangan `kelopak-1`) |
| 12 | caps usage at 50% | DIGANTI K16: `checkout_test` "the share cap follows KelopakPolicy.redeemShareBp" |
| 14 | state JSON round trip | `kelopak_engine_test` "state survives a JSON round trip" (+ pesanan, hadiah, promo) |
| 16, 17 | cart add/cap/undo, drop retired lines | app `cart_test` (agen A) |
| 18, 19 | misi 74.999/75.000, tahap 2 lalu habis | `kelopak_engine_test` grup "Misi Belanja on completion" (tahap 2 demo v3 15.000/150.000) |
| 20 | voucher min 100rb, bukan pesanan sendiri, sekali | `checkout_test` "needs min. Rp100.000, never on its own order, used once" |
| 21 | Kelopak covers at most 50% | DIGANTI K16: `checkout_test` "total Rp0 is fully covered and booked as one debit" |
| 22 | small balance used fully | `checkout_test` "a small balance is used fully and only when switched on" |
| 23 | outdated or empty quote | `checkout_test` "an outdated or empty quote cannot be committed" |
| 24 | order numbers BP-YYYYMMDD-NNNN | app `orders_test` (agen A) |
| 25 | shop state round trip | `checkout_test` "orders and requests survive a JSON round trip" (keranjang: app) |
| 26-29, 31, 32 | app_state: fresh, reload, pergantian hari, putar, checkout, riwayat | `kelopak_controller_test` |
| 30 | demo tools | `kelopak_controller_test` "demo tools need a backend that has them" (geser kalender: app `AppServices`) |
| 33 | settings | app `app_services_test` (agen A) |
| 34 | stale tab adopts newer | `local_kelopak_backend_test`, `kelopak_document_test` (RevisionedDocument), `kelopak_controller_test` "a stale tab cannot claim the same day twice" |
| 35 | syncFromStore once | `kelopak_controller_test` + `local_kelopak_backend_test` "refresh picks up a newer save once" |
| 36 | revision survives reload | `kelopak_document_test` "each save raises the revision and the revision survives a reload" |
| 37 | only single waiting order | `kelopak_engine_test` nama sama |
| 38-41 | wording roda, jam mundur (2), stockForSpin | `kelopak_controller_test` |
| 42-45, 47 | persistence: simpan/muat, hilang, rusak, varian mustahil, MemoryKeyValueStore | `kelopak_document_test` |
| 46 | corrupt document repaired | `local_kelopak_backend_test` "starts fresh on a corrupt document and repairs it" |

Kasus baru: K16 (urutan voucher -> Kelopak -> ongkir, pecahan < Rp100, total Rp0, minimum voucher sebelum Kelopak), K17 (hadiah butuh barang berbayar, lampir/kirim/terima, batal mengembalikan Kelopak/voucher/hadiah), K4 (hanya produk misi dihitung, satu pesanan satu tahap, pesanan batal tidak dihitung), kuota roda mingguan + rotasi produk, voucher promo, migrasi v2 (5), dokumen rusak, transport palsu RemoteKelopakBackend (6), event + host + KelopakScope.

## API untuk H2 dan I1 (impor `package:kelopak_hub/kelopak_hub.dart`)

- Membuat: `final c = await KelopakController.open(backend: LocalKelopakBackend(store: <KeyValueStore app>, campaign: <KelopakCampaign dari demo_campaign.dart>), clock: WibClock(), host: <KelopakHost>);` lalu `KelopakScope(controller: c, child: ...)`; baca dengan `KelopakScope.of/read/maybeRead`. Server asli: `RemoteKelopakBackend(transport: <KelopakTransport>, campaign: ...)`.
- Kutipan: `CheckoutQuote q = c.quote(CheckoutRequest(lines: [CheckoutLine(productCode, unitPrice, quantity)], shippingFee, voucherId, useKelopak: true))`; medan `goodsSubtotal, voucherId, voucherAmount, voucherProblem, voucherApplied, goodsAfterVoucher, kelopakBalance, kelopakMax, kelopakUsed, kelopakValue, gifts (List<PendingGift>), waitingGiftCount, giftsBlocked, hasPaidItems, isFullyCovered, shippingFee, total, token`. `c.quoteByToken(token)`, `c.problemWith(q)`.
- Pesanan: `c.commitOrder(orderId, q)` -> `OrderCommitted(order)` / `OrderNotCommitted(CheckoutProblem)`; `c.cancelOrder(id)` -> `OrderCancellation?`; `c.shipOrder(id)` -> `KelopakOrder?`; `c.completeOrder(id)` -> `OrderCompletion?` (`decision`, `voucher`, `gifts`).
- Event: `c.events` (Stream sinkron) dan `KelopakHost.onEvent`: `CheckInClaimedEvent`, `WheelSpunEvent`, `PromoVoucherClaimedEvent`, `VoucherRedeemedEvent`, `KelopakRedeemedEvent`, `GiftAttachedEvent`, `OrderRefundedEvent`, `GiftsShippedEvent`, `GiftsReceivedEvent`, `MissionCompletedEvent`; tiap event punya `analyticsName` (bp_* atau null), `parameters`, `notice` (`KelopakNotice{title, body, route}`).
