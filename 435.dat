shader_type spatial;
render_mode cull_disabled;
uniform vec4 cloth_color : source_color = vec4(0.76,0.70,0.53,1);
uniform float strength=0.12;
uniform float motion=0.0;
uniform sampler2D cloth_texture : source_color, filter_linear_mipmap;
uniform bool use_texture=false;
uniform float damage=0.0;
void vertex(){
 float free_edge=UV.y*UV.y;
 VERTEX.z+=sin(TIME*2.5+VERTEX.x*3.8+UV.y*3.0)*strength*free_edge;
 VERTEX.x+=sin(TIME*1.9+UV.y*5.0)*strength*0.3*free_edge;
 VERTEX.z+=motion*free_edge*0.06;
}
void fragment(){
 float weave=sin(UV.x*800.0)*sin(UV.y*650.0)*0.025;
 vec3 base=cloth_color.rgb;
 if(use_texture) base*=texture(cloth_texture,UV).rgb;
 float tear=sin(UV.x*31.0+sin(UV.y*19.0))*sin(UV.y*27.0);
 if(damage>0.25 && UV.y>0.3 && tear>1.0-damage*0.45) discard;
 ALBEDO=base*(0.96+weave)*(1.0-damage*0.28);
 ROUGHNESS=0.95;
}
