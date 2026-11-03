class_name CuckooClock

extends Enemy

## The giant cuckoo clock, the carved wooden chalet with the friendly eyes,
## who comes at the end of the Swiss Alps once all the others have fled. It
## hangs at the top of the screen and sways slowly from side to side.
##
## Its clock face tells the players what comes next. The face is split into
## four colored quarters, each with a picture: the cuckoo, the pine cones,
## the dancers and the moon. Before each chime, the hour hand turns to point
## at the next quarter, which lights up, and the minute hand ticks once around
## the clock: a countdown which the players can watch. On the full hour,
## the clock chimes:
##
## * The cuckoo: the little doors open, the cuckoo pops out and calls
##   "cuck-oo", with a fan of notes at the nearest spaceship for each call.
##   While the cuckoo is out, the clock is ticklish: every hit counts double.
## * The pine cones: the clock lines up one of its two pine cone weights above
##   the nearest spaceship, soft lanes show below the weights, the weights
##   shake, and then the pine cones drop down the lanes.
## * The dancers: the little dancing pair comes out on the turntable, spins
##   around and throws two rings of notes.
## * The moon: the clock dozes off for a moment, a breather for the players.
##
## When it is low on energy, it ticks faster and does not doze off any more.

enum Chime { CUCKOO, PINE_CONES, DANCERS, MOON }

enum Phase { DESCENDING, COUNTDOWN, CHIMING }

@export var descent_speed: float = 140.0

## How far the clock sways to the sides, in pixels, how often, and how fast
## it slides at most.
@export var sway: float = 260.0
@export var sway_frequency: float = 0.05
@export var slide_speed: float = 170.0

## How fast it slides to line up a pine cone weight above a spaceship.
@export var line_up_speed: float = 320.0

## The countdown: how many ticks of the minute hand, and the seconds between
## them, normally and in a hurry.
@export var ticks: int = 12
@export var tick_interval: float = 0.28
@export var hurry_tick_interval: float = 0.2

## The cuckoo: how many calls, the seconds between them, the fan of notes of
## each call, and how much a hit counts while the cuckoo is out.
@export var cuckoo_calls: int = 2
@export var cuckoo_interval: float = 0.8
@export var fan_size: int = 3
@export var fan_angle: float = 0.32
@export var cuckoo_damage_factor: int = 2

## The pine cones: how long the lanes show before the drop, how many cones
## drop from each weight, the seconds between them, and how fast they fall.
@export var cone_warning: float = 1.3
@export var cones_per_weight: int = 2
@export var cone_interval: float = 0.35
@export var cone_speed: float = 360.0
@export var cone_fall_acceleration: float = 300.0

## The dancers: how many rings of notes, the seconds between them, and how
## fast the notes fly.
@export var dance_rings: int = 2
@export var dance_interval: float = 0.8
@export var ring_size: int = 6
@export var ring_speed: float = 220.0

## How long the clock dozes off on the moon.
@export var moon_duration: float = 2.5

## Below this fraction of the energy, it ticks faster and does not doze off.
@export_range(0.0, 1.0) var hurry_below: float = 0.5

@export var margin: float = 300.0

## How many times each chime came so far, e.g., for the tests.
var chimes: Dictionary[Chime, int] = {}

## How many hits counted double while the cuckoo was out, e.g., for the tests.
var ticklish_hits: int = 0

## How many pine cones dropped so far, e.g., for the tests.
var cones_dropped: int = 0

var _phase: Phase = Phase.DESCENDING
var _phase_time: float = 0.0
var _time: float = 0.0
var _x: float = 0.0

## The chime which the hour hand points at, i.e., the next or the current one.
var _chime: Chime = Chime.MOON
var _tick: int = 0
var _tick_left: float = 0.0
var _hour_from: float = 0.0

## The x of the weight which lines up above the nearest spaceship.
var _weight_side: float = 1.0

## How many of the steps of the current chime happened, e.g., the calls of
## the cuckoo, the drops of the cones or the rings of the dance.
var _steps: int = 0


func _ready() -> void:
    super()
    rocket_look = Rocket.Look.NOTE
    for each: Chime in Chime.values():
        chimes[each] = 0


func is_in_a_hurry() -> bool:
    return is_alive() and float(energy) / float(max_energy) < hurry_below


## Return the chime which the hour hand points at: the next one during
## the countdown, or the current one while chiming.
func chime() -> Chime:
    return _chime


