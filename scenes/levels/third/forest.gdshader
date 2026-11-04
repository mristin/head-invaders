shader_type canvas_item;

// Slide the forest seen from high above down below the spaceships, and let
// the river ripple softly.
//
// NOTE (mristin):
// The forest itself is too heavy to draw on every frame on the weaker
// laptops, so PrerenderedGround draws one tile of it once with
// forest_tile.gdshader, and we only slide the tile here and wrap it around.

#include "res://scenes/levels/third/forest_common.gdshaderinc"

// How fast the ground slides down, in pixels per second. The ground enemies
// slide at the same speed.
uniform float scroll_speed = 50.0;

// The tile of the forest, drawn once by PrerenderedGround.
uniform sampler2D tile : filter_linear, repeat_enable;

varying vec2 local_position;

void vertex() {
    local_position = VERTEX;
}

void fragment() {
    vec2 p = local_position - vec2(0.0, TIME * scroll_speed);
    vec3 color = texture(tile, vec2(p.x / 1920.0, p.y / FOREST_PERIOD)).rgb;

    // NOTE (mristin):
    // The river ripples slowly. The tile draws the river as if the ripple were
    // halfway, so we brighten and darken around that.
    float river_distance = abs(p.x - river_x(p.y));
    if (river_distance < 68.0) {
        float river = smoothstep(68.0, 58.0, river_distance);
        float ripple = 0.5 + 0.5 * sin(p.y * 0.05 + sin(p.x * 0.04) * 2.0 + TIME * 0.8);
        color *= mix(1.0, (0.85 + 0.25 * ripple) / 0.975, river);
    }

    COLOR = vec4(color, 1.0);
}
