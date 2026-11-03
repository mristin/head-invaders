class_name FinalMessage

extends CanvasLayer

## Show a friendly picture with a message between the levels, and count down
## until the game moves on.
##
## The game pauses while the message is shown, so the message keeps on
## processing on its own.

signal done

var _seconds: float = 5.0
var _left: float = 5.0
var _done: bool = false

@onready var image: TextureRect = $Image
@onready var title: Label = $Title
@onready var subtitle: Label = $Subtitle
@onready var counter: Label = $Counter
@onready var spinner: Spinner = $Spinner


func show_message(
    texture: Texture2D, title_text: String, subtitle_text: String, seconds: float
) -> void:
    image.texture = texture
    title.text = title_text
    subtitle.text = subtitle_text
    _seconds = seconds
    _left = seconds
    _update_counter()


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _update_counter()


func _process(delta: float) -> void:
    if _done:
        return

    _left -= delta
    if _left <= 0.0:
        _done = true
        done.emit()
        return

    _update_counter()


func _update_counter() -> void:
    if not is_node_ready():
        return
    counter.text = str(ceili(maxf(_left, 0.0)))
    spinner.set_progress(_left / _seconds)
