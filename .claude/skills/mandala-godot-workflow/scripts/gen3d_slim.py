"""Готовит модель из нейросети «картинка → 3D» (TRELLIS.2 и т. п.) для сцены «24 божества 3Д».
  blender --background --factory-startup --python gen3d_slim.py -- in.glb out.glb [--faces 200000] [--tex 4096] [--no-polish]
1. Склеивает вершины, убирает мелкие висящие куски (<0.5% вершин), упрощает сетку до --faces треугольников.
2. Доводка текстур (если не --no-polish):
   - золото: там, где нейросеть сама поставила металл (синий канал ORM), металл усилен, шероховатость снижена
     с ~0.95 до ~0.35, цвет металла чуть светлее — золото блестит, а не выглядит глиной;
   - цвет: лёгкая резкость (unsharp mask);
   - пустоты атласа (серые промежутки между кусочками развёртки) залиты цветом соседних кусочков,
     иначе на расстоянии mipmap подмешивает серое и по швам идут светлые линии.
3. Уменьшает текстуры до --tex и сохраняет .glb (JPEG внутри)."""
import sys, bpy, bmesh, numpy as np

argv = sys.argv[sys.argv.index("--") + 1:]
src, dst = argv[0], argv[1]
faces, tex, polish = 200000, 4096, "--no-polish" not in argv
for i, a in enumerate(argv):
    if a == "--faces": faces = int(argv[i + 1])
    if a == "--tex": tex = int(argv[i + 1])

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
# в файле бывают лишние объекты из чужой сцены (куб, лампа, камера) — оставить только самую большую сетку
meshes = sorted([o for o in bpy.context.scene.objects if o.type == "MESH"], key=lambda o: len(o.data.polygons))
for o in [o for o in bpy.context.scene.objects if o.type != "MESH"] + meshes[:-1]:
    print("DROP", o.type, o.name)
    bpy.data.objects.remove(o)
obj = None
for o in [o for o in bpy.context.scene.objects if o.type == "MESH"]:
    obj = o
    bm = bmesh.new(); bm.from_mesh(o.data)
    # glTF режет вершины по швам UV — сначала склеить совпадающие (UV остаются на углах граней)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.verts.ensure_lookup_table(); bm.verts.index_update()
    seen = set(); islands = []
    for v in bm.verts:
        if v.index in seen: continue
        stack = [v]; isl = []; seen.add(v.index)
        while stack:
            u = stack.pop(); isl.append(u)
            for e in u.link_edges:
                w = e.other_vert(u)
                if w.index not in seen: seen.add(w.index); stack.append(w)
        islands.append(isl)
    small = [v for isl in islands if len(isl) < len(bm.verts) * 0.005 for v in isl]
    bmesh.ops.delete(bm, geom=small, context="VERTS")
    bm.to_mesh(o.data); bm.free()
    n = len(o.data.polygons)
    print("ISLANDS", o.name, len(islands), "removed verts", len(small), "faces", n)
    if n > faces:
        bpy.context.view_layer.objects.active = o
        m = o.modifiers.new("dec", "DECIMATE"); m.ratio = faces / n
        bpy.ops.object.modifier_apply(modifier="dec")
    print("FACES", o.name, len(o.data.polygons))

def get(im):
    w, h = im.size; a = np.empty(w * h * 4, np.float32); im.pixels.foreach_get(a)
    return a.reshape(h, w, 4)

def put(im, a):
    im.pixels.foreach_set(a.astype(np.float32).ravel()); im.update()

def blur(a, r):  # прямоугольное размытие (2r+1) по двум осям через накопленные суммы
    for ax in (0, 1):
        c = np.cumsum(np.pad(a, [(r + 1, r) if i == ax else (0, 0) for i in range(a.ndim)], mode="edge"), axis=ax)
        a = (np.take(c, range(2 * r + 1, c.shape[ax]), axis=ax) - np.take(c, range(0, c.shape[ax] - 2 * r - 1), axis=ax)) / (2 * r + 1)
    return a

