# Более реалистичная кожа для модели с «нарисованной» ровной текстурой (HDRP-набор BaseMap/Normal/MaskMap).
# Запекает 3D-позицию каждого текселя выбранных объектов, строит маску кожи по цвету и (если задан объект глаз)
# зоны лица, затем добавляет в цвет неравномерность тона/румянец, а в normal map — поры. Шум считается
# в 3D, поэтому бесшовный через швы развёртки.
#
# Запуск:
#   blender.exe --background --factory-startup --python skin_texture.py -- \
#       --glb <модель.glb> --texdir <папка текстур> --prefix Datta_low_Material_3 \
#       --objects Golova_low [--eyes Glasa_low] --out <папка> [--preview <папка>] [опции]
# Результат: <out>/<prefix>_BaseMap_skin.png и <out>/<prefix>_Normal_skin.png
import bpy, bmesh, sys, os, time, argparse
import numpy as np
from mathutils import Vector

ap = argparse.ArgumentParser()
ap.add_argument("--glb", required=True)
ap.add_argument("--texdir", required=True)
ap.add_argument("--prefix", required=True, help="например Datta_low_Material_3")
ap.add_argument("--objects", required=True, help="объекты с кожей через запятую")
ap.add_argument("--eyes", default="", help="объект глаз: по нему находятся лица (щёки, нос, глазницы, губы)")
ap.add_argument("--out", required=True)
ap.add_argument("--preview", default="", help="папка для превью-кропов и масок")
ap.add_argument("--preview-center", default="", help="x,y,z (Blender, Z вверх) центр кропа; по умолчанию первое лицо или центр объектов")
ap.add_argument("--res", type=int, default=4096)
ap.add_argument("--pores", type=float, default=0.38, help="сила пор в normal map (лицо 0.38, тело 0.25)")
ap.add_argument("--sat-max", type=float, default=0.6, help="макс. насыщенность «кожи»; 0.4 исключит бежевую/оранжевую одежду")
ap.add_argument("--mottle", type=float, default=0.04, help="сила пятнистости тона")
ap.add_argument("--redness", type=float, default=1.0, help="множитель румянца носа/щёк/губ")
ap.add_argument("--saturation", type=float, default=0.93, help="насыщенность кожи после обработки")
args = ap.parse_args(sys.argv[sys.argv.index("--") + 1:])

RES = args.res
t0 = time.time()
def log(*a):
    print("LOG %6.1fs" % (time.time() - t0), *a, flush=True)

# ---------- импорт и запекание позиций ----------
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=args.glb)
skin_objs = [bpy.data.objects[n] for n in args.objects.split(",")]
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 1
scene.render.bake.margin = 16
pimg = bpy.data.images.new("pos", RES, RES, float_buffer=True)
mat = bpy.data.materials.new("bake_pos"); mat.use_nodes = True
nt = mat.node_tree; nt.nodes.clear()
geo = nt.nodes.new("ShaderNodeNewGeometry")
em = nt.nodes.new("ShaderNodeEmission")
outn = nt.nodes.new("ShaderNodeOutputMaterial")
tex = nt.nodes.new("ShaderNodeTexImage"); tex.image = pimg
nt.links.new(geo.outputs["Position"], em.inputs["Color"])
nt.links.new(em.outputs["Emission"], outn.inputs["Surface"])
nt.nodes.active = tex
bbox_pts = []
for o in skin_objs:
    bbox_pts += [o.matrix_world @ Vector(c) for c in o.bound_box]
    o.data.materials.clear(); o.data.materials.append(mat)
obj_center = sum(bbox_pts, Vector()) / len(bbox_pts)
bpy.ops.object.select_all(action='DESELECT')
for o in skin_objs:
    o.select_set(True)
bpy.context.view_layer.objects.active = skin_objs[0]
bpy.ops.object.bake(type='EMIT')
buf = np.empty(RES * RES * 4, np.float32); pimg.pixels.foreach_get(buf)
pos = buf.reshape(RES, RES, 4)[..., :3].copy(); del buf
cov = np.abs(pos).sum(axis=2) > 1e-4   # фон после запекания остаётся нулевым
log("baked positions, coverage", float(cov.mean()))

# ---------- текстуры ----------
def load(name, noncolor):
    im = bpy.data.images.load(os.path.join(args.texdir, name))
    if noncolor:
        im.colorspace_settings.name = 'Non-Color'
    a = np.empty(im.size[0] * im.size[1] * 4, np.float32); im.pixels.foreach_get(a)
    a = a.reshape(im.size[1], im.size[0], 4)
    if a.shape[0] != RES:
        raise SystemExit(f"texture {name} is {a.shape[:2]}, expected {RES}; pass --res")
    return a

base = load(args.prefix + "_BaseMap.1001.tga", False)
nrm = load(args.prefix + "_Normal.1001.tga", True)

# ---------- утилиты ----------
def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)

