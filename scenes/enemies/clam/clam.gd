class_name Clam

extends GroundEnemy

## A giant clam drifting down with the current. It opens and closes its shell
## in turns. While it is closed, the bullets bounce off with a "ting"; when it
## opens, it spits a big pearl at the nearest spaceship, and only then it can
## be hit.

enum State { CLOSED, OPENING, OPEN, CLOSING }

@export var closed_duration: float = 2.4
@export var open_duration: float = 2.2

## How long the shell takes to open or close, in seconds.
@export var hinge_duration: float = 0.35

## How often a bounced bullet goes "ting" at most, in seconds.
@export var ting_interval: float = 0.15

## How many hits bounced off the closed shell, e.g., for the tests.
var bounced_hits: int = 0

var _time: float = 0.0
var _state: State = State.CLOSED
var _state_left: float = 0.0
var _ting_cooldown: float = 0.0
var _spat: bool = false


func _ready() -> void:
    super()
    _state_left = closed_duration * randf_range(0.5, 1.0)


func is_open() -> bool:
    return _state == State.OPEN


func take_damage(amount: int) -> void:
    if not is_open():
        if is_alive() and has_arrived():
            bounced_hits += 1
            if _ting_cooldown <= 0.0:
                _ting_cooldown = ting_interval
                Poof.spawn(
                    self, global_position + Vector2(0, -radius * 0.2), radius * 0.25, Color(1, 1, 1)
                )
        return
    super(amount)


func _may_fire() -> bool:
    # NOTE (mristin):
    # The clam fires only once per opening; see _walk.
    return false


## Return how open the shell is, from 0 (closed) to 1 (open).
func _openness() -> float:
    match _state:
        State.OPEN:
            return 1.0
        State.OPENING:
            return 1.0 - _state_left / hinge_duration
        State.CLOSING:
            return _state_left / hinge_duration
        _:
            return 0.0


func _walk(delta: float) -> void:
    _time += delta
    _ting_cooldown = maxf(0.0, _ting_cooldown - delta)
    _state_left -= delta

    if _state == State.OPEN and not _spat and _state_left < open_duration * 0.6:
        _spat = true
        if get_viewport_rect().has_point(global_position) and super._may_fire():
            var aim := _rocket_direction()
            if aim != Vector2.ZERO:
                _launch_rocket(aim, rocket_speed)

    if _state_left > 0.0:
        return

    match _state:
        State.CLOSED:
            _state = State.OPENING
            _state_left = hinge_duration
        State.OPENING:
            _state = State.OPEN
            _state_left = open_duration
            _spat = false
        State.OPEN:
            _state = State.CLOSING
            _state_left = hinge_duration
        _:
            _state = State.CLOSED
            _state_left = closed_duration


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var open := _openness()
    var shell := Color(0.75, 0.65, 0.85).lerp(white, flash)
    var ridge := Color(0.6, 0.5, 0.72).lerp(white, flash)

    # NOTE (mristin):
    # The lower shell is a bowl; the upper shell lifts when the clam opens.
    var lower := PackedVector2Array()
    for i in range(17):
        var a := PI * i / 16.0
        lower.append(Vector2(cos(a) * r * 0.8, sin(a) * r * 0.45))
    draw_colored_polygon(lower, shell)

    if open > 0.0:
        var inside := PackedVector2Array()
        for i in range(17):
            var a := PI + PI * i / 16.0
            inside.append(Vector2(cos(a) * r * 0.72, sin(a) * r * 0.5 * open))
        for i in range(17):
            var a := PI * i / 16.0
            inside.append(Vector2(cos(a) * r * 0.72, sin(a) * r * 0.12))
        draw_colored_polygon(inside, Color(1.0, 0.65, 0.75).lerp(white, flash))
        var pearl := Vector2(0, -r * 0.12 * open)
        draw_circle(pearl, r * 0.16 * open, Color(0.97, 0.95, 1.0))
        draw_circle(pearl + Vector2(-r * 0.05, -r * 0.05) * open, r * 0.05 * open, white)
        for side: float in [-1.0, 1.0]:
            var eye := Vector2(side * r * 0.36, -r * 0.08 * open)
            draw_circle(eye, r * 0.08 * open, white)
            draw_circle(eye, r * 0.04 * open, Color(0.2, 0.05, 0.15))

    var lift := -r * 0.55 * open
    var upper := PackedVector2Array()
    for i in range(17):
        var a := PI + PI * i / 16.0
        var scallop := 1.0 + 0.05 * absf(sin(a * 8.0))
        upper.append(
            Vector2(cos(a) * r * 0.8 * scallop, sin(a) * r * 0.55 * (1.0 - 0.6 * open) + lift)
        )
    draw_colored_polygon(upper, shell)
    for i in range(5):
        var a := PI + PI * (i + 1) / 6.0
        draw_line(
            Vector2(0, lift),
            Vector2(cos(a) * r * 0.72, sin(a) * r * 0.5 * (1.0 - 0.6 * open) + lift),
            ridge,
            r * 0.04
        )

    if open == 0.0:
        # NOTE (mristin):
        # The closed clam peeks out, sleepily.
        for side: float in [-1.0, 1.0]:
            draw_arc(
                Vector2(side * r * 0.25, r * 0.02),
                r * 0.07,
                0.2,
                PI - 0.2,
                8,
                Color(0.3, 0.2, 0.35),
                r * 0.03
            )
