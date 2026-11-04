shader_type canvas_item;

// Slide the arctic sea in the polar night seen from high above down below
// the spaceships, with a faint glow of the northern lights over everything.
//
// NOTE (mristin):
// The ice itself is too heavy to draw on every frame on the weaker laptops,
// so PrerenderedGround draws one tile of it once with arctic_tile.gdshader,
// and we only slide the tile here, wrap it around, and add the northern
// lights, which drift.

// How fast the ice slides down, in pixels per second. The ground enemies
// slide at the same speed.
uniform float scroll_speed = 40.0;

uniform vec4 aurora_color : source_color = vec4(0.04, 0.14, 0.12, 1.0);

// The tile of the ice, drawn once by PrerenderedGround.
uniform sampler2D tile : filter_linear, repeat_enable;

// The height of the tile, in pixels; keep it the same as PERIOD in
// periodic_noise.gdshaderinc.
const float PERIOD = 4320.0;

varying vec2 local_position;

// NOTE (mristin):
// The northern lights are big and soft, so a few slow waves are plenty; we
// avoid the noise here, since we draw the lights on every frame.
float soft_wave(vec2 p, float t) {
    return 0.5 + 0.25 * sin(p.x * 1.7 + t * 1.3) * sin(p.y * 1.3 - t)
        + 0.25 * sin(p.x * 0.9 - p.y * 1.1 + t * 0.7);
}

void vertex() {
    local_position = VERTEX;
}

void fragment() {
    vec2 p = local_position - vec2(0.0, TIME * scroll_speed);
    vec3 color = texture(tile, vec2(p.x / 1920.0, p.y / PERIOD)).rgb;

    // NOTE (mristin):
    // The faint northern lights drift slowly over the whole sea.
    vec2 screen = local_position;
    float band = sin(screen.x / 420.0 + TIME * 0.07 + soft_wave(screen / 500.0, TIME * 0.02) * 3.0);
    float aurora = smoothstep(0.2, 1.0, band) * (0.6 + 0.4 * soft_wave(screen / 260.0 + 3.1, TIME * 0.03));
    color += aurora_color.rgb * aurora * 0.6;

    COLOR = vec4(color, 1.0);
}