def box_blur(a, r):
    for axis in (0, 1):
        c = np.cumsum(np.pad(a, [(r + 1, r) if i == axis else (0, 0) for i in range(a.ndim)], mode='edge'), axis=axis, dtype=np.float64)
        n = a.shape[axis]
        a = ((np.take(c, np.arange(2 * r + 1, 2 * r + 1 + n), axis=axis) - np.take(c, np.arange(0, n), axis=axis)) / (2 * r + 1)).astype(np.float32)
    return a

def vnoise3(P, freq, seed):
    Q = P * freq
    I = np.floor(Q).astype(np.int64)
    F = (Q - I).astype(np.float32)
    F = F * F * (3.0 - 2.0 * F)
    def h(dx, dy, dz):
        n = (I[:, 0] + dx) * 73856093 ^ (I[:, 1] + dy) * 19349663 ^ (I[:, 2] + dz) * 83492791 ^ seed * 2654435761
        n = (n ^ (n >> 13)) * 1274126177
        n = n ^ (n >> 16)
        return (n & 0xFFFF).astype(np.float32) / 65535.0
    x0 = h(0, 0, 0) + (h(1, 0, 0) - h(0, 0, 0)) * F[:, 0]
    x1 = h(0, 1, 0) + (h(1, 1, 0) - h(0, 1, 0)) * F[:, 0]
    x2 = h(0, 0, 1) + (h(1, 0, 1) - h(0, 0, 1)) * F[:, 0]
    x3 = h(0, 1, 1) + (h(1, 1, 1) - h(0, 1, 1)) * F[:, 0]
    y0 = x0 + (x1 - x0) * F[:, 1]
    y1 = x2 + (x3 - x2) * F[:, 1]
    return y0 + (y1 - y0) * F[:, 2]

def field(fn):
    out = np.zeros((RES, RES), np.float32)
    idx = np.flatnonzero(cov)
    P = pos.reshape(-1, 3)
    flat = out.reshape(-1)
    for s in range(0, idx.size, 2_000_000):
        sel = idx[s:s + 2_000_000]
        flat[sel] = fn(P[sel])
    return out

def fbm(P, cell, seed, octaves):
    v = np.zeros(P.shape[0], np.float32); amp = 0.5; tot = 0.0; freq = 1.0 / cell
    for o in range(octaves):
        v += amp * vnoise3(P, freq, seed + o * 17); tot += amp
        amp *= 0.5; freq *= 2.0
    return v / tot * 2.0 - 1.0

# ---------- лица по глазам ----------
def find_faces(eyes_obj):
    # Связные куски меша глаз -> центры; пары ближайших -> лица
    bm = bmesh.new(); bm.from_mesh(eyes_obj.data); bm.verts.ensure_lookup_table()
    seen, centers, mw = set(), [], eyes_obj.matrix_world
    for v in bm.verts:
        if v.index in seen:
            continue
        stack, comp = [v], []
        while stack:
            x = stack.pop()
            if x.index in seen:
                continue
            seen.add(x.index); comp.append(x)
            stack += [e.other_vert(x) for e in x.link_edges]
        centers.append(sum((mw @ p.co for p in comp), Vector()) / len(comp))
    bm.free()
    faces, used = [], set()
    for i, a in enumerate(centers):
        if i in used:
            continue
        j = min((k for k in range(len(centers)) if k != i and k not in used), key=lambda k: (centers[k] - a).length, default=None)
        if j is None:
            continue
        used |= {i, j}
        b = centers[j]
        c = (a + b) / 2
        right = Vector((b.x - a.x, b.y - a.y, 0)).normalized()
        fwd = Vector((right.y, -right.x, 0))
        away = Vector((c.x - obj_center.x, c.y - obj_center.y, 0))
        if fwd.dot(away) < 0:
            fwd = -fwd
        faces.append((np.array(c, np.float32), np.array(right, np.float32), np.array(fwd, np.float32), (b - a).length))
        log("face center=(%.3f, %.3f, %.3f) eye_dist=%.3f fwd=(%.2f, %.2f)" % (c.x, c.y, c.z, (b - a).length, fwd.x, fwd.y))
    return faces

cheeks = np.zeros((RES, RES), np.float32); nose = np.zeros_like(cheeks)
sockets = np.zeros_like(cheeks); lips = np.zeros_like(cheeks)
faces = find_faces(bpy.data.objects[args.eyes]) if args.eyes else []

def g(lx, ly, cx, cy, rx, ry):
    return np.exp(-(((lx - cx) / rx) ** 2 + ((ly - cy) / ry) ** 2))

up = np.array([0.0, 0.0, 1.0], np.float32)
for c, r, f, D in faces:
    v = pos - c
    lx = np.abs(v @ r) / D
    ly = (v @ up) / D
    lz = (v @ f) / D
    front = smoothstep(-0.9, -0.35, lz) * cov
    cheeks += front * g(lx, ly, 0.62, -0.62, 0.32, 0.28)
    nose += front * g(lx, ly, 0.0, -0.5, 0.17, 0.33)
    sockets += front * g(lx, ly, 0.5, -0.06, 0.34, 0.24)
    lips += front * g(lx, ly, 0.0, -1.05, 0.42, 0.16)
