"""Убирает золотой ореол за божеством на картинках мандалы 24 (images/mandala24/parts/<id>.png).
Фигура на карте глубины (Depth Anything V2) ближе плоского диска ореола — всё, что дальше, становится прозрачным.
Запуск:
  blender --background --factory-startup --python cut_halo.py -- <папка parts> <папка вывода> [--preview <папка>] [--off 0.10,0.17] [id ...]
Вывод: <id>.png с прозрачным фоном (обрезан по фигуре); в --preview — on_dark_<id>.png и sheet.png (все сразу).
Нужны onnxruntime в C:/Users/shumi/tools/blender_py и модель C:/Users/shumi/tools/depth/depth_anything_v2_small.onnx."""
import sys, os, bpy, numpy as np
from collections import deque
sys.path.append(r"C:\Users\shumi\tools\blender_py")
import onnxruntime as ort

argv = sys.argv[sys.argv.index("--") + 1:]
src_dir, out_dir = argv[0], argv[1]
prev_dir = None; off = (0.10, 0.17); ids = []
i = 2
while i < len(argv):
    if argv[i] == "--preview": prev_dir = argv[i + 1]; i += 2
    elif argv[i] == "--off": off = tuple(float(v) for v in argv[i + 1].split(",")); i += 2
    else: ids.append(argv[i]); i += 1
if not ids:
    ids = sorted(f[:-4] for f in os.listdir(src_dir) if f.endswith(".png"))
os.makedirs(out_dir, exist_ok=True)
if prev_dir: os.makedirs(prev_dir, exist_ok=True)

sess = ort.InferenceSession(r"C:\Users\shumi\tools\depth\depth_anything_v2_small.onnx")
inp = sess.get_inputs()[0].name
MEAN = np.array([0.485, 0.456, 0.406], np.float32); STD = np.array([0.229, 0.224, 0.225], np.float32)

def load(path):
    img = bpy.data.images.load(path)
    w, h = img.size
    px = np.empty(w * h * 4, np.float32); img.pixels.foreach_get(px)
    bpy.data.images.remove(img)
    return px.reshape(h, w, 4)[::-1].copy()

def save(path, arr):
    im = bpy.data.images.new("o", arr.shape[1], arr.shape[0], alpha=True)
    im.pixels.foreach_set(arr[::-1].astype(np.float32).ravel())
    im.filepath_raw = path; im.file_format = "PNG"; im.save()
    bpy.data.images.remove(im)

def depth(px):
    h, w = px.shape[:2]; S = 518
    rgb = px[(np.arange(S) * h / S).astype(int)][:, (np.arange(S) * w / S).astype(int), :3]
    x = ((rgb - MEAN) / STD).transpose(2, 0, 1)[None].astype(np.float32)
    d = sess.run(None, {inp: x})[0].squeeze()
    D = d[(np.arange(h) * S / h).astype(int)][:, (np.arange(w) * S / w).astype(int)]
    return (D - D.min()) / (D.max() - D.min())

def components(mask):
    h, w = mask.shape; lab = np.zeros((h, w), np.int32); comps = []
    for y0, x0 in zip(*np.nonzero(mask)):
        if lab[y0, x0]: continue
        n = len(comps) + 1; lab[y0, x0] = n; q = deque([(y0, x0)]); pts = []; edge = False
        while q:
            y, x = q.popleft(); pts.append((y, x))
            if y in (0, h - 1) or x in (0, w - 1): edge = True
            for yy, xx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                if 0 <= yy < h and 0 <= xx < w and mask[yy, xx] and not lab[yy, xx]:
                    lab[yy, xx] = n; q.append((yy, xx))
        comps.append((pts, edge))
    return comps

