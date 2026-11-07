shader_type canvas_item;

// Slide the desert at dusk seen from high above down below the spaceships,
// and let the ponds of the oases shimmer.
//
// NOTE (mristin):
// The desert itself is too heavy to draw on every frame on the weaker
// laptops, so PrerenderedGround draws one tile of it once with
// desert_tile.gdshader, and we only slide the tile here and wrap it around.

// How fast the sand slides down, in pixels per second. The ground enemies
// slide at the same speed.
uniform float scroll_speed = 40.0;

// The tile of the desert, drawn once by PrerenderedGround. Its alpha tells
// where the ponds are.
uniform sampler2D tile : filter_linear, repeat_enable;

// The height of the tile, in pixels; keep it the same as PERIOD in
// periodic_noise.gdshaderinc.
const float PERIOD = 4320.0;

// The shimmer of the ponds as desert_tile.gdshader draws them.
const float POND_SHIMMER = 0.9;

varying vec2 local_position;

void vertex() {
    local_position = VERTEX;
}

void fragment() {
    vec2 p = local_position - vec2(0.0, TIME * scroll_speed);
    vec4 ground = texture(tile, vec2(p.x / 1920.0, p.y / PERIOD));
    vec3 color = ground.rgb;

    if (ground.a > 0.0) {
        float shimmer = 0.9 + 0.1 * sin(p.x * 0.02 + p.y * 0.03 + TIME * 0.6);
        color *= mix(1.0, shimmer / POND_SHIMMER, ground.a);
    }

    COLOR = vec4(color, 1.0);
}
