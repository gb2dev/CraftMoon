shader_type spatial;
render_mode unshaded, depth_draw_never;

uniform float intensity = 0.02;
uniform float speed = 2.5;

void fragment( )
{
	ALBEDO = vec3(1.0, 1.0, 1.0);
	ALPHA = (sin(TIME * speed) + 1.0) * intensity;
}
