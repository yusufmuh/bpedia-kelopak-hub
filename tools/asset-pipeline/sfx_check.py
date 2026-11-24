import subprocess, numpy as np
from pathlib import Path
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
files = sorted(Path("audio").glob("*.mp3"))
fig, axes = plt.subplots(len(files), 2, figsize=(10, 1.25 * len(files)))
for row, f in zip(axes, files):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(f), "-ac", "1", "-ar", "22050", "-f", "s16le", "-"], capture_output=True, check=True).stdout
    x = np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768
    if f.stem == "bgm_jingle": x = x[: 22050 * 6]
    peak = float(np.max(np.abs(x))); rms = float(np.sqrt(np.mean(x ** 2)))
    row[0].plot(np.arange(len(x)) / 22050, x, lw=0.4, color="#D81F57"); row[0].set_ylim(-1, 1)
    row[0].set_title(f"{f.stem}  peak {peak:.2f}  rms {rms:.3f}  {len(x)/22050:.2f}s", fontsize=7, loc="left")
    row[1].specgram(x, Fs=22050, NFFT=512, noverlap=384, cmap="magma"); row[1].set_ylim(0, 8000)
    for a in row: a.tick_params(labelsize=5)
    print(f.stem, f"peak={peak:.2f}", f"rms={rms:.3f}", f"clip={(np.abs(x) > 0.99).sum()}")
plt.tight_layout(); plt.savefig("renders/sfx_check.png", dpi=90)
