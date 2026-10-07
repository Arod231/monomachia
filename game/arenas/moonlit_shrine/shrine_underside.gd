class_name ShrineUnderside
extends RefCounted
## Builds what holds the shrine up: the rock ledge round the courtyard, which
## turns into a great inverted crag below it, roots hanging from the rock,
## chains running down into the clouds, and smaller floating rocks round it,
## some carrying a lantern, a tree or a broken pillar.
##
## Node layout:
## - Underside/Ledge: the shelf the lanterns, pillars and trees stand on, on
##   the ground layer, always drawn;
## - Underside/BelowDeck/{Crag, Roots, Chains}: everything under the rim, on
##   LookPalette.BELOW_DECK_LAYER, which cameras above the courtyard leave out
##   (MoonlitShrine.cull_below_deck);
## - Underside/FloatingRocks/FloatingRock0 and on, which MoonlitShrine bobs
##   with bob_rocks(). A scene in ShrineLayout.prop_scenes under
##   floating_rock replaces each rock and what stands on it.

const ROCK: Shader = preload("res://shaders/rock.gdshader")
## Rows of the crag's lattice that make the ledge, and rows down its sides
## from the rim to the tip.
const LEDGE_ROWS := 5
const SIDE_ROWS := 30
## How far in from the rim the crag's sides stay, as a share of its radius,
## so the ledge hides them from every camera above it.
const UNDERCUT := 0.03
## The side rows the roots hang from (from the rim down; the upper ones,
## above LONG_ROOT_ROWS, hang longer) and the chains hang from.
const ROOT_ROWS := Vector2i(3, 12)
const LONG_ROOT_ROWS := 9
const CHAIN_ROW := 4
## How far the floating rocks bob (m), how fast (radians a second), and how
## fast they turn.
const BOB_HEIGHT := 0.7
const BOB_SPEED := 0.35
const TURN_SPEED := 0.01
## The golden angle: spreads the rocks' bob phases and starting turns.
const PHASE_STEP := 2.39996


## Builds the underside under a new Node3D named Underside.
static func build(layout: ShrineLayout, def: ArenaDef) -> Node3D:
	var root := Node3D.new()
	root.name = "Underside"
	var rng: RandomNumberGenerator = layout.random_stream(&"underside")
	var noise := FastNoiseLite.new()
	noise.seed = layout.seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.045
	noise.fractal_octaves = 4
	var surface: Array[PackedVector3Array] = _crag_lattice(def.floor_radius - 0.15, layout.crag_radius, layout.crag_depth,
		96, noise, true)
	var rock: ShaderMaterial = rock_material()
	root.add_child(_ledge(surface, noise, rock))
	var below := Node3D.new()
	below.name = "BelowDeck"
	root.add_child(below)
	below.add_child(_crag(layout, surface, noise, rng, rock))
	below.add_child(_roots(layout, surface, rng))
	below.add_child(_chains(layout, surface))
	for part: Node in below.get_children():
		(part as GeometryInstance3D).layers = LookPalette.BELOW_DECK_LAYER
	root.add_child(_floating_rocks(layout, rock))
	return root


## Puts each floating rock under rocks over its spot, bobbing up and down and
## slowly turning, time seconds in.
static func bob_rocks(rocks: Node3D, layout: ShrineLayout, time: float) -> void:
	for i: int in mini(rocks.get_child_count(), layout.floating_rocks.size()):
		var f: Vector4 = layout.floating_rocks[i]
		var phase: float = i * PHASE_STEP
		var rock := rocks.get_child(i) as Node3D
		rock.position = ShrineLayout.polar(f.x, f.y, f.z + sin(time * BOB_SPEED + phase) * BOB_HEIGHT)
		rock.rotation.y = phase + time * TURN_SPEED


## The rock's physically based material, for the crag, the floating rocks
## and the backdrop's cliffs.
static func rock_material() -> ShaderMaterial:
	return LookMaterials.make_with_shader(ROCK, LookMaterials.Surface.PROP)


