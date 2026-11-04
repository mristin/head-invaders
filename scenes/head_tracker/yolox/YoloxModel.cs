using System;
using System.Collections.Generic;
using System.Linq;

using Microsoft.ML.OnnxRuntime;
using Microsoft.ML.OnnxRuntime.Tensors;

// NOTE (mristin):
// This file must not depend on Godot so that we can unit-test the head detection
// outside of the engine. See tests/HeadInvaders.Tests.

namespace HeadInvaders.Tracking
{
    /// <summary>
    /// Detect heads (from any side, not only faces) and bodies with
    /// YOLOX-Body-Head-Hand-Face.
    /// </summary>
    /// <remarks>
    /// <para>
    /// See: https://github.com/PINTO0309/PINTO_model_zoo/tree/main/434_YOLOX-Body-Head-Hand-Face
    /// </para>
    ///
    /// <para>
    /// We use the variant with the built-in post-processing ("post"), so the model
    /// already applies the non-maximum suppression. It keeps at most 20 boxes per
    /// class and drops the boxes scoring below 0.25.
    /// </para>
    ///
    /// <para>
    /// The instance is not thread-safe; use it from a single thread only.
    /// </para>
    /// </remarks>
    public sealed class YoloxModel : IHeadDetector
    {
        public const int ClassBody = 0;
        public const int ClassHead = 1;
        public const int ClassHand = 2;
        public const int ClassFace = 3;

        /// <summary>
        /// Drop the boxes below this score.
        /// </summary>
        /// <remarks>
        /// We keep this low on purpose. The tracker continues the known heads with
        /// the weak detections, but starts new heads only from the strong ones.
        /// </remarks>
        public float ScoreThreshold = 0.25f;

        public readonly int InputWidth;
        public readonly int InputHeight;

        private readonly InferenceSession _session;
        private readonly string _outputName;

        // NOTE (mristin):
        // We pre-allocate the buffers to avoid the GC pressure.
        private readonly float[] _inputData;
        private readonly List<NamedOnnxValue> _inputs;

        public YoloxModel(byte[] model)
        {
            OnnxRuntimePrivacy.DisableTelemetry();

            using var options = new SessionOptions
            {
                GraphOptimizationLevel = GraphOptimizationLevel.ORT_ENABLE_ALL,
                LogSeverityLevel = OrtLoggingLevel.ORT_LOGGING_LEVEL_ERROR,
            };
            _session = new InferenceSession(model, options);

            try
            {
                if (_session.InputMetadata.Count != 1 || _session.OutputMetadata.Count != 1)
                {
                    throw new InvalidOperationException(
                        "Expected the YOLOX model with built-in post-processing " +
                        "to have exactly one input and one output, but got " +
                        $"{_session.InputMetadata.Count} input(s) and " +
                        $"{_session.OutputMetadata.Count} output(s)."
                    );
                }

                var input = _session.InputMetadata.First();
                int[] dimensions = input.Value.Dimensions;
                if (dimensions.Length != 4 || dimensions[0] != 1 || dimensions[1] != 3)
                {
                    throw new InvalidOperationException(
                        "Expected the YOLOX input of shape [1, 3, H, W], but got " +
                        $"[{string.Join(", ", dimensions)}]."
                    );
                }

                InputHeight = dimensions[2];
                InputWidth = dimensions[3];
                _outputName = _session.OutputMetadata.Keys.First();

                _inputData = new float[3 * InputHeight * InputWidth];
                var inputTensor = new DenseTensor<float>(
                    _inputData,
                    new[] { 1, 3, InputHeight, InputWidth }
                );
                _inputs = new List<NamedOnnxValue>
                {
                    NamedOnnxValue.CreateFromTensor(input.Key, inputTensor)
                };
            }
            catch
            {
                _session.Dispose();
                throw;
            }
        }