func is_counting_down() -> bool:
    return _phase == Phase.COUNTDOWN


func is_chiming() -> bool:
    return _phase == Phase.CHIMING


## Return true while the cuckoo is out of its door, i.e., the hits count
## double.
func is_cuckoo_out() -> bool:
    return is_alive() and _phase == Phase.CHIMING and _chime == Chime.CUCKOO


## Return the x of the lanes where the pine cones will drop, in the coordinates
## of the level, or an empty array if no pine cones come now.
func cone_lanes() -> Array[float]:
    var lanes: Array[float] = []
    if not is_alive() or _chime != Chime.PINE_CONES:
        return lanes
    if _phase == Phase.CHIMING or (_phase == Phase.COUNTDOWN and _tick >= ticks - 4):
        for side: float in [-1.0, 1.0]:
            lanes.append(global_position.x + side * _weight_offset())
    return lanes


func take_damage(amount: int) -> void:
    if is_cuckoo_out() and has_arrived():
        ticklish_hits += 1
        amount *= cuckoo_damage_factor
    super(amount)


func _may_fire() -> bool:
    # NOTE (mristin):
    # The clock attacks only on the chimes; see _move.
    return false


func _enter() -> void:
    super()
    _x = home.x


func _weight_offset() -> float:
    return radius * 0.4


func _energy_bar_y() -> float:
    return radius * 1.28


func _move(delta: float) -> void:
    _time += delta
    _phase_time += delta

    if _phase == Phase.DESCENDING:
        position.y = minf(position.y + descent_speed * delta, home.y)
        if position.y >= home.y:
            _time = 0.0
            _start_countdown()
        return

    _slide(delta)
    position.y = home.y + sin(_time * TAU * 0.25) * 6.0

    match _phase:
        Phase.COUNTDOWN:
            _count_down(delta)
        Phase.CHIMING:
            _chime_on(delta)


func _slide(delta: float) -> void:
    var bounds := get_viewport_rect()
    var wanted := home.x + sin(_time * TAU * sway_frequency) * sway
    var speed := slide_speed
    if _chime == Chime.PINE_CONES and _phase == Phase.COUNTDOWN:
        # NOTE (mristin):
        # The clock lines up a weight above the nearest spaceship during
        # the countdown, and stays put while the weights shake.
        var target := _nearest_spaceship()
        if target != null:
            var x := target.global_position.x
            _weight_side = -1.0 if x < _x else 1.0
            wanted = x - _weight_side * _weight_offset()
            speed = line_up_speed
    elif _phase == Phase.CHIMING and _chime == Chime.PINE_CONES:
        wanted = _x
    wanted = clampf(wanted, bounds.position.x + margin, bounds.end.x - margin)
    _x = move_toward(_x, wanted, speed * delta)
    position.x = _x


func _start_countdown() -> void:
    _hour_from = _quarter_angle(_chime)
    _phase = Phase.COUNTDOWN
    _phase_time = 0.0
    _tick = 0
    _tick_left = _tick_interval()

    var next := (int(_chime) + 1) % Chime.size()
    if next == Chime.MOON and is_in_a_hurry():
        next = Chime.CUCKOO
    _chime = next as Chime


func _tick_interval() -> float:
    return hurry_tick_interval if is_in_a_hurry() else tick_interval


func _count_down(delta: float) -> void:
    _tick_left -= delta
    if _tick_left > 0.0:
        return
    _tick += 1
    _tick_left = _tick_interval()
    if _tick >= ticks:
        _start_chime()


func _start_chime() -> void:
    _phase = Phase.CHIMING
    _phase_time = 0.0
    _steps = 0
    chimes[_chime] += 1
    Poof.spawn(self, global_position + _dial_center(), radius * 0.3, Color(1.0, 0.9, 0.5))


func _chime_on(_delta: float) -> void:
    var done := false
    match _chime:
        Chime.CUCKOO:
            var due := 0.5 + _steps * cuckoo_interval
            if _steps < cuckoo_calls and _phase_time >= due:
                _steps += 1
                _call_cuckoo()
            done = _phase_time >= 0.5 + cuckoo_calls * cuckoo_interval + 0.3
        Chime.PINE_CONES:
            var due := cone_warning + _steps * cone_interval
            if _steps < cones_per_weight and _phase_time >= due:
                _steps += 1
                _drop_cones()
            done = _phase_time >= cone_warning + cones_per_weight * cone_interval + 0.6
        Chime.DANCERS:
            var due := 0.7 + _steps * dance_interval
            if _steps < dance_rings and _phase_time >= due:
                _steps += 1
                _dance_ring()
            done = _phase_time >= 0.7 + dance_rings * dance_interval + 0.5
        Chime.MOON:
            done = _phase_time >= moon_duration
    if done:
        _start_countdown()


