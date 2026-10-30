# Вырезает фигуры из картинки по разметке layout.json в отдельные PNG с прозрачностью.
# circle — медальон: круг с мягким краем + подставка-лотос снизу, у которой убирается фон;
# key — рамка (или эллипс, "ellipse": true), в которой убирается фиолетовый фон.
# Запуск: blender.exe --background --factory-startup --python cut_figures.py -- <папка с layout.json> [--preview <папка>]
import bpy, sys, os, json
import numpy as np

argv = sys.argv[sys.argv.index("--") + 1:]
d = argv[0]
prev = argv[argv.index("--preview") + 1] if "--preview" in argv else ""
lay = json.load(open(os.path.join(d, "layout.json"), encoding="utf-8"))
im = bpy.data.images.load(os.path.join(d, lay["source"]))
W, H = im.size
src = np.empty(W * H * 4, np.float32); im.pixels.foreach_get(src)
src = src.reshape(H, W, 4)[::-1].copy()      # строки сверху вниз

def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)

def background_alpha(rgb):
    # «Фиолетовость» фона: оттенок 235–295°, заметная насыщенность. Возвращает непрозрачность (1 — оставить).
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx = rgb.max(axis=-1); mn = rgb.min(axis=-1)
    sat = (mx - mn) / (mx + 1e-5)
    hue = np.zeros_like(mx)
    dlt = mx - mn + 1e-5
    hue = np.where(mx == r, ((g - b) / dlt) % 6, hue)
    hue = np.where(mx == g, (b - r) / dlt + 2, hue)
    hue = np.where(mx == b, (r - g) / dlt + 4, hue)
    hue *= 60.0
    hue_w = smoothstep(220, 240, hue) * (1 - smoothstep(290, 310, hue))
    purple = hue_w * smoothstep(0.08, 0.2, sat)
    return 1.0 - purple

def despill(rgb, alpha):
    # убрать фиолетовый оттенок у полупрозрачных краёв
    gray = rgb.mean(axis=-1, keepdims=True)
    k = (1.0 - alpha)[..., None] * 0.8
    return rgb * (1 - k) + gray * k

out_dir = os.path.join(d, "parts")
os.makedirs(out_dir, exist_ok=True)
parts = []
for it in lay["items"]:
    cx, cy = it["cx"], it["cy"]
    if it["mode"] == "circle":
        r = it["r"]
        x0, x1 = int(cx - r - 6), int(cx + r + 6)
        y0, y1 = int(cy - r - 6), int(cy + r * 1.6)
    else:
        x0, x1 = int(cx - it["w"] / 2), int(cx + it["w"] / 2)
        y0, y1 = int(cy - it["h"] / 2), int(cy + it["h"] / 2)
    x0, y0 = max(0, x0), max(0, y0)
    x1, y1 = min(W, x1), min(H, y1)
    crop = src[y0:y1, x0:x1].copy()
    yy, xx = np.mgrid[y0:y1, x0:x1].astype(np.float32)
    key = background_alpha(crop[..., :3])
    if it["mode"] == "circle":
        dist = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
        a_circle = 1 - smoothstep(r - 1.5, r + 1.5, dist)
        # подставка-лотос: эллипс под кругом, фон вырезается по цвету ("base": false — без подставки)
        if it.get("base", True):
            e = ((xx - cx) / (r * 0.95)) ** 2 + ((yy - (cy + 0.95 * r)) / (r * 0.55)) ** 2
            lower = (1 - smoothstep(0.7, 1.0, e)) * smoothstep(cy + 0.3 * r, cy + 0.6 * r, yy)
            alpha = np.maximum(a_circle, key * lower)
        else:
            alpha = a_circle
    else:
        edge = np.minimum.reduce([xx - x0, x1 - 1 - xx, yy - y0, y1 - 1 - yy])
        alpha = key * smoothstep(0, 18, edge)
        if it.get("ellipse"):
            e = ((xx - cx) / (it["w"] / 2)) ** 2 + ((yy - cy) / (it["h"] / 2)) ** 2
            alpha *= 1 - smoothstep(0.75, 1.0, e)
    crop[..., :3] = despill(crop[..., :3], alpha)
    crop[..., 3] = alpha
    h, w = crop.shape[:2]
    o = bpy.data.images.new(it["id"], w, h, alpha=True)
    o.pixels.foreach_set(crop[::-1].ravel())
    o.filepath_raw = os.path.join(out_dir, it["id"] + ".png"); o.file_format = 'PNG'; o.save()
    parts.append({"id": it["id"], "row": it["row"], "cx": (x0 + x1) / 2, "cy": (y0 + y1) / 2, "w": w, "h": h})

json.dump({"image_size": [W, H], "parts": parts}, open(os.path.join(d, "parts.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("PARTS", len(parts))

if prev:
    # сборка всех частей на тёмном фоне — проверить вырезание
    comp = np.zeros((H, W, 4), np.float32); comp[..., 2] = 0.08; comp[..., 3] = 1
    for p in parts:
        pim = bpy.data.images[p["id"]]
        a = np.empty(p["w"] * p["h"] * 4, np.float32); pim.pixels.foreach_get(a)
        a = a.reshape(p["h"], p["w"], 4)[::-1]
        x0 = int(p["cx"] - p["w"] / 2); y0 = int(p["cy"] - p["h"] / 2)
        reg = comp[y0:y0 + p["h"], x0:x0 + p["w"]]
        reg[..., :3] = reg[..., :3] * (1 - a[..., 3:4]) + a[..., :3] * a[..., 3:4]
    o = bpy.data.images.new("comp", W, H)
    o.pixels.foreach_set(comp[::-1].ravel())
    os.makedirs(prev, exist_ok=True)
    o.filepath_raw = os.path.join(prev, "parts_composite.png"); o.file_format = 'PNG'; o.save()
    print("PREVIEW saved")
