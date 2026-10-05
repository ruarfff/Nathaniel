shader_type canvas_item;
render_mode unshaded;

uniform float warning : hint_range(0.0, 1.0) = 0.0;
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform bool disarmed = false;
uniform float corpse_seed = 0.0;

float patch_noise(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7)) + corpse_seed * 13.7) * 43758.5453);
}

void fragment() {
	vec4 source = COLOR;
	float luminance = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
	float seam = smoothstep(0.0, 0.10, source.g - max(source.r, source.b));
	if (disarmed) {
		source.rgb *= 1.0 - seam * 0.42;
	}
	float shell = smoothstep(0.10, 0.45, luminance);
	source.rgb = mix(source.rgb, vec3(0.81, 0.96, 0.42), warning * (0.38 * shell + 0.45 * seam));
	if (dissolve > 0.0) {
		vec2 cell = floor(UV * vec2(25.0, 25.0));
		float radius = clamp(length((cell / 25.0 - vec2(0.43, 0.67)) * vec2(1.65, 2.0)), 0.0, 1.0);
		float threshold = clamp(0.15 + (1.0 - radius) * 0.55 + patch_noise(cell) * 0.28, 0.02, 0.98);
		float edge = 1.0 - smoothstep(0.0, 0.055, threshold - dissolve);
		source.rgb = mix(source.rgb, vec3(0.74, 0.95, 0.27), edge * 0.86);
		source.a *= step(dissolve, threshold) * (1.0 - smoothstep(0.78, 1.0, dissolve));
	}
	COLOR = source;
}
