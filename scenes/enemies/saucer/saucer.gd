class_name Saucer

extends Enemy

## A flying saucer: it descends from above to its place in the level, then
## cruises from side to side, bobs up and down, and now and then fires a rocket
## at the nearest spaceship.

@export var speed: float = 110.0
@export var bob_amplitude: float = 24.0
@export var bob_frequency: float = 0.5

## How fast the saucer descends to its place when entering the screen.
@export var descent_speed: float = 220.0

## Turn around this far from the screen edge.
@export var margin: float = 110.0

var _direction: float = 1.0
var _time: float = 0.0
var _descending: bool = true


func _ready() -> void:
    super()
    _direction = -1.0 if randf() < 0.5 else 1.0


func _move(delta: float) -> void:
    _time += delta

    if _descending:
        position.y = minf(position.y + descent_speed * delta, home.y)
        if position.y >= home.y:
            _descending = false
            # NOTE (mristin):
            # We start bobbing from the home so that the saucer does not jump.
            _time = 0.0
        return

    var bounds := get_viewport_rect()
    position.x += _direction * speed * delta
    if position.x < bounds.position.x + margin:
        position.x = bounds.position.x + margin
        _direction = 1.0
    elif position.x > bounds.end.x - margin:
        position.x = bounds.end.x - margin
        _direction = -1.0

    position.y = home.y + sin(_time * TAU * bob_frequency) * bob_amplitude


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)

    var dome := Color(0.55, 0.95, 0.85, 0.85).lerp(white, flash)
    draw_circle(Vector2(0, -radius * 0.17), radius * 0.4, dome)

    var hull := PackedVector2Array()
    for i in range(32):
        var angle := TAU * i / 32.0
        hull.append(Vector2(cos(angle) * radius, sin(angle) * radius * 0.32))
    draw_colored_polygon(hull, Color(0.45, 0.5, 0.6).lerp(white, flash))

    # NOTE (mristin):
    # The lights run around the hull so that the saucer looks alive.
    for i in range(6):
        var x := -radius * 0.7 + radius * 1.4 * i / 5.0
        var on := fmod(_time * 4.0 + i, 3.0) < 1.0
        var light := Color(1.0, 0.9, 0.3) if on else Color(0.6, 0.2, 0.2)
        draw_circle(Vector2(x, radius * 0.04), radius * 0.085, light.lerp(white, flash))
