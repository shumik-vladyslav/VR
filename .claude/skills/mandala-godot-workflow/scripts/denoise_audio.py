# Очистка голосовой записи: профиль шума берётся из тихих пауз (находятся сами), спектральный гейт
# с мягким «полом», срез гула ниже ~60 Гц, нормализация пика до -1 dBFS. Пишет OGG Vorbis.
# Запуск: blender.exe --background --factory-startup --python denoise_audio.py -- in.mp3 out.ogg
import aud, sys, os
import numpy as np

inp, outp = sys.argv[sys.argv.index("--") + 1:][:2]
snd = aud.Sound(inp)
rate = int(snd.specs[0])
x = snd.data().astype(np.float32)
N, HOP = 2048, 512
win = np.hanning(N).astype(np.float32)

def stft(sig):
    pad = np.pad(sig, (N, N))
    n = 1 + (len(pad) - N) // HOP
    idx = np.arange(N)[None, :] + HOP * np.arange(n)[:, None]
    return np.fft.rfft(pad[idx] * win, axis=1).astype(np.complex64)

def istft(S, length):
    frames = np.fft.irfft(S, n=N, axis=1).astype(np.float32) * win
    out = np.zeros(N + HOP * (S.shape[0] - 1), np.float32)
    wsum = np.zeros_like(out)
    for i in range(S.shape[0]):
        out[i * HOP:i * HOP + N] += frames[i]
        wsum[i * HOP:i * HOP + N] += win ** 2
    return (out / np.maximum(wsum, 1e-6))[N:N + length]

def smooth2d(a, rt, rf):
    for axis, r in ((0, rt), (1, rf)):
        c = np.cumsum(np.pad(a, [(r + 1, r) if i == axis else (0, 0) for i in range(2)], mode='edge'), axis=axis)
        n = a.shape[axis]
        a = (np.take(c, np.arange(2 * r + 1, 2 * r + 1 + n), axis=axis) - np.take(c, np.arange(n), axis=axis)) / (2 * r + 1)
    return a

# Тихие паузы: кадры 0.1 с не громче (8-й перцентиль + 6 дБ), не короче 0.5 с
mono = x.mean(axis=1)
hop = int(rate * 0.1); n = len(mono) // hop
db = 20 * np.log10(np.sqrt((mono[:n * hop].reshape(n, hop) ** 2).mean(axis=1)) + 1e-12)
quiet = db < np.percentile(db, 8) + 6
spans, i = [], 0
while i < n:
    if quiet[i]:
        j = i
        while j < n and quiet[j]:
            j += 1
        if j - i >= 5:
            spans.append(((i + 1) / 10, (j - 1) / 10))
        i = j
    else:
        i += 1
print("NOISE_SPANS %d, %.1fs total" % (len(spans), sum(b - a for a, b in spans)))

out = np.zeros_like(x)
freqs = np.fft.rfftfreq(N, 1 / rate)
for ch in range(x.shape[1]):
    S = stft(x[:, ch])
    mag = np.abs(S)
    t = (np.arange(S.shape[0]) * HOP - N / 2) / rate
    nmask = np.zeros(S.shape[0], bool)
    for a, b in spans:
        nmask |= (t >= a) & (t <= b)
    noise_pow = (mag[nmask] ** 2).mean(axis=0)
    p = smooth2d(mag ** 2, 2, 1)
    gain = np.clip(1.0 - 2.5 * noise_pow[None, :] / np.maximum(p, 1e-12), 0.0, 1.0)
    gain = smooth2d(gain, 3, 2)
    floor = 10 ** (-22 / 20)
    gain = floor + (1 - floor) * gain
    gain *= np.clip((freqs - 40) / 30, 0, 1)[None, :]
    out[:, ch] = istft(S * gain, x.shape[0])

peak = np.abs(out).max()
out *= 10 ** (-1 / 20) / peak

def span_db(sig):
    m = sig.mean(axis=1)
    v = [20 * np.log10(np.sqrt((m[int(a * rate):int(b * rate)] ** 2).mean()) + 1e-12) for a, b in spans]
    return float(np.mean(v))
raw = x * (10 ** (-1 / 20) / np.abs(x).max())
print("NOISE_FLOOR raw=%.1f dB clean=%.1f dB" % (span_db(raw), span_db(out)))

aud.Sound.buffer(out, rate).write(outp, rate, aud.CHANNELS_STEREO, aud.FORMAT_FLOAT32, aud.CONTAINER_OGG, aud.CODEC_VORBIS, 192000, 0)
print("WROTE", outp, os.path.getsize(outp))
