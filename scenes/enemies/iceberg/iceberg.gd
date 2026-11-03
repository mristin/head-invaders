class_name Iceberg

extends GroundEnemy

## A big, sleepy iceberg drifting down the sea, with a friendly face in
## the ice. It is tough, and fires a slow fan of icicles at the nearest
## spaceship now and then. Each time it loses a third of its energy, it
## cracks, shrinks and a little ice cube breaks off, which slides around on
## its own and throws icicles too, until it is chased away as well.
##
## It floats on the sea, so the spaceships fly over it.

const _ICE_CUBE_SCENE: PackedScene = preload("res://scenes/enemies/ice_cube/ice_cube.tscn")

## The icicles: the number in the fan, and the angle between them.
@export var fan_size: int = 2
@export var fan_angle: float = 0.35

## How much of its size it keeps once almost melted away.
@export var smallest: float = 0.6

## How fast it drifts to the sides, in pixels per second.
@export var drift_speed: float = 35.0

## How many ice cubes broke off so far, e.g., for the tests.
var calved: int = 0

var _time: float = 0.0
var _drift: float = 1.0
var _crack: float = 0.0
var _full_radius: float = 0.0
var _shapes: Dictionary[CollisionShape2D, Vector2] = {}


func _ready() -> void:
    super()
    rocket_look = Rocket.Look.ICICLE
    _drift = -1.0 if randf() < 0.5 else 1.0
    _full_radius = radius
    for child in get_children():
        var shape := child as CollisionShape2D
        if shape != null:
            _shapes[shape] = shape.scale


## Return how big the iceberg is now, from smallest to 1.
func size() -> float:
    return lerpf(smallest, 1.0, float(energy) / float(max_energy))


func take_damage(amount: int) -> void:
    if not is_alive() or not has_arrived():
        return
    var thirds_before := _thirds_left()
    super(amount)
    if not is_alive():
        return

    var lost := thirds_before - _thirds_left()
    for i in range(lost):
        _calve()

    radius = _full_radius * size()
    for shape in _shapes:
        shape.scale = _shapes[shape] * size()


func _thirds_left() -> int:
    return ceili(3.0 * energy / float(max_energy))


func _calve() -> void:
    calved += 1
    _crack = 1.0
    var side := -1.0 if calved % 2 == 1 else 1.0
    var at := global_position + Vector2(side * radius * 0.8, radius * 0.3)
    var cube := _summon(_ICE_CUBE_SCENE, at, false)
    cube.ground_speed = ground_speed
    Poof.spawn(self, at, radius * 0.4, Color(0.7, 0.9, 1.0))


func _walk(delta: float) -> void:
    _time += delta
    _crack = maxf(0.0, _crack - delta * 2.0)
    var bounds := get_viewport_rect()
    position.x += _drift * drift_speed * delta
    if position.x < bounds.position.x + margin * 1.5:
        _drift = 1.0
    elif position.x > bounds.end.x - margin * 1.5:
        _drift = -1.0


func _fire_rocket() -> void:
    var aim := _rocket_direction()
    if aim == Vector2.ZERO:
        return
    for i in range(fan_size):
        var angle := (i - (fan_size - 1) / 2.0) * fan_angle
        _launch_rocket(aim.rotated(angle), rocket_speed)


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var shake := sin(_time * 50.0) * r * 0.03 * _crack
    draw_set_transform(Vector2(shake, 0), 0.0)

    # NOTE (mristin):
    # The iceberg from above: the dark ice under the water around it, then
    # the jagged top, lit from the upper left.
    var outline := PackedVector2Array()
    var top := PackedVector2Array()
    for i in range(14):
        var a := TAU * i / 14.0
        var jag := 1.0 + 0.12 * sin(a * 3.0 + 0.7) + 0.06 * sin(a * 7.0)
        outline.append(Vector2(cos(a), sin(a) * 0.85) * r * 0.62 * jag)
        top.append(Vector2(cos(a), sin(a) * 0.85) * r * 0.5 * jag + Vector2(-r * 0.03, -r * 0.04))
    draw_circle(Vector2.ZERO, r * 0.72, Color(0.3, 0.55, 0.7, 0.2))
    draw_colored_polygon(outline, Color(0.35, 0.6, 0.78).lerp(white, flash))
    draw_colored_polygon(top, Color(0.72, 0.88, 0.97).lerp(white, flash))
    draw_colored_polygon(
        PackedVector2Array(
            [
                Vector2(-r * 0.35, -r * 0.3),
                Vector2(-r * 0.05, -r * 0.38),
                Vector2(-r * 0.2, -r * 0.15)
            ]
        ),
        Color(1, 1, 1, 0.5)
    )

    # The cracks show how much it has taken.
    var crack_color := Color(0.3, 0.5, 0.7)
    var thirds := _thirds_left()
    if thirds <= 2:
        draw_polyline(
            PackedVector2Array(
                [
                    Vector2(r * 0.45, -r * 0.2),
                    Vector2(r * 0.3, -r * 0.1),
                    Vector2(r * 0.33, r * 0.05)
                ]
            ),
            crack_color,
            r * 0.025
        )
    if thirds <= 1:
        draw_polyline(
            PackedVector2Array(
                [
                    Vector2(-r * 0.4, r * 0.25),
                    Vector2(-r * 0.25, r * 0.18),
                    Vector2(-r * 0.3, r * 0.35)
                ]
            ),
            crack_color,
            r * 0.025
        )

    # The sleepy, friendly face in the ice.
    var face := Vector2(0, r * 0.05)
    for side: float in [-1.0, 1.0]:
        var eye := face + Vector2(side * r * 0.15, -r * 0.05)
        if _crack > 0.0:
            draw_circle(eye, r * 0.07, white)
            draw_circle(eye, r * 0.035, Color(0.1, 0.2, 0.35))
        else:
            draw_arc(eye, r * 0.06, 0.2, PI - 0.2, 8, Color(0.15, 0.3, 0.45), r * 0.025)
        draw_circle(face + Vector2(side * r * 0.25, r * 0.07), r * 0.05, Color(1.0, 0.6, 0.75, 0.6))
    if _crack > 0.0:
        draw_circle(face + Vector2(0, r * 0.12), r * 0.05, Color(0.15, 0.3, 0.45))
    else:
        draw_arc(
            face + Vector2(0, r * 0.06),
            r * 0.08,
            0.3,
            PI - 0.3,
            8,
            Color(0.15, 0.3, 0.45),
            r * 0.025
        )
    draw_set_transform(Vector2.ZERO, 0.0)
