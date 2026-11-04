class_name SunBall

extends Enemy

## The big, smiling sun ball of the great scarab. It floats right below
## the scarab and slides over to shield it from the nearest spaceship: the
## bullets bounce off the sun ball with a "ting", so the players have to fly
## around it. Now and then the scarab rolls it down the screen: first the ball
## wobbles and a soft lane shows where it will roll, then it rolls straight
## down. While it rolls, the scarab has no shield, until a new sun ball grows
## below it.
##
## The sun ball can not be beaten; it follows the scarab home.

enum State { GROWING, GUARDING, WINDING_UP, ROLLING }

## The size of the sun ball, in radii of the scarab.
@export var size: float = 0.45

## How far below the scarab the sun ball floats, in radii of the scarab.
@export var below: float = 1.25

## How far the sun ball slides to the sides, in radii of the scarab, and how
## fast.
@export var guard_reach: float = 0.5
@export var guard_speed: float = 170.0

@export var grow_duration: float = 1.8
@export var windup_duration: float = 1.2
@export var roll_speed: float = 430.0

## How many sparks the sun ball shines all around when it has grown, once
## the scarab is in a hurry.
@export var spark_count: int = 6
@export var spark_speed: float = 240.0

## How often a bounced bullet goes "ting" at most, in seconds.
@export var ting_interval: float = 0.15

## The scarab, which the sun ball shields.
var scarab: GreatScarab = null

## How many bullets bounced off so far, e.g., for the tests.
var bounced_hits: int = 0

## How many times the sun ball rolled so far, e.g., for the tests.
var rolls: int = 0

var _state: State = State.GROWING
var _state_left: float = 0.0
var _time: float = 0.0
var _spin: float = 0.0
var _offset_x: float = 0.0
var _ting_cooldown: float = 0.0
var _shape: CollisionShape2D = null
var _full_radius: float = 0.0


func _ready() -> void:
    super()
    rocket_look = Rocket.Look.ZAP
    max_energy = 10000
    energy = max_energy

    # NOTE (mristin):
    # The sun ball takes its size from the scarab, so we make its shape here.
    if scarab != null:
        radius = scarab.radius * size
    _full_radius = radius
    _shape = CollisionShape2D.new()
    var circle := CircleShape2D.new()
    circle.radius = radius * 0.9
    _shape.shape = circle
    add_child(_shape)
    _grow()


func is_targetable() -> bool:
    return false


func is_guarding() -> bool:
    return _state == State.GUARDING


func is_rolling() -> bool:
    return _state == State.ROLLING or _state == State.WINDING_UP


## Wind up and roll down the screen, if guarding.
func roll() -> bool:
    if _state != State.GUARDING:
        return false
    _state = State.WINDING_UP
    _state_left = windup_duration
    return true


func take_damage(_amount: int) -> void:
    if not is_alive() or not has_arrived():
        return
    bounced_hits += 1
    if _ting_cooldown <= 0.0:
        _ting_cooldown = ting_interval
        Poof.spawn(self, global_position + Vector2(0, radius * 0.7), radius * 0.25, Color(1, 1, 1))


func _may_fire() -> bool:
    return false


func _grow() -> void:
    _state = State.GROWING
    _state_left = grow_duration
    _offset_x = 0.0
    radius = _full_radius * 0.1
    set_deferred("monitorable", false)
    _follow_scarab(0.0)


## Return how much the sun ball has grown, from 0 to 1.
func _growth() -> float:
    if _state != State.GROWING:
        return 1.0
    return 1.0 - _state_left / grow_duration


func _follow_scarab(delta: float) -> void:
    if scarab == null or not is_instance_valid(scarab):
        return

    var reach := scarab.radius * guard_reach
    var wanted := 0.0
    var target := _nearest_spaceship()
    if target != null and _state == State.GUARDING:
        wanted = clampf(target.global_position.x - scarab.global_position.x, -reach, reach)
    _offset_x = move_toward(_offset_x, wanted, guard_speed * delta)
    var before := position.x
    position = scarab.position + Vector2(_offset_x, scarab.radius * below)
    _spin += (position.x - before) / maxf(radius, 1.0)


