extends SceneTree
## Test the combat on the first level: the firing, the clashes, the blinking,
## the rockets, keeping the damage on return, the dizzy spaceship and the
## fleeing aliens, and the messages between the levels.
##
## Run it with dev_scripts/run_tests.py, or directly:
##   godot --headless --fixed-fps 60 --path . --script tests/godot/test_combat.gd

var _failures: Array[String] = []
var _controller: HeadController
var _game: Game


func _check(condition: bool, message: String) -> void:
    print(("PASS " if condition else "FAIL ") + message)
    if not condition:
        _failures.append(message)


func _initialize() -> void:
    _run.call_deferred()


func _wait(seconds: float) -> void:
    await create_timer(seconds).timeout


func _level() -> Node:
    return _game.get_node("Screen").get_child(0)


func _fighting_enemies() -> Array[Enemy]:
    var result: Array[Enemy] = []
    for child in _level().get_node("Enemies").get_children():
        if child is Enemy and child.is_alive():
            result.append(child)
    return result


func _count(type_name: String) -> int:
    var n := 0
    for child in _level().get_node("Projectiles").get_children():
        if child.get_script() != null and child.get_script().get_global_name() == type_name:
            n += 1
    return n


func _message() -> String:
    for child in _game.get_children():
        if child is FinalMessage and not child.is_queued_for_deletion():
            return child.title.text
    return ""


func _ship() -> Spaceship:
    return _game._fleet._spaceships.get("0:0")


## Keep the enemies from firing and dropping, so that the checks are under
## control. Bring in all the saucers at once, and the darts only if asked, since
## they dive into the spaceship.
func _calm_level(with_darts: bool) -> void:
    for child in _level().get_node("Enemies").get_children():
        var enemy := child as Enemy
        enemy.entry_delay = 0.0 if with_darts or enemy is Saucer else 1000.0
        enemy._rocket_cooldown = 1000.0
        enemy.drop_chance = 0.0
    _level().get_node("SupplyDrops").enabled = false


## Chase all the aliens of the current level away, then the boss, which comes
## last, and wait for the outcome.
func _clear_level(boss_class: String) -> void:
    _calm_level(true)
    await _wait(0.1)
    # NOTE: Some aliens split or call in others, so we chase the aliens away
    # until only the boss is left.
    # NOTE: The clams can only be hit while open, so we keep trying for a while.
    for i in range(100):
        var others := _fighting_enemies().filter(func(e): return not e.waits_for_others)
        if others.is_empty():
            break
        for enemy in others:
            enemy.take_damage(enemy.max_energy)
        await _wait(0.1)
    var fighting := _fighting_enemies()
    _check(
        fighting.size() == 1 and fighting[0].get_script().get_global_name() == boss_class,
        "only the boss %s is left (%d)" % [boss_class, fighting.size()]
    )
    await _wait(0.1)
    var boss: Enemy = fighting[0]
    _check(boss.has_arrived(), "%s comes once all the others have fled" % boss_class)
    boss.take_damage(boss.max_energy)
    await _wait(2.3)


