shader_type canvas_item;

// Draw the space sliding down below the spaceships: three layers of stars, where
// the nearer layers slide faster, a faint nebula drifting far behind them, and
// optionally a dim planet far away.
//
// Each level sets its own colors, the nebula and the planet, so that every
// level has a background of its own.
//
// NOTE (mristin):
// We keep the space calm: the stars are few, dim, bluish and slow, and barely
// twinkle, so that the players never mistake them for the bullets and
// the rockets, which are bright and warm. The game is played on a small screen
// from a distance.
//
// The stars were adapted from ergo-chaos. We grid in local pixels instead of UV
// so that the stars stay round on non-square rectangles.

// How fast the nearest layer of stars slides down, in pixels per second.
uniform float scroll_speed = 40.0;

uniform float star_density : hint_range(0.0, 1.0) = 0.025;
uniform float twinkle_speed = 0.8;
uniform vec4 star_color : source_color = vec4(0.55, 0.65, 0.9, 1.0);

// The brightest star stays this dim, well below the bullets and the rockets.
uniform float star_brightness : hint_range(0.0, 1.0) = 0.35;

// The color of the deep space behind everything.
uniform vec4 deep_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

// The nebula blends between the two colors.
uniform vec4 nebula_color : source_color = vec4(0.3, 0.12, 0.5, 1.0);
uniform vec4 nebula_color_2 : source_color = vec4(0.3, 0.12, 0.5, 1.0);
uniform float nebula_strength : hint_range(0.0, 1.0) = 0.3;

// The size of the nebula clouds, in pixels.
uniform float nebula_scale = 420.0;

// The planet in the far distance; a zero radius means no planet.
uniform vec2 planet_center = vec2(1500.0, 300.0);
uniform float planet_radius = 0.0;
uniform vec4 planet_color : source_color = vec4(0.25, 0.4, 0.5, 1.0);
uniform vec4 planet_ring_color : source_color = vec4(0.5, 0.45, 0.35, 1.0);

// The planet slides down this many times slower than the nearest stars.
uniform float planet_slowness = 40.0;

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

// Return the planet's color with its coverage in alpha.
vec4 planet(vec2 p) {
    if (planet_radius <= 0.0) {
        return vec4(0.0);
    }

    vec2 d = (p - planet_center) / planet_radius;
    float dist = length(d);
    float body = smoothstep(1.0, 0.97, dist);

    // NOTE (mristin):
    // The light comes from the upper left, and the bands are faint.
    vec3 normal = vec3(d, sqrt(max(0.0, 1.0 - dist * dist)));
    float light = clamp(0.25 + 0.75 * dot(normal, normalize(vec3(-0.6, -0.5, 0.6))), 0.0, 1.0);
    float bands = 0.9 + 0.1 * sin(d.y * 14.0 + sin(d.x * 3.0) * 1.5);
    vec3 body_color = planet_color.rgb * light * bands;

    // NOTE (mristin):
    // The ring is a tilted, flat ellipse. Its upper half passes behind
    // the planet.
    float c = cos(-0.3);
    float s = sin(-0.3);
    vec2 rd = vec2(c * d.x - s * d.y, s * d.x + c * d.y);
    float ring_dist = length(vec2(rd.x, rd.y * 4.0));
    float ring = smoothstep(0.08, 0.0, abs(ring_dist - 1.55)) * 0.8
        + smoothstep(0.1, 0.0, abs(ring_dist - 1.8)) * 0.5;
    if (rd.y < 0.0) {
        ring *= 1.0 - body;
    }
    ring = clamp(ring, 0.0, 1.0);

    vec3 color = mix(planet_ring_color.rgb, mix(body_color, planet_ring_color.rgb, ring), body);
    return vec4(color, max(body, ring));
}

float star_layer(vec2 p, float cell_size, float star_radius, float density, float seed) {
    vec2 grid = floor(p / cell_size);
    vec2 cell_uv = fract(p / cell_size) - 0.5;

    float rnd = hash(grid + seed);
    float is_star = step(1.0 - density, rnd);

    // NOTE (mristin):
    // We jitter the stars within their cells so that the grid does not show.
    vec2 offset = vec2(hash(grid + seed + 1.3), hash(grid + seed + 7.1)) - 0.5;
    float star = smoothstep(star_radius, 0.0, length(cell_uv - offset * 0.5) * cell_size);

    float twinkle = 0.85 + 0.15 * sin(TIME * twinkle_speed + rnd * 20.0);
    return is_star * star * twinkle;
}

void vertex() {
    local_position = VERTEX;
}

void fragment() {
    float travel = TIME * scroll_speed;

    float stars =
        0.4 * star_layer(local_position - vec2(0.0, travel * 0.25), 24.0, 2.5, star_density, 0.0)
        + 0.7 * star_layer(local_position - vec2(0.0, travel * 0.5), 40.0, 3.5, star_density, 17.0)
        + 1.0 * star_layer(local_position - vec2(0.0, travel), 64.0, 4.5, star_density * 0.6, 41.0);
    stars = min(stars, 1.0) * star_brightness;

    vec2 cloud_position = (local_position - vec2(0.0, travel * 0.1)) / nebula_scale;
    float cloud = fbm(cloud_position);
    float tone = fbm(cloud_position * 0.7 + vec2(13.7, 5.3));
    vec3 nebula_tint = mix(nebula_color.rgb, nebula_color_2.rgb, smoothstep(0.3, 0.7, tone));
    vec3 nebula = nebula_tint * smoothstep(0.45, 0.9, cloud) * nebula_strength;

    vec3 color = deep_color.rgb + nebula;

    // NOTE (mristin):
    // The planet is far away, so it slides very slowly, and the nearer stars
    // pass in front of it. We wrap it around so that it comes back.
    vec2 planet_position = local_position - vec2(0.0, mod(travel / planet_slowness, 1080.0 + planet_radius * 4.0));
    vec4 far_planet = planet(planet_position);
    if (far_planet.a <= 0.0) {
        far_planet = planet(planet_position + vec2(0.0, 1080.0 + planet_radius * 4.0));
    }
    color = mix(color, far_planet.rgb, far_planet.a);

    COLOR = vec4(color + star_color.rgb * stars, 1.0);
}
