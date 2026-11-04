using System;
using System.Collections.Generic;
using System.Linq;

using HeadInvaders.Tracking;
using Xunit;

namespace HeadInvaders.Tests
{
    public class OsNetModelTests
    {
        private const int _width = TestData.Width;
        private const int _height = TestData.Height;

        [Fact]
        public void Test_that_the_embedding_is_normalized()
        {
            using var osNet = new OsNetModel(TestData.LoadModel(TestData.OsNet));
            var frame = TestData.LoadFrame("astronaut_640x480.png");

            var embedding = osNet.Embed(frame, new PixelRect(160f, 0f, 520f, 480f));

            Assert.Equal(512, embedding.Length);
            Assert.Equal(1f, OsNetModel.CosineSimilarity(embedding, embedding), 1e-4f);
        }

        /// <summary>
        /// Check that a player looks like themselves when the crop moves a bit,
        /// and unlike the other players.
        /// </summary>
        /// <remarks>
        /// The tracker gives a returning player the identity of the most similar
        /// lost player, so each player must look the most like themselves.
        /// </remarks>
        [Fact]
        public void Test_that_players_are_told_apart_in_the_crew_photo()
        {
            using var yolox = new YoloxModel(TestData.LoadModel(TestData.Yolox));
            using var osNet = new OsNetModel(TestData.LoadModel(TestData.OsNet));
            var frame = TestData.LoadFrame("crew_of_six_640x480.png");

            var result = yolox.Detect(frame);
            var crops = result.Heads
                .Where(h => h.Score >= 0.5f)
                .Select(h => PlayerCrop.For(h, result.Bodies, _width, _height))
                .Where(c => c.HasValue)
                .Select(c => c!.Value)
                .ToList();

            Assert.True(crops.Count >= 4, $"Expected at least 4 players, got {crops.Count}.");

            var embeddings = crops.Select(c => osNet.Embed(frame, c)).ToList();

            var same = new List<float>();
            for (int i = 0; i < crops.Count; i++)
            {
                var c = crops[i];
                var shifted = new PixelRect(
                    c.X1 + 0.08f * c.Width, c.Y1, c.X2 + 0.08f * c.Width, c.Y2
                ).ClampTo(_width, _height);

                same.Add(OsNetModel.CosineSimilarity(embeddings[i], osNet.Embed(frame, shifted)));
            }

            var different = new List<float>();
            for (int i = 0; i < crops.Count; i++)
            {
                float mostSimilarOther = float.NegativeInfinity;
                for (int j = 0; j < crops.Count; j++)
                {
                    if (j != i)
                    {
                        mostSimilarOther = System.Math.Max(
                            mostSimilarOther,
                            OsNetModel.CosineSimilarity(embeddings[i], embeddings[j])
                        );
                    }
                }
                different.Add(mostSimilarOther);
            }

            string summary = (
                $"same: [{string.Join(", ", same.Select(s => s.ToString("F2")))}], " +
                $"different: [{string.Join(", ", different.Select(s => s.ToString("F2")))}]"
            );

            for (int i = 0; i < crops.Count; i++)
            {
                Assert.True(
                    same[i] > different[i],
                    $"Player {i} looks more like somebody else; {summary}"
                );
            }
        }

        [Fact]
        public void Test_that_the_crop_uses_the_body_with_the_head_on_top()
        {
            var head = new Detection(0.40f, 0.10f, 0.50f, 0.25f, 0.9f);
            var bodies = new[]
            {
                // NOTE (mristin):
                // This body contains the head, but the head is not on its top.
                new Detection(0.30f, 0.00f, 0.70f, 0.30f, 0.9f),
                new Detection(0.35f, 0.08f, 0.55f, 0.95f, 0.9f),
                new Detection(0.70f, 0.10f, 0.90f, 0.90f, 0.9f),
            };

            var crop = PlayerCrop.For(head, bodies, _width, _height);

            Assert.True(crop.HasValue);
            var expected = PixelRect.FromMirrored(bodies[1], _width, _height);
            Assert.Equal(expected.X1, crop!.Value.X1, 1e-3f);
            Assert.Equal(expected.Y1, crop.Value.Y1, 1e-3f);
            Assert.Equal(expected.X2, crop.Value.X2, 1e-3f);
            Assert.Equal(expected.Y2, crop.Value.Y2, 1e-3f);
        }

        [Fact]
        public void Test_that_the_crop_falls_back_to_the_region_below_the_head()
        {
            var head = new Detection(0.40f, 0.10f, 0.50f, 0.25f, 0.9f);

            var crop = PlayerCrop.For(head, Array.Empty<Detection>(), _width, _height);

            Assert.True(crop.HasValue);
            var headRect = PixelRect.FromMirrored(head, _width, _height);

            Assert.True(crop!.Value.X1 < headRect.X1 && crop.Value.X2 > headRect.X2);
            Assert.True(crop.Value.Y1 <= headRect.Y1);
            Assert.True(crop.Value.Y2 > headRect.Y2 + 2f * headRect.Height);
        }

        [Fact]
        public void Test_that_the_crop_is_unmirrored()
        {
            // NOTE (mristin):
            // A head on the left of the mirrored frame is on the right of the
            // original frame, which we crop from.
            var head = new Detection(0.05f, 0.10f, 0.15f, 0.25f, 0.9f);

            var crop = PlayerCrop.For(head, Array.Empty<Detection>(), _width, _height);

            Assert.True(crop.HasValue);
            Assert.True(crop!.Value.X1 > _width / 2f);
        }
    }
}
