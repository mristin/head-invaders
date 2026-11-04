shader_type canvas_item;

// Draw one tile of the ocean seen from above: the deep water with darker
// patches of the sea grass far below. PrerenderedGround draws the tile only
// once, and ocean.gdshader slides it down below the spaceships and adds
// the swell and the shimmer.
//
// NOTE (mristin):
// The tile repeats itself vertically after OCEAN_PERIOD, so all the noise
// wraps around after it.

uniform vec4 deep_color : source_color = vec4(0.02, 0.08, 0.16, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.03, 0.14, 0.22, 1.0);
uniform vec4 grass_color : source_color = vec4(0.02, 0.1, 0.09, 1.0);

// The height of the tile, in pixels; keep it the same as in ocean.gdshader.
const float OCEAN_PERIOD = 4160.0;

varying vec2 local_position;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// Return the value noise which wraps around vertically after the period, in
// the units of the noise.
float value_noise(vec2 p, float period) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float y0 = mod(i.y, period);
    float y1 = mod(i.y + 1.0, period);
    return mix(
        mix(hash(vec2(i.x, y0)), hash(vec2(i.x + 1.0, y0)), u.x),
        mix(hash(vec2(i.x, y1)), hash(vec2(i.x + 1.0, y1)), u.x),
        u.y
    );
}

// Return the fractal noise of the water at the given scale in pixels, which
// must divide OCEAN_PERIOD.
float fbm(vec2 p, float scale) {
    float period = OCEAN_PERIOD / scale;
    vec2 q = p / scale;
    float sum = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 4; i++) {
        sum += amplitude * value_noise(q, period);
        q *= 2.0;
        period *= 2.0;
        amplitude *= 0.5;
    }
    return sum;
}

void vertex() {
    local_position = VERTEX;
}

void fragment() {
    vec2 p = local_position;

    float depth = fbm(p, OCEAN_PERIOD / 6.0);
    vec3 color = mix(deep_color.rgb, shallow_color.rgb, smoothstep(0.35, 0.7, depth));

    float grass = smoothstep(0.55, 0.75, fbm(p + vec2(1352.0, 0.0), 260.0));
    color = mix(color, grass_color.rgb, grass * 0.6);

    COLOR = vec4(color, 1.0);
}
