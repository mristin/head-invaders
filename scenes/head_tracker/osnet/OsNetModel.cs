using System;
using System.Collections.Generic;
using System.Linq;

using Microsoft.ML.OnnxRuntime;
using Microsoft.ML.OnnxRuntime.Tensors;

// NOTE (mristin):
// This file must not depend on Godot so that we can unit-test the
// re-identification outside of the engine. See tests/HeadInvaders.Tests.

namespace HeadInvaders.Tracking
{
    /// <summary>Represent a rectangle in the pixels of the (not mirrored) frame.</summary>
    public readonly struct PixelRect
    {
        public readonly float X1;
        public readonly float Y1;
        public readonly float X2;
        public readonly float Y2;

        public PixelRect(float x1, float y1, float x2, float y2)
        {
            X1 = x1;
            Y1 = y1;
            X2 = x2;
            Y2 = y2;
        }

        public float Width => X2 - X1;
        public float Height => Y2 - Y1;

        /// <summary>Convert a mirrored, normalized detection to frame pixels.</summary>
        public static PixelRect FromMirrored(Detection detection, int width, int height)
        {
            return new PixelRect(
                (1f - detection.X2) * width,
                detection.Y1 * height,
                (1f - detection.X1) * width,
                detection.Y2 * height
            );
        }

        public PixelRect ClampTo(int width, int height)
        {
            return new PixelRect(
                Math.Clamp(X1, 0f, width),
                Math.Clamp(Y1, 0f, height),
                Math.Clamp(X2, 0f, width),
                Math.Clamp(Y2, 0f, height)
            );
        }
    }

    public static class PlayerCrop
    {
        /// <summary>
        /// Determine the region of the frame which shows the player with the head.
        /// </summary>
        /// <remarks>
        /// We prefer the detected body which contains the head near its top. If
        /// there is none, we take the region below the head, where the torso
        /// usually is. The re-identification works much better on the clothes than
        /// on the head alone.
        /// </remarks>
        /// <param name="head">Mirrored, normalized head detection.</param>
        /// <param name="bodies">Mirrored, normalized body detections.</param>
        /// <returns>The crop in frame pixels, or null if it would be too small.</returns>
        public static PixelRect? For(
            Detection head,
            IReadOnlyList<Detection> bodies,
            int width,
            int height
        )
        {
            Detection? best = null;
            foreach (var body in bodies)
            {
                bool headOnTop = (
                    body.Contains(head.CenterX, head.CenterY)
                    && head.CenterY <= body.Y1 + 0.35f * body.Height
                    && body.Width >= head.Width
                );

                if (headOnTop && (best == null || body.Area < best.Value.Area))
                {
                    best = body;
                }
            }

            PixelRect crop;
            if (best != null)
            {
                crop = PixelRect.FromMirrored(best.Value, width, height);
            }
            else
            {
                var headRect = PixelRect.FromMirrored(head, width, height);
                float centerX = (headRect.X1 + headRect.X2) * 0.5f;
                float halfWidth = 1.2f * headRect.Width;

                crop = new PixelRect(
                    centerX - halfWidth,
                    headRect.Y1 - 0.2f * headRect.Height,
                    centerX + halfWidth,
                    headRect.Y1 + 4.5f * headRect.Height
                );
            }

            crop = crop.ClampTo(width, height);

            // NOTE (mristin):
            // A crop of a few pixels carries no appearance worth comparing.
            if (crop.Width < 8f || crop.Height < 16f)
            {
                return null;
            }

            return crop;
        }
    }

    /// <summary>
    /// Compute the appearance embeddings of the players with OSNet so that we can
    /// recognize them again.
    /// </summary>
    /// <remarks>
    /// <para>
    /// See: https://github.com/KaiyangZhou/deep-person-reid and
    /// https://github.com/PINTO0309/PINTO_model_zoo/tree/main/429_OSNet
    /// </para>
    ///
    /// <para>
    /// The instance is not thread-safe; use it from a single thread only.
    /// </para>
    /// </remarks>
    public sealed class OsNetModel : IDisposable
    {
        // NOTE (mristin):
        // OSNet was trained on person crops of 256x128 (height x width).
        public const int InputWidth = 128;
        public const int InputHeight = 256;

        private static readonly float[] _mean = { 0.485f, 0.456f, 0.406f };
        private static readonly float[] _std = { 0.229f, 0.224f, 0.225f };