for m in (cheeks, nose, sockets, lips):
    np.clip(m, 0.0, 1.0, out=m)

# ---------- маска кожи ----------
R, G, B = base[..., 0], base[..., 1], base[..., 2]
mx = np.maximum(np.maximum(R, G), B); mn = np.minimum(np.minimum(R, G), B)
sat = (mx - mn) / (mx + 1e-4)
skin = ((R > 0.55) & (R >= G) & (G >= B * 0.85) & (sat > 0.08) & (sat < args.sat_max) & cov).astype(np.float32)
skin = smoothstep(0.35, 0.9, box_blur(skin, 3))
log("skin mask coverage", float(skin.mean()))

# ---------- цвет ----------
mottle = field(lambda P: fbm(P, 0.02, 11, 3))
grain = field(lambda P: fbm(P, 0.004, 31, 2))
warm = field(lambda P: fbm(P, 0.035, 47, 2))
col = base[..., :3].copy()
col *= (1.0 + args.mottle * mottle + 0.018 * grain - 0.07 * sockets)[..., None]
red = args.redness * (0.07 * cheeks + 0.10 * nose + 0.05 * lips) + 0.015 * cov + 0.02 * warm
col[..., 1] *= 1.0 - red
col[..., 2] *= 1.0 - red * 0.9
col[..., 0] *= 1.0 - 0.025 * sockets
gray = (col @ np.array([0.299, 0.587, 0.114], np.float32))[..., None]
col = gray + (col - gray) * args.saturation
col = base[..., :3] + (col - base[..., :3]) * skin[..., None]
new_base = base.copy(); new_base[..., :3] = np.clip(col, 0.0, 1.0)
del col, gray, mottle, warm, grain
log("albedo done")

# ---------- поры ----------
pores = smoothstep(0.66, 0.93, field(lambda P: vnoise3(P, 1.0 / 0.0011, 101)))
fine = field(lambda P: fbm(P, 0.0024, 131, 2))
h = (-pores + 0.35 * fine) * skin * (1.0 - 0.75 * lips) * (1.0 + 0.8 * nose) * (1.0 - 0.6 * sockets)
del pores, fine
gy, gx = np.gradient(h)    # ось 0 — v (строки Blender идут снизу вверх), ось 1 — u
n = nrm[..., :3] * 2.0 - 1.0
n[..., 0] -= gx * args.pores
n[..., 1] -= gy * args.pores
n /= np.linalg.norm(n, axis=2, keepdims=True) + 1e-6
new_nrm = nrm.copy(); new_nrm[..., :3] = n * 0.5 + 0.5
del n, gx, gy, h
log("normal done")

# ---------- сохранение ----------
def save(arr, name, noncolor, path):
    hgt, wid = arr.shape[:2]
    im = bpy.data.images.new(name, wid, hgt, alpha=False)
    im.colorspace_settings.name = 'Non-Color' if noncolor else 'sRGB'
    a = arr.copy(); a[..., 3] = 1.0
    im.pixels.foreach_set(a.ravel())
    im.filepath_raw = path; im.file_format = 'PNG'
    im.save()

os.makedirs(args.out, exist_ok=True)
save(new_base, "skin_base", False, os.path.join(args.out, args.prefix + "_BaseMap_skin.png"))
save(new_nrm, "skin_nrm", True, os.path.join(args.out, args.prefix + "_Normal_skin.png"))
log("saved", args.out)

if args.preview:
    os.makedirs(args.preview, exist_ok=True)
    if args.preview_center:
        fc = np.array([float(x) for x in args.preview_center.split(",")], np.float32)
    elif faces:
        fc = faces[0][0]
    else:
        fc = np.array(obj_center, np.float32)
    d2 = np.where(cov, np.sum((pos - fc) ** 2, axis=2), 1e9)
    cy, cx = np.unravel_index(np.argmin(d2), d2.shape)
    S = RES // 6
    y0, x0 = max(0, cy - S), max(0, cx - S)
    def crop_save(arr, name):
        c = arr[y0:y0 + 2 * S, x0:x0 + 2 * S].copy()
        if c.ndim == 2:
            c = np.repeat(c[..., None], 4, axis=2)
        c[..., 3] = 1.0
        save(c, name, True, os.path.join(args.preview, name + ".png"))
    crop_save(base, "crop_before")
    crop_save(new_base, "crop_after")
    crop_save(new_nrm, "crop_normal_after")
    crop_save(np.clip(np.stack([cheeks + lips, nose, sockets, np.ones_like(nose)], axis=2), 0, 1), "crop_masks")
    crop_save(skin, "crop_skin")
    log("previews saved", args.preview)
log("SKIN_DONE")
