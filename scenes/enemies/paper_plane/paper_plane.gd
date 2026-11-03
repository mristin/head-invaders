class_name PaperPlane

extends Enemy

## A big, happy paper airplane folded from a colorful page. It glides across
## the screen, turns around in wide arcs at the edges, and now and then flies
## a loop-the-loop. It throws a pair of little paper darts at the nearest
## spaceship, which curve out in mirrored arcs like boomerangs and then come
## back to the plane, which catches them again. So the players have to watch
## out for the darts twice: on the way out and on the way back.

@export var glide_speed: float = 230.0

## How fast the plane turns, in radians per second, at the edges and in
## the loop.
@export var turn_rate: float = 2.2
@export var loop_rate: float = 3.2

## Fly a loop-the-loop about this often, in seconds.
@export var loop_every: float = 7.0

## The darts: how fast they curve, in radians per second, how long they fly
## out before they turn back, and how fast they come back.
@export var dart_curve: float = 1.4
@export var dart_out_duration: float = 1.3
@export var dart_return_speed: float = 480.0
@export var dart_steer_rate: float = 4.0

@export var descent_speed: float = 260.0

@export var margin: float = 380.0

## How many darts the plane threw and caught again so far, e.g., for the tests.
var darts_thrown: int = 0
var darts_caught: int = 0

## How many loops the plane flew so far, e.g., for the tests.
var loops: int = 0

var _time: float = 0.0
var _descending: bool = true
var _heading: float = 0.0
var _direction: float = 1.0
var _loop_left: float = 0.0
var _loop_cooldown: float = 0.0

## The darts in flight, with their age and their curve.
var _darts: Array[Rocket] = []
var _dart_ages: Array[float] = []
var _dart_curves: Array[float] = []


func _ready() -> void:
    super()
    rocket_look = Rocket.Look.PAPER_DART
    _loop_cooldown = loop_every


func _enter() -> void:
    super()
    _heading = PI * 0.5
    var bounds := get_viewport_rect()
    _direction = 1.0 if home.x < bounds.get_center().x else -1.0


func _may_fire() -> bool:
    return not _descending and _loop_left <= 0.0 and _darts.is_empty()


func _move(delta: float) -> void:
    _time += delta
    _steer_darts(delta)

    if _descending:
        position.y = minf(position.y + descent_speed * delta, home.y)
        if position.y >= home.y:
            _descending = false
        return

    var bounds := get_viewport_rect()
    if _loop_left > 0.0:
        # NOTE (mristin):
        # The loop goes up first, against the direction of the clock when
        # flying to the right.
        var step := loop_rate * delta
        _heading -= _direction * step
        _loop_left -= step
    else:
        if position.x > bounds.end.x - margin:
            _direction = -1.0
        elif position.x < bounds.position.x + margin:
            _direction = 1.0

        # NOTE (mristin):
        # We aim the plane along its direction, but pull it back towards
        # the height of its home.
        var pull := clampf((home.y - position.y) / 300.0, -0.6, 0.6)
        var wanted := (Vector2(_direction, pull)).angle()
        _heading = rotate_toward(_heading, wanted, turn_rate * delta)

        _loop_cooldown -= delta
        var middle := absf(position.x - bounds.get_center().x) < bounds.size.x * 0.25
        if _loop_cooldown <= 0.0 and middle:
            _loop_cooldown = loop_every
            _loop_left = TAU
            loops += 1

    position += Vector2.from_angle(_heading) * glide_speed * delta
    position.y = clampf(
        position.y, bounds.position.y + radius, bounds.position.y + bounds.size.y * 0.5
    )


func _fire_rocket() -> void:
    var aim := _rocket_direction()
    if aim == Vector2.ZERO:
        return

    for side: float in [-1.0, 1.0]:
        var dart := _launch_rocket(aim.rotated(-side * 0.35), rocket_speed)
        if dart == null:
            continue
        dart.lifetime = 20.0
        _darts.append(dart)
        _dart_ages.append(0.0)
        _dart_curves.append(side * dart_curve)
        darts_thrown += 1


