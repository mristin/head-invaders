shader_type canvas_item;

// Draw an arctic sea in the polar night, seen from high above, sliding down
// below the spaceships: the big ice floes covered with snow drifts and fine
// cracks, the dark water between them, and a faint glow of the northern
// lights over everything.
//
// NOTE (mristin):
// The snow is bright in real life, so we keep it dusky blue-grey here, so that
// the snowballs, the icicles and the snowflakes stand out. Nothing on the ice
// is small and bright, so that nobody mistakes it for a projectile.

// How fast the ice slides down, in pixels per second. The ground enemies
// slide at the same speed.
uniform float scroll_speed = 40.0;

uniform vec4 water_color : source_color = vec4(0.03, 0.06, 0.1, 1.0);
uniform vec4 deep_color : source_color = vec4(0.015, 0.03, 0.06, 1.0);
uniform vec4 ice_color : source_color = vec4(0.15, 0.19, 0.26, 1.0);
uniform vec4 snow_color : source_color = vec4(0.22, 0.26, 0.33, 1.0);
uniform vec4 aurora_color : source_color = vec4(0.04, 0.14, 0.12, 1.0);

// The size of the floes, in pixels.
uniform float floe_cell = 420.0;

varying vec2 local_position;

vec2 hash2(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453123);
}

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float value_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
        mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
        u.y
    );
}

float fbm(vec2 p) {
    float sum = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 4; i++) {
        sum += amplitude * value_noise(p);
        p *= 2.03;
        amplitude *= 0.5;
    }
    return sum;
}

// Return the distance to the nearest edge between the floes, in cells, and
// two random numbers of the floe.
vec3 floes(vec2 p) {
    vec2 g = floor(p);
    vec2 f = fract(p);
    vec2 nearest_cell = vec2(0.0);
    vec2 nearest_offset = vec2(0.0);
    float nearest = 8.0;
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            vec2 c = vec2(float(x), float(y));
            vec2 o = c + 0.15 + 0.7 * hash2(g + c) - f;
            float d = dot(o, o);
            if (d < nearest) {
                nearest = d;
                nearest_offset = o;
                nearest_cell = g + c;
            }
        }
    }
    float edge = 8.0;
    for (int x = -2; x <= 2; x++) {
        for (int y = -2; y <= 2; y++) {
            vec2 c = vec2(float(x), float(y));
            vec2 o = c + 0.15 + 0.7 * hash2(g + c) - f;
            vec2 diff = o - nearest_offset;
            if (dot(diff, diff) > 0.0001) {
                edge = min(edge, dot(0.5 * (nearest_offset + o), normalize(diff)));
            }
        }
    }
    return vec3(edge, hash(nearest_cell), hash(nearest_cell + 4.2));
}

void vertex() {
    local_position = VERTEX;
}

void fragment() {
    vec2 p = local_position - vec2(0.0, TIME * scroll_speed);

    // NOTE (mristin):
    // The edges of the floes wobble a little, so that they look like ice, not
    // like tiles.
    vec2 wobble = vec2(fbm(p / 140.0), fbm(p / 140.0 + 5.3)) - 0.5;
    vec3 floe = floes(p / floe_cell + wobble * 0.35);
    float edge_px = floe.x * floe_cell;

    // The water: dark, with slow, soft ripples.
    float ripple = fbm(p / 70.0 + vec2(TIME * 0.05, 0.0));
    vec3 color = mix(deep_color.rgb, water_color.rgb, ripple);

    // Some cells are open water; the others are floes, with gaps of different
    // widths between them.
    float open_water = step(floe.y, 0.22);
    float gap = mix(10.0, 45.0, floe.z * floe.z);
    float on_ice = (1.0 - open_water) * smoothstep(gap, gap + 5.0, edge_px);

    // The snow on the floe: soft drifts, the rim of bare ice, and the cracks.
    float drift = fbm(p / 160.0 + floe.y * 9.0);
    vec3 ice = mix(ice_color.rgb, snow_color.rgb, smoothstep(0.35, 0.75, drift));
    ice *= 0.93 + 0.1 * fbm(p / 35.0);
    // Some floes are snow fields, some bare, bluer ice.
    ice = mix(ice * vec3(0.8, 0.88, 1.0), ice, smoothstep(0.3, 0.7, floe.y));
    float rim = smoothstep(gap + 30.0, gap + 5.0, edge_px);
    ice = mix(ice, ice_color.rgb * 0.85, rim * 0.6);
    float crack_line = abs(fbm(p / 220.0 + floe.z * 7.0) - 0.5);
    float crack = smoothstep(0.012, 0.0, crack_line) * step(0.45, floe.z);
    ice = mix(ice, water_color.rgb * 1.6, crack * 0.6);

    // The shadow of the floe on the water, to the lower right.
    vec3 shadow_floe = floes((p - vec2(10.0, 12.0)) / floe_cell + wobble * 0.35);
    float shadow = (1.0 - step(shadow_floe.y, 0.22))
        * smoothstep(gap, gap + 8.0, shadow_floe.x * floe_cell);
    color *= 1.0 - 0.35 * shadow;

    color = mix(color, ice, on_ice);

    // NOTE (mristin):
    // The faint northern lights drift slowly over the whole sea.
    vec2 screen = local_position;
    float band = sin(screen.x / 420.0 + TIME * 0.07 + fbm(screen / 500.0 + TIME * 0.02) * 3.0);
    float aurora = smoothstep(0.2, 1.0, band) * (0.6 + 0.4 * fbm(screen / 260.0 + TIME * 0.03));
    color += aurora_color.rgb * aurora * 0.6;

    COLOR = vec4(color, 1.0);
}
