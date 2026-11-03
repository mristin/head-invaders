class_name Shark

extends Enemy

## A cartoon shark: it swims across the screen in its lane and comes back from
## the other side. When it swims over a spaceship, it dives at it, and swims
## back up to its lane. It does not fire; it only rams.

enum State { SWIM, DIVE, RISE }

## How fast the shark swims along its lane.
@export var speed: float = 230.0

## How fast it dives down at a spaceship, and how fast it swims back up.
@export var dive_speed: float = 650.0
@export var rise_speed: float = 320.0

## It dives at a spaceship within this horizontal distance.
@export var dive_reach: float = 70.0

@export var min_dive_interval: float = 2.5
@export var max_dive_interval: float = 4.5

## It dives at most this deep, as a fraction of the screen height.
@export_range(0.0, 1.0) var deepest: float = 0.85

var _time: float = 0.0
var _direction: float = 1.0
var _state: State = State.SWIM
var _dive_cooldown: float = 0.0
var _dive_to: float = 0.0


func _ready() -> void:
    super()
    _direction = 1.0 if randf() < 0.5 else -1.0
    _dive_cooldown = randf_range(min_dive_interval, max_dive_interval)


func is_diving() -> bool:
    return _state != State.SWIM


func _enter() -> void:
    # NOTE (mristin):
    # The shark swims in from the side, in its lane.
    var bounds := get_viewport_rect()
    var x := bounds.position.x - radius * 2.0 if _direction > 0.0 else bounds.end.x + radius * 2.0
    position = Vector2(x, home.y)


func _may_fire() -> bool:
    return false


func _move(delta: float) -> void:
    _time += delta
    _dive_cooldown -= delta

    var bounds := get_viewport_rect()
    match _state:
        State.SWIM:
            position.x += _direction * speed * delta
            position.y = home.y + sin(_time * 2.0) * 10.0

            if position.x > bounds.end.x + radius * 2.0:
                position.x = bounds.position.x - radius * 2.0
            elif position.x < bounds.position.x - radius * 2.0:
                position.x = bounds.end.x + radius * 2.0

            if _dive_cooldown <= 0.0 and bounds.has_point(global_position):
                var target := _nearest_spaceship()
                if (
                    target != null
                    and absf(target.global_position.x - global_position.x) < dive_reach
                ):
                    _state = State.DIVE
                    _dive_to = minf(
                        target.global_position.y, bounds.position.y + bounds.size.y * deepest
                    )
        State.DIVE:
            position.y = minf(position.y + dive_speed * delta, _dive_to)
            if position.y >= _dive_to:
                _state = State.RISE
        State.RISE:
            position.y = maxf(position.y - rise_speed * delta, home.y)
            if position.y <= home.y:
                _state = State.SWIM
                _dive_cooldown = randf_range(min_dive_interval, max_dive_interval)


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius

    # NOTE (mristin):
    # We draw the shark from the side, pointing along the positive x-axis,
    # and turn it to where it swims.
    var angle := 0.0
    var flip := 1.0
    match _state:
        State.DIVE:
            angle = PI / 2.0
        State.RISE:
            angle = -PI / 2.0
        _:
            if _direction < 0.0:
                angle = PI
                flip = -1.0
    if _state != State.SWIM and _direction < 0.0:
        flip = -1.0
    draw_set_transform(Vector2.ZERO, angle, Vector2(1.0, flip))

    var body_color := Color(0.45, 0.6, 0.75).lerp(white, flash)
    var wag := sin(_time * 10.0) * r * 0.08
    var tail := PackedVector2Array(
        [
            Vector2(-r * 0.7, 0),
            Vector2(-r * 1.05, -r * 0.35 + wag),
            Vector2(-r * 0.95, wag * 0.5),
            Vector2(-r * 1.05, r * 0.3 + wag),
        ]
    )
    draw_colored_polygon(tail, body_color)
    draw_colored_polygon(
        PackedVector2Array(
            [
                Vector2(-r * 0.15, -r * 0.25),
                Vector2(-r * 0.3, -r * 0.62),
                Vector2(r * 0.15, -r * 0.25)
            ]
        ),
        body_color
    )

    var body := PackedVector2Array()
    for i in range(32):
        var a := TAU * i / 32.0
        body.append(Vector2(cos(a) * r * 0.85, sin(a) * r * 0.32))
    draw_colored_polygon(body, body_color)

    var belly := PackedVector2Array()
    for i in range(17):
        var a := PI * i / 16.0
        belly.append(Vector2(cos(a) * r * 0.75, sin(a) * r * 0.24 + r * 0.04))
    draw_colored_polygon(belly, Color(0.92, 0.95, 1.0).lerp(white, flash))

    draw_colored_polygon(
        PackedVector2Array(
            [Vector2(0, r * 0.2), Vector2(-r * 0.15, r * 0.48), Vector2(r * 0.15, r * 0.25)]
        ),
        body_color.darkened(0.15)
    )

    var eye := Vector2(r * 0.5, -r * 0.08)
    draw_circle(eye, r * 0.09, white)
    draw_circle(eye + Vector2(r * 0.02, 0), r * 0.05, Color(0.05, 0.1, 0.2))
    draw_arc(
        Vector2(r * 0.55, r * 0.08), r * 0.15, 0.2, PI * 0.6, 8, Color(0.15, 0.2, 0.3), r * 0.03
    )

    draw_set_transform(Vector2.ZERO, 0.0)
