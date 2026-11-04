extends SceneTree
## Smoke-test the scrolling-shooter mechanics headless: the waves, the saucers
## descending, the darts wrapping around, the pickups and the weapons.

var _failures: Array[String] = []
var _controller: HeadController
var _game: Game


func _check(condition: bool, message: String) -> void:
    if condition:
        print("PASS ", message)
    else:
        print("FAIL ", message)
        _failures.append(message)


func _initialize() -> void:
    _run.call_deferred()


func _wait(seconds: float) -> void:
    await create_timer(seconds).timeout


func _level() -> Node:
    return _game.get_node("Screen").get_child(0)


func _enemies() -> Array[Enemy]:
    var result: Array[Enemy] = []
    for child in _level().get_node("Enemies").get_children():
        if child is Enemy and not child.is_queued_for_deletion():
            result.append(child)
    return result


func _of_type(type_name: String) -> Array[Node]:
    var result: Array[Node] = []
    for child in _level().get_node("Projectiles").get_children():
        if (
            child.get_script() != null
            and child.get_script().get_global_name() == type_name
            and not child.is_queued_for_deletion()
        ):
            result.append(child)
    return result


func _ship() -> Spaceship:
    return _game._fleet._spaceships.get("0:0")


func _hold_fire(enemies: Array[Enemy]) -> void:
    for enemy in enemies:
        enemy._rocket_cooldown = 1000.0
        enemy.drop_chance = 0.0


