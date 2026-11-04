using Godot;
using System;
using System.Collections.Concurrent;

using HeadInvaders.Tracking;

/// <summary>
/// Detect and track the heads in the webcam feed, and overlay the webcam dimly
/// over the whole screen.
/// </summary>
/// <remarks>
/// <para>
/// We detect the heads with YOLOX (from any side) or with UltraFace (frontal faces
/// only, but faster). We recognize the players with OSNet when they come back.
/// </para>
///
/// <para>
/// The detection and the tracking run on a separate thread, so that the game
/// stays smooth. The main thread only emits the resulting signals.
/// </para>
/// </remarks>
public partial class CameraHeadTracker : Node
{
    public enum DetectorKind
    {
        Yolox,
        UltraFace,
    }

    /// <summary>Signal that a new head entered the scene.</summary>
    /// <remarks>The position is given in viewport coordinates.</remarks>
    [Signal]
    public delegate void HeadAppearedEventHandler(int id, Vector2 position);

    /// <summary>Signal that a head moved.</summary>
    /// <remarks>The position is given in viewport coordinates.</remarks>
    [Signal]
    public delegate void HeadMovedEventHandler(int id, Vector2 position);

    /// <summary>Signal that a head left the scene.</summary>
    [Signal]
    public delegate void HeadLostEventHandler(int id);

    [Export]
    public DetectorKind Detector = DetectorKind.Yolox;

    /// <summary>Recognize the players with OSNet when they come back.</summary>
    [Export]
    public bool ReIdentification = true;

    [Export]
    public int MaxHeads = 16;

    /// <summary>Lower means smoother, but laggier, when the head is slow.</summary>
    [Export]
    public float MinCutoff = 1.5f;

    /// <summary>Higher means less lag, but more jitter, when the head is fast.</summary>
    [Export]
    public float Beta = 0.01f;

    /// <summary>Remove a head after it has not been seen for this many seconds.</summary>
    [Export]
    public float LostTimeout = 0.5f;

    /// <summary>Recognize a returning player only if they look at least this similar.</summary>
    [Export(PropertyHint.Range, "0,1")]
    public float ReIdThreshold = 0.85f;

    /// <summary>Remember the lost players for this many seconds.</summary>
    [Export]
    public float ReIdMemory = 30f;

    [Export(PropertyHint.Range, "0,1")]
    public float OverlayOpacity = 0.2f;

    private const string _yoloxModelPath = (
        "res://scenes/head_tracker/yolox/model/yolox_n_body_head_hand_face_post_1x3x256x320.onnx"
    );

    private const string _ultraFaceModelPath = (
        "res://scenes/head_tracker/ultra_face/model/version-RFB-320.onnx"
    );

    private const string _osNetModelPath = (
        "res://scenes/head_tracker/osnet/model/osnet_x0_25_msmt17.onnx"
    );

    private enum EventKind
    {
        Appeared,
        Moved,
        Lost,
    }

    private readonly struct HeadEvent
    {
        public readonly EventKind Kind;
        public readonly int Id;
        public readonly System.Numerics.Vector2 CameraPosition;
        public readonly System.Numerics.Vector2 CameraSize;

        public HeadEvent(
            EventKind kind,
            int id,
            System.Numerics.Vector2 cameraPosition,
            System.Numerics.Vector2 cameraSize
        )
        {
            Kind = kind;
            Id = id;
            CameraPosition = cameraPosition;
            CameraSize = cameraSize;
        }
    }

    private CameraFeed? _cameraFeed;
    private CameraTexture? _cameraTexture;
    private TextureRect _cameraPort = null!;
    private Label _status = null!;

    private readonly System.Diagnostics.Stopwatch _clock = (
        System.Diagnostics.Stopwatch.StartNew()
    );

    private readonly object _latestFrameLock = new object();
    private Frame? _latestFrame;

    // NOTE (mristin):
    // Unlike the frames, we must not drop any events, so we queue them all.
    private readonly ConcurrentQueue<HeadEvent> _events = new ConcurrentQueue<HeadEvent>();

