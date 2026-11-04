class_name QuitPrompt

extends CanvasLayer

var _awaiting_confirmation: bool = false

@onready var label: Label = $Label
@onready var timer: Timer = $Timer


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    label.visible = false
    timer.timeout.connect(_on_confirmation_window_elapsed)


func _unhandled_input(event: InputEvent) -> void:
    if not (event is InputEventKey and event.pressed and not event.echo):
        return

    if event.keycode != KEY_ESCAPE:
        return

    if _awaiting_confirmation:
        get_tree().quit()
        return

    _awaiting_confirmation = true
    label.visible = true
    timer.start()


func _on_confirmation_window_elapsed() -> void:
    _awaiting_confirmation = false
    label.visible = false
