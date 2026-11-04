class_name Enemy

extends Area2D

## Define what all the enemies share: arriving in waves, the energy, taking
## the damage, fleeing when out of energy and firing the rockets.
##
## The enemies leave no pickups behind; the boosters come only from the
## treasure chests.
##
## NOTE (mristin):
## This is a game for children, so the enemies never explode; they get dizzy and
## flee home.
##
## Each kind of enemy extends this class. It enters the screen by overriding
## _enter, moves in its own way by overriding _move, and looks its own way by
## overriding _draw_body. It fires its own pattern of rockets by overriding
## _rocket_direction or _fire_rocket. Its scene must put the enemy on the "enemies"
## collision layer (2) and scan nothing, so that the enemies never hit each
## other.

## The enemy ran out of energy and flees; it no longer counts.
signal defeated

const GROUP: String = "enemies"

## How many times bigger we make the enemies than their scenes say, except for
## the bosses, which are big already. We play on a small screen from a distance.
const GROW: float = 1.35

# NOTE (mristin):
# We load the scene lazily; a preload would be cyclic, since the projectiles
# refer back to the spaceships and the enemies.
const _ROCKET_SCENE_PATH: String = "res://scenes/rocket/rocket.tscn"

## The enemies have less energy than the spaceships have health. Like all the
## damage, the energy counts in tenths of a hit, so that we can tune it finely:
## a bullet takes 13.
@export var max_energy: int = 90

## Roughly the size of the enemy, for the energy bar and the poof.
@export var radius: float = 48.0

## Seconds after the start of the level until the enemy enters the screen.
## The level arranges the enemies into the waves with this delay.
@export var entry_delay: float = 0.0

## Wait until all the other enemies have fled before entering, e.g., for
## the queen at the end of the level. The entry delay then counts from that
## moment on.
@export var waits_for_others: bool = false

@export var min_rocket_interval: float = 2.5
@export var max_rocket_interval: float = 6.0
@export var rocket_speed: float = 380.0

## How the rockets of the enemy look, e.g., the spores of a mushroom.
@export var rocket_look: Rocket.Look = Rocket.Look.ROCKET

## How long the rockets fly, in seconds; short for the short-range sparks of
## a jellyfish.
@export var rocket_lifetime: float = 8.0

## How fast the enemy speeds up when fleeing, in pixels per second squared.
@export var flee_acceleration: float = 900.0

var energy: int = 0

## Where the level placed the enemy; each kind interprets it in its own way.
var home: Vector2 = Vector2.ZERO

## Enter right where the enemy was placed instead of from above the screen,
## e.g., when the queen calls in her darts.
var spawned_in_place: bool = false

## The enemy is on the ground, so the spaceships fly over it without clashing.
var grounded: bool = false

var _arrived: bool = false
var _rocket_cooldown: float = 0.0
var _hit_flash: float = 0.0

var _flee_time: float = 0.0
var _flee_velocity: Vector2 = Vector2.ZERO

## The enemies this one called in, which follow it home when it flees.
var _minions: Array[Enemy] = []

## The enemy was told to retreat before it even entered the scene tree.
var _retreat_when_ready: bool = false


func _ready() -> void:
    add_to_group(GROUP)
    if not waits_for_others:
        _enlarge_by(GROW)
    energy = max_energy
    home = position
    _rocket_cooldown = randf_range(min_rocket_interval, max_rocket_interval)

    # NOTE (mristin):
    # The enemy waits off the screen, out of reach, until its wave comes.
    visible = false
    monitorable = false

    if _retreat_when_ready:
        # NOTE (mristin):
        # We wait a frame so that the level can count us in first.
        retreat.call_deferred()


## Make the enemy bigger: its radius, which all the drawing follows, and its
## collision shapes.
func _enlarge_by(factor: float) -> void:
    radius *= factor
    for child in get_children():
        var shape := child as CollisionShape2D
        if shape != null:
            shape.position *= factor
            shape.scale *= factor


