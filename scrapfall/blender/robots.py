"""Builds the five robots and exports one FBX (+ preview render) per robot.
Run:  python robots.py <outdir>"""
import math
import sys
import os
import bpy

sys.path.insert(0, os.path.dirname(__file__))
from common import reset, box, cyl, sphere, tube_between, wedge, merge_by_material, export_fbx, render_preview, _finish  # noqa: E402

OUT = sys.argv[-1]
os.makedirs(OUT, exist_ok=True)

DARK = "2b2c30"
GUN = "3a3b40"
ARMOR = "d9d2c3"
RUST = "8a4a2c"
ORANGE = "ff8c1e"


def torus(name, mat, color, major, minor, loc, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, location=loc,
                                     rotation=[math.radians(a) for a in rot], major_segments=32, minor_segments=10)
    return _finish(bpy.context.active_object, name, mat, color, 0, 0, True)


def leg(hip, knee, foot, r, color):
    tube_between("Leg", "Metal", color, hip, knee, r)
    tube_between("Leg", "Metal", color, knee, foot, r * 0.8)
    sphere("Joint", "Metal", DARK, r * 1.5, knee)
    sphere("Joint", "Metal", DARK, r * 1.3, hip)
    cyl("Foot", "Metal", DARK, r * 1.6, r, (foot[0], foot[1], foot[2] + r * 0.5), verts=12)


def crawler():
    # small skittering spider-bot (front = -Y)
    sphere("Shell", "Metal", "3e4046", 1.0, (0, 0.1, 1.05), scale=(0.95, 1.25, 0.5))
    box("Plate", "SmoothPlastic", ARMOR, (1.3, 1.5, 0.22), (0, 0.25, 1.48), rot=(6, 0, 0), bevel=0.08, segments=3)
    box("PlateSide", "SmoothPlastic", "bfb8a8", (0.25, 1.2, 0.18), (0.72, 0.2, 1.28), rot=(0, 25, 0), bevel=0.05)
    box("PlateSide", "SmoothPlastic", "bfb8a8", (0.25, 1.2, 0.18), (-0.72, 0.2, 1.28), rot=(0, -25, 0), bevel=0.05)
    box("Stripe", "SmoothPlastic", ORANGE, (0.16, 1.3, 0.05), (0.35, 0.25, 1.61), rot=(6, 0, 0), bevel=0.02)
    for i in range(3):
        box("Vent", "Metal", "1c1c20", (0.7, 0.08, 0.06), (0, 0.75 + i * 0.14, 1.58), rot=(6, 0, 0), bevel=0.01)
    box("Face", "Metal", "26272b", (0.9, 0.35, 0.45), (0, -1.05, 1.0), bevel=0.06)
    sphere("Eye", "Neon", "ff3c28", 0.17, (0, -1.24, 1.05))
    for x in (-0.28, 0.28):
        sphere("EyeSmall", "Neon", "ff3c28", 0.09, (x, -1.22, 1.12))
    for x in (-0.25, 0.25):
        tube_between("Mandible", "Metal", "1c1c20", (x, -1.15, 0.85), (x * 0.5, -1.55, 0.7), 0.05)
    for side in (-1, 1):
        for y in (-0.6, 0.05, 0.7):
            hip = (side * 0.7, y, 0.95)
            knee = (side * 1.55, y * 1.2, 1.75)
            foot = (side * 2.05, y * 1.5, 0.0)
            tube_between("Leg", "Metal", "2e2f34", hip, knee, 0.065)
            tube_between("Leg", "Metal", "2e2f34", knee, foot, 0.05)
            sphere("Joint", "Metal", "1c1c20", 0.1, knee)
            mid = ((hip[0] + knee[0]) / 2, (hip[1] + knee[1]) / 2, (hip[2] + knee[2]) / 2 + 0.08)
            box("Thigh", "SmoothPlastic", "bfb8a8", (0.5, 0.16, 0.12), mid, rot=(0, -side * 40, 0), bevel=0.03)
            cyl("Claw", "Metal", "1c1c20", 0.07, 0.12, (foot[0], foot[1], 0.06), verts=8, bevel=0)
    merge_by_material()


