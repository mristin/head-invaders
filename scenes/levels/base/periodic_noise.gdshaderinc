// The noise for the tiles of the grounds which PrerenderedGround draws once,
// e.g., the desert or the Alps. Everything here repeats itself vertically after
// PERIOD pixels, so that the level's shader can wrap the tile around while it
// slides it down.
//
// NOTE (mristin):
// We round the scales, the cells and the frequencies so that a whole number of
// them fits into PERIOD. The look hardly changes, but the tile has no seam.

// The height of the tile, in pixels; keep it the same as the height of
// the PrerenderedGround and as in the level's shader.
const float PERIOD = 4320.0;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

vec2 hash2(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453123);
}

// Return how many times something of roughly the given size in pixels fits
// into PERIOD.
float fit_count(float size) {
    return max(1.0, round(PERIOD / size));
}

// Return the size of the cells, roughly the given size in pixels, so that
// a whole number of them fits into PERIOD.
float wrap_cell(float size) {
    return PERIOD / fit_count(size);
}

// Wrap the index of a cell of the given size around vertically, e.g., before
// hashing it, so that the cells repeat after PERIOD.
vec2 wrap_index(vec2 cell, float size) {
    return vec2(cell.x, mod(cell.y, PERIOD / size));
}

// Return the frequency, close to the given one in radians per pixel, so that
// a sine along y repeats after PERIOD.
float wrap_frequency(float frequency) {
    return 6.28318530718 * max(1.0, round(frequency * PERIOD / 6.28318530718)) / PERIOD;
}

// Return the value noise in the units of the noise, where the lattice wraps
// around vertically after the given number of cells.
float value_noise_cells(vec2 q, float cells) {
    vec2 i = floor(q);
    vec2 f = fract(q);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float y0 = mod(i.y, cells);
    float y1 = mod(i.y + 1.0, cells);
    return mix(
        mix(hash(vec2(i.x, y0)), hash(vec2(i.x + 1.0, y0)), u.x),
        mix(hash(vec2(i.x, y1)), hash(vec2(i.x + 1.0, y1)), u.x),
        u.y
    );
}

// Return the value noise at the point in pixels, at roughly the given scale in
// pixels, shifted by the offset in the units of the noise.
float value_noise(vec2 p, float scale, vec2 offset) {
    float cells = fit_count(scale);
    return value_noise_cells(p * cells / PERIOD + offset, cells);
}

// Return the fractal noise at the point in pixels, at roughly the given scale
// in pixels, shifted by the offset in the units of the noise.
float fbm(vec2 p, float scale, vec2 offset, int octaves) {
    float cells = fit_count(scale);
    vec2 q = p * cells / PERIOD + offset;
    float sum = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < octaves; i++) {
        sum += amplitude * value_noise_cells(q, cells);
        // NOTE (mristin):
        // The shift keeps the lattices of the octaves from lining up; it does
        // not break the wrapping, since the cells double as well.
        q = q * 2.0 + vec2(1.7, 9.2);
        cells *= 2.0;
        amplitude *= 0.5;
    }
    return sum;
}