## The crag's surface as a lattice of rows, each a closed ring of segments + 1
## points: with_ledge, a flat ledge at ShrinePlatform.LEDGE_Y from inner out
## to the rim first (a small flat top otherwise), then down the sides to the
## tip. The rim reaches at least radius all round, its bumps up to 16%
## further, and the sides stay inside it (UNDERCUT); depth is how far the
## tip hangs.
static func _crag_lattice(inner: float, radius: float, depth: float, segments: int, noise: FastNoiseLite,
		with_ledge: bool) -> Array[PackedVector3Array]:
	var rows: Array[PackedVector3Array] = []
	var ledge_y: float = ShrinePlatform.LEDGE_Y
	var top_rows: int = LEDGE_ROWS if with_ledge else 2
	var edge := PackedFloat32Array()
	for i: int in segments + 1:
		var a: float = -TAU * (i % segments) / segments
		var ring := Vector2(sin(a), cos(a))
		# The bumps only push the rim out, so whatever the layout stands on the
		# ledge stays on it.
		edge.append(radius * (1.0 + 0.05 * (1.0 + noise.get_noise_2d(ring.x * 60.0, ring.y * 60.0))
			+ 0.03 * (1.0 + noise.get_noise_2d(ring.x * 200.0, ring.y * 200.0))))
	for j: int in top_rows:
		var t: float = float(j) / (top_rows - 1)
		var row := PackedVector3Array()
		for i: int in segments + 1:
			var a: float = -TAU * (i % segments) / segments
			var r: float = lerpf(inner if with_ledge else 0.0, edge[i], t)
			var p := Vector3(sin(a) * r, ledge_y, cos(a) * r)
			p.y += noise.get_noise_2d(p.x * 3.0, p.z * 3.0) * 0.12 * t - 0.25 * t * t
			row.append(p)
		rows.append(row)
	for j: int in SIDE_ROWS:
		var t: float = float(j + 1) / SIDE_ROWS
		var row := PackedVector3Array()
		var y: float = ledge_y - radius * 0.03 - pow(t, 1.15) * (depth - radius * 0.03)
		for i: int in segments + 1:
			var a: float = -TAU * (i % segments) / segments
			# Steep cliffs under the rim, then a lumpy taper to a point. The
			# buttress noise is stretched vertically, so ridges and gullies run
			# down the rock instead of round it.
			var shape: float = pow(1.0 - t, 0.85) * (1.0 - 0.3 * smoothstep(0.08, 0.35, t))
			var r: float = edge[i] * shape
			var p := Vector3(sin(a), 0.0, cos(a))
			var n3: float = noise.get_noise_3d(p.x * r, y * 1.2, p.z * r)
			var buttress: float = noise.get_noise_3d(p.x * 95.0, y * 0.3, p.z * 95.0)
			r = minf(r * (1.0 + 0.24 * buttress + 0.09 * n3), edge[i] * (1.0 - UNDERCUT))
			if j == SIDE_ROWS - 1:
				r = 0.0
			p = p * r
			p.y = y + n3 * radius * 0.07 * (1.0 - t)
			row.append(p)
		rows.append(row)
	return rows


## Adds the lattice rows to kit, darkening crevices and the deep underside.
## first_row and total_rows place the rows within a larger lattice, so a
## lattice split in parts darkens with depth as one piece.
static func _shade_lattice(kit: MeshKit, rows: Array[PackedVector3Array], noise: FastNoiseLite,
		first_row: int = 0, total_rows: int = -1) -> void:
	var total: int = rows.size() if total_rows < 0 else total_rows
	var colors: Array[PackedColorArray] = []
	for j: int in rows.size():
		var depth: float = float(first_row + j) / total
		var row := PackedColorArray()
		for p: Vector3 in rows[j]:
			var crevice: float = clampf(0.5 + 0.5 * noise.get_noise_3d(p.x * 4.0, p.y * 4.0, p.z * 4.0), 0.0, 1.0)
			var v: float = (1.0 - depth * 0.5) * lerpf(0.7, 1.05, crevice)
			row.append(Color(v, v, v * 1.03))
		colors.append(row)
	kit.grid_surface(Transform3D.IDENTITY, rows, true, colors)


