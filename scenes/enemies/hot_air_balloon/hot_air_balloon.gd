class_name HotAirBalloon

extends Enemy

## A round, striped hot-air balloon with a smiling face, and a little bear in
## its basket. It drifts slowly towards the nearest spaceship. Before it drops
## a sandbag, the bear lifts the bag over the rim of the basket for a moment.
## The sandbag starts slowly and falls faster and faster. Lighter by a bag,
## the balloon hops up, then slowly sinks back down.

## How fast the balloon drifts sideways, in pixels per second.
@export var drift_speed: float = 110.0

## How long the bear holds the sandbag up before dropping it, in seconds.
@export var lift_duration: float = 0.6

## How fast the sandbag starts falling and how strongly it is pulled down.
@export var drop_speed: float = 80.0
@export var drop_fall_acceleration: float = 520.0

## How high the balloon hops after a drop, in pixels, and how fast it sinks
## back, in pixels per second.
@export var hop_height: float = 110.0
@export var sink_speed: float = 45.0

@export var descent_speed: float = 180.0

@export var margin: float = 140.0

## How many sandbags the balloon dropped so far, e.g., for the tests.
var sandbags_dropped: int = 0

## How high the balloon flew above its home after a drop, e.g., for the tests.
var highest_hop: float = 0.0

var _time: float = 0.0
var _descending: bool = true
var _lift_left: float = -1.0
var _hop: float = 0.0
var _hop_velocity: float = 0.0


func _ready() -> void:
    super()
    rocket_look = Rocket.Look.SANDBAG


func _may_fire() -> bool:
    return not _descending and _lift_left < 0.0


func _move(delta: float) -> void:
    _time += delta

    if _descending:
        position.y = minf(position.y + descent_speed * delta, home.y)
        if position.y >= home.y:
            _descending = false
        return

    # NOTE (mristin):
    # The balloon drifts towards the nearest spaceship, slowly, so that
    # the players can always outrun it.
    var target := _nearest_spaceship()
    if target != null:
        var bounds := get_viewport_rect()
        var x := clampf(target.global_position.x, bounds.position.x + margin, bounds.end.x - margin)
        position.x = move_toward(position.x, x, drift_speed * delta)

    # NOTE (mristin):
    # After a drop the balloon hops up quickly, then sinks back slowly.
    if _hop_velocity > 0.0:
        _hop += _hop_velocity * delta
        _hop_velocity = maxf(0.0, _hop_velocity - 600.0 * delta)
        if _hop >= hop_height:
            _hop_velocity = 0.0
    else:
        _hop = maxf(0.0, _hop - sink_speed * delta)
    highest_hop = maxf(highest_hop, _hop)
    position.y = home.y - _hop + sin(_time * 1.8) * 8.0

    if _lift_left >= 0.0:
        _lift_left -= delta
        if _lift_left < 0.0:
            _drop()


## Start lifting the sandbag; the bear drops it a moment later.
func _fire_rocket() -> void:
    _lift_left = lift_duration


func _drop() -> void:
    var sandbag := _launch_rocket_from(
        _basket() + Vector2(0, radius * 0.2), Vector2.DOWN, drop_speed
    )
    if sandbag != null:
        sandbag.fall_acceleration = drop_fall_acceleration
    sandbags_dropped += 1
    _hop_velocity = sqrt(2.0 * 600.0 * hop_height)


## Return the global position of the basket.
func _basket() -> Vector2:
    return global_position + Vector2(0, radius * 0.62)


