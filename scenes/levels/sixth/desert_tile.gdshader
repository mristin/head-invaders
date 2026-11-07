shader_type canvas_item;

// We keep the alpha raw, since it carries the ponds, not the coverage.
render_mode blend_disabled;

// Draw one tile of a desert at dusk seen from high above: the long dunes with
// their lit and shaded sides, the fine ripples of the wind in the sand, now
// and then an oasis with its pond and palms, and the old walls of the ruins,
// half buried in the sand. PrerenderedGround draws the tile only once, and
// desert.gdshader slides it down below the spaceships and lets the ponds
// shimmer.
//
// NOTE (mristin):
// We keep the desert dim and calm, so that the needles, the sand balls and
// the twisters stand out. Nothing in the desert is small and bright, so that
// nobody mistakes it for a projectile.
//
// The tile repeats itself vertically after PERIOD, so all the noise wraps
// around after it. The alpha tells desert.gdshader where the ponds are.

#include "res://scenes/levels/base/periodic_noise.gdshaderinc"

uniform vec4 shade_color : source_color = vec4(0.15, 0.1, 0.06, 1.0);
uniform vec4 sand_color : source_color = vec4(0.24, 0.16, 0.09, 1.0);
uniform vec4 lit_color : source_color = vec4(0.33, 0.23, 0.13, 1.0);
uniform vec4 water_color : source_color = vec4(0.04, 0.12, 0.14, 1.0);
uniform vec4 palm_color : source_color = vec4(0.07, 0.14, 0.07, 1.0);
uniform vec4 stone_color : source_color = vec4(0.2, 0.15, 0.11, 1.0);

// The size of the grid in which we place the oases and the ruins, in pixels.
uniform float site_cell = 1100.0;

// The shimmer of the ponds as we draw them here; desert.gdshader brightens
// and darkens around it.
const float POND_SHIMMER = 0.9;

varying vec2 local_position;

// Return the height of the dunes: long, wavy crests across the screen, with
// a gentle windward slope and a steeper lee side.
float dunes(vec2 p) {
    vec2 q = p + vec2(
        fbm(p, 900.0, vec2(0.0), 4) * 500.0,
        fbm(p, 700.0, vec2(3.7), 4) * 260.0
    );
    float phase = q.y / wrap_cell(330.0) + q.x / 1400.0;
    float saw = fract(phase);
    float crest = smoothstep(0.0, 0.7, saw) * smoothstep(1.0, 0.7, saw);
    return crest * (0.7 + 0.3 * fbm(p, 500.0, vec2(9.1), 4));
}

// Return how much of an oasis covers the point: the pond and the palms around
// it, as (pond, palm).
vec2 oasis(vec2 p, vec2 site, float seed) {
    vec2 d = p - site;
    float angle = atan(d.y, d.x);
    float pond_r = 130.0 + 50.0 * seed;
    float wobble = pond_r * (1.0 + 0.12 * sin(angle * 3.0 + seed * 9.0));
    float pond = smoothstep(wobble, wobble - 10.0, length(d * vec2(1.0, 1.4)));

    float palm = 0.0;
    for (int i = 0; i < 5; i++) {
        float a = seed * 6.28 + float(i) * 1.3;
        vec2 center = site + vec2(cos(a), sin(a) * 0.75) * (pond_r + 70.0);
        vec2 e = p - center;
        float ea = atan(e.y, e.x);
        // NOTE (mristin):
        // A palm from above is a star of broad, soft fronds.
        float fronds = 55.0 * (0.65 + 0.35 * cos(ea * 6.0 + float(i)));
        palm = max(palm, smoothstep(fronds, fronds - 8.0, length(e)));
    }
    return vec2(pond, palm);
}

