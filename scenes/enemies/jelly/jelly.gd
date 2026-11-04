class_name Jelly

extends Enemy

## A space jelly: big, slow and sturdy. It floats down to its place, then
## drifts sideways after the nearest spaceship, and now and then puffs a fan of
## slow rockets straight down.

## How fast the jelly floats down to its place.
@export var descent_speed: float = 120.0

## How fast the jelly drifts after the nearest spaceship.
@export var drift_speed: float = 70.0

@export var bob_amplitude: float = 18.0
@export var bob_frequency: float = 0.4

## The number of rockets in a fan, and the angle between them, in radians.
@export var fan_size: int = 3
@export var fan_angle: float = 0.4

@export var margin: float = 110.0

var _time: float = 0.0
var _descending: bool = true


func _move(delta: float) -> void:
    _time += delta

    if _descending:
        position.y = minf(position.y + descent_speed * delta, home.y)
        if position.y >= home.y:
            _descending = false
            _time = 0.0
        return

    var bounds := get_viewport_rect()
    var target := _nearest_spaceship()
    if target != null:
        position.x = move_toward(position.x, target.global_position.x, drift_speed * delta)
    position.x = clampf(position.x, bounds.position.x + margin, bounds.end.x - margin)

    position.y = home.y + sin(_time * TAU * bob_frequency) * bob_amplitude


func _fire_rocket() -> void:
    for i in range(fan_size):
        var angle := (i - (fan_size - 1) / 2.0) * fan_angle
        _launch_rocket(Vector2.DOWN.rotated(angle), rocket_speed)


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius

    # NOTE (mristin):
    # The tentacles wave below the bell.
    var tentacle_color := Color(0.95, 0.55, 0.85, 0.85).lerp(white, flash)
    for i in range(5):
        var x := -r * 0.6 + r * 1.2 * i / 4.0
        var points := PackedVector2Array()
        for j in range(8):
            var t := j / 7.0
            var wave := sin(_time * 4.0 + i * 1.3 + t * 5.0) * r * 0.12 * t
            points.append(Vector2(x + wave, r * 0.05 + t * r * 0.75))
        draw_polyline(points, tentacle_color, r * 0.1, true)

    # NOTE (mristin):
    # The bell squishes a little as the jelly swims.
    var squish := 1.0 + sin(_time * 3.0) * 0.06
    var bell := PackedVector2Array()
    for i in range(25):
        var angle := PI + PI * i / 24.0
        bell.append(Vector2(cos(angle) * r * squish, sin(angle) * r * 0.8 / squish))
    for i in range(7):
        var x := r * squish - 2.0 * r * squish * i / 6.0
        bell.append(Vector2(x, r * 0.12 * (1.0 if i % 2 == 0 else 0.4)))
    draw_colored_polygon(bell, Color(0.75, 0.35, 0.95).lerp(white, flash))

    var shine := Color(1, 1, 1, 0.25 + 0.5 * flash)
    draw_circle(Vector2(-r * 0.45, -r * 0.5), r * 0.14, shine)

    # NOTE (mristin):
    # The friendly face makes the jelly cute rather than scary.
    for side: float in [-1.0, 1.0]:
        var eye := Vector2(side * r * 0.3, -r * 0.25)
        draw_circle(eye, r * 0.16, white)
        draw_circle(eye + Vector2(0, r * 0.03), r * 0.08, Color(0.15, 0.1, 0.25))
    draw_arc(Vector2(0, -r * 0.08), r * 0.15, 0.2, PI - 0.2, 12, Color(0.2, 0.1, 0.3), r * 0.05)
