class_name GiantWalrus

extends Enemy

## The giant walrus, the big, round and friendly guardian of the arctic sea,
## who comes at the end of the seventh level once all the others have fled.
## It lies on its big ice floe at the top of the screen, paddles slowly to and
## fro, and takes turns:
##
## * The clap: it lifts its flippers, then claps them and throws a fan of
##   snowballs at the nearest spaceship.
## * The belly flop: it wiggles, and a big shadow shows on the ice where it
##   will land. Then it hops up high, towards the players looking down, and
##   flops onto the ice with a big "splosh", which sends a slow ring of ice
##   chunks all around.
## * The ice walls: it slaps the ice, and three walls of ice rise between it
##   and the players, with gaps between them. The bullets bump into the walls,
##   so the players shoot them down or fly to the gaps.
##
## When it is low on energy, it attacks more often, and its belly flop sends
## a second ring right after the first one.
##
## The walrus lies on the ice, so the spaceships fly over it.

enum Action { ENTERING, RESTING, CLAP, FLOP_WINDUP, FLOP, SLAP }

const _ICE_WALL_SCENE: PackedScene = preload("res://scenes/enemies/ice_wall/ice_wall.tscn")

@export var descent_speed: float = 150.0

## How fast the ice slides down, in pixels per second; the ice walls slide
## with it.
@export var ground_speed: float = 40.0

@export var sway_amplitude: float = 380.0
@export var sway_frequency: float = 0.04

## The clap: how long it lifts its flippers first, and the fan of snowballs.
@export var clap_duration: float = 0.7
@export var fan_size: int = 3
@export var fan_angle: float = 0.3

## The belly flop: how long it wiggles first, how long it is in the air, how
## far it hops at most, and the ring of ice chunks.
@export var flop_windup: float = 1.3
@export var flop_duration: float = 1.1
@export var flop_reach: float = 450.0
@export var ring_count: int = 6
@export var ring_speed: float = 210.0
@export var second_ring_delay: float = 0.6

## The ice walls: how long it takes to slap the ice, how many walls rise, how
## far apart, and how far below the walrus.
@export var slap_duration: float = 0.8
@export var wall_count: int = 3
@export var wall_spacing: float = 420.0
@export var wall_below: float = 380.0

## Below this fraction of the energy, it attacks this many times as often.
@export_range(0.0, 1.0) var hurry_below: float = 0.4
@export var hurry_factor: float = 1.4

@export var margin: float = 300.0

var _action: Action = Action.ENTERING
var _action_time: float = 0.0
var _time: float = 0.0
var _sway_time: float = 0.0
var _attack: int = 0
var _flops: int = 0
var _claps: int = 0
var _walls_raised: int = 0
var _anchor_x: float = 0.0
var _flop_from: float = 0.0
var _flop_to: float = 0.0
var _height: float = 0.0
var _second_ring_left: float = -1.0
var _walls: Array[IceWall] = []


func _ready() -> void:
    super()
    grounded = true
    rocket_look = Rocket.Look.SNOWBALL


## Return how many times it belly-flopped so far, e.g., for the tests.
func flops() -> int:
    return _flops


## Return how many times it clapped the snowballs so far, e.g., for the tests.
func claps() -> int:
    return _claps


## Return how many ice walls it raised so far, e.g., for the tests.
func walls_raised() -> int:
    return _walls_raised


func action() -> Action:
    return _action


## Return where the walrus will land, in global coordinates, while it gets
## ready to flop or is in the air.
func landing_spot() -> Vector2:
    var parent := get_parent() as Node2D
    var local := Vector2(_flop_to, home.y)
    return parent.to_global(local) if parent != null else local


## Return the ice walls which still stand.
func walls() -> Array[IceWall]:
    var result: Array[IceWall] = []
    for wall in _walls:
        if is_instance_valid(wall) and wall.is_alive():
            result.append(wall)
    return result


func is_in_a_hurry() -> bool:
    return is_alive() and float(energy) / float(max_energy) < hurry_below


func _enter() -> void:
    super()
    _anchor_x = home.x


func _may_fire() -> bool:
    return _action == Action.RESTING


