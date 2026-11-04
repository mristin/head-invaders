class_name Spaceship

extends Area2D

## Represent a player's spaceship which follows the player's head, fires all
## the time, collects the pickups, and takes damage from the enemies and their
## rockets.
##
## The spaceship only says where it would like to be. The fleet decides on
## the actual position.

signal health_changed(health: int)

## The shield ran out and the spaceship is too dizzy to go on.
##
## NOTE (mristin):
## This is a game for children, so the spaceships never explode.
signal knocked_out

const GROUP: String = "spaceships"

# NOTE (mristin):
# We load the scene lazily; a preload would be cyclic, since the projectiles
# refer back to the spaceships and the enemies.
const _BULLET_SCENE_PATH: String = "res://scenes/bullet/bullet.tscn"
const _MISSILE_SCENE_PATH: String = "res://scenes/missile/missile.tscn"

## Radius of the shield ring, which shows the remaining health.
@export var radius: float = 58.0

@export var max_health: int = 10

## The damage the spaceship takes when it clashes with an enemy.
@export var collision_damage: int = 2

## The damage the enemy takes in the same clash.
@export var ramming_damage: int = 2

## Seconds between the shots.
@export var fire_interval: float = 0.2

## After a hit, the spaceship blinks and takes no more damage for this long.
@export var invulnerability_duration: float = 1.5

@export var blink_period: float = 0.12

@export_group("Pickups")

## How long the weapon pickups last, in seconds.
@export var boost_duration: float = 12.0

## How long the bubble from a treasure chest lasts, in seconds.
@export var bubble_duration: float = 8.0

## How much of the shield a shield pickup recharges.
@export var shield_recharge: int = 4

## With the rapid fire, the spaceship fires this many times as often, and the
## bullets fly this many times as fast.
@export var rapid_fire_factor: float = 2.0
@export var rapid_bullet_speed_factor: float = 1.3

## The angle between the bullets of the spread shot, in radians.
@export var spread_angle: float = 0.2

## Seconds between the homing rockets.
@export var missile_interval: float = 0.6

## Where the player's head is.
var target: Vector2 = Vector2.ZERO

var color: Color = Color.WHITE

var health: int = 0

var _fire_cooldown: float = 0.0
var _missile_cooldown: float = 0.0
var _missile_side: float = 1.0
var _invulnerable_left: float = 0.0
var _dizzy_time: float = 0.0

## Seconds left of each active weapon pickup.
var _boosts: Dictionary[Pickup.Kind, float] = {}

## How much the hull leans into the turns now, in radians.
var _lean: float = 0.0
var _last_x: float = NAN

@onready var hull: ShipHull = $Hull


func _ready() -> void:
    add_to_group(GROUP)

    _apply_color()

    health = max_health


func set_color(value: Color) -> void:
    color = value
    if is_node_ready():
        _apply_color()


func set_target(value: Vector2) -> void:
    target = value


func desired_position() -> Vector2:
    # NOTE (mristin):
    # We follow the head directly for now. This is the place to introduce
    # the lag later.
    #
    # We deliberately ignore the size of the face: the spaceship keeps the same
    # scale no matter how close the player is to the camera.
    return target


func is_alive() -> bool:
    return health > 0


func is_invulnerable() -> bool:
    return _invulnerable_left > 0.0


## Set the health without any effects, e.g., when a player returns with the
## damage they had before.
func set_health(value: int) -> void:
    health = clampi(value, 0, max_health)
    _apply_alive_state()
    health_changed.emit(health)
    queue_redraw()


## Repair the spaceship completely and drop the weapon pickups, e.g., at
## the start of a level.
func repair() -> void:
    _invulnerable_left = 0.0
    _boosts.clear()
    set_health(max_health)


func has_boost(kind: Pickup.Kind) -> bool:
    return _boosts.get(kind, 0.0) > 0.0


