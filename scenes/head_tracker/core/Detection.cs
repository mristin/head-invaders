using System;
using System.Collections.Generic;

// NOTE (mristin):
// This file must not depend on Godot so that we can unit-test the head tracking
// outside of the engine. See tests/HeadInvaders.Tests.

namespace HeadInvaders.Tracking
{
    /// <summary>Represent a single box detected by a model.</summary>
    /// <remarks>
    /// The coordinates are normalized to [0, 1] with respect to the
    /// <em>mirrored</em> camera image, so that the left of the image corresponds
    /// to the left of the player looking at the screen.
    /// </remarks>
    public readonly struct Detection
    {
        public readonly float X1;
        public readonly float Y1;
        public readonly float X2;
        public readonly float Y2;
        public readonly float Score;

        public Detection(float x1, float y1, float x2, float y2, float score)
        {
            X1 = x1;
            Y1 = y1;
            X2 = x2;
            Y2 = y2;
            Score = score;
        }

        public float Width => X2 - X1;
        public float Height => Y2 - Y1;
        public float CenterX => (X1 + X2) * 0.5f;
        public float CenterY => (Y1 + Y2) * 0.5f;
        public float Area => Math.Max(0f, Width) * Math.Max(0f, Height);

        public bool Contains(float x, float y)
        {
            return x >= X1 && x <= X2 && y >= Y1 && y <= Y2;
        }

        public static float IntersectionOverUnion(Detection a, Detection b)
        {
            float x1 = Math.Max(a.X1, b.X1);
            float y1 = Math.Max(a.Y1, b.Y1);
            float x2 = Math.Min(a.X2, b.X2);
            float y2 = Math.Min(a.Y2, b.Y2);

            float intersection = Math.Max(0f, x2 - x1) * Math.Max(0f, y2 - y1);
            float union = a.Area + b.Area - intersection;

            return union > 0f ? intersection / union : 0f;
        }
    }

    public static class NonMaximumSuppression
    {
        /// <summary>
        /// Greedily keep the best-scoring detections and drop the ones that overlap
        /// them too much.
        /// </summary>
        public static List<Detection> Apply(
            List<Detection> candidates,
            float iouThreshold,
            int maxCount
        )
        {
            candidates.Sort((a, b) => b.Score.CompareTo(a.Score));

            var kept = new List<Detection>();
            foreach (var candidate in candidates)
            {
                if (kept.Count >= maxCount)
                {
                    break;
                }

                bool overlaps = false;
                foreach (var other in kept)
                {
                    if (Detection.IntersectionOverUnion(candidate, other) > iouThreshold)
                    {
                        overlaps = true;
                        break;
                    }
                }

                if (!overlaps)
                {
                    kept.Add(candidate);
                }
            }

            return kept;
        }
    }

    /// <summary>Hold a camera frame copied out of the engine.</summary>
    public sealed class Frame
    {
        /// <summary>Pixels as RGB8, row by row, <em>not</em> mirrored.</summary>
        public readonly byte[] Rgb;
        public readonly int Width;
        public readonly int Height;
        public readonly double Timestamp;

        public Frame(byte[] rgb, int width, int height, double timestamp)
        {
            if (rgb.Length < width * height * 3)
            {
                throw new ArgumentException(
                    $"Expected an RGB8 frame of {width}x{height}, " +
                    $"but got only {rgb.Length} bytes.",
                    nameof(rgb)
                );
            }

            Rgb = rgb;
            Width = width;
            Height = height;
            Timestamp = timestamp;
        }

        /// <summary>
        /// Sample the frame bilinearly at the given (not mirrored) pixel position.
        /// </summary>
        public float Sample(float x, float y, int channel)
        {
            x = Math.Clamp(x, 0f, Width - 1);
            y = Math.Clamp(y, 0f, Height - 1);

            int x0 = (int)x;
            int y0 = (int)y;
            int x1 = Math.Min(x0 + 1, Width - 1);
            int y1 = Math.Min(y0 + 1, Height - 1);
            float fx = x - x0;
            float fy = y - y0;

            float p00 = Rgb[(y0 * Width + x0) * 3 + channel];
            float p01 = Rgb[(y0 * Width + x1) * 3 + channel];
            float p10 = Rgb[(y1 * Width + x0) * 3 + channel];
            float p11 = Rgb[(y1 * Width + x1) * 3 + channel];

            float p0 = p00 * (1f - fx) + p01 * fx;
            float p1 = p10 * (1f - fx) + p11 * fx;
            return p0 * (1f - fy) + p1 * fy;
        }
    }

    /// <summary>Hold everything a detector found in a frame.</summary>
    public sealed class DetectionResult
    {
        public readonly List<Detection> Heads;

        /// <summary>
        /// Whole bodies, if the detector supports them. We use them to crop the
        /// players for the re-identification.
        /// </summary>
        public readonly List<Detection> Bodies;

        public DetectionResult(List<Detection> heads, List<Detection> bodies)
        {
            Heads = heads;
            Bodies = bodies;
        }
    }

    /// <summary>Detect the heads of the players in a frame.</summary>
    public interface IHeadDetector : IDisposable
    {
        DetectionResult Detect(Frame frame);
    }
}  // namespace HeadInvaders.Tracking