    private volatile bool _inferenceRunning = false;
    private System.Threading.Thread? _inferenceThread;

    public override void _Ready()
    {
        _cameraPort = GetNode<TextureRect>("Overlay/CameraPort");
        _cameraPort.Modulate = new Color(1f, 1f, 1f, OverlayOpacity);

        _status = GetNode<Label>("Overlay/Status");
        _status.Text = "Waiting for the camera...";
    }

    /// <summary>Start displaying the camera feed and tracking the heads.</summary>
    public void Start(CameraFeed cameraFeed)
    {
        if (_cameraFeed != null)
        {
            throw new InvalidOperationException(
                "CameraHeadTracker has already been started."
            );
        }

        _cameraFeed = cameraFeed;

        // NOTE (mristin):
        // We display the camera texture directly so that the GPU does the mirroring
        // and the scaling for us. This keeps the main thread free.
        _cameraTexture = new CameraTexture
        {
            CameraFeedId = _cameraFeed.GetId(),
            CameraIsActive = true
        };
        _cameraPort.Texture = _cameraTexture;

        _cameraFeed.FrameChanged += OnFrameChanged;

        string detectorPath = Detector == DetectorKind.Yolox
            ? _yoloxModelPath
            : _ultraFaceModelPath;

        byte[]? detectorModel = LoadModel(detectorPath);
        if (detectorModel == null)
        {
            return;
        }

        byte[]? osNetModel = null;
        if (ReIdentification)
        {
            osNetModel = LoadModel(_osNetModelPath);
            if (osNetModel == null)
            {
                return;
            }
        }

        var tracker = new MultiHeadTracker
        {
            MaxHeads = MaxHeads,
            MinCutoff = MinCutoff,
            Beta = Beta,
            LostTimeout = LostTimeout,
            ReIdThreshold = ReIdThreshold,
            ReIdMemory = ReIdMemory,
        };

        // NOTE (mristin):
        // UltraFace has no weak detections worth continuing a head with.
        if (Detector == DetectorKind.UltraFace)
        {
            tracker.HighScoreThreshold = 0f;
        }

        _status.Text = "Loading the head detector...";

        var detectorKind = Detector;
        _inferenceRunning = true;
        _inferenceThread = new System.Threading.Thread(
            () => InferenceLoop(detectorKind, detectorModel, osNetModel, tracker)
        )
        {
            IsBackground = true,
            Name = "Head tracking"
        };
        _inferenceThread.Start();
    }

    private byte[]? LoadModel(string path)
    {
        if (!FileAccess.FileExists(path))
        {
            _status.Text = $"The model is missing: {path}";
            GD.PushError(_status.Text);
            return null;
        }

        byte[] model = FileAccess.GetFileAsBytes(path);
        GD.Print($"Loaded {path}, size: {model.Length / 1024.0 / 1024.0:F2} MB");
        return model;
    }

    public override void _ExitTree()
    {
        if (_cameraFeed != null)
        {
            _cameraFeed.FrameChanged -= OnFrameChanged;
        }

        _inferenceRunning = false;
        _inferenceThread?.Join();
        _inferenceThread = null;
    }

    private void OnFrameChanged()
    {
        Image? image = _cameraTexture?.GetImage();
        if (image == null || image.IsEmpty())
        {
            return;
        }

        if (image.GetFormat() != Image.Format.Rgb8)
        {
            image.Convert(Image.Format.Rgb8);
        }

        // NOTE (mristin):
        // We copy the raw bytes on the main thread so that the inference thread
        // never touches any engine objects.
        var frame = new Frame(
            image.GetData(),
            image.GetWidth(),
            image.GetHeight(),
            _clock.Elapsed.TotalSeconds
        );

        lock (_latestFrameLock)
        {
            _latestFrame = frame;
        }
    }