## The ledge: the lattice's top rows. It shares the rim row with the crag, so
## they meet without a gap.
static func _ledge(surface: Array[PackedVector3Array], noise: FastNoiseLite, rock: Material) -> MeshInstance3D:
	var kit := MeshKit.new()
	_shade_lattice(kit, surface.slice(0, LEDGE_ROWS), noise, 0, surface.size())
	var ledge := MeshKit.instance(kit.commit(), rock, false)
	ledge.name = "Ledge"
	ledge.layers = LookPalette.GROUND_LAYER
	return ledge


## The crag: the lattice's sides from the rim down, and three spurs hanging
## under the main mass to break up the cone.
static func _crag(layout: ShrineLayout, surface: Array[PackedVector3Array], noise: FastNoiseLite,
		rng: RandomNumberGenerator, rock: Material) -> MeshInstance3D:
	var kit := MeshKit.new()
	_shade_lattice(kit, surface.slice(LEDGE_ROWS - 1), noise, LEDGE_ROWS - 1, surface.size())
	for k: int in 3:
		var a: float = deg_to_rad(40.0 + k * 125.0 + rng.randf_range(-20, 20))
		var spur_r: float = layout.crag_radius * rng.randf_range(0.2, 0.24)
		var spur: Array[PackedVector3Array] = _crag_lattice(0.0, spur_r, layout.crag_depth * rng.randf_range(0.45, 0.6), 28, noise, false)
		var offset := Vector3(sin(a), 0, cos(a)) * layout.crag_radius * 0.17 + Vector3(0, -layout.crag_depth * 0.38, 0)
		for j: int in spur.size():
			var row: PackedVector3Array = spur[j]
			for i: int in row.size():
				row[i] += offset
			spur[j] = row
		_shade_lattice(kit, spur, noise)
	# No shadows: they would fall on nothing that matters.
	var crag := MeshKit.instance(kit.commit(), rock, false)
	crag.name = "Crag"
	return crag


## Roots hanging from the crag's upper sides, a few with a side tendril.
static func _roots(layout: ShrineLayout, surface: Array[PackedVector3Array], rng: RandomNumberGenerator) -> MeshInstance3D:
	var bark := MeshKit.new()
	for i: int in layout.root_count:
		var col: int = rng.randi_range(0, surface[0].size() - 2)
		var side_row: int = rng.randi_range(ROOT_ROWS.x, ROOT_ROWS.y)
		var start: Vector3 = surface[LEDGE_ROWS + side_row][col]
		var outward := Vector3(start.x, 0.0, start.z).normalized()
		var length: float = rng.randf_range(3.0, 11.0) * (1.2 if side_row < LONG_ROOT_ROWS else 0.8)
		var pts := PackedVector3Array()
		var radii := PackedFloat32Array()
		var steps: int = 9
		var sway := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)) * 0.6
		for k: int in steps + 1:
			var t: float = float(k) / steps
			pts.append(start - outward * 0.3 + outward * sqrt(t) * 0.9 + Vector3.DOWN * length * t
				+ sway * sin(t * 3.0) + Vector3(sin(t * 9.0 + i), 0, cos(t * 7.0 + i)) * 0.12)
			radii.append(lerpf(rng.randf_range(0.1, 0.18), 0.012, pow(t, 0.7)))
		bark.tube(pts, radii, 5)
		if rng.randf() < 0.5:
			var k0: int = rng.randi_range(2, 5)
			var base: Vector3 = pts[k0]
			var dir := Vector3(rng.randf_range(-1, 1), -1.5, rng.randf_range(-1, 1)).normalized()
			bark.tube(PackedVector3Array([base, base + dir * 1.2, base + dir * 2.2 + Vector3(0, -0.6, 0)]),
				PackedFloat32Array([radii[k0] * 0.6, radii[k0] * 0.35, 0.01]), 4)
	var roots := MeshKit.instance(bark.commit(), LookMaterials.prop(LookPalette.WOOD_DARK), false)
	roots.name = "Roots"
	return roots


