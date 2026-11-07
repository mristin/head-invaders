using System;
using System.Collections.Generic;
using System.Numerics;

// NOTE (mristin):
// This file must not depend on Godot so that we can unit-test the head tracking
// outside of the engine. See tests/HeadInvaders.Tests.

namespace HeadInvaders.Tracking
{
    /// <summary>Filter a signal with an exponential moving average.</summary>
    public sealed class LowPassFilter
    {
        private float? _value;

        public float Filter(float value, float alpha)
        {
            _value = _value.HasValue
                ? _value.Value + alpha * (value - _value.Value)
                : value;

            return _value.Value;
        }
    }

    /// <summary>
    /// Smooth a noisy signal while keeping the lag low on fast movements.
    /// </summary>
    /// <remarks>
    /// See: Casiez et al., "1€ Filter: A Simple Speed-based Low-pass Filter for
    /// Noisy Input in Interactive Systems", CHI 2012.
    /// </remarks>
    public sealed class OneEuroFilter
    {
        private readonly float _minCutoff;
        private readonly float _beta;
        private readonly float _derivativeCutoff;

        private readonly LowPassFilter _value = new LowPassFilter();
        private readonly LowPassFilter _derivative = new LowPassFilter();
        private float? _previousRaw;
        private float _previousFiltered;

        public OneEuroFilter(float minCutoff, float beta, float derivativeCutoff)
        {
            _minCutoff = minCutoff;
            _beta = beta;
            _derivativeCutoff = derivativeCutoff;
        }

        public float Filter(float value, float dt)
        {
            if (!_previousRaw.HasValue)
            {
                _previousRaw = value;
                _previousFiltered = _value.Filter(value, 1f);
                return _previousFiltered;
            }

            if (dt <= 0f)
            {
                return _previousFiltered;
            }

            float rawDerivative = (value - _previousRaw.Value) / dt;
            float derivative = _derivative.Filter(
                rawDerivative,
                Alpha(dt, _derivativeCutoff)
            );

            float cutoff = _minCutoff + _beta * Math.Abs(derivative);

            _previousRaw = value;
            _previousFiltered = _value.Filter(value, Alpha(dt, cutoff));
            return _previousFiltered;
        }

        private static float Alpha(float dt, float cutoff)
        {
            float tau = 1f / (2f * MathF.PI * cutoff);
            return 1f / (1f + tau / dt);
        }
    }

    /// <summary>Compute the appearance embedding of a head, if possible.</summary>
    /// <returns>L2-normalized embedding, or null if not available.</returns>
    public delegate float[]? EmbedHead(Detection head);

    /// <summary>Represent a head followed over multiple frames.</summary>
    public sealed class Track
    {
        public int Id;

        /// <summary>Smoothed center of the head in (mirrored) camera pixels.</summary>
        public Vector2 Position;

        /// <summary>Smoothed velocity of the head in camera pixels per second.</summary>
        public Vector2 Velocity = Vector2.Zero;

        /// <summary>Smoothed size of the head in camera pixels.</summary>
        public float Size;

        public double LastSeen;
        public int Hits = 1;
        public bool Confirmed = false;

        /// <summary>Appearance of the player, if we computed it already.</summary>
        public float[]? Embedding;
        public double EmbeddingTimestamp = double.NegativeInfinity;

        private Vector2 _lastRawPosition;
        private readonly float _minCutoff;
        private readonly float _beta;
        private OneEuroFilter _filterX;
        private OneEuroFilter _filterY;

        public Track(
            int id,
            Vector2 position,
            float size,
            double timestamp,
            float minCutoff,
            float beta
        )
        {
            Id = id;
            Size = size;
            LastSeen = timestamp;
            _minCutoff = minCutoff;
            _beta = beta;
            _filterX = new OneEuroFilter(minCutoff, beta, 1f);
            _filterY = new OneEuroFilter(minCutoff, beta, 1f);
            _lastRawPosition = position;
            Position = new Vector2(
                _filterX.Filter(position.X, 0f),
                _filterY.Filter(position.Y, 0f)
            );
        }

