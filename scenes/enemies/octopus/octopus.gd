class_name Octopus

extends Enemy

## A little octopus: it jets from spot to spot in the upper part of the screen
## and fires a quick burst of ink blobs at the nearest spaceship. When hit, it
## squirts a cloud of ink and darts away to another spot.

## How long the octopus rests between the jets, in seconds.
@export var rest_duration: float = 1.8

## How long a jet takes, in seconds.
@export var jet_duration: float = 0.9

## After darting away from a hit, it waits this long before darting again.
@export var dart_cooldown: float = 2.0

## The burst: the number of ink blobs, and the seconds between them.
@export var burst_size: int = 2
@export var burst_interval: float = 0.25

## The octopus stays above this fraction of the screen height.
@export_range(0.0, 1.0) var lowest: float = 0.5

@export var margin: float = 110.0

var _time: float = 0.0
var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _jet_elapsed: float = 0.0
var _jetting: bool = false
var _rest_left: float = 0.0
var _dart_left: float = 0.0
var _burst_left: int = 0
var _burst_cooldown: float = 0.0


func _enter() -> void:
    super()
    _jet_to(home)


func take_damage(amount: int) -> void:
    super(amount)

    if is_alive() and has_arrived() and _dart_left <= 0.0:
        # NOTE (mristin):
        # Squirt the ink and dart away.
        _dart_left = dart_cooldown
        Poof.spawn(self, global_position, radius, Color(0.35, 0.1, 0.45))
        _jet_to(_random_spot())


func _random_spot() -> Vector2:
    var bounds := get_viewport_rect()
    return Vector2(
        randf_range(bounds.position.x + margin, bounds.end.x - margin),
        randf_range(bounds.position.y + margin, bounds.position.y + bounds.size.y * lowest)
    )


func _jet_to(to: Vector2) -> void:
    _from = position
    _to = to
    _jet_elapsed = 0.0
    _jetting = true


func _move(delta: float) -> void:
    _time += delta
    _dart_left = maxf(0.0, _dart_left - delta)

    if _burst_left > 0:
        _burst_cooldown -= delta
        if _burst_cooldown <= 0.0:
            _burst_cooldown = burst_interval
            _burst_left -= 1
            var aim := _rocket_direction()
            if aim != Vector2.ZERO:
                _launch_rocket(aim, rocket_speed)

    if _jetting:
        _jet_elapsed += delta
        var t := clampf(_jet_elapsed / jet_duration, 0.0, 1.0)
        # NOTE (mristin):
        # The jet is quick at first, then glides to a stop.
        position = _from.lerp(_to, 1.0 - pow(1.0 - t, 3.0))
        if t >= 1.0:
            _jetting = false
            _rest_left = rest_duration * randf_range(0.8, 1.2)
        return

    position = _to + Vector2(0, sin(_time * 2.5) * 6.0)
    _rest_left -= delta
    if _rest_left <= 0.0:
        _jet_to(_random_spot())


func _fire_rocket() -> void:
    _burst_left = burst_size
    _burst_cooldown = 0.0


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var color := Color(1.0, 0.5, 0.6).lerp(white, flash)
    var dark := Color(0.85, 0.35, 0.45).lerp(white, flash)

    # NOTE (mristin):
    # The tentacles stream behind while jetting, and curl while resting.
    var stream := 0.0
    if _jetting:
        stream = 1.0 - clampf(_jet_elapsed / jet_duration, 0.0, 1.0)
    for i in range(6):
        var x := (i - 2.5) * r * 0.16
        var points := PackedVector2Array()
        for j in range(8):
            var t := j / 7.0
            var curl := sin(_time * 4.0 + i * 1.3 + t * 4.0) * r * 0.12 * t * (1.0 - stream)
            points.append(
                Vector2(x * (1.0 - 0.4 * stream) + curl, r * 0.1 + t * r * (0.55 + 0.35 * stream))
            )
        draw_polyline(points, dark, r * 0.1, true)

    var squeeze := 1.0 - 0.15 * stream
    var head := PackedVector2Array()
    for i in range(28):
        var a := TAU * i / 28.0
        head.append(Vector2(cos(a) * r * 0.48 * squeeze, sin(a) * r * 0.45 / squeeze - r * 0.15))
    draw_colored_polygon(head, color)
    draw_circle(Vector2(-r * 0.18, -r * 0.4), r * 0.08, Color(1, 1, 1, 0.4))

    for side: float in [-1.0, 1.0]:
        var eye := Vector2(side * r * 0.17, -r * 0.08)
        draw_circle(eye, r * 0.1, white)
        draw_circle(eye + Vector2(0, r * 0.02), r * 0.05, Color(0.15, 0.05, 0.1))
    draw_circle(Vector2(0, r * 0.1), r * 0.06, dark.darkened(0.2))
