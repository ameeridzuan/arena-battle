"""Convert a supplied PMX skin onto a base character rig (Python + numpy/Pillow).

Preserves canonical bone axes, weapon and motion, fitting translations to Astra's anatomy.
Hair/clothing chains retain their PMX weights for Godot spring-bone simulation.
MMD rigid-body constraints, facial morphs and accessory props are not exported.
"""
from pathlib import Path
import io
import json
import struct
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'Skins/AstraYao'


class PMX:
    def read(self, fmt):
        result = struct.unpack('<' + fmt, self.f.read(struct.calcsize('<' + fmt)))
        return result[0] if len(result) == 1 else result

    def text(self):
        return self.f.read(self.read('i')).decode(self.encoding)

    def index(self, size, unsigned=False):
        return self.read(({1: 'B', 2: 'H', 4: 'I'} if unsigned else {1: 'b', 2: 'h', 4: 'i'})[size])

    def __init__(self, path):
        self.f = path.open('rb')
        assert self.f.read(4) == b'PMX '
        self.version = self.read('f')
        header = self.read('B')
        flags = list(self.f.read(header))
        enc, uv, vi, ti, mi, bi, moi, ri = flags[:8]
        self.encoding = 'utf-16-le' if enc == 0 else 'utf-8'
        self.metadata = [self.text() for _ in range(4)]
        self.vertices = []
        for _ in range(self.read('i')):
            position, normal, texcoord = self.read('3f'), self.read('3f'), self.read('2f')
            self.f.read(16 * uv)
            kind = self.read('B')
            count = {0: 1, 1: 2, 2: 4, 3: 2, 4: 4}[kind]
            bones = [self.index(bi) for _ in range(count)]
            if kind == 0:
                weights = [1.0]
            elif kind in (1, 3):
                weight = self.read('f')
                weights = [weight, 1.0 - weight]
                if kind == 3:
                    self.f.read(36)
            else:
                weights = self.read('4f')
            self.read('f')
            self.vertices.append((position, normal, texcoord, bones, weights))
        self.indices = [self.index(vi, True) for _ in range(self.read('i'))]
        self.textures = [self.text() for _ in range(self.read('i'))]
        self.materials = []
        for _ in range(self.read('i')):
            name, english = self.text(), self.text()
            diffuse = self.read('4f')
            self.read('3f'); self.read('f'); self.read('3f')
            flags = self.read('B')
            self.read('4f'); self.read('f')
            texture = self.index(ti)
            self.index(ti); self.read('B')
            shared = self.read('B')
            self.read('B') if shared else self.index(ti)
            self.text()
            self.materials.append(dict(name=name, diffuse=diffuse, texture=texture,
                                       flags=flags, count=self.read('i')))
        self.bones = []
        for _ in range(self.read('i')):
            name, english = self.text(), self.text()
            position, parent = self.read('3f'), self.index(bi)
            self.read('i')
            flags = self.read('H')
            self.index(bi) if flags & 1 else self.read('3f')
            if flags & 0x300:
                self.index(bi); self.read('f')
            if flags & 0x400:
                self.read('3f')
            if flags & 0x800:
                self.read('3f'); self.read('3f')
            if flags & 0x2000:
                self.read('i')
            if flags & 0x20:
                self.index(bi); self.read('i'); self.read('f')
                for _ in range(self.read('i')):
                    self.index(bi)
                    if self.read('B'):
                        self.read('3f'); self.read('3f')
            self.bones.append(dict(name=name, english=english, position=position, parent=parent))
        self.f.close()


def node_matrix(node):
    if 'matrix' in node:
        return np.array(node['matrix']).reshape(4, 4).T
    x, y, z, w = node.get('rotation', [0, 0, 0, 1])
    rotation = np.array([[1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)],
                         [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)],
                         [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)]])
    result = np.eye(4)
    result[:3, :3] = rotation @ np.diag(node.get('scale', [1, 1, 1]))
    result[:3, 3] = node.get('translation', [0, 0, 0])
    return result


