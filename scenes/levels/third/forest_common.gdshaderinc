// The functions which the forest's tile and its sliding share, so that
// the river of the sliding matches the river of the tile.

// The height of the tile, in pixels, after which the forest repeats itself.
// It is a multiple of the tree cell (120 px), of the clearings (360 px) and of
// the river's bends.
const float FOREST_PERIOD = 4320.0;

// Return the x of the middle of the river at the given y of the ground.
float river_x(float y) {
    float phase = y * 6.28318530718 / FOREST_PERIOD;
    return 960.0 + sin(phase) * 380.0 + sin(phase * 4.0) * 50.0;
}
