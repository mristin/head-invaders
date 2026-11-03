class_name SandWorm

extends Enemy

## A big, sleepy sand worm with a bow on its head. It burrows under the sand,
## where only a moving mound of sand shows, and the bullets can not reach it.
## The mound creeps over to the spot above the nearest spaceship, so that
## the players see where it will pop up. There it pops out of the sand with
## a ring of sand balls, looks around, throws a sand ball at the nearest
## spaceship, and burrows again.
##
## The worm stays in the sand, so the spaceships fly over it.

enum Phase { BURROWED, RISING, UP, SINKING }

## How fast the mound creeps under the sand, in pixels per second.
@export var burrow_speed: float = 260.0

## How long the worm burrows at least, in seconds, before it pops up again.
@export var burrow_duration: float = 2.6

## How long it takes to pop out or to sink, and how long it stays out.
@export var rise_duration: float = 0.45
@export var up_duration: float = 3.4

## The ring of sand balls when it pops out.
@export var ring_size: int = 5
@export var ring_speed: float = 260.0

## The worm pops up in this band of the screen height.
@export_range(0.0, 1.0) var highest: float = 0.18
@export_range(0.0, 1.0) var lowest: float = 0.45

@export var margin: float = 160.0

## How many times the worm popped out of the sand so far, e.g., for the tests.
var pops: int = 0

var _phase: Phase = Phase.BURROWED
var _phase_left: float = 0.0
var _time: float = 0.0
var _target: Vector2 = Vector2.ZERO
var _thrown: bool = false


func _ready() -> void:
    super()
    grounded = true
    rocket_look = Rocket.Look.SAND


func is_burrowed() -> bool:
    return _phase == Phase.BURROWED


func is_targetable() -> bool:
    return _phase == Phase.UP or _phase == Phase.RISING


func take_damage(amount: int) -> void:
    if not is_targetable():
        return
    super(amount)


func _may_fire() -> bool:
    # NOTE (mristin):
    # The worm throws only when it is out of the sand; see _move.
    return false


func _enter() -> void:
    super()
    _burrow()


## Return how far the worm is out of the sand, from 0 to 1.
func _out() -> float:
    match _phase:
        Phase.UP:
            return 1.0
        Phase.RISING:
            return 1.0 - _phase_left / rise_duration
        Phase.SINKING:
            return _phase_left / rise_duration
        _:
            return 0.0


func _burrow() -> void:
    _phase = Phase.BURROWED
    _phase_left = burrow_duration
    set_deferred("monitorable", false)
    _pick_target()


func _pick_target() -> void:
    var bounds := get_viewport_rect()
    var x := randf_range(bounds.position.x + margin, bounds.end.x - margin)
    var target := _nearest_spaceship()
    if target != null:
        x = target.global_position.x + randf_range(-radius, radius)
    _target = Vector2(
        clampf(x, bounds.position.x + margin, bounds.end.x - margin),
        randf_range(
            bounds.position.y + bounds.size.y * highest, bounds.position.y + bounds.size.y * lowest
        )
    )


func _move(delta: float) -> void:
    _time += delta
    _phase_left -= delta

    match _phase:
        Phase.BURROWED:
            position = position.move_toward(_target, burrow_speed * delta)
            if _phase_left <= 0.0 and position.is_equal_approx(_target):
                _phase = Phase.RISING
                _phase_left = rise_duration
                set_deferred("monitorable", true)
                _pop()
        Phase.RISING:
            if _phase_left <= 0.0:
                _phase = Phase.UP
                _phase_left = up_duration
                _thrown = false
        Phase.UP:
            if not _thrown and _phase_left < up_duration * 0.5:
                _thrown = true
                var aim := _rocket_direction()
                if aim != Vector2.ZERO:
                    _launch_rocket(aim, rocket_speed)
            if _phase_left <= 0.0:
                _phase = Phase.SINKING
                _phase_left = rise_duration
        Phase.SINKING:
            if _phase_left <= 0.0:
                _burrow()


