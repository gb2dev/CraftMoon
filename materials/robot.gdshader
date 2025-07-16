shader_type spatial;

uniform sampler2D albedo_texture;
uniform sampler2D tint_mask;
uniform vec4 tint_color : source_color;

void fragment() {
	vec4 albedo = texture(albedo_texture, UV);
	float mask_value = texture(tint_mask, UV).r;

	vec3 blended_color = mix(
	    albedo.rgb, 
	    albedo.rgb * tint_color.rgb, 
	    mask_value
	);

	ALBEDO = blended_color;
}