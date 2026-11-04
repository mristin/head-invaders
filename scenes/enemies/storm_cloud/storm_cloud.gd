class_name StormCloud

extends Enemy

## The grumpy storm cloud, the big, puffy boss of the sky kingdom, who comes
## at the end of the eighth level once all the others have fled. It is grumpy,
## but never mean, and all its attacks are announced:
##
## * The lightning: the cloud picks the lane of the nearest spaceship, which
##   glows and flickers, with arrows sliding down it, while the cloud
##   squeezes its eyes and crackles. Then a cartoon lightning bolt strikes
##   down the lane. Whoever steps out of the lane in time is safe.
## * The rain: it lets a shower of big raindrops fall from its belly.
## * The gust: it puffs up its cheeks, then blows a gust of wind across
##   the screen while it rains. The wind pushes the raindrops sideways, so
##   the rain slants, but it never pushes the spaceships.
##
## When it is low on energy, it sneezes out two little rain clouds, once, and
## its lightning strikes two lanes at a time.

enum Action { ENTERING, DRIFT, CHARGE, STRIKE, RAIN, PUFF, BLOW }

# NOTE (mristin):
# We load the scene lazily, so that the boss does not drag the rain clouds
# into every scene which merely mentions the boss.
const _RAIN_CLOUD_SCENE_PATH: String = "res://scenes/enemies/rain_cloud/rain_cloud.tscn"

@export var descent_speed: float = 150.0

## How far the cloud drifts to and fro, in pixels, and how often.
@export var drift_amplitude: float = 380.0
@export var drift_frequency: float = 0.05

## The lightning: how long the lane glows before the strike, how long
## the strike lasts, and the half width of the lane, in pixels.
@export var charge_duration: float = 1.4
@export var strike_duration: float = 0.45
@export var lane_half_width: float = 95.0
@export var lightning_damage: int = 14

## The rain: how long the cloud gathers it, the number of the raindrops and
## the seconds between them.
@export var gather_duration: float = 0.6
@export var rain_count: int = 6
@export var rain_interval: float = 0.15

## The gust: how long the cloud puffs up its cheeks, how long it blows, how
## fast it pushes the raindrops sideways, and how many raindrops it lets fall
## while blowing.
@export var puff_duration: float = 1.0
@export var blow_duration: float = 2.6
@export var wind_speed: float = 260.0
@export var wind_acceleration: float = 420.0
@export var blow_rain_count: int = 5

## Below this fraction of the energy, the cloud sneezes out the rain clouds
## and strikes two lanes at a time.
@export_range(0.0, 1.0) var hurry_below: float = 0.5

@export var margin: float = 300.0

## How many lightning bolts struck so far, and how many lanes glowed before
## them, e.g., for the tests.
var strikes: int = 0
var lanes_warned: int = 0

## How many gusts the cloud blew so far, e.g., for the tests.
var gusts: int = 0

## The fastest sideways speed of a raindrop pushed by the wind so far, e.g.,
## for the tests.
var fastest_pushed_drop: float = 0.0

## How many spaceships the lightning hit so far, e.g., for the tests.
var lightning_hits: int = 0

## Whether the cloud sneezed out its rain clouds, e.g., for the tests.
var sneezed: bool = false

var _action: Action = Action.ENTERING
var _time: float = 0.0
var _action_time: float = 0.0
var _attack: int = 0
var _drift_time: float = 0.0

## The global x of the lanes of the coming or striking lightning.
var _lanes: Array[float] = []

## The raindrops of the cloud, which the wind pushes.
var _drops: Array[Rocket] = []
var _drops_left: int = 0
var _drop_cooldown: float = 0.0
var _wind: float = 1.0


func _ready() -> void:
    super()
    rocket_look = Rocket.Look.RAINDROP


## Return the global x of the lanes which glow or strike now; empty if none.
func lightning_lanes() -> Array[float]:
    if _action in [Action.CHARGE, Action.STRIKE]:
        return _lanes.duplicate()
    return []


## Return true while the cloud gathers the rain, rains or blows.
func is_raining() -> bool:
    return _action in [Action.RAIN, Action.PUFF, Action.BLOW]


