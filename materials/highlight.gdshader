shader_type spatial;
render_mode unshaded, depth_draw_never;

void fragment( )
{
	ALBEDO = vec3(1.0, 1.0, 1.0);
	ALPHA = (sin(TIME * 2.5) + 1.0) * 0.02;
}