func _call_cuckoo() -> void:
    var beak := global_position + _door_center() + Vector2(0, radius * 0.12)
    var aim := _rocket_direction()
    if aim == Vector2.ZERO:
        aim = Vector2.DOWN
    for i in range(fan_size):
        var angle := (i - (fan_size - 1) / 2.0) * fan_angle
        _launch_rocket_from(beak, aim.rotated(angle), rocket_speed)


func _drop_cones() -> void:
    for side: float in [-1.0, 1.0]:
        var at := global_position + Vector2(side * _weight_offset(), _weight_y())
        var cone := _launch_rocket_from(at, Vector2.DOWN, cone_speed)
        if cone != null:
            cone.look = Rocket.Look.PINE_CONE
            cone.fall_acceleration = cone_fall_acceleration
            cones_dropped += 1


func _dance_ring() -> void:
    var at := global_position + Vector2(0, radius * 0.45)
    var start := PI / ring_size * _steps
    for i in range(ring_size):
        _launch_rocket_from(at, Vector2.RIGHT.rotated(start + TAU * i / ring_size), ring_speed)


# region Drawing


func _dial_center() -> Vector2:
    return Vector2(0, -radius * 0.12)


func _door_center() -> Vector2:
    return Vector2(0, -radius * 0.7)


func _weight_y() -> float:
    return radius * 0.98


## Return the angle of the quarter of the chime on the face, from twelve
## o'clock, clockwise.
func _quarter_angle(chime_of: Chime) -> float:
    return PI / 4.0 + PI / 2.0 * int(chime_of)


## Return the angle of the hour hand: it turns to the next quarter during
## the first ticks of the countdown.
func _hour_angle() -> float:
    var goal := _quarter_angle(_chime)
    if _phase != Phase.COUNTDOWN:
        return goal
    var from := _hour_from
    while goal < from:
        goal += TAU
    var t := clampf(_tick / 3.0, 0.0, 1.0)
    return lerpf(from, goal, smoothstep(0.0, 1.0, t))


func _minute_angle() -> float:
    if _phase == Phase.COUNTDOWN:
        return TAU * _tick / ticks
    return 0.0


## Return how strongly the next quarter lights up, from 0 to 1.
func _glow() -> float:
    match _phase:
        Phase.COUNTDOWN:
            return clampf(float(_tick) / ticks, 0.0, 1.0)
        Phase.CHIMING:
            return 1.0
        _:
            return 0.0


func _draw() -> void:
    if is_alive() and _phase != Phase.DESCENDING:
        _draw_lanes()
    super()