## Return the nearest enemy which can be hit, or null if there is none.
static func nearest_to(near: Node, global_pos: Vector2) -> Enemy:
    var nearest: Enemy = null
    var nearest_distance := INF

    for node in near.get_tree().get_nodes_in_group(GROUP):
        var enemy := node as Enemy
        if (
            enemy == null
            or not enemy.is_alive()
            or not enemy.has_arrived()
            or not enemy.is_targetable()
        ):
            continue

        var distance := global_pos.distance_squared_to(enemy.global_position)
        if distance < nearest_distance:
            nearest_distance = distance
            nearest = enemy

    return nearest


## Return true while the enemy still fights, i.e., it has not fled yet.
func is_alive() -> bool:
    return energy > 0


## Return false while the enemy can not be hit, e.g., while diving, so that
## the homing rockets look for another target.
func is_targetable() -> bool:
    return true


func is_fleeing() -> bool:
    return energy == 0


## Return true once the enemy's wave has come.
func has_arrived() -> bool:
    return _arrived


func take_damage(amount: int) -> void:
    if not is_alive() or not has_arrived():
        return

    energy = maxi(0, energy - amount)
    _hit_flash = 0.1
    queue_redraw()

    if energy == 0:
        _start_fleeing()


## Give up and flee home without being beaten, e.g., when the queen
## flees and her darts follow her.
func retreat() -> void:
    if not is_inside_tree():
        _retreat_when_ready = true
        return

    if not is_alive():
        return

    energy = 0
    if not has_arrived():
        # NOTE (mristin):
        # The enemy never showed up, so it quietly stays away.
        defeated.emit()
        queue_free()
        return

    _start_fleeing(false)


## Flee home, beaten by the players or retreating with the boss.
func _start_fleeing(_beaten: bool = true) -> void:
    Poof.spawn(self, global_position, radius, Color(1.0, 0.82, 0.4))

    # NOTE (mristin):
    # We may be inside a physics callback here (e.g., a bullet hit us), where
    # Godot forbids changing the monitoring directly.
    set_deferred("monitorable", false)

    for minion in minions():
        minion.retreat()

    # NOTE (mristin):
    # Flee up and away from the middle of the screen.
    var side := signf(global_position.x - get_viewport_rect().get_center().x)
    if side == 0.0:
        side = 1.0
    _flee_velocity = Vector2(side * 120.0, -150.0)

    defeated.emit()


func _flee(delta: float) -> void:
    _flee_time += delta
    _flee_velocity += Vector2(_flee_velocity.x * 0.5, -flee_acceleration) * delta
    position += _flee_velocity * delta

    if not get_viewport_rect().grow(radius * 3.0).has_point(global_position):
        queue_free()
        return

    queue_redraw()


func _physics_process(delta: float) -> void:
    if is_fleeing():
        _flee(delta)
        return

    if not _arrived:
        if waits_for_others and _others_fighting():
            return

        entry_delay -= delta
        if entry_delay > 0.0:
            return

        _arrived = true
        _enter()
        visible = true
        monitorable = true

    _move(delta)

    if get_viewport_rect().has_point(global_position) and _may_fire():
        _rocket_cooldown -= delta
        if _rocket_cooldown <= 0.0:
            _rocket_cooldown = randf_range(min_rocket_interval, max_rocket_interval)
            _fire_rocket()

    if _hit_flash > 0.0:
        _hit_flash = maxf(0.0, _hit_flash - delta)

    queue_redraw()


## Return the enemies this one called in, which still fight.
func minions() -> Array[Enemy]:
    var result: Array[Enemy] = []
    for minion in _minions:
        if is_instance_valid(minion) and minion.is_alive():
            result.append(minion)
    return result


## Call in another enemy at the given global position. If it follows, it flees
## home together with us.
func _summon(scene: PackedScene, global_pos: Vector2, follows: bool = true) -> Enemy:
    var minion: Enemy = scene.instantiate()
    minion.spawned_in_place = true
    var enemies := get_parent() as Node2D
    minion.position = enemies.to_local(global_pos) if enemies != null else global_pos
    if follows:
        _minions.append(minion)

    # NOTE (mristin):
    # We add the minion deferred, since we are often inside a physics callback
    # (e.g., a bullet hit us), where Godot forbids adding new areas.
    get_parent().add_child.call_deferred(minion)
    return minion


## Return true while any other enemy, which does not wait itself, still fights.
func _others_fighting() -> bool:
    for node in get_tree().get_nodes_in_group(GROUP):
        var enemy := node as Enemy
        if enemy != null and enemy != self and enemy.is_alive() and not enemy.waits_for_others:
            return true
    return false


## Return true if the enemy may fire from where it is now.
func _may_fire() -> bool:
    return true


## Put the enemy where it enters the screen; by default just above its home.
func _enter() -> void:
    if spawned_in_place:
        return
    position = Vector2(home.x, get_viewport_rect().position.y - radius * 2.0)


## Move the enemy; each kind of enemy moves in its own way.
func _move(_delta: float) -> void:
    pass


## Draw the enemy itself; the flash tells how much to whiten it after a hit.
func _draw_body(_flash: float) -> void:
    pass


## Return where the energy bar goes below the enemy, relative to its center.
func _energy_bar_y() -> float:
    return radius * 0.55


## Return the direction of the next rocket, or zero to hold the fire.
##
## By default, we aim at the nearest spaceship.
func _rocket_direction() -> Vector2:
    var target := _nearest_spaceship()
    if target == null:
        return Vector2.ZERO
    return global_position.direction_to(target.global_position)


## Fire the rocket(s); override for other patterns, e.g., a fan of rockets.
func _fire_rocket() -> void:
    var direction := _rocket_direction()
    if direction == Vector2.ZERO:
        return

    _launch_rocket(direction, rocket_speed)


## Launch a rocket and return it, so that the caller can, e.g., make it fall;
## return null if there is no level to launch it in.
func _launch_rocket(direction: Vector2, speed: float) -> Rocket:
    return _launch_rocket_from(global_position + direction * radius * 0.6, direction, speed)


func _launch_rocket_from(global_pos: Vector2, direction: Vector2, speed: float) -> Rocket:
    var projectiles := Projectiles.of(self)
    if projectiles == null:
        return null

    var rocket: Rocket = (load(_ROCKET_SCENE_PATH) as PackedScene).instantiate()
    rocket.velocity = direction * speed
    rocket.look = rocket_look
    rocket.lifetime = rocket_lifetime
    projectiles.launch(rocket, global_pos)
    return rocket


func _nearest_spaceship() -> Spaceship:
    var nearest: Spaceship = null
    var nearest_distance := INF

    for node in get_tree().get_nodes_in_group(Spaceship.GROUP):
        var spaceship := node as Spaceship
        if spaceship == null or not spaceship.is_alive():
            continue

        var distance := global_position.distance_squared_to(spaceship.global_position)
        if distance < nearest_distance:
            nearest_distance = distance
            nearest = spaceship

    return nearest


func _draw() -> void:
    if is_fleeing():
        # NOTE (mristin):
        # The dizzy enemy wobbles, with the stars circling above its head.
        draw_set_transform(Vector2.ZERO, sin(_flee_time * 14.0) * 0.3)
        _draw_body(0.0)
        draw_set_transform(Vector2.ZERO, 0.0)
        for i in range(3):
            var angle := _flee_time * 6.0 + TAU * i / 3.0
            var center := Vector2(
                cos(angle) * radius * 0.6, -radius * 0.8 + sin(angle) * radius * 0.15
            )
            Poof.draw_twinkle(self, center, 9.0, angle, Color(1.0, 0.9, 0.4))
        return

    # NOTE (mristin):
    # We only half whiten the enemy on a hit, so that an enemy under steady
    # fire, e.g., a boss, does not turn all white.
    _draw_body(0.5 * clampf(_hit_flash / 0.1, 0.0, 1.0))

    # NOTE (mristin):
    # The energy bar shows how many more hits the enemy takes.
    var width := radius * 1.4
    var top_left := Vector2(-width / 2.0, _energy_bar_y())
    var height := maxf(6.0, radius * 0.12)
    var fraction := float(energy) / float(max_energy)
    draw_rect(Rect2(top_left, Vector2(width, height)), Color(0, 0, 0, 0.6))
    draw_rect(
        Rect2(top_left, Vector2(width * fraction, height)),
        Color(1.0, 0.25, 0.2).lerp(Color(0.3, 1.0, 0.4), fraction)
    )