        /// <summary>Predict where the head is at the given time.</summary>
        public Vector2 Predict(double timestamp, float maxHorizon)
        {
            float horizon = (float)Math.Clamp(timestamp - LastSeen, 0.0, maxHorizon);
            return Position + Velocity * horizon;
        }

        public void Observe(Vector2 position, float size, double timestamp)
        {
            float dt = (float)(timestamp - LastSeen);

            if (dt > 0f)
            {
                var rawVelocity = (position - _lastRawPosition) / dt;
                Velocity = Vector2.Lerp(Velocity, rawVelocity, 0.5f);
            }

            _lastRawPosition = position;
            LastSeen = timestamp;

            Position = new Vector2(
                _filterX.Filter(position.X, dt),
                _filterY.Filter(position.Y, dt)
            );
            Size += (size - Size) * 0.3f;

            Hits++;
        }

        /// <summary>Blend a new embedding into the appearance of the player.</summary>
        public void UpdateEmbedding(float[] embedding, double timestamp, float momentum)
        {
            if (Embedding == null)
            {
                Embedding = (float[])embedding.Clone();
            }
            else
            {
                for (int i = 0; i < Embedding.Length; i++)
                {
                    Embedding[i] = momentum * Embedding[i] + (1f - momentum) * embedding[i];
                }
                OsNetModel.Normalize(Embedding);
            }

            EmbeddingTimestamp = timestamp;
        }
    }

    /// <summary>
    /// Associate per-frame detections with heads which persist over time, so that
    /// each head keeps its identity and moves smoothly.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The association follows the ideas of ByteTrack (Zhang et al., ECCV 2022):
    /// we predict the motion of each head, match the confident detections first,
    /// and use the weak detections only to continue the known heads.
    /// </para>
    ///
    /// <para>
    /// On top of that, we use the appearance embeddings (e.g., from OSNet) to
    /// resolve the ambiguous matches and to recognize the players who come back
    /// after they were lost.
    /// </para>
    ///
    /// <para>
    /// A new head never gets a new identity while a player is away: otherwise
    /// a player could step out of the camera and back in for a fresh spaceship.
    /// The new head takes over the identity of the lost player who looks the
    /// most alike, or of the one lost most recently if we can not compare the
    /// appearances. This also hands the spaceship over when the players take
    /// turns, which is fine for the game.
    /// </para>
    /// </remarks>
    public sealed class MultiHeadTracker
    {
        public delegate void HeadEventHandler(int id, Vector2 cameraPosition);
        public delegate void HeadLostEventHandler(int id);

        public HeadEventHandler? OnAppeared;
        public HeadEventHandler? OnMoved;
        public HeadLostEventHandler? OnLost;

        public int MaxHeads = 16;
        public float MinCutoff = 1.5f;
        public float Beta = 0.01f;

        /// <summary>
        /// Match a detection to a head only if it is at most this many head sizes
        /// away from the predicted position.
        /// </summary>
        public float MatchDistanceFactor = 1.5f;

        /// <summary>Do not extrapolate the motion further than this, in seconds.</summary>
        public float MaxPredictionHorizon = 0.3f;

        /// <summary>
        /// Only detections at least this confident can start new heads; the weaker
        /// ones only continue the known heads.
        /// </summary>
        public float HighScoreThreshold = 0.5f;

        /// <summary>
        /// Consider a head real only after this many detections, to suppress
        /// one-off false positives.
        /// </summary>
        public int HitsToConfirm = 2;

        /// <summary>Forget a confirmed head after this many seconds unseen.</summary>
        public float LostTimeout = 0.5f;

        /// <summary>Forget an unconfirmed head after this many seconds unseen.</summary>
        public float TentativeTimeout = 0.25f;

        /// <summary>
        /// Remember the lost players for this many seconds so that we can
        /// recognize them when they come back.
        /// </summary>
        /// <remarks>
        /// We remember them longer than a level lasts, since a player who comes
        /// back too late would get a fresh spaceship.
        /// </remarks>
        public float ReIdMemory = 600f;

