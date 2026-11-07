shader_type canvas_item;

// Draw one tile of the forest seen from high above: the round crowns of
// the trees with their shadows, the grassy clearings, and a river winding
// through. PrerenderedGround draws the tile only once, and forest.gdshader
// slides it down below the spaceships.
//
// NOTE (mristin):
// We keep the forest dark and calm, so that the bullets, the rockets and
// the aliens stand out. Nothing in the forest is small and bright, so that
// nobody mistakes it for a projectile.
//
// The tile repeats itself vertically after FOREST_PERIOD, so all the noise
// wraps around after it.

#include "res://scenes/levels/third/forest_common.gdshaderinc"

uniform vec4 ground_color : source_color = vec4(0.05, 0.1, 0.05, 1.0);
uniform vec4 clearing_color : source_color = vec4(0.11, 0.16, 0.07, 1.0);
uniform vec4 tree_color : source_color = vec4(0.07, 0.19, 0.08, 1.0);
uniform vec4 tree_color_2 : source_color = vec4(0.12, 0.2, 0.06, 1.0);
uniform vec4 river_color : source_color = vec4(0.06, 0.13, 0.2, 1.0);

// The size of the grid in which we plant the trees, in pixels.
const float TREE_CELL = 120.0;

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

// Return the fractal noise of the ground at the given scale in pixels, which
// must divide FOREST_PERIOD.
float fbm(vec2 p, float scale) {
    float period = FOREST_PERIOD / scale;
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

float clearing(vec2 p) {
    return smoothstep(0.55, 0.72, fbm(p + vec2(1116.0, 0.0), 360.0));
}

// Return the center and the radius of the tree crown in the cell, or a zero
// radius if no tree grows there.
vec3 tree(vec2 cell) {
    vec2 wrapped = vec2(cell.x, mod(cell.y, FOREST_PERIOD / TREE_CELL));
    vec2 center = (cell + 0.2 + 0.6 * vec2(hash(wrapped + 1.7), hash(wrapped + 9.3))) * TREE_CELL;
    float radius = TREE_CELL * (0.42 + 0.22 * hash(wrapped + 4.1));

    if (abs(center.x - river_x(center.y)) < 110.0 + radius * 0.5) {
        return vec3(center, 0.0);
    }
    if (clearing(center) > 0.5 || hash(wrapped + 2.9) < 0.12) {
        return vec3(center, 0.0);
    }
    return vec3(center, radius);
}

float crown(vec2 p, vec3 t, float seed) {
    vec2 d = p - t.xy;
    float distance = length(d);

    // We skip the lumpy edge, and its arc tangent, far from the crown.
    if (distance > t.z * 1.08) {
        return 0.0;
    }
    float angle = atan(d.y, d.x);
    float lumpy = t.z * (1.0 + 0.07 * sin(angle * 6.0 + seed * 20.0));
    return smoothstep(lumpy, lumpy - 3.0, distance);
}

void vertex() {
    local_position = VERTEX;
}

void fragment() {
    vec2 p = local_position;

    vec3 color = mix(ground_color.rgb, clearing_color.rgb, clearing(p));
    color *= 0.9 + 0.2 * fbm(p, 60.0);

    // NOTE (mristin):
    // The river with its darker banks. forest.gdshader adds the ripples.
    float river_distance = abs(p.x - river_x(p.y));
    float river = smoothstep(68.0, 58.0, river_distance);
    float bank = smoothstep(88.0, 68.0, river_distance) * (1.0 - river);
    color *= 1.0 - 0.35 * bank;
    color = mix(color, river_color.rgb * 0.975, river);

    // We look up the trees of the 3 x 3 neighboring cells only once, and use
    // them both for the shadows and for the crowns.
    vec2 cell = floor(p / TREE_CELL);
    vec3 trees[9];
    float seeds[9];
    for (int i = 0; i < 9; i++) {
        vec2 c = cell + vec2(float(i % 3 - 1), float(i / 3 - 1));
        trees[i] = tree(c);
        seeds[i] = hash(vec2(c.x, mod(c.y, FOREST_PERIOD / TREE_CELL)));
    }

    // We draw all the shadows first, so that no shadow falls on a crown.
    float shadow = 0.0;
    for (int i = 0; i < 9; i++) {
        if (trees[i].z > 0.0) {
            shadow = max(shadow, crown(p - vec2(14.0, 16.0), trees[i], seeds[i]) * 0.55);
        }
    }
    color *= 1.0 - shadow;

    for (int i = 0; i < 9; i++) {
        vec3 t = trees[i];
        if (t.z <= 0.0) {
            continue;
        }
        float inside = crown(p, t, seeds[i]);
        if (inside <= 0.0) {
            continue;
        }

        // NOTE (mristin):
        // The light comes from the upper left.
        vec2 d = (p - t.xy) / t.z;
        float light = 0.75 + 0.4 * dot(d, normalize(vec2(-0.7, -0.7)));
        light *= 0.9 + 0.2 * value_noise(p / 15.0, FOREST_PERIOD / 15.0);
        vec3 leaves = mix(tree_color.rgb, tree_color_2.rgb, fract(seeds[i] * 7.31 + 0.37)) * light;
        color = mix(color, leaves, inside);
    }

    COLOR = vec4(color, 1.0);
}
