# Вырезает божество из сгенерированной картинки «фигура в золотом ореоле на фиолетовом фоне с кольцом искр».
# Фон убирается по фиолетовому цвету; искры (белые точки на фоне) отбрасываются тем, что остаётся только то,
# что связано с центром картинки (фигура + ореол + лотос + ездовое животное). Результат обрезается по фигуре.
# Запуск: blender.exe --background --factory-startup --python cut_generated.py -- <папка с <id>.webp|png> <папка вывода>
#         [--preview <папка>] [--max-h 1024] [id ...]
import bpy, sys, os
import numpy as np

argv = sys.argv[sys.argv.index("--") + 1:]
src_dir, out_dir = argv[0], argv[1]
rest = argv[2:]
prev = ""
max_h = 1024
ids = []
halo_override = {}
i = 0
while i < len(rest):
    if rest[i] == "--preview":
        prev = rest[i + 1]; i += 2
    elif rest[i] == "--halo":
        # круг ореола вручную, если найденный (sheet_circles.png) лёг не туда: --halo agni=837,472,226
        k_, v_ = rest[i + 1].split("=")
        halo_override[k_] = tuple(float(x) for x in v_.split(","))
        i += 2
    elif rest[i] == "--max-h":
        max_h = int(rest[i + 1]); i += 2
    else:
        ids.append(rest[i]); i += 1
if not ids:
    ids = sorted(os.path.splitext(f)[0] for f in os.listdir(src_dir) if f.lower().endswith((".webp", ".png", ".jpg")))
os.makedirs(out_dir, exist_ok=True)

def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)

def background_alpha(rgb):
    # фиолетовый фон: оттенок 220–310°, заметная насыщенность → 0; остальное → 1
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx = rgb.max(axis=-1); mn = rgb.min(axis=-1)
    sat = (mx - mn) / (mx + 1e-5)
    dlt = mx - mn + 1e-5
    hue = np.zeros_like(mx)
    hue = np.where(mx == r, ((g - b) / dlt) % 6, hue)
    hue = np.where(mx == g, (b - r) / dlt + 2, hue)
    hue = np.where(mx == b, (r - g) / dlt + 4, hue)
    hue *= 60.0
    hue_w = smoothstep(215, 235, hue) * (1 - smoothstep(295, 315, hue))
    return 1.0 - hue_w * smoothstep(0.06, 0.16, sat)

def dilate(m, n=1):
    for _ in range(n):
        r = m.copy()
        r[1:] |= m[:-1]; r[:-1] |= m[1:]; r[:, 1:] |= m[:, :-1]; r[:, :-1] |= m[:, 1:]
        m = r
    return m

def flood(seed, passable):
    cur = seed & passable
    while True:
        nxt = cur
        for _ in range(16):
            nxt = dilate(nxt) & passable
        if (nxt == cur).all():
            return cur
        cur = nxt

def erode(m, n=1):
    return ~dilate(~m, n)

def open_(m, n):
    # убирает детали тоньше 2n+1 пикселей
    return dilate(erode(m, n), n)

def find_halo(rgb):
    # золотой/кремовый круг ореола: подбираем радиус, при котором ширина тёплой области по строкам
    # сверху до середины лучше всего совпадает с кругом
    val = rgb.max(-1)
    warm = open_((rgb[..., 0] - rgb[..., 2] > 0.06) & (val > 0.55), 3)
    H, W = warm.shape
    cnt = warm.sum(1)
    y_top = int(np.argmax(cnt > 40))
    any_ = cnt > 0
    left = np.where(any_, warm.argmax(1), 0)
    right = np.where(any_, W - 1 - warm[:, ::-1].argmax(1), 0)
    hw = (right - left) / 2.0
    mid = (right + left) / 2.0
    best = None
    for rr in range(120, 460, 2):
        ys = np.arange(y_top + int(0.1 * rr), min(H, y_top + int(0.9 * rr)))
        e = np.sqrt(np.maximum(rr * rr - (ys - (y_top + rr)) ** 2, 0))
        err = np.median(np.abs(hw[ys] - e))
        if best is None or err < best[0]:
            best = (err, rr, float(np.median(mid[ys])))
    _, rr, cx = best
    return cx, float(y_top + rr), float(rr)

halo_info = {}

def load(path):
    im = bpy.data.images.load(path)
    w, h = im.size
    px = np.empty(w * h * 4, np.float32); im.pixels.foreach_get(px)
    return px.reshape(h, w, 4)[::-1].copy()

def save(arr, path):
    h, w = arr.shape[:2]
    o = bpy.data.images.new(os.path.basename(path), w, h, alpha=True)
    o.pixels.foreach_set(arr[::-1].ravel())
    o.filepath_raw = path; o.file_format = 'PNG'; o.save()