## Curve the darts out like boomerangs, then bring them back to be caught.
func _steer_darts(delta: float) -> void:
    for i in range(_darts.size() - 1, -1, -1):
        var dart := _darts[i]
        if not is_instance_valid(dart) or dart.is_queued_for_deletion():
            _forget_dart(i)
            continue
        if not dart.is_inside_tree():
            continue

        _dart_ages[i] += delta
        var age := _dart_ages[i]
        if age < dart_out_duration:
            var speed := rocket_speed * lerpf(1.0, 0.35, age / dart_out_duration)
            var direction := dart.velocity.normalized().rotated(_dart_curves[i] * delta)
            dart.velocity = direction * speed
        else:
            var wanted := dart.global_position.angle_to_point(global_position)
            var heading := rotate_toward(dart.velocity.angle(), wanted, dart_steer_rate * delta)
            var speed := move_toward(dart.velocity.length(), dart_return_speed, 600.0 * delta)
            dart.velocity = Vector2.from_angle(heading) * speed
            if dart.global_position.distance_to(global_position) < radius * 0.5:
                darts_caught += 1
                dart.queue_free()
                _forget_dart(i)
                continue
        dart.rotation = dart.velocity.angle()


func _forget_dart(i: int) -> void:
    _darts.remove_at(i)
    _dart_ages.remove_at(i)
    _dart_curves.remove_at(i)


func _start_fleeing(may_drop: bool = true) -> void:
    # NOTE (mristin):
    # The darts in flight unfold into a poof.
    for dart in _darts:
        if is_instance_valid(dart):
            Poof.spawn(self, dart.global_position, 18.0, Color(1.0, 0.7, 0.85))
            dart.queue_free()
    _darts.clear()
    _dart_ages.clear()
    _dart_curves.clear()
    super(may_drop)


func _energy_bar_y() -> float:
    return radius * 0.7


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius

    # NOTE (mristin):
    # We see the plane from above, its nose along its heading. The face
    # stays upright, so that it is always easy to see.
    draw_set_transform(Vector2.ZERO, _heading)
    var outline := PackedVector2Array(
        [
            Vector2(r * 0.78, 0),
            Vector2(-r * 0.58, -r * 0.62),
            Vector2(-r * 0.36, 0),
            Vector2(-r * 0.58, r * 0.62)
        ]
    )
    draw_colored_polygon(outline, Color(1, 1, 1, 0.9))
    var left := PackedVector2Array(
        [Vector2(r * 0.7, 0), Vector2(-r * 0.52, -r * 0.55), Vector2(-r * 0.32, 0)]
    )
    var right := PackedVector2Array(
        [Vector2(r * 0.7, 0), Vector2(-r * 0.32, 0), Vector2(-r * 0.52, r * 0.55)]
    )
    draw_colored_polygon(left, Color(0.55, 0.8, 1.0).lerp(white, flash))
    draw_colored_polygon(right, Color(0.45, 0.7, 0.95).lerp(white, flash))
    # The stripes printed on the paper, and the fold along the middle.
    for k in range(3):
        var x := -r * 0.3 + k * r * 0.22
        var half := (r * 0.7 - x) / (r * 1.22) * r * 0.55
        draw_line(
            Vector2(x, -half),
            Vector2(x, half),
            Color(1.0, 0.85, 0.4, 0.8).lerp(white, flash),
            r * 0.04
        )
    draw_line(
        Vector2(-r * 0.32, 0),
        Vector2(r * 0.7, 0),
        Color(0.3, 0.45, 0.7).lerp(white, flash),
        r * 0.04
    )
    draw_set_transform(Vector2.ZERO, 0.0)

    var face := Vector2.from_angle(_heading) * r * 0.05
    draw_circle(face, r * 0.24, Color(1.0, 0.97, 0.9).lerp(white, flash))
    var ink := Color(0.15, 0.15, 0.3)
    var looping := _loop_left > 0.0
    for side: float in [-1.0, 1.0]:
        var eye := face + Vector2(side * r * 0.09, -r * 0.04)
        if looping:
            # NOTE (mristin):
            # Happy, squeezed eyes in the loop-the-loop.
            draw_arc(eye + Vector2(0, r * 0.02), r * 0.045, PI + 0.3, TAU - 0.3, 8, ink, r * 0.025)
        else:
            draw_circle(eye, r * 0.055, white)
            draw_circle(eye + Vector2(0, r * 0.01), r * 0.034, ink)
            draw_circle(eye + Vector2(-r * 0.012, -r * 0.012), r * 0.012, white)
        draw_circle(
            face + Vector2(side * r * 0.16, r * 0.07), r * 0.035, Color(1.0, 0.55, 0.65, 0.8)
        )
    draw_arc(face + Vector2(0, r * 0.06), r * 0.07, 0.3, PI - 0.3, 10, ink, r * 0.025)