func _run() -> void:
    _controller = load("res://scenes/head_controller/head_controller.gd").new()
    _game = load("res://scenes/game/game.tscn").instantiate()
    _game.own_head_controllers([_controller])
    root.add_child(_game)
    await _wait(0.1)
    _calm_level(false)

    var hud: Hud = _game.get_node("Hud")
    _check(
        hud.enemy_count.text == "Aliens: 10",
        "HUD counts the aliens (got '%s')" % hud.enemy_count.text
    )

    # region Firing
    _controller.head_appeared.emit(0, Vector2(960, 1000))
    await _wait(1.0)
    var ship := _ship()
    _check(ship != null and ship.health == ship.max_health, "ship spawns with full health")
    _check(
        _count("Bullet") >= 2, "ship fires all the time (%d bullets in flight)" % _count("Bullet")
    )
    # endregion

    # region Bullets make a saucer flee
    await _wait(2.0)
    var victim: Saucer = null
    for enemy in _fighting_enemies():
        if enemy is Saucer:
            victim = enemy
            break
    var elapsed := 0.0
    while victim.is_alive() and elapsed < 5.0:
        _controller.head_moved.emit(0, Vector2(victim.global_position.x, 950))
        await _wait(0.05)
        elapsed += 0.05
    _check(victim.is_fleeing(), "bullets make a saucer flee (in %.2f s)" % elapsed)
    var energy_when_fled := victim.energy
    await _wait(0.05)
    # NOTE: Other saucers in the line of fire may flee as well.
    var still_fighting := _fighting_enemies().size()
    _check(
        still_fighting < 10 and hud.enemy_count.text == "Aliens: %d" % still_fighting,
        (
            "HUD counts the fled aliens off (got '%s', expected %d)"
            % [hud.enemy_count.text, still_fighting]
        )
    )
    _check(_count("Poof") >= 1, "the saucer goes poof instead of exploding")
    var victim_ref: WeakRef = weakref(victim)
    await _wait(3.0)
    _check(victim_ref.get_ref() == null, "the fled saucer leaves the screen")
    _check(energy_when_fled == 0, "the fleeing saucer takes no more hits")
    # endregion

    # region A clash costs both sides energy, then the spaceship blinks
    _controller.head_moved.emit(0, Vector2(960, 1000))
    await _wait(0.3)
    var bumped: Saucer = null
    for enemy in _fighting_enemies():
        if enemy is Saucer:
            bumped = enemy
            break
    # NOTE: Hold the fire, and clear the bullets in flight, so that only
    # the clash costs the saucer energy.
    ship._fire_cooldown = 1000.0
    for child in _level().get_node("Projectiles").get_children():
        if child is Bullet:
            child.queue_free()
    await _wait(0.05)
    bumped.max_energy = 100
    bumped.energy = 100
    for i in range(6):
        _controller.head_moved.emit(0, bumped.global_position)
        await _wait(0.05)
    _check(
        ship.health == ship.max_health - ship.collision_damage,
        "the clash costs the spaceship %d (health %d)" % [ship.collision_damage, ship.health]
    )
    _check(
        bumped.energy == 100 - ship.ramming_damage,
        "the clash costs the saucer %d (energy %d)" % [ship.ramming_damage, bumped.energy]
    )
    _check(ship.is_invulnerable(), "the spaceship is invulnerable right after the clash")

    var alphas := {}
    for i in range(12):
        _controller.head_moved.emit(0, bumped.global_position)
        alphas[snappedf(ship.modulate.a, 0.1)] = true
        await _wait(0.03)
    _check(alphas.size() >= 2, "the spaceship blinks (alphas seen: %s)" % str(alphas.keys()))
    _check(
        ship.health == ship.max_health - ship.collision_damage, "no further damage while blinking"
    )
    _check(
        bumped.energy == 100 - ship.ramming_damage,
        "no further clash damage to the saucer while blinking"
    )

    _controller.head_moved.emit(0, Vector2(960, 1000))
    await _wait(ship.invulnerability_duration + 0.2)
    _check(not ship.is_invulnerable() and is_equal_approx(ship.modulate.a, 1.0), "blinking stops")
    ship._fire_cooldown = 0.0
    # endregion

    # region A rocket hits the spaceship, but passes through the enemies
    var projectiles: Projectiles = _level().get_node("Projectiles")
    var health_before := ship.health
    var rocket_scene: PackedScene = load("res://scenes/rocket/rocket.tscn")
    var rocket: Rocket = rocket_scene.instantiate()
    rocket.velocity = Vector2(0, 600)
    projectiles.launch(rocket, ship.global_position - Vector2(0, 250))
    await _wait(0.8)
    _check(
        ship.health == health_before - 1,
        "a rocket costs 1 health (%d -> %d)" % [health_before, ship.health]
    )

    ship._fire_cooldown = 1000.0
    var crossed: Enemy = _fighting_enemies()[0]
    var crossed_energy := crossed.energy
    crossed.set_physics_process(false)
    var stray: Rocket = rocket_scene.instantiate()
    stray.velocity = Vector2(500, 0)
    projectiles.launch(stray, crossed.global_position - Vector2(200, 0))
    var stray_ref: WeakRef = weakref(stray)
    await _wait(0.7)
    _check(crossed.energy == crossed_energy, "a rocket passes through an enemy")
    _check(
        (
            stray_ref.get_ref() != null
            and (stray_ref.get_ref() as Rocket).global_position.x > crossed.global_position.x + 50
        ),
        "the rocket keeps flying past the enemy"
    )
    crossed.set_physics_process(true)
    ship._fire_cooldown = 0.0
    # endregion

    # region Leaving and returning keeps the damage and the color
    await _wait(ship.invulnerability_duration)
    var health_left := ship.health
    var color_left := ship.color
    _controller.head_lost.emit(0)
    await _wait(0.1)
    _controller.head_appeared.emit(1, Vector2(300, 1000))
    _controller.head_appeared.emit(0, Vector2(960, 1000))
    await _wait(0.1)
    ship = _ship()
    _check(
        ship.health == health_left,
        "a returning player keeps the damage (%d, expected %d)" % [ship.health, health_left]
    )
    _check(ship.color == color_left, "a returning player keeps the color")
    var other: Spaceship = _game._fleet._spaceships.get("0:1")
    _check(other.health == other.max_health, "a new player starts with full health")
    _controller.head_lost.emit(1)
    await _wait(0.1)
    # endregion

    # region A dizzy spaceship means trying the level again
    var level_id := _level().get_instance_id()
    ship.set_health(1)
    ship.take_damage(1)
    _check(
        ship.visible and not ship.is_alive(),
        "the spaceship out of shield gets dizzy, but stays visible"
    )
    await _wait(0.05)
    _check(_count("Poof") >= 1, "the dizzy spaceship goes poof")
    await _wait(1.0)
    _check(
        _message() == "" and _level().get_instance_id() == level_id,
        "the level waits a moment first"
    )
    await _wait(1.2)
    _check(_message() == "Let's try again!", "then it says to try again (got '%s')" % _message())
    _check(paused, "the game pauses during the message")
    await _wait(_game.level_message_seconds + 0.3)
    _check(
        not paused and _level().get_instance_id() != level_id,
        "the level restarts after the message"
    )
    ship = _ship()
    _check(
        ship.is_alive() and ship.health == ship.max_health and is_zero_approx(ship.hull.rotation),
        "the spaceship gets a fresh shield"
    )
    _check(hud.enemy_count.text == "Aliens: 10", "the restarted level has all the aliens again")
    # endregion

    # region All the aliens fled means the next level
    _calm_level(true)
    await _wait(0.1)
    level_id = _level().get_instance_id()
    for enemy in _fighting_enemies():
        if enemy.waits_for_others:
            continue
        enemy.take_damage(enemy.max_energy - 1)
        _check(enemy.is_alive(), "%s survives %d damage" % [enemy.name, enemy.max_energy - 1])
        enemy.take_damage(1)
    var queen: Queen = _fighting_enemies()[0]
    _check(
        _fighting_enemies().size() == 1 and queen is Queen,
        "only the queen is left (%d)" % _fighting_enemies().size()
    )
    await _wait(0.1)
    _check(queen.has_arrived(), "the queen comes once all the others have fled")
    queen.take_damage(queen.max_energy)
    await _wait(2.3)
    _check(_message() == "Great job!", "the first level is accomplished (got '%s')" % _message())
    await _wait(_game.level_message_seconds + 0.3)
    _check(
        _level().get_instance_id() != level_id and _level().name == "Second",
        "the second level comes next (got '%s')" % _level().name
    )
    _check(_level().get_node("ChestDrops").enabled, "the second level has the treasure chests")
    # endregion

    # region The second level leads to the third
    await _clear_level("Mothership")
    _check(_message() == "Great job!", "the second level is accomplished (got '%s')" % _message())
    await _wait(_game.level_message_seconds + 0.3)
    _check(_level().name == "Third", "the third level comes next (got '%s')" % _level().name)
    # endregion

    # region The spaceships fly over the ground enemies without clashing
    _calm_level(true)
    await _wait(0.1)
    var mushroom: Mushroom = null
    for enemy in _fighting_enemies():
        if enemy is Mushroom:
            mushroom = enemy
            break
    ship = _ship()
    var ship_health := ship.health
    var mushroom_energy := mushroom.energy
    # NOTE: Hold the fire, so that only a clash could cost the mushroom energy.
    ship.set_physics_process(false)
    for i in range(10):
        _controller.head_moved.emit(0, mushroom.global_position)
        await _wait(0.05)
    ship.set_physics_process(true)
    _check(
        ship.health == ship_health and mushroom.energy == mushroom_energy,
        (
            "the spaceship flies over the mushroom (health %d -> %d, energy %d -> %d)"
            % [ship_health, ship.health, mushroom_energy, mushroom.energy]
        )
    )
    _controller.head_moved.emit(0, Vector2(960, 1000))
    # endregion

    # region The third level leads to the fourth
    await _clear_level("OldOak")
    _check(_message() == "Great job!", "the third level is accomplished (got '%s')" % _message())
    await _wait(_game.level_message_seconds + 0.3)
    _check(_level().name == "Fourth", "the fourth level comes next (got '%s')" % _level().name)
    # endregion

    # region The fourth level leads to the fifth
    await _clear_level("SeaSerpent")
    _check(_message() == "Great job!", "the fourth level is accomplished (got '%s')" % _message())
    await _wait(_game.level_message_seconds + 0.3)
    _check(_level().name == "Fifth", "the fifth level comes next (got '%s')" % _level().name)
    # endregion

    # region The fifth level leads to the sixth
    await _clear_level("GreatDragon")
    _check(_message() == "Great job!", "the fifth level is accomplished (got '%s')" % _message())
    await _wait(_game.level_message_seconds + 0.3)
    _check(_level().name == "Sixth", "the sixth level comes next (got '%s')" % _level().name)
    # endregion

    # region The sixth level leads to the seventh
    await _clear_level("GreatScarab")
    _check(_message() == "Great job!", "the sixth level is accomplished (got '%s')" % _message())
    await _wait(_game.level_message_seconds + 0.3)
    _check(_level().name == "Seventh", "the seventh level comes next (got '%s')" % _level().name)
    # endregion

    # region The seventh level leads to the eighth
    await _clear_level("GiantWalrus")
    _check(_message() == "Great job!", "the seventh level is accomplished (got '%s')" % _message())
    await _wait(_game.level_message_seconds + 0.3)
    _check(_level().name == "Eighth", "the eighth level comes next (got '%s')" % _level().name)
    # endregion

    # region The eighth level leads to the ninth
    await _clear_level("StormCloud")
    _check(_message() == "Great job!", "the eighth level is accomplished (got '%s')" % _message())
    await _wait(_game.level_message_seconds + 0.3)
    _check(_level().name == "Ninth", "the ninth level comes next (got '%s')" % _level().name)
    # endregion

    # region The ninth level leads to Zurich, the last one
    await _clear_level("CuckooClock")
    _check(_message() == "Great job!", "the ninth level is accomplished (got '%s')" % _message())
    await _wait(_game.level_message_seconds + 0.3)
    _check(_level().name == "Tenth", "Zurich comes next (got '%s')" % _level().name)
    # endregion

    # region All the aliens of the last level fled means the game is finished
    level_id = _level().get_instance_id()
    await _clear_level("Banker")
    _check(_message() == "You did it!", "the last level finishes the game (got '%s')" % _message())
    await _wait(_game.game_finished_message_seconds + 0.3)
    _check(
        _level().get_instance_id() != level_id and _level().name == "First", "the game starts over"
    )
    # endregion

    # region The enemies fire rockets on their own
    _controller.head_moved.emit(0, Vector2(960, 1000))
    await _wait(1.0)
    for child in _level().get_node("Enemies").get_children():
        (child as Enemy).entry_delay = 0.0
    await _wait(1.5)
    for enemy in _fighting_enemies():
        enemy._rocket_cooldown = 0.1
    await _wait(0.4)
    _check(_count("Rocket") >= 3, "the enemies fire rockets (%d in flight)" % _count("Rocket"))
    # endregion

    print("RESULT: %s" % ("OK" if _failures.is_empty() else "FAILED %s" % str(_failures)))
    quit(0 if _failures.is_empty() else 1)
