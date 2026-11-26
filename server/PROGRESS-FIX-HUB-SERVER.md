# Progres perbaikan HUB-SERVER

Lingkup: `server/**`, `docs/BACKEND.md`, §3 `docs/SPEC-CONTRACT.md`, bagian backend `HANDOFF-PENGEMBANG.md`, baris `server/` di `README.md`.

- [x] Salin `spin.php` dan `missions.php` v3 dari repo modul (checkin.php sudah identik)
- [x] R1-09 server referensi v3: `kelopak.php` (mesin), `kelopak_http.php` + `index.php` (HTTP), `campaign.bpedia-demo.json`
- [x] R1-10 claimPromo: nilai voucher dari katalog promo server, nilai dari klien diabaikan
- [x] Idempoten per `Idempotency-Key` + idempotensi alami (komit dengan token sama)
- [x] Swa-uji `php server/selftest.php` lolos (108 cek + swa-uji tiga modul)
- [x] Uji ujung ke ujung `RemoteKelopakBackend` lawan `php -S` (scratch di %TEMP%): 3 tes lolos; keadaan akhir sama persis dengan `LocalKelopakBackend`, `amount` 999999 dari klien menjadi 12000
- [x] Dokumen: `docs/BACKEND.md`, SPEC-CONTRACT §3 (galat HTTP, token sesi, claimPromo), HANDOFF, README
- [x] flutter analyze hub bersih, commit lokal berkas lingkup
