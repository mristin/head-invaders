class_name RainCloud

extends Enemy

## A little, sleepy cloud sprite which follows the nearest spaceship around,
## slowly, to rain on it. Before it rains, it frowns and darkens, and a soft
## shadow shows on the lane below, where the raindrops will fall. Then it
## lets a short shower of big drops fall straight down, one after another, so
## the players only need to step aside.

## How fast the cloud follows the nearest spaceship, in pixels per second.
@export var follow_speed: float = 150.0

## How long the cloud gathers the rain before the shower, in seconds.
@export var gather_duration: float = 0.9

## The shower: the number of the raindrops and the seconds between them.
@export var drop_count: int = 4
@export var drop_interval: float = 0.18

@export var descent_speed: float = 220.0

@export var margin: float = 120.0

## How many showers the cloud rained so far, e.g., for the tests.
var showers: int = 0

## The seconds until the first shower, if called in, e.g., by the storm
## cloud; negative to wait as usual.
var first_rain_delay: float = -1.0

var _time: float = 0.0
var _descending: bool = true
var _gather_left: float = -1.0
var _drops_left: int = 0
var _drop_cooldown: float = 0.0


func _ready() -> void:
    super()
    rocket_look = Rocket.Look.RAINDROP


func _enter() -> void:
    super()
    if spawned_in_place:
        # NOTE (mristin):
        # Called in, e.g., by the storm cloud, the cloud floats down from
        # where it was called in, if that is too high up.
        home.y = maxf(home.y, get_viewport_rect().position.y + radius * 2.0)
    if first_rain_delay >= 0.0:
        _rocket_cooldown = first_rain_delay


## Return true while the cloud is about to rain or raining, e.g., for
## the scripted players to step aside.
func is_raining() -> bool:
    return is_alive() and (_gather_left >= 0.0 or _drops_left > 0)


func _may_fire() -> bool:
    return not _descending and not is_raining()


func _move(delta: float) -> void:
    _time += delta

    if _descending:
        position.y = minf(position.y + descent_speed * delta, home.y)
        if position.y >= home.y:
            _descending = false
        return

    # NOTE (mristin):
    # The cloud stays put while it rains, so that the lane is clear to see.
    if not is_raining():
        var target := _nearest_spaceship()
        if target != null:
            var bounds := get_viewport_rect()
            var x := clampf(
                target.global_position.x, bounds.position.x + margin, bounds.end.x - margin
            )
            position.x = move_toward(position.x, x, follow_speed * delta)
        _keep_apart(delta)
        var bounds := get_viewport_rect()
        position.x = clampf(position.x, bounds.position.x + margin, bounds.end.x - margin)
    position.y = home.y + sin(_time * 2.2) * 10.0

    if _gather_left >= 0.0:
        _gather_left -= delta
        if _gather_left < 0.0:
            _drops_left = drop_count
            _drop_cooldown = 0.0
            showers += 1

    if _drops_left > 0:
        _drop_cooldown -= delta
        if _drop_cooldown <= 0.0:
            _drop_cooldown = drop_interval
            _drops_left -= 1
            var x := randf_range(-radius * 0.25, radius * 0.25)
            _launch_rocket_from(
                global_position + Vector2(x, radius * 0.4), Vector2.DOWN, rocket_speed
            )


## Drift away from the other rain clouds, so that they never bunch up over
## the same spaceship.
func _keep_apart(delta: float) -> void:
    for node in get_tree().get_nodes_in_group(GROUP):
        var other := node as RainCloud
        if other == null or other == self or not other.is_alive() or not other.has_arrived():
            continue
        var dx := position.x - other.position.x
        if absf(dx) < radius * 2.2:
            var away := (
                signf(dx)
                if dx != 0.0
                else (1.0 if get_instance_id() > other.get_instance_id() else -1.0)
            )
            position.x += away * follow_speed * 1.5 * delta


func _fire_rocket() -> void:
    _gather_left = gather_duration


func _energy_bar_y() -> float:
    return radius * 0.6


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var gather := 0.0
    if _gather_left >= 0.0:
        gather = 1.0 - clampf(_gather_left / gather_duration, 0.0, 1.0)
    elif _drops_left > 0:
        gather = 1.0

    # NOTE (mristin):
    # The shadow of the coming rain on the lane below, as a warning.
    if gather > 0.0 and not is_fleeing():
        var lane := r * 1.1
        var height := get_viewport_rect().end.y - global_position.y
        draw_rect(
            Rect2(Vector2(-lane / 2.0, r * 0.3), Vector2(lane, height)),
            Color(0.45, 0.65, 1.0, 0.12 * gather)
        )

    var body := Color(0.78, 0.8, 0.95).lerp(Color(0.5, 0.55, 0.78), gather).lerp(white, flash)
    var shade := body.darkened(0.15)
    var bob := sin(_time * 3.0) * r * 0.02
    var puffs: Array[Vector3] = [
        Vector3(-0.38, 0.08, 0.26),
        Vector3(0.38, 0.08, 0.26),
        Vector3(-0.18, -0.12, 0.3),
        Vector3(0.18, -0.15, 0.32),
        Vector3(0.0, 0.1, 0.34),
    ]
    for puff in puffs:
        draw_circle(Vector2(puff.x * r, puff.y * r + bob + r * 0.03), puff.z * r, shade)
    for puff in puffs:
        draw_circle(Vector2(puff.x * r, puff.y * r + bob), puff.z * r * 0.94, body)
    draw_circle(Vector2(-r * 0.2, -r * 0.25 + bob), r * 0.1, Color(1, 1, 1, 0.3))

    # The face: sleepy, then a little frown while it gathers the rain.
    var face := Vector2(0, r * 0.02 + bob)
    var ink := Color(0.2, 0.2, 0.35)
    for side: float in [-1.0, 1.0]:
        var eye := face + Vector2(side * r * 0.14, 0)
        if gather > 0.0:
            draw_circle(eye, r * 0.06, white)
            draw_circle(eye + Vector2(0, r * 0.015), r * 0.035, ink)
            draw_line(
                eye + Vector2(-side * r * 0.08, -r * 0.1),
                eye + Vector2(side * r * 0.05, -r * 0.07),
                ink,
                r * 0.025
            )
        else:
            draw_arc(eye, r * 0.05, 0.2, PI - 0.2, 8, ink, r * 0.025)
        draw_circle(face + Vector2(side * r * 0.24, r * 0.08), r * 0.045, Color(1.0, 0.6, 0.7, 0.7))
    if gather > 0.0:
        draw_circle(face + Vector2(0, r * 0.11), r * 0.035, ink)
    else:
        draw_arc(face + Vector2(0, r * 0.07), r * 0.06, 0.3, PI - 0.3, 10, ink, r * 0.025)

    # NOTE (mristin):
    # The drops gather under the cloud before the shower.
    if gather > 0.0 and _drops_left == 0 and not is_fleeing():
        for i in range(3):
            var at := Vector2((i - 1) * r * 0.18, r * 0.36 + bob)
            draw_circle(at, r * 0.04 * gather, Color(0.55, 0.8, 1.0, 0.9))