def coverage(me, w, h):
    """Какие пиксели атласа заняты развёрткой: треугольники UV, растеризованные точками."""
    me.calc_loop_triangles()
    uv = np.empty(len(me.loops) * 2, np.float32); me.uv_layers.active.data.foreach_get("uv", uv); uv = uv.reshape(-1, 2)
    tri = np.empty(len(me.loop_triangles) * 3, np.int32); me.loop_triangles.foreach_get("loops", tri); tri = tri.reshape(-1, 3)
    A, B, C = uv[tri[:, 0]], uv[tri[:, 1]], uv[tri[:, 2]]
    ext = np.maximum(np.abs(B - A).max(1), np.maximum(np.abs(C - A).max(1), np.abs(C - B).max(1))) * max(w, h)
    mask = np.zeros((h, w), bool)
    for lo, hi in ((0, 4), (4, 16), (16, 64), (64, 1e9)):  # мелким треугольникам — мало точек, крупным — много
        sel = (ext >= lo) & (ext < hi)
        if not sel.any(): continue
        k = int(min(hi, 256)) + 2
        s = np.linspace(0, 1, k)
        u, v = np.meshgrid(s, s); keep = u + v <= 1; u, v = u[keep], v[keep]
        a, b, c = A[sel], B[sel], C[sel]
        for i in range(0, len(a), max(1, 2000000 // len(u))):
            sl = slice(i, i + max(1, 2000000 // len(u)))
            p = a[sl, None] + (b[sl, None] - a[sl, None]) * u[None, :, None] + (c[sl, None] - a[sl, None]) * v[None, :, None]
            x = np.clip((p[..., 0] * w).astype(int), 0, w - 1); y = np.clip((p[..., 1] * h).astype(int), 0, h - 1)
            mask[y.ravel(), x.ravel()] = True
    # чуть расширить (сэмплирование по краям)
    m = mask.copy()
    m[1:] |= mask[:-1]; m[:-1] |= mask[1:]; m[:, 1:] |= mask[:, :-1]; m[:, :-1] |= mask[:, 1:]
    return m

def dilate(a, mask, steps=48):
    """Заливает пустые пиксели средним цветом занятых соседей, шаг за шагом наружу."""
    a = a.copy(); a[~mask] = 0; filled = mask.astype(np.float32)
    for _ in range(steps):
        if filled.min() > 0: break
        acc = np.zeros_like(a); cnt = np.zeros_like(filled)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            acc += np.roll(a * filled[..., None], (dy, dx), (0, 1)); cnt += np.roll(filled, (dy, dx), (0, 1))
        new = (filled == 0) & (cnt > 0)
        a[new] = acc[new] / cnt[new][:, None]; filled[new] = 1
    if filled.min() == 0:
        a[filled == 0] = a[filled > 0].mean(0)
    return a

if polish and obj is not None:
    mat = obj.data.materials[0]
    col_im = orm_im = None
    for n in mat.node_tree.nodes:
        if n.type == "TEX_IMAGE":
            to = [l.to_node for l in n.outputs["Color"].links]
            if any(t.type == "BSDF_PRINCIPLED" for t in to): col_im = n.image
            else: orm_im = n.image
    col, orm = get(col_im), get(orm_im)
    h, w = col.shape[:2]
    mask = coverage(obj.data, w, h)
    print("COVER", round(float(mask.mean()), 3))
    met = np.clip((orm[..., 2] - 0.15) / 0.35, 0, 1)  # где нейросеть видит металл
    met = met * met * (3 - 2 * met)
    rgb = col[..., :3]
    # резкость цвета (по занятым пикселям)
    rgb = np.clip(rgb + 0.6 * (rgb - blur(dilate(rgb, mask, 8), 2)), 0, 1)
    # металл: светлее и ярче, как полированное золото
    lum = rgb.mean(-1, keepdims=True)
    gold = np.clip(lum + (rgb - lum) * 1.25, 0, 1) * 1.35
    rgb = rgb * (1 - met[..., None]) + np.clip(gold, 0, 1) * met[..., None]
    col[..., :3] = dilate(rgb, mask)
    rough = orm[..., 1]
    rough = rough * (1 - met) + np.minimum(rough, 0.32 + 0.15 * (1 - orm[..., 2])) * met  # золото гладкое
    rough = np.minimum(rough, 0.85)  # остальное не «мел»
    orm[..., 1] = rough
    orm[..., 2] = np.maximum(orm[..., 2], met * 0.95)
    orm[..., :3] = dilate(orm[..., :3], mask)
    put(col_im, col); put(orm_im, orm)
    print("POLISH metal share", round(float((met > 0.5)[mask].mean()), 3))

for im in bpy.data.images:
    if im.size[0] > tex:
        im.scale(tex, tex)
        print("TEX", im.name, im.size[:])
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_image_format="JPEG", export_jpeg_quality=92)
print("OUT", dst)
