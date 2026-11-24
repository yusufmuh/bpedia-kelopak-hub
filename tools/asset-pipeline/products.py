import os
import sys
from pathlib import Path
from PIL import Image, ImageEnhance

src = Path(sys.argv[1] if len(sys.argv) > 1 else os.environ.get("COMFYUI_OUTPUT", "comfyui-output"))
out = Path("images"); out.mkdir(exist_ok=True)
names = ["serum", "cream", "facialwash", "bodyserum", "liptint", "shampoo", "perfume", "cushion", "bodysoap"]
sheet = []
for n in names:
    f = src / f"bpedia_prod_{n}_00001_.png"
    if not f.exists():
        print("MISSING", f.name); continue
    im = Image.open(f).convert("RGB")
    im = ImageEnhance.Brightness(im).enhance(1.05)
    tint = Image.new("RGB", im.size, (253, 231, 236)); im = Image.blend(im, tint, 0.12)
    im.thumbnail((600, 600), Image.LANCZOS)
    dst = out / f"produk_{n}.webp"; im.save(dst, "WEBP", quality=82, method=6)
    print(n, im.size, dst.stat().st_size // 1024, "KB"); sheet.append(im)
if sheet:
    w = 256; cs = Image.new("RGB", (w * 3, w * ((len(sheet) + 2) // 3)), (255, 255, 255))
    for i, im in enumerate(sheet):
        t = im.copy(); t.thumbnail((w, w)); cs.paste(t, ((i % 3) * w, (i // 3) * w))
    cs.save("renders/products_preview.jpg", quality=80)
