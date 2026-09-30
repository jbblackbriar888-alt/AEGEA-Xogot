shader_type spatial;
render_mode cull_back;
uniform sampler2D sand_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D shore_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 biome_color : source_color = vec4(0.72,0.77,0.58,1.0);
uniform float volcanic = 0.0;
varying vec3 world_pos;
varying float slope;
void vertex(){
 world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 slope=1.0-NORMAL.y;
}
void fragment(){
 vec2 p=world_pos.xz;
 float macro=0.5+0.5*sin(p.x*0.025+sin(p.y*0.031))*cos(p.y*0.02);
 vec3 sand=texture(sand_tex,p*0.23).rgb;
 vec3 soil=mix(texture(soil_tex,p*0.17).rgb,texture(soil_tex,p.yx*0.041).rgb,0.24);
 vec3 rock=texture(rock_tex,p*0.14).rgb;
 vec3 shore=texture(shore_tex,p*0.38).rgb;
 float beach=1.0-smoothstep(1.8,5.5,world_pos.y+macro*1.2);
 vec3 land=mix(soil*biome_color.rgb*1.3,rock,smoothstep(0.08,0.32,slope));
 land=mix(land,rock*vec3(0.34,0.30,0.28),volcanic*0.72);
 ALBEDO=mix(land,mix(sand,shore,0.32),beach)*(0.88+macro*0.18);
 float wet=1.0-smoothstep(0.3,1.5,world_pos.y);
 ALBEDO*=1.0-wet*0.3;
 ROUGHNESS=mix(0.93,0.48,wet);
 NORMAL_MAP=texture(detail_normal,p*0.3).rgb;
 NORMAL_MAP_DEPTH=0.35;
}