    private void InferenceLoop(
        DetectorKind detectorKind,
        byte[] detectorModel,
        byte[]? osNetModel,
        MultiHeadTracker tracker
    )
    {
        IHeadDetector? detector = null;
        OsNetModel? osNet = null;

        try
        {
            detector = detectorKind == DetectorKind.Yolox
                ? new YoloxModel(detectorModel)
                : new UltraFaceModel(detectorModel)
                {
                    ScoreThreshold = 0.7f,
                    MaxDetections = MaxHeads * 2,
                };

            if (osNetModel != null)
            {
                osNet = new OsNetModel(osNetModel);
            }

            GD.Print("The head tracking is ready.");
            Callable.From(() => { _status.Visible = false; }).CallDeferred();

            System.Numerics.Vector2 cameraSize = System.Numerics.Vector2.Zero;

            tracker.OnAppeared = (id, position) => _events.Enqueue(
                new HeadEvent(EventKind.Appeared, id, position, cameraSize)
            );
            tracker.OnMoved = (id, position) => _events.Enqueue(
                new HeadEvent(EventKind.Moved, id, position, cameraSize)
            );
            tracker.OnLost = id => _events.Enqueue(
                new HeadEvent(EventKind.Lost, id, System.Numerics.Vector2.Zero, cameraSize)
            );

            while (_inferenceRunning)
            {
                Frame? frame;
                lock (_latestFrameLock)
                {
                    frame = _latestFrame;
                    _latestFrame = null;
                }

                if (frame == null)
                {
                    System.Threading.Thread.Sleep(1);
                    continue;
                }

                cameraSize = new System.Numerics.Vector2(frame.Width, frame.Height);

                var result = detector.Detect(frame);

                EmbedHead? embed = null;
                if (osNet != null)
                {
                    embed = head =>
                    {
                        var crop = PlayerCrop.For(
                            head, result.Bodies, frame.Width, frame.Height
                        );
                        return crop.HasValue ? osNet.Embed(frame, crop.Value) : null;
                    };
                }

                tracker.Update(result.Heads, cameraSize, frame.Timestamp, embed);
            }
        }
        catch (Exception exception)
        {
            GD.PushError($"The head tracking failed: {exception}");
            string message = $"The head tracking failed:\n{exception.Message}";
            Callable.From(() =>
            {
                _status.Text = message;
                _status.Visible = true;
            }).CallDeferred();
        }
        finally
        {
            detector?.Dispose();
            osNet?.Dispose();
        }

        GD.Print("Left the inference loop.");
    }

    public override void _Process(double delta)
    {
        while (_events.TryDequeue(out var headEvent))
        {
            switch (headEvent.Kind)
            {
                case EventKind.Appeared:
                    EmitSignal(
                        SignalName.HeadAppeared,
                        headEvent.Id,
                        CameraToViewport(headEvent.CameraPosition, headEvent.CameraSize)
                    );
                    break;

                case EventKind.Moved:
                    EmitSignal(
                        SignalName.HeadMoved,
                        headEvent.Id,
                        CameraToViewport(headEvent.CameraPosition, headEvent.CameraSize)
                    );
                    break;

                case EventKind.Lost:
                    EmitSignal(SignalName.HeadLost, headEvent.Id);
                    break;
            }
        }
    }

    /// <summary>
    /// Map a position in camera pixels to the viewport, exactly as the overlay
    /// displays it.
    /// </summary>
    private Vector2 CameraToViewport(
        System.Numerics.Vector2 cameraPosition,
        System.Numerics.Vector2 cameraSize
    )
    {
        Rect2 rect = _cameraPort.GetGlobalRect();
        if (cameraSize.X <= 0f || cameraSize.Y <= 0f)
        {
            return rect.Position + rect.Size * 0.5f;
        }

        var size = new Vector2(cameraSize.X, cameraSize.Y);
        var position = new Vector2(cameraPosition.X, cameraPosition.Y);

        // NOTE (mristin):
        // The overlay uses "keep aspect covered", so it scales the camera image to
        // fill the rectangle and crops the overflow evenly on both sides.
        float scale = Math.Max(rect.Size.X / size.X, rect.Size.Y / size.Y);
        Vector2 visibleSize = rect.Size / scale;
        Vector2 crop = (size - visibleSize) * 0.5f;

        Vector2 viewportPosition = rect.Position + (position - crop) * scale;

        return viewportPosition.Clamp(rect.Position, rect.End);
    }
}
