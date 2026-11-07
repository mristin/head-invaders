shader_type canvas_item;

// Draw one tile of the far-away ground below the sky kingdom: a patchwork of
// fields with a winding river, faded by the haze of the dusk into the deep
// blue sky. PrerenderedGround draws the tile only once, and sky.gdshader
// slides it down, slower than the clouds, since it is far below.
//
// NOTE (mristin):
// The tile repeats itself vertically after PERIOD, so all the noise wraps
// around after it.

#include "res://scenes/levels/base/periodic_noise.gdshaderinc"

uniform vec4 sky_color : source_color = vec4(0.05, 0.07, 0.18, 1.0);
uniform vec4 field_color : source_color = vec4(0.07, 0.13, 0.15, 1.0);
uniform vec4 field_alt_color : source_color = vec4(0.1, 0.11, 0.2, 1.0);
uniform vec4 river_color : source_color = vec4(0.14, 0.17, 0.32, 1.0);

varying vec2 local_position;

void vertex() {
    local_position = VERTEX;
}

void fragment() {
    vec2 p = local_position;

    vec2 field_size = vec2(160.0, wrap_cell(110.0));
    vec2 field = floor((p + vec2(fbm(p, 300.0, vec2(0.0), 5) * 60.0, 0.0)) / field_size);
    vec3 color = mix(
        field_color.rgb, field_alt_color.rgb, hash(wrap_index(field, field_size.y))
    );
    color *= 0.85 + 0.25 * fbm(p, 40.0, vec2(0.0), 5);
    float river = abs(
        p.x - 900.0 - sin(p.y * wrap_frequency(1.0 / 420.0)) * 380.0
        - fbm(p, 250.0, vec2(0.0), 5) * 260.0
    );
    color = mix(color, river_color.rgb, smoothstep(26.0, 18.0, river));

    COLOR = vec4(mix(color, sky_color.rgb, 0.45), 1.0);
}
