shader_type canvas_item;

// Draw a sky kingdom at dusk seen from high above, drifting down below
// the spaceships: the far-away fields and rivers far below, the thin veils of
// haze, and the banks of clouds with the floating islands on top.
//
// NOTE (mristin):
// The sky itself is too heavy to draw on every frame on the weaker laptops,
// so PrerenderedGround draws one tile of each layer once, and we only slide
// the tiles here at their own speeds and wrap them around: the ground with
// sky_ground_tile.gdshader, the veils with sky_veil_tile.gdshader and
// the clouds with sky_cloud_tile.gdshader.

// How fast the clouds drift down, in pixels per second. The far-away ground
// drifts slower, and the ground enemies, if any, slide at this speed.
uniform float scroll_speed = 36.0;

uniform vec4 sky_color : source_color = vec4(0.05, 0.07, 0.18, 1.0);

// The tiles of the layers, drawn once by PrerenderedGround.
uniform sampler2D ground_tile : filter_linear, repeat_enable;
uniform sampler2D veil_tile : filter_linear, repeat_enable;
uniform sampler2D tile : filter_linear, repeat_enable;

// The height of the tiles, in pixels; keep it the same as PERIOD in
// periodic_noise.gdshaderinc.
const float PERIOD = 4320.0;

varying vec2 local_position;

vec2 uv_of(vec2 p) {
    return vec2(p.x / 1920.0, p.y / PERIOD);
}

void vertex() {
    local_position = VERTEX;
}

void fragment() {
    vec2 p = local_position - vec2(0.0, TIME * scroll_speed);

    // NOTE (mristin):
    // The ground is far below, so it drifts slower, and the thin veils of
    // haze drift a bit faster than the ground.
    vec2 far = local_position - vec2(0.0, TIME * scroll_speed * 0.35);
    vec3 color = texture(ground_tile, uv_of(far)).rgb;

    vec2 high = local_position - vec2(0.0, TIME * scroll_speed * 0.6);
    color = mix(color, sky_color.rgb * 1.3, texture(veil_tile, uv_of(high)).r);

    // The clouds and the islands darken the ground and cover it.
    vec4 clouds = texture(tile, uv_of(p));
    color = color * clouds.a + clouds.rgb;

    // A gentle evening glow from the top of the screen.
    float glow = smoothstep(500.0, 0.0, local_position.y);
    color += vec3(0.05, 0.02, 0.05) * glow;

    COLOR = vec4(color, 1.0);
}
