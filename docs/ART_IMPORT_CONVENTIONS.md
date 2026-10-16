# Art & Character Import Conventions (M6)

> Establishes the Blender → Godot hand-off conventions for ArenaBattle.
> Source of truth for models: **Blender**, driven through the Qoder `blender` MCP
> (`execute_blender_code` / `bpy`). All asset libraries / 3D generators are OFF, so
> characters are authored procedurally from primitives.

## File layout

| Path | Purpose |
|------|---------|
| `assets/models/<name>.glb` | Exported game-ready model (mesh + rig + animations). |
| `assets/models/preview_frames/` | Optional rendered contact-sheet frames (not imported by Godot gameplay). |
| `scenes/characters/<Name>ModelPreview.tscn` | Standalone manual-preview scene (F5 to eyeball). |
| `scripts/characters/` | Presentation-only preview helpers (no gameplay logic). |
| `tests/integration/model_import_smoke_test.gd` | Automated M6 import/animation gate. |

## Blender export conventions

- **Units / scale:** metric, 1 Blender unit = 1 metre. Character height ~1.7–1.8 m.
- **Origin:** at the feet (ground plane), so Godot places characters on the floor with no offset.
- **Facing:** character faces **−Y** in Blender.
- **Export:** glTF Binary (`.glb`), `export_yup=True` so Godot receives Y-up; `export_skins=True`;
  `export_animations=True`; `export_animation_mode='ACTIONS'`; select only rig + meshes.
- **Rig:** a single armature named `<Name>Rig`. Bone names use Blender `.L` / `.R` suffixes
  (e.g. `upper_arm.R`). Hard-surface / robot characters use **rigid skinning** (each part's
  vertices weighted 1.0 to exactly one bone) — clean deformation and clean game export.
- **Weapons:** model as a SEPARATE mesh skinned to the hand bone (e.g. `hand.R`) so they stay
  swappable and follow the hand.
- **Animations:** one Blender Action per animation, named in PascalCase to match the Godot
  animation name (`Attack`, `Idle`, `Run`). Cyclic animations (Idle/Run) should return to their
  start pose so they loop; one-shot attacks end at rest.
- **Materials:** Principled BSDF only, named `<Category>_<Name>` (e.g. `Armor_Dark`, `Blade_Steel`).
  Avoid node graphs Godot cannot map (procedural textures, complex mixes).

## Godot import conventions

- Keep the default **scene importer** for `.glb` (it produces `Skeleton3D` + `MeshInstance3D`
  + `AnimationPlayer`). Do not switch to "import as skeleton bones" for skinned characters.
- **Do not rename imported nodes that gameplay references.** Until the placeholder mesh is
  swapped, gameplay code hard-references `Player.tscn` node paths: `$Mesh`, `CameraPivot`,
  `AttackHitbox`, `Combatant`, `Health`, `CollisionShape3D`. Any future swap MUST preserve the
  `Mesh` node name/path (or update every reference) or M3/M4/M5 break.
- The actual swap of the placeholder mesh inside `Player.tscn` is **deferred** until the M4/M5
  multiplayer work merges; M6 delivers assets + preview + automated gate only (zero-conflict scope).

## Verification gate (M6 acceptance)

1. Automated: `godot --headless --path . --script res://tests/integration/model_import_smoke_test.gd`
   → asserts model loads, `Skeleton3D` with expected bone count, ≥2 skinned meshes, materials
   present, unit scale, and that playing `Attack` actually moves `hand.R`.
2. Manual: F5 on `scenes/characters/PlayerModelPreview.tscn` (loops `Attack`).

## Coordination

M6 work lives on branch `feature/m6-art` while M4/M5 proceed on `main`. Merge after M4/M5 land;
then perform the `Player.tscn` visual swap preserving node-name contracts.
