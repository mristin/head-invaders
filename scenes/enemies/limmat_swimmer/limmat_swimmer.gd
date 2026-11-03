class_name LimmatSwimmer

extends GroundEnemy

## A swimmer floating down the Limmat on a donut float on a summer day, like
## the people of Zurich do. The float stays on the river: it follows the bends
## of the Limmat as the city slides down, and the current carries it a bit
## north all the time, so it drifts down slower than the ground. It turns
## round and round on the float, and squirts a pair of water drops from its
## water pistol at the nearest spaceship.
##
## Without the map of Zurich, e.g., in a plain test level, it simply drifts.

## How fast the current carries the float to the north, in pixels per second.
@export var current_speed: float = 14.0

## How fast the float follows the bends of the river, in pixels per second.
@export var follow_speed: float = 120.0

## How fast the float turns round, in radians per second.
@export var spin_speed: float = 0.5

## The angle between the two drops, in radians.
@export var squirt_angle: float = 0.22

var _time: float = 0.0
var _squirt_left: float = 0.0


## Return the x of the river at the swimmer's height, or NAN without a river.
func river_x() -> float:
    var map := get_tree().get_first_node_in_group(ZurichMap.GROUP) as ZurichMap
    if map == null:
        return NAN
    var d := map.distance_at_screen_y(global_position.y)
    if d < ZurichMap.LAKE_END:
        return NAN
    return map.limmat_x(d)


func _enter() -> void:
    super()
    var x := river_x()
    if not is_nan(x):
        position.x = x


func _walk(delta: float) -> void:
    _time += delta
    _squirt_left = maxf(0.0, _squirt_left - delta)
    position.y -= current_speed * delta

    var x := river_x()
    if not is_nan(x):
        position.x = move_toward(position.x, x, follow_speed * delta)


func _move(delta: float) -> void:
    var before := position.y
    super(delta)
    if position.y < before - 500.0:
        # NOTE (mristin):
        # We came around from the top at a random spot; jump onto the river.
        var x := river_x()
        if not is_nan(x):
            position.x = x


func _fire_rocket() -> void:
    var aim := _rocket_direction()
    if aim == Vector2.ZERO:
        return
    _squirt_left = 0.4
    for side: float in [-0.5, 0.5]:
        _launch_rocket(aim.rotated(side * squirt_angle), rocket_speed)


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius

    for k in range(2):
        var ripple := fmod(_time * 0.5 + k * 0.5, 1.0)
        draw_arc(
            Vector2.ZERO,
            r * (0.7 + 0.25 * ripple),
            0.0,
            TAU,
            32,
            Color(0.7, 0.85, 1.0, 0.4 * (1.0 - ripple)),
            3.0,
            true
        )

    # NOTE (mristin):
    # The donut float turns round, with its sprinkles.
    var spin := _time * spin_speed
    draw_circle(Vector2.ZERO, r * 0.62, Color(1.0, 0.55, 0.75).lerp(white, flash))
    draw_circle(Vector2.ZERO, r * 0.3, Color(0.3, 0.5, 0.75))
    var sprinkles: Array[Color] = [
        Color(1, 1, 0.5), Color(0.5, 1, 0.9), Color(1, 1, 1), Color(0.6, 0.7, 1)
    ]
    for k in range(10):
        var angle := spin + TAU * k / 10.0
        var at := Vector2.from_angle(angle) * r * 0.46
        var along := Vector2.from_angle(angle + 1.2) * r * 0.05
        draw_line(at - along, at + along, sprinkles[k % 4], r * 0.04)

    # The swimmer sits in the hole, with the swimming cap and the goggles up.
    var skin := Color(1.0, 0.8, 0.62).lerp(white, flash)
    var facing := Vector2.from_angle(spin * 0.5).x
    for side: float in [-1.0, 1.0]:
        draw_line(
            Vector2(side * r * 0.2, r * 0.05),
            Vector2(side * r * 0.5, -r * 0.12 + side * r * 0.04),
            skin,
            r * 0.1
        )
    var pistol := Vector2(r * 0.52, -r * 0.1)
    draw_rect(
        Rect2(pistol - Vector2(r * 0.05, r * 0.07), Vector2(r * 0.2, r * 0.1)), Color(0.3, 0.9, 0.5)
    )
    if _squirt_left > 0.0:
        draw_circle(pistol + Vector2(r * 0.2, -r * 0.03), r * 0.06, Color(0.8, 0.95, 1.0))
    draw_circle(Vector2(0, -r * 0.05), r * 0.26, skin)
    var cap := PackedVector2Array()
    for k in range(13):
        var angle := PI + PI * k / 12.0
        cap.append(Vector2(cos(angle) * r * 0.27, -r * 0.08 + sin(angle) * r * 0.25))
    draw_colored_polygon(cap, Color(1.0, 0.85, 0.2).lerp(white, flash))
    for side: float in [-1.0, 1.0]:
        draw_circle(Vector2(side * r * 0.1, -r * 0.2), r * 0.06, Color(0.4, 0.8, 1.0))
        var eye := Vector2(side * r * 0.1 + facing * r * 0.02, -r * 0.05)
        draw_circle(eye, r * 0.045, Color(0.1, 0.1, 0.15))
        draw_circle(Vector2(side * r * 0.17, r * 0.04), r * 0.04, Color(1.0, 0.55, 0.55))
    draw_arc(Vector2(0, r * 0.04), r * 0.08, 0.3, PI - 0.3, 8, Color(0.5, 0.2, 0.15), r * 0.025)
