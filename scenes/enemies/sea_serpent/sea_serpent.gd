class_name SeaSerpent

extends Enemy

## The sea serpent, who comes at the end of the water level once all the others
## have fled. Unlike the other bosses, it does not hover at the top and call
## for help. Its long body winds through the upper part of the screen along
## a figure of eight, and the players can hit it anywhere on its body.
##
## While surfaced, it sends a wave of bubbles down its body, from the tail to
## the head, or spits a fan of bubbles from its head. Every now and then, and
## each time it loses another share of its energy, it dives: then only its dark
## shadow shows, it can not be hit, and it swims fast to another spot, where it
## surfaces with a splash of bubbles all around.

enum Phase { ENTERING, SURFACED, DIVING }

@export var segment_count: int = 9
@export var segment_spacing: float = 52.0

## The figure of eight around the serpent's place in the level.
@export var path_width: float = 680.0
@export var path_height: float = 160.0

## How fast the serpent swims along the figure of eight, in radians per second,
## and how many times as fast while diving.
@export var path_speed: float = 0.55
@export var dive_speed_factor: float = 2.5

## How fast it swims in to the figure of eight when entering.
@export var enter_speed: float = 320.0

@export var min_surfaced_duration: float = 9.0
@export var max_surfaced_duration: float = 13.0
@export var dive_duration: float = 2.8

## It dives each time it loses another share of its energy, so many times.
@export var dives_by_energy: int = 3

## The wave of bubbles down the body, from every other segment: the seconds
## between the bubbles.
@export var wave_interval: float = 0.14
@export var wave_bubble_speed: float = 300.0

## The fan of bubbles from the head: the number and the angle between them.
@export var fan_size: int = 3
@export var fan_angle: float = 0.22

## The splash when surfacing: the number of bubbles all around.
@export var splash_size: int = 6
@export var splash_speed: float = 280.0

## Below this fraction of the energy, it attacks this many times as often.
@export_range(0.0, 1.0) var hurry_below: float = 0.34
@export var hurry_factor: float = 1.5

var _phase: Phase = Phase.ENTERING
var _time: float = 0.0
var _path_t: float = 0.0
var _surfaced_left: float = 0.0
var _dive_left: float = 0.0
var _dives: int = 0
var _energy_dives: int = 0
var _attack: int = 0
var _wave_index: int = -1
var _wave_cooldown: float = 0.0

## The past positions of the head, the newest first; the body follows them.
var _trail: Array[Vector2] = []

## The positions of the body segments relative to the head.
var _offsets: Array[Vector2] = []
var _shapes: Array[CollisionShape2D] = []


func _ready() -> void:
    super()
    for i in range(segment_count):
        var circle := CircleShape2D.new()
        circle.radius = _segment_radius(i) * 0.85
        var shape := CollisionShape2D.new()
        shape.shape = circle
        add_child(shape)
        _shapes.append(shape)
        _offsets.append(Vector2(0, -(i + 1) * segment_spacing))


## Return how many times the serpent has dived so far.
func dives() -> int:
    return _dives


func is_submerged() -> bool:
    return _phase == Phase.DIVING


func is_targetable() -> bool:
    return not is_submerged()


func is_in_a_hurry() -> bool:
    return is_alive() and float(energy) / float(max_energy) < hurry_below


func take_damage(amount: int) -> void:
    if is_submerged():
        return

    super(amount)

    var lost := 1.0 - float(energy) / float(max_energy)
    if (
        is_alive()
        and _phase == Phase.SURFACED
        and _energy_dives < dives_by_energy
        and lost >= (_energy_dives + 1.0) / (dives_by_energy + 1.0)
    ):
        _energy_dives += 1
        _dive()


func _segment_radius(i: int) -> float:
    return radius * lerpf(0.36, 0.18, i / float(maxi(1, segment_count - 1)))


func _path(t: float) -> Vector2:
    return Vector2(home.x + sin(t * 0.5) * path_width, home.y + sin(t) * path_height)


func _enter() -> void:
    super()
    _trail.clear()
    for i in range(segment_count + 2):
        _trail.append(position - Vector2(0, i * segment_spacing))
    _update_body()


func _move(delta: float) -> void:
    _time += delta

    match _phase:
        Phase.ENTERING:
            var target := _path(_path_t)
            position = position.move_toward(target, enter_speed * delta)
            if position.is_equal_approx(target):
                _phase = Phase.SURFACED
                _surfaced_left = randf_range(min_surfaced_duration, max_surfaced_duration)
        Phase.SURFACED:
            _path_t += path_speed * delta
            position = _path(_path_t)
            _surfaced_left -= delta
            if _surfaced_left <= 0.0:
                _dive()
        Phase.DIVING:
            _path_t += path_speed * dive_speed_factor * delta
            position = _path(_path_t)
            _dive_left -= delta
            if _dive_left <= 0.0:
                _surface()

    _update_body()
    _update_wave(delta)


func _update_body() -> void:
    _trail.push_front(position)

    # NOTE (mristin):
    # We walk back along the trail of the head, and put each segment at its
    # distance along the trail, so that the body follows the head's path.
    var walked := 0.0
    var segment := 0
    var used := _trail.size()
    for j in range(1, _trail.size()):
        var a := _trail[j - 1]
        var b := _trail[j]
        var length := a.distance_to(b)
        while segment < segment_count and walked + length >= (segment + 1) * segment_spacing:
            var t := ((segment + 1) * segment_spacing - walked) / length
            _offsets[segment] = a.lerp(b, t) - position
            segment += 1
        walked += length
        if segment >= segment_count:
            used = j + 1
            break

    for i in range(segment, segment_count):
        _offsets[i] = _trail[-1] - position
    _trail.resize(used)

    for i in range(segment_count):
        _shapes[i].position = _offsets[i]


