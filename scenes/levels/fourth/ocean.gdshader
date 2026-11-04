shader_type canvas_item;

// Draw the ocean seen from above, sliding down below the spaceships: the deep
// water with darker patches of the sea grass far below, the slow swell, and
// the faint, shimmering network of the sunlight on the sea floor.
//
// NOTE (mristin):
// We keep the ocean dark and calm, so that the bubbles, the ink and the sparks
// stand out. The shimmer is faint and large, so that nobody mistakes it for
// a projectile.

// How fast the water slides down, in pixels per second. The alligators and
// the clams drift at the same speed.
uniform float scroll_speed = 40.0;

uniform vec4 deep_color : source_color = vec4(0.02, 0.08, 0.16, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.03, 0.14, 0.22, 1.0);
uniform vec4 grass_color : source_color = vec4(0.02, 0.1, 0.09, 1.0);
uniform vec4 shimmer_color : source_color = vec4(0.35, 0.6, 0.7, 1.0);
uniform float shimmer_strength : hint_range(0.0, 1.0) = 0.12;

// The size of the shimmer's network, in pixels.
uniform float shimmer_scale = 520.0;

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

// Return the brightness of the light's network on the sea floor.
//
// NOTE (mristin):
// This is the well-known iterative trick for the tileable water caustics.
float caustic(vec2 uv, float t) {
    vec2 p = mod(uv * 6.28318, 6.28318) - 250.0;
    vec2 i = p;
    float c = 1.0;
    float intensity = 0.005;
    for (int n = 0; n < 4; n++) {
        float tt = t * (1.0 - (3.5 / float(n + 1)));
        i = p + vec2(cos(tt - i.x) + sin(tt + i.y), sin(tt - i.y) + cos(tt + i.x));
        c += 1.0 / length(vec2(p.x / (sin(i.x + tt) / intensity), p.y / (cos(i.y + tt) / intensity)));
    }
    c /= 4.0;
    c = 1.17 - pow(c, 1.4);
    return clamp(pow(abs(c), 8.0), 0.0, 1.0);
}

void vertex() {
    local_position = VERTEX;
}

void fragment() {
    vec2 p = local_position - vec2(0.0, TIME * scroll_speed);

    float depth = fbm(p / 700.0);
    vec3 color = mix(deep_color.rgb, shallow_color.rgb, smoothstep(0.35, 0.7, depth));

    float grass = smoothstep(0.55, 0.75, fbm(p / 260.0 + vec2(5.2, 1.3)));
    color = mix(color, grass_color.rgb, grass * 0.6);

    // NOTE (mristin):
    // The swell slowly brightens and darkens the water in broad bands.
    float swell = sin(p.y / 140.0 + sin(p.x / 300.0 + TIME * 0.3) * 1.5 + TIME * 0.5);
    color *= 0.95 + 0.05 * swell;

    color += shimmer_color.rgb * caustic(p / shimmer_scale, TIME * 0.25) * shimmer_strength;

    COLOR = vec4(color, 1.0);
}
