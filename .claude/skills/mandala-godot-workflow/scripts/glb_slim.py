# Облегчает .glb точечно: упрощает названные меши и уменьшает крупные текстуры, всё остальное в файле остаётся байт в байт.
# (Обычный экспорт из Blender пересобрал бы все меши — а body_strip.gd опирается на точные вершины тела.)
#   blender --background --factory-startup --python glb_slim.py -- in.glb out.glb [--decimate "имя меша=доля,…"] [--max-image 2048]
# Имена — как в JSON файла (lepestok.001); нормали переносятся с исходного меша, поэтому затенение не меняется.
import bpy, sys, json, struct, os, tempfile

args = sys.argv[sys.argv.index('--') + 1:]
src_path, out_path = args[0], args[1]
ratios = {}
max_image = 0
i = 2
while i < len(args):
    if args[i] == '--decimate':
        for pair in args[i + 1].split(','):
            name, r = pair.rsplit('=', 1)
            ratios[name] = float(r)
    elif args[i] == '--max-image':
        max_image = int(args[i + 1])
    i += 2

data = open(src_path, 'rb').read()
json_len = struct.unpack('<I', data[12:16])[0]
gltf = json.loads(data[20:20 + json_len])
bin_start = 20 + json_len + 8
binary = data[bin_start:]
views = gltf['bufferViews']
accessors = gltf['accessors']
blobs = {}   # индекс bufferView -> новые байты


def view_bytes(v):
    if v in blobs:
        return blobs[v]
    bv = views[v]
    o = bv.get('byteOffset', 0)
    return binary[o:o + bv['byteLength']]


def add_view(payload, target=None):
    views.append({'buffer': 0, 'byteOffset': 0, 'byteLength': len(payload)})
    if target:
        views[-1]['target'] = target
    blobs[len(views) - 1] = payload
    return len(views) - 1


def add_accessor(payload, ctype, kind, count, target, lo=None, hi=None):
    a = {'bufferView': add_view(payload, target), 'componentType': ctype, 'count': count, 'type': kind}
    if lo:
        a['min'], a['max'] = lo, hi
    accessors.append(a)
    return len(accessors) - 1


def decimate(obj, ratio):
    bpy.ops.object.select_all(action='DESELECT')
    source = obj.copy()
    source.data = obj.data.copy()
    bpy.context.collection.objects.link(source)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    m = obj.modifiers.new('decimate', 'DECIMATE')
    m.ratio = ratio
    bpy.ops.object.modifier_apply(modifier=m.name)
    t = obj.modifiers.new('normals', 'DATA_TRANSFER')
    t.object = source
    t.use_loop_data = True
    t.data_types_loops = {'CUSTOM_NORMAL'}
    t.loop_mapping = 'POLYINTERP_NEAREST'
    bpy.ops.object.modifier_apply(modifier=t.name)
    bpy.data.objects.remove(source)


def patch_mesh(prim, mesh):
    mesh.calc_loop_triangles()
    uv = mesh.uv_layers.active.uv
    normals = mesh.corner_normals
    index_of, pos, nor, tex, idx = {}, [], [], [], []
    for tri in mesh.loop_triangles:
        for loop in tri.loops:
            v = mesh.loops[loop].vertex_index
            n = normals[loop].vector
            t = uv[loop].vector
            key = (v, round(n.x, 3), round(n.y, 3), round(n.z, 3), round(t.x, 5), round(t.y, 5))
            k = index_of.get(key)
            if k is None:
                k = index_of[key] = len(pos)
                c = mesh.vertices[v].co
                pos.append((c.x, c.z, -c.y))        # Blender Z-вверх -> glTF Y-вверх
                nor.append((n.x, n.z, -n.y))
                tex.append((t.x, 1.0 - t.y))
            idx.append(k)
    if len(pos) > 65535:
        raise SystemExit('слишком много вершин для 16-битных индексов')
    flat = lambda rows: [x for r in rows for x in r]
    lo = [min(p[i] for p in pos) for i in range(3)]
    hi = [max(p[i] for p in pos) for i in range(3)]
    attrs = prim['attributes']
    attrs['POSITION'] = add_accessor(struct.pack('<%df' % (len(pos) * 3), *flat(pos)), 5126, 'VEC3', len(pos), 34962, lo, hi)
    attrs['NORMAL'] = add_accessor(struct.pack('<%df' % (len(nor) * 3), *flat(nor)), 5126, 'VEC3', len(nor), 34962)
    attrs['TEXCOORD_0'] = add_accessor(struct.pack('<%df' % (len(tex) * 2), *flat(tex)), 5126, 'VEC2', len(tex), 34962)
    payload = struct.pack('<%dH' % len(idx), *idx)
    prim['indices'] = add_accessor(payload, 5123, 'SCALAR', len(idx), 34963)
    return len(idx) // 3


