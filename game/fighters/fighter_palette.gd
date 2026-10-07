class_name FighterPalette
extends Resource
## One colour scheme of a fighter. Every fighter has two, so that a mirror
## match can dress the second fighter differently; the two should differ over
## a large area seen from every side (a value swap of the hood and sleeves,
## not just a different trim), which tests/content/test_palettes.gd checks.
##
## tools/bake_palettes.gd recolours the Ranger outfit's T_Ranger_3 texture
## garment by garment: it knows which garment each texel belongs to from the
## outfit meshes' UVs, and sorts the texels into four materials by colour
## (cloth: the cream shirt, sleeves and trousers; trim: the ochre quilting;
## leather: the brown hood, vest, belts, gloves and boots; metal: buckles,
## studs and plates). Each colour below is what that part should look like
## where the source is a typical mid tone, so the painted shading is kept.
## The bake then adds the wear: ambient occlusion, dirt rising from the
## ground, scuffed knees and cuffs, worn leather edges and blotchy grime.
## The result is `outfit_albedo`.
##
## A palette may instead be dyed in Blender (the Hunter's crimson and indigo,
## milestone-1 task 45): `outfit_maps` is the export's GLB
## (scripts/blender/dye_outfit.py), holding one material per atlas, each its
## base colour, roughness and metalness, and normal map. The outfit's parts
## share one atlas and the gear (belts, boots) reuses the cloth's texels, so
## the dyed cloth and the undyed gear are two atlases: dyed_material() gives a
## mesh its own. The outfit colours below then only record the dye.

@export var display_name: String = ""
@export_group("Outfit")
## The hood, all over.
@export var hood_color: Color = Color(0.3, 0.3, 0.3)
## The leather of the vest.
@export var vest_color: Color = Color(0.3, 0.3, 0.3)
## The shirt showing at the collar and under the vest.
@export var shirt_color: Color = Color(0.3, 0.3, 0.3)
## The quilted panel and padding (the outfit's trim).
@export var trim_color: Color = Color(0.3, 0.3, 0.3)
## The sleeves.
@export var sleeve_color: Color = Color(0.3, 0.3, 0.3)
## The trousers.
@export var trouser_color: Color = Color(0.3, 0.3, 0.3)
## Belts, straps, gloves, bracers and the pauldron's leather.
@export var leather_color: Color = Color(0.2, 0.2, 0.2)
## The boots.
@export var boot_color: Color = Color(0.2, 0.2, 0.2)
## Buckles, studs, rivets and plates (the source's metal is a teal grey,
## which is replaced, not tinted).
@export var metal_color: Color = Color(0.4, 0.4, 0.4)
## How dirty and worn the outfit is, 0 to 1.
@export_range(0.0, 1.0) var wear: float = 0.6
@export_group("Head")
## Multiplies the hair and eyebrows (the hair textures are near white).
@export var hair_color: Color = Color.WHITE
## The cloth of a face mask or hat, for fighters that wear one.
@export var headwear_color: Color = Color(0.1, 0.1, 0.1)
@export_group("Weapon")
## The Katana's sageo, the cord on its saya (milestone-1 task 47): the side's
## dye.
@export var cord_color: Color = Color(0.42, 0.04, 0.05)
@export_group("")
## The baked outfit base colour (written by tools/bake_palettes.gd).
@export var outfit_albedo: Texture2D
## The dyed outfit's maps, from the Blender export, in place of outfit_albedo.
@export var outfit_maps: PackedScene
## The outfit meshes (by a part of their names) that wear the gear atlas.
@export var gear_meshes: PackedStringArray = ["_Body_Belt", "_Feet"]

var _dyed: Dictionary[String, BaseMaterial3D] = {}


## The dyed atlas material `mesh` (an outfit mesh's name) wears: the
## gear's or the cloth's, from outfit_maps (null without them). Each is the
## material named Dye_<id>_<atlas> in the export.
func dyed_material(mesh: String) -> BaseMaterial3D:
	if outfit_maps == null:
		return null
	if _dyed.is_empty():
		var scene: Node = outfit_maps.instantiate()
		for node: Node in scene.find_children("*", "MeshInstance3D", true, false):
			var m: BaseMaterial3D = (node as MeshInstance3D).mesh.surface_get_material(0) as BaseMaterial3D
			if m != null:
				_dyed[m.resource_name.get_slice("_", m.resource_name.get_slice_count("_") - 1)] = m
		scene.free()
	for part: String in gear_meshes:
		if mesh.contains(part):
			return _dyed.get("gear")
	return _dyed.get("cloth")