## Return the direction of the wind, -1 to the left and 1 to the right, while
## the cloud puffs or blows, otherwise 0.
func wind() -> float:
    return _wind if _action in [Action.PUFF, Action.BLOW] else 0.0


func is_in_a_hurry() -> bool:
    return is_alive() and float(energy) / float(max_energy) < hurry_below


func take_damage(amount: int) -> void:
    super(amount)
    if _action != Action.ENTERING and is_in_a_hurry() and not sneezed:
        _sneeze()


func _may_fire() -> bool:
    return _action == Action.DRIFT


func _move(delta: float) -> void:
    _time += delta
    _action_time += delta
    _push_drops(delta)

    match _action:
        Action.ENTERING:
            position.y = minf(position.y + descent_speed * delta, home.y)
            if position.y >= home.y:
                _time = 0.0
                _start(Action.DRIFT)
        Action.DRIFT:
            _drift(delta)
        Action.CHARGE:
            if _action_time >= charge_duration:
                strikes += 1
                _start(Action.STRIKE)
        Action.STRIKE:
            _strike()
            if _action_time >= strike_duration:
                _start(Action.DRIFT)
        Action.RAIN:
            _drift(delta)
            if _action_time >= gather_duration:
                _rain(delta)
                if _drops_left == 0:
                    _start(Action.DRIFT)
        Action.PUFF:
            if _action_time >= puff_duration:
                gusts += 1
                _drops_left = blow_rain_count
                _drop_cooldown = 0.0
                _start(Action.BLOW)
        Action.BLOW:
            _rain(delta)
            if _action_time >= blow_duration:
                _start(Action.DRIFT)


func _start(action: Action) -> void:
    _action = action
    _action_time = 0.0


func _drift(delta: float) -> void:
    var bounds := get_viewport_rect()
    _drift_time += delta
    var x := home.x + sin(_drift_time * TAU * drift_frequency) * drift_amplitude
    position.x = clampf(x, bounds.position.x + margin, bounds.end.x - margin)
    position.y = home.y + sin(_time * TAU * 0.25) * 12.0


func _fire_rocket() -> void:
    # NOTE (mristin):
    # The gust comes early, so that the players see it even when they beat
    # the cloud quickly.
    match _attack % 4:
        0, 2:
            _charge()
        1:
            _wind = -1.0 if randf() < 0.5 else 1.0
            _start(Action.PUFF)
        _:
            _drops_left = rain_count
            _drop_cooldown = 0.0
            _start(Action.RAIN)
    _attack += 1


func _charge() -> void:
    var target := _nearest_spaceship()
    var x := target.global_position.x if target != null else global_position.x
    _lanes = [x]

    if is_in_a_hurry():
        # NOTE (mristin):
        # The second lane goes to another spaceship far enough away, or
        # else next to the first lane, towards the middle of the screen.
        var bounds := get_viewport_rect()
        var second := x + (520.0 if x < bounds.get_center().x else -520.0)
        for node in get_tree().get_nodes_in_group(Spaceship.GROUP):
            var spaceship := node as Spaceship
            if spaceship == null or not spaceship.is_alive():
                continue
            if absf(spaceship.global_position.x - x) > lane_half_width * 3.0:
                second = spaceship.global_position.x
                break
        _lanes.append(second)

    lanes_warned += _lanes.size()
    _start(Action.CHARGE)


func _strike() -> void:
    for node in get_tree().get_nodes_in_group(Spaceship.GROUP):
        var spaceship := node as Spaceship
        if spaceship == null or not spaceship.is_alive():
            continue
        for lane in _lanes:
            if absf(spaceship.global_position.x - lane) < lane_half_width:
                if spaceship.take_damage(lightning_damage):
                    lightning_hits += 1
                break


func _rain(delta: float) -> void:
    if _drops_left <= 0:
        return
    _drop_cooldown -= delta
    if _drop_cooldown > 0.0:
        return

    var interval := rain_interval if _action == Action.RAIN else blow_duration / blow_rain_count
    _drop_cooldown = interval
    _drops_left -= 1
    var from := global_position + Vector2(randf_range(-radius * 0.7, radius * 0.7), radius * 0.3)
    var drop := _launch_rocket_from(from, Vector2.DOWN, rocket_speed)
    if drop != null:
        _drops.append(drop)