func _dive() -> void:
    _phase = Phase.DIVING
    _dive_left = dive_duration
    _wave_index = -1
    _dives += 1
    set_deferred("monitorable", false)
    Poof.spawn(self, global_position, radius * 0.8, Color(0.7, 0.9, 1.0))


func _surface() -> void:
    _phase = Phase.SURFACED
    _surfaced_left = randf_range(min_surfaced_duration, max_surfaced_duration)
    set_deferred("monitorable", true)
    Poof.spawn(self, global_position, radius, Color(0.7, 0.9, 1.0))

    var start := randf() * TAU
    for i in range(splash_size):
        _launch_rocket(Vector2.RIGHT.rotated(start + TAU * i / splash_size), splash_speed)


func _fire_rocket() -> void:
    if _phase != Phase.SURFACED or _wave_index >= 0:
        return

    if is_in_a_hurry():
        _rocket_cooldown /= hurry_factor

    if _attack % 2 == 0:
        _wave_index = segment_count - 1
        _wave_cooldown = 0.0
    else:
        var aim := _rocket_direction()
        if aim != Vector2.ZERO:
            for i in range(fan_size):
                var angle := (i - (fan_size - 1) / 2.0) * fan_angle
                _launch_rocket(aim.rotated(angle), rocket_speed)
    _attack += 1


func _update_wave(delta: float) -> void:
    if _wave_index < 0 or _phase != Phase.SURFACED:
        return

    _wave_cooldown -= delta
    if _wave_cooldown > 0.0:
        return
    _wave_cooldown = wave_interval

    var from := global_position + _offsets[_wave_index]
    from.y += _segment_radius(_wave_index) * 0.5
    _launch_rocket_from(from, Vector2.DOWN.rotated(randf_range(-0.15, 0.15)), wave_bubble_speed)
    _wave_index -= 2


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius

    if is_submerged():
        # NOTE (mristin):
        # Under water, only the dark shadow and the ripples show.
        var shadow := Color(0.0, 0.04, 0.1, 0.45)
        for i in range(segment_count - 1, -1, -1):
            draw_circle(_offsets[i], _segment_radius(i), shadow)
        draw_circle(Vector2.ZERO, r * 0.42, shadow)
        for k in range(2):
            var ripple := fmod(_time * 1.2 + k * 0.5, 1.0)
            draw_arc(
                Vector2.ZERO,
                r * (0.4 + 0.5 * ripple),
                0.0,
                TAU,
                32,
                Color(0.7, 0.9, 1.0, 0.35 * (1.0 - ripple)),
                3.0,
                true
            )
        return

    var teal := Color(0.2, 0.65, 0.6).lerp(white, flash)
    var light_teal := Color(0.3, 0.78, 0.68).lerp(white, flash)
    var fin := Color(1.0, 0.65, 0.3).lerp(white, flash)

    for i in range(segment_count - 1, -1, -1):
        var center := _offsets[i]
        var ahead := _offsets[i - 1] if i > 0 else Vector2.ZERO
        var along := (ahead - center).normalized() if ahead != center else Vector2.UP
        var across := along.orthogonal()
        var sr := _segment_radius(i)

        if i % 2 == 0:
            for side: float in [-1.0, 1.0]:
                draw_colored_polygon(
                    PackedVector2Array(
                        [
                            center + across * side * sr * 0.6,
                            center + across * side * sr * 1.45 - along * sr * 0.4,
                            center + across * side * sr * 0.6 - along * sr * 0.6,
                        ]
                    ),
                    fin
                )
        draw_circle(center, sr, teal if i % 2 == 0 else light_teal)
        draw_circle(center - across * sr * 0.3, sr * 0.3, Color(1, 1, 1, 0.15))

    # NOTE (mristin):
    # The head looks where it swims.
    var forward := (-_offsets[0]).normalized() if _offsets[0] != Vector2.ZERO else Vector2.DOWN
    var side_axis := forward.orthogonal()
    var hr := r * 0.42
    for side: float in [-1.0, 1.0]:
        draw_colored_polygon(
            PackedVector2Array(
                [
                    side_axis * side * hr * 0.5 - forward * hr * 0.4,
                    side_axis * side * hr * 1.1 - forward * hr * 1.1,
                    side_axis * side * hr * 0.2 - forward * hr * 0.8,
                ]
            ),
            fin
        )
    draw_circle(Vector2.ZERO, hr, teal)
    draw_circle(forward * hr * 0.6, hr * 0.6, light_teal)
    for side: float in [-1.0, 1.0]:
        var eye := side_axis * side * hr * 0.45 + forward * hr * 0.1
        draw_circle(eye, hr * 0.24, white)
        draw_circle(eye + forward * hr * 0.06, hr * 0.12, Color(0.05, 0.15, 0.2))
        draw_circle(
            forward * hr * 1.0 + side_axis * side * hr * 0.2, hr * 0.06, Color(0.1, 0.3, 0.3)
        )
