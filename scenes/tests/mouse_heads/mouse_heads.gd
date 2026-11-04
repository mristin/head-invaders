class_name MouseHeads

extends HeadController

## Play the heads with the mouse and the keyboard, for testing only; the game
## itself needs a camera.
##
## The mouse is the head of the first player; Space makes it leave and come
## back. The keys 1 to 9 bring in and send away the bots, which wander around
## on their own.

var _mouse_present: bool = true
var _bots: Dictionary[int, float] = {}
var _time: float = 0.0


func _ready() -> void:
    # NOTE (mristin):
    # The game connects to our signals only after adding us.
    head_appeared.emit.call_deferred(0, get_viewport().get_mouse_position())


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and _mouse_present:
        head_moved.emit(0, get_viewport().get_mouse_position())
        return

    if not (event is InputEventKey and event.pressed and not event.echo):
        return

    if event.keycode == KEY_SPACE:
        _mouse_present = not _mouse_present
        if _mouse_present:
            head_appeared.emit(0, get_viewport().get_mouse_position())
        else:
            head_lost.emit(0)
    elif event.keycode >= KEY_1 and event.keycode <= KEY_9:
        var id := int(event.keycode - KEY_0)
        if _bots.erase(id):
            head_lost.emit(id)
        else:
            _bots[id] = randf() * TAU
            head_appeared.emit(id, _bot_position(id))


func _process(delta: float) -> void:
    _time += delta
    for id in _bots:
        head_moved.emit(id, _bot_position(id))


func _bot_position(id: int) -> Vector2:
    var rect := get_viewport().get_visible_rect()
    var phase: float = _bots[id]
    var t := _time * (0.25 + 0.04 * id) + phase
    return (
        rect.get_center()
        + Vector2(sin(t) * rect.size.x * 0.4, 0.2 * rect.size.y + sin(t * 1.7) * rect.size.y * 0.2)
    )