func _energy_bar_y() -> float:
    return radius * 0.95


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var basket := _basket() - global_position
    var sway := sin(_time * 1.3) * r * 0.03

    # NOTE (mristin):
    # The ropes from the envelope down to the basket.
    var rope := Color(0.85, 0.75, 0.6).lerp(white, flash)
    for side: float in [-1.0, 1.0]:
        draw_line(
            Vector2(side * r * 0.14, r * 0.36),
            basket + Vector2(side * r * 0.15 + sway, -r * 0.05),
            rope,
            r * 0.025
        )

    # The little bear in the basket waves, and lifts the sandbag before
    # the drop.
    var bear := basket + Vector2(sway, -r * 0.14)
    var fur := Color(0.75, 0.5, 0.3).lerp(white, flash)
    var lifting := _lift_left >= 0.0
    draw_circle(bear + Vector2(-r * 0.07, -r * 0.08), r * 0.035, fur)
    draw_circle(bear + Vector2(r * 0.07, -r * 0.08), r * 0.035, fur)
    draw_circle(bear, r * 0.09, fur)
    for side: float in [-1.0, 1.0]:
        draw_circle(bear + Vector2(side * r * 0.032, -r * 0.01), r * 0.016, Color(0.1, 0.05, 0.05))
    draw_circle(bear + Vector2(0, r * 0.035), r * 0.022, Color(0.35, 0.2, 0.15))
    if lifting:
        var bag := bear + Vector2(r * 0.15, -r * 0.12)
        draw_line(bear + Vector2(r * 0.07, r * 0.02), bag, fur, r * 0.035)
        draw_circle(bag, r * 0.08, Color(1, 1, 1, 0.95))
        draw_circle(bag, r * 0.065, Color(0.85, 0.65, 0.4))
        draw_line(
            bag + Vector2(-r * 0.04, -r * 0.04),
            bag + Vector2(r * 0.04, -r * 0.04),
            Color(0.75, 0.2, 0.3),
            r * 0.02
        )
    else:
        var wave := sin(_time * 6.0) * r * 0.04
        draw_line(
            bear + Vector2(r * 0.07, r * 0.02),
            bear + Vector2(r * 0.14, -r * 0.08 + wave),
            fur,
            r * 0.035
        )

    var wicker := Color(0.7, 0.48, 0.25).lerp(white, flash)
    draw_rect(
        Rect2(basket + Vector2(-r * 0.17 + sway, -r * 0.07), Vector2(r * 0.34, r * 0.2)), wicker
    )
    draw_line(
        basket + Vector2(-r * 0.19 + sway, -r * 0.07),
        basket + Vector2(r * 0.19 + sway, -r * 0.07),
        Color(0.5, 0.32, 0.15).lerp(white, flash),
        r * 0.04
    )
    # The sandbags still hanging on the basket.
    for side: float in [-1.0, 1.0]:
        draw_circle(
            basket + Vector2(side * r * 0.2 + sway, r * 0.06),
            r * 0.045,
            Color(0.85, 0.65, 0.4).lerp(white, flash)
        )

    # NOTE (mristin):
    # The envelope: round on top, narrowing towards the neck above the basket,
    # with the colored gores drawn as narrower and narrower lenses.
    var gores: Array[Color] = [
        Color(0.95, 0.45, 0.5),
        Color(1.0, 0.85, 0.45),
        Color(0.95, 0.45, 0.5),
        Color(0.5, 0.78, 0.95)
    ]
    draw_colored_polygon(_envelope(1.06, r * 0.03), Color(1, 1, 1, 0.9))
    for i in range(4):
        draw_colored_polygon(_envelope(1.0 - i * 0.28, 0.0), gores[i].lerp(white, flash))
    draw_circle(Vector2(-r * 0.25, -r * 0.55), r * 0.1, Color(1, 1, 1, 0.18))

    # The friendly face on the envelope.
    var face := Vector2(0, -r * 0.28)
    for side: float in [-1.0, 1.0]:
        var eye := face + Vector2(side * r * 0.15, 0)
        draw_circle(eye, r * 0.075, white)
        draw_circle(eye + Vector2(0, r * 0.015), r * 0.045, Color(0.15, 0.1, 0.2))
        draw_circle(eye + Vector2(-r * 0.015, -r * 0.015), r * 0.016, white)
        draw_circle(face + Vector2(side * r * 0.27, r * 0.11), r * 0.05, Color(1.0, 0.55, 0.6, 0.8))
    if lifting:
        draw_circle(face + Vector2(0, r * 0.14), r * 0.05, Color(0.45, 0.12, 0.18))
    else:
        draw_arc(
            face + Vector2(0, r * 0.09),
            r * 0.09,
            0.3,
            PI - 0.3,
            12,
            Color(0.35, 0.1, 0.15),
            r * 0.03
        )


## Return the outline of the envelope, its width scaled by the given factor
## and grown by the given margin.
func _envelope(width: float, grow: float) -> PackedVector2Array:
    var center := Vector2(0, -radius * 0.3)
    var size := radius * 0.55 + grow
    var points := PackedVector2Array()
    for i in range(40):
        var angle := TAU * i / 40.0
        var below := maxf(0.0, sin(angle))
        points.append(
            (
                center
                + Vector2(
                    cos(angle) * size * width * (1.0 - 0.55 * below),
                    sin(angle) * size * (1.0 + 0.25 * below)
                )
            )
        )
    return points
