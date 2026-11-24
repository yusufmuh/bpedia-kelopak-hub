# Kontrak Implementasi v2 · Bpedia Preview (clean-room) + 3 Modul Kelopak

Dokumen kerja untuk agen implementasi. Bahasa UI: Indonesia. Bahasa kode/identifier: Inggris. Tanpa placeholder/TODO.

## 0. Batas

- Aplikasi dibangun ulang dari nol (clean-room) memakai brand guideline resmi dan screenshot milik owner sebagai referensi UX. Tidak memakai kode/aset dari APK produksi.
- applicationId Android: `id.bpedia.preview` · label: `Bpedia Demo` (§4; "Bpedia Preview" = nama teknis proyek) · iOS bundle: `id.bpedia.preview`. Tidak bentrok dengan app produksi.
- Semua data adalah **Mode Demo** (engine lokal di perangkat, persist di shared_preferences). Tidak ada login/backend nyata. Label "Demo" tampil pada nilai yang belum disetujui bisnis.
- Teks UI tidak memakai glyph `≥ → ✓` (font Poppins subset tidak punya). Pakai kata ("min.") atau ikon.

## 1. Aturan bisnis (wajib persis)

| Fitur | Aturan |
|---|---|
| Kelopak | 1 Kelopak = Rp100. Integer, saldo tidak pernah negatif. Saldo = jumlah ledger. |
| Check-in | +1 Kelopak per tanggal WIB (UTC+7), satu kali per tanggal. Setiap hari ke-7, 14, 21, … beruntun: +3 bonus (total 7 hari = 10 Kelopak = Rp1.000). Setiap hari ke-30, 60, … beruntun: 1 hak produk gratis. Bolong 1 tanggal = rentetan mulai dari 1 lagi; saldo & hak tidak hilang. |
| Roda Sabtu | Gratis, 1 putaran per akun per Sabtu WIB (00.00–23.59) saat promo aktif. Hadiah: produk (sesuai stok) atau Kelopak. Peluang (%) + sisa kuota + ketentuan ongkir tampil SEBELUM tombol putar. Hasil ditentukan engine (bukan animasi). Demo: produk 10% (stok 1), 3 Kelopak 90%; stok 0 → produk 0%, Kelopak 100%. |
| Misi Belanja | Tahap 1: pesanan SELESAI dengan subtotal barang min. Rp75.000 → voucher Rp10.000, berlaku untuk pesanan LAIN berikutnya dengan min. belanja Rp100.000. Setelah voucher tahap N terbit, tahap N+1 terbuka. Demo tahap 2: selesai min. Rp100.000 → voucher Rp5.000 (min. Rp100.000). Sesudah tahap terakhir: "Tahap berikutnya menunggu kampanye". Satu pesanan hanya dihitung sekali. Voucher berlaku 30 hari (Demo). |
| Pakai Kelopak (Demo) | Di checkout bisa dipakai sebagai potongan, maks. 50% subtotal (Demo, menunggu keputusan bisnis). Tercatat sebagai debit ledger. |

Hari WIB: `wibDay = (utcMillis + 7*3600*1000) ~/ 86400000`. Weekday (1=Senin..7=Minggu): `((wibDay + 3) % 7) + 1` (hari 0 = Kamis 1 Jan 1970). Sabtu: `((wibDay + 3) % 7) + 1 == 6`. Tanggal kalender WIB: `DateTime.utc(1970,1,1).add(Duration(days: wibDay))`.

## 2. API publik modul (signature tetap; hub memakai ini)

### daily_checkin (`package:daily_checkin/daily_checkin.dart`)
```dart
abstract final class CheckInRules { static const int dailyKelopak = 1; static const int bonusEvery = 7; static const int bonusKelopak = 3; static const int productEvery = 30; }
int wibDayOf(DateTime instant);
int wibWeekdayOf(int wibDay);            // 1..7
DateTime wibDateOf(int wibDay);          // UTC DateTime = tanggal kalender WIB
final class CheckInAward { const CheckInAward({required this.streak, required this.dailyKelopak, required this.bonusKelopak, required this.productEntitled}); final int streak; final int dailyKelopak; final int bonusKelopak; final bool productEntitled; int get totalKelopak; }
CheckInAward? evaluateCheckIn({required int today, required int? lastClaimDay, required int streak}); // null jika today <= lastClaimDay
int liveStreak({required int today, required int? lastClaimDay, required int streak}); // 0 jika rentetan putus (last < today-1)
bool isClaimedOn({required int today, required int? lastClaimDay});
int filledInWeek({required int liveStreak, required bool claimedToday});   // 0..7
int dayInMonthCycle({required int liveStreak, required bool claimedToday}); // 0..30
enum CheckInButtonState { ready, claimed }
class CheckInWeekTrack extends StatelessWidget   // 7 slot, slot 7 = hadiah bonus +3; slot "Hari ini" disorot; Semantics per slot
  ({required int filled, required bool claimedToday, required Widget currencyIcon, Widget? bonusIcon})
class CheckInMonthProgress extends StatelessWidget // progres 0..30 + penanda 7/14/21/28 + hadiah di 30
  ({required int day, Widget? rewardImage})
class CheckInClaimButton extends StatelessWidget
  ({required CheckInButtonState state, required VoidCallback? onPressed, required String claimedHint})
```

