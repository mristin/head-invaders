# Third-party notices

Head Invaders is licensed under the MIT License; see [LICENSE](LICENSE).
This covers the code, the shaders, the scenes and all the creatures, worlds and bosses, which the game draws in code.

The game includes, or is built with, the following third-party components.
Each keeps its own license.
The release packages carry all the license texts in the directory `licenses/`.

## Distributed with the game

### Godot Engine

* Version: 4.6.2 (.NET)
* License: MIT
* Copyright (c) 2014-present Godot Engine contributors; Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur
* Source: https://godotengine.org
* License text: [licenses/godot/LICENSE.txt](licenses/godot/LICENSE.txt)

Godot Engine itself includes third-party components under their own licenses, e.g., FreeType, the fonts and the image libraries.
Their notices are in [licenses/godot/COPYRIGHT.txt](licenses/godot/COPYRIGHT.txt), generated from the Godot binary with `dev/write_godot_licenses.gd`.

### .NET runtime

* License: MIT
* Copyright (c) .NET Foundation and Contributors
* Source: https://github.com/dotnet/runtime
* Third-party notices: https://github.com/dotnet/runtime/blob/main/THIRD-PARTY-NOTICES.TXT

The .NET build of Godot bundles the .NET runtime with the exported game.

### ONNX Runtime

* Package: `Microsoft.ML.OnnxRuntime` 1.24.4
* License: MIT
* Copyright (c) Microsoft Corporation
* Source: https://github.com/microsoft/onnxruntime
* License text and third-party notices: included in the release packages as `licenses/onnxruntime/LICENSE` and `licenses/onnxruntime/ThirdPartyNotices.txt`

### YOLOX-Body-Head-Hand-Face (head and body detection)

* File: `scenes/head_tracker/yolox/model/yolox_n_body_head_hand_face_post_1x3x256x320.onnx`
* License: Apache License 2.0
* Source: https://github.com/PINTO0309/PINTO_model_zoo/tree/main/434_YOLOX-Body-Head-Hand-Face, based on YOLOX by Megvii (https://github.com/Megvii-BaseDetection/YOLOX)
* License text: [scenes/head_tracker/yolox/model/LICENSE](scenes/head_tracker/yolox/model/LICENSE)

We distribute the model unmodified.

### OSNet (recognizing the returning players)

* File: `scenes/head_tracker/osnet/model/osnet_x0_25_msmt17.onnx`
* License: MIT
* Copyright (c) 2018 Kaiyang Zhou
* Source: https://github.com/KaiyangZhou/deep-person-reid
* License text: [scenes/head_tracker/osnet/model/LICENSE](scenes/head_tracker/osnet/model/LICENSE)

Note that the weights were trained on the MSMT17 dataset, which its authors license for research only.
Whether this restriction carries over to the trained weights is unclear.
Please take it into account before any commercial use of the game.

### UltraFace (frontal face detection)

* File: `scenes/head_tracker/ultra_face/model/version-RFB-320.onnx`
* License: MIT
* Copyright (c) 2019 linzai
* Source: https://github.com/Linzaer/Ultra-Light-Fast-Generic-Face-Detector-1MB
* License text: [scenes/head_tracker/ultra_face/model/LICENSE](scenes/head_tracker/ultra_face/model/LICENSE)

## Used only for development, not distributed

| Component | Version | License | Source |
|---|---|---|---|
| xUnit.net (`xunit`, `xunit.runner.visualstudio`) | 2.9.3, 4.0.1 | Apache-2.0 | https://xunit.net |
| Microsoft.NET.Test.Sdk | 18.11.0 | MIT | https://github.com/microsoft/vstest |
| StbImageSharp | 2.30.16 | Unlicense or MIT | https://github.com/StbSharp/StbImageSharp |
| gdtoolkit (`gdformat`, `gdlint`) | 4.5.0 | MIT | https://github.com/Scony/godot-gdscript-toolkit |
| black | 24.10.0 | MIT | https://github.com/psf/black |

The test photos in `tests/HeadInvaders.Tests/data/` are public-domain NASA photos: the scikit-image "astronaut" (Eileen Collins), "Flight Controllers in Mission Control Center during splashdown of Apollo 14" (S71-18400), and "Expedition 38 crew members pose for an in-flight crew portrait" (ISS038-E-054970).
