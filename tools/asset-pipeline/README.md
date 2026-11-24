# Pipeline aset Bpedia Demo

Skrip yang dipakai untuk membuat aset di `assets/` (24 Nov 2026). Semua aset sudah ada di repo; skrip ini hanya untuk membuat ulang atau menambah aset dengan gaya yang sama. Jalankan dari folder kerja terpisah, bukan dari dalam repo.

| Skrip | Input | Output | Alat |
|---|---|---|---|
| `fonts.py <dir_woff2> <dir_out>` | `02_Brand Guidline/03_Warna_Font/font-web/*.woff2` | Poppins 400–800 + Fraunces italic `.ttf` | Python, fontTools + brotli |
| `images.py <dir_brand> <dir_out>` | `02_Brand Guidline/` (Bipy, logo, placeholder produk) | `*.webp` dipangkas & diperkecil | Pillow |
| `render3d.py -- <dir_out>` | — | `kelopak_token_3d.png`, `gift_box_3d.png` | Blender 5.2: `blender -b --factory-startup -P render3d.py -- <dir_out>` |
| `queue_products2.py` | ComfyUI lokal `127.0.0.1:8188` + checkpoint `realvisxlV50_v50LightningBakedvae` | packshot produk tanpa merek di podium pink | ComfyUI (SDXL Lightning, 6 step) |
| `products.py <dir_output_comfyui>` | hasil ComfyUI | `produk_*.webp` 600 px, tint blush | Pillow |
| `delabel.py <src> <dst> x0 y0 x1 y1` | packshot dengan teks palsu AI | area label diisi ulang per kolom | NumPy + Pillow |
| `sfx.py <dir_out>` | — | 8 SFX MP3 (`claim` = motif brand "Bi-py" E6 → A6) | NumPy, SciPy, ffmpeg |
| `sfx_check.py` | `audio/*.mp3` | puncak/RMS + spektrogram (cek clipping) | NumPy, matplotlib, ffmpeg |
| `preview_icon.py` | ikon app brand + Poppins-800 | ikon launcher dengan pita "DEMO" | Pillow |

Aturan: jangan membuat ulang atau memvariasikan Bipy dengan AI (pakai render resmi `02_Bipy`). Foto produk hasil AI hanya untuk Mode Demo dan diberi label "Foto ilustrasi"; produksi wajib memakai foto produk resmi. Cek setiap aset secara manual sebelum masuk repo (teks palsu, bentuk rusak, warna di luar palet).