### roda_sabtu (`package:roda_sabtu/roda_sabtu.dart`)
```dart
bool isSaturdayWib(int wibDay);
int daysUntilSaturday(int wibDay);       // 0 jika Sabtu
enum PrizeKind { product, kelopak }
final class SpinPrize { const SpinPrize({required this.id, required this.kind, required this.label, required this.kelopak, required this.weight}); final String id; final PrizeKind kind; final String label; final int kelopak; final int weight; } // weight basis poin, total 10000
final class SpinConfig { const SpinConfig({required this.version, required this.prizes, required this.shippingNote}); ... }
const SpinConfig demoSpinConfig;         // 'demo-2026-11': produk 1000, 3 Kelopak 9000, ongkir: "Gratis ongkir (Demo)"
final class SpinOdds { final SpinPrize prize; final int weight; double get percent; }
List<SpinOdds> effectiveOdds(SpinConfig config, {required int productStock}); // stok 0 → produk 0, sisa dibagi proporsional ke Kelopak; total selalu 10000
SpinPrize resolveSpin(SpinConfig config, {required int productStock, required int roll}); // roll 0..9999 (assert)
enum SpinEligibility { available, alreadySpun, notSaturday, promoInactive }
SpinEligibility spinEligibility({required int today, required int? lastSpinDay, required bool promoActive});
class SaturdayWheel extends StatefulWidget  // segmen proporsional peluang; jarum di atas; animasi ease-out ~4 dtk ke segmen hasil; reduce motion = langsung
  ({required List<SpinOdds> odds, required String? resultPrizeId, required int spinToken, required int landingSeed, VoidCallback? onSettled, VoidCallback? onPegPassed, Widget? centerChild})
class OddsTable extends StatelessWidget ({required List<SpinOdds> odds, required int productStock, required String shippingNote})
```

### misi_belanja (`package:misi_belanja/misi_belanja.dart`)
```dart
final class MissionStage { const MissionStage({required this.number, required this.minOrderSubtotal, required this.voucherAmount, required this.voucherMinSpend, required this.voucherValidDays}); ... }
const List<MissionStage> demoMissionStages; // [1: 75000→10000 min 100000, 2: 100000→5000 min 100000], valid 30 hari
enum StageStatus { completed, active, locked }
StageStatus stageStatus({required int stageIndex, required int issuedCount});
bool allStagesDone({required List<MissionStage> stages, required int issuedCount});
enum OrderRejection { notCompleted, belowThreshold, alreadyCounted, allStagesDone }
final class MissionDecision { final MissionStage? issuedStage; final OrderRejection? rejection; bool get issued; }
MissionDecision evaluateOrder({required List<MissionStage> stages, required int issuedCount, required Set<String> countedOrderIds, required String orderId, required int eligibleSubtotal, required bool completed});
final class MissionVoucher { const MissionVoucher({required this.id, required this.stageNumber, required this.sourceOrderId, required this.amount, required this.minSpend, required this.issuedDay, required this.expiresDay, this.usedOnOrderId}); ... MissionVoucher markUsed(String orderId); Map<String,Object?> toJson(); factory fromJson(...); }
enum RedeemProblem { belowMinimum, sameOrder, alreadyUsed, expired }
RedeemProblem? redeemProblem({required MissionVoucher voucher, required String orderId, required int subtotal, required int today});
String rupiah(int amount);               // "Rp10.000"
class MissionLadder extends StatelessWidget ({required List<MissionStage> stages, required int issuedCount, String? pendingNote})
class VoucherCard extends StatelessWidget ({required MissionVoucher voucher, required int today, VoidCallback? onUse})
```