func _move(delta: float) -> void:
    _time += delta
    _ting_cooldown = maxf(0.0, _ting_cooldown - delta)
    _state_left -= delta

    match _state:
        State.GROWING:
            _follow_scarab(delta)
            radius = _full_radius * lerpf(0.1, 1.0, _growth())
            (_shape.shape as CircleShape2D).radius = radius * 0.9
            monitorable = _growth() > 0.4
            if _state_left <= 0.0:
                _state = State.GUARDING
                radius = _full_radius
                _shine()
        State.GUARDING:
            _follow_scarab(delta)
        State.WINDING_UP:
            if _state_left <= 0.0:
                _state = State.ROLLING
                rolls += 1
        State.ROLLING:
            position.y += roll_speed * delta
            _spin += roll_speed * delta / maxf(radius, 1.0)
            if global_position.y > get_viewport_rect().end.y + radius * 1.5:
                _grow()


## Shine the sparks all around, once the scarab is in a hurry.
func _shine() -> void:
    if scarab == null or not is_instance_valid(scarab):
        return
    if not scarab.is_in_a_hurry() or not get_viewport_rect().has_point(global_position):
        return
    var start := randf() * TAU
    for i in range(spark_count):
        _launch_rocket(Vector2.RIGHT.rotated(start + TAU * i / spark_count), spark_speed)


func _draw() -> void:
    if is_fleeing():
        super()
        return

    # NOTE (mristin):
    # The sun ball can not be beaten, so it shows no energy bar.
    _draw_body(clampf(_hit_flash / 0.12, 0.0, 1.0))


func _draw_body(_flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius

    if _state == State.WINDING_UP:
        # NOTE (mristin):
        # The soft lane shows where the sun ball will roll.
        var lane_length := get_viewport_rect().end.y - global_position.y + r
        var pulse := 0.5 + 0.5 * sin(_time * 10.0)
        draw_rect(
            Rect2(Vector2(-r, 0), Vector2(r * 2.0, lane_length)),
            Color(1.0, 0.8, 0.4, 0.08 + 0.06 * pulse)
        )
        for side: float in [-1.0, 1.0]:
            draw_line(
                Vector2(side * r, 0),
                Vector2(side * r, lane_length),
                Color(1.0, 0.85, 0.5, 0.25 + 0.15 * pulse),
                4.0
            )

    var wobble := 0.0
    if _state == State.WINDING_UP:
        wobble = sin(_time * 30.0) * r * 0.06

    var center := Vector2(wobble, 0)
    draw_circle(center, r * 1.15, Color(1.0, 0.75, 0.3, 0.18))
    for i in range(10):
        var a := TAU * i / 10.0 + _time * 0.6
        draw_colored_polygon(
            PackedVector2Array(
                [
                    center + Vector2.from_angle(a - 0.12) * r * 0.95,
                    center + Vector2.from_angle(a) * r * 1.22,
                    center + Vector2.from_angle(a + 0.12) * r * 0.95,
                ]
            ),
            Color(1.0, 0.7, 0.25)
        )
    draw_circle(center, r, Color(1.0, 0.72, 0.25))
    draw_circle(center + Vector2(-r * 0.1, -r * 0.1), r * 0.82, Color(1.0, 0.82, 0.35))

    # NOTE (mristin):
    # The swirls show the sun ball rolling; the face stays upright.
    for i in range(3):
        var a := _spin + TAU * i / 3.0
        draw_arc(center, r * 0.68, a, a + 0.9, 10, Color(1.0, 0.62, 0.2, 0.7), r * 0.06, true)
    draw_circle(center + Vector2(-r * 0.35, -r * 0.4), r * 0.14, Color(1, 1, 1, 0.5))

    var excited := _state == State.WINDING_UP or _state == State.ROLLING
    for side: float in [-1.0, 1.0]:
        var eye := center + Vector2(side * r * 0.3, -r * 0.1)
        if excited:
            draw_circle(eye, r * 0.15, white)
            draw_circle(eye, r * 0.08, Color(0.35, 0.15, 0.05))
        else:
            draw_arc(eye, r * 0.12, PI + 0.3, TAU - 0.3, 10, Color(0.45, 0.2, 0.05), r * 0.05)
        draw_circle(center + Vector2(side * r * 0.5, r * 0.15), r * 0.1, Color(1.0, 0.5, 0.45, 0.7))
    if excited:
        draw_circle(center + Vector2(0, r * 0.3), r * 0.13, Color(0.55, 0.2, 0.1))
    else:
        draw_arc(
            center + Vector2(0, r * 0.15),
            r * 0.25,
            0.3,
            PI - 0.3,
            12,
            Color(0.45, 0.2, 0.05),
            r * 0.06
        )
