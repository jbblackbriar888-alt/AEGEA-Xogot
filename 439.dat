shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_opaque;
uniform sampler2D seabed : filter_linear, repeat_disable;
uniform float world_extent = 1400.0;
uniform vec3 shallow : source_color = vec3(0.085,0.43,0.43);
uniform vec3 deep : source_color = vec3(0.012,0.095,0.17);
varying vec3 world_pos;
void vertex(){
 world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 float a=sin(world_pos.x*0.12+world_pos.z*0.07+TIME*1.2);
 float b=sin(world_pos.x*0.19-world_pos.z*0.11+TIME*1.5);
 VERTEX.y+=a*0.1+b*0.045;
}
void fragment(){
 vec2 uv=world_pos.xz/(world_extent*2.0)+0.5;
 float height=texture(seabed,uv).r*100.0-50.0;
 float depth=max(0.0,-height);
 if(height>0.45){discard;}
 float wave=sin(world_pos.x*0.32+TIME*1.5)*sin(world_pos.z*0.24-TIME);
 float foam=(1.0-smoothstep(0.3,2.5,depth))*(0.35+0.65*smoothstep(0.0,0.6,sin(depth*4.0-TIME*1.8+wave)));
 ALBEDO=mix(mix(shallow,deep,smoothstep(0.2,16.0,depth)),vec3(0.78,0.9,0.87),foam*0.65);
 NORMAL_MAP=normalize(vec3(sin(world_pos.x*1.6+TIME*1.5)*0.12,sin(world_pos.z*1.7+TIME)*0.12,1.0))*0.5+0.5;
 NORMAL_MAP_DEPTH=0.45;
 ROUGHNESS=0.16+foam*0.35;
 METALLIC=0.12;
 SPECULAR=0.9;
 ALPHA=mix(0.25,0.96,smoothstep(0.0,3.0,depth));
}
