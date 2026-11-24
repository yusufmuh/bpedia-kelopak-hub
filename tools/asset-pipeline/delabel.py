import sys
import numpy as np
from PIL import Image

src, dst = sys.argv[1], sys.argv[2]
x0, y0, x1, y1 = map(int, sys.argv[3:7])
a = np.asarray(Image.open(src).convert("RGB")).astype(np.float32)
m = 4
for x in range(x0, x1):
    top = a[y0 - m:y0, x].mean(axis=0)
    bot = a[y1:y1 + m, x].mean(axis=0)
    for y in range(y0, y1):
        t = (y - y0) / max(1, (y1 - y0))
        a[y, x] = top * (1 - t) + bot * t
rng = np.random.default_rng(3)
a[y0:y1, x0:x1] += rng.normal(0, 0.8, a[y0:y1, x0:x1].shape)
feather = 3
blur = np.asarray(Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))).astype(np.float32)
Image.fromarray(np.clip(blur, 0, 255).astype(np.uint8)).save(dst)
print("ok", dst)
