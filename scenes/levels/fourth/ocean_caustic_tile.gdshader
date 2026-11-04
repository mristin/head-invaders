shader_type canvas_item;

// Draw one period of the shimmering network of the sunlight on the sea floor,
// on every frame, into a small tile which ocean.gdshader stretches over
// the whole screen.
//
// NOTE (mristin):
// The network repeats itself, so a small tile is enough, and the shimmer is
// faint and large, so nobody sees that we draw it at a lower resolution.

// The size of the tile, in pixels; keep it the same as the SubViewport.
uniform vec2 tile_size = vec2(256.0, 256.0);

varying vec2 local_position;

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

    // We raise to the eighth power by squaring three times, cheaper than pow().
    c = c * c;
    c = c * c;
    c = c * c;
    return clamp(c, 0.0, 1.0);
}

void vertex() {
    local_position = VERTEX;
}

void fragment() {
    float c = caustic(local_position / tile_size, TIME * 0.25);
    COLOR = vec4(c, c, c, 1.0);
}
