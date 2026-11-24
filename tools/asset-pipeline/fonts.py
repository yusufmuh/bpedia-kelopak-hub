import sys
from pathlib import Path
from fontTools.ttLib import TTFont

src = Path(sys.argv[1])
dst = Path(sys.argv[2])
dst.mkdir(parents=True, exist_ok=True)
for f in sorted(src.glob("*.woff2")):
    font = TTFont(str(f))
    font.flavor = None
    out = dst / (f.stem + ".ttf")
    font.save(str(out))
    names = {r.nameID: r.toUnicode() for r in font["name"].names if r.nameID in (1, 2, 4)}
    print(out.name, out.stat().st_size, names.get(4), "glyphs", len(font.getGlyphOrder()), "fvar" if "fvar" in font else "")