        /// <summary>How much the appearance counts when resolving ambiguous matches.</summary>
        public float AppearanceWeight = 1f;

        /// <summary>
        /// Compute at most this many embeddings per frame to keep the frame rate.
        /// </summary>
        /// <remarks>
        /// One embedding with OSNet x0.25 takes about 10 ms on a laptop CPU.
        /// </remarks>
        public int EmbeddingBudget = 1;

        /// <summary>Refresh the appearance of a player every this many seconds.</summary>
        public float EmbeddingRefreshInterval = 1f;

        /// <summary>How much of the old appearance to keep when refreshing it.</summary>
        public float EmbeddingMomentum = 0.8f;

        private readonly List<Track> _tracks = new List<Track>();

        private readonly List<(int Id, float[]? Embedding, double LostAt)> _lost = (
            new List<(int, float[]?, double)>()
        );

        private int _nextId = 0;

        public IReadOnlyList<Track> Tracks => _tracks;

        /// <summary>Update the heads with the detections of a new frame.</summary>
        /// <param name="heads">Mirrored, normalized head detections.</param>
        /// <param name="cameraSize">Size of the camera frame in pixels.</param>
        /// <param name="timestamp">Time of the frame in seconds.</param>
        /// <param name="embed">
        /// Compute the appearance of a head, or null to track by motion only.
        /// </param>
        public void Update(
            IReadOnlyList<Detection> heads,
            Vector2 cameraSize,
            double timestamp,
            EmbedHead? embed = null
        )
        {
            int budget = embed != null ? EmbeddingBudget : 0;
            var embeddings = new float[]?[heads.Count];

            float[]? Embed(int d)
            {
                if (embeddings[d] == null && budget > 0 && embed != null)
                {
                    budget--;
                    embeddings[d] = embed(heads[d]);
                }
                return embeddings[d];
            }

            var centers = new Vector2[heads.Count];
            var sizes = new float[heads.Count];
            for (int i = 0; i < heads.Count; i++)
            {
                centers[i] = new Vector2(
                    heads[i].CenterX * cameraSize.X,
                    heads[i].CenterY * cameraSize.Y
                );
                sizes[i] = Math.Max(
                    heads[i].Width * cameraSize.X,
                    heads[i].Height * cameraSize.Y
                );
            }

            var predictions = new Vector2[_tracks.Count];
            for (int t = 0; t < _tracks.Count; t++)
            {
                predictions[t] = _tracks[t].Predict(timestamp, MaxPredictionHorizon);
            }

            var trackMatched = new bool[_tracks.Count];
            var detectionMatched = new bool[heads.Count];
            var matchedDetection = new int[_tracks.Count];

            // NOTE (mristin):
            // First stage: the confident detections against all the heads.
            Associate(
                heads, centers, sizes, predictions, Embed,
                d => heads[d].Score >= HighScoreThreshold,
                t => true,
                trackMatched, detectionMatched, matchedDetection
            );

            // NOTE (mristin):
            // Second stage: the weak detections only continue the confirmed heads,
            // e.g., when a player turns the head and the detector becomes unsure.
            Associate(
                heads, centers, sizes, predictions, null,
                d => heads[d].Score < HighScoreThreshold,
                t => _tracks[t].Confirmed,
                trackMatched, detectionMatched, matchedDetection
            );

            var confirmedNow = new List<Track>();
            var observed = new List<(Track Track, int Detection)>();

            for (int t = 0; t < _tracks.Count; t++)
            {
                if (!trackMatched[t])
                {
                    continue;
                }

                var track = _tracks[t];
                int d = matchedDetection[t];
                track.Observe(centers[d], sizes[d], timestamp);
                observed.Add((track, d));

                // NOTE (mristin):
                // We deliberately do not blend in the embeddings computed for the
                // ambiguous matches: the crop probably mixes in the other player.

                if (track.Confirmed)
                {
                    OnMoved?.Invoke(track.Id, track.Position);
                }
                else if (track.Hits >= HitsToConfirm)
                {
                    // NOTE (mristin):
                    // We need the appearance to recognize a returning player.
                    if (track.Embedding == null && IsIsolated(d, centers, track.Size))
                    {
                        var embedding = Embed(d);
                        if (embedding != null)
                        {
                            track.UpdateEmbedding(embedding, timestamp, EmbeddingMomentum);
                        }
                    }

                    confirmedNow.Add(track);
                }
            }

            // NOTE (mristin):
            // The detections are sorted by score, so the most confident ones get
            // to start new heads first.
            for (int d = 0; d < heads.Count; d++)
            {
                if (
                    detectionMatched[d]
                    || heads[d].Score < HighScoreThreshold
                    || _tracks.Count >= MaxHeads
                )
                {
                    continue;
                }

                var track = new Track(
                    _nextId++, centers[d], sizes[d], timestamp, MinCutoff, Beta
                );

                var embedding = Embed(d);
                if (embedding != null)
                {
                    track.UpdateEmbedding(embedding, timestamp, EmbeddingMomentum);
                }

                _tracks.Add(track);

                if (track.Hits >= HitsToConfirm)
                {
                    confirmedNow.Add(track);
                }
            }

            foreach (var track in confirmedNow)
            {
                Confirm(track);
            }

            ForgetUnseen(timestamp);
            RefreshEmbeddings(heads, centers, observed, timestamp, embed, ref budget);
        }

