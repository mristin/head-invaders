# head-invaders

![Playing Head Invaders: the spaceship follows the player's head, seen through the webcam](docs/gameplay.gif)

Head Invaders is a video game for children which they play with their whole body instead of sitting still with a controller.
Bad dreams have invaded the players' heads, and the players chase them away through ten worlds, from outer space over forests, seas, lava, deserts, ice, the sky and the Swiss Alps all the way home to Zurich.
The game watches the players through a webcam: each player in front of the camera gets a spaceship, which follows their head.
To fly, the children move: they step left and right, duck and stretch up to dodge the projectiles, catch the falling boosters and shoot open the treasure chests.
The spaceships fire all by themselves, so there are no buttons to learn, and friends can join or leave at any time just by stepping in front of the camera or away from it.
That way, the children get the fun of a video game without the drawbacks of sitting for a long time without moving.
Nothing in the game is violent: the defeated creatures only get dizzy and fly home, and a spaceship which runs out of shield just tries the level again.

**No network access.**
The game runs entirely on your computer and works offline.
It never connects to any server: the webcam images are processed locally, in memory, and are never saved or sent anywhere.
There are no accounts, no ads, no analytics and no telemetry; we even switch off the telemetry events of ONNX Runtime, the library which runs the head-tracking models.

## Download

Download the game for Linux, Windows or macOS from the [releases].
Unzip the package and start the game.
You need a webcam which supports 640x480 in the YUYV format.

The macOS package runs on Apple Silicon.
On Intel Macs, the head tracking does not work, since ONNX Runtime provides no library for them.

[releases]: https://github.com/mristin/head-invaders/releases

## Acknowledgments

We track the heads with the following models (each model directory contains its license):

* [YOLOX-Body-Head-Hand-Face] (nano, 256x320, Apache-2.0) detects the whole heads from any side, and the bodies.
* [OSNet] (x0.25, trained on MSMT17, MIT) recognizes the players when they come back.
  Note that the MSMT17 dataset itself is licensed for research only.
* [UltraFace] (RFB-320, MIT) detects frontal faces; we keep it as a faster fallback.

[YOLOX-Body-Head-Hand-Face]: https://github.com/PINTO0309/PINTO_model_zoo/tree/main/434_YOLOX-Body-Head-Hand-Face
[OSNet]: https://github.com/KaiyangZhou/deep-person-reid
[UltraFace]: https://github.com/Linzaer/Ultra-Light-Fast-Generic-Face-Detector-1MB

The structure of the game, the camera set-up and the inference loop were adapted from [ergo-chaos].

[ergo-chaos]: https://github.com/mristin/ergo-chaos

## License

Head Invaders is licensed under the [MIT License](LICENSE).
The third-party components, e.g., Godot Engine, ONNX Runtime and the head-tracking models, keep their own licenses; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to set up the development environment, how to test the levels in isolation, and how to run the formatter, the linter and the tests.
