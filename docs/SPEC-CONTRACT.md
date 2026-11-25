# Kontrak Data dan API v3 · kelopak_hub (Bpedia Demo v3)

Dokumen ini mengikat bentuk data, API Dart publik, dan API backend sistem Kelopak. Aturan bisnis lengkap: `bpedia-asset-build/v3/KEPUTUSAN-V3.md`. Tampilan: `SPEC-V3.md` §5. Bila kode dan dokumen ini berbeda, kode di `lib/src/` yang benar dan dokumen ini harus diperbaiki.

## 0. Batas paket

- `kelopak_hub` hanya bergantung pada Flutter SDK + `daily_checkin`, `roda_sabtu`, `misi_belanja` (path). Tanpa plugin, tanpa HTTP.
- Aplikasi induk (`bpedia_app`) menyediakan login, katalog, keranjang, suara, analitik, notifikasi lewat `KelopakHost` (+ `KelopakGameActions` opsional) dan menyuntikkan `KelopakBackend`.
- Semua hari adalah **hari WIB** (bilangan bulat: hari sejak 1 Jan 1970 pada UTC+7). Uang dalam rupiah bulat. 1 Kelopak = `KelopakPolicy.rupiahPerKelopak` (demo Rp100).

## 1. Aturan yang dijalankan mesin (`KelopakEngine`)

| Area | Aturan |
|---|---|
| Check-in Harian | +1 Kelopak per hari WIB; hari ke-7, 14, ... beruntun +3; hari ke-30, 60, ... = 1 hadiah produk (`GiftSource.checkIn30`). Lewat sehari, rentetan mulai dari 1. |
| Roda Sabtu | 1 putaran per Sabtu WIB selama `promoActive`; undian 0..9999 di backend; hadiah produk memakai kuota (`wheelQuota`, isi ulang tiap Senin bila `wheelQuotaRefillsWeekly`); kuota habis: bobot produk pindah ke `SpinConfig.fallbackPrizeId`. Nilai peluang = (demo). |
| Misi Belanja | Tahap berurutan; dihitung **subtotal produk misi** (`MissionStage.productCodes`, kosong = semua) dari satu pesanan yang **diterima**; satu pesanan menyelesaikan satu tahap; pesanan batal tidak dihitung. Tahap selesai menerbitkan voucher misi. |
| Kutipan checkout (K16) | Urutan: subtotal barang → voucher (cek min. belanja pada subtotal sebelum Kelopak) → Kelopak (maks. `redeemShareBp` dari harga barang setelah voucher, dibulatkan ke bawah per Kelopak, tidak melebihi saldo) → + ongkir. Total tidak pernah negatif. Pecahan < Rp100 tetap dibayar. |
| Hadiah menunggu (K17) | Produk gratis berstatus `pending` sampai ada pesanan dengan minimal 1 barang berbayar; saat komit menjadi `attached`, lalu `shipped`, `received`. Batal mengembalikan ke `pending`. |
| Batal | Kelopak (`checkoutRefund`), voucher (dilepas), dan hadiah kembali. |

## 2. Model data (JSON, `KelopakState.toJson()`)

Dokumen tersimpan: kunci `bpedia_kelopak_v3`, skema `1`, berisi `{schema, revision, state}`. Migrasi sekali jalan dari `bpedia_preview_state_v1` (v2) lewat `migrateV2`.

```json
{
  "ledger": [{"id": "L000001", "wibDay": 20783, "amount": 1, "kind": "checkIn", "note": "Check-in hari ke-1", "orderId": null}],
  "streak": 31, "lastClaimDay": 20782,
  "gifts": [{"id": "HG-0001", "source": "checkIn30|wheel", "wonDay": 20781, "productCode": "P39A06S01000089", "status": "pending|attached|shipped|received", "orderId": null}],
  "spins": [{"wibDay": 20771, "prizeId": "kelopak-3", "roll": 4210, "landingSeed": 17, "configVersion": "...", "productStockBefore": 3, "giftId": null}],
  "promoActive": true, "wheelQuotaUsed": 1, "wheelQuotaWeek": 2969,
  "missionIssuedCount": 1, "countedOrderIds": ["BP-261120-0001"],
  "vouchers": [{"id": "V-0001", "kind": "mission|promo", "title": "...", "amount": 10000, "minSpend": 100000, "issuedDay": 20777, "expiresDay": 20807, "stageNumber": 1, "sourceOrderId": "BP-...", "promoId": null, "usedOnOrderId": null}],
  "orders": [{"id": "BP-...", "placedDay": 20777, "lines": [{"productCode": "...", "unitPrice": 26000, "quantity": 2}], "goodsSubtotal": 76800, "shippingFee": 12000, "voucherId": null, "voucherAmount": 0, "kelopakUsed": 0, "kelopakValue": 0, "giftIds": [], "total": 88800, "quoteToken": "...", "status": "placed|shipped|completed|cancelled", "closedDay": null}],
  "ledgerSeq": 48, "giftSeq": 2, "voucherSeq": 2
}
```

