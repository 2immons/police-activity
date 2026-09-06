shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float stress_amount : hint_range(0.0, 1.0) = 0.0;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.72;
uniform float clear_center_radius : hint_range(0.1, 0.9) = 0.48;
uniform float vignette_softness : hint_range(0.05, 0.8) = 0.34;
uniform float edge_blur_lod : hint_range(0.0, 6.0) = 3.2;
uniform float desaturation : hint_range(0.0, 1.0) = 0.34;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 centered = (UV - vec2(0.5)) * vec2(1.0, SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y);
	float radius = length(centered) * 2.0;
	float edge = smoothstep(clear_center_radius, clear_center_radius + vignette_softness, radius);
	float strength = clamp(stress_amount + pulse, 0.0, 1.0);
	float blur_weight = edge * strength;
	vec3 sharp = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	vec3 blurred = textureLod(screen_texture, SCREEN_UV, edge_blur_lod * blur_weight).rgb;
	vec3 color = mix(sharp, blurred, blur_weight);
	float luminance = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(color, vec3(luminance), edge * strength * desaturation);
	color *= 1.0 - edge * strength * vignette_strength;
	COLOR = vec4(color, 1.0);
}
