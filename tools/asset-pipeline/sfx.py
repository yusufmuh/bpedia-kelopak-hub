import sys, subprocess
from pathlib import Path
import numpy as np
from scipy.io import wavfile

SR = 44100
out = Path(sys.argv[1]); out.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(7)

def t(d): return np.arange(int(SR * d)) / SR
def env(n, a=0.004, decay=8.0):
    x = np.arange(n) / SR
    e = np.exp(-x * decay)
    na = max(1, int(SR * a)); e[:na] *= np.linspace(0, 1, na)
    return e
def tone(f, d, decay=8.0, a=0.004, harm=((1, 1.0),), detune=0.0):
    x = t(d); s = np.zeros_like(x)
    for k, amp in harm:
        s += amp * np.sin(2 * np.pi * f * k * x)
        if detune: s += amp * 0.5 * np.sin(2 * np.pi * f * k * (1 + detune) * x)
    return s * env(len(x), a, decay)
def bell(f, d, decay=5.0):
    return tone(f, d, decay, 0.002, ((1, 1.0), (2.0, 0.35), (3.01, 0.18), (4.2, 0.08)), detune=0.0015)
def place(buf, sig, at):
    i = int(SR * at); j = min(len(buf), i + len(sig)); buf[i:j] += sig[: j - i]; return buf
def room(x, delays=((0.031, 0.32), (0.047, 0.24), (0.071, 0.16), (0.113, 0.10))):
    y = x.copy()
    for dl, g in delays:
        n = int(SR * dl); z = np.zeros_like(x); z[n:] = x[:-n] * g; y += z
    return y
def norm(x, peak=0.82):
    x = x - np.mean(x); m = np.max(np.abs(x)) or 1.0
    fade = int(SR * 0.012); x[-fade:] *= np.linspace(1, 0, fade)
    return x / m * peak
def save(name, x, br="128k"):
    wav = out / f"{name}.wav"; mp3 = out / f"{name}.mp3"
    wavfile.write(wav, SR, (norm(x) * 32767).astype(np.int16))
    subprocess.run(["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-i", str(wav), "-ac", "1", "-b:a", br, str(mp3)], check=True)
    wav.unlink(); print(name, f"{len(x)/SR:.2f}s", mp3.stat().st_size, "bytes")

# 1. tap: soft rounded pop
d = 0.06; x = t(d); f = 900 * np.exp(-x * 40) + 380
tap = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(x), 0.002, 55)
save("tap", tap)

# 2. tick: wheel peg click (short, woody)
d = 0.035; n = int(SR * d)
noise = rng.normal(0, 1, n) * env(n, 0.0005, 160)
tick = noise * 0.5 + tone(2400, d, 120, 0.0005) * 0.6 + tone(1200, d, 90, 0.0005) * 0.3
save("tick", tick)

# 3. claim: brand motif "Bi-py" (pop, ting E6, ting A6, sparkle) per brand guideline halaman-28
buf = np.zeros(int(SR * 1.1))
d0 = 0.05; x0 = t(d0); f0 = 700 * np.exp(-x0 * 45) + 320
place(buf, np.sin(2 * np.pi * np.cumsum(f0) / SR) * env(len(x0), 0.002, 60) * 0.5, 0.0)
place(buf, bell(1318.5, 0.6, 6.0) * 0.9, 0.06)
place(buf, bell(1760.0, 0.75, 5.0) * 0.95, 0.22)
for i, f in enumerate([2637.0, 3136.0, 3520.0]):
    place(buf, bell(f, 0.35, 10.0) * 0.22, 0.42 + i * 0.045)
save("claim", room(buf))

# 4. bonus: fanfare for 7-day bonus / big win (G5 C6 E6 G6 + chord)
buf = np.zeros(int(SR * 1.5))
for i, f in enumerate([784.0, 1046.5, 1318.5]):
    place(buf, tone(f, 0.22, 9, 0.004, ((1, 1), (2, .3), (3, .12))), i * 0.11)
for f in [1046.5, 1318.5, 1568.0, 2093.0]:
    place(buf, bell(f, 1.1, 3.2) * 0.55, 0.36)
save("bonus", room(buf))

# 5. spin_start: soft whoosh up
d = 0.55; n = int(SR * d); x = t(d)
nz = rng.normal(0, 1, n)
kernel = np.ones(24) / 24
w = np.convolve(nz, kernel, mode="same") * np.sin(np.pi * x / d) ** 2
sweep = np.sin(2 * np.pi * np.cumsum(300 + 900 * (x / d) ** 2) / SR) * 0.15 * np.sin(np.pi * x / d)
save("spin_start", w + sweep)

# 6. win_product: sparkle cascade + warm chord
buf = np.zeros(int(SR * 1.8))
notes = [1568.0, 1760.0, 2093.0, 2349.3, 2637.0, 3136.0]
for i, f in enumerate(notes):
    place(buf, bell(f, 0.5, 7) * 0.5, i * 0.05)
for f in [523.25, 659.25, 783.99, 1046.5]:
    place(buf, tone(f, 1.4, 2.4, 0.03, ((1, 1), (2, .25))) * 0.45, 0.28)
save("win_product", room(buf))

# 7. soft_error: gentle two-note down (not harsh)
buf = np.zeros(int(SR * 0.42))
place(buf, tone(523.25, 0.2, 14, 0.004, ((1, 1), (2, .2))), 0.0)
place(buf, tone(392.0, 0.25, 12, 0.004, ((1, 1), (2, .2))), 0.13)
save("soft_error", buf)

# 8. unlock: mission stage unlocked (two bright notes + shimmer)
buf = np.zeros(int(SR * 0.9))
place(buf, bell(1318.5, 0.6, 7) * 0.8, 0.0)
place(buf, bell(1975.5, 0.7, 6) * 0.8, 0.12)
save("unlock", room(buf))
