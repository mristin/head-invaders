shader_type canvas_item;

// We keep the alpha raw, since it carries how much of the ground shows, not
// the coverage.
render_mode blend_disabled;

// Draw one tile of the sky kingdom's clouds seen from high above: soft banks
// of clouds tinted violet and pink by the evening sun, with their shadows on
// the ground, and now and then a floating island with a little castle on top.
// PrerenderedGround draws the tile only once, and sky.gdshader slides it down
// over the far-away ground.
//
// NOTE (mristin):
// We keep the sky dim and calm, so that the raindrops, the sandbags and
// the paper darts stand out. Nothing in the sky is small and bright, so that
// nobody mistakes it for a projectile. The clouds are dusky, never white.
//
// The ground below drifts at another speed, so we can not draw it into this
// tile. But all the clouds and the islands only darken the ground and mix
// their colors over it, so the final color is ground * a + rgb: we put how
// much of the ground shows into the alpha and the rest into the color.
//
// The tile repeats itself vertically after PERIOD, so all the noise wraps
// around after it.

#include "res://scenes/levels/base/periodic_noise.gdshaderinc"

uniform vec4 cloud_shade_color : source_color = vec4(0.16, 0.13, 0.3, 1.0);
uniform vec4 cloud_color : source_color = vec4(0.27, 0.22, 0.37, 1.0);
uniform vec4 cloud_lit_color : source_color = vec4(0.42, 0.28, 0.4, 1.0);
uniform vec4 rock_color : source_color = vec4(0.16, 0.12, 0.17, 1.0);
uniform vec4 grass_color : source_color = vec4(0.1, 0.16, 0.17, 1.0);
uniform vec4 castle_color : source_color = vec4(0.24, 0.21, 0.31, 1.0);
uniform vec4 roof_color : source_color = vec4(0.3, 0.17, 0.27, 1.0);

// The size of the grid in which we place the floating islands, in pixels.
uniform float island_cell = 1000.0;

varying vec2 local_position;

// Return the density of the clouds, from 0 to 1: puffy banks with soft,
// billowy edges.
float clouds(vec2 p) {
    vec2 q = p + vec2(
        fbm(p, 800.0, vec2(0.0), 5) * 260.0, fbm(p, 700.0, vec2(4.2), 5) * 180.0
    );
    float bank = fbm(q, 620.0, vec2(0.0), 5);
    float billows = value_noise(q, 90.0, vec2(0.0)) * 0.6 + value_noise(q, 45.0, vec2(0.0)) * 0.4;
    return smoothstep(0.5, 0.56, bank + (billows - 0.5) * 0.07);
}

// Return how much of a floating island with its castle covers the point, as
// (rock, grass, castle, roof).
vec4 island(vec2 p, vec2 site, float seed) {
    vec2 d = p - site;
    float angle = atan(d.y, d.x);
    float size = 150.0 + 70.0 * seed;
    float edge = size * (1.0 + 0.12 * sin(angle * 4.0 + seed * 11.0) + 0.06 * sin(angle * 9.0));
    float rock = smoothstep(edge, edge - 6.0, length(d * vec2(1.0, 1.25)));
    float grass = smoothstep(edge - 22.0, edge - 30.0, length(d * vec2(1.0, 1.25)));

    // NOTE (mristin):
    // The castle from above: a square keep with a pointed roof and four
    // round towers at the corners, each with a round roof.
    vec2 k = abs(d) - vec2(48.0, 40.0);
    float keep = smoothstep(2.0, -2.0, max(k.x, k.y));
    float roof = smoothstep(2.0, -2.0, abs(d.x) + abs(d.y) * 1.2 - 40.0);
    float tower = 0.0;
    float tower_roof = 0.0;
    for (int i = 0; i < 4; i++) {
        vec2 corner = vec2(i < 2 ? -52.0 : 52.0, (i % 2 == 0) ? -44.0 : 44.0);
        float r = length(d - corner);
        tower = max(tower, smoothstep(24.0, 21.0, r));
        tower_roof = max(tower_roof, smoothstep(17.0, 14.0, r));
    }
    float castle = max(keep, tower);
    float roofs = max(roof * keep, tower_roof);
    return vec4(rock, grass, castle, roofs);
}

void vertex() {
    local_position = VERTEX;
}

void fragment() {
    vec2 p = local_position;

    // NOTE (mristin):
    // We track the final color as ground * through + color.
    float through = 1.0;
    vec3 color = vec3(0.0);

    // The banks of clouds, lit softly from the upper left by the low sun.
    float density = clouds(p);
    // NOTE (mristin):
    // The edges facing the sun glow pink, the far sides sink into violet,
    // and the inside of the banks is softly rounded by the billows.
    float sunward = clouds(p + vec2(-30.0, -40.0));
    float away = clouds(p + vec2(30.0, 40.0));
    vec3 cloud = cloud_color.rgb * (0.9 + 0.2 * value_noise(p, 60.0, vec2(0.0)));
    cloud = mix(cloud, cloud_lit_color.rgb, (1.0 - sunward) * 0.8);
    cloud = mix(cloud, cloud_shade_color.rgb, (1.0 - away) * 0.7);
    float billow = fbm(p, 110.0, vec2(2.1), 5);
    cloud *= 0.88 + 0.24 * smoothstep(0.3, 0.7, billow);

    // The shadow of the clouds on the ground, then the clouds.
    float shadow = clouds(p + vec2(40.0, 60.0));
    through *= 1.0 - 0.35 * shadow;
    through *= 1.0 - density;
    color = mix(color, cloud, density);

    // NOTE (mristin):
    // The floating islands drift with the clouds, some resting in a cloud
    // bank, others over the gaps.
    float cell_size = wrap_cell(island_cell);
    vec2 cell = floor(p / cell_size);
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            vec2 c = cell + vec2(float(x), float(y));
            vec2 k = wrap_index(c, cell_size);
            if (hash(k + 3.3) > 0.3) {
                continue;
            }
            vec2 site = (c + 0.25 + 0.5 * vec2(hash(k + 1.1), hash(k + 7.7))) * cell_size;
            float seed = hash(k + 5.9);
            vec4 shade = island(p - vec2(26.0, 34.0), site, seed);
            float darken = 1.0 - 0.4 * shade.x;
            through *= darken;
            color *= darken;

            vec4 isle = island(p, site, seed);
            vec3 rock = rock_color.rgb * (0.85 + 0.3 * value_noise(p, 14.0, vec2(0.0)));
            through *= 1.0 - isle.x;
            color = mix(color, rock, isle.x);
            vec3 grass = grass_color.rgb * (0.85 + 0.3 * fbm(p, 20.0, vec2(0.0), 5));
            through *= 1.0 - isle.y;
            color = mix(color, grass, isle.y);
            float wall_shadow = 1.0 - 0.4 * island(p - vec2(8.0, 10.0), site, seed).z * isle.y;
            through *= wall_shadow;
            color *= wall_shadow;
            through *= 1.0 - isle.z;
            color = mix(color, castle_color.rgb, isle.z);
            through *= 1.0 - isle.w;
            color = mix(color, roof_color.rgb, isle.w);
        }
    }

    COLOR = vec4(color, through);
}