def cut(px):
    h, w = px.shape[:2]
    D = depth(px); a = px[..., 3] > 0.5
    # уровень ореола по строкам: нейросеть считает низ картинки ближе, поэтому ореол «приближается» сверху вниз.
    # Берём самые далёкие пиксели строки (5%) на высоте 15…60% (там по краям только ореол), ведём прямую
    # и ниже 65% держим её постоянной (там уже лотос, а не ореол)
    ys_fit, lv = [], []
    for y in range(int(h * 0.15), int(h * 0.6)):
        v = D[y][a[y]]
        if v.size > 20:
            ys_fit.append(y); lv.append(np.percentile(v, 5))
    k, c0 = np.polyfit(ys_fit, lv, 1)
    rows = np.minimum(np.arange(h), int(h * 0.65))
    level = (k * rows + c0)[:, None]
    halo = float(k * h * 0.4 + c0)
    t0, t1 = level + off[0], level + off[1]
    hard = (np.clip((D - t0) / (t1 - t0), 0, 1) > 0.5) & a
    comps = components(hard)
    keep = np.zeros((h, w), bool)
    if comps:
        for y, x in max(comps, key=lambda c: len(c[0]))[0]: keep[y, x] = True
    for pts, edge in components(~keep):  # мелкие дырки в фигуре закрыть, просветы у рук оставить
        if not edge and len(pts) < 400:
            for y, x in pts: keep[y, x] = True
    m = keep.astype(np.float32)
    s = m.copy()  # подрезать край на 1 px
    s[1:] = np.minimum(s[1:], m[:-1]); s[:-1] = np.minimum(s[:-1], m[1:])
    s[:, 1:] = np.minimum(s[:, 1:], m[:, :-1]); s[:, :-1] = np.minimum(s[:, :-1], m[:, 1:])
    b = s.copy()
    b[1:-1, 1:-1] = (s[1:-1, 1:-1] * 4 + s[:-2, 1:-1] + s[2:, 1:-1] + s[1:-1, :-2] + s[1:-1, 2:]) / 8
    al = np.minimum(b, px[..., 3])
    ys, xs = np.where(al > 0.05); pad = 12
    y0, y1 = max(ys.min() - pad, 0), min(ys.max() + pad + 1, h)
    x0, x1 = max(xs.min() - pad, 0), min(xs.max() + pad + 1, w)
    return np.dstack([px[y0:y1, x0:x1, :3], al[y0:y1, x0:x1]]), halo

tiles = []
for id in ids:
    px = load(os.path.join(src_dir, id + ".png"))
    out, halo = cut(px)
    save(os.path.join(out_dir, id + ".png"), out)
    print("CUT", id, "halo=%.2f" % halo, out.shape[1], "x", out.shape[0])
    if prev_dir:
        al = out[..., 3:]
        c = out[..., :3] * al + np.array([0.12, 0.1, 0.25]) * (1 - al)
        c = np.dstack([c, np.ones(al.shape[:2])])
        save(os.path.join(prev_dir, "on_dark_" + id + ".png"), c)
        T = 300  # плитка для общего листа
        H, W = c.shape[:2]; k = min(T / H, T / W)
        hh, ww = int(H * k), int(W * k)
        t = np.zeros((T, T, 4), np.float32); t[..., :3] = (0.12, 0.1, 0.25); t[..., 3] = 1
        r = c[(np.arange(hh) / k).astype(int)][:, (np.arange(ww) / k).astype(int)]
        t[(T - hh) // 2:(T - hh) // 2 + hh, (T - ww) // 2:(T - ww) // 2 + ww] = r
        t[:, :2] = 1; t[:2] = 1
        tiles.append(t)
if prev_dir and tiles:
    cols = 6; rows = (len(tiles) + cols - 1) // cols
    sheet = np.zeros((rows * 300, cols * 300, 4), np.float32); sheet[..., 3] = 1
    for n, t in enumerate(tiles):
        sheet[(n // cols) * 300:(n // cols + 1) * 300, (n % cols) * 300:(n % cols + 1) * 300] = t
    save(os.path.join(prev_dir, "sheet.png"), sheet)
    print("SHEET", " ".join(ids))
