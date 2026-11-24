# AGENTS.md · Bpedia Preview (bpedia-kelopak-hub)

Berlaku untuk Claude, Codex, Gemini/Antigravity, dan agen lain. Bahasa kerja dan UI: Indonesia. Identifier kode: Inggris.

## Baca dulu

1. `PRD.md`: PRD pusat, sumber kebenaran.
2. `docs/SPEC-CONTRACT.md`: aturan bisnis persis dan API publik modul.
3. `docs/SPEC-UIUX.md`: layar, umpan balik, copy; ADDENDUM brand §7 mengalahkan nilai lain.
4. `docs/research/RISET-2026-11-24.md`: fakta terverifikasi dan versi paket.
5. `MEMORY.md` (keputusan), `GAMBARAN.md` (alur dan visual), `HANDOFF-PENGEMBANG.md` (setup dan build).

Repo modul bersebelahan: `../bpedia-daily-checkin`, `../bpedia-roda-sabtu`, `../bpedia-misi-belanja`.

## Aturan produk

- Aturan ekonomi Kelopak tidak boleh diubah tanpa persetujuan owner yang dicatat di `MEMORY.md`.
- Aturan bisnis hanya di modul; hub memanggil fungsi modul dan mencatat hasilnya. Hari = WIB (UTC+7).
- Jangan mengarang metrik, angka bisnis, atau klaim yang belum dicek. Nilai belum disetujui ditandai **(Demo)**.
- Clean-room: jangan membongkar atau memakai kode/aset APK produksi.
- Bipy hanya dari render resmi di `assets/images`; jangan membuat varian AI.

## Aturan kode

- Tipe ketat (tanpa `dynamic` implisit, cast eksplisit di batas JSON), null-safety, `const` bila bisa, widget kecil.
- Dispose setiap controller; jangan `setState` setelah dispose; setelah `await` cek `if (!context.mounted) return;`.
- Tanpa `print`/`debugPrint`, TODO/FIXME/placeholder, delay palsu, atau kode yang dikomentari.
- Hindari API deprecated: `withOpacity`, `SemanticsService.announce`, `WillPopScope`, `MaterialStateProperty`.
- Warna dan gaya teks hanya dari `Theme.of(context)` atau `lib/core/tokens.dart`. Uang selalu lewat `rupiah()`.
- UI: target sentuh min. 48 dp, label Semantics, teks 200% tanpa terpotong, mode gelap, hormati `MediaQuery.disableAnimationsOf`. Jangan pakai glyph `≥ → ✓` di teks UI.
- Sebelum memakai API paket pihak ketiga, cek dokumentasinya (Context7 atau sumber di pub cache) untuk versi yang dikunci.

## Keamanan

- Jangan menulis secret, kata sandi, token, atau alamat email ke kode maupun dokumen (repo ini publik).
- `android/key.properties` dan keystore tidak pernah di-commit atau ditampilkan.
- Jangan login ke akun owner memakai kata sandi.

## Sebelum selesai

```bash
flutter analyze      # bersih
flutter test         # lulus
```

Lakukan juga di modul yang disentuh. Untuk perubahan UI, cek di browser/perangkat (terang, gelap, teks besar) tanpa error console. Perbarui dokumen yang terdampak (`MEMORY.md` untuk keputusan baru).
