class_name HeadTracker

extends HeadController

## Track the heads of the players in the webcam feed.

var _camera_feed: CameraFeed = null

@onready var camera_head_tracker: Node = $CameraHeadTracker


func set_camera_feed(feed: CameraFeed) -> void:
    _camera_feed = feed


func _ready() -> void:
    assert(_camera_feed != null, "Camera feed must be set before call to _ready.")

    # NOTE (mristin):
    # We keep the tracking implementation general so that we can swap the models
    # without touching the rest of the game.
    camera_head_tracker.HeadAppeared.connect(
        func(id: int, pos: Vector2): head_appeared.emit(id, pos)
    )
    camera_head_tracker.HeadMoved.connect(func(id: int, pos: Vector2): head_moved.emit(id, pos))
    camera_head_tracker.HeadLost.connect(func(id: int): head_lost.emit(id))

    camera_head_tracker.Start(_camera_feed)
