using System;
using System.Linq;

using HeadInvaders.Tracking;
using Xunit;

namespace HeadInvaders.Tests
{
    public class UltraFaceModelTests
    {
        private const int _width = TestData.Width;
        private const int _height = TestData.Height;

        private static UltraFaceModel LoadModel()
        {
            return new UltraFaceModel(TestData.LoadModel(TestData.UltraFace));
        }

        [Fact]
        public void Test_that_the_face_on_the_portrait_is_detected_in_mirrored_coordinates()
        {
            using var model = LoadModel();

            // NOTE (mristin):
            // The portrait is the public-domain NASA photo of Eileen Collins
            // ("astronaut" from scikit-image), resized to 480x480 and pasted at
            // x = 160 into a black 640x480 frame, like a webcam frame.
            var frame = TestData.LoadFrame("astronaut_640x480.png");

            var detections = model.DetectFaces(frame);

            var detection = Assert.Single(detections);
            Assert.True(
                detection.Score > 0.9f,
                $"Expected a confident detection, but got score {detection.Score}."
            );

            // NOTE (mristin):
            // We determined the expected box visually, in pixels of the mirrored
            // frame (what the overlay shows). In the original, unmirrored frame the
            // face is on the right of the center, so it must end up on the left.
            var expected = new Detection(
                230f / _width, 61f / _height, 312f / _width, 163f / _height, 1f
            );

            float iou = Detection.IntersectionOverUnion(detection, expected);
            Assert.True(
                iou > 0.8f,
                $"Expected the box to cover the face, but IoU is {iou}; got " +
                $"({detection.X1 * _width:F0}, {detection.Y1 * _height:F0}) - " +
                $"({detection.X2 * _width:F0}, {detection.Y2 * _height:F0}) in pixels."
            );

            Assert.InRange(detection.CenterX * _width, 261f, 281f);
            Assert.InRange(detection.CenterY * _height, 102f, 122f);
        }

        [Fact]
        public void Test_that_nothing_is_detected_on_a_blank_frame()
        {
            using var model = LoadModel();

            var frame = new Frame(new byte[_width * _height * 3], _width, _height, 0.0);

            Assert.Empty(model.Detect(frame).Heads);
        }

        [Fact]
        public void Test_that_preprocess_normalizes_to_planar_rgb()
        {
            // NOTE (mristin):
            // A uniform frame must survive the resizing unchanged, so we can check
            // the normalization and the channel planes exactly.
            var rgb = new byte[_width * _height * 3];
            for (int i = 0; i < _width * _height; i++)
            {
                rgb[i * 3] = 255;
                rgb[i * 3 + 1] = 127;
                rgb[i * 3 + 2] = 0;
            }

            var target = new float[3 * UltraFaceModel.InputWidth * UltraFaceModel.InputHeight];
            UltraFaceModel.Preprocess(new Frame(rgb, _width, _height, 0.0), target);

            int plane = UltraFaceModel.InputWidth * UltraFaceModel.InputHeight;

            Assert.All(target.Take(plane), v => Assert.Equal(1f, v, 1e-5f));
            Assert.All(target.Skip(plane).Take(plane), v => Assert.Equal(0f, v, 1e-5f));
            Assert.All(target.Skip(2 * plane), v => Assert.Equal(-127f / 128f, v, 1e-5f));
        }

        [Fact]
        public void Test_that_non_maximum_suppression_keeps_the_best_of_overlapping_boxes()
        {
            var candidates = new[]
            {
                new Detection(0.10f, 0.10f, 0.30f, 0.30f, 0.80f),
                new Detection(0.11f, 0.11f, 0.31f, 0.31f, 0.95f),
                new Detection(0.60f, 0.60f, 0.80f, 0.80f, 0.75f),
            }.ToList();

            var kept = NonMaximumSuppression.Apply(candidates, 0.3f, 10);

            Assert.Equal(2, kept.Count);
            Assert.Equal(0.95f, kept[0].Score);
            Assert.Equal(0.75f, kept[1].Score);
        }
    }
}
