class_name Djinn

extends Enemy

## A jolly blue djinn of the sandstorm, floating in a lazy figure of eight in
## the upper part of the screen, with a curly tail of wind instead of legs. It
## spins up a little sand twister, which winds slowly down the screen in big,
## swaying curves towards the nearest spaceship. The twister is slow and
## easy to see, but the players have to watch which way it sways.

## The figure of eight around the djinn's place in the level, in radii of
## the djinn.
@export var path_width: float = 3.0
@export var path_height: float = 0.5
@export var path_speed: float = 0.5

## How fast the djinn floats in to its place.
@export var enter_speed: float = 300.0

## How fast the twister winds down, how far it sways to the sides, in radii
## of the djinn, and how many times per second.
@export var twister_speed: float = 170.0
@export var twister_sway: float = 1.4
@export var twister_frequency: float = 0.35

## How many twisters the djinn has spun up so far, e.g., for the tests.
var twisters_spun: int = 0

var _time: float = 0.0
var _path_t: float = 0.0
var _floating_in: bool = true
var _spin: float = 0.0

## The twisters in flight, with the age and the heading of each.
var _twisters: Array[Rocket] = []
var _twister_ages: Array[float] = []
var _twister_headings: Array[Vector2] = []


func _ready() -> void:
    super()
    rocket_look = Rocket.Look.TWISTER


func _path(t: float) -> Vector2:
    return home + Vector2(sin(t) * path_width, sin(t * 2.0) * path_height) * radius


func _move(delta: float) -> void:
    _time += delta
    _spin = maxf(0.0, _spin - delta)

    if _floating_in:
        position = position.move_toward(_path(_path_t), enter_speed * delta)
        if position.is_equal_approx(_path(_path_t)):
            _floating_in = false
    else:
        _path_t += path_speed * delta
        var bounds := get_viewport_rect()
        var at := _path(_path_t)
        at.x = clampf(at.x, bounds.position.x + radius, bounds.end.x - radius)
        position = at

    _steer_twisters(delta)


func _fire_rocket() -> void:
    if _floating_in:
        return

    var target := _nearest_spaceship()
    var heading := Vector2.DOWN
    if target != null:
        heading = global_position.direction_to(target.global_position)
        # NOTE (mristin):
        # The twister always winds downwards, never sideways.
        heading = Vector2(heading.x, maxf(heading.y, 0.7)).normalized()

    var twister := _launch_rocket_from(
        global_position + Vector2(0, radius * 0.6), heading, twister_speed
    )
    if twister == null:
        return

    twisters_spun += 1
    _spin = 0.8
    twister.lifetime = rocket_lifetime
    _twisters.append(twister)
    _twister_ages.append(0.0)
    _twister_headings.append(heading)


## Wind the twisters in flight from side to side along their headings.
func _steer_twisters(delta: float) -> void:
    for i in range(_twisters.size() - 1, -1, -1):
        var twister := _twisters[i]
        if not is_instance_valid(twister) or twister.is_queued_for_deletion():
            _twisters.remove_at(i)
            _twister_ages.remove_at(i)
            _twister_headings.remove_at(i)
            continue

        _twister_ages[i] += delta
        var heading := _twister_headings[i]
        var omega := TAU * twister_frequency
        var sway := cos(_twister_ages[i] * omega) * twister_sway * radius * omega
        twister.velocity = heading * twister_speed + heading.orthogonal() * sway
        twister.rotation = twister.velocity.angle()


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var blue := Color(0.4, 0.62, 0.95).lerp(white, flash)
    var light_blue := Color(0.6, 0.78, 1.0).lerp(white, flash)
    var gold := Color(1.0, 0.8, 0.3).lerp(white, flash)

    # NOTE (mristin):
    # The tail of wind curls under the djinn, and spins fast when it spins up
    # a twister.
    var tail := PackedVector2Array()
    var spin := _time * (3.0 + 10.0 * _spin)
    for i in range(16):
        var t := i / 15.0
        tail.append(Vector2(sin(t * 7.0 + spin) * r * 0.22 * (1.0 - t), r * 0.15 + t * r * 0.65))
    draw_polyline(tail, light_blue, r * 0.28 * 0.6, true)
    for i in range(3):
        var t := i / 3.0
        var at := Vector2(sin(t * 7.0 + spin) * r * 0.2 * (1.0 - t), r * 0.2 + t * r * 0.6)
        draw_circle(at, r * lerpf(0.26, 0.1, t), blue)

    # The body, the arms crossed in front, and the golden bracelets.
    draw_circle(Vector2(0, 0), r * 0.36, blue)
    draw_circle(Vector2(0, r * 0.05), r * 0.22, light_blue)
    for side: float in [-1.0, 1.0]:
        var shoulder := Vector2(side * r * 0.3, -r * 0.05)
        var hand := Vector2(-side * r * 0.08, r * 0.1 + side * r * 0.04)
        draw_line(shoulder, hand, blue, r * 0.14, true)
        draw_circle(shoulder.lerp(hand, 0.55), r * 0.08, gold)

    # The head with the turban, the friendly eyes and the curly beard.
    var head := Vector2(0, -r * 0.42)
    draw_circle(head, r * 0.28, blue)
    var turban := PackedVector2Array()
    for i in range(17):
        var a := PI + PI * i / 16.0
        turban.append(head + Vector2(cos(a) * r * 0.32, sin(a) * r * 0.26 - r * 0.08))
    draw_colored_polygon(turban, Color(0.85, 0.35, 0.55).lerp(white, flash))
    draw_circle(head + Vector2(0, -r * 0.2), r * 0.06, gold)
    for side: float in [-1.0, 1.0]:
        var eye := head + Vector2(side * r * 0.1, r * 0.03)
        draw_circle(eye, r * 0.07, white)
        draw_circle(eye + Vector2(0, r * 0.01), r * 0.04, Color(0.08, 0.1, 0.25))
        draw_circle(eye + Vector2(-r * 0.015, -r * 0.02), r * 0.015, white)
    draw_arc(
        head + Vector2(0, r * 0.1), r * 0.1, 0.25, PI - 0.25, 10, Color(0.1, 0.15, 0.35), r * 0.03
    )
    draw_circle(head + Vector2(0, r * 0.25), r * 0.06, Color(0.25, 0.3, 0.6).lerp(white, flash))
