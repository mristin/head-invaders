# Contributing

Thank you for helping with Head Invaders!
This guide explains how to set up the development environment, how to run and test the game, and how to prepare a pull request.

## Overview

The game is made with [Godot] 4.6 (.NET), written in GDScript and C#:

* The head tracking runs in C# (`scenes/head_tracker/`).
  It detects the heads with YOLOX and recognizes the returning players with OSNet, both through ONNX Runtime.
  The C# core does not depend on Godot, so we unit-test it with plain .NET in `tests/HeadInvaders.Tests/`.
* The game itself is in GDScript (`scenes/`).
  Following [ergo-chaos], the `game` scene only orchestrates; the rules live in `level_state`, the spaceships in `fleet`, the enemies in `enemies/` and so on.
* The test levels and the test harness live in `scenes/tests/`, and the automatic Godot tests in `tests/godot/`.
* The development tools live in `dev/`.

The enemies on the ground (e.g., the mushrooms of the forest) extend `GroundEnemy`, which slides them down with the ground; keep its `ground_speed` the same as the scrolling of the level's background.

Each level has a background of its own: it overrides the material of `Stars` from `scenes/levels/base/base.tscn` and either sets the parameters of `space.gdshader` (the colors of the space and the nebula, the size of the clouds, and an optional planet far away), or uses a shader of its own, like the forest of the third level.
Keep the backgrounds calm and dim, so that the players never mistake the stars for the bullets or the rockets.
The tenth level (Zurich) has no shader: `ZurichMap` (`scenes/levels/tenth/zurich_map.gd`) draws a dim map of the city in chunks and slides it at `scroll_speed`, which its ground enemies match; enemies can find it in the group `zurich_map`, e.g., the Limmat swimmer follows the river with `limmat_x()`.

This is a game for children, so we avoid violence as well as sad and realistic themes: nothing explodes, things go "poof", the defeated aliens flee home, and a spaceship out of shield only gets dizzy.

[Godot]: https://godotengine.org
[ergo-chaos]: https://github.com/mristin/ergo-chaos

## Setting up the development environment

You need:

