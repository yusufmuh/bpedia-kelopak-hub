# AGENTS.md · Bpedia Kelopak Hub (repo pusat)

Berlaku untuk Codex, Antigravity, Claude, dan agen lain. Bahasa kerja: Indonesia.

## Baca dulu
1. `PRD.md` — PRD pusat, sumber kebenaran tunggal
2. `MEMORY.md` — keputusan owner dan asumsi terbuka
3. `GAMBARAN.md` — alur pengguna dan arah visual
4. `HANDOFF-PENGEMBANG.md` — setup dan cara kerja

Repo modul (bersebelahan dengan folder ini): `../bpedia-daily-checkin`, `../bpedia-roda-sabtu`, `../bpedia-misi-belanja`.

## Aturan
- Aturan ekonomi Kelopak (PRD §2–3) tidak boleh diubah tanpa persetujuan owner yang dicatat di `MEMORY.md`.
- Server yang menentukan saldo, streak, hasil roda, dan voucher. Hari = WIB.
- Jangan mengarang metrik atau angka bisnis; tandai nilai belum disetujui sebagai **Demo**.
- Jangan menulis secret ke file mana pun. Jangan login ke akun owner dengan password.
- Sebelum selesai: `flutter analyze` bersih, `flutter test` hijau, cek web tanpa error console.
- Tidak boleh ada placeholder/TODO di kode yang dikirim.
- Akhiri sesi dengan update bagian **Riwayat** di PRD yang disentuh.