Semua widget modul hanya memakai `Theme.of(context)` (ColorScheme + TextTheme) dan slot widget dari host; tanpa warna hardcode selain ilustrasi.

## 2b. Hub (kelopak_hub) — keputusan teknis

- Paket: `audioplayers ^6.7.1`, `shared_preferences ^2.5.6`, `flutter_svg ^2.3.4`, `url_launcher ^6.3.3`, `flutter_localizations` (SDK; locale tunggal `id`); dev: `flutter_launcher_icons ^0.14.4`, `flutter_native_splash ^2.4.7`, `flutter_lints ^6.0.0`. Environment `sdk: ^3.11.0`, `flutter: '>=3.41.0'`.
- Penyimpanan: interface `KeyValueStore { Future<String?> read(String key); Future<void> write(String key, String value); Future<void> delete(String key); }` dengan implementasi `SharedPreferencesAsync` (produksi) dan `MemoryKeyValueStore` (tes). Satu dokumen JSON kunci `bpedia_preview_state_v1`, `"schema": 1`. JSON rusak/skema tak dikenal → mulai baru tanpa crash.
- Suara: `AudioPool` per SFX (mode default mediaPlayer), BGM `AudioPlayer` loop. Semua panggilan audio dibungkus agar kegagalan (web autoplay, codec) tidak pernah melempar error ke UI.
- Tautan resmi (Akun > Tentang): `https://bpedia.id` dan unduh app resmi `https://beautypediaofc.onelink.me/hebt/9fer7r7y` via `launchUrl(..., mode: LaunchMode.externalApplication)`.
- Jam: `AppClock` (now() bisa disuntik + `demoOffsetDays`) → `today` = `wibDayOf(now) + offset`.
- Acak: `Random.secure()` di AppState untuk `roll` (0..9999) dan `landingSeed`; engine murni deterministik (mudah dites).
- Hindari API deprecated: `withOpacity` → `withValues(alpha:)`, `SemanticsService.announce` → `sendAnnouncement`, `WillPopScope` → `PopScope`, `MaterialStateProperty` → `WidgetStateProperty`.

## 3. Pemetaan ColorScheme (host)

primary `#D81F57` · onPrimary `#FFFFFF` · primaryContainer `#FDE7EC` · onPrimaryContainer `#45122B` · secondary `#B3164B` · onSecondary `#FFFFFF` · secondaryContainer `#FBCFDB` · onSecondaryContainer `#45122B` · tertiary `#F5B83D` · onTertiary `#2A0A18` · tertiaryContainer `#FFF4DB` · onTertiaryContainer `#8A5A00` · surface `#FFF7F8` · onSurface `#45122B` · onSurfaceVariant `#6E4556` · surfaceContainerLowest `#FFFFFF` · surfaceContainerLow `#FFF7F8` · surfaceContainer `#FDE7EC` · outline `#9C7E8A` · outlineVariant `#F3D3DD` · error `#C62828`. Gelap mengikuti token `[data-theme="dark"]` brand.
Tipografi Poppins: display 28/34 w700, title 22/28 w600, headline 18/24 w600, body 16/24 w400, body-s 14/20 w400, caption 12/16 w500, button 16/20 w600, price 18/24 w800. Tagline: Fraunces italic.
Radius 6/10/16/24/40/pill · spasi 4/8/12/16/24/32/48 · target sentuh min. 48 dp · bayangan kartu `0 10 30 rgba(179,22,75,.08)`.

## 4. ADDENDUM brand (mengalahkan nilai di atas bila bertentangan)

- FilledButton/OutlinedButton/TextButton: `StadiumBorder()` (pil), `minimumSize: Size(64, 52)`, padding horizontal 24, label 16 w600. OutlinedButton sekunder: isi putih (`surfaceContainerLowest`), garis & label `secondary` (Berry `#B3164B`).
- Chip: `StadiumBorder`; tidak aktif putih + garis `outlineVariant` + label `onSurface`; terpilih `primaryContainer` + garis & label `secondary`.
- Card produk: radius 16, border 1,5 px `outlineVariant`, bayangan kartu brand. Harga: `secondary` w800. Harga coret: `onSurfaceVariant` + lineThrough.
- Nama tampil app: **"Bpedia Demo"** (label launcher maks. 12 karakter). Logo AppBar: `assets/images/logo_wordmark_bipy.webp` (gelap: `logo_wordmark_reverse.webp`).
- Lihat `SPEC-UIUX.md` §7 untuk aturan lengkap (badge, Bipy pose, voice "Babes", audio context).