        public readonly int EmbeddingSize;

        private readonly InferenceSession _session;
        private readonly string _outputName;

        // NOTE (mristin):
        // We pre-allocate the buffers to avoid the GC pressure.
        private readonly float[] _inputData = new float[3 * InputHeight * InputWidth];
        private readonly List<NamedOnnxValue> _inputs;

        public OsNetModel(byte[] model)
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
                        "Expected the OSNet model to have exactly one input and one " +
                        $"output, but got {_session.InputMetadata.Count} input(s) and " +
                        $"{_session.OutputMetadata.Count} output(s)."
                    );
                }

                var input = _session.InputMetadata.First();
                int[] dimensions = input.Value.Dimensions;
                if (
                    dimensions.Length != 4
                    || dimensions[1] != 3
                    || dimensions[2] != InputHeight
                    || dimensions[3] != InputWidth
                )
                {
                    throw new InvalidOperationException(
                        $"Expected the OSNet input of shape [1, 3, {InputHeight}, " +
                        $"{InputWidth}], but got [{string.Join(", ", dimensions)}]."
                    );
                }

                var output = _session.OutputMetadata.First();
                _outputName = output.Key;
                EmbeddingSize = output.Value.Dimensions.Last();
                if (EmbeddingSize <= 0)
                {
                    throw new InvalidOperationException(
                        "Expected the OSNet output to have a fixed embedding size, " +
                        $"but got [{string.Join(", ", output.Value.Dimensions)}]."
                    );
                }

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

        /// <summary>Compute the L2-normalized embedding of the crop.</summary>
        public float[] Embed(Frame frame, PixelRect crop)
        {
            Preprocess(frame, crop, _inputData);

            using var results = _session.Run(_inputs);
            var output = results.First(r => r.Name == _outputName).AsTensor<float>();

            var embedding = output.ToArray();
            if (embedding.Length != EmbeddingSize)
            {
                throw new InvalidOperationException(
                    $"Expected an embedding of size {EmbeddingSize}, " +
                    $"but got {embedding.Length}."
                );
            }

            Normalize(embedding);
            return embedding;
        }

        public void Dispose()
        {
            _session.Dispose();
        }

        /// <summary>
        /// Resize the crop to the model input and convert it to planar RGB floats
        /// normalized with the ImageNet statistics.
        /// </summary>
        public static void Preprocess(Frame frame, PixelRect crop, float[] target)
        {
            if (target.Length != 3 * InputWidth * InputHeight)
            {
                throw new ArgumentException(
                    $"Expected the target of length {3 * InputWidth * InputHeight}, " +
                    $"but got {target.Length}.",
                    nameof(target)
                );
            }

            float scaleX = crop.Width / InputWidth;
            float scaleY = crop.Height / InputHeight;
            int planeSize = InputWidth * InputHeight;

            for (int y = 0; y < InputHeight; y++)
            {
                float srcY = crop.Y1 + (y + 0.5f) * scaleY - 0.5f;

                for (int x = 0; x < InputWidth; x++)
                {
                    float srcX = crop.X1 + (x + 0.5f) * scaleX - 0.5f;
                    int targetIndex = y * InputWidth + x;

                    for (int c = 0; c < 3; c++)
                    {
                        float value = frame.Sample(srcX, srcY, c) / 255f;
                        target[c * planeSize + targetIndex] = (value - _mean[c]) / _std[c];
                    }
                }
            }
        }

        public static void Normalize(float[] vector)
        {
            double sum = 0.0;
            foreach (var v in vector)
            {
                sum += v * v;
            }

            float norm = (float)Math.Sqrt(sum);
            if (norm < 1e-12f)
            {
                return;
            }

            for (int i = 0; i < vector.Length; i++)
            {
                vector[i] /= norm;
            }
        }

        /// <summary>Compute the cosine similarity of two L2-normalized embeddings.</summary>
        public static float CosineSimilarity(float[] a, float[] b)
        {
            if (a.Length != b.Length)
            {
                throw new ArgumentException(
                    $"Expected embeddings of the same size, but got {a.Length} " +
                    $"and {b.Length}."
                );
            }

            float dot = 0f;
            for (int i = 0; i < a.Length; i++)
            {
                dot += a[i] * b[i];
            }
            return dot;
        }
    }
}  // namespace HeadInvaders.Tracking
