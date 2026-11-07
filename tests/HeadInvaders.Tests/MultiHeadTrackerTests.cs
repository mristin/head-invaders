using System.Collections.Generic;
using System.Linq;
using System.Numerics;

using HeadInvaders.Tracking;
using Xunit;

namespace HeadInvaders.Tests
{
    public class MultiHeadTrackerTests
    {
        private const double _dt = 1.0 / 30.0;
        private static readonly Vector2 _cameraSize = new Vector2(640f, 480f);

        private static Detection Head(float centerX, float centerY, float score = 0.9f)
        {
            const float half = 0.05f;
            return new Detection(
                centerX - half, centerY - half, centerX + half, centerY + half, score
            );
        }

        private static float[] Appearance(params float[] values)
        {
            var embedding = values.ToArray();
            OsNetModel.Normalize(embedding);
            return embedding;
        }

        /// <summary>Record the events of the tracker and feed it the frames.</summary>
        private sealed class Harness
        {
            public readonly MultiHeadTracker Tracker;
            public readonly List<string> Events = new List<string>();
            public readonly Dictionary<int, Vector2> Positions = new Dictionary<int, Vector2>();
            public double Time = 0.0;

            public Harness(MultiHeadTracker? tracker = null)
            {
                Tracker = tracker ?? new MultiHeadTracker();
                Tracker.OnAppeared = (id, position) =>
                {
                    Events.Add($"appeared {id}");
                    Positions[id] = position;
                };
                Tracker.OnMoved = (id, position) =>
                {
                    Events.Add($"moved {id}");
                    Positions[id] = position;
                };
                Tracker.OnLost = id =>
                {
                    Events.Add($"lost {id}");
                    Positions.Remove(id);
                };
            }

            public void Step(EmbedHead? embed, params Detection[] heads)
            {
                Tracker.Update(heads, _cameraSize, Time, embed);
                Time += _dt;
            }

            public void Steps(int count, EmbedHead? embed, params Detection[] heads)
            {
                for (int i = 0; i < count; i++)
                {
                    Step(embed, heads);
                }
            }

            public IEnumerable<string> EventsOf(string kind)
            {
                return Events.Where(e => e.StartsWith(kind));
            }
        }

        [Fact]
        public void Test_that_a_head_appears_on_the_second_detection_and_then_moves()
        {
            var harness = new Harness();

            harness.Step(null, Head(0.5f, 0.5f));
            Assert.Empty(harness.Events);

            harness.Step(null, Head(0.51f, 0.5f));
            Assert.Equal(new[] { "appeared 0" }, harness.Events);

            harness.Step(null, Head(0.52f, 0.5f));
            Assert.Equal(new[] { "appeared 0", "moved 0" }, harness.Events);
        }

        [Fact]
        public void Test_that_a_one_off_false_detection_never_appears()
        {
            var harness = new Harness();

            harness.Step(null, Head(0.5f, 0.5f));
            harness.Steps(30, null);

            Assert.Empty(harness.Events);
        }

        [Fact]
        public void Test_that_a_short_gap_keeps_the_head()
        {
            var harness = new Harness();

            harness.Steps(10, null, Head(0.5f, 0.5f));

            // NOTE (mristin):
            // E.g., the player blinked out of the detector for 0.3 seconds.
            harness.Steps(9, null);
            harness.Steps(5, null, Head(0.5f, 0.5f));

            Assert.Empty(harness.EventsOf("lost"));
            Assert.Equal(new[] { "appeared 0" }, harness.EventsOf("appeared"));
        }

        [Fact]
        public void Test_that_an_unseen_head_is_lost()
        {
            var harness = new Harness();

            harness.Steps(10, null, Head(0.5f, 0.5f));
            harness.Steps(30, null);

            Assert.Equal(new[] { "lost 0" }, harness.EventsOf("lost"));
        }

        [Fact]
        public void Test_that_weak_detections_continue_a_head_but_never_start_one()
        {
            var harness = new Harness();

            harness.Steps(10, null, Head(0.3f, 0.5f));

            // NOTE (mristin):
            // The player turns the head and the detector becomes unsure. A weak
            // detection elsewhere must not start a new head.
            harness.Steps(30, null, Head(0.3f, 0.5f, score: 0.3f), Head(0.8f, 0.5f, score: 0.3f));

            Assert.Equal(new[] { "appeared 0" }, harness.EventsOf("appeared"));
            Assert.Empty(harness.EventsOf("lost"));
        }

        [Fact]
        public void Test_that_crossing_heads_keep_their_identities()
        {
            var harness = new Harness();

            // NOTE (mristin):
            // Player A walks from the left to the right, player B the other way,
            // and they pass each other in the middle.
            for (int i = 0; i <= 40; i++)
            {
                float a = 0.1f + 0.02f * i;
                float b = 0.9f - 0.02f * i;
                harness.Step(null, Head(a, 0.5f), Head(b, 0.52f));
            }

            // NOTE (mristin):
            // A was the first detection in the first frame, so it got the id 0.
            Assert.Equal(new[] { "appeared 0", "appeared 1" }, harness.EventsOf("appeared"));
            Assert.Empty(harness.EventsOf("lost"));

            Assert.True(
                harness.Positions[0].X > harness.Positions[1].X,
                $"Expected A (id 0) to end on the right, but got A at " +
                $"{harness.Positions[0]} and B at {harness.Positions[1]}."
            );
        }