def buzzer():
    cyl("Hull", "Metal", "5a5f6e", 1.1, 0.5, (0, 0, 2.0), verts=32, bevel=0.08)
    sphere("Dome", "SmoothPlastic", ARMOR, 0.75, (0, 0, 2.3), scale=(1, 1, 0.6))
    box("Stripe", "SmoothPlastic", ORANGE, (0.2, 1.8, 0.05), (0, 0, 2.27), bevel=0.02)
    for i in range(4):
        a = math.radians(45 + 90 * i)
        tip = (math.cos(a) * 2.0, math.sin(a) * 2.0, 2.15)
        tube_between("Arm", "Metal", DARK, (math.cos(a) * 0.8, math.sin(a) * 0.8, 2.05), tip, 0.12)
        torus("RotorRing", "Metal", GUN, 0.75, 0.07, (tip[0], tip[1], tip[2] + 0.15))
        cyl("Rotor", "Glass", "1e1e22", 0.7, 0.03, (tip[0], tip[1], tip[2] + 0.2), verts=24, bevel=0)
        sphere("Thruster", "Neon", "78c8ff", 0.16, (tip[0], tip[1], tip[2] - 0.15))
    tube_between("Gun", "Metal", "1e1e22", (0, -0.4, 1.6), (0, -1.6, 1.5), 0.12)
    cyl("GunHousing", "Metal", DARK, 0.3, 0.6, (0, -0.4, 1.65), rot=(90, 0, 0), verts=16)
    sphere("Eye", "Neon", "ffc828", 0.25, (0, -1.08, 1.95))
    merge_by_material()


def watcher():
    sphere("Body", "SmoothPlastic", "e1e1e6", 1.0, (0, 0, 2.5))
    torus("Ring", "Metal", "3c3c42", 1.35, 0.12, (0, 0, 2.5), rot=(90, 0, 0))
    torus("Ring", "Metal", "3c3c42", 1.35, 0.08, (0, 0, 2.5))
    cyl("LensHousing", "Metal", DARK, 0.5, 0.35, (0, -0.9, 2.5), rot=(90, 0, 0), verts=24)
    sphere("Eye", "Neon", "ff2828", 0.38, (0, -1.08, 2.5))
    sphere("Siren", "Neon", "ff2828", 0.25, (0, 0, 3.55))
    for x in (-0.5, 0.5):
        tube_between("Antenna", "Metal", DARK, (x, 0.2, 3.3), (x * 1.6, 0.5, 4.3), 0.04)
        sphere("AntennaTip", "Neon", "ff2828", 0.07, (x * 1.6, 0.5, 4.3))
    merge_by_material()


