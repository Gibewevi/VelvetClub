shader_type canvas_item;
// Pixel-art recolouring: the sprite stores a palette index in its red
// channel (index * index_scale); the palette texture is one row of colours.
// Optional 1 px selection outline (alone with outline_only, for furniture
// drawn in parts) and a flat tint for placement previews.

uniform sampler2D palette : filter_nearest, repeat_disable;
uniform float index_scale = 4.0;
uniform float palette_size = 64.0;
uniform bool indexed = true;
uniform vec4 outline_color : source_color = vec4(0.0);
uniform vec4 tint : source_color = vec4(0.0);
uniform bool outline_only = false;
varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

vec4 resolve(vec4 t) {
	if (!indexed) {
		return t;
	}
	float idx = floor(t.r * 255.0 / index_scale + 0.5);
	vec3 c = texture(palette, vec2((idx + 0.5) / palette_size, 0.5)).rgb;
	return vec4(c, t.a);
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	vec4 c = resolve(t);
	if (outline_color.a > 0.0 && t.a < 0.5) {
		vec2 px = TEXTURE_PIXEL_SIZE;
		// Trace solid pixels only: adding four translucent shadow samples
		// would paint an opaque selection plate over floor stains.
		float a = step(0.5, texture(TEXTURE, UV + vec2(px.x, 0.0)).a) + step(0.5, texture(TEXTURE, UV - vec2(px.x, 0.0)).a)
			+ step(0.5, texture(TEXTURE, UV + vec2(0.0, px.y)).a) + step(0.5, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
		if (a > 0.5) {
			c = outline_color;
		}
	} else if (outline_only) {
		c = vec4(0.0);
	}
	if (tint.a > 0.0 && c.a > 0.5) {
		c.rgb = mix(c.rgb, tint.rgb, tint.a);
	}
	COLOR = c * modulate;
}