## Iron chains from the crag's sides at layout.chain_angles, sagging outward
## and down into the sea of clouds: one MultiMesh of links.
static func _chains(layout: ShrineLayout, surface: Array[PackedVector3Array]) -> MultiMeshInstance3D:
	var link := MeshKit.new()
	link.torus(Transform3D(Basis().scaled(Vector3(1.0, 1.0, 1.75)), Vector3.ZERO), 0.2, 0.05, 8, 4)
	var link_mesh: ArrayMesh = link.commit()
	var transforms: Array[Transform3D] = []
	var row: int = LEDGE_ROWS + CHAIN_ROW
	var cols: int = surface[0].size() - 1
	for angle: float in layout.chain_angles:
		# Lattice column i lies at -TAU * i / cols round from +Z.
		var col: int = int(wrapf(-angle / 360.0, 0.0, 1.0) * cols) % cols
		var anchor: Vector3 = surface[row][col]
		var outward := Vector3(anchor.x, 0, anchor.z).normalized()
		var end: Vector3 = anchor + outward * 16.0 + Vector3(0, layout.cloud_sea_height - 18.0 - anchor.y, 0)
		var count: int = int(anchor.distance_to(end) / 0.36)
		var prev: Vector3 = anchor
		for k: int in count:
			var t: float = float(k + 1) / count
			# Hangs in a curve: steep near the rock, flatter toward the clouds.
			var p: Vector3 = anchor.lerp(end, t) + outward * sin(t * PI) * 2.5 + Vector3.DOWN * sin(t * PI) * 1.5
			var dir: Vector3 = (p - prev).normalized()
			var b := Basis.looking_at(-dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT)
			# Each link turned a quarter from the last.
			b = b.rotated(dir, PI * 0.5 * (k % 2))
			transforms.append(Transform3D(b, (p + prev) * 0.5))
			prev = p
	var chains: MultiMeshInstance3D = MeshKit.multimesh(link_mesh, transforms, LookMaterials.prop(LookPalette.IRON, LookMaterials.METAL_SURFACE))
	chains.name = "Chains"
	chains.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return chains


## The floating rocks, placed by bob_rocks() at time 0.
static func _floating_rocks(layout: ShrineLayout, rock: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "FloatingRocks"
	var rng: RandomNumberGenerator = layout.random_stream(&"floating_rock")
	var props: Dictionary[StringName, Material] = ShrineProps.materials()
	for i: int in layout.floating_rocks.size():
		if layout.place_art(root, &"floating_rock", i, Transform3D.IDENTITY):
			continue
		var node: Node3D = _floating_rock(layout, i, rock, props, rng)
		node.name = "FloatingRock%d" % i
		root.add_child(node)
	bob_rocks(root, layout, 0.0)
	return root


## Floating rock index: a small crag with its flat top at y = 0, carrying a
## lantern and a young wisteria, a young wisteria or a broken pillar, or
## nothing, in turn (milestone-1 task 48).
static func _floating_rock(layout: ShrineLayout, index: int, rock: Material,
		props: Dictionary[StringName, Material], rng: RandomNumberGenerator) -> Node3D:
	var size: float = layout.floating_rocks[index].w
	var node := Node3D.new()
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.045 / maxf(size / 6.0, 0.3)
	var lattice: Array[PackedVector3Array] = _crag_lattice(0.0, size, size * 2.6, 28, noise, false)
	for j: int in lattice.size():
		var row: PackedVector3Array = lattice[j]
		for i: int in row.size():
			row[i] -= Vector3(0, ShrinePlatform.LEDGE_Y, 0)
		lattice[j] = row
	var kit := MeshKit.new()
	_shade_lattice(kit, lattice, noise)
	var mi := MeshKit.instance(kit.commit(), rock, false)
	mi.name = "Rock"
	node.add_child(mi)
	var kits := MeshKitSet.new()
	match index % 4:
		0:
			ShrineProps.lantern(kits, Transform3D(Basis(), Vector3(size * 0.2, 0, -size * 0.1)), rng)
			var small: Node3D = ShrineWisteria.young(index, size * 0.02)
			small.position = Vector3(-size * 0.35, 0, size * 0.2)
			node.add_child(small)
		1:
			# where a pine stood
			var tree: Node3D = ShrineWisteria.young(index, size * 0.03)
			tree.rotation.y = rng.randf() * TAU
			node.add_child(tree)
		2:
			ShrineProps.pillar(kits, Transform3D(Basis(), Vector3(size * 0.2, 0, 0)), 3.0, true, rng)
	kits.finish(node, props, ShrinePlatform.NO_SHADOW)
	return node
