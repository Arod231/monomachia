# Credits

The per-file record of where everything in `game/assets` comes from. The short credits page the game ships with is `CREDITS.md` at the repository root (`CREDITS.txt` beside the exe), and `tests/credits.test.mjs` checks that it names every pack recorded here.

| Folder | What it holds | Record |
|---|---|---|
| `quaternius/` | characters, outfits, hair and animation libraries by Quaternius (CC0) | the tables below |
| `weapons/` | the Greatsword and Dagger models by Quaternius (CC0) | the tables below |
| `audio/` | sound effects cut from the Sonniss bundle, and generated sounds and music | `audio/SOURCES.md` |
| `kevin_iglesias/` | the list of licensed Kevin Iglesias clips the game uses and their bone map; the clips themselves are converted on the developer's PC into the gitignored `library/` and never committed | `kevin_iglesias/clip_manifest.json`, and "Not in the repo" below |
| `exports/` | models exported from Blender sources in the asset repository (`npm run export`): Monomachia's own, and CC0 scans | "Exported from Blender" below |
| `authored/` | the hand-keyed animations (`keys/*.json` and the library built from them), Monomachia's own | the project's licence |

The art in `game/assets` comes from free packs by Quaternius. Every pack is under the **CC0 1.0 Universal** public domain dedication (https://creativecommons.org/publicdomain/zero/1.0/): free for any use, commercial included, with no credit required. We credit Quaternius anyway.

Models and animations by **Quaternius** (https://quaternius.com, https://www.patreon.com/quaternius).

| Files | Pack | Source | Licence |
|---|---|---|---|
| `quaternius/animations/UAL1_Standard.glb` | Universal Animation Library, Standard (free) tier | https://quaternius.com | CC0 1.0 (`License.txt` in the pack) |
| `quaternius/animations/UAL2_Standard.glb`, `UAL2_Standard_RM.glb` | Universal Animation Library 2, Standard tier (`_RM`: root motion baked in) | https://quaternius.com | CC0 1.0 (`License.txt`) |
| `quaternius/animations/UAL2_Source.glb`, `UAL2_Source_RM.glb` | Universal Animation Library 2, Source tier: the full clip set (the pack's `UAL2.glb` and `UAL2_RM.glb`, renamed) | https://quaternius.com | CC0 1.0 (`License.txt`) |
| `quaternius/characters/Mannequin_F.glb` | Universal Animation Library 2, female mannequin (same rig as the library, no clips) | https://quaternius.com | CC0 1.0 |
| `quaternius/characters/Superhero_Female_FullBody.*`, `Superhero_Male_FullBody.*` and their textures | Universal Base Characters, Standard tier | https://quaternius.com/packs/universalbasecharacters.html | CC0 1.0 (`License_Standard.txt`) |
| `quaternius/hair/Hair_Long.*`, `Hair_Buzzed.*`, `Hair_Beard.*` and `T_Hair_*` | Universal Base Characters, Standard tier (hairstyles rigged to the head bone) | as above | CC0 1.0 |
| `quaternius/outfits/Female_Ranger_*`, `Male_Ranger_*`, `T_Ranger_*`, `T_Regular_*` | Modular Character Outfits – Fantasy, Standard tier | https://quaternius.com | CC0 1.0 (`License_Standard.txt`) |
| `weapons/Sword_Big.fbx`, `weapons/Dagger.fbx` | LowPoly Medieval Weapons (pack dated 2018-09-10) | https://quaternius.itch.io/lowpoly-medieval-weapons | CC0 1.0 (stated on the itch.io page; the zip has no licence file) |

## What was changed

`game/tools/import_assets.gd` copies these files from the downloaded packs and changes them as follows (all allowed under CC0):

- textures scaled down with Lanczos filtering: base colour to at most 2048 px, normal, ORM and roughness maps to at most 1024 px;
- the bodies' broken texture references (`T_Eye_Normal_png.png`, `T_Hair_1_Normal_png.png`) pointed at the files that exist;
- the outfits use the pack's unreferenced, darker `T_Ranger_3_BaseColor` colourway instead of the green `T_Ranger_BaseColor`;
- the weapons' flat colours replaced at import by the game's own materials (`game/weapons/materials`).

Derived files outside this folder: the head-only meshes (`game/fighters/heads`, cut from the base bodies by `game/tools/cut_heads.gd`), the palette textures (`game/fighters/*/…_outfit.png`, from `T_Ranger_3_BaseColor`, worn with the occlusion in `T_Ranger_ORM`, by `game/tools/bake_palettes.gd`), the fighters' skins (`game/fighters/*/…_skin.png`, from the base bodies' skin by `game/tools/bake_skins.gd`), the Rogue's mask and the Hunter's scarf (made from the head meshes by `game/tools/build_headwear.gd`), the Greatsword and Dagger meshes (`game/weapons/greatsword`, `game/weapons/daggers`, rebuilt from the pack's models by `game/tools/build_pack_weapons.gd`) and the shared clip library (`quaternius/animations/ual_library.res`, built from the two GLBs by `game/tools/build_animation_library.gd`).

The Katana (`game/weapons/katana`), the Hunter's tricorn and the worn-cloth texture (`game/fighters/materials/worn_cloth.png`) are original to this project, built in code by `game/tools/build_katana.gd` and `game/tools/build_headwear.gd`.

## Not in the repo

These packs live in `kevin_iglesias/` of the private asset repository, which the import tools read through the clone `.assets-src-path` names. Their licence allows using them in the game but not redistributing them, so the raw files, and the clips converted from them, must never be committed to this public repo. `node scripts/godot.mjs clips` converts the clips `kevin_iglesias/clip_manifest.json` names into the gitignored `kevin_iglesias/library/`, and a build made with them packs them into the exe. The game uses Human Melee Animations, Human Basic Motions and Human Crafting Animations (two shoulder-carry clips); Human Dance Animations is unused.

| Pack | Version | Source | Licence |
|---|---|---|---|
| Human Melee Animations | 2.1 | https://www.keviniglesias.com | Standard Asset Store EULA: royalty-free, commercial use allowed, no resale, no credit required |
| Human Basic Motions | 2.5 | as above | as above |
| Human Crafting Animations | 2.2 | as above | as above |
| Human Dance Animations | 2.1 | as above | as above |

All four are FBX clips (plus Blender files) made for Kevin Iglesias's own HumanF and HumanM rigs, not the Quaternius skeleton; the import tool retargets them through `kevin_iglesias/iglesias_bone_map.tres`.

## Exported from Blender

`npm run export` copies these from the asset repository's `exports/` (each made from a source listed in its `blender/sources.json`).

| Files | Pack | Source | Licence |
|---|---|---|---|
| `exports/shrine/wisteria_bark.glb` (its colour, normal and roughness maps) | Bark Willow (2K colour, 1K normal and roughness maps), by Poly Haven | https://polyhaven.com/a/bark_willow | CC0 1.0 |

The Hunter's two dyed palettes (`exports/fighters/hunter_crimson.glb` and `hunter_indigo.glb`, each a cloth and a gear atlas of colour, roughness and normal maps) are original to this project, dyed by script in Blender (milestone-1 task 45, `scripts/blender/dye_outfit.py`) from the Quaternius Modular Character Outfits' Ranger maps (CC0, above).

The Moonlit Shrine's five wisteria (`exports/shrine/wisteria_0.glb` to `wisteria_4.glb`, with their blossom texture) are original to this project, grown by script in Blender (milestone-1 task 48).