def resize(arr, nh):
    # уменьшение усреднением по блокам (box filter) с дробным шагом
    h, w = arr.shape[:2]
    s = h / nh
    nw = int(round(w / s))
    ys = (np.arange(nh + 1) * s).astype(int); xs = (np.arange(nw + 1) * w / nw).astype(int)
    c = np.cumsum(np.cumsum(np.pad(arr, ((1, 0), (1, 0), (0, 0))), 0), 1)
    tot = c[ys[1:]][:, xs[1:]] - c[ys[:-1]][:, xs[1:]] - c[ys[1:]][:, xs[:-1]] + c[ys[:-1]][:, xs[:-1]]
    area = ((ys[1:] - ys[:-1])[:, None] * (xs[1:] - xs[:-1])[None, :])[..., None]
    return tot / area

thumbs = []
circ = []
for id_ in ids:
    fn = next(f for f in os.listdir(src_dir) if os.path.splitext(f)[0] == id_)
    img = load(os.path.join(src_dir, fn))
    H, W = img.shape[:2]
    rgb = img[..., :3]
    key = background_alpha(rgb)
    val = rgb.max(-1)
    yy, xx = np.mgrid[0:H, 0:W]
    # 1. круг ореола: внутри него всё непрозрачно (синяя кожа Вишну, Шивы, Агхоры по цвету похожа на фон)
    cx, cy, r = halo_override[id_] if id_ in halo_override else find_halo(rgb)
    dist = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    inside = dist < r * 0.96
    # 2. снаружи круга — то, что связано с ореолом (лотос, руки, оружие, ездовое животное).
    # Фон всегда светлый, поэтому тёмное (кожа Агхоры) оставляем, даже если оно синевато-фиолетовое.
    dark = smoothstep(0.75, 0.65, val)
    base = (key > 0.5) | (dark > 0.5)
    warm = rgb[..., 0] - rgb[..., 2] > 0.04
    # у верхнего края ореола от него расходятся белые лучи — там из не-золотого оставляем только толстое (оружие)
    band = (dist >= r * 0.96) & (dist < r * 1.3) & (yy < cy + 0.2 * r)
    passable = np.where(band, (warm & base) | open_(base, 4) | (dark > 0.5), open_(base, 2)) | inside
    mask = flood(inside, passable)
    near = dilate(mask, 2)
    alpha = np.where(inside, 1.0, np.where(mask, np.maximum(key, dark), key * near * ~band))
    alpha = np.clip(alpha, 0, 1)
    halo_info[id_] = (cx, cy, r)
    # убрать фиолетовый оттенок у полупрозрачных краёв
    gray = rgb.mean(axis=-1, keepdims=True)
    k = (1.0 - alpha)[..., None] * 0.8
    rgb2 = rgb * (1 - k) + gray * k
    ys, xs = np.nonzero(alpha > 0.03)
    m = 6
    y0, y1 = max(0, ys.min() - m), min(H, ys.max() + m + 1)
    x0, x1 = max(0, xs.min() - m), min(W, xs.max() + m + 1)
    out = np.concatenate([rgb2, alpha[..., None]], -1)[y0:y1, x0:x1]
    # премультипликация на время уменьшения, чтобы края не темнели
    if out.shape[0] > max_h:
        pm = out.copy(); pm[..., :3] *= pm[..., 3:4]
        pm = resize(pm, max_h)
        a = pm[..., 3:4]
        pm[..., :3] = np.where(a > 1e-4, pm[..., :3] / np.maximum(a, 1e-4), 0)
        out = pm
    save(out.astype(np.float32), os.path.join(out_dir, id_ + ".png"))
    print("CUT", id_, "src", W, H, "crop", x1 - x0, y1 - y0, "out", out.shape[1], out.shape[0])
    print("HALO", id_, "cx %.0f cy %.0f r %.0f" % (cx, cy, r))
    if prev:
        thumbs.append((id_, resize(out, 300)))
        # проверка круга: исходник с красной окружностью
        dbg = img.copy(); ring = np.abs(dist - r) < 2.5
        dbg[ring, 0] = 1; dbg[ring, 1] = 0; dbg[ring, 2] = 0
        circ.append((id_, resize(dbg[y0:y1, x0:x1], 300)))

if prev:
    # лист проверки: каждая фигура на тёмном и на сиреневом фоне
    os.makedirs(prev, exist_ok=True)
    cols = 6
    cw, ch = 260, 320
    rows = (len(thumbs) + cols - 1) // cols
    for name, bg, items in (("dark", (0.05, 0.05, 0.12), thumbs), ("lilac", (0.62, 0.52, 0.92), thumbs),
                            ("circles", (0, 0, 0), circ)):
        sheet = np.zeros((rows * ch, cols * cw, 4), np.float32); sheet[..., :3] = bg; sheet[..., 3] = 1
        for n, (id_, t) in enumerate(items):
            th, tw = t.shape[:2]
            if tw > cw - 10:
                t = resize(t, int(th * (cw - 10) / tw)); th, tw = t.shape[:2]
            r, c = divmod(n, cols)
            oy = r * ch + (ch - th) // 2; ox = c * cw + (cw - tw) // 2
            reg = sheet[oy:oy + th, ox:ox + tw]
            reg[..., :3] = reg[..., :3] * (1 - t[..., 3:4]) + t[..., :3] * t[..., 3:4]
        save(sheet, os.path.join(prev, "sheet_" + name + ".png"))
    print("PREVIEW", prev)
