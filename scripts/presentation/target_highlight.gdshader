shader_type canvas_item;
render_mode blend_premul_alpha;

uniform vec4 highlight_color : source_color = vec4(1.0);
uniform float highlight_strength : hint_range(0.0, 1.0) = 0.0;
uniform bool source_premultiplied = false;

void fragment() {
	vec4 source = COLOR;
	vec3 tint = highlight_color.rgb * (source_premultiplied ? source.a : 1.0);
	source.rgb = mix(source.rgb, tint, highlight_strength);
	if (!source_premultiplied) {
		source.rgb *= source.a;
	}
	COLOR = source;
}
