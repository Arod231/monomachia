// Shared by the camera-facing particle shaders (particle_glow and
// particle_flake): turning a quad to face the camera, and fading it out as
// it nears the camera.

// The model-view matrix that turns a quad at the model's origin to face the
// camera, keeping the model's (or the particle's) scale.
mat4 billboard_modelview(mat4 view, mat4 inv_view, mat4 model) {
	mat4 facing = mat4(inv_view[0], inv_view[1], inv_view[2], model[3]);
	return view * facing * mat4(
		vec4(length(model[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(model[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(model[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}

// How much of a quad shows dist metres from the camera: none nearer than
// fade.x, all of it from fade.y, and all of it anywhere while fade.y is 0.
float near_fade_alpha(vec2 fade, float dist) {
	return fade.y > 0.0 ? smoothstep(fade.x, fade.y, dist) : 1.0;
}
