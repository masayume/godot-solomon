shader_type canvas_item;

uniform vec4 trail_color : source_color = vec4(5.0, 0.1, 0.1, 1.0);
uniform float softness : hint_range(0.0, 1.0) = 0.8;
uniform float trail_opacity : hint_range(0.0, 1.0) = 0.3; // New slider

void fragment() {
    float dist = distance(UV.y, 0.5);
    float mask = smoothstep(0.5, 0.5 - softness, dist);
    
    // UV.x = 1.0 at Eye, 0.0 at Tail
    float fade = UV.x; 
    
    vec4 final_color = trail_color;
    
    // Combine the shape mask, the length fade, and the master opacity
    final_color.a *= mask * fade * trail_opacity;
    
    COLOR = final_color;
}