## Collect the pickup: recharge the shield, or arm the weapon for a while.
func collect(kind: Pickup.Kind) -> void:
    if not is_alive():
        return

    if kind == Pickup.Kind.SHIELD:
        health = mini(max_health, health + shield_recharge)
        health_changed.emit(health)
    else:
        # NOTE (mristin):
        # Collecting the same weapon again restarts its time.
        _boosts[kind] = _duration_of(kind)

    queue_redraw()


## Take the damage unless the spaceship is still blinking from the last hit.
##
## Return true if the spaceship took the damage.
func take_damage(amount: int) -> bool:
    if not is_alive() or is_invulnerable() or has_boost(Pickup.Kind.BUBBLE):
        return false

    health = maxi(0, health - amount)
    health_changed.emit(health)
    queue_redraw()

    if health == 0:
        Poof.spawn(self, global_position, radius * 1.5, color)
        _apply_alive_state()
        knocked_out.emit()
    else:
        _invulnerable_left = invulnerability_duration

    return true


func _process(delta: float) -> void:
    if is_alive():
        _lean_into_turns(delta)
        return

    # NOTE (mristin):
    # The dizzy spaceship spins, with the stars circling around it.
    _dizzy_time += delta
    hull.rotation = sin(_dizzy_time * 3.0) * 0.6 + _dizzy_time * 4.0
    queue_redraw()


## Lean the hull into the turns, so that the spaceship feels alive.
func _lean_into_turns(delta: float) -> void:
    if delta <= 0.0:
        return
    var speed := 0.0 if is_nan(_last_x) else (global_position.x - _last_x) / delta
    _last_x = global_position.x
    var wanted := clampf(speed / 2000.0, -1.0, 1.0) * 0.4
    _lean = lerpf(_lean, wanted, minf(1.0, delta * 10.0))
    hull.rotation = _lean


func _physics_process(delta: float) -> void:
    if not is_alive():
        return

    _update_boosts(delta)

    var interval := fire_interval
    if has_boost(Pickup.Kind.RAPID_FIRE):
        interval /= rapid_fire_factor

    _fire_cooldown -= delta
    if _fire_cooldown <= 0.0:
        # NOTE (mristin):
        # We do not catch up on the missed shots after a long frame.
        _fire_cooldown = maxf(_fire_cooldown + interval, 0.0)
        _fire()

    if has_boost(Pickup.Kind.ROCKETS):
        _missile_cooldown -= delta
        if _missile_cooldown <= 0.0:
            _missile_cooldown = missile_interval
            _launch_missile()

    if is_invulnerable():
        _invulnerable_left = maxf(0.0, _invulnerable_left - delta)
        var blink_on := fmod(_invulnerable_left, 2.0 * blink_period) < blink_period
        modulate.a = 0.2 if blink_on and is_invulnerable() else 1.0
    else:
        for area in get_overlapping_areas():
            var enemy := area as Enemy
            if enemy != null and enemy.is_alive() and not enemy.grounded:
                # NOTE (mristin):
                # Both lose some energy in a clash, but only once per hit, i.e.,
                # not again while the spaceship blinks.
                if take_damage(collision_damage):
                    enemy.take_damage(ramming_damage)
                break


func _duration_of(kind: Pickup.Kind) -> float:
    return bubble_duration if kind == Pickup.Kind.BUBBLE else boost_duration


func _update_boosts(delta: float) -> void:
    var expired: Array[Pickup.Kind] = []
    for kind: Pickup.Kind in _boosts:
        _boosts[kind] -= delta
        if _boosts[kind] <= 0.0:
            expired.append(kind)

    for kind in expired:
        _boosts.erase(kind)

    if not _boosts.is_empty() or not expired.is_empty():
        queue_redraw()


func _fire() -> void:
    var projectiles := Projectiles.of(self)
    if projectiles == null:
        return

    var angles: Array[float] = [0.0]
    if has_boost(Pickup.Kind.SPREAD_SHOT):
        angles = [-spread_angle, 0.0, spread_angle]

    var scene: PackedScene = load(_BULLET_SCENE_PATH)
    for angle in angles:
        var bullet: Bullet = scene.instantiate()
        bullet.color = color
        bullet.direction = Vector2.UP.rotated(angle)
        if has_boost(Pickup.Kind.RAPID_FIRE):
            bullet.speed *= rapid_bullet_speed_factor
        projectiles.launch(bullet, global_position + Vector2(0.0, -radius * 0.7))