## Push the raindrops sideways while the wind blows.
func _push_drops(delta: float) -> void:
    var alive: Array[Rocket] = []
    for drop in _drops:
        if is_instance_valid(drop) and not drop.is_queued_for_deletion():
            alive.append(drop)
    _drops = alive

    if _action != Action.BLOW:
        return
    for drop in _drops:
        if not drop.is_inside_tree():
            continue
        drop.velocity.x = move_toward(
            drop.velocity.x, _wind * wind_speed, wind_acceleration * delta
        )
        drop.rotation = drop.velocity.angle()
        fastest_pushed_drop = maxf(fastest_pushed_drop, absf(drop.velocity.x))


func _sneeze() -> void:
    sneezed = true
    var scene: PackedScene = load(_RAIN_CLOUD_SCENE_PATH)
    for side: float in [-1.0, 1.0]:
        var at := global_position + Vector2(side * radius * 0.9, radius * 0.3)
        var cloud := _summon(scene, at) as RainCloud
        # NOTE (mristin):
        # The little clouds rain only a moment later, one after the other.
        cloud.first_rain_delay = 2.0 if side < 0.0 else 3.5
        Poof.spawn(self, at, radius * 0.3, Color(0.75, 0.8, 1.0))


func _start_fleeing(beaten: bool = true) -> void:
    _lanes.clear()
    super(beaten)


func _energy_bar_y() -> float:
    return radius * 0.5


func _draw_body(flash: float) -> void:
    if not is_fleeing():
        _draw_lanes()
        _draw_wind()

    var white := Color(1, 1, 1)
    var r := radius
    var charge := _action in [Action.CHARGE, Action.STRIKE]
    var puffed := 0.0
    if _action == Action.PUFF:
        puffed = clampf(_action_time / puff_duration, 0.0, 1.0)
    elif _action == Action.BLOW:
        puffed = 1.0

    # NOTE (mristin):
    # The cloud leans back while it puffs up, and into the gust while blowing.
    var lean := -_wind * 0.08 * puffed if _action == Action.PUFF else _wind * 0.06 * puffed
    draw_set_transform(Vector2.ZERO, lean)

    var body := Color(0.42, 0.42, 0.62).lerp(white, flash)
    var shade := Color(0.3, 0.29, 0.48).lerp(white, flash)
    var top := Color(0.55, 0.55, 0.75).lerp(white, flash)
    var puffs: Array[Vector3] = [
        Vector3(-0.68, 0.12, 0.27),
        Vector3(0.68, 0.12, 0.27),
        Vector3(-0.45, -0.12, 0.33),
        Vector3(0.45, -0.1, 0.33),
        Vector3(-0.15, -0.3, 0.36),
        Vector3(0.2, -0.32, 0.34),
        Vector3(-0.3, 0.15, 0.32),
        Vector3(0.3, 0.15, 0.32),
        Vector3(0.0, 0.05, 0.4),
    ]
    var swell := 1.0 + 0.06 * sin(_time * 1.5) + 0.05 * puffed
    # NOTE (mristin):
    # A soft, dark rim sets the boss apart from the clouds of the sky.
    for puff in puffs:
        draw_circle(
            Vector2(puff.x * r, puff.y * r + r * 0.03),
            puff.z * r * swell + r * 0.03,
            Color(0.1, 0.08, 0.2, 0.85)
        )
    for puff in puffs:
        draw_circle(Vector2(puff.x * r, puff.y * r + r * 0.05), puff.z * r * swell, shade)
    for puff in puffs:
        draw_circle(Vector2(puff.x * r, puff.y * r), puff.z * r * swell * 0.93, body)
    for puff in puffs.slice(2, 6):
        draw_circle(
            Vector2(puff.x * r - r * 0.05, puff.y * r - r * 0.06), puff.z * r * swell * 0.6, top
        )

    # NOTE (mristin):
    # The little sparks crackle around the cloud while it charges.
    if charge and not is_fleeing():
        for i in range(4):
            var angle := TAU * i / 4.0 + _time * 3.0
            var at := Vector2(cos(angle) * r * 0.75, sin(angle) * r * 0.35 - r * 0.05)
            Poof.draw_twinkle(self, at, r * 0.05, _time * 10.0 + i, Color(1.0, 0.95, 0.55, 0.8))

    _draw_face(flash, charge, puffed)
    draw_set_transform(Vector2.ZERO, 0.0)

    if charge and not is_fleeing():
        _draw_lane_puffs(body, shade)
    if _action == Action.STRIKE and not is_fleeing():
        _draw_bolts()


