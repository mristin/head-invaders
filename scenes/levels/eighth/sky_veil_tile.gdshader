shader_type canvas_item;

// Draw one tile of the thin, high veils of haze over the sky kingdom.
// PrerenderedGround draws the tile only once, and sky.gdshader slides it down
// a bit faster than the far-away ground.
//
// NOTE (mristin):
// The veils are big and soft, so we draw them at a quarter of the resolution;
// the tile is a quarter of the size of the other tiles in both directions.
// The tile repeats itself vertically after PERIOD, so all the noise wraps
// around after it. We put how much of the veil covers the point into red.

#include "res://scenes/levels/base/periodic_noise.gdshaderinc"

// How many times smaller the tile is than the screen.
const float SHRINK = 4.0;

varying vec2 local_position;

void vertex() {
    local_position = VERTEX;
}

void fragment() {
    vec2 p = local_position * SHRINK;
    float veil = fbm(p, 380.0, vec2(7.3), 5);
    COLOR = vec4(smoothstep(0.45, 0.75, veil) * 0.5, 0.0, 0.0, 1.0);
}
