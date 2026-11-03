class_name OldOak

extends Enemy

## The old oak, the grumpy guardian of the forest, who comes at the end of
## the third level once all the others have fled. It strides on its roots
## against the sliding ground, so that it stays at the top of the screen, and
## takes turns: a shower of acorns, a fan of spores at the nearest spaceship,
## and sprouting the mushrooms around it.
##
## The oak stands on the ground, so the spaceships fly over it. When it is low
## on energy, it shakes its leaves and attacks more often. When it flees, its
## mushrooms follow it home.

const _MUSHROOM_SCENE: PackedScene = preload("res://scenes/enemies/mushroom/mushroom.tscn")

@export var descent_speed: float = 150.0

@export var sway_amplitude: float = 420.0
@export var sway_frequency: float = 0.05

## The acorns: the number of them, spread over the lower half circle.
@export var acorn_count: int = 5
@export var acorn_speed: float = 330.0

## The spores: the number in the fan, and the angle between them.
@export var spore_fan_size: int = 3
@export var spore_fan_angle: float = 0.3
@export var spore_speed: float = 260.0

@export var mushrooms_per_sprout: int = 2
@export var max_mushrooms: int = 2

## Below this fraction of the energy, it attacks this many times as often.
@export_range(0.0, 1.0) var hurry_below: float = 0.34
@export var hurry_factor: float = 1.5

@export var margin: float = 240.0

var _time: float = 0.0
var _descending: bool = true
var _attack: int = 0


func _ready() -> void:
    super()
    grounded = true


func is_in_a_hurry() -> bool:
    return is_alive() and float(energy) / float(max_energy) < hurry_below


func _move(delta: float) -> void:
    _time += delta

    if _descending:
        position.y = minf(position.y + descent_speed * delta, home.y)
        if position.y >= home.y:
            _descending = false
            _time = 0.0
        return

    var bounds := get_viewport_rect()
    var x := home.x + sin(_time * TAU * sway_frequency) * sway_amplitude
    position.x = clampf(x, bounds.position.x + margin, bounds.end.x - margin)


func _fire_rocket() -> void:
    if _descending:
        return

    if is_in_a_hurry():
        _rocket_cooldown /= hurry_factor

    match _attack % 3:
        0:
            _throw_acorns()
        1:
            _puff_spores()
        _:
            if minions().size() + mushrooms_per_sprout <= max_mushrooms:
                _sprout_mushrooms()
            else:
                _throw_acorns()
    _attack += 1


func _throw_acorns() -> void:
    rocket_look = Rocket.Look.ACORN
    for i in range(acorn_count):
        var angle := lerpf(0.2 * PI, 0.8 * PI, i / float(acorn_count - 1))
        var from := global_position + Vector2(0, -radius * 0.45)
        _launch_rocket_from(from, Vector2.RIGHT.rotated(angle), acorn_speed)


func _puff_spores() -> void:
    rocket_look = Rocket.Look.SPORE
    var aim := _rocket_direction()
    if aim == Vector2.ZERO:
        aim = Vector2.DOWN
    for i in range(spore_fan_size):
        var angle := (i - (spore_fan_size - 1) / 2.0) * spore_fan_angle
        _launch_rocket(aim.rotated(angle), spore_speed)


func _sprout_mushrooms() -> void:
    for i in range(mushrooms_per_sprout):
        var side := -1.0 if i % 2 == 0 else 1.0
        var at := global_position + Vector2(side * radius * 0.9, radius * 0.5)
        var mushroom := _summon(_MUSHROOM_SCENE, at)
        mushroom.max_energy = 3
        mushroom.drop_chance = 0.1
        Poof.spawn(self, at, radius * 0.3, Color(0.6, 1.0, 0.4))


func _start_fleeing(may_drop: bool = true) -> void:
    # NOTE (mristin):
    # Its mushrooms follow it home; see Enemy.minions.
    super(may_drop)
    Poof.spawn(self, global_position, radius * 1.5, Color(0.6, 1.0, 0.4))


func _draw_body(flash: float) -> void:
    var white := Color(1, 1, 1)
    var r := radius
    var hurry := is_in_a_hurry()
    var bark := Color(0.5, 0.33, 0.18).lerp(white, flash)
    var dark_bark := Color(0.35, 0.22, 0.12).lerp(white, flash)

    # NOTE (mristin):
    # The roots wiggle as the oak strides.
    for i in range(4):
        var x := (i - 1.5) * r * 0.22
        var wiggle := sin(_time * 6.0 + i * 1.7) * r * 0.06
        draw_line(
            Vector2(x * 0.6, r * 0.4), Vector2(x * 1.6 + wiggle, r * 0.72), dark_bark, r * 0.1, true
        )

    draw_rect(Rect2(Vector2(-r * 0.3, -r * 0.3), Vector2(r * 0.6, r * 0.75)), bark)

    # The face on the trunk: the bushy brows, the eyes, the mossy moustache.
    var brow := 0.15 if hurry else 0.0
    for side: float in [-1.0, 1.0]:
        var eye := Vector2(side * r * 0.12, -r * 0.02)
        draw_circle(eye, r * 0.075, white)
        draw_circle(eye + Vector2(0, r * 0.015), r * 0.04, Color(0.1, 0.07, 0.03))
        draw_line(
            eye + Vector2(-side * r * 0.1, -r * (0.12 + brow)),
            eye + Vector2(side * r * 0.08, -r * 0.1),
            Color(0.25, 0.4, 0.15).lerp(white, flash),
            r * 0.05
        )
    draw_arc(Vector2(0, r * 0.22), r * 0.08, 0.3, PI - 0.3, 10, Color(0.2, 0.1, 0.05), r * 0.03)
    for side: float in [-1.0, 1.0]:
        draw_circle(
            Vector2(side * r * 0.08, r * 0.13), r * 0.07, Color(0.35, 0.6, 0.25).lerp(white, flash)
        )

    # NOTE (mristin):
    # The crown is a bunch of leafy balls, which shake when the oak is in
    # a hurry.
    var shake := sin(_time * 30.0) * r * 0.02 if hurry else 0.0
    var leaves := Color(0.3, 0.62, 0.28).lerp(white, flash)
    var light_leaves := Color(0.42, 0.75, 0.32).lerp(white, flash)
    var balls: Array[Vector3] = [
        Vector3(-0.55, -0.55, 0.35),
        Vector3(0.55, -0.55, 0.35),
        Vector3(-0.3, -0.85, 0.38),
        Vector3(0.3, -0.85, 0.38),
        Vector3(0.0, -0.6, 0.42),
    ]
    for ball in balls:
        var center := Vector2(ball.x * r + shake, ball.y * r)
        draw_circle(center, ball.z * r, leaves)
        draw_circle(center + Vector2(-0.1, -0.1) * r, ball.z * r * 0.55, light_leaves)

    for acorn: Vector2 in [Vector2(-0.6, -0.4), Vector2(0.45, -0.75), Vector2(0.15, -0.45)]:
        var at := acorn * r + Vector2(shake, 0)
        draw_circle(at, r * 0.05, Color(0.95, 0.7, 0.35).lerp(white, flash))
        draw_circle(at + Vector2(0, -r * 0.03), r * 0.04, Color(0.5, 0.32, 0.15).lerp(white, flash))
