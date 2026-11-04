shader_type canvas_item;

// Slide the Swiss Alps in the late afternoon seen from high above down below
// the spaceships, and let the small mountain lakes ripple.
//
// NOTE (mristin):
// The mountains themselves are too heavy to draw on every frame on the weaker
// laptops, so PrerenderedGround draws one tile of them once with
// alps_tile.gdshader, and we only slide the tile here and wrap it around.

// How fast the mountains slide down, in pixels per second. The ground enemies
// slide at the same speed.
uniform float scroll_speed = 40.0;

// The tile of the mountains, drawn once by PrerenderedGround. Its alpha tells
// where the lakes are.
uniform sampler2D tile : filter_linear, repeat_enable;

// The height of the tile, in pixels; keep it the same as PERIOD in
// periodic_noise.gdshaderinc.
const float PERIOD = 4320.0;

// The ripple of the lakes as alps_tile.gdshader draws them.
const float LAKE_RIPPLE = 0.96;

varying vec2 local_position;

void vertex() {
    local_position = VERTEX;
}

void fragment() {
    vec2 p = local_position - vec2(0.0, TIME * scroll_speed);
    vec4 ground = texture(tile, vec2(p.x / 1920.0, p.y / PERIOD));
    vec3 color = ground.rgb;

    if (ground.a > 0.0) {
        float ripple = 0.92 + 0.08 * sin(p.y * 0.05 + p.x * 0.02 + TIME * 0.5);
        color *= mix(1.0, ripple / LAKE_RIPPLE, ground.a);
    }

    COLOR = vec4(color, 1.0);
}