        /// <summary>
        /// Greedily match the eligible detections to the eligible heads, closest
        /// pairs first.
        /// </summary>
        private void Associate(
            IReadOnlyList<Detection> heads,
            Vector2[] centers,
            float[] sizes,
            Vector2[] predictions,
            Func<int, float[]?>? embed,
            Func<int, bool> detectionEligible,
            Func<int, bool> trackEligible,
            bool[] trackMatched,
            bool[] detectionMatched,
            int[] matchedDetection
        )
        {
            var pairs = new List<(float Cost, int Track, int Detection)>();
            var candidatesPerDetection = new int[heads.Count];
            var candidatesPerTrack = new int[_tracks.Count];

            for (int t = 0; t < _tracks.Count; t++)
            {
                if (trackMatched[t] || !trackEligible(t))
                {
                    continue;
                }

                for (int d = 0; d < heads.Count; d++)
                {
                    if (detectionMatched[d] || !detectionEligible(d))
                    {
                        continue;
                    }

                    float gate = MatchDistanceFactor * Math.Max(_tracks[t].Size, sizes[d]);
                    float distance = Vector2.Distance(predictions[t], centers[d]);
                    if (distance <= gate)
                    {
                        pairs.Add((distance / gate, t, d));
                        candidatesPerDetection[d]++;
                        candidatesPerTrack[t]++;
                    }
                }
            }

            // NOTE (mristin):
            // When the motion alone is ambiguous (e.g., two players crossing), we
            // let the appearance decide.
            if (embed != null)
            {
                for (int i = 0; i < pairs.Count; i++)
                {
                    var (cost, t, d) = pairs[i];
                    bool ambiguous = (
                        candidatesPerDetection[d] > 1 || candidatesPerTrack[t] > 1
                    );

                    var trackEmbedding = _tracks[t].Embedding;
                    if (!ambiguous || trackEmbedding == null)
                    {
                        continue;
                    }

                    var detectionEmbedding = embed(d);
                    if (detectionEmbedding == null)
                    {
                        continue;
                    }

                    float similarity = OsNetModel.CosineSimilarity(
                        trackEmbedding, detectionEmbedding
                    );
                    pairs[i] = (cost + AppearanceWeight * (1f - similarity), t, d);
                }
            }

            pairs.Sort((a, b) => a.Cost.CompareTo(b.Cost));

            foreach (var (_, t, d) in pairs)
            {
                if (trackMatched[t] || detectionMatched[d])
                {
                    continue;
                }

                trackMatched[t] = true;
                detectionMatched[d] = true;
                matchedDetection[t] = d;
            }
        }