`LedgerKind`: `checkIn`, `checkInBonus`, `spinPrize`, `checkoutSpend` (negatif), `checkoutRefund`, `demoGrant`. Saldo = jumlah `amount` dan tidak pernah negatif.

## 3. API backend (`KelopakBackend`)

Antarmuka asinkron; setiap aksi membalas `KelopakReply<T>{state, value}` sehingga UI selalu memakai keadaan terbaru dari server.

| Implementasi | Pakai |
|---|---|
| `LocalKelopakBackend(store: KeyValueStore, campaign:, random:)` | Demo dan offline; menulis dokumen ber-`revision`; punya `KelopakDemoTools` (promo, kuota, isi saldo, atur ulang). |
| `RemoteKelopakBackend(transport: KelopakTransport, campaign:)` | Server otoritatif; host menyuntikkan `KelopakTransport.send(action, body)` (HTTP + token sesi milik app). |

Endpoint yang disarankan (`KelopakAction`), semua membalas `{"state": {...}, "result": {...}}`:

| Aksi | Endpoint | Isi permintaan | `result` |
|---|---|---|---|
| `read` | `GET /kelopak/state` | - | - |
| `checkIn` | `POST /kelopak/check-in` | `today` | `claimed`, `streak`, `dailyKelopak`, `bonusKelopak`, `productEntitled`, `giftId` |
| `spin` | `POST /kelopak/wheel/spin` | `today` | `spun`, `wibDay` atau `reason` |
| `claimPromo` | `POST /kelopak/vouchers/promo` | `promoId`, `amount`, `minSpend`, `validDays`, `title`, `today` | `claimed`, `voucherId` atau `problem` |
| `commit` | `POST /kelopak/orders/commit` | `orderId`, `request` (`CheckoutRequest`), `token`, `today` | `committed`, `orderId` atau `problem` |
| `cancel` | `POST /kelopak/orders/cancel` | `orderId`, `today` | `cancelled`, `kelopakRefunded`, `voucherId`, `giftIds` |
| `ship` | `POST /kelopak/orders/ship` | `orderId` | `shipped`, `orderId` |
| `complete` | `POST /kelopak/orders/complete` | `orderId`, `today` | `completed`, `issuedStage`, `rejection`, `voucherId`, `giftIds` |

Ketentuan server: mengundi roda sendiri; menghitung ulang kutipan dari `request` dan menolak dengan `quoteOutdated` bila `token` tidak cocok; komit ulang dengan token sama idempoten, token beda untuk ID sama = `duplicateOrder`; `today` hanya petunjuk demo (produksi memakai jam WIB server). Simulator PHP v2 ada di `server/`; aksi pesanan v3 belum dibuat di PHP (BACKLOG-V3).

## 4. API Dart untuk host

Impor: `package:kelopak_hub/kelopak_hub.dart` (di `bpedia_app` dengan `hide CheckoutQuote, CheckoutRequest, v2DocumentKey`) dan `package:kelopak_hub/kit.dart` (kit pesta + `BipySprite`).

### 4.1 Inti

- `KelopakController.open(backend:, clock: WibClock(), host:, watchDayChange:)`; `KelopakScope(controller:, child:)`; `KelopakScope.of/read/maybeRead`.
- Baca: `balance`, `ledgerHistory`, `claimedToday`, `liveStreak`, `checkInMonthDay`, `spinEligibility`, `spinOdds`, `wheelQuotaLeft`, `nextWheelOpening`, `activeMissionStage`, `missionProductCodes`, `cartMissionProgress`, `activeVouchers`, `vouchers`, `pendingGifts`, `gifts`, `view` (`KelopakView`).
- Aksi: `claimCheckIn()`, `spin()`, `claimPromoVoucher(...)`, `quote(CheckoutRequest)`, `problemWith(quote)`, `commitOrder(id, quote)`, `cancelOrder(id)`, `shipOrder(id)`, `completeOrder(id)`; Mode Demo: `setPromoActive`, `setWheelQuotaLeft`, `refillWheelQuota`, `grantKelopak`, `resetAll`; hari: `clock.demoOffsetDays` + `refreshDay()`.
- Peristiwa: `events` (stream sinkron) dan `KelopakHost.onEvent`: `CheckInClaimedEvent`, `WheelSpunEvent`, `PromoVoucherClaimedEvent`, `VoucherRedeemedEvent`, `KelopakRedeemedEvent`, `GiftAttachedEvent`, `OrderRefundedEvent`, `GiftsShippedEvent`, `GiftsReceivedEvent`, `MissionCompletedEvent` (masing-masing `analyticsName`, `parameters`, `notice`).

