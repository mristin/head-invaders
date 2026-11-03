shader_type canvas_item;

// Draw a lava world seen from above, sliding down below the spaceships: dark
// volcanic rock with faintly glowing cracks, and slow rivers and pools of lava
// winding through it.
//
// NOTE (mristin):
// We keep the lava dim and dark red, so that the fireballs, which are bright
// yellow with a white outline, stand out. Nothing in the rock is small and
// bright, so that nobody mistakes it for a projectile.

// How fast the ground slides down, in pixels per second. The ground enemies
// slide at the same speed.
uniform float scroll_speed = 40.0;

uniform vec4 rock_color : source_color = vec4(0.08, 0.06, 0.06, 1.0);
uniform vec4 crack_color : source_color = vec4(0.22, 0.05, 0.02, 1.0);
uniform vec4 lava_color : source_color = vec4(0.26, 0.06, 0.02, 1.0);
uniform vec4 lava_hot_color : source_color = vec4(0.36, 0.11, 0.03, 1.0);

// The size of the rock plates between the cracks, in pixels.
uniform float plate_size = 130.0;

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

// Return how close the point is to a crack between the rock plates, from 0
// (the middle of a plate) to 1 (on the crack).
float crack(vec2 p) {
    vec2 cell = floor(p);
    float nearest = 8.0;
    float second = 8.0;
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            vec2 c = cell + vec2(float(x), float(y));
            vec2 point = c + vec2(hash(c), hash(c + 7.7));
            float d = length(p - point);
            if (d < nearest) {
                second = nearest;
                nearest = d;
            } else if (d < second) {
                second = d;
            }
        }
    }
    return smoothstep(0.08, 0.0, second - nearest);
}

void vertex() {
    local_position = VERTEX;
}

void fragment() {
    vec2 p = local_position - vec2(0.0, TIME * scroll_speed);

    vec3 color = rock_color.rgb * (0.75 + 0.5 * fbm(p / 90.0));

    // NOTE (mristin):
    // The cracks between the plates glow faintly, and the glow breathes
    // slowly.
    float breathing = 0.75 + 0.25 * sin(TIME * 0.8 + fbm(p / 400.0) * 6.0);
    color = mix(color, crack_color.rgb * breathing, crack(p / plate_size) * 0.55);

    // The lava rivers and pools, with the slowly flowing hot streaks.
    float flow = fbm(p / 520.0 + vec2(2.3, 8.1));
    float river = smoothstep(0.022, 0.01, abs(flow - 0.5));
    float pool = smoothstep(0.76, 0.8, fbm(p / 380.0 + vec2(11.0, 3.0)));
    float lava = max(river, pool);
    float streaks = fbm(p / vec2(60.0, 140.0) + vec2(0.0, TIME * 0.15));
    vec3 molten = mix(lava_color.rgb, lava_hot_color.rgb, smoothstep(0.4, 0.75, streaks));
    float rim = max(
        smoothstep(0.04, 0.022, abs(flow - 0.5)),
        smoothstep(0.72, 0.76, fbm(p / 380.0 + vec2(11.0, 3.0)))
    );
    color *= 1.0 - 0.4 * (rim - lava);
    color = mix(color, molten, lava);

    COLOR = vec4(color, 1.0);
}
