extends Control

signal key_pressed(keycode: Key)

## Give up waiting for the camera server after this many seconds.
const _CAMERA_SERVER_TIMEOUT: float = 7.0

## Wait this long after the first feed shows up, so that the others can follow.
const _GRACE_AFTER_FIRST_FEED: float = 1.0

var compatible_feeds: Array[FeedRecord] = []

## Play these levels instead of the game's own, e.g., from the test harness.
var level_scene_paths: Array[String] = []

@onready var status: Label = $Status
@onready var spinner: Spinner = $Spinner
@onready var selection_part: Control = $SelectionPart
@onready var camera_option: OptionButton = $SelectionPart/CameraOption


class FeedRecord:
    var feed: CameraFeed
    var format_index: int

    func _init(camera_feed: CameraFeed, fmt_index: int):
        feed = camera_feed
        format_index = fmt_index


func _input(event):
    if event is InputEventKey and event.pressed and not event.echo:
        key_pressed.emit(event.keycode)


func _ready() -> void:
    CameraServer.monitoring_feeds = true

    # NOTE (mristin):
    # The camera server enumerates the feeds asynchronously, so we poll instead of
    # always waiting for the whole timeout.
    var waited := 0.0
    var first_feed_at := -1.0
    while waited < _CAMERA_SERVER_TIMEOUT:
        if CameraServer.get_feed_count() > 0:
            if first_feed_at < 0.0:
                first_feed_at = waited
            elif waited - first_feed_at >= _GRACE_AFTER_FIRST_FEED:
                break

        await get_tree().create_timer(0.25).timeout
        waited += 0.25

    print("Camera server reports %d feed(s)." % CameraServer.get_feed_count())

    compatible_feeds.clear()

    # Filter feeds to only include those with 640x480 YUYV format
    for i in range(CameraServer.get_feed_count()):
        var feed = CameraServer.get_feed(i)
        var formats = feed.get_formats()

        for format_idx in range(formats.size()):
            var format = formats[format_idx] as Dictionary
            var width = format.get("width", 0) as int
            var height = format.get("height", 0) as int
            var pixel_format = format.get("format", "") as String

            if width == 640 and height == 480 and pixel_format.begins_with("YUYV"):
                print("Found compatible feed: ", feed.get_name(), " with format: ", format)
                compatible_feeds.append(FeedRecord.new(feed, format_idx))
                break

    spinner.visible = false

    if compatible_feeds.is_empty():
        if CameraServer.get_feed_count() == 0:
            status.text = "Unfortunately, there are no camera feeds."
        else:
            status.text = (
                "Unfortunately, we need the camera feed to support "
                + "640x480 YUYV format, but none of them support it."
            )

        status.text += "\n\nPress any key to quit."

        await key_pressed
        get_tree().quit()
        return

    if compatible_feeds.size() == 1:
        var feed_record = compatible_feeds[0]
        print("Auto-selecting single compatible feed: ", feed_record.feed.get_name())
        start(feed_record.feed, feed_record.format_index)
        return

    # Multiple feeds available - populate the option button
    selection_part.visible = true
    status.text = "Please select the camera feed:"

    camera_option.clear()
    for feed_record in compatible_feeds:
        camera_option.add_item(feed_record.feed.get_name())


func _on_start_button_pressed() -> void:
    var selected_index = camera_option.get_selected_id()

    if selected_index >= 0 and selected_index < compatible_feeds.size():
        var feed_record = compatible_feeds[selected_index]
        print("Starting with selected feed: ", feed_record.feed.get_name())
        start(feed_record.feed, feed_record.format_index)


func start(feed: CameraFeed, format_index: int) -> void:
    print("Setting feed format and activating feed: ", feed.get_name())
    feed.set_format(format_index, {})
    feed.feed_is_active = true

    var head_tracker: HeadTracker = (
        load("res://scenes/head_tracker/head_tracker.tscn").instantiate()
    )
    head_tracker.set_camera_feed(feed)

    _start_game([head_tracker])


func _start_game(controllers: Array[HeadController]) -> void:
    var game: Game = load("res://scenes/game/game.tscn").instantiate()
    game.own_head_controllers(controllers)
    if not level_scene_paths.is_empty():
        game.level_scene_paths = level_scene_paths

    get_tree().root.add_child(game)
    queue_free()
