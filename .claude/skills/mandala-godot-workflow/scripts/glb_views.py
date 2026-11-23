"""Снимки модели .glb в Blender (Eevee), чтобы посмотреть её со всех сторон или крупно.
  blender --background --factory-startup --python glb_views.py -- model.glb out_prefix [вид ...]
Без видов — 4 стороны (спереди, справа, сзади, слева) в <out_prefix>_views.png.
Вид: "имя:угол°:наклон°:x,y,z:размер" — ортокамера смотрит на точку x,y,z (координаты Blender: Z вверх,
лицо модели в −Y) с поворотом угол° вокруг вертикали (0 — спереди, 180 — сзади), кадр шириной «размер» м.
Каждый вид — отдельный <out_prefix>_<имя>.png 768×768."""
import sys, math, bpy, numpy as np
from mathutils import Vector
argv = sys.argv[sys.argv.index("--") + 1:]
src, out, views = argv[0], argv[1], argv[2:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
ctr = (lo + hi) / 2; size = max(hi - lo)
print("BOUNDS", tuple(round(v, 3) for v in lo), tuple(round(v, 3) for v in hi))
sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE"
w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.12, 0.1, 0.25, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 0.6
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam)
cam.data.type = "ORTHO"; sc.camera = cam
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); sc.collection.objects.link(sun)
sun.data.energy = 3.0

def shot(path, ang, elev, target, width, res):
    sc.render.resolution_x = sc.render.resolution_y = res
    a, e = math.radians(ang), math.radians(elev)
    d = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e))).normalized()
    cam.data.ortho_scale = width
    cam.location = target + d * size * 3
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    sun.rotation_euler = (-(d + Vector((0.4, 0, 0.6)))).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)

if views:
    for v in views:
        name, ang, elev, xyz, width = v.split(":")
        shot(out + "_" + name + ".png", float(ang), float(elev), Vector([float(c) for c in xyz.split(",")]), float(width), 768)
        print("VIEW", out + "_" + name + ".png")
else:
    tiles = []
    for i, ang in enumerate([0, 90, 180, 270]):
        p = out + "_%d.png" % i
        shot(p, ang, 8, ctr, size * 1.1, 512)
        im = bpy.data.images.load(p)
        tiles.append(np.array(im.pixels[:], np.float32).reshape(512, 512, 4))
    sheet = np.concatenate(tiles, axis=1)
    im = bpy.data.images.new("s", 2048, 512, alpha=True)
    im.pixels.foreach_set(sheet.ravel()); im.filepath_raw = out + "_views.png"; im.file_format = "PNG"; im.save()
    print("VIEWS", out + "_views.png")
