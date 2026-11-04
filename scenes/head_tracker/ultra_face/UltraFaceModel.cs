using System;
using System.Collections.Generic;
using System.Linq;

using Microsoft.ML.OnnxRuntime;
using Microsoft.ML.OnnxRuntime.Tensors;

// NOTE (mristin):
// This file must not depend on Godot so that we can unit-test the face detection
// outside of the engine. See tests/HeadInvaders.Tests.
//
// We keep UltraFace as a fast fallback for YOLOX; it only sees frontal faces.

namespace HeadInvaders.Tracking
{
    /// <summary>Detect faces with the UltraFace model.</summary>
    /// <remarks>
    /// <para>
    /// See: https://github.com/Linzaer/Ultra-Light-Fast-Generic-Face-Detector-1MB
    /// </para>
    ///
    /// <para>
    /// The instance is not thread-safe; use it from a single thread only.
    /// </para>
    /// </remarks>
    public sealed class UltraFaceModel : IHeadDetector
    {
        // NOTE (mristin):
        // We hard-code these to match the RFB-320 variant of the model.
        public const int InputWidth = 320;
        public const int InputHeight = 240;

        private const string _inputName = "input";

        public float ScoreThreshold = 0.7f;
        public float IouThreshold = 0.3f;
        public int MaxDetections = 8;

        private readonly InferenceSession _session;

        // NOTE (mristin):
        // We pre-allocate the buffers to avoid the GC pressure.
        private readonly float[] _inputData = new float[1 * 3 * InputHeight * InputWidth];
        private readonly List<NamedOnnxValue> _inputs;

        public UltraFaceModel(byte[] model)
        {
            OnnxRuntimePrivacy.DisableTelemetry();

            using var options = new SessionOptions
            {
                GraphOptimizationLevel = GraphOptimizationLevel.ORT_ENABLE_ALL,

                // NOTE (mristin):
                // The model lists its initializers as graph inputs, which makes
                // the runtime warn about every single one of them.
                LogSeverityLevel = OrtLoggingLevel.ORT_LOGGING_LEVEL_ERROR,
            };
            _session = new InferenceSession(model, options);

            if (!_session.InputMetadata.ContainsKey(_inputName))
            {
                _session.Dispose();
                throw new InvalidOperationException(
                    $"Expected the model to have the input {_inputName}, but got: " +
                    string.Join(", ", _session.InputMetadata.Keys)
                );
            }

            var inputTensor = new DenseTensor<float>(
                _inputData,
                new[] { 1, 3, InputHeight, InputWidth }
            );
            _inputs = new List<NamedOnnxValue>
            {
                NamedOnnxValue.CreateFromTensor(_inputName, inputTensor)
            };
        }

        /// <summary>Detect the faces in the frame.</summary>
        /// <remarks>
        /// UltraFace only detects faces, so we report them as heads and do not
        /// detect any bodies.
        /// </remarks>
        public DetectionResult Detect(Frame frame)
        {
            return new DetectionResult(DetectFaces(frame), new List<Detection>());
        }

        /// <summary>Detect the faces in the frame.</summary>
        /// <returns>
        /// Mirrored detections, sorted by descending score.
        /// </returns>
        public List<Detection> DetectFaces(Frame frame)
        {
            Preprocess(frame, _inputData);

            using var results = _session.Run(_inputs);

            var scores = results.First(r => r.Name == "scores").AsTensor<float>();
            var boxes = results.First(r => r.Name == "boxes").AsTensor<float>();

            return Postprocess(
                scores, boxes, ScoreThreshold, IouThreshold, MaxDetections
            );
        }

        public void Dispose()
        {
            _session.Dispose();
        }

        /// <summary>
        /// Resize the RGB8 frame to the model input and convert it to normalized
        /// planar floats, all in a single pass.
        /// </summary>
        public static void Preprocess(Frame frame, float[] target)
        {
            byte[] source = frame.Rgb;
            int sourceWidth = frame.Width;
            int sourceHeight = frame.Height;

            if (target.Length != 3 * InputWidth * InputHeight)
            {
                throw new ArgumentException(
                    $"Expected the target of length {3 * InputWidth * InputHeight}, " +
                    $"but got {target.Length}.",
                    nameof(target)
                );
            }

            float scaleX = (float)sourceWidth / InputWidth;
            float scaleY = (float)sourceHeight / InputHeight;

            int planeSize = InputWidth * InputHeight;

            for (int y = 0; y < InputHeight; y++)
            {
                // NOTE (mristin):
                // We sample at the pixel centers. For the usual 2x down-scaling of
                // 640x480 to 320x240, the bilinear interpolation then averages
                // exactly the 2x2 source block.
                float srcY = Math.Clamp(
                    (y + 0.5f) * scaleY - 0.5f, 0f, sourceHeight - 1
                );
                int y0 = (int)srcY;
                int y1 = Math.Min(y0 + 1, sourceHeight - 1);
                float fy = srcY - y0;

                for (int x = 0; x < InputWidth; x++)
                {
                    float srcX = Math.Clamp(
                        (x + 0.5f) * scaleX - 0.5f, 0f, sourceWidth - 1
                    );
                    int x0 = (int)srcX;
                    int x1 = Math.Min(x0 + 1, sourceWidth - 1);
                    float fx = srcX - x0;

                    int idx00 = (y0 * sourceWidth + x0) * 3;
                    int idx01 = (y0 * sourceWidth + x1) * 3;
                    int idx10 = (y1 * sourceWidth + x0) * 3;
                    int idx11 = (y1 * sourceWidth + x1) * 3;

                    int targetIndex = y * InputWidth + x;

                    for (int c = 0; c < 3; c++)
                    {
                        float p0 = source[idx00 + c] * (1f - fx) + source[idx01 + c] * fx;
                        float p1 = source[idx10 + c] * (1f - fx) + source[idx11 + c] * fx;
                        float p = p0 * (1f - fy) + p1 * fy;

                        // NOTE (mristin):
                        // UltraFace expects RGB normalized as (pixel - 127) / 128.
                        target[c * planeSize + targetIndex] = (p - 127f) / 128f;
                    }
                }
            }
        }

        /// <summary>Decode the model outputs into mirrored, normalized detections.</summary>
        public static List<Detection> Postprocess(
            Tensor<float> scores,
            Tensor<float> boxes,
            float scoreThreshold,
            float iouThreshold,
            int maxDetections
        )
        {
            // NOTE (mristin):
            // We expect scores as [1, N, 2] (background, face) and boxes as
            // [1, N, 4] with already decoded corners (x1, y1, x2, y2) normalized
            // to [0, 1].
            int count = scores.Dimensions[1];

            var candidates = new List<Detection>();
            for (int i = 0; i < count; i++)
            {
                float score = scores[0, i, 1];
                if (score < scoreThreshold)
                {
                    continue;
                }

                float x1 = Math.Clamp(boxes[0, i, 0], 0f, 1f);
                float y1 = Math.Clamp(boxes[0, i, 1], 0f, 1f);
                float x2 = Math.Clamp(boxes[0, i, 2], 0f, 1f);
                float y2 = Math.Clamp(boxes[0, i, 3], 0f, 1f);

                if (x2 <= x1 || y2 <= y1)
                {
                    continue;
                }

                // NOTE (mristin):
                // We mirror the detections so that they match the mirrored overlay.
                candidates.Add(new Detection(1f - x2, y1, 1f - x1, y2, score));
            }

            return NonMaximumSuppression.Apply(
                candidates, iouThreshold, maxDetections
            );
        }
    }
}  // namespace HeadInvaders.Tracking
