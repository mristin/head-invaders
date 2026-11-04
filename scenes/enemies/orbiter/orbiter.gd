class_name Orbiter

extends Enemy

## A little planet with a ring: it circles around its place in the level, and
## fires the rockets at the nearest spaceship. Its place first comes down from
## above the screen.

@export var orbit_radius: float = 150.0

## How fast the orbiter circles, in radians per second.
@export var angular_speed: float = 1.2

## How fast the center of the orbit comes down to its place.
@export var descent_speed: float = 200.0

var _center: Vector2 = Vector2.ZERO
var _angle: float = 0.0
var _turn: float = 1.0
var _time: float = 0.0


func _ready() -> void:
    super()
    _turn = -1.0 if randf() < 0.5 else 1.0
    _angle = randf() * TAU


func _enter() -> void:
    _center = Vector2(home.x, get_viewport_rect().position.y - orbit_radius - radius * 2.0)
    if spawned_in_place:
        _center = home
    _place()


func _move(delta: float) -> void:
    _time += delta
    _center.y = minf(_center.y + descent_speed * delta, home.y)
    _angle += _turn * angular_speed * delta
    _place()


func _place() -> void:
    position = _center + Vector2(cos(_angle), sin(_angle)) * orbit_radius


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var tilt := -0.35
    var ring_color := Color(1.0, 0.8, 0.35).lerp(white, flash)

    # NOTE (mristin):
    # We draw the back half of the ring, the planet, then the front half, so
    # that the ring goes around the planet.
    draw_set_transform(Vector2.ZERO, tilt, Vector2(1.0, 0.3))
    draw_arc(Vector2.ZERO, r * 1.05, PI, TAU, 24, ring_color, r * 0.3)
    draw_set_transform(Vector2.ZERO, 0.0)

    draw_circle(Vector2.ZERO, r * 0.62, Color(0.25, 0.75, 0.55).lerp(white, flash))
    draw_circle(Vector2(r * 0.18, r * 0.2), r * 0.16, Color(0.2, 0.6, 0.45).lerp(white, flash))
    draw_circle(Vector2(-r * 0.25, -r * 0.3), r * 0.1, Color(1, 1, 1, 0.3))

    # NOTE (mristin):
    # The eyes follow the direction the orbiter is circling in.
    var look := Vector2(-sin(_angle), cos(_angle)) * _turn * r * 0.04
    for side: float in [-1.0, 1.0]:
        var eye := Vector2(side * r * 0.22, -r * 0.08)
        draw_circle(eye, r * 0.13, white)
        draw_circle(eye + look, r * 0.06, Color(0.1, 0.2, 0.15))

    draw_set_transform(Vector2.ZERO, tilt, Vector2(1.0, 0.3))
    draw_arc(Vector2.ZERO, r * 1.05, 0.0, PI, 24, ring_color, r * 0.3)
    draw_set_transform(Vector2.ZERO, 0.0)
