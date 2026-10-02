"""Weapons (barrel along -Y, Handle + Muzzle parts) and loot containers.
Run:  python items.py <outdir>"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from common import reset, box, cyl, sphere, tube_between, wedge, merge_by_material, export_fbx, render_preview  # noqa: E402

OUT = sys.argv[-1]
os.makedirs(os.path.join(OUT, "weapons"), exist_ok=True)
os.makedirs(os.path.join(OUT, "props"), exist_ok=True)

DARK = "1f2024"
GRIP = "2b2a28"
ORANGE = "ff8c1e"


def gun(body_col, length, barrel_len, mag=True, stock=False, scope=False, pump=False, drum=False):
    z = 1.0
    box("Receiver", "Metal", body_col, (0.32, length, 0.42), (0, 0, z), bevel=0.04)
    box("TopRail", "Metal", DARK, (0.18, length * 0.8, 0.06), (0, -0.05, z + 0.24), bevel=0.01)
    box("Stripe", "SmoothPlastic", ORANGE, (0.33, length * 0.25, 0.08), (0, length * 0.15, z + 0.05), bevel=0.01)
    box("Handle", "SmoothPlastic", GRIP, (0.26, 0.3, 0.6), (0, length * 0.3, z - 0.42), rot=(-15, 0, 0), bevel=0.05)
    box("TriggerGuard", "Metal", DARK, (0.08, 0.3, 0.05), (0, length * 0.12, z - 0.3), bevel=0)
    cyl("Barrel", "Metal", DARK, 0.07, barrel_len, (0, -length / 2 - barrel_len / 2, z + 0.06), rot=(90, 0, 0), verts=16)
    box("Muzzle", "Metal", DARK, (0.16, 0.12, 0.16), (0, -length / 2 - barrel_len - 0.06, z + 0.06), bevel=0.02)
    if mag:
        if drum:
            cyl("Mag", "Metal", DARK, 0.28, 0.22, (0, -length * 0.05, z - 0.45), rot=(0, 90, 0), verts=20)
        else:
            box("Mag", "Metal", DARK, (0.2, 0.26, 0.65), (0, -length * 0.08, z - 0.48), rot=(10, 0, 0), bevel=0.03)
    if stock:
        box("Stock", "SmoothPlastic", GRIP, (0.24, 0.8, 0.3), (0, length / 2 + 0.38, z - 0.08), bevel=0.05)
        box("StockPad", "SmoothPlastic", "111111", (0.26, 0.08, 0.42), (0, length / 2 + 0.8, z - 0.12), bevel=0.02)
    if scope:
        cyl("Scope", "Metal", DARK, 0.11, 0.9, (0, -0.05, z + 0.42), rot=(90, 0, 0), verts=16)
        cyl("Lens", "Neon", "50b4ff", 0.09, 0.02, (0, -0.51, z + 0.42), rot=(90, 0, 0), verts=16, bevel=0)
        box("ScopeMount", "Metal", DARK, (0.08, 0.3, 0.16), (0, -0.05, z + 0.3), bevel=0)
    if pump:
        cyl("Pump", "SmoothPlastic", GRIP, 0.1, 0.55, (0, -length / 2 - barrel_len * 0.35, z - 0.08), rot=(90, 0, 0), verts=16)


WEAPONS = {
    "ScrapPistol": lambda: gun("6e665e", 0.8, 0.35, mag=False),
    "Rattler": lambda: gun("4a5a46", 1.2, 0.5, drum=True),
    "Hammer": lambda: gun("3a3a40", 1.5, 0.8, stock=True),
    "Breacher": lambda: gun("6e4a2c", 1.4, 1.0, mag=False, stock=True, pump=True),
    "Longshot": lambda: gun("2e3a4a", 1.7, 1.5, stock=True, scope=True),
}


def crate():
    box("Crate", "WoodPlanks", "8c6a3c", (2.2, 1.6, 1.4), (0, 0, 0.7), bevel=0.04)
    for x in (-1.05, 1.05):
        box("Frame", "Metal", "3a3a3e", (0.12, 1.65, 1.45), (x, 0, 0.7), bevel=0.02)
    box("Lid", "WoodPlanks", "7a5a30", (2.25, 1.65, 0.12), (0, 0, 1.45), bevel=0.02)
    box("Stencil", "SmoothPlastic", ORANGE, (0.8, 0.02, 0.3), (0, -0.81, 0.8), bevel=0)


def toolbox():
    box("Box", "Metal", "c8322a", (1.6, 0.8, 0.8), (0, 0, 0.4), bevel=0.05)
    box("Lid", "Metal", "a82820", (1.62, 0.82, 0.2), (0, 0, 0.88), bevel=0.04)
    tube_between("HandleBar", "Metal", "222222", (-0.4, 0, 1.0), (0.4, 0, 1.0), 0.04)
    box("Latch", "Metal", "cccccc", (0.15, 0.04, 0.12), (0, -0.42, 0.75), bevel=0)


def med_cabinet():
    box("Cabinet", "Metal", "e6e6e6", (1.4, 0.6, 2.0), (0, 0, 1.0), bevel=0.04)
    box("Cross", "Neon", "ff3232", (0.5, 0.04, 0.15), (0, -0.31, 1.3), bevel=0)
    box("Cross", "Neon", "ff3232", (0.15, 0.04, 0.5), (0, -0.31, 1.3), bevel=0)
    box("Seam", "Metal", "999999", (0.02, 0.62, 1.8), (0, 0, 1.0), bevel=0)


def weapon_case():
    box("Case", "Metal", "3c4a3a", (2.6, 1.0, 0.6), (0, 0, 0.3), bevel=0.06)
    box("Lid", "Metal", "33402f", (2.62, 1.02, 0.25), (0, 0, 0.72), bevel=0.05)
    for x in (-0.9, 0.9):
        box("Clasp", "Metal", "c8c8c8", (0.2, 0.06, 0.2), (x, -0.52, 0.55), bevel=0.01)
    box("Stripe", "SmoothPlastic", ORANGE, (2.0, 0.02, 0.08), (0, -0.52, 0.3), bevel=0)


def robot_cache():
    box("Cache", "Metal", "3a3a42", (2.0, 2.0, 2.0), (0, 0, 1.0), bevel=0.15, segments=3)
    for x in (-1, 1):
        box("Vent", "Metal", "1c1c20", (0.05, 1.2, 1.2), (x * 1.01, 0, 1.0), bevel=0)
    sphere("Core", "Neon", "50c8ff", 0.35, (0, -1.0, 1.2))
    box("Band", "SmoothPlastic", ORANGE, (2.05, 2.05, 0.15), (0, 0, 1.6), bevel=0.02)


def backpack():
    box("Pack", "Fabric", "3c5078", (1.2, 0.7, 1.5), (0, 0, 0.75), bevel=0.15, segments=3)
    box("Pocket", "Fabric", "2e3e5e", (0.9, 0.25, 0.6), (0, -0.45, 0.5), bevel=0.08)
    box("Flap", "Fabric", "2e3e5e", (1.22, 0.72, 0.25), (0, 0, 1.5), bevel=0.08)
    for x in (-0.35, 0.35):
        box("Strap", "Fabric", "1e1e1e", (0.12, 0.08, 1.3), (x, 0.38, 0.75), bevel=0.02)


def wreck():
    box("Hull", "CorrodedMetal", "4a4540", (2.0, 1.6, 0.8), (0, 0, 0.4), rot=(0, 8, 15), bevel=0.06)
    tube_between("BrokenLeg", "Metal", "2e2f34", (0.6, 0.4, 0.4), (1.6, 1.1, 0.1), 0.08)
    tube_between("BrokenLeg", "Metal", "2e2f34", (-0.6, -0.3, 0.4), (-1.5, -1.2, 0.05), 0.08)
    sphere("DeadEye", "Neon", "ff6a28", 0.18, (0, -0.85, 0.5))
    box("Plate", "SmoothPlastic", "bfb8a8", (1.0, 0.8, 0.12), (0.8, -0.8, 0.06), rot=(0, 0, 30), bevel=0.03)


PROPS = {
    "Crate": crate, "Toolbox": toolbox, "MedCabinet": med_cabinet, "WeaponCase": weapon_case,
    "RobotCache": robot_cache, "DeathCache": backpack, "Wreck": wreck,
}

for name, build in WEAPONS.items():
    reset()
    build()
    merge_by_material()
    render_preview(os.path.join(OUT, "weapons", f"{name}.png"), 3.2, 1.5, (0, -0.3, 1))
    export_fbx(os.path.join(OUT, "weapons", f"{name}.fbx"))
    print("built", name)

for name, build in PROPS.items():
    reset()
    build()
    merge_by_material()
    render_preview(os.path.join(OUT, "props", f"{name}.png"), 4.5, 2.5, (0, 0, 0.7))
    export_fbx(os.path.join(OUT, "props", f"{name}.fbx"))
    print("built", name)
