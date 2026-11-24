import bpy, math, sys
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
OUT = argv[0]

def hexrgb(h, a=1.0):
    h = h.lstrip('#'); c = [int(h[i:i+2], 16) / 255 for i in (0, 2, 4)]
    lin = [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return (*lin, a)

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    engines = [i.identifier for i in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    eevee = next((e for e in engines if "EEVEE" in e), None)
    try:
        sc.render.engine = eevee or "CYCLES"
    except TypeError:
        sc.render.engine = "CYCLES"
    if sc.render.engine == "CYCLES":
        sc.cycles.samples = 96
        sc.cycles.use_denoising = True
    sc.render.resolution_x = sc.render.resolution_y = 768
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    try:
        sc.view_settings.view_transform = "Standard"
    except TypeError:
        pass
    world = bpy.data.worlds.new("W"); sc.world = world
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = hexrgb("#FFF7F8"); bg.inputs[1].default_value = 0.45
    return sc

def mat(name, color, rough=0.35, coat=0.6, metallic=0.0, sss=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    p = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    def setin(key, val):
        if key in p.inputs: p.inputs[key].default_value = val
    setin("Base Color", hexrgb(color)); setin("Roughness", rough); setin("Metallic", metallic)
    setin("Coat Weight", coat); setin("Coat Roughness", 0.08)
    setin("Subsurface Weight", sss)
    return m

def smooth(obj, levels=2):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.shade_smooth()
    mod = obj.modifiers.new("Sub", "SUBSURF"); mod.levels = levels; mod.render_levels = levels
    obj.select_set(False)

def lights_camera(sc, target=(0, 0, 0), dist=6.2, elev=18, size=3.2):
    def area(name, loc, energy, color="#FFFFFF", s=4.0):
        L = bpy.data.lights.new(name, "AREA"); L.energy = energy; L.size = s; L.color = hexrgb(color)[:3]
        o = bpy.data.objects.new(name, L); sc.collection.objects.link(o); o.location = loc
        d = Vector(target) - Vector(loc); o.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    area("Key", (3.5, -4.5, 5.0), 420)
    area("Fill", (-5.0, -3.0, 2.0), 180, "#FDE7EC")
    area("Rim", (0.0, 4.5, 4.0), 380, "#F9A2C1")
    cam = bpy.data.cameras.new("Cam"); cam.type = "ORTHO"; cam.ortho_scale = size
    co = bpy.data.objects.new("Cam", cam); sc.collection.objects.link(co); sc.camera = co
    e = math.radians(elev)
    co.location = (0, -dist * math.cos(e), dist * math.sin(e) + target[2])
    co.rotation_euler = (Vector(target) - co.location).to_track_quat("-Z", "Y").to_euler()

def petal(sc, loc, rot_y, scale, m):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=24, location=loc)
    o = bpy.context.active_object; o.scale = scale; o.rotation_euler = (0, rot_y, 0)
    o.data.materials.append(m); smooth(o, 1); return o

def tulip(sc, z, base_scale, m_main, m_side):
    s = base_scale
    petal(sc, (-0.26 * s, 0.0, z - 0.06 * s), math.radians(-24), (0.22 * s, 0.10 * s, 0.40 * s), m_side)
    petal(sc, (0.26 * s, 0.0, z - 0.06 * s), math.radians(24), (0.22 * s, 0.10 * s, 0.40 * s), m_side)
    petal(sc, (0, -0.04, z + 0.04 * s), 0.0, (0.24 * s, 0.11 * s, 0.48 * s), m_main)

def token():
    sc = reset()
    gold = mat("Gold", "#F5B83D", rough=0.22, coat=0.4, metallic=0.85)
    face = mat("Pearl", "#FDE7EC", rough=0.35, coat=0.8)
    pink = mat("Pink", "#E62B5E", rough=0.28, coat=0.9, sss=0.05)
    petal_m = mat("Petal", "#F7729A", rough=0.3, coat=0.9)
    bpy.ops.mesh.primitive_cylinder_add(vertices=128, radius=1.25, depth=0.32, rotation=(math.radians(90), 0, 0))
    rim = bpy.context.active_object; rim.data.materials.append(gold)
    bev = rim.modifiers.new("Bev", "BEVEL"); bev.width = 0.08; bev.segments = 6
    bpy.ops.object.shade_smooth()
    bpy.ops.mesh.primitive_cylinder_add(vertices=128, radius=1.04, depth=0.34, rotation=(math.radians(90), 0, 0))
    disc = bpy.context.active_object; disc.data.materials.append(face)
    bev = disc.modifiers.new("Bev", "BEVEL"); bev.width = 0.05; bev.segments = 5
    bpy.ops.object.shade_smooth()
    for o in list(sc.objects):
        pass
    tulip(sc, 0.0, 1.25, pink, petal_m)
    for o in sc.objects:
        if o.type == "MESH" and o.name.startswith("Sphere"):
            o.location.y += -0.22
    lights_camera(sc, target=(0, 0, 0), elev=8, size=2.9)
    sc.render.filepath = OUT + "/kelopak_token_3d.png"
    bpy.ops.render.render(write_still=True)

def gift():
    sc = reset()
    box_m = mat("Box", "#F7729A", rough=0.32, coat=0.8, sss=0.03)
    lid_m = mat("Lid", "#D81F57", rough=0.3, coat=0.85)
    rib_m = mat("Ribbon", "#FBCFDB", rough=0.25, coat=0.9)
    bpy.ops.mesh.primitive_cube_add(size=2, location=(0, 0, -0.35)); b = bpy.context.active_object
    b.scale = (0.9, 0.9, 0.72); b.data.materials.append(box_m)
    m = b.modifiers.new("Bev", "BEVEL"); m.width = 0.12; m.segments = 6
    bpy.ops.mesh.primitive_cube_add(size=2, location=(0, 0, 0.47)); l = bpy.context.active_object
    l.scale = (1.0, 1.0, 0.18); l.data.materials.append(lid_m)
    m = l.modifiers.new("Bev", "BEVEL"); m.width = 0.1; m.segments = 6
    for sx, sy in ((0.17, 0.92), (0.92, 0.17)):
        bpy.ops.mesh.primitive_cube_add(size=2, location=(0, 0, -0.33)); r = bpy.context.active_object
        r.scale = (sx, sy, 0.745); r.data.materials.append(rib_m)
        m = r.modifiers.new("Bev", "BEVEL"); m.width = 0.04; m.segments = 4
        bpy.ops.mesh.primitive_cube_add(size=2, location=(0, 0, 0.48)); r2 = bpy.context.active_object
        r2.scale = (sx * 1.04 if sx < 0.5 else 1.03, sy * 1.04 if sy < 0.5 else 1.03, 0.19); r2.data.materials.append(rib_m)
        m = r2.modifiers.new("Bev", "BEVEL"); m.width = 0.04; m.segments = 4
    for side in (-1, 1):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.36, minor_radius=0.12, location=(side * 0.34, 0, 0.95),
                                         rotation=(math.radians(90), math.radians(side * 32), 0))
        t = bpy.context.active_object; t.scale = (1.0, 1.0, 0.75); t.data.materials.append(rib_m)
        bpy.ops.object.shade_smooth()
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.16, location=(0, -0.02, 0.8)); k = bpy.context.active_object
    k.data.materials.append(rib_m); bpy.ops.object.shade_smooth()
    for o in sc.objects:
        if o.type == "MESH":
            bpy.context.view_layer.objects.active = o; o.select_set(True); bpy.ops.object.shade_smooth(); o.select_set(False)
    root = bpy.data.objects.new("Root", None); sc.collection.objects.link(root)
    for o in sc.objects:
        if o.type == "MESH": o.parent = root
    root.rotation_euler = (0, 0, math.radians(-24))
    lights_camera(sc, target=(0, 0, 0.15), elev=24, size=3.3)
    sc.render.filepath = OUT + "/gift_box_3d.png"
    bpy.ops.render.render(write_still=True)

token()
gift()
print("RENDER_DONE")
