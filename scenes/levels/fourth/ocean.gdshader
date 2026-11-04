shader_type canvas_item;

// Slide the ocean seen from above down below the spaceships: the deep water
// with the sea grass far below, the slow swell, and the faint, shimmering
// network of the sunlight on the sea floor.
//
// NOTE (mristin):
// We keep the ocean dark and calm, so that the bubbles, the ink and the sparks
// stand out. The shimmer is faint and large, so that nobody mistakes it for
// a projectile.
//
// The water and the sea grass are too heavy to draw on every frame on
// the weaker laptops, so PrerenderedGround draws one tile of them once with
// ocean_tile.gdshader, and we only slide the tile here, wrap it around, and
// add the swell and the shimmer, which move. The shimmer is still too heavy
// to compute for every pixel, so another PrerenderedGround draws one period of
// it on every frame into a small tile with ocean_caustic_tile.gdshader, and
// we stretch that tile over the screen.

// How fast the water slides down, in pixels per second. The alligators and
// the clams drift at the same speed.
uniform float scroll_speed = 40.0;

uniform vec4 shimmer_color : source_color = vec4(0.35, 0.6, 0.7, 1.0);
uniform float shimmer_strength : hint_range(0.0, 1.0) = 0.12;

// The size of the shimmer's network, in pixels.
uniform float shimmer_scale = 520.0;

// The tile of the water, drawn once by PrerenderedGround.
uniform sampler2D tile : filter_linear, repeat_enable;

// One period of the shimmer, drawn on every frame by PrerenderedGround.
uniform sampler2D caustic_tile : filter_linear, repeat_enable;

// The height of the tile, in pixels; keep it the same as in ocean_tile.gdshader.
const float OCEAN_PERIOD = 4160.0;

varying vec2 local_position;

void vertex() {
    local_position = VERTEX;
}

void fragment() {
    vec2 p = local_position - vec2(0.0, TIME * scroll_speed);
    vec3 color = texture(tile, vec2(p.x / 1920.0, p.y / OCEAN_PERIOD)).rgb;

    // NOTE (mristin):
    // The swell slowly brightens and darkens the water in broad bands.
    float swell = sin(p.y / 140.0 + sin(p.x / 300.0 + TIME * 0.3) * 1.5 + TIME * 0.5);
    color *= 0.95 + 0.05 * swell;

    float caustic = texture(caustic_tile, p / shimmer_scale).r;
    color += shimmer_color.rgb * caustic * shimmer_strength;

    COLOR = vec4(color, 1.0);
}
