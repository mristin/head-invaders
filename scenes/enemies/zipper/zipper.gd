class_name Zipper

extends Enemy

## A little buzzing bug: it rests for a moment, then zips to another spot in
## the upper part of the screen. It is fragile, but hard to catch, and fires
## the rockets at the nearest spaceship only while resting.

## How long the zipper rests between the zips, in seconds.
@export var rest_duration: float = 1.6

## How long a zip takes, in seconds.
@export var zip_duration: float = 0.5

## The zipper stays above this fraction of the screen height.
@export_range(0.0, 1.0) var lowest: float = 0.5

@export var margin: float = 100.0

var _time: float = 0.0
var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _zip_elapsed: float = 0.0
var _rest_left: float = 0.0
var _zipping: bool = false


func _enter() -> void:
    super()
    _zip_to(home)


func _zip_to(to: Vector2) -> void:
    _from = position
    _to = to
    _zip_elapsed = 0.0
    _zipping = true


func _move(delta: float) -> void:
    _time += delta

    if _zipping:
        _zip_elapsed += delta
        var t := clampf(_zip_elapsed / zip_duration, 0.0, 1.0)
        position = _from.lerp(_to, smoothstep(0.0, 1.0, t))
        if t >= 1.0:
            _zipping = false
            _rest_left = rest_duration * randf_range(0.8, 1.2)
        return

    # NOTE (mristin):
    # The zipper hovers in place, buzzing a little.
    position = _to + Vector2(sin(_time * 9.0), cos(_time * 7.0)) * 3.0

    _rest_left -= delta
    if _rest_left <= 0.0:
        var bounds := get_viewport_rect()
        _zip_to(
            Vector2(
                randf_range(bounds.position.x + margin, bounds.end.x - margin),
                randf_range(bounds.position.y + margin, bounds.position.y + bounds.size.y * lowest)
            )
        )


func _rocket_direction() -> Vector2:
    if _zipping:
        return Vector2.ZERO
    return super()


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var body_color := Color(1.0, 0.75, 0.15).lerp(white, flash)

    # NOTE (mristin):
    # The trail shows where the zipper came from.
    if _zipping:
        var back := (_from - _to).normalized() if _from != _to else Vector2.UP
        for i in range(3):
            var center := back * r * 0.6 * (i + 1)
            draw_circle(center, r * (0.45 - 0.1 * i), Color(body_color, 0.3 - 0.08 * i))

    # NOTE (mristin):
    # The wings flap so fast that they blur.
    var flap := 0.75 + 0.25 * sin(_time * 50.0)
    for side: float in [-1.0, 1.0]:
        draw_set_transform(Vector2(side * r * 0.45, -r * 0.35), side * 0.5, Vector2(1.0, flap))
        draw_circle(Vector2.ZERO, r * 0.4, Color(0.8, 0.95, 1.0, 0.55))
    draw_set_transform(Vector2.ZERO, 0.0)

    draw_circle(Vector2.ZERO, r * 0.55, body_color)
    for i in range(2):
        var y := r * (0.12 + 0.22 * i)
        var half := sqrt(maxf(0.0, r * r * 0.3 - y * y))
        draw_line(Vector2(-half, y), Vector2(half, y), Color(0.35, 0.2, 0.05), r * 0.1)

    for side: float in [-1.0, 1.0]:
        var eye := Vector2(side * r * 0.2, -r * 0.15)
        draw_circle(eye, r * 0.14, white)
        draw_circle(eye + Vector2(0, r * 0.03), r * 0.07, Color(0.15, 0.1, 0.05))
