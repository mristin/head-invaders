using System.Linq;

using HeadInvaders.Tracking;
using Xunit;

namespace HeadInvaders.Tests
{
    public class YoloxModelTests
    {
        private const int _width = TestData.Width;
        private const int _height = TestData.Height;

        private static YoloxModel LoadModel()
        {
            return new YoloxModel(TestData.LoadModel(TestData.Yolox));
        }

        /// <summary>Convert a box in pixels of the mirrored frame to a detection.</summary>
        private static Detection Mirrored(float x1, float y1, float x2, float y2)
        {
            return new Detection(x1 / _width, y1 / _height, x2 / _width, y2 / _height, 1f);
        }

        private static string Describe(Detection detection)
        {
            return $"({detection.X1 * _width:F0}, {detection.Y1 * _height:F0}) - " +
                $"({detection.X2 * _width:F0}, {detection.Y2 * _height:F0}) " +
                $"score {detection.Score:F2}";
        }

        [Fact]
        public void Test_that_the_input_size_is_read_from_the_model()
        {
            using var model = LoadModel();

            Assert.Equal(320, model.InputWidth);
            Assert.Equal(256, model.InputHeight);
        }

        [Fact]
        public void Test_that_the_whole_head_and_the_body_are_detected_in_mirrored_coordinates()
        {
            using var model = LoadModel();
            var frame = TestData.LoadFrame("astronaut_640x480.png");

            var result = model.Detect(frame);

            var head = Assert.Single(result.Heads);
            Assert.True(head.Score > 0.8f, $"Expected a confident head, got {Describe(head)}.");

            // NOTE (mristin):
            // We determined the expected box visually, in pixels of the mirrored
            // frame. Unlike UltraFace, the box covers the whole head including the
            // hair, not only the face.
            var expectedHead = Mirrored(188f, 5f, 343f, 182f);
            float iou = Detection.IntersectionOverUnion(head, expectedHead);
            Assert.True(iou > 0.8f, $"Expected the box to cover the head, IoU {iou}; got {Describe(head)}.");

            var body = Assert.Single(result.Bodies);
            Assert.True(
                body.Contains(head.CenterX, head.CenterY),
                $"Expected the body {Describe(body)} to contain the head {Describe(head)}."
            );
        }

        [Fact]
        public void Test_that_heads_seen_from_behind_are_detected()
        {
            using var model = LoadModel();
            var frame = TestData.LoadFrame("mission_control_from_behind_640x480.png");

            var heads = model.Detect(frame).Heads;
            var confident = heads.Where(h => h.Score >= 0.5f).ToList();

            Assert.True(
                confident.Count >= 4,
                $"Expected at least 4 confident heads, but got: " +
                string.Join("; ", heads.Select(Describe))
            );

            // NOTE (mristin):
            // The two flight controllers in the foreground face away from the
            // camera; a face detector can not find them at all.
            foreach (var expected in new[]
            {
                Mirrored(469f, 332f, 590f, 452f),
                Mirrored(179f, 352f, 300f, 456f),
            })
            {
                Assert.Contains(
                    confident,
                    h => Detection.IntersectionOverUnion(h, expected) > 0.6f
                );
            }
        }

        [Fact]
        public void Test_that_nothing_is_detected_on_a_blank_frame()
        {
            using var model = LoadModel();
            var frame = new Frame(new byte[_width * _height * 3], _width, _height, 0.0);

            var result = model.Detect(frame);

            Assert.Empty(result.Heads);
            Assert.Empty(result.Bodies);
        }

        [Fact]
        public void Test_that_preprocess_converts_to_planar_bgr_without_normalization()
        {
            var rgb = new byte[_width * _height * 3];
            for (int i = 0; i < _width * _height; i++)
            {
                rgb[i * 3] = 200;
                rgb[i * 3 + 1] = 100;
                rgb[i * 3 + 2] = 50;
            }

            var target = new float[3 * 320 * 256];
            YoloxModel.Preprocess(new Frame(rgb, _width, _height, 0.0), target, 320, 256);

            int plane = 320 * 256;
            Assert.All(target.Take(plane), v => Assert.Equal(50f, v, 1e-3f));
            Assert.All(target.Skip(plane).Take(plane), v => Assert.Equal(100f, v, 1e-3f));
            Assert.All(target.Skip(2 * plane), v => Assert.Equal(200f, v, 1e-3f));
        }
    }
}
