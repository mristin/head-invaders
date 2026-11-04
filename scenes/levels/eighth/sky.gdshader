shader_type canvas_item;

// Draw a sky kingdom at dusk seen from high above, drifting down below
// the spaceships: soft banks of clouds tinted violet and pink by the evening
// sun, with glimpses of the far-away fields and rivers between them, and now
// and then a floating island with a little castle on top.
//
// NOTE (mristin):
// We keep the sky dim and calm, so that the raindrops, the sandbags and
// the paper darts stand out. Nothing in the sky is small and bright, so that
// nobody mistakes it for a projectile. The clouds are dusky, never white.

// How fast the clouds drift down, in pixels per second. The far-away ground
// drifts slower, and the ground enemies, if any, slide at this speed.
uniform float scroll_speed = 36.0;

uniform vec4 sky_color : source_color = vec4(0.05, 0.07, 0.18, 1.0);
uniform vec4 field_color : source_color = vec4(0.07, 0.13, 0.15, 1.0);
uniform vec4 field_alt_color : source_color = vec4(0.1, 0.11, 0.2, 1.0);
uniform vec4 river_color : source_color = vec4(0.14, 0.17, 0.32, 1.0);
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
    for (int i = 0; i < 5; i++) {
        sum += amplitude * value_noise(p);
        p *= 2.03;
        amplitude *= 0.5;
    }
    return sum;
}

// Return the color of the far-away ground: a patchwork of fields with a
// winding river, faded by the haze.
vec3 ground(vec2 p) {
    vec2 field = floor((p + vec2(fbm(p / 300.0) * 60.0, 0.0)) / vec2(160.0, 110.0));
    vec3 color = mix(field_color.rgb, field_alt_color.rgb, hash(field));
    color *= 0.85 + 0.25 * fbm(p / 40.0);
    float river = abs(p.x - 900.0 - sin(p.y / 420.0) * 380.0 - fbm(p / 250.0) * 260.0);
    color = mix(color, river_color.rgb, smoothstep(26.0, 18.0, river));
    return color;
}

// Return the density of the clouds, from 0 to 1: puffy banks with soft,
// billowy edges.
float clouds(vec2 p) {
    vec2 q = p + vec2(fbm(p / 800.0) * 260.0, fbm(p / 700.0 + 4.2) * 180.0);
    float bank = fbm(q / 620.0);
    float billows = value_noise(q / 90.0) * 0.6 + value_noise(q / 45.0) * 0.4;
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
    vec2 p = local_position - vec2(0.0, TIME * scroll_speed);

    // NOTE (mristin):
    // The ground is far below, so it drifts slower, and the haze of the dusk
    // fades it into the deep blue sky.
    vec2 far = local_position - vec2(0.0, TIME * scroll_speed * 0.35);
    vec3 color = mix(ground(far), sky_color.rgb, 0.45);

    // The thin, high veils of haze drift a bit faster than the ground.
    float veil = fbm((local_position - vec2(0.0, TIME * scroll_speed * 0.6)) / 380.0 + 7.3);
    color = mix(color, sky_color.rgb * 1.3, smoothstep(0.45, 0.75, veil) * 0.5);

    // The banks of clouds, lit softly from the upper left by the low sun.
    float density = clouds(p);
    // NOTE (mristin):
    // The edges facing the sun glow pink, the far sides sink into violet,
    // and the inside of the banks is softly rounded by the billows.
    float sunward = clouds(p + vec2(-30.0, -40.0));
    float away = clouds(p + vec2(30.0, 40.0));
    vec3 cloud = cloud_color.rgb * (0.9 + 0.2 * value_noise(p / 60.0));
    cloud = mix(cloud, cloud_lit_color.rgb, (1.0 - sunward) * 0.8);
    cloud = mix(cloud, cloud_shade_color.rgb, (1.0 - away) * 0.7);
    float billow = fbm(p / 110.0 + 2.1);
    cloud *= 0.88 + 0.24 * smoothstep(0.3, 0.7, billow);

    // The shadow of the clouds on the ground, then the clouds.
    float shadow = clouds(p + vec2(40.0, 60.0));
    color *= 1.0 - 0.35 * shadow;
    color = mix(color, cloud, density);

    // NOTE (mristin):
    // The floating islands drift with the clouds, some resting in a cloud
    // bank, others over the gaps.
    vec2 cell = floor(p / island_cell);
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            vec2 c = cell + vec2(float(x), float(y));
            if (hash(c + 3.3) > 0.3) {
                continue;
            }
            vec2 site = (c + 0.25 + 0.5 * vec2(hash(c + 1.1), hash(c + 7.7))) * island_cell;
            float seed = hash(c + 5.9);
            vec4 shade = island(p - vec2(26.0, 34.0), site, seed);
            color *= 1.0 - 0.4 * shade.x;
            vec4 isle = island(p, site, seed);
            color = mix(color, rock_color.rgb * (0.85 + 0.3 * value_noise(p / 14.0)), isle.x);
            color = mix(color, grass_color.rgb * (0.85 + 0.3 * fbm(p / 20.0)), isle.y);
            color = mix(color, color * 0.6, island(p - vec2(8.0, 10.0), site, seed).z * isle.y);
            color = mix(color, castle_color.rgb, isle.z);
            color = mix(color, roof_color.rgb, isle.w);
        }
    }

    // A gentle evening glow from the top of the screen.
    float glow = smoothstep(500.0, 0.0, local_position.y);
    color += vec3(0.05, 0.02, 0.05) * glow;

    COLOR = vec4(color, 1.0);
}