        /// <summary>Detect the heads and the bodies in the frame.</summary>
        /// <returns>Mirrored detections, sorted by descending score.</returns>
        public DetectionResult Detect(Frame frame)
        {
            Preprocess(frame, _inputData, InputWidth, InputHeight);

            using var results = _session.Run(_inputs);
            var output = results.First(r => r.Name == _outputName).AsTensor<float>();

            return Postprocess(output, InputWidth, InputHeight, ScoreThreshold);
        }

        public void Dispose()
        {
            _session.Dispose();
        }

        /// <summary>
        /// Resize the RGB8 frame to the model input and convert it to planar BGR
        /// floats in [0, 255], all in a single pass.
        /// </summary>
        public static void Preprocess(
            Frame frame,
            float[] target,
            int inputWidth,
            int inputHeight
        )
        {
            if (target.Length != 3 * inputWidth * inputHeight)
            {
                throw new ArgumentException(
                    $"Expected the target of length {3 * inputWidth * inputHeight}, " +
                    $"but got {target.Length}.",
                    nameof(target)
                );
            }

            float scaleX = (float)frame.Width / inputWidth;
            float scaleY = (float)frame.Height / inputHeight;
            int planeSize = inputWidth * inputHeight;

            for (int y = 0; y < inputHeight; y++)
            {
                // NOTE (mristin):
                // We sample at the pixel centers, which matches cv2.resize used
                // in the reference implementation.
                float srcY = (y + 0.5f) * scaleY - 0.5f;

                for (int x = 0; x < inputWidth; x++)
                {
                    float srcX = (x + 0.5f) * scaleX - 0.5f;
                    int targetIndex = y * inputWidth + x;

                    // NOTE (mristin):
                    // The model was trained on images loaded with OpenCV, so it
                    // expects the BGR order and no normalization.
                    target[targetIndex] = frame.Sample(srcX, srcY, 2);
                    target[planeSize + targetIndex] = frame.Sample(srcX, srcY, 1);
                    target[2 * planeSize + targetIndex] = frame.Sample(srcX, srcY, 0);
                }
            }
        }

        /// <summary>Decode the model output into mirrored, normalized detections.</summary>
        public static DetectionResult Postprocess(
            Tensor<float> output,
            int inputWidth,
            int inputHeight,
            float scoreThreshold
        )
        {
            // NOTE (mristin):
            // We expect the output as [N, 7] with rows of
            // (batch number, class ID, score, x1, y1, x2, y2), where the box is
            // given in the pixels of the model input.
            if (output.Dimensions.Length != 2 || output.Dimensions[1] != 7)
            {
                throw new InvalidOperationException(
                    "Expected the YOLOX output of shape [N, 7], but got " +
                    $"[{string.Join(", ", output.Dimensions.ToArray())}]."
                );
            }

            var heads = new List<Detection>();
            var bodies = new List<Detection>();

            int count = output.Dimensions[0];
            for (int i = 0; i < count; i++)
            {
                int classId = (int)output[i, 1];
                float score = output[i, 2];

                if (score < scoreThreshold)
                {
                    continue;
                }

                List<Detection> target;
                if (classId == ClassHead)
                {
                    target = heads;
                }
                else if (classId == ClassBody)
                {
                    target = bodies;
                }
                else
                {
                    continue;
                }

                float x1 = Math.Clamp(output[i, 3] / inputWidth, 0f, 1f);
                float y1 = Math.Clamp(output[i, 4] / inputHeight, 0f, 1f);
                float x2 = Math.Clamp(output[i, 5] / inputWidth, 0f, 1f);
                float y2 = Math.Clamp(output[i, 6] / inputHeight, 0f, 1f);

                if (x2 <= x1 || y2 <= y1)
                {
                    continue;
                }

                // NOTE (mristin):
                // We mirror the detections so that they match the mirrored overlay.
                target.Add(new Detection(1f - x2, y1, 1f - x1, y2, score));
            }

            heads.Sort((a, b) => b.Score.CompareTo(a.Score));
            bodies.Sort((a, b) => b.Score.CompareTo(a.Score));

            return new DetectionResult(heads, bodies);
        }
    }
}  // namespace HeadInvaders.Tracking
