// A spark (CombatEffects' sparks, milestone-1 task 37): a hot streak drawn
// along its flight, as a fast speck of burning steel smears across a frame.
// Each instance's transform gives the streak: its X axis the streak itself
// in world space (from its tail to its head, as long as the spark moved in
// a short exposure), the length of its Y axis the streak's width, its origin
// the streak's middle. The quad turns about the streak to face the camera.
// The instance colour (COLOR) is the spark's heat, white-yellow cooling to
// orange and red, its alpha the fade; energy pushes it into the bloom.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float energy = 6.0;

void vertex() {
	vec3 axis = MODEL_MATRIX[0].xyz;
	float width = length(MODEL_MATRIX[1].xyz);
	vec3 centre = MODEL_MATRIX[3].xyz;
	vec3 to_camera = normalize(CAMERA_POSITION_WORLD - centre);
	vec3 side = cross(axis, to_camera);
	float side_length = length(side);
	// a streak seen end on draws as a dot of its width
	side = side_length > 1e-6 ? side / side_length : normalize(cross(vec3(0.0, 1.0, 0.0), to_camera) + vec3(1e-4, 0.0, 0.0));
	vec3 world = centre + axis * VERTEX.x + side * width * VERTEX.y;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	// hottest at the head (UV.x 1), thin and soft across
	float across = 1.0 - abs(UV.y - 0.5) * 2.0;
	float core = smoothstep(0.0, 0.8, across);
	float along = mix(0.25, 1.0, UV.x) * smoothstep(0.0, 0.15, UV.x) * (1.0 - smoothstep(0.92, 1.0, UV.x) * 0.5);
	ALBEDO = COLOR.rgb * energy * (0.6 + 0.4 * core);
	ALPHA = COLOR.a * core * along;
}
