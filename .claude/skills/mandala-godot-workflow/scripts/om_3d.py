# Объёмный знак из плоской картинки: контур по альфе -> кривая с заливкой, толщиной и скруглением -> .glb.
#   blender --background --factory-startup --python om_3d.py -- in.png out.glb [толщина] [скругление]
# В Godot знак стоит лицом в +Z, ширина 1 м, центр в начале координат. Толщина и скругление — в долях ширины.
import bpy, sys, math
import numpy as np

args = sys.argv[sys.argv.index('--') + 1:]
src, out = args[0], args[1]
depth = float(args[2]) if len(args) > 2 else 0.05
round_off = float(args[3]) if len(args) > 3 else 0.018

bpy.ops.wm.read_factory_settings(use_empty=True)   # без кубика стартовой сцены

im = bpy.data.images.load(src)
w, h = im.size
pix = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)
mask = pix[:, :, 3] > 0.5        # строки снизу вверх — как ось Y

# границы пикселей: у каждой ребро идёт так, что заполненное слева; рёбра сцепляются в замкнутые контуры
padded = np.pad(mask, 1)
edges = {}
ys, xs = np.nonzero(padded[1:-1, 1:-1])
for y, x in zip(ys.tolist(), xs.tolist()):
    if not padded[y, x + 1]:
        edges.setdefault((x + 1, y), []).append((x, y))          # низ... сосед снизу пуст
    if not padded[y + 2, x + 1]:
        edges.setdefault((x, y + 1), []).append((x + 1, y + 1))  # сосед сверху пуст
    if not padded[y + 1, x]:
        edges.setdefault((x, y), []).append((x, y + 1))          # сосед слева пуст
    if not padded[y + 1, x + 2]:
        edges.setdefault((x + 1, y + 1), []).append((x + 1, y))  # сосед справа пуст

loops = []
while edges:
    start = next(iter(edges))
    loop = [start]
    cur = start
    while True:
        nxt = edges[cur].pop()
        if not edges[cur]:
            del edges[cur]
        if nxt == start:
            break
        loop.append(nxt)
        cur = nxt
        if cur not in edges:
            break
    loops.append(np.array(loop, dtype=np.float64))


def smooth(loop, radius):
    k = np.exp(-0.5 * (np.arange(-3 * radius, 3 * radius + 1) / radius) ** 2)
    k /= k.sum()
    n = len(loop)
    wrap = np.concatenate([loop[-3 * radius:], loop, loop[:3 * radius]])
    return np.stack([np.convolve(wrap[:, i], k, mode='valid')[:n] for i in range(2)], axis=1)


def resample(loop, step):
    closed = np.vstack([loop, loop[:1]])
    d = np.r_[0.0, np.cumsum(np.linalg.norm(np.diff(closed, axis=0), axis=1))]
    t = np.arange(0.0, d[-1], step)
    return np.stack([np.interp(t, d, closed[:, i]) for i in range(2)], axis=1)


# скругление контура сглаживает и настоящие углы букв — радиус небольшой, углы остаются углами
loops = [resample(smooth(l, 4), 5.0) for l in loops if len(l) > 40]
pts = np.vstack(loops)
lo, hi = pts.min(axis=0), pts.max(axis=0)
center = (lo + hi) / 2.0
scale = 1.0 / (hi - lo).max()
print('OM3D loops', [len(l) for l in loops], 'size', (hi - lo) * scale)

curve = bpy.data.curves.new('om', 'CURVE')
curve.dimensions = '2D'
curve.fill_mode = 'BOTH'
curve.extrude = depth / 2.0
curve.bevel_depth = round_off
curve.bevel_resolution = 3
curve.offset = -round_off        # скругление внутрь контура: толщина линий как на картинке
for l in loops:
    p = (l - center) * scale
    s = curve.splines.new('POLY')
    s.points.add(len(p) - 1)
    for i, (x, y) in enumerate(p):
        s.points[i].co = (x, y, 0.0, 1.0)
    s.use_cyclic_u = True

obj = bpy.data.objects.new('OmGold', curve)
bpy.context.collection.objects.link(obj)
bpy.context.view_layer.objects.active = obj
obj.select_set(True)
bpy.ops.object.convert(target='MESH')
obj = bpy.context.view_layer.objects.active
obj.rotation_euler = (math.pi / 2.0, 0.0, 0.0)     # лицо в -Y Blender = +Z в Godot
bpy.ops.object.transform_apply(rotation=True)
bpy.ops.object.shade_smooth_by_angle(angle=math.radians(45.0)) if hasattr(bpy.ops.object, 'shade_smooth_by_angle') else bpy.ops.object.shade_smooth()
print('OM3D faces', len(obj.data.polygons), 'verts', len(obj.data.vertices))
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', use_selection=True, export_apply=True, export_materials='NONE')