def walker(scale, boss):
    s = scale
    body_col = "6e6450" if not boss else "3c3732"
    box("Torso", "Metal", body_col, (2.4 * s, 3.0 * s, 1.6 * s), (0, 0, 3.6 * s), bevel=0.15 * s, segments=3)
    wedge("ArmorFront", "SmoothPlastic", ARMOR, (2.6 * s, 1.0 * s, 1.0 * s), (0, -1.6 * s, 3.9 * s), rot=(0, 0, 180))
    box("ArmorTop", "SmoothPlastic", ARMOR, (2.6 * s, 2.4 * s, 0.35 * s), (0, 0.1 * s, 4.55 * s), bevel=0.08 * s)
    box("Stripe", "SmoothPlastic", ORANGE, (0.3 * s, 2.4 * s, 0.05 * s), (0.7 * s, 0.1 * s, 4.75 * s), bevel=0.02)
    box("Head", "Metal", DARK, (1.3 * s, 1.1 * s, 0.9 * s), (0, -1.9 * s, 3.9 * s), bevel=0.1 * s)
    box("Eye", "Neon", "50c8ff" if not boss else "ff2828", (1.0 * s, 0.08 * s, 0.18 * s), (0, -2.47 * s, 4.0 * s), bevel=0)
    for x in (-0.35, 0.35):
        tube_between("Barrel", "Metal", "1e1e22", (x * s, -2.2 * s, 3.6 * s), (x * s, -3.6 * s, 3.55 * s), 0.12 * s)
    # weak point on the back
    cyl("CoreHousing", "Metal", DARK, 0.6 * s, 0.5 * s, (0, 1.55 * s, 3.8 * s), rot=(90, 0, 0), verts=24)
    sphere("WeakPoint", "Neon", ORANGE, 0.45 * s, (0, 1.75 * s, 3.8 * s))
    legr = (0.42 if boss else 0.3) * s
    for sx in (-1, 1):
        for sy in (-1, 1):
            hip = (sx * 1.25 * s, sy * 1.15 * s, 3.2 * s)
            knee = (sx * 2.6 * s, sy * 2.0 * s, 2.6 * s)
            foot = (sx * 2.9 * s, sy * 2.4 * s, 0.0)
            box("HipMount", "Metal", DARK, (0.9 * s, 0.9 * s, 0.9 * s), hip, bevel=0.12 * s)
            tube_between("Thigh", "Metal", "4a4a4f", hip, knee, legr)
            tube_between("Shin", "Metal", "38383d", knee, foot, legr * 0.85)
            sphere("Knee", "Metal", DARK, legr * 1.5, knee)
            mid = ((knee[0] + foot[0]) / 2, (knee[1] + foot[1]) / 2, (knee[2] + foot[2]) / 2)
            box("ShinArmor", "SmoothPlastic", ARMOR, (legr * 2.6, legr * 2.6, 1.6 * s), (mid[0], mid[1], mid[2] + 0.2 * s), bevel=0.08 * s)
            box("ThighArmor", "CorrodedMetal", RUST, (legr * 2.4, 1.0 * s, legr * 1.6),
                ((hip[0] + knee[0]) / 2, (hip[1] + knee[1]) / 2, (hip[2] + knee[2]) / 2 + legr), bevel=0.06 * s)
            box("Foot", "Metal", DARK, (legr * 3.2, legr * 3.6, legr * 1.2), (foot[0], foot[1], legr * 0.6), bevel=0.08 * s)
    if boss:
        for x in (-1, 1):
            box("RocketPod", "CorrodedMetal", "5a2a1e", (1.0 * s, 1.6 * s, 1.0 * s), (x * 1.75 * s, 0, 4.3 * s), bevel=0.08 * s)
            for r in (-1, 1):
                for c in (-1, 1):
                    cyl("RocketTube", "Neon", "ff5a28", 0.15 * s, 0.1 * s, (x * 1.75 * s + c * 0.25 * s, -0.82 * s, 4.3 * s + r * 0.25 * s),
                        rot=(90, 0, 0), verts=12, bevel=0)
        box("Spine", "Metal", DARK, (0.5 * s, 2.6 * s, 0.6 * s), (0, 0.2 * s, 4.95 * s), bevel=0.08 * s)
    merge_by_material()


BUILDERS = {
    "Crawler": (crawler, 6, 2.5, (0, 0, 0.9)),
    "Buzzer": (buzzer, 7, 3.5, (0, 0, 2)),
    "Watcher": (watcher, 7, 3.5, (0, 0, 2.6)),
    "Sentinel": (lambda: walker(1.0, False), 11, 5, (0, 0, 3)),
    "Colossus": (lambda: walker(1.0, True), 12, 6, (0, 0, 3)),
}

only = os.environ.get("ONLY")
for name, (build, dist, height, target) in BUILDERS.items():
    if only and name != only:
        continue
    reset()
    build()
    render_preview(os.path.join(OUT, f"{name}.png"), dist, height, target)
    export_fbx(os.path.join(OUT, f"{name}.fbx"))
    print("built", name)