* [Git] and [Git LFS], since we keep the ONNX models and the images in LFS,
* the [.NET 8 SDK],
* the **.NET** build of [Godot 4.6.2] (also called "mono"; the standard build can not run C#), and
* [Python] 3.10 or newer, for the formatter and the linter (see below).

[Git]: https://git-scm.com
[Git LFS]: https://git-lfs.com
[.NET 8 SDK]: https://dotnet.microsoft.com/download/dotnet/8.0
[Godot 4.6.2]: https://godotengine.org/download/archive/4.6.2-stable/
[Python]: https://www.python.org/downloads/

### Clone the repository

```
git lfs install
git clone https://github.com/mristin/head-invaders.git
cd head-invaders
git lfs pull
```

If the models are missing or are only small text files, Git LFS was not set up before cloning.
Run `git lfs pull` again.

### Install Godot

Download the .NET build of Godot 4.6.2 and unpack it anywhere.
Our scripts find Godot through the `GODOT` environment variable, or as `godot` on your path.
For example, on Linux:

```
export GODOT=~/apps/Godot_v4.6.2-stable_mono_linux_x86_64/Godot_v4.6.2-stable_mono_linux.x86_64
```

Put the line in your shell profile (e.g., `~/.bashrc`) so that you do not have to repeat it.

### Restore and build the C# code

```
dotnet restore
dotnet build "Head Invaders.sln"
```

### Set up the Python environment

**Why do we need Python in a Godot project?**
The tools which keep the GDScript code tidy are written in Python: [gdtoolkit] provides the formatter (`gdformat`) and the linter (`gdlint`) for GDScript.
We also format our own development scripts in `dev/` with [black].
All the tools are pinned in `dev/requirements.txt`, so that everybody, including the continuous integration, formats and lints the code in exactly the same way.

We install the tools in a [virtual environment] in `venv/` (it is ignored by Git), so that they do not interfere with the other Python packages on your system:

```
python3 -m venv venv
venv/bin/pip install -r dev/requirements.txt
touch venv/.gdignore
```

On Windows, use `py -m venv venv`, then `venv\Scripts\pip install -r dev\requirements.txt`, and create an empty file `venv\.gdignore`.

**Do not skip the `.gdignore`!**
Godot scans every directory of the project, and would otherwise try to import the thousands of files of the virtual environment.

[gdtoolkit]: https://github.com/Scony/godot-gdscript-toolkit
[black]: https://black.readthedocs.io
[virtual environment]: https://docs.python.org/3/library/venv.html

## Running the game

Open the project in the Godot editor (Import, then select `project.godot`), and press F5.
The game needs a webcam which supports 640x480 in the YUYV format.
Without one, it explains the problem and quits on any key.

Press Escape twice to quit.

## Testing the levels in isolation

Like in [ergo-chaos], the test harness plays a single level at a time.
Open `scenes/tests/game_harness/game_harness.tscn` in the editor and press F6 (run the current scene).
Pick a test and how to play it:

* **Scripted players** play the level by themselves, so the test shows its behavior without anybody in front of the camera.
* **Mouse** makes the mouse the head of the first player.
  Space makes the player leave and come back, and the keys 1 to 9 bring in and send away the bots, which wander around on their own.
* **Camera** plays the level with the webcam.

To add a test level:

1. Create `scenes/tests/levels/test_<name>/test_<name>.tscn`, usually inheriting from `scenes/levels/base/base.tscn`, and put the enemies under `Enemies`.
   Override the exported properties to isolate the behavior.
   For example, a saucer with `speed = 0` and a huge `max_energy` makes a training dummy.
   Disable the supply drops if you do not need them, and enable the treasure chests (`ChestDrops`) if you need them.
2. Script the players in `test_<name>_players.gd`, extending `ScriptedHeads` (`scenes/tests/scripted_heads/scripted_heads.gd`) and overriding `_play` with the helpers like `appear`, `glide`, `chase` and `lose`.
3. Register the test in `scenes/tests/game_harness/game_harness.gd`.
4. Add the expected behavior to `tests/godot/test_harness_levels.gd`, so that the automatic tests check it as well.

## Pre-commit checks

Before you commit, run:

```
venv/bin/python dev/continuous_integration/precommit.py --overwrite
```

The script:

1. re-formats the code (`reformat`): the GDScripts with `gdformat` (configured in `gdformatrc`), the C# code with `dotnet format` and the Python scripts in `dev/` with `black`,
2. lints the GDScripts with `gdlint` (`lint`),
3. runs the C# unit tests (`dotnet-test`),
4. builds the C# part of the game, so that Godot can load it (`build`),
5. imports the project with Godot (`import`),
6. type-checks every GDScript with Godot (`check-scripts`), and
7. runs the Godot tests in `tests/godot/` (`godot-test`).

Without `--overwrite`, the script only checks the formatting and changes no files.
This is what the continuous integration runs.

Re-run only some steps with `--select`, or leave some out with `--skip`, e.g.:

```
venv/bin/python dev/continuous_integration/precommit.py --select godot-test
venv/bin/python dev/continuous_integration/precommit.py --skip reformat dotnet-test
```

Run only some of the Godot tests with `--only`, and see the output of the passed tests too with `--verbose`:

```
venv/bin/python dev/continuous_integration/precommit.py --select godot-test --only combat --verbose
```

Pass `--godot` if you do not want to set the `GODOT` environment variable.

### The Godot tests

Each Godot test in `tests/godot/test_*.gd` is a script extending `SceneTree`, which plays the game headless, checks the behavior, prints `RESULT: OK` and quits with zero on success.
The directory `tests/` contains a `.gdignore`, so that Godot does not import the tests as part of the game.

We run the tests with `--fixed-fps 60`: Godot then advances the game by exactly 1/60 of a second per frame, and runs the frames as fast as it can instead of waiting for the wall clock.
A minute of play takes only a second or two to test, and the physics stays the same as in the real game.
We run the tests in parallel.

To run a single test directly:

```
$GODOT --headless --fixed-fps 60 --path . --script tests/godot/test_combat.gd
```

## Continuous integration

GitHub Actions runs the pre-commit checks (without `--overwrite`) on every pull request and on every push to `main`; see `.github/workflows/ci.yaml`.
It installs the same versions of .NET, Godot and the Python tools as described above.

## Publishing a release

When you publish a release on GitHub, the workflow `.github/workflows/publish.yaml` exports the game for Linux, Windows and macOS, zips each package, and attaches the zips to the release.
The export presets live in `export_presets.cfg`.
They include the ONNX models explicitly (`include_filter`), since Godot does not export them as resources otherwise.

Each package carries our license, [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and the license texts of the components we distribute (Godot Engine, ONNX Runtime and the models) in `licenses/`.
When you add a third-party component, list it in the notices.
When you upgrade Godot, regenerate its license texts in `licenses/godot/`:

```
$GODOT --headless --script dev/write_godot_licenses.gd
```

The script has a shebang, so if `godot` is on your path, you can also run `dev/write_godot_licenses.gd` directly.

You can also start the workflow by hand in the Actions tab to try out the packaging.
The packages are then only uploaded as the artifacts of the workflow run.

To export locally, install the .NET export templates of Godot 4.6.2 (in the editor: Editor, Manage Export Templates), and run, e.g.:

```
mkdir -p build/linux
$GODOT --headless --path . --export-release "Linux" build/linux/head-invaders.x86_64
```

The macOS app is universal, but ONNX Runtime provides its native library only for Apple Silicon, so the head tracking does not work on Intel Macs.
The macOS app is not notarized, so the players have to allow it in the system settings on the first start.

## Commit messages

We follow Chris Beams' [guidelines on commit messages]:

1) Separate subject from body with a blank line
2) Limit the subject line to 50 characters
3) Capitalize the subject line
4) Do not end the subject line with a period
5) Use the imperative mood in the subject line
6) Wrap the body at 72 characters
7) Use the body to explain *what* and *why* vs. *how*

[guidelines on commit messages]: https://chris.beams.io/posts/git-commit/