func _move(delta: float) -> void:
    _time += delta
    _action_time += delta

    if _second_ring_left >= 0.0:
        _second_ring_left -= delta
        if _second_ring_left < 0.0:
            _ring(PI / ring_count)

    match _action:
        Action.ENTERING:
            position.y = minf(position.y + descent_speed * delta, home.y)
            if position.y >= home.y:
                _start(Action.RESTING)
        Action.RESTING:
            _sway(delta)
        Action.CLAP:
            if _action_time >= clap_duration:
                _clap()
                _start(Action.RESTING)
        Action.FLOP_WINDUP:
            if _action_time >= flop_windup:
                _start(Action.FLOP)
        Action.FLOP:
            var t := clampf(_action_time / flop_duration, 0.0, 1.0)
            position.x = lerpf(_flop_from, _flop_to, smoothstep(0.0, 1.0, t))
            _height = sin(PI * t)
            if t >= 1.0:
                _height = 0.0
                _land()
                _start(Action.RESTING)
        Action.SLAP:
            if _action_time >= slap_duration:
                _raise_walls()
                _start(Action.RESTING)


func _start(new_action: Action) -> void:
    _action = new_action
    _action_time = 0.0


## Paddle slowly to and fro around the anchor.
func _sway(delta: float) -> void:
    _sway_time += delta
    var bounds := get_viewport_rect()
    var x := _anchor_x + sin(_sway_time * TAU * sway_frequency) * sway_amplitude * 0.5
    position.x = clampf(x, bounds.position.x + margin, bounds.end.x - margin)
    position.y = home.y + sin(_time * 1.3) * 8.0


func _fire_rocket() -> void:
    if is_in_a_hurry():
        _rocket_cooldown /= hurry_factor

    match _attack % 4:
        0, 2:
            _start(Action.CLAP)
        1:
            _start_flop()
        _:
            if walls().is_empty():
                _start(Action.SLAP)
            else:
                _start_flop()
    _attack += 1


func _clap() -> void:
    _claps += 1
    var aim := _rocket_direction()
    if aim == Vector2.ZERO:
        aim = Vector2.DOWN
    var from := global_position + Vector2(0, radius * 0.4)
    for i in range(fan_size):
        var angle := (i - (fan_size - 1) / 2.0) * fan_angle
        _launch_rocket_from(from, aim.rotated(angle), rocket_speed)


func _start_flop() -> void:
    var bounds := get_viewport_rect()
    var target := _nearest_spaceship()
    var x := position.x
    if target != null:
        x = target.global_position.x - global_position.x + position.x
    x = clampf(x, position.x - flop_reach, position.x + flop_reach)
    _flop_from = position.x
    _flop_to = clampf(x, bounds.position.x + margin, bounds.end.x - margin)
    _start(Action.FLOP_WINDUP)


func _land() -> void:
    _flops += 1
    _anchor_x = position.x
    _sway_time = 0.0
    Poof.spawn(
        self, global_position + Vector2(0, radius * 0.3), radius * 0.9, Color(0.75, 0.9, 1.0)
    )
    _ring(0.0)
    if is_in_a_hurry():
        _second_ring_left = second_ring_delay


func _ring(offset: float) -> void:
    if not is_alive():
        return
    rocket_look = Rocket.Look.ICICLE
    for i in range(ring_count):
        var direction := Vector2.DOWN.rotated(offset + TAU * (i + 0.5) / ring_count)
        _launch_rocket(direction, ring_speed)
    rocket_look = Rocket.Look.SNOWBALL


func _raise_walls() -> void:
    var bounds := get_viewport_rect()
    var target := _nearest_spaceship()
    var center_x := target.global_position.x if target != null else global_position.x
    var half := (wall_count - 1) / 2.0 * wall_spacing
    center_x = clampf(center_x, bounds.position.x + half + 120.0, bounds.end.x - half - 120.0)
    for i in range(wall_count):
        var at := Vector2(
            center_x + (i - (wall_count - 1) / 2.0) * wall_spacing, global_position.y + wall_below
        )
        var wall: IceWall = _ICE_WALL_SCENE.instantiate()
        wall.ground_speed = ground_speed
        wall.spawned_in_place = true
        var enemies := get_parent() as Node2D
        wall.position = enemies.to_local(at) if enemies != null else at
        _minions.append(wall)
        _walls.append(wall)
        get_parent().add_child.call_deferred(wall)
        Poof.spawn(self, at, 70.0, Color(0.75, 0.92, 1.0))
        _walls_raised += 1