func _pop() -> void:
    pops += 1
    Poof.spawn(self, global_position, radius * 0.9, Color(0.95, 0.75, 0.45))
    if not get_viewport_rect().has_point(global_position):
        return
    var start := randf() * TAU
    for i in range(ring_size):
        _launch_rocket(Vector2.RIGHT.rotated(start + TAU * i / ring_size), ring_speed)


func _draw() -> void:
    if is_alive() and _phase == Phase.BURROWED:
        _draw_mound()
        return
    super()


## Draw the mound of sand which creeps over the worm under the sand.
func _draw_mound() -> void:
    var r := radius
    var sand := Color(0.62, 0.45, 0.27)
    var shadow := Color(0.25, 0.16, 0.09, 0.7)
    var wobble := sin(_time * 8.0) * r * 0.03
    draw_circle(Vector2(r * 0.08, r * 0.1), r * 0.5, shadow)
    draw_circle(Vector2(0, wobble), r * 0.46, sand)
    draw_circle(Vector2(-r * 0.12, -r * 0.12 + wobble), r * 0.24, Color(0.72, 0.55, 0.34))
    for i in range(3):
        var ripple := fmod(_time * 0.9 + i / 3.0, 1.0)
        draw_arc(
            Vector2.ZERO,
            r * (0.5 + 0.35 * ripple),
            0.0,
            TAU,
            32,
            Color(0.8, 0.62, 0.4, 0.35 * (1.0 - ripple)),
            r * 0.04,
            true
        )


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var out := _out() if is_alive() else 1.0
    var skin := Color(0.95, 0.62, 0.55).lerp(white, flash)
    var belly := Color(1.0, 0.8, 0.68).lerp(white, flash)
    var sand := Color(0.62, 0.45, 0.27)

    # NOTE (mristin):
    # The hole in the sand, then the worm standing out of it, seen from
    # slightly in front so that its face shows.
    draw_circle(Vector2(0, r * 0.38), r * 0.55, Color(0.25, 0.16, 0.09, 0.8))
    draw_arc(Vector2(0, r * 0.38), r * 0.55, 0.0, TAU, 32, sand, r * 0.1, true)

    var rise := r * 0.75 * out
    var sway := sin(_time * 2.4) * r * 0.08 * out
    var segments := 4
    for i in range(segments):
        var t := i / float(segments - 1)
        var center := Vector2(sway * t, r * 0.35 - rise * t)
        draw_circle(center, r * lerpf(0.4, 0.36, t), skin)
        draw_circle(center + Vector2(0, r * 0.06), r * lerpf(0.26, 0.22, t), belly)

    var head := Vector2(sway, r * 0.35 - rise)
    draw_circle(head, r * 0.42, skin)
    for side: float in [-1.0, 1.0]:
        var eye := head + Vector2(side * r * 0.16, -r * 0.05)
        draw_circle(eye, r * 0.12, white)
        draw_circle(eye + Vector2(side * r * 0.02, r * 0.02), r * 0.065, Color(0.15, 0.08, 0.1))
        draw_circle(eye + Vector2(-r * 0.03, -r * 0.03), r * 0.03, white)
        draw_circle(head + Vector2(side * r * 0.27, r * 0.12), r * 0.06, Color(1.0, 0.45, 0.5, 0.8))
    draw_arc(
        head + Vector2(0, r * 0.12), r * 0.12, 0.2, PI - 0.2, 10, Color(0.4, 0.15, 0.15), r * 0.04
    )

    # The bow on its head.
    var bow := head + Vector2(r * 0.15, -r * 0.38)
    var bow_color := Color(0.4, 0.75, 1.0).lerp(white, flash)
    for side: float in [-1.0, 1.0]:
        draw_colored_polygon(
            PackedVector2Array(
                [
                    bow,
                    bow + Vector2(side * r * 0.2, -r * 0.1),
                    bow + Vector2(side * r * 0.2, r * 0.1),
                ]
            ),
            bow_color
        )
    draw_circle(bow, r * 0.05, Color(0.3, 0.55, 0.9).lerp(white, flash))