## Draw a little puff of the cloud at the top of each lane away from the cloud,
## where its bolt comes from.
func _draw_lane_puffs(body: Color, shade: Color) -> void:
    var r := radius
    for lane in _lanes:
        var x := lane - global_position.x
        if absf(x) < r * 0.7:
            continue
        var top := Vector2(x, r * 0.3)
        var puffs: Array[Vector3] = [
            Vector3(-0.12, 0.0, 0.1), Vector3(0.12, 0.0, 0.1), Vector3(0.0, -0.05, 0.13)
        ]
        for puff in puffs:
            draw_circle(
                top + Vector2(puff.x, puff.y) * r,
                puff.z * r + r * 0.02,
                Color(0.1, 0.08, 0.2, 0.85)
            )
        for puff in puffs:
            draw_circle(top + Vector2(puff.x, puff.y + 0.01) * r, puff.z * r, shade)
        for puff in puffs:
            draw_circle(top + Vector2(puff.x, puff.y) * r, puff.z * r * 0.9, body)


func _draw_face(flash: float, charge: bool, puffed: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var ink := Color(0.12, 0.1, 0.22)
    var face := Vector2(0, -r * 0.02)

    for side: float in [-1.0, 1.0]:
        var eye := face + Vector2(side * r * 0.17, -r * 0.03)
        if charge:
            # NOTE (mristin):
            # The eyes squeezed tight with the effort, like a pout.
            draw_line(
                eye + Vector2(-r * 0.06, -r * 0.02),
                eye + Vector2(r * 0.06, r * 0.0),
                ink,
                r * 0.025
            )
            draw_line(
                eye + Vector2(-r * 0.06, r * 0.02), eye + Vector2(r * 0.06, 0), ink, r * 0.025
            )
        else:
            draw_circle(eye, r * 0.075, white)
            var look := Vector2(_wind * puffed * r * 0.02, r * 0.015)
            draw_circle(eye + look, r * 0.045, ink)
            draw_circle(eye + look + Vector2(-r * 0.015, -r * 0.015), r * 0.015, white)
        # The grumpy eyebrows, slanting down towards the nose.
        draw_line(
            eye + Vector2(-side * r * 0.07, -r * 0.08),
            eye + Vector2(side * r * 0.09, -r * 0.15),
            ink,
            r * 0.03
        )
        # The rosy cheeks, puffed up for the gust.
        var cheek := face + Vector2(side * r * (0.3 + 0.04 * puffed), r * 0.1)
        draw_circle(
            cheek, r * (0.06 + 0.09 * puffed), Color(1.0, 0.55, 0.65, 0.75).lerp(white, flash)
        )

    if puffed > 0.0:
        # NOTE (mristin):
        # The round mouth blowing the gust.
        var mouth := face + Vector2(_wind * r * 0.06 * puffed, r * 0.14)
        draw_circle(mouth, r * (0.035 + 0.025 * puffed), ink)
    else:
        # The pout: a little upside-down smile.
        draw_arc(face + Vector2(0, r * 0.19), r * 0.07, PI + 0.4, TAU - 0.4, 10, ink, r * 0.025)


## Draw the glowing lanes of the coming lightning, flickering faster and
## faster, with arrows sliding down.
func _draw_lanes() -> void:
    if _action != Action.CHARGE:
        return

    var t := clampf(_action_time / charge_duration, 0.0, 1.0)
    var flicker := 0.5 + 0.5 * sin(_action_time * lerpf(10.0, 40.0, t))
    var bottom := get_viewport_rect().end.y - global_position.y
    var from := radius * 0.3
    var glow := Color(1.0, 0.88, 0.3, lerpf(0.1, 0.22, t) + 0.06 * flicker)
    var edge := Color(1.0, 0.93, 0.6, 0.35 + 0.3 * flicker)
    for lane in _lanes:
        var x := lane - global_position.x
        draw_rect(Rect2(x - lane_half_width, from, lane_half_width * 2.0, bottom - from), glow)
        for side: float in [-1.0, 1.0]:
            var edge_x := x + side * lane_half_width
            draw_dashed_line(Vector2(edge_x, from), Vector2(edge_x, bottom), edge, 4.0, 18.0)
        # NOTE (mristin):
        # The arrows slide down the lane, where the bolt will come.
        for k in range(4):
            var y := from + fmod(_action_time * 420.0 + k * (bottom - from) / 4.0, bottom - from)
            var size := lane_half_width * 0.35
            draw_polyline(
                PackedVector2Array(
                    [
                        Vector2(x - size, y - size * 0.6),
                        Vector2(x, y),
                        Vector2(x + size, y - size * 0.6),
                    ]
                ),
                Color(1.0, 0.95, 0.6, 0.7),
                6.0,
                true
            )


## Draw the cartoon lightning bolts down the lanes.
func _draw_bolts() -> void:
    var bottom := get_viewport_rect().end.y - global_position.y
    var from := radius * 0.3
    var fade := 1.0 - clampf(_action_time / strike_duration, 0.0, 1.0) * 0.5
    for lane in _lanes:
        var x := lane - global_position.x
        var bolt := PackedVector2Array()
        var steps := 9
        for i in range(steps + 1):
            var y := lerpf(from, bottom, i / float(steps))
            var zig := 0.0 if i == 0 or i == steps else (1.0 if i % 2 == 0 else -1.0) * 38.0
            bolt.append(Vector2(x + zig, y))
        draw_rect(
            Rect2(x - lane_half_width, from, lane_half_width * 2.0, bottom - from),
            Color(1.0, 0.95, 0.6, 0.18 * fade)
        )
        draw_polyline(bolt, Color(1.0, 0.95, 0.6, 0.35 * fade), 60.0, true)
        draw_polyline(bolt, Color(1, 1, 1, fade), 30.0, true)
        draw_polyline(bolt, Color(1.0, 0.85, 0.15, fade), 18.0, true)
        Poof.draw_twinkle(
            self, Vector2(x, bottom - 30.0), 50.0, _time * 8.0, Color(1.0, 0.9, 0.4, fade)
        )


## Draw the streaks of the wind across the screen while the cloud puffs and
## blows.
func _draw_wind() -> void:
    var strength := 0.0
    if _action == Action.PUFF:
        strength = clampf(_action_time / puff_duration, 0.0, 1.0) * 0.6
    elif _action == Action.BLOW:
        strength = 1.0 - clampf((_action_time - blow_duration + 0.4) / 0.4, 0.0, 1.0)
    if strength <= 0.0:
        return

    var bounds := get_viewport_rect()
    var width := bounds.size.x + 600.0
    for i in range(6):
        var y := lerpf(radius * 0.4, bounds.end.y - global_position.y - 80.0, i / 5.0)
        var x := fmod(_time * 700.0 + i * 337.0, width) - 300.0
        if _wind < 0.0:
            x = bounds.size.x - x
        x -= global_position.x
        var streak := PackedVector2Array()
        for j in range(8):
            var u := j / 7.0
            streak.append(Vector2(x - _wind * u * 260.0, y + sin(u * PI * 2.0 + i) * 14.0))
        draw_polyline(streak, Color(0.85, 0.85, 1.0, 0.33 * strength), 8.0, true)
        var curl := streak[0]
        draw_arc(
            curl + Vector2(0, -16),
            16.0,
            PI * 0.5,
            PI * 2.0,
            12,
            Color(0.85, 0.85, 1.0, 0.33 * strength),
            6.0,
            true
        )
