# Handoff Pengembang · Bpedia Kelopak

File ini boleh dibagikan ke pengembang lain (manusia atau AI). Tidak berisi password atau token.

## Mulai dalam 5 menit

```bash
mkdir bpedia-kelopak && cd bpedia-kelopak
git clone https://github.com/yusufmuh/bpedia-kelopak-hub.git
git clone https://github.com/yusufmuh/bpedia-daily-checkin.git
git clone https://github.com/yusufmuh/bpedia-roda-sabtu.git
git clone https://github.com/yusufmuh/bpedia-misi-belanja.git
```

Keempat folder harus **bersebelahan** (hub merujuk modul lewat path `../bpedia-*` saat pengembangan lokal).

Baca dulu, berurutan:
1. `bpedia-kelopak-hub/PRD.md` — PRD pusat (aturan lintas fitur)
2. `bpedia-kelopak-hub/MEMORY.md` — keputusan owner & asumsi
3. `bpedia-kelopak-hub/GAMBARAN.md` — alur & visual
4. `PRD.md` di repo modul yang akan dikerjakan

## Kebutuhan alat

| Alat | Versi |
|---|---|
| Flutter | 3.41 stable (Dart ≥ 3.11) |
| PHP | 8.2+ dengan `pdo_sqlite` (untuk simulator demo) |
| Android Studio / Xcode | Untuk build APK / iOS |

## Menjalankan

```bash
cd bpedia-kelopak-hub
flutter pub get
flutter run -d chrome          # web
flutter run -d <android-id>    # Android
php -S localhost:8080 -t server  # simulator API demo (terminal lain)
```

Simulator butuh file logika modul di `server/` hub: salin `checkin.php`, `spin.php`, `missions.php` dari folder `server/` masing-masing repo modul. Data demo ditulis ke `KELOPAK_DATA_DIR` (default: dua folder di atas `server/`).

## Cara kerja tim

1. Buat branch: `git checkout -b fitur/<nama-singkat>`.
2. Ubah aturan lintas fitur? Update `PRD.md` + `MEMORY.md` di hub **dulu**, cantumkan tanggal & siapa yang menyetujui.
3. Ubah satu fitur? Update PRD modul + test di repo modul itu.
4. Sebelum PR: `flutter analyze` bersih dan `flutter test` hijau (lihat §10 PRD pusat).
5. Buka Pull Request ke `main`. Jangan push langsung ke `main`.
6. Rilis modul diberi tag `vX.Y.Z` agar app Bpedia bisa mengunci versi.

## Aturan yang tidak boleh dilanggar

- Saldo, streak, hasil roda, dan voucher **ditentukan server**. Klien hanya menampilkan.
- Hari = WIB dari server. Jangan pakai jam perangkat untuk keputusan.
- Setiap klaim memakai `Idempotency-Key`. Klaim ganda = satu hasil.
- Peluang roda wajib tampil sebelum tombol putar aktif.
- Jangan commit secret (`.env`, keystore, token, password). Kredensial disimpan di luar repo.
- Nilai yang belum disetujui owner ditandai **Demo** di UI.

## Untuk agen AI (Claude, Codex, Antigravity)

Setiap repo punya `AGENTS.md` (Codex & Antigravity), `CLAUDE.md` (Claude), dan `GEMINI.md` (Antigravity) yang semuanya menunjuk ke `PRD.md` pusat di hub. Saat berhenti bekerja, tulis status singkat di bagian **Riwayat** PRD terkait.

## Kontak

Owner produk: Muhammad Yusuf (Bpedia).
