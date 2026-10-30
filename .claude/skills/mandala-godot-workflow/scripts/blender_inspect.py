# Список объектов модели (.glb) в Blender: вершины, материалы, размеры.
# Запуск: blender.exe --background --factory-startup --python blender_inspect.py -- <путь.glb>
import bpy, sys

glb = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
for o in sorted(bpy.data.objects, key=lambda o: o.name):
    if o.type != 'MESH':
        continue
    me = o.data
    dims = tuple(round(d, 3) for d in o.dimensions)
    mats = [m.name for m in me.materials if m]
    print(f"OBJ {o.name:16} verts={len(me.vertices):7} faces={len(me.polygons):7} uv={[uv.name for uv in me.uv_layers]} mats={mats} dims={dims}")
