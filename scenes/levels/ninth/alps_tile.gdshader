shader_type canvas_item;

// We keep the alpha raw, since it carries the lakes, not the coverage.
render_mode blend_disabled;

// Draw one tile of the Swiss Alps in the late afternoon, seen from high
// above: the green alpine meadows in the valleys, the dark pine forests on
// the slopes, the grey rocky ridges, the snowy peaks and the glaciers up high,
// a pass road winding through the valley, and now and then a small mountain
// lake. PrerenderedGround draws the tile only once, and alps.gdshader slides
// it down below the spaceships and lets the lakes ripple.
//
// NOTE (mristin):
// We keep the mountains dim and muted, so that the notes, the snowballs and
// the pine cones stand out. The snow is tinted blue-grey and shaded, and
// nothing in the mountains is small and bright, so that nobody mistakes it for
// a projectile.
//
// The tile repeats itself vertically after PERIOD, so all the noise wraps
// around after it. The alpha tells alps.gdshader where the lakes are.

#include "res://scenes/levels/base/periodic_noise.gdshaderinc"

uniform vec4 meadow_color : source_color = vec4(0.17, 0.25, 0.11, 1.0);
uniform vec4 meadow_lit_color : source_color = vec4(0.25, 0.32, 0.13, 1.0);
uniform vec4 forest_color : source_color = vec4(0.06, 0.12, 0.08, 1.0);
uniform vec4 rock_color : source_color = vec4(0.24, 0.23, 0.23, 1.0);
uniform vec4 snow_color : source_color = vec4(0.32, 0.36, 0.43, 1.0);
uniform vec4 shade_color : source_color = vec4(0.06, 0.07, 0.11, 1.0);
uniform vec4 water_color : source_color = vec4(0.05, 0.13, 0.19, 1.0);
uniform vec4 road_color : source_color = vec4(0.3, 0.27, 0.22, 1.0);

// The size of the grid in which we place the lakes, in pixels.
uniform float lake_cell = 1300.0;

// The ripple of the lakes as we draw them here; alps.gdshader brightens and
// darkens around it.
const float LAKE_RIPPLE = 0.96;

varying vec2 local_position;

// Return the x of the pass road at the given height, winding along
// the valley.
float road_x(float y) {
    return 960.0 + 420.0 * sin(y * wrap_frequency(1.0 / 520.0))
        + 160.0 * sin(y * wrap_frequency(1.0 / 190.0) + 1.3);
}

// Return the height of the mountains, from 0 in the valley to about 1 on
// the peaks. The valley follows the pass road, so the road stays low.
float height(vec2 p) {
    // NOTE (mristin):
    // The ridges are sharper than the plain noise: we fold the noise.
    float ridges = 1.0 - abs(fbm(p, 620.0, vec2(0.0), 5) * 2.0 - 1.0);
    float h = 0.55 * ridges * ridges + 0.55 * fbm(p, 380.0, vec2(4.1), 5);
    float valley = smoothstep(120.0, 620.0, abs(p.x - road_x(p.y)));
    return h * (0.35 + 0.65 * valley);
}

void vertex() {
    local_position = VERTEX;
}

void fragment() {
    vec2 p = local_position;

    float h = height(p);
    float hx = height(p + vec2(3.0, 0.0)) - h;
    float hy = height(p + vec2(0.0, 3.0)) - h;
    vec3 normal = normalize(vec3(-hx * 90.0, -hy * 90.0, 1.0));
    // NOTE (mristin):
    // The low afternoon sun comes from the upper right.
    float light = clamp(dot(normal, normalize(vec3(0.55, -0.5, 0.65))), 0.0, 1.0);

    float grain = value_noise(p, 14.0, vec2(0.0));
    vec3 color = mix(meadow_color.rgb, meadow_lit_color.rgb, fbm(p, 240.0, vec2(2.0), 5));
    color *= 0.94 + 0.08 * grain;

    // The pine forests grow in soft patches on the slopes.
    float forest = smoothstep(0.56, 0.63, fbm(p, 230.0, vec2(7.3), 5) + h * 0.35)
        * (1.0 - smoothstep(0.6, 0.7, h));
    vec3 trees = forest_color.rgb * (0.8 + 0.4 * value_noise(p, 9.0, vec2(0.0)));
    color = mix(color, trees, forest);

    // The rocks up high, then the snow and the glaciers on the peaks.
    float rock = smoothstep(0.55, 0.65, h + 0.06 * fbm(p, 60.0, vec2(0.0), 5));
    color = mix(color, rock_color.rgb * (0.85 + 0.3 * fbm(p, 40.0, vec2(0.0), 5)), rock);
    float snow = smoothstep(0.74, 0.8, h + 0.05 * fbm(p, 50.0, vec2(3.0), 5));
    float crevasse = 0.93 + 0.07 * sin(p.x * 0.03 + fbm(p, 120.0, vec2(0.0), 5) * 8.0);
    color = mix(color, snow_color.rgb * crevasse, snow);

    // NOTE (mristin):
    // The shade is strong, so that the mountains look steep, but soft.
    color = mix(shade_color.rgb, color, 0.3 + 0.7 * light);
    color = mix(color, color * vec3(1.06, 0.98, 0.88), 0.4 * light);

    // The pass road, a dim winding ribbon with a soft edge.
    float road_d = abs(p.x - road_x(p.y));
    float road = smoothstep(11.0, 7.0, road_d);
    color = mix(color, color * 0.7, smoothstep(16.0, 10.0, road_d));
    color = mix(color, road_color.rgb * (0.9 + 0.1 * grain), road);

    // The small mountain lakes, in the valleys only.
    float lake_cover = 0.0;
    float cell_size = wrap_cell(lake_cell);
    vec2 cell = floor(p / cell_size);
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            vec2 c = cell + vec2(float(x), float(y));
            vec2 k = wrap_index(c, cell_size);
            if (hash(k + 3.3) > 0.45) {
                continue;
            }
            vec2 site = (c + 0.25 + 0.5 * vec2(hash(k + 1.1), hash(k + 7.7))) * cell_size;
            // NOTE (mristin):
            // The lake lies beside the road, never on it.
            float side = hash(k + 5.9) < 0.5 ? -1.0 : 1.0;
            site.x = road_x(site.y) + side * (190.0 + 60.0 * hash(k + 2.2));
            vec2 d = (p - site) * vec2(1.0, 1.5);
            float angle = atan(d.y, d.x);
            float r = 110.0 * (1.0 + 0.15 * sin(angle * 3.0 + hash(k) * 9.0));
            float lake = smoothstep(r, r - 6.0, length(d));
            float shore = smoothstep(r + 26.0, r, length(d)) * (1.0 - lake);
            color = mix(color, color * 0.75, shore);
            color = mix(color, water_color.rgb * LAKE_RIPPLE, lake);
            lake_cover = max(lake_cover, lake);
        }
    }

    COLOR = vec4(color, lake_cover);
}