        /// <summary>
        /// Confirm the head, and give it the identity of a lost player, if any.
        /// </summary>
        private void Confirm(Track track)
        {
            track.Confirmed = true;

            int index = PickLost(track.Embedding);
            if (index >= 0)
            {
                // NOTE (mristin):
                // The identity is new to this head, so the embedding of the head
                // carries over, while the old one of the lost player is dropped.
                track.Id = _lost[index].Id;
                _lost.RemoveAt(index);
            }

            OnAppeared?.Invoke(track.Id, track.Position);
        }

        /// <summary>
        /// Pick the lost player who looks the most like the given appearance, or
        /// the one lost most recently if we can not compare the appearances.
        /// </summary>
        /// <returns>Index in the lost players, or -1 if nobody is lost.</returns>
        private int PickLost(float[]? embedding)
        {
            int mostSimilar = -1;
            float bestSimilarity = float.NegativeInfinity;
            int mostRecent = -1;

            for (int i = 0; i < _lost.Count; i++)
            {
                if (mostRecent < 0 || _lost[i].LostAt > _lost[mostRecent].LostAt)
                {
                    mostRecent = i;
                }

                var lostEmbedding = _lost[i].Embedding;
                if (embedding == null || lostEmbedding == null)
                {
                    continue;
                }

                float similarity = OsNetModel.CosineSimilarity(embedding, lostEmbedding);
                if (similarity > bestSimilarity)
                {
                    bestSimilarity = similarity;
                    mostSimilar = i;
                }
            }

            return mostSimilar >= 0 ? mostSimilar : mostRecent;
        }

        private void ForgetUnseen(double timestamp)
        {
            for (int i = _tracks.Count - 1; i >= 0; i--)
            {
                var track = _tracks[i];
                double unseen = timestamp - track.LastSeen;

                float timeout = track.Confirmed ? LostTimeout : TentativeTimeout;
                if (unseen <= timeout)
                {
                    continue;
                }

                _tracks.RemoveAt(i);

                if (track.Confirmed)
                {
                    _lost.Add((track.Id, track.Embedding, timestamp));
                    OnLost?.Invoke(track.Id);
                }
            }

            _lost.RemoveAll(lost => timestamp - lost.LostAt > ReIdMemory);
        }

        /// <summary>
        /// Refresh the appearance of the players whose appearance is the oldest,
        /// within the remaining budget.
        /// </summary>
        private void RefreshEmbeddings(
            IReadOnlyList<Detection> heads,
            Vector2[] centers,
            List<(Track Track, int Detection)> observed,
            double timestamp,
            EmbedHead? embed,
            ref int budget
        )
        {
            if (embed == null || budget <= 0)
            {
                return;
            }

            var candidates = new List<(Track Track, int Detection)>();
            foreach (var (track, d) in observed)
            {
                if (
                    _tracks.Contains(track)
                    && timestamp - track.EmbeddingTimestamp >= EmbeddingRefreshInterval
                    && IsIsolated(d, centers, track.Size)
                )
                {
                    candidates.Add((track, d));
                }
            }

            candidates.Sort(
                (a, b) => a.Track.EmbeddingTimestamp.CompareTo(b.Track.EmbeddingTimestamp)
            );

            foreach (var (track, d) in candidates)
            {
                if (budget <= 0)
                {
                    break;
                }

                budget--;
                var embedding = embed(heads[d]);
                if (embedding != null)
                {
                    track.UpdateEmbedding(embedding, timestamp, EmbeddingMomentum);
                }
            }
        }

        /// <summary>
        /// Check that no other head is close, so that the crop of the player does
        /// not mix in another player's appearance.
        /// </summary>
        private static bool IsIsolated(int d, Vector2[] centers, float size)
        {
            for (int other = 0; other < centers.Length; other++)
            {
                if (other != d && Vector2.Distance(centers[d], centers[other]) < 2.5f * size)
                {
                    return false;
                }
            }
            return true;
        }
    }
}  // namespace HeadInvaders.Tracking
