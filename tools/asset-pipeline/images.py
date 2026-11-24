import sys
from pathlib import Path
from PIL import Image

brand = Path(sys.argv[1])
out = Path(sys.argv[2]); out.mkdir(parents=True, exist_ok=True)
jobs = {
    "bipy_menyapa": (brand/"02_Bipy/bipy-full-menyapa.png", 720),
    "bipy_berdiri": (brand/"02_Bipy/bipy-full-berdiri.png", 720),
    "bipy_ngintip": (brand/"02_Bipy/bipy-ngintip.png", 640),
    "bipy_senyum": (brand/"02_Bipy/bipy-wajah-senyum.png", 480),
    "bipy_wink": (brand/"02_Bipy/bipy-wajah-wink.png", 480),
    "bipy_tas_hati": (brand/"02_Bipy/bipy-tas-hati.png", 640),
    "bipy_tas_depan": (brand/"02_Bipy/bipy-tas-depan.png", 480),
    "logo_horizontal": (brand/"01_Logo/bpedia-logo-horizontal-flat.png", 640),
    "logo_horizontal_reverse": (brand/"01_Logo/bpedia-logo-horizontal-flat-reverse.png", 640),
    "monogram_putih": (brand/"01_Logo/bpedia-monogram-putih.png", 256),
    "monogram_plum": (brand/"01_Logo/bpedia-monogram-plum.png", 256),
}
for p in sorted((brand/"09_Produk_placeholder").glob("*.png")):
    jobs["produk_" + p.stem.replace("placeholder-", "").replace("-", "_")] = (p, 600)

sheet = []
for name, (src, maxside) in jobs.items():
    im = Image.open(src)
    im = im.convert("RGBA")
    bbox = im.getchannel("A").getbbox()
    if bbox and name.startswith("bipy"):
        im = im.crop(bbox)
    im.thumbnail((maxside, maxside), Image.LANCZOS)
    dst = out / f"{name}.webp"
    im.save(dst, "WEBP", quality=88, method=6)
    print(f"{name}: {src.name} {Image.open(src).size} -> {im.size} {dst.stat().st_size//1024} KB")
    sheet.append(im)

w = 220; h = 240
cols = 6
rows = (len(sheet) + cols - 1) // cols
cs = Image.new("RGBA", (cols*w, rows*h), (255, 247, 248, 255))
for i, im in enumerate(sheet):
    t = im.copy(); t.thumbnail((w-10, h-10))
    cs.alpha_composite(t, ((i % cols)*w + (w - t.width)//2, (i//cols)*h + (h - t.height)//2))
cs.convert("RGB").save(out.parent / "contact_sheet.jpg", quality=80)