func _energy_bar_y() -> float:
    return radius * 0.62


func _draw() -> void:
    if not is_fleeing() and _action in [Action.FLOP_WINDUP, Action.FLOP]:
        _draw_landing_shadow()
    super()


## Draw the shadow where the walrus will land; it grows darker until it lands.
func _draw_landing_shadow() -> void:
    var r := radius
    var at := Vector2(_flop_to - position.x, home.y - position.y)
    var t := 0.0
    if _action == Action.FLOP_WINDUP:
        t = 0.4 * clampf(_action_time / flop_windup, 0.0, 1.0)
    else:
        t = 0.4 + 0.6 * clampf(_action_time / flop_duration, 0.0, 1.0)
    var pulse := 0.5 + 0.5 * sin(_time * 10.0)
    draw_set_transform(at + Vector2(0, r * 0.05), 0.0, Vector2(1.0, 0.65))
    draw_circle(Vector2.ZERO, r * 0.75 * (0.6 + 0.4 * t), Color(0.0, 0.02, 0.08, 0.3 + 0.35 * t))
    draw_arc(
        Vector2.ZERO,
        r * 0.8,
        0.0,
        TAU,
        48,
        Color(0.75, 0.92, 1.0, 0.45 + 0.45 * pulse),
        r * 0.035,
        true
    )
    draw_set_transform(Vector2.ZERO, 0.0)

    # NOTE (mristin):
    # Little snowflakes show the directions in which the ice chunks will fly
    # out.
    for i in range(ring_count):
        var direction := Vector2.DOWN.rotated(TAU * (i + 0.5) / ring_count)
        Poof.draw_twinkle(
            self,
            at + direction * r * 0.62,
            r * 0.06,
            _time * 2.0,
            Color(0.8, 0.95, 1.0, 0.4 + 0.5 * pulse)
        )


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var skin := Color(0.7, 0.48, 0.4).lerp(white, flash)
    var light := Color(0.88, 0.7, 0.6).lerp(white, flash)
    var dark := Color(0.48, 0.31, 0.27).lerp(white, flash)
    var ivory := Color(1.0, 0.97, 0.88)
    var hurry := is_in_a_hurry()

    # NOTE (mristin):
    # The big ice floe it lies on stays on the ice when it hops.
    if _action != Action.FLOP:
        var floe := PackedVector2Array()
        for i in range(16):
            var a := TAU * i / 16.0
            var jag := 1.0 + 0.06 * sin(a * 5.0 + 0.4)
            floe.append(Vector2(cos(a) * r * 1.0, sin(a) * r * 0.5 + r * 0.08) * jag)
        draw_colored_polygon(floe, Color(0.3, 0.45, 0.6))
        var top := PackedVector2Array()
        for point in floe:
            top.append(point * 0.93 + Vector2(-r * 0.02, -r * 0.03))
        draw_colored_polygon(top, Color(0.45, 0.58, 0.72))

    # While it hops, it grows bigger, as it comes up towards the players.
    var lift := 1.0 + 0.3 * _height
    var wiggle := 0.0
    if _action == Action.FLOP_WINDUP:
        wiggle = sin(_time * 22.0) * 0.08
    var squash := 1.0
    if _action == Action.SLAP:
        squash = 1.0 - 0.08 * sin(PI * clampf(_action_time / slap_duration, 0.0, 1.0))
    draw_set_transform(Vector2(0, -r * 0.25 * _height), wiggle, Vector2(lift, lift * squash))

    # NOTE (mristin):
    # The walrus lies on its belly facing the players: the tail flippers
    # peek out at the back corners, then the big, round, blubbery body.
    for side: float in [-1.0, 1.0]:
        var flick := sin(_time * 3.0 + side) * r * 0.03
        draw_colored_polygon(
            PackedVector2Array(
                [
                    Vector2(side * r * 0.5, -r * 0.2),
                    Vector2(side * r * 0.85, -r * 0.3 + flick),
                    Vector2(side * r * 0.78, -r * 0.12 + flick),
                ]
            ),
            dark
        )
    var body := PackedVector2Array()
    for i in range(48):
        var a := TAU * i / 48.0
        body.append(Vector2(cos(a) * r * 0.68, sin(a) * r * 0.4 - r * 0.05))
    draw_colored_polygon(body, skin)
    draw_circle(Vector2(-r * 0.3, -r * 0.25), r * 0.12, Color(1, 1, 1, 0.12))
    for k in range(2):
        draw_arc(
            Vector2(0, r * (0.02 + k * 0.07)), r * 0.42, 0.5, PI - 0.5, 16, dark, r * 0.012, true
        )

    # The front flippers: lifted for the clap, flat on the ice otherwise.
    var raise := 0.0
    if _action == Action.CLAP:
        raise = clampf(_action_time / clap_duration, 0.0, 1.0)
    elif _action == Action.SLAP:
        raise = 1.0 - clampf(_action_time / slap_duration, 0.0, 1.0)
    for side: float in [-1.0, 1.0]:
        var shoulder := Vector2(side * r * 0.5, r * 0.15)
        var reach := Vector2(side * r * 0.32, r * 0.14).rotated(-side * raise * 1.4)
        var across := reach.orthogonal().normalized() * r * 0.09
        var flipper := PackedVector2Array(
            [
                shoulder + across,
                shoulder + reach + across * 0.8,
                shoulder + reach * 1.2,
                shoulder + reach - across * 0.8,
                shoulder - across,
            ]
        )
        draw_colored_polygon(flipper, dark)

    # The head: the round face, the friendly eyes and the rosy cheeks.
    var head := Vector2(0, r * 0.12)
    draw_circle(head, r * 0.34, skin)
    draw_circle(head + Vector2(-r * 0.1, -r * 0.14), r * 0.08, Color(1, 1, 1, 0.1))
    for side: float in [-1.0, 1.0]:
        var eye := head + Vector2(side * r * 0.13, -r * 0.12)
        draw_circle(eye, r * 0.065, white)
        draw_circle(eye + Vector2(0, r * 0.012), r * 0.04, Color(0.12, 0.08, 0.06))
        draw_circle(eye + Vector2(-r * 0.014, -r * 0.012), r * 0.016, white)
        var brow := r * 0.03 if hurry else 0.0
        draw_line(
            eye + Vector2(-side * r * 0.07, -r * 0.09 - brow),
            eye + Vector2(side * r * 0.05, -r * 0.09),
            dark,
            r * 0.02
        )
        draw_circle(
            head + Vector2(side * r * 0.25, -r * 0.02), r * 0.05, Color(1.0, 0.55, 0.6, 0.6)
        )

    # NOTE (mristin):
    # The two long, rounded tusks point down; they are just for show.
    for side: float in [-1.0, 1.0]:
        var root := head + Vector2(side * r * 0.07, r * 0.12)
        var tip := root + Vector2(side * r * 0.025, r * 0.24)
        draw_line(root, tip, dark, r * 0.065, true)
        draw_line(root, tip, ivory, r * 0.045, true)
        draw_circle(tip, r * 0.023, ivory)

    # The big, puffy whisker pads with the whiskers, and the nose on top.
    for side: float in [-1.0, 1.0]:
        var pad := head + Vector2(side * r * 0.09, r * 0.07)
        draw_circle(pad, r * 0.11, light)
        for k in range(3):
            draw_circle(
                pad + Vector2(side * r * (0.01 + k * 0.03), r * (-0.02 + (k % 2) * 0.04)),
                r * 0.009,
                dark
            )
            var from := pad + Vector2(side * r * 0.08, r * (-0.03 + k * 0.035))
            draw_line(
                from,
                from + Vector2(side * r * 0.2, r * (k - 1) * 0.045),
                Color(0.98, 0.94, 0.86),
                r * 0.011,
                true
            )
    draw_circle(head + Vector2(0, r * 0.0), r * 0.055, Color(0.3, 0.18, 0.15))
    if _action == Action.FLOP_WINDUP or _action == Action.FLOP:
        draw_circle(head + Vector2(0, r * 0.17), r * 0.04, Color(0.45, 0.15, 0.15))
    draw_set_transform(Vector2.ZERO, 0.0)