        [Fact]
        public void Test_that_a_returning_player_is_recognized()
        {
            var harness = new Harness();
            var alice = Appearance(1f, 0f, 0f);

            harness.Steps(10, _ => alice, Head(0.3f, 0.5f));
            harness.Steps(30, _ => alice);

            // NOTE (mristin):
            // Alice comes back at another place after a second.
            harness.Steps(5, _ => Appearance(0.98f, 0.1f, 0f), Head(0.7f, 0.4f));

            Assert.Equal(new[] { "appeared 0", "lost 0", "appeared 0" },
                harness.Events.Where(e => !e.StartsWith("moved")));
        }

        [Fact]
        public void Test_that_a_returning_player_who_looks_different_is_still_recognized()
        {
            var harness = new Harness();

            // NOTE (mristin):
            // The light changed, so Alice looks different, but nobody else is
            // away; she must not get a fresh spaceship.
            harness.Steps(10, _ => Appearance(1f, 0f, 0f), Head(0.3f, 0.5f));
            harness.Steps(30, null);

            harness.Steps(5, _ => Appearance(0f, 1f, 0f), Head(0.3f, 0.5f));

            Assert.Equal(new[] { "appeared 0", "lost 0", "appeared 0" },
                harness.Events.Where(e => !e.StartsWith("moved")));
        }

        [Fact]
        public void Test_that_a_returning_player_gets_the_identity_of_the_most_similar_lost_one()
        {
            var harness = new Harness();

            harness.Steps(
                10,
                d => d.CenterX < 0.5f ? Appearance(1f, 0f, 0f) : Appearance(0f, 1f, 0f),
                Head(0.3f, 0.5f), Head(0.7f, 0.5f)
            );
            harness.Steps(30, null);

            // NOTE (mristin):
            // The player on the right comes back on the left.
            harness.Steps(5, _ => Appearance(0.1f, 1f, 0f), Head(0.3f, 0.5f));

            Assert.Equal("appeared 1", harness.EventsOf("appeared").Last());
        }

        [Fact]
        public void Test_that_without_the_appearance_the_most_recently_lost_player_returns()
        {
            var harness = new Harness();

            harness.Steps(10, null, Head(0.3f, 0.5f), Head(0.7f, 0.5f));

            // NOTE (mristin):
            // The player on the left leaves first, then the one on the right.
            harness.Steps(30, null, Head(0.7f, 0.5f));
            harness.Steps(30, null);

            harness.Steps(5, null, Head(0.5f, 0.5f));

            Assert.Equal(new[] { "lost 0", "lost 1" }, harness.EventsOf("lost"));
            Assert.Equal("appeared 1", harness.EventsOf("appeared").Last());
        }

        [Fact]
        public void Test_that_a_new_player_gets_a_new_identity_when_nobody_is_away()
        {
            var harness = new Harness();

            harness.Steps(10, _ => Appearance(1f, 0f, 0f), Head(0.3f, 0.5f));
            harness.Steps(5, _ => Appearance(1f, 0f, 0f), Head(0.3f, 0.5f), Head(0.7f, 0.5f));

            Assert.Equal(new[] { "appeared 0", "appeared 1" }, harness.EventsOf("appeared"));
        }

        [Fact]
        public void Test_that_the_appearance_is_computed_within_the_budget()
        {
            var tracker = new MultiHeadTracker { EmbeddingBudget = 1 };
            var harness = new Harness(tracker);

            int calls = 0;
            int maxCallsPerFrame = 0;

            for (int frame = 0; frame < 60; frame++)
            {
                int callsBefore = calls;
                harness.Step(
                    _ => { calls++; return Appearance(1f, 0f, 0f); },
                    Head(0.1f, 0.5f), Head(0.4f, 0.5f), Head(0.7f, 0.5f), Head(0.9f, 0.2f)
                );
                maxCallsPerFrame = System.Math.Max(maxCallsPerFrame, calls - callsBefore);
            }

            Assert.Equal(1, maxCallsPerFrame);

            // NOTE (mristin):
            // All the players still got an appearance eventually.
            Assert.All(tracker.Tracks, t => Assert.NotNull(t.Embedding));
        }

        [Fact]
        public void Test_that_the_number_of_heads_is_limited()
        {
            var harness = new Harness(new MultiHeadTracker { MaxHeads = 2 });

            harness.Steps(5, null, Head(0.1f, 0.5f), Head(0.5f, 0.5f), Head(0.9f, 0.5f));

            Assert.Equal(2, harness.EventsOf("appeared").Count());
        }
    }
}