## Draw the soft lanes below the weights before the pine cones drop.
func _draw_lanes() -> void:
    var lanes := cone_lanes()
    if lanes.is_empty():
        return
    var bounds := get_viewport_rect()
    var strength := 0.5
    if _phase == Phase.CHIMING:
        strength = 0.5 + 0.5 * absf(sin(_phase_time * 9.0))
    for x in lanes:
        var top := to_local(Vector2(x, global_position.y + _weight_y()))
        var bottom := to_local(Vector2(x, bounds.end.y))
        var width := radius * 0.3
        draw_rect(
            Rect2(top + Vector2(-width / 2.0, 0), Vector2(width, bottom.y - top.y)),
            Color(1.0, 0.8, 0.45, 0.2 * strength)
        )
        for side: float in [-1.0, 1.0]:
            draw_dashed_line(
                top + Vector2(side * width / 2.0, 0),
                bottom + Vector2(side * width / 2.0, 0),
                Color(1.0, 0.8, 0.45, 0.45 * strength),
                4.0,
                18.0
            )


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var wood := Color(0.5, 0.32, 0.18).lerp(white, flash)
    var dark_wood := Color(0.32, 0.19, 0.1).lerp(white, flash)
    var light_wood := Color(0.68, 0.48, 0.28).lerp(white, flash)
    var dark := Color(0.15, 0.08, 0.05)

    var tick_sway := sin(_time * PI / _tick_interval()) * 0.22
    _draw_pendulum(tick_sway, flash)
    _draw_weights(flash)

    # The house: the body, the balcony and the roof with its carved trim.
    draw_rect(Rect2(Vector2(-r * 0.6, -r * 0.55), Vector2(r * 1.2, r * 1.1)), wood)
    draw_rect(
        Rect2(Vector2(-r * 0.6, -r * 0.55), Vector2(r * 1.2, r * 1.1)), dark_wood, false, r * 0.03
    )
    _draw_dancers(flash)
    draw_rect(Rect2(Vector2(-r * 0.7, r * 0.5), Vector2(r * 1.4, r * 0.08)), dark_wood)
    for i in range(9):
        var x := lerpf(-r * 0.66, r * 0.66, i / 8.0)
        draw_line(Vector2(x, r * 0.38), Vector2(x, r * 0.5), light_wood, r * 0.025)
    draw_line(Vector2(-r * 0.68, r * 0.38), Vector2(r * 0.68, r * 0.38), light_wood, r * 0.03)

    var roof := PackedVector2Array(
        [Vector2(-r * 0.86, -r * 0.48), Vector2(0, -r * 1.02), Vector2(r * 0.86, -r * 0.48)]
    )
    draw_colored_polygon(roof, dark_wood)
    var gable := PackedVector2Array(
        [Vector2(-r * 0.66, -r * 0.55), Vector2(0, -r * 0.9), Vector2(r * 0.66, -r * 0.55)]
    )
    draw_colored_polygon(gable, wood)
    # The dim snow on the roof.
    for side: float in [-1.0, 1.0]:
        draw_line(
            Vector2(side * r * 0.86, -r * 0.5),
            Vector2(0, -r * 1.04),
            Color(0.62, 0.66, 0.74).lerp(white, flash),
            r * 0.05,
            true
        )
    # The carved leaves on the sides.
    for side: float in [-1.0, 1.0]:
        for i in range(3):
            var at := Vector2(side * r * 0.66, -r * 0.3 + i * r * 0.28)
            draw_set_transform(at, side * 0.6, Vector2(1.0, 0.5))
            draw_circle(Vector2.ZERO, r * 0.08, Color(0.22, 0.35, 0.18).lerp(white, flash))
            draw_set_transform(Vector2.ZERO, 0.0)

    _draw_face(flash)
    _draw_cuckoo(flash)
    _draw_dial(flash)

    # The smile under the dial.
    draw_arc(Vector2(0, r * 0.25), r * 0.1, 0.35, PI - 0.35, 12, dark, r * 0.03)
    for side: float in [-1.0, 1.0]:
        draw_circle(Vector2(side * r * 0.38, r * 0.27), r * 0.06, Color(1.0, 0.5, 0.5, 0.6))


