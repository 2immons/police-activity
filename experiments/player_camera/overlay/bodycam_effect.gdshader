shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float lens_distortion = 0.055;
uniform float vignette_strength = 0.16;
uniform float sensor_noise = 0.012;
uniform float chromatic_aberration = 0.00045;
uniform float saturation = 0.88;
uniform float contrast = 1.04;
uniform float exposure = 1.0;
uniform float compression_strength = 0.10;
uniform float motion_smear = 0.35;
uniform float rolling_shutter = 0.0015;
uniform float noise_refresh_rate = 30.0;
uniform vec2 turn_velocity = vec2(0.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
void fragment() {
	vec2 p = SCREEN_UV - vec2(0.5);
	float radius = dot(p, p);
	// Keep the centre of aim fixed; curve the periphery without moving gameplay rays.
	vec2 uv = vec2(0.5) + p * (1.0 + lens_distortion * radius) / (1.0 + lens_distortion * 0.5);
	vec2 motion = clamp(turn_velocity, vec2(-2.0), vec2(2.0));
	uv.x += motion.x * rolling_shutter * (SCREEN_UV.y - 0.5);
	uv = clamp(uv, vec2(0.001), vec2(0.999));
	vec2 smear = motion * motion_smear * 0.002;
	vec3 colour = textureLod(screen_texture, uv, 0.0).rgb * 0.60;
	colour += textureLod(screen_texture, clamp(uv + smear, vec2(0.001), vec2(0.999)), 0.0).rgb * 0.20;
	colour += textureLod(screen_texture, clamp(uv - smear, vec2(0.001), vec2(0.999)), 0.0).rgb * 0.20;
	vec2 fringe = p * chromatic_aberration * radius * 4.0;
	colour.r = mix(colour.r, textureLod(screen_texture, uv + fringe, 0.0).r, 0.5);
	colour.b = mix(colour.b, textureLod(screen_texture, uv - fringe, 0.0).b, 0.5);
	float luminance = dot(colour, vec3(0.2126, 0.7152, 0.0722));
	colour = mix(vec3(luminance), colour, saturation);
	colour = (colour - vec3(0.5)) * contrast + vec3(0.5);
	colour *= exposure * (1.0 - vignette_strength * smoothstep(0.06, 0.46, radius));
	// Modest sensor noise, stronger in shadows; no analogue scanlines/VHS artifacts.
	float frame = floor(TIME * noise_refresh_rate);
	float grain = hash(floor(SCREEN_UV / SCREEN_PIXEL_SIZE) + vec2(frame, frame * 0.37)) - 0.5;
	colour += vec3(grain * sensor_noise * (1.5 - clamp(luminance, 0.0, 1.0)));
	vec3 quantized = floor(clamp(colour, 0.0, 1.0) * 127.0 + 0.5) / 127.0;
	colour = mix(colour, quantized, compression_strength);
	COLOR = vec4(clamp(colour, 0.0, 1.0), 1.0);
}
