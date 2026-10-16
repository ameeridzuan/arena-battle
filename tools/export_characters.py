import bpy, sys, os, traceback

OUT_DIR = r"C:\Users\ameer.noorfizan\Documents\BE Development\SourceCode\Qoder_Personal\game_test\ArenaBattle\assets\models"

JOBS = [
    {
        "src": r"C:\Users\ameer.noorfizan\Documents\Codex\2026-10-16\li\outputs\Arclight_Character_Review.blend",
        "rig": "ArclightRig",
        "keep_rigs": ["ArclightRig"],
        "strip_prefix": None,
        "out": os.path.join(OUT_DIR, "arclight.glb"),
    },
    {
        "src": r"C:\Users\ameer.noorfizan\Documents\Codex\2026-10-16\li\outputs\Ashen_Warden_Review.blend",
        "rig": "AshenWardenRig",
        "keep_rigs": ["AshenWardenRig"],
        "strip_prefix": "Warden_",
        "out": os.path.join(OUT_DIR, "ashen_warden.glb"),
    },
]


def slot_rig(act):
    """Return the object-name a slotted action targets (strip leading 'OB'), else None."""
    ids = [s.identifier for s in act.slots]
    for i in ids:
        if i.startswith("OB"):
            return i[2:]
    return None


def do_export(filepath):
    base = dict(
        filepath=filepath,
        use_selection=True,
        export_format="GLB",
        export_yup=True,
        export_skins=True,
        export_animations=True,
        export_animation_mode="ACTIONS",
    )
    try:
        bpy.ops.export_scene.gltf(**base)
        return
    except TypeError as e:
        print("PARAM_RETRY:", e)
    # Fallback: drop params the 5.x exporter may have renamed/removed.
    minimal = dict(filepath=filepath, use_selection=True, export_format="GLB",
                   export_yup=True, export_skins=True, export_animations=True)
    try:
        bpy.ops.export_scene.gltf(**minimal)
        return
    except TypeError:
        bpy.ops.export_scene.gltf(filepath=filepath, use_selection=True,
                                  export_format="GLB", export_animations=True)


for job in JOBS:
    print("\n######## EXPORT", job["rig"], "->", os.path.basename(job["out"]))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.wm.open_mainfile(filepath=job["src"])

    rig = bpy.data.objects.get(job["rig"])
    if rig is None:
        print("FATAL: rig not found", job["rig"]); continue

    # 1) Delete every armature object we are NOT keeping, plus meshes parented to them.
    doomed_rigs = [o for o in bpy.data.objects if o.type == "ARMATURE" and o.name not in job["keep_rigs"]]
    for dr in doomed_rigs:
        for m in [o for o in bpy.data.objects if o.type == "MESH" and o.parent == dr]:
            bpy.data.objects.remove(m, do_unlink=True)
        bpy.data.objects.remove(dr, do_unlink=True)
    print("deleted rigs:", [d.name for d in doomed_rigs])

    # 2) Delete actions slotted to any deleted rig (avoids rename collisions + slim export).
    doomed_rig_names = {d.name for d in doomed_rigs}
    for act in list(bpy.data.actions):
        if slot_rig(act) in doomed_rig_names:
            bpy.data.actions.remove(act, do_unlink=True)

    # 3) Rename remaining (target-rig) actions to canonical names.
    if job["strip_prefix"]:
        for act in bpy.data.actions:
            if act.name.startswith(job["strip_prefix"]):
                act.name = act.name[len(job["strip_prefix"]):]

    # 4) Purge orphan data blocks left by deletions.
    bpy.ops.outliner.orphans_purge(do_recursive=True)

    # 5) Select ONLY the target rig + its skinned meshes.
    bpy.ops.object.select_all(action="DESELECT")
    keep_meshes = [o for o in bpy.data.objects if o.type == "MESH" and o.parent == rig]
    for o in keep_meshes:
        o.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    print("selected meshes:", len(keep_meshes), "| rig:", rig.name)
    print("actions to export:", sorted(a.name for a in bpy.data.actions))

    # 6) Export.
    do_export(job["out"])
    print("exported ->", job["out"], "| exists:", os.path.exists(job["out"]),
          "| bytes:", os.path.getsize(job["out"]) if os.path.exists(job["out"]) else 0)

print("\nDONE_ALL_EXPORTS")