### 4.2 Host

```dart
abstract class KelopakHost {
  bool get isLoggedIn;
  Listenable? get changes;            // login/keranjang berubah
  void openLogin(); void openShop(); void openCart(); void openProduct(String code);
  Future<bool> addToCart(String code, {int quantity = 1});
  List<CheckoutLine> get cartLines;   // barang berbayar, untuk progres misi
  KelopakProduct? productOf(String code);
  void playCue(GameCue cue);
  KelopakReminder? get reminder;      // "Ingatkan saya" Sabtu 09.00 WIB
  void onEvent(KelopakEvent event);   // analitik + kotak masuk
}

abstract interface class KelopakGameActions {   // opsional, diimplementasikan bersama KelopakHost
  void openCheckout(); void openOrder(String orderId);
  Future<bool> setCartQuantity(String code, int quantity);
  bool? get soundOn; void setSoundOn(bool value);
}
```

Tanpa `KelopakGameActions`: "Checkout" dan "Lihat pesanan" membuka keranjang, mengurangi jumlah membuka keranjang, tombol suara di game disembunyikan.

### 4.3 Zona Hadiah dan game

| API | Isi |
|---|---|
| `kelopakRoutes` (`Map<String, WidgetBuilder>`), `kelopakRouteFor(location)` | `/hadiah` → `RewardsHubPage`, `/hadiah/checkin` → `KelopakCheckInScreen`, `/hadiah/roda` → `KelopakWheelScreen`, `/hadiah/misi` → `KelopakMissionScreen`, `/hadiah/hadiahku` → `MyGiftsPage`, `/hadiah/voucher` → `VouchersPage`, `/hadiah/riwayat` → `LedgerPage`. Jalur di `KelopakPaths`. |
| `KelopakNavigation(open: (context, location) {...}, child:)` | Cara halaman hub berpindah jalur; bawaan `Navigator.pushNamed`. Host dengan tab memetakan `/hadiah` ke tab Hadiah. |
| `KelopakCheckInController`, `KelopakWheelController`, `KelopakMissionController` | Controller sungguhan tiap modul di atas `KelopakController` (dipakai layar `Kelopak*Screen`; boleh dipakai langsung dengan halaman modul). |
| `showKelopakHowTo(context, focus:)`, `KelopakHowTo` | Lembar "Cara pakai" dengan peluang roda dan tahap misi yang berlaku. |
| `RewardsHubPage(showBack:, onBack:)` | Zona Hadiah SPEC §5. |
| `KelopakGameStatus.all(controller)` | Status hari ini tiap game (dipakai kartu dan strip; bisa dipakai host untuk titik merah). |
| `kelopakPreviewTheme(Brightness)` | Tema token Bpedia untuk contoh/tes (host memakai `BpTheme`). |

### 4.4 Widget tanam (Beranda host)

| Widget | Isi |
|---|---|
| `KelopakWalletStrip({margin})` | Tiga sel: Kelopak + nilai rupiah (→ `/hadiah/riwayat`), voucher (→ `/hadiah/voucher`), hadiah menunggu (→ keranjang host; nol → `/hadiah/hadiahku`). Netral mengikuti tema host. Tamu: ketuk → `openLogin`. |
| `KelopakGameStrip({margin})` | Kartu pesta "Main bareng Bipy": Bipy berjalan + tiga kartu mini (Check-in, Roda Sabtu, Misi) dengan titik merah; ketuk kartu → game, latar → `/hadiah`. |
| `MissionCompleteCelebration({child, navigatorKey, enabled})` | Mendengarkan `MissionCompletedEvent` dan membuka lembar "Misi tuntas!". Fungsi langsung: `showMissionCompleteCelebration(context, voucher:, stageNumber:, onViewVouchers:)`. |

Semua widget membaca `KelopakScope` terdekat; pasang scope di atas `MaterialApp` (atau di atas navigator host).

## 5. Pemetaan `ColorScheme` host

Halaman hub membaca warna dari tema host dengan pemetaan `BpTheme` (`bpedia_app/lib/design/theme.dart`): `primary` = brand, `onPrimaryContainer` = brandStrong, `primaryContainer` = brandTint, `tertiaryContainer`/`onTertiaryContainer` = goldTint/onGoldTint, `surface`, `surfaceDim` = canvas, `surfaceContainerHighest` = surfaceMuted, `outlineVariant` = line, `onSurfaceVariant` = textMuted, `outline` = textFaint. Hero, tombol permen, dan koin memakai palet pesta tetap (`FestivePalette`).
