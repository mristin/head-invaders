shader_type canvas_item;

// Draw a forest seen from high above, sliding down below the spaceships:
// the round crowns of the trees with their shadows, the grassy clearings, and
// a river winding through.
//
// NOTE (mristin):
// We keep the forest dark and calm, so that the bullets, the rockets and
// the aliens stand out. Nothing in the forest is small and bright, so that
// nobody mistakes it for a projectile.

// How fast the ground slides down, in pixels per second. The ground enemies
// slide at the same speed.
uniform float scroll_speed = 50.0;

uniform vec4 ground_color : source_color = vec4(0.05, 0.1, 0.05, 1.0);
uniform vec4 clearing_color : source_color = vec4(0.11, 0.16, 0.07, 1.0);
uniform vec4 tree_color : source_color = vec4(0.07, 0.19, 0.08, 1.0);
uniform vec4 tree_color_2 : source_color = vec4(0.12, 0.2, 0.06, 1.0);
uniform vec4 river_color : source_color = vec4(0.06, 0.13, 0.2, 1.0);

// The size of the grid in which we plant the trees, in pixels.
uniform float tree_cell = 120.0;

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
    for (int i = 0; i < 4; i++) {
        sum += amplitude * value_noise(p);
        p *= 2.03;
        amplitude *= 0.5;
    }
    return sum;
}

// Return the x of the middle of the river at the given y of the ground.
float river_x(float y) {
    return 960.0 + sin(y / 520.0) * 380.0 + sin(y / 170.0) * 50.0;
}

float clearing(vec2 p) {
    return smoothstep(0.55, 0.72, fbm(p / 340.0 + vec2(3.1, 7.7)));
}

// Return the center and the radius of the tree crown in the cell, or a zero
// radius if no tree grows there.
vec3 tree(vec2 cell) {
    vec2 center = (cell + 0.2 + 0.6 * vec2(hash(cell + 1.7), hash(cell + 9.3))) * tree_cell;
    float radius = tree_cell * (0.42 + 0.22 * hash(cell + 4.1));

    if (abs(center.x - river_x(center.y)) < 110.0 + radius * 0.5) {
        return vec3(center, 0.0);
    }
    if (clearing(center) > 0.5 || hash(cell + 2.9) < 0.12) {
        return vec3(center, 0.0);
    }
    return vec3(center, radius);
}

float crown(vec2 p, vec3 t, float seed) {
    vec2 d = p - t.xy;
    float angle = atan(d.y, d.x);
    float lumpy = t.z * (1.0 + 0.07 * sin(angle * 6.0 + seed * 20.0));
    return smoothstep(lumpy, lumpy - 3.0, length(d));
}

void vertex() {
    local_position = VERTEX;
}

void fragment() {
    vec2 p = local_position - vec2(0.0, TIME * scroll_speed);

    vec3 color = mix(ground_color.rgb, clearing_color.rgb, clearing(p));
    color *= 0.9 + 0.2 * fbm(p / 60.0);

    // NOTE (mristin):
    // The river with its darker banks and slow, soft ripples.
    float river_distance = abs(p.x - river_x(p.y));
    float river = smoothstep(68.0, 58.0, river_distance);
    float bank = smoothstep(88.0, 68.0, river_distance) * (1.0 - river);
    color *= 1.0 - 0.35 * bank;
    float ripple = 0.5 + 0.5 * sin(p.y * 0.05 + sin(p.x * 0.04) * 2.0 + TIME * 0.8);
    color = mix(color, river_color.rgb * (0.85 + 0.25 * ripple), river);

    vec2 cell = floor(p / tree_cell);

    // We draw all the shadows first, so that no shadow falls on a crown.
    float shadow = 0.0;
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            vec2 c = cell + vec2(float(x), float(y));
            vec3 t = tree(c);
            if (t.z > 0.0) {
                shadow = max(shadow, crown(p - vec2(14.0, 16.0), t, hash(c)) * 0.55);
            }
        }
    }
    color *= 1.0 - shadow;

    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            vec2 c = cell + vec2(float(x), float(y));
            vec3 t = tree(c);
            if (t.z <= 0.0) {
                continue;
            }
            float inside = crown(p, t, hash(c));
            if (inside <= 0.0) {
                continue;
            }

            // NOTE (mristin):
            // The light comes from the upper left.
            vec2 d = (p - t.xy) / t.z;
            float light = 0.75 + 0.4 * dot(d, normalize(vec2(-0.7, -0.7)));
            light *= 0.9 + 0.2 * value_noise(p / 14.0);
            vec3 leaves = mix(tree_color.rgb, tree_color_2.rgb, hash(c + 5.5)) * light;
            color = mix(color, leaves, inside);
        }
    }

    COLOR = vec4(color, 1.0);
}