if ratios:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src_path, merge_vertices=True)
    by_mesh = {o.data.name: o for o in bpy.data.objects if o.type == 'MESH'}
    for m in gltf['meshes']:
        if m['name'] not in ratios:
            continue
        obj = next((o for n, o in by_mesh.items() if n == m['name'] or n.startswith(m['name'])), None)
        if obj is None:
            raise SystemExit('нет меша ' + m['name'])
        prim = m['primitives'][0]
        before = accessors[prim['indices']]['count'] // 3
        decimate(obj, ratios[m['name']])
        print('SLIM %s %d -> %d' % (m['name'], before, patch_mesh(prim, obj.data)))

if max_image:
    tmp = tempfile.mkdtemp()
    for n, image in enumerate(gltf.get('images', [])):
        f = os.path.join(tmp, '%d.png' % n)
        open(f, 'wb').write(view_bytes(image['bufferView']))
        im = bpy.data.images.load(f)
        im.colorspace_settings.name = 'Non-Color'   # значения не пересчитывать
        w, h = im.size
        if max(w, h) > max_image:
            k = max_image / max(w, h)
            im.scale(int(w * k), int(h * k))
            small = os.path.join(tmp, 's%d.png' % n)
            im.filepath_raw = small
            im.file_format = 'PNG'
            im.save()
            payload = open(small, 'rb').read()
            print('SLIM image %s %dx%d %d KB -> %d KB' % (image.get('name'), w, h, len(view_bytes(image['bufferView'])) // 1024, len(payload) // 1024))
            image['bufferView'] = add_view(payload)
        bpy.data.images.remove(im)

# только то, на что есть ссылки: старые данные упрощённых мешей и картинок из файла уходят
used = []
for m in gltf['meshes']:
    for p in m['primitives']:
        used += list(p['attributes'].values())
        if 'indices' in p:
            used.append(p['indices'])
remap = {old: new for new, old in enumerate(sorted(set(used)))}
for m in gltf['meshes']:
    for p in m['primitives']:
        p['attributes'] = {k: remap[v] for k, v in p['attributes'].items()}
        if 'indices' in p:
            p['indices'] = remap[p['indices']]
gltf['accessors'] = [accessors[o] for o in sorted(remap)]

used_views = sorted({a['bufferView'] for a in gltf['accessors']} | {im['bufferView'] for im in gltf.get('images', []) if 'bufferView' in im})
vmap = {}
out_bin = bytearray()
new_views = []
for v in used_views:
    payload = view_bytes(v)
    while len(out_bin) % 4:
        out_bin.append(0)
    bv = dict(views[v])
    bv['byteOffset'] = len(out_bin)
    bv['byteLength'] = len(payload)
    vmap[v] = len(new_views)
    new_views.append(bv)
    out_bin += payload
while len(out_bin) % 4:
    out_bin.append(0)
for a in gltf['accessors']:
    a['bufferView'] = vmap[a['bufferView']]
for im in gltf.get('images', []):
    im['bufferView'] = vmap[im['bufferView']]
gltf['bufferViews'] = new_views
gltf['buffers'][0]['byteLength'] = len(out_bin)

text = json.dumps(gltf, ensure_ascii=False, separators=(',', ':')).encode('utf-8')
text += b' ' * (-len(text) % 4)
with open(out_path, 'wb') as f:
    f.write(struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(text) + 8 + len(out_bin)))
    f.write(struct.pack('<II', len(text), 0x4E4F534A) + text)
    f.write(struct.pack('<II', len(out_bin), 0x004E4942) + out_bin)
print('SLIM written %s %.1f MB' % (out_path, os.path.getsize(out_path) / 1048576))