func _launch_missile() -> void:
    var projectiles := Projectiles.of(self)
    if projectiles == null:
        return

    # NOTE (mristin):
    # We launch the rockets from the left and the right wing in turns, slightly
    # outwards, so that they visibly curve towards their targets.
    _missile_side = -_missile_side
    var missile: Missile = (load(_MISSILE_SCENE_PATH) as PackedScene).instantiate()
    missile.color = color
    missile.direction = Vector2.UP.rotated(_missile_side * 0.5)
    projectiles.launch(missile, global_position + Vector2(_missile_side * radius * 0.6, 0.0))


func _apply_alive_state() -> void:
    var alive := is_alive()
    modulate.a = 1.0 if alive else 0.8
    _dizzy_time = 0.0
    _lean = 0.0
    hull.rotation = 0.0

    # NOTE (mristin):
    # We may be inside a physics callback here (e.g., a rocket hit us), where
    # Godot forbids changing the monitoring directly.
    set_deferred("monitoring", alive)
    set_deferred("monitorable", alive)


func _apply_color() -> void:
    hull.color = color
    queue_redraw()


func _draw() -> void:
    # NOTE (mristin):
    # The ring makes the player's color easy to spot and works as the shield:
    # it shrinks with each hit, starting from the top and going clockwise.
    draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(color, 0.15), 3.0, true)

    if not is_alive():
        for i in range(4):
            var angle := _dizzy_time * 5.0 + TAU * i / 4.0
            var center := Vector2(
                cos(angle) * radius * 0.8, -radius * 0.9 + sin(angle) * radius * 0.25
            )
            Poof.draw_twinkle(self, center, 11.0, angle, Color(1.0, 0.9, 0.4))
        return

    if has_boost(Pickup.Kind.BUBBLE):
        # NOTE (mristin):
        # The bubble shimmers around the spaceship, and blinks when it is about
        # to pop.
        var left: float = _boosts[Pickup.Kind.BUBBLE]
        if left > 2.0 or fmod(left, 0.4) < 0.25:
            var bubble := Pickup.color_of(Pickup.Kind.BUBBLE)
            var wobble := 1.0 + 0.04 * sin(Time.get_ticks_msec() / 120.0)
            draw_circle(Vector2.ZERO, radius * 1.25 * wobble, Color(bubble, 0.15))
            draw_arc(
                Vector2.ZERO, radius * 1.25 * wobble, 0.0, TAU, 48, Color(bubble, 0.8), 3.0, true
            )
            draw_arc(
                Vector2.ZERO, radius * 0.95, PI * 1.1, PI * 1.45, 12, Color(1, 1, 1, 0.6), 4.0, true
            )

    var fraction := float(health) / float(max_health)
    if fraction > 0.0:
        var start := -PI / 2.0
        draw_arc(
            Vector2.ZERO,
            radius,
            start,
            start + TAU * fraction,
            maxi(4, int(64 * fraction)),
            Color(color, 0.85),
            5.0,
            true
        )

    # NOTE (mristin):
    # We show the active weapons below the ring, each with an arc telling how
    # long it lasts.
    var kinds := _boosts.keys()
    kinds.sort()
    for i in range(kinds.size()):
        var kind: Pickup.Kind = kinds[i]
        var center := Vector2((i - (kinds.size() - 1) / 2.0) * 56.0, radius + 34.0)
        var boost_color := Pickup.color_of(kind)
        draw_circle(center, 24.0, Color(boost_color.darkened(0.6), 0.85))
        draw_arc(
            center,
            24.0,
            -PI / 2.0,
            -PI / 2.0 + TAU * _boosts[kind] / _duration_of(kind),
            24,
            boost_color,
            5.0,
            true
        )
        Pickup.draw_symbol(self, kind, center, 14.0, Color(1, 1, 1))