def build(*, source=SOURCE, pmx_name='耀嘉音.pmx', base_model='arclight', skin_name='Astra Yao',
          node_prefix='Astra', body_name='AstraYaoBody', output_name='astra_yao',
          rig_name='ArclightRig', weapon_prefix='Sword', skipped_materials=('髮+',)):
    model = PMX(source / pmx_name)
    with (ROOT / f'assets/models/{base_model}.glb').open('rb') as f:
        f.read(12)
        size, _ = struct.unpack('<II', f.read(8))
        gltf = json.loads(f.read(size))
        size, _ = struct.unpack('<II', f.read(8))
        binary = bytearray(f.read(size))
    nodes = gltf['nodes']
    parent = {child: i for i, n in enumerate(nodes) for child in n.get('children', [])}

    def world(index):
        local = node_matrix(nodes[index])
        return world(parent[index]) @ local if index in parent else local

    joints = gltf['skins'][0]['joints']
    target = {nodes[i]['name']: world(i)[:3, 3] for i in joints}
    joint_ids = {nodes[i]['name']: slot for slot, i in enumerate(joints)}
    source_positions = {b['name']: np.array(b['position']) * [1, 1, -1] for b in model.bones}
    mapping = {'全ての親': 'root', 'センター': 'hips', 'グルーブ': 'hips', '腰': 'hips',
               '下半身': 'hips', '上半身': 'spine', '上半身1': 'chest', '上半身2': 'chest', '首': 'neck', '頭': 'head'}
    source_names = {'spine': '上半身', 'chest': '上半身2', 'neck': '首', 'head': '頭'}
    for side, suffix in [('左', '.L'), ('右', '.R')]:
        for jp, en in [('肩', 'shoulder'), ('腕', 'upper_arm'), ('ひじ', 'forearm'),
                       ('手首', 'hand'), ('足', 'thigh'), ('ひざ', 'shin'), ('足首', 'foot')]:
            mapping[side + jp] = en + suffix
            source_names[en + suffix] = side + jp
        for jp, en in [('足D', 'thigh'), ('ひざD', 'shin'), ('足首D', 'foot'), ('足先EX', 'foot')]:
            mapping[side + jp] = en + suffix
    anchors = {name: source_positions[jp] for name, jp in source_names.items()}
    anchors['hips'] = (anchors['thigh.L'] + anchors['thigh.R']) / 2
    anchors['root'] = np.zeros(3)
    next_bone = {'hips': 'spine', 'spine': 'chest', 'chest': 'neck', 'neck': 'head'}
    for suffix in ['.L', '.R']:
        for a, b in [('shoulder', 'upper_arm'), ('upper_arm', 'forearm'),
                     ('forearm', 'hand'), ('thigh', 'shin'), ('shin', 'foot')]:
            next_bone[a + suffix] = b + suffix
    scale = 0.085
    # Retain the base rig's joint axes and motion while fitting the skin's anatomy.
    original_world = {i: world(i).copy() for i in joints}
    old_target = {name: position.copy() for name, position in target.items()}
    target = {name: anchor * scale for name, anchor in anchors.items()}
    # Preserve extra unweighted rig bones (e.g. Warden's cape) and their animation paths.
    def extra_anchor(index):
        name = nodes[index]['name']
        if name not in anchors:
            ancestor = parent[index]
            parent_name = nodes[ancestor]['name']
            extra_anchor(ancestor)
            anchors[name] = anchors[parent_name] + (old_target[name] - old_target[parent_name]) / scale
            target[name] = anchors[name] * scale
    for index in joints:
        extra_anchor(index)
    for suffix in ['.L', '.R']:
        for a, b in [('upper_arm', 'forearm'), ('forearm', 'hand')]:
            first, second = a + suffix, b + suffix
            direction = old_target[second] - old_target[first]
            target[second] = target[first] + direction / np.linalg.norm(direction) * np.linalg.norm(anchors[second] - anchors[first]) * scale
    translation_deltas = {}
    for index in joints:
        name = nodes[index]['name']
        old_local = np.array(nodes[index].get('translation', [0, 0, 0]))
        ancestor = parent.get(index)
        parent_position = target[nodes[ancestor]['name']] if ancestor in joints else world(ancestor)[:3, 3]
        parent_basis = original_world[ancestor][:3, :3] if ancestor in joints else world(ancestor)[:3, :3]
        new_local = np.linalg.inv(parent_basis) @ (target[name] - parent_position)
        nodes[index]['translation'] = new_local.tolist()
        translation_deltas[index] = new_local - old_local

    def array_view(accessor_id):
        acc = gltf['accessors'][accessor_id]
        view = gltf['bufferViews'][acc['bufferView']]
        count = {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}[acc['type']]
        return np.frombuffer(binary, dtype='<f4', count=acc['count'] * count,
                             offset=view.get('byteOffset', 0) + acc.get('byteOffset', 0)).reshape(-1, count)

    translated = {}
    for animation in gltf['animations']:
        for channel in animation['channels']:
            index = channel['target']['node']
            if channel['target']['path'] == 'translation' and index in translation_deltas:
                sampler = animation['samplers'][channel['sampler']].copy()
                key = (sampler['output'], index)
                if key not in translated:
                    # glTF shares constant accessors between clips AND left/right joints.
                    # Fit a private copy rather than accumulating offsets on shared data.
                    values = array_view(sampler['output']).copy() + translation_deltas[index]
                    values = values.astype('<f4')
                    binary.extend(b'\0' * (-len(binary) % 4))
                    view_id = len(gltf['bufferViews'])
                    gltf['bufferViews'].append(dict(buffer=0, byteOffset=len(binary), byteLength=values.nbytes))
                    binary.extend(values.tobytes())
                    translated[key] = len(gltf['accessors'])
                    gltf['accessors'].append(dict(bufferView=view_id, componentType=5126, count=len(values), type='VEC3',
                                                 min=values.min(axis=0).tolist(), max=values.max(axis=0).tolist()))
                sampler['output'] = translated[key]
                channel['sampler'] = len(animation['samplers'])
                animation['samplers'].append(sampler)
    inverse_binds = array_view(gltf['skins'][0]['inverseBindMatrices'])
    for slot, index in enumerate(joints):
        matrix = original_world[index].copy()
        matrix[:3, 3] = target[nodes[index]['name']]
        inverse_binds[slot] = np.linalg.inv(matrix).T.reshape(-1)
    del inverse_binds
    sword_delta = target['hand.R'] - old_target['hand.R']
    changed = set()
    for node in nodes:
        if 'mesh' in node and node.get('name', '').startswith(weapon_prefix):
            for primitive in gltf['meshes'][node['mesh']]['primitives']:
                accessor_id = primitive['attributes']['POSITION']
                if accessor_id not in changed:
                    array_view(accessor_id)[:] += sword_delta
                    changed.add(accessor_id)
                    gltf['accessors'][accessor_id]['min'] = array_view(accessor_id).min(axis=0).tolist()
                    gltf['accessors'][accessor_id]['max'] = array_view(accessor_id).max(axis=0).tolist()
    transforms = {}
    for name in anchors:
        linear = np.eye(3) * scale
        if name in next_bone:
            child = next_bone[name]
            a, b = anchors[child] - anchors[name], target[child] - target[name]
            alen, blen = np.linalg.norm(a), np.linalg.norm(b)
            u, v = a / alen, b / blen
            cross = np.cross(u, v)
            skew = np.array([[0, -cross[2], cross[1]], [cross[2], 0, -cross[0]], [-cross[1], cross[0], 0]])
            rotation = np.eye(3) + skew + skew @ skew / max(1e-8, 1 + np.dot(u, v))
            linear = rotation @ (scale * np.eye(3) + (blen / alen - scale) * np.outer(u, u))
        elif name.startswith('hand'):
            linear = transforms['forearm' + name[-2:]][0].copy()
        transforms[name] = linear, target[name] - linear @ anchors[name]

    def canonical(index):
        visited = set()
        while index >= 0 and index not in visited:
            visited.add(index)
            bone = model.bones[index]
            if bone['name'] in mapping:
                return mapping[bone['name']]
            index = bone['parent']
        return 'hips'

    # Restore secondary bones instead of collapsing all hair/cloth weights to the torso.
    # Keep the base rig's bones first, preserving animation and contact paths.
    secondary = {}
    for i, bone in enumerate(model.bones):
        name = bone['name']
        if '錘' in name:
            continue
        category = None
        if name.startswith(('裙_', 'WT_')):
            category = 'Skirt'
        elif '髮_' in name:
            category = 'Hair'
        elif '袖' in name:
            category = 'Sleeve'
        elif name.startswith(('Ctr_', 'Skn_')):
            if any(word in name for word in ['Hair', 'Bangs', 'FaShi']):
                category = 'Hair'
            elif 'Sleeve' in name:
                category = 'Sleeve'
            elif any(word in name for word in ['Tape', 'ArmKnot', 'Accessories', 'Pendant', 'CopperCoins']):
                category = 'Ribbon'
        if category:
            secondary[i] = f'{node_prefix}{category}_{i:03d}'
    secondary_nodes = {}

    def add_secondary(index):
        if index in secondary_nodes:
            return secondary_nodes[index]
        bone = model.bones[index]
        ancestor = bone['parent']
        if ancestor in secondary:
            parent_node = add_secondary(ancestor)
        else:
            parent_node = joints[joint_ids[canonical(ancestor)]]
        base = canonical(index)
        linear, offset = transforms[base]
        global_matrix = np.eye(4)
        global_matrix[:3, 3] = linear @ source_positions[bone['name']] + offset
        local_matrix = np.linalg.inv(world(parent_node)) @ global_matrix
        node_id = len(nodes)
        nodes.append(dict(name=secondary[index], matrix=local_matrix.T.reshape(-1).tolist()))
        nodes[parent_node].setdefault('children', []).append(node_id)
        parent[node_id] = parent_node
        secondary_nodes[index] = node_id
        joint_ids[secondary[index]] = len(joints)
        joints.append(node_id)
        return node_id

    for index in secondary:
        add_secondary(index)
    inverse_matrices = np.array([np.linalg.inv(world(index)).T.reshape(-1) for index in joints], dtype='<f4')
    binary.extend(b'\0' * (-len(binary) % 4))
    bind_view = len(gltf['bufferViews'])
    gltf['bufferViews'].append(dict(buffer=0, byteOffset=len(binary), byteLength=inverse_matrices.nbytes))
    binary.extend(inverse_matrices.tobytes())
    gltf['skins'][0]['inverseBindMatrices'] = len(gltf['accessors'])
    gltf['accessors'].append(dict(bufferView=bind_view, componentType=5126, count=len(joints), type='MAT4'))

    def skin_joint(index):
        while index >= 0:
            if index in secondary:
                return secondary[index]
            if model.bones[index]['name'] in mapping:
                return mapping[model.bones[index]['name']]
            index = model.bones[index]['parent']
        return 'hips'

    positions, normals, uvs, weights, skin_joints = [], [], [], [], []
    for pos, normal, uv, bones, values in model.vertices:
        p, n = np.array(pos) * [1, 1, -1], np.array(normal) * [1, 1, -1]
        influence = {}
        for index, weight in zip(bones, values):
            if index >= 0 and weight > 0:
                name = canonical(index)
                influence[name] = influence.get(name, 0.0) + weight
        if not influence:
            influence = {'hips': 1.0}
        total = sum(influence.values())
        influence = {k: v / total for k, v in influence.items()}
        positions.append(sum(weight * (transforms[name][0] @ p + transforms[name][1]) for name, weight in influence.items()))
        normal = sum(weight * (np.linalg.inv(transforms[name][0]).T @ n) for name, weight in influence.items())
        normals.append(normal / max(np.linalg.norm(normal), 1e-8))
        uvs.append(uv)
        skin_influence = {}
        for index, weight in zip(bones, values):
            if index >= 0 and weight > 0:
                name = skin_joint(index)
                skin_influence[name] = skin_influence.get(name, 0.0) + weight
        if not skin_influence:
            skin_influence = {'hips': 1.0}
        total = sum(skin_influence.values())
        skin_joints.append([joint_ids[k] for k in skin_influence] + [0] * (4 - len(skin_influence)))
        weights.append([v / total for v in skin_influence.values()] + [0.0] * (4 - len(skin_influence)))

    def buffer_view(data):
        binary.extend(b'\0' * (-len(binary) % 4))
        view = len(gltf['bufferViews'])
        gltf['bufferViews'].append(dict(buffer=0, byteOffset=len(binary), byteLength=len(data)))
        binary.extend(data)
        return view

    def accessor(values, dtype, component, kind):
        array = np.asarray(values, dtype=dtype)
        result = dict(bufferView=buffer_view(array.tobytes()), componentType=component, count=len(array), type=kind)
        if kind == 'VEC3':
            result.update(min=array.min(axis=0).tolist(), max=array.max(axis=0).tolist())
        index = len(gltf['accessors'])
        gltf['accessors'].append(result)
        return index

    attributes = dict(POSITION=accessor(positions, '<f4', 5126, 'VEC3'),
                      NORMAL=accessor(normals, '<f4', 5126, 'VEC3'),
                      TEXCOORD_0=accessor(uvs, '<f4', 5126, 'VEC2'),
                      JOINTS_0=accessor(skin_joints, '<u2', 5123, 'VEC4'),
                      WEIGHTS_0=accessor(weights, '<f4', 5126, 'VEC4'))
    gltf.setdefault('images', [])
    gltf.setdefault('textures', [])
    texture_cache = {}

    def texture(index):
        if index not in texture_cache:
            path = source / model.textures[index].replace('\\', '/')
            out = io.BytesIO()
            with Image.open(path) as im:
                im.convert('RGBA').save(out, format='PNG')
            image_id = len(gltf['images'])
            gltf['images'].append(dict(bufferView=buffer_view(out.getvalue()), mimeType='image/png'))
            texture_cache[index] = len(gltf['textures'])
            gltf['textures'].append(dict(source=image_id))
        return texture_cache[index]

    primitives, start = [], 0
    for material in model.materials:
        indices = model.indices[start:start + material['count']]
        start += material['count']
        # MMD sphere highlight duplicates the hair surface; keep the actual hair only.
        if material['diffuse'][3] <= 0 or material['name'] in skipped_materials:
            continue
        pbr = dict(baseColorFactor=list(material['diffuse']), metallicFactor=0.0, roughnessFactor=0.85)
        if material['texture'] >= 0:
            pbr['baseColorTexture'] = dict(index=texture(material['texture']))
        mat_id = len(gltf['materials'])
        mat = dict(name=node_prefix + '_' + material['name'], pbrMetallicRoughness=pbr,
                   doubleSided=True, alphaMode='BLEND' if material['diffuse'][3] < 1 else 'MASK', alphaCutoff=0.1)
        gltf['materials'].append(mat)
        faces = np.array(indices, dtype=np.uint32).reshape(-1, 3)[:, ::-1].copy().reshape(-1)
        primitives.append(dict(attributes=attributes, indices=accessor(faces, '<u4', 5125, 'SCALAR'), material=mat_id))
    # Keep the base character's weapon nodes and blade length for the contact system.
    removed = {i for i, node in enumerate(nodes) if 'mesh' in node and not node.get('name', '').startswith(weapon_prefix)}
    for i in removed:
        nodes[i].pop('mesh', None)
        nodes[i].pop('skin', None)
    for node in nodes:
        if 'children' in node:
            node['children'] = [i for i in node['children'] if i not in removed]
    for scene in gltf['scenes']:
        scene['nodes'] = [i for i in scene.get('nodes', []) if i not in removed]
    new_index = len(nodes)
    nodes.append(dict(name=body_name, mesh=len(gltf['meshes']), skin=0))
    gltf['meshes'].append(dict(name=body_name, primitives=primitives))
    rig = next(n for n in nodes if n.get('name') == rig_name)
    rig.setdefault('children', []).append(new_index)
    gltf['asset']['extras'] = dict(skin=skin_name, base_character='Arclight' if base_model == 'arclight' else 'Ashen Warden', author='观海子', rights='miHoYo',
                                  source=str((source / pmx_name).relative_to(ROOT)), terms=str((source / 'readme【一定要看】.txt').relative_to(ROOT)))
    binary.extend(b'\0' * (-len(binary) % 4))
    gltf['buffers'] = [dict(byteLength=len(binary))]
    payload = json.dumps(gltf, ensure_ascii=True, separators=(',', ':')).encode()
    payload += b' ' * (-len(payload) % 4)
    output = ROOT / f'assets/models/{output_name}.glb'
    with output.open('wb') as f:
        f.write(struct.pack('<III', 0x46546c67, 2, 12 + 8 + len(payload) + 8 + len(binary)))
        f.write(struct.pack('<II', len(payload), 0x4e4f534a)); f.write(payload)
        f.write(struct.pack('<II', len(binary), 0x004e4942)); f.write(binary)
    print(f'Built {output.name}: {len(positions)} vertices, {len(primitives)} surfaces, {len(joints)} bones ({len(secondary)} spring bones), {output.stat().st_size} bytes')


if __name__ == '__main__':
    build()