func _draw_face(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var dark := Color(0.15, 0.08, 0.05)
    var dozing := _phase == Phase.CHIMING and _chime == Chime.MOON
    for side: float in [-1.0, 1.0]:
        var eye := Vector2(side * r * 0.3, -r * 0.62)
        if dozing:
            draw_arc(eye, r * 0.07, 0.3, PI - 0.3, 10, dark, r * 0.025)
        else:
            draw_circle(eye, r * 0.085, white.lerp(Color(1, 1, 1), flash))
            var look := Vector2(0, r * 0.02)
            var target := _nearest_spaceship()
            if target != null:
                look = global_position.direction_to(target.global_position) * r * 0.025
            draw_circle(eye + look, r * 0.05, dark)
            draw_circle(eye + look + Vector2(-r * 0.015, -r * 0.015), r * 0.018, white)
        var brow := 0.03 if is_in_a_hurry() else 0.0
        draw_line(
            eye + Vector2(-side * r * 0.08, -r * (0.11 + brow)),
            eye + Vector2(side * r * 0.08, -r * 0.11),
            dark,
            r * 0.02
        )

    if dozing:
        # The sleepy "z"s float up from the roof.
        for i in range(3):
            var t := fmod(_phase_time * 0.6 + i / 3.0, 1.0)
            var at := Vector2(r * (0.6 + 0.3 * t), -r * (0.65 + 0.35 * t))
            var s := r * (0.06 + 0.06 * t)
            var color := Color(0.8, 0.8, 1.0, 0.8 * (1.0 - t))
            draw_polyline(
                PackedVector2Array(
                    [
                        at + Vector2(-s, -s),
                        at + Vector2(s, -s),
                        at + Vector2(-s, s),
                        at + Vector2(s, s)
                    ]
                ),
                color,
                r * 0.025
            )


func _draw_cuckoo(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var door := _door_center()
    var size := Vector2(r * 0.24, r * 0.2)
    var dark := Color(0.12, 0.07, 0.04)
    var door_color := Color(0.62, 0.42, 0.24).lerp(white, flash)

    var out := 0.0
    if is_cuckoo_out():
        out = clampf(_phase_time / 0.3, 0.0, 1.0)
        var end := 0.5 + cuckoo_calls * cuckoo_interval + 0.3
        out = minf(out, clampf((end - _phase_time) / 0.25, 0.0, 1.0))

    draw_rect(Rect2(door - size / 2.0, size), dark)
    if out <= 0.0:
        for side: float in [-1.0, 1.0]:
            draw_rect(
                Rect2(
                    door + Vector2(minf(side, 0.0) * size.x / 2.0, -size.y / 2.0),
                    Vector2(size.x / 2.0, size.y)
                ),
                door_color
            )
        draw_circle(door + Vector2(-r * 0.02, 0), r * 0.012, Color(0.9, 0.75, 0.3))
        draw_circle(door + Vector2(r * 0.02, 0), r * 0.012, Color(0.9, 0.75, 0.3))
        return

    # The open doors, and the cuckoo coming out, bigger when it calls.
    for side: float in [-1.0, 1.0]:
        draw_rect(
            Rect2(
                (
                    door
                    + Vector2(side * size.x / 2.0 + minf(side, 0.0) * size.x * 0.25, -size.y / 2.0)
                ),
                Vector2(size.x * 0.25, size.y)
            ),
            door_color
        )
    var calling := fmod(_phase_time - 0.5, cuckoo_interval) < 0.3 and _phase_time > 0.5
    var bird := door + Vector2(0, r * 0.05 * out)
    var bird_scale := out * (0.95 if calling else 0.8)
    var blue := Color(0.35, 0.6, 0.85).lerp(white, flash)
    draw_set_transform(bird, 0.0, Vector2(bird_scale, bird_scale))
    draw_circle(Vector2.ZERO, r * 0.14, blue)
    draw_circle(Vector2(0, r * 0.06), r * 0.08, Color(0.85, 0.9, 1.0).lerp(white, flash))
    for side: float in [-1.0, 1.0]:
        draw_circle(Vector2(side * r * 0.055, -r * 0.03), r * 0.035, white)
        draw_circle(Vector2(side * r * 0.055, -r * 0.025), r * 0.02, dark)
    var beak := Color(1.0, 0.75, 0.2).lerp(white, flash)
    var gape := r * (0.035 if calling else 0.005)
    draw_colored_polygon(
        PackedVector2Array(
            [Vector2(-r * 0.04, r * 0.01), Vector2(r * 0.04, r * 0.01), Vector2(0, r * 0.07)]
        ),
        beak
    )
    draw_colored_polygon(
        PackedVector2Array(
            [
                Vector2(-r * 0.035, r * 0.02 + gape),
                Vector2(r * 0.035, r * 0.02 + gape),
                Vector2(0, r * 0.06 + gape)
            ]
        ),
        beak
    )
    draw_set_transform(Vector2.ZERO, 0.0)


func _draw_dial(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var center := _dial_center()
    var dial_r := r * 0.34
    var dark := Color(0.15, 0.1, 0.08)
    var quarter_colors: Array[Color] = [
        Color(0.55, 0.75, 0.95),
        Color(0.9, 0.7, 0.45),
        Color(0.95, 0.65, 0.8),
        Color(0.7, 0.65, 0.95)
    ]

    draw_circle(center, dial_r + r * 0.04, Color(0.8, 0.62, 0.3).lerp(white, flash))
    draw_circle(center, dial_r, Color(0.95, 0.92, 0.82).lerp(white, flash))

    var glow := _glow()
    for chime_of: Chime in Chime.values():
        var mid := _quarter_angle(chime_of)
        var color: Color = quarter_colors[chime_of]
        var lit := chime_of == _chime and is_alive()
        color.a = 0.2
        if lit:
            color.a = 0.45 + 0.55 * glow
            if _phase == Phase.COUNTDOWN and _tick >= ticks - 4:
                # NOTE (mristin):
                # The quarter blinks for the last ticks before the chime.
                color.a = 0.6 + 0.4 * absf(sin(_time * 12.0))
        var wedge := PackedVector2Array([center])
        for i in range(13):
            var a := mid - PI / 4.0 + PI / 2.0 * i / 12.0
            wedge.append(center + Vector2(sin(a), -cos(a)) * dial_r * 0.97)
        draw_colored_polygon(wedge, color.lerp(white, flash))
        var icon_at := center + Vector2(sin(mid), -cos(mid)) * dial_r * 0.6
        _draw_icon(chime_of, icon_at, r * 0.075 * (1.25 if lit else 1.0))

    for i in range(12):
        var a := TAU * i / 12.0
        var direction := Vector2(sin(a), -cos(a))
        draw_line(
            center + direction * dial_r * 0.86, center + direction * dial_r * 0.97, dark, r * 0.015
        )

    var hour := _hour_angle()
    var minute := _minute_angle()
    draw_line(
        center, center + Vector2(sin(hour), -cos(hour)) * dial_r * 0.55, dark, r * 0.045, true
    )
    draw_line(
        center, center + Vector2(sin(minute), -cos(minute)) * dial_r * 0.85, dark, r * 0.025, true
    )
    draw_circle(center, r * 0.035, Color(0.8, 0.62, 0.3))


## Draw the little picture of the chime on its quarter of the face.
func _draw_icon(chime_of: Chime, at: Vector2, s: float) -> void:
    var dark := Color(0.2, 0.15, 0.12)
    match chime_of:
        Chime.CUCKOO:
            draw_circle(at, s, Color(0.3, 0.5, 0.8))
            draw_circle(at + Vector2(-s * 0.3, -s * 0.2), s * 0.2, dark)
            draw_circle(at + Vector2(s * 0.3, -s * 0.2), s * 0.2, dark)
            draw_colored_polygon(
                PackedVector2Array(
                    [
                        at + Vector2(-s * 0.3, s * 0.1),
                        at + Vector2(s * 0.3, s * 0.1),
                        at + Vector2(0, s * 0.6)
                    ]
                ),
                Color(1.0, 0.7, 0.15)
            )
        Chime.PINE_CONES:
            draw_set_transform(at, 0.0, Vector2(0.75, 1.1))
            draw_circle(Vector2.ZERO, s, Color(0.55, 0.32, 0.15))
            draw_set_transform(Vector2.ZERO, 0.0)
            draw_line(at + Vector2(-s * 0.5, -s * 0.3), at + Vector2(s * 0.5, s * 0.1), dark, 2.0)
            draw_line(at + Vector2(s * 0.5, -s * 0.3), at + Vector2(-s * 0.5, s * 0.1), dark, 2.0)
        Chime.DANCERS:
            for side: float in [-1.0, 1.0]:
                var dancer := at + Vector2(side * s * 0.55, 0)
                draw_circle(dancer + Vector2(0, -s * 0.5), s * 0.35, Color(1.0, 0.82, 0.68))
                draw_colored_polygon(
                    PackedVector2Array(
                        [
                            dancer + Vector2(0, -s * 0.2),
                            dancer + Vector2(-s * 0.45, s * 0.8),
                            dancer + Vector2(s * 0.45, s * 0.8)
                        ]
                    ),
                    Color(0.85, 0.2, 0.25) if side < 0.0 else Color(0.2, 0.45, 0.3)
                )
        Chime.MOON:
            draw_circle(at, s, Color(1.0, 0.9, 0.55))
            draw_circle(at + Vector2(s * 0.45, -s * 0.3), s * 0.85, Color(0.7, 0.65, 0.95))


func _draw_pendulum(tick_sway: float, flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var top := Vector2(0, r * 0.5)
    var angle := tick_sway if _phase != Phase.DESCENDING else 0.0
    var bob := top + Vector2(0, r * 0.62).rotated(-angle)
    draw_line(top, bob, Color(0.8, 0.62, 0.3).lerp(white, flash), r * 0.03)
    draw_circle(bob, r * 0.12, Color(0.85, 0.65, 0.3).lerp(white, flash))
    draw_circle(bob, r * 0.08, Color(0.95, 0.8, 0.45).lerp(white, flash))


func _draw_weights(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var chain := Color(0.6, 0.55, 0.45).lerp(white, flash)
    var cone := Color(0.55, 0.33, 0.16).lerp(white, flash)
    var dark := Color(0.35, 0.2, 0.1).lerp(white, flash)

    var shaking := _chime == Chime.PINE_CONES and _phase == Phase.CHIMING
    for side: float in [-1.0, 1.0]:
        var top := Vector2(side * _weight_offset(), r * 0.5)
        var at := Vector2(side * _weight_offset(), _weight_y())
        if shaking and _phase_time < cone_warning:
            at.x += sin(_time * 40.0) * r * 0.02
        # NOTE (mristin):
        # Right after a drop, a new pine cone grows on the chain.
        var grow := 1.0
        if shaking and _phase_time >= cone_warning:
            grow = clampf(fmod(_phase_time - cone_warning, cone_interval) / cone_interval, 0.2, 1.0)
        draw_line(top, at, chain, r * 0.02)
        draw_set_transform(at + Vector2(0, r * 0.05), 0.0, Vector2(0.7, 1.0) * grow)
        draw_circle(Vector2.ZERO, r * 0.1, cone)
        for i in range(3):
            var y := -r * 0.05 + i * r * 0.05
            draw_line(Vector2(-r * 0.07, y - r * 0.03), Vector2(0, y), dark, 2.0)
            draw_line(Vector2(r * 0.07, y - r * 0.03), Vector2(0, y), dark, 2.0)
        draw_set_transform(Vector2.ZERO, 0.0)


func _draw_dancers(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var dancing := is_alive() and _phase == Phase.CHIMING and _chime == Chime.DANCERS
    var out := 0.0
    if dancing:
        var end := 0.7 + dance_rings * dance_interval + 0.5
        out = minf(clampf(_phase_time / 0.5, 0.0, 1.0), clampf((end - _phase_time) / 0.4, 0.0, 1.0))

    # The two little doors on the sides of the balcony.
    for side: float in [-1.0, 1.0]:
        var door := Rect2(Vector2(side * r * 0.42 - r * 0.08, r * 0.24), Vector2(r * 0.16, r * 0.2))
        draw_rect(
            door,
            Color(0.12, 0.07, 0.04) if out > 0.0 else Color(0.62, 0.42, 0.24).lerp(white, flash)
        )

    if out <= 0.0:
        return

    # NOTE (mristin):
    # The pair dances around the turntable, in front of the house.
    var spin := _phase_time * 4.0
    for i in range(2):
        var a := spin + PI * i
        var at := Vector2(cos(a) * r * 0.42 * out, r * 0.36 + sin(a) * r * 0.05)
        var dress := Color(0.85, 0.2, 0.25) if i == 0 else Color(0.2, 0.45, 0.3)
        var s := r * 0.13
        draw_colored_polygon(
            PackedVector2Array(
                [at + Vector2(0, -s * 0.6), at + Vector2(-s, s * 0.9), at + Vector2(s, s * 0.9)]
            ),
            dress.lerp(white, flash)
        )
        draw_rect(
            Rect2(at + Vector2(-s * 0.45, -s * 0.4), Vector2(s * 0.9, s * 0.25)),
            Color(1, 1, 1, 0.9)
        )
        var head := at + Vector2(0, -s * 1.1)
        draw_circle(head, s * 0.55, Color(1.0, 0.82, 0.68).lerp(white, flash))
        draw_circle(head + Vector2(-s * 0.2, -s * 0.05), s * 0.09, Color(0.15, 0.08, 0.05))
        draw_circle(head + Vector2(s * 0.2, -s * 0.05), s * 0.09, Color(0.15, 0.08, 0.05))
        draw_arc(head + Vector2(0, s * 0.12), s * 0.18, 0.3, PI - 0.3, 6, Color(0.5, 0.2, 0.2), 2.0)
        if i == 0:
            draw_circle(head + Vector2(-s * 0.55, s * 0.1), s * 0.22, Color(0.95, 0.8, 0.35))
            draw_circle(head + Vector2(s * 0.55, s * 0.1), s * 0.22, Color(0.95, 0.8, 0.35))
        else:
            draw_rect(
                Rect2(head + Vector2(-s * 0.6, -s * 0.75), Vector2(s * 1.2, s * 0.3)),
                Color(0.15, 0.25, 0.15)
            )

# endregion