func _run() -> void:
    _controller = load("res://scenes/head_controller/head_controller.gd").new()
    _game = load("res://scenes/game/game.tscn").instantiate()
    _game.own_head_controllers([_controller])
    root.add_child(_game)
    await _wait(0.05)

    var hud: Hud = _game.get_node("Hud")
    var all := _enemies()
    _hold_fire(all)
    _level().get_node("SupplyDrops")._cooldown = 1000.0

    var saucers := all.filter(func(e): return e is Saucer)
    var darts := all.filter(func(e): return e is Dart)
    _check(saucers.size() == 2 and darts.size() == 2, "first level has 2 saucers and 2 darts")
    _check(
        all.filter(func(e): return e is Queen).size() == 1, "the first level ends with the queen"
    )
    _check(
        hud.enemy_count.text == "Aliens: 10",
        "HUD counts the enemies of all the waves (got '%s')" % hud.enemy_count.text
    )

    # region Waves
    var first: Saucer = saucers[0]
    _check(
        not first.visible or first.global_position.y < 0.0,
        "the first saucer enters from above the screen"
    )
    _check(
        darts.all(func(d): return not d.has_arrived() and not d.visible),
        "the later waves wait unseen"
    )

    var waiting: Dart = darts[0]
    waiting.take_damage(100)
    _check(waiting.energy == waiting.max_energy, "a waiting enemy can not be hit")

    await _wait(2.5)
    _check(
        (
            first.has_arrived()
            and not first._descending
            and absf(first.global_position.y - first.home.y) <= first.bob_amplitude + 0.1
        ),
        (
            "the saucer descends to its place (y %.0f, home %.0f)"
            % [first.global_position.y, first.home.y]
        )
    )
    # endregion

    # region Darts come around
    var dart: Dart = darts[0]
    dart.entry_delay = 0.0
    await _wait(0.1)
    _check(dart.has_arrived() and dart.visible, "the dart enters when its wave comes")
    var wrapped := false
    var last_y := dart.global_position.y
    for i in range(120):
        await _wait(0.05)
        if dart.global_position.y < last_y - 500.0:
            wrapped = true
            break
        last_y = dart.global_position.y
    _check(wrapped, "the dart comes around from the top after leaving the bottom")
    _check(dart.max_energy < first.max_energy, "the dart has less energy than the saucer")
    # endregion

    # region Pickups
    _controller.head_appeared.emit(0, Vector2(960, 950))
    await _wait(0.1)
    var ship := _ship()
    ship.boost_duration = 1.5

    ship.take_damage(5)
    ship._invulnerable_left = 0.0
    var damaged := ship.health
    Pickup.drop(ship, ship.global_position - Vector2(0, 120), Pickup.Kind.SHIELD)
    await _wait(1.2)
    _check(
        ship.health == mini(ship.max_health, damaged + ship.shield_recharge),
        "the shield pickup recharges the ring (%d -> %d)" % [damaged, ship.health]
    )
    _check(_of_type("Pickup").is_empty(), "the pickup is gone once collected")

    Pickup.drop(ship, ship.global_position, Pickup.Kind.SPREAD_SHOT)
    await _wait(0.3)
    _check(ship.has_boost(Pickup.Kind.SPREAD_SHOT), "the spread shot is armed")
    var directions := {}
    for bullet in _of_type("Bullet"):
        directions[snappedf((bullet as Bullet).direction.x, 0.01)] = true
    _check(
        directions.size() == 3, "the spread shot fires a fan of three (%s)" % str(directions.keys())
    )

    await _wait(1.5)
    _check(not ship.has_boost(Pickup.Kind.SPREAD_SHOT), "the weapon pickup wears off")

    Pickup.drop(ship, ship.global_position, Pickup.Kind.RAPID_FIRE)
    await _wait(0.2)
    var shots_before := ship._fire_cooldown
    _check(ship.has_boost(Pickup.Kind.RAPID_FIRE), "the rapid fire is armed")
    var fast := _of_type("Bullet").filter(func(b): return b.speed > 1800.0)
    _check(not fast.is_empty(), "the rapid fire shoots faster bullets")

    ship.boost_duration = 5.0
    # NOTE: Park the ship in the bottom-right corner, away from every enemy's
    # column, so that only the homing rockets can do damage.
    _controller.head_moved.emit(0, Vector2(1880, 1050))
    await _wait(0.2)
    var arrived := _enemies().filter(func(e): return e.has_arrived())
    var total_before := 0
    for e in arrived:
        total_before += e.energy
    var hits := [0]
    for e in arrived:
        e.set_physics_process(false)
    var scene_missile: PackedScene = load("res://scenes/missile/missile.tscn")
    var missile: Missile = scene_missile.instantiate()
    missile.direction = Vector2.UP
    # NOTE: The rocket homes in on whichever enemy is nearest along the way,
    # so we check that it hit some enemy, which a straight shot up would miss.
    var energies := {}
    for e in arrived:
        energies[e] = e.energy
    var projectiles: Projectiles = _level().get_node("Projectiles")
    projectiles.launch(missile, Vector2(100, 1000))
    await _wait(2.5)
    var lost := 0
    for e in energies:
        lost += energies[e] - (e.energy if is_instance_valid(e) else 0)
    _check(lost > 0, "a homing rocket curves into an enemy (energy lost %d)" % lost)

    Pickup.drop(ship, ship.global_position, Pickup.Kind.ROCKETS)
    await _wait(0.1)
    _check(ship.has_boost(Pickup.Kind.ROCKETS), "the rockets are armed")
    await _wait(0.7)
    _check(not _of_type("Missile").is_empty(), "the ship launches homing rockets")
    for e in arrived:
        if is_instance_valid(e):
            e.set_physics_process(true)
    # endregion

    # region Defeated enemies drop pickups
    var dropper: Saucer = saucers[1]
    if not is_instance_valid(dropper):
        dropper = saucers.filter(func(e): return is_instance_valid(e))[0]
    await _wait(1.0)
    dropper.drop_chance = 1.0
    var pickups_before := _of_type("Pickup").size()
    dropper.take_damage(100)
    await _wait(0.05)
    _check(
        _of_type("Pickup").size() == pickups_before + 1, "a defeated enemy leaves a pickup behind"
    )
    # endregion

    # region Supply drops
    _level().get_node("SupplyDrops")._cooldown = 0.0
    await _wait(0.1)
    var supplies := _of_type("Pickup").filter(func(p): return p.global_position.y < 100.0)
    _check(not supplies.is_empty(), "the supply drops come from the top")
    # endregion

    # region Repair clears the weapons
    _game._fleet.repair()
    _check(
        ship._boosts.is_empty() and ship.health == ship.max_health,
        "a new level starts without the weapons"
    )
    # endregion

    print("RESULT: %s" % ("OK" if _failures.is_empty() else "FAILED %s" % str(_failures)))
    quit(0 if _failures.is_empty() else 1)