// Return how much of the old walls covers the point.
float ruins(vec2 p, vec2 site, float seed) {
    vec2 d = p - site;
    float c = cos(seed * 1.2 - 0.6);
    float s = sin(seed * 1.2 - 0.6);
    d = vec2(c * d.x - s * d.y, s * d.x + c * d.y);

    float walls = 0.0;
    // The outer walls of a square courtyard and an inner room.
    vec2 outer = abs(d) - vec2(220.0, 170.0);
    walls = max(walls, smoothstep(14.0, 10.0, abs(max(outer.x, outer.y))));
    vec2 inner = abs(d - vec2(90.0, -40.0)) - vec2(70.0, 60.0);
    walls = max(walls, smoothstep(12.0, 8.0, abs(max(inner.x, inner.y))));

    // NOTE (mristin):
    // The sand covers the walls here and there.
    walls *= smoothstep(0.42, 0.55, fbm(p, 90.0, vec2(seed * 7.0), 4));
    return walls;
}

void vertex() {
    local_position = VERTEX;
}

void fragment() {
    vec2 p = local_position;

    // NOTE (mristin):
    // The low sun comes from the upper left, so the dunes have a lit and
    // a shaded side.
    float h = dunes(p);
    float hx = dunes(p + vec2(4.0, 0.0)) - h;
    float hy = dunes(p + vec2(0.0, 4.0)) - h;
    vec3 normal = normalize(vec3(-hx * 35.0, -hy * 35.0, 1.0));
    float light = dot(normal, normalize(vec3(-0.5, -0.6, 0.6)));
    vec3 color = mix(shade_color.rgb, sand_color.rgb, smoothstep(-0.1, 0.8, light));
    color = mix(color, lit_color.rgb, smoothstep(0.75, 1.0, light) * 0.8);
    color *= 0.92 + 0.12 * h;

    // The fine ripples of the wind, faint and soft.
    float ripple = sin(
        p.y * wrap_frequency(0.09) + p.x * 0.025 + fbm(p, 160.0, vec2(0.0), 4) * 6.0
    );
    color *= 0.97 + 0.03 * ripple;
    color *= 0.94 + 0.1 * fbm(p, 45.0, vec2(0.0), 4);

    float pond_cover = 0.0;
    float cell_size = wrap_cell(site_cell);
    vec2 cell = floor(p / cell_size);
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            vec2 c = cell + vec2(float(x), float(y));
            vec2 k = wrap_index(c, cell_size);
            float kind = hash(k + 3.3);
            vec2 site = (c + 0.3 + 0.4 * vec2(hash(k + 1.1), hash(k + 7.7))) * cell_size;
            float seed = hash(k + 5.9);
            if (kind < 0.2) {
                vec2 o = oasis(p, site, seed);
                float bank = smoothstep(0.0, 1.0, o.x) * (1.0 - o.x);
                color = mix(color, color * 0.75 + vec3(0.0, 0.02, 0.0), smoothstep(0.0, 1.0,
                    1.0 - length((p - site) * vec2(1.0, 1.4)) / 320.0) * 0.6);
                color = mix(color, water_color.rgb * POND_SHIMMER, o.x);
                color = mix(color, color * 0.55, bank);
                // The shadows of the palms, then the palms.
                vec2 shade = oasis(p - vec2(12.0, 14.0), site, seed);
                color *= 1.0 - shade.y * 0.4 * (1.0 - o.y);
                color = mix(
                    color,
                    palm_color.rgb * (0.85 + 0.3 * value_noise(p, 10.0, vec2(0.0))),
                    o.y
                );
                pond_cover = max(pond_cover, o.x * (1.0 - o.y));
            } else if (kind < 0.38) {
                float shadow = ruins(p - vec2(8.0, 10.0), site, seed);
                color *= 1.0 - 0.35 * shadow;
                color = mix(
                    color,
                    stone_color.rgb * (0.9 + 0.2 * value_noise(p, 12.0, vec2(0.0))),
                    ruins(p, site, seed)
                );
            }
        }
    }

    COLOR = vec4(color, pond_cover);
}
