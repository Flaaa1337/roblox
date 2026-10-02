"""Shared helpers for building SCRAPFALL assets in Blender (headless).

Every mesh object is named  <Name>__<RobloxMaterial>__<hexcolor>
The game reads these names after import and applies the Roblox material and
colour (so Neon glows, Metal reflects, etc.), independent of how the importer
treats FBX materials. Objects named Eye / WeakPoint / Handle / Muzzle keep that
role in the game.
"""
import math
import bpy
import bmesh

_materials = {}
from mathutils import Vector, Euler


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _materials.clear()


def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def material(rbx_material, color_hex):
    key = (rbx_material, color_hex)
    if key in _materials:
        return _materials[key]
    m = bpy.data.materials.new(f"{rbx_material}_{color_hex}")
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    r, g, b = hex_to_rgb(color_hex)
    # linearize for nicer preview renders
    lin = tuple(c ** 2.2 for c in (r, g, b))
    bsdf.inputs["Base Color"].default_value = (*lin, 1)
    metallic = {"Metal": 0.8, "DiamondPlate": 0.8, "CorrodedMetal": 0.5}.get(rbx_material, 0.0)
    rough = {"Metal": 0.35, "SmoothPlastic": 0.25, "Neon": 0.3, "Glass": 0.05}.get(rbx_material, 0.6)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough
    if rbx_material == "Neon":
        bsdf.inputs["Emission Color"].default_value = (*lin, 1)
        bsdf.inputs["Emission Strength"].default_value = 2.5
    m.diffuse_color = (*lin, 1)
    _materials[key] = m
    return m


def _finish(obj, name, rbx_material, color_hex, bevel, segments, smooth):
    obj.name = f"{name}__{rbx_material}__{color_hex.lstrip('#')}"
    obj.data.materials.clear()
    obj.data.materials.append(material(rbx_material, color_hex.lstrip("#")))
    if bevel > 0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = segments
        mod.limit_method = "ANGLE"
    if smooth:
        for p in obj.data.polygons:
            p.use_smooth = True
    return obj


def box(name, mat, color, size, loc=(0, 0, 0), rot=(0, 0, 0), bevel=0.05, segments=2):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=[math.radians(a) for a in rot])
    obj = bpy.context.active_object
    obj.scale = size
    bpy.ops.object.transform_apply(scale=True)
    return _finish(obj, name, mat, color, bevel, segments, False)


def cyl(name, mat, color, radius, depth, loc=(0, 0, 0), rot=(0, 0, 0), verts=24, bevel=0.03, segments=2):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=loc,
                                        rotation=[math.radians(a) for a in rot])
    obj = bpy.context.active_object
    return _finish(obj, name, mat, color, bevel, segments, True)


def sphere(name, mat, color, radius, loc=(0, 0, 0), scale=(1, 1, 1), segments=24):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=segments // 2, radius=radius, location=loc)
    obj = bpy.context.active_object
    obj.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return _finish(obj, name, mat, color, 0, 0, True)


def tube_between(name, mat, color, a, b, radius, verts=12):
    a, b = Vector(a), Vector(b)
    d = b - a
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=d.length, location=(a + b) / 2)
    obj = bpy.context.active_object
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    return _finish(obj, name, mat, color, 0, 0, True)


def wedge(name, mat, color, size, loc=(0, 0, 0), rot=(0, 0, 0), bevel=0.03):
    """A ramp/prism: full height at -Y, zero at +Y."""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    sx, sy, sz = size[0] / 2, size[1] / 2, size[2] / 2
    v = [bm.verts.new(p) for p in [(-sx, -sy, -sz), (sx, -sy, -sz), (sx, sy, -sz), (-sx, sy, -sz), (-sx, -sy, sz), (sx, -sy, sz)]]
    bm.faces.new([v[0], v[1], v[2], v[3]])
    bm.faces.new([v[0], v[4], v[5], v[1]])
    bm.faces.new([v[3], v[2], v[5], v[4]])
    bm.faces.new([v[0], v[3], v[4]])
    bm.faces.new([v[1], v[5], v[2]])
    bm.normal_update()
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = loc
    obj.rotation_euler = Euler([math.radians(a) for a in rot])
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return _finish(obj, name, mat, color, bevel, 2, False)


def mirror_x(obj):
    """Duplicate an object mirrored across X (for symmetric parts)."""
    new = obj.copy()
    new.data = obj.data.copy()
    bpy.context.collection.objects.link(new)
    new.location.x = -obj.location.x
    new.scale.x = -obj.scale.x
    bpy.context.view_layer.objects.active = new
    for o in bpy.context.selected_objects:
        o.select_set(False)
    new.select_set(True)
    bpy.ops.object.transform_apply(scale=True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.flip_normals()
    bpy.ops.object.mode_set(mode="OBJECT")
    return new


SPECIAL = ("Eye", "WeakPoint", "Handle", "Muzzle")


def merge_by_material():
    """Apply modifiers and join objects that share name role + material + colour,
    keeping special parts (Eye, WeakPoint, Handle, Muzzle) separate."""
    groups = {}
    for obj in list(bpy.context.scene.objects):
        if obj.type != "MESH":
            continue
        role, mat, color = obj.name.split("__")[:3]
        role = role.split(".")[0]
        color = color.split(".")[0]
        key = (role if role in SPECIAL else "Part", mat, color)
        groups.setdefault(key, []).append(obj)
    for (role, mat, color), objs in groups.items():
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.select_set(True)
            bpy.context.view_layer.objects.active = o
            for mod in list(o.modifiers):
                bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.context.view_layer.objects.active = objs[0]
        if len(objs) > 1:
            bpy.ops.object.join()
        joined = bpy.context.active_object
        joined.name = f"{role}__{mat}__{color}"
        joined.data.name = joined.name


def export_fbx(path):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.fbx(
        filepath=path, use_selection=True, apply_unit_scale=True, apply_scale_options="FBX_SCALE_UNITS",
        axis_forward="-Z", axis_up="Y", use_mesh_modifiers=True, mesh_smooth_type="FACE", add_leaf_bones=False,
        bake_space_transform=True,
    )


def render_preview(path, distance=8.0, height=3.0, target=(0, 0, 1)):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 24
    scene.cycles.device = "CPU"
    scene.render.resolution_x = 640
    scene.render.resolution_y = 480
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.12, 0.1, 0.09, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.6
    t = Vector(target)
    cam_data = bpy.data.cameras.new("Cam")
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = t + Vector((distance * 0.75, -distance, height))
    cam.rotation_mode = "QUATERNION"
    cam.rotation_quaternion = (t - cam.location).to_track_quat("-Z", "Y")
    scene.camera = cam
    sun_data = bpy.data.lights.new("Sun", "SUN")
    sun_data.energy = 4
    sun = bpy.data.objects.new("Sun", sun_data)
    sun.rotation_euler = Euler((math.radians(50), math.radians(10), math.radians(30)))
    scene.collection.objects.link(sun)
    # ground
    bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 0, 0))
    ground = bpy.context.active_object
    ground.data.materials.append(material("Concrete", "6b6560"))
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(ground)
    bpy.data.objects.remove(cam)
    bpy.data.objects.remove(sun)
