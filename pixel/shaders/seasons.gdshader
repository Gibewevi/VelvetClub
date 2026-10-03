shader_type canvas_item;

uniform sampler2D leaf_mask : filter_nearest, repeat_disable;
uniform sampler2D winter_texture : filter_nearest, repeat_disable;
uniform sampler2D snow_texture : filter_nearest, repeat_disable;
uniform int kind = 0; // 0 lawn, 1 tree, 2 shrub/planter, 3 pit
uniform float autumn = 0.0;
uniform float leaf_loss = 0.0;
uniform float snow = 0.0;
varying vec4 modulation;

void vertex() { modulation = COLOR; }

vec3 warm(vec3 c, float variation) {
	float light = dot(c,vec3(.25,.6,.15));
	vec3 dark = variation > .45 ? vec3(.27,.06,.055) : vec3(.25,.11,.055);
	vec3 mid = variation > .45 ? vec3(.72,.18,.07) : vec3(.86,.39,.055);
	vec3 bright = variation > .45 ? vec3(1.0,.53,.13) : vec3(1.0,.78,.22);
	return light < .37 ? mix(dark,mid,clamp(light/.37,0.0,1.0)) : mix(mid,bright,clamp((light-.37)/.48,0.0,1.0));
}

void fragment() {
	vec4 base = texture(TEXTURE,UV);
	vec4 mask = texture(leaf_mask,UV);
	if (kind == 0) {
		// The meadow dries gently; autumn is never a flat orange carpet.
		base.rgb = mix(base.rgb,base.rgb*vec3(1.18,.91,.72),autumn*.65);
		base = mix(base,texture(snow_texture,UV),snow);
	} else if (kind == 1) {
		base.rgb = mix(base.rgb,warm(base.rgb,mask.b),autumn*mask.r);
		float drop = smoothstep(mask.g-.055,mask.g+.055,leaf_loss)*mask.r;
		if (leaf_loss <= 0.0) drop = 0.0;
		if (leaf_loss >= 1.0) drop = mask.r;
		base.a *= 1.0-drop;
		// Fully dormant trees use the complete bare silhouette, without
		// retaining isolated dark canopy outlines or two overlapping trunks.
		base.a *= 1.0-smoothstep(.82,1.0,leaf_loss)*(1.0-mask.r);
		vec4 under = mix(texture(winter_texture,UV),texture(snow_texture,UV),snow);
		under.a *= smoothstep(0.0,.3,leaf_loss);
		float alpha = base.a+under.a*(1.0-base.a);
		vec3 rgb = (base.rgb*base.a+under.rgb*under.a*(1.0-base.a))/max(alpha,.0001);
		base = vec4(rgb,alpha);
	} else {
		base.rgb = mix(base.rgb,warm(base.rgb,mask.b),autumn*mask.r);
		base.rgb = mix(base.rgb,base.rgb*vec3(.67,.78,.87),leaf_loss*mask.r*.65);
		vec4 cap = texture(snow_texture,UV);
		base.rgb = mix(base.rgb,cap.rgb,snow*cap.a);
		base.a = max(base.a,snow*cap.a);
	}
	COLOR = base*modulation;
}
