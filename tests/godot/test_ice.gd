extends SceneTree
## Test the arctic sea of the seventh level: the level itself, and each of its
## creatures and the giant walrus in their own test levels, played by
## the scripted players, headless.
##
## Run it directly:
##   godot --headless --fixed-fps 60 --path . --script tests/godot/test_ice.gd

const _TESTS: String = "res://scenes/tests/levels"
const _SEVENTH: String = "res://scenes/levels/seventh/seventh.tscn"

## How many times we play the giant walrus, so that the players beat it
## reliably, not by chance.
const _WALRUS_ROUNDS: int = 3

var _failures: Array[String] = []


class Metrics:
    var messages := []
    var kinds_seen := {}
    var looks_seen := {}
    var penguin_slides := 0
    var flakes_thrown := 0
    var flakes_caught := 0
    var snowballs_rolled := 0
    var biggest_snowball := 0.0
    var orca_leaps := 0
    var orca_airborne := 0
    var iceberg_calved := 0
    var iceberg_shrank := false
    var walrus_claps := 0
    var walrus_flops := 0
    var walls_raised := 0
    var wall_hit := false
    var walrus_lost_energy := false
    var walls_followed_walrus := false
    var min_health := 1000


func _check(condition: bool, message: String) -> void:
    print(("PASS " if condition else "FAIL ") + message)
    if not condition:
        _failures.append(message)


func _initialize() -> void:
    _run.call_deferred()


func _play_case(title: String, level_path: String, players_path: String, seconds: float) -> Metrics:
    print("--- ", title)
    var players: HeadController = (load(players_path) as GDScript).new()
    var game: Game = load("res://scenes/game/game.tscn").instantiate()
    game.own_head_controllers([players])
    game.level_scene_paths = [level_path]
    root.add_child(game)

    var m := Metrics.new()
    var elapsed := 0.0
    while elapsed < seconds:
        await create_timer(0.05).timeout
        elapsed += 0.05

        for child in game.get_children():
            if child is FinalMessage and not child.is_queued_for_deletion():
                var message_title: String = child.title.text
                if m.messages.is_empty() or m.messages[-1] != message_title:
                    m.messages.append(message_title)
        if game.get_tree().paused:
            continue
        if not m.messages.is_empty():
            # NOTE: The level is accomplished; we skip the next round.
            continue

        var level := game.get_node("Screen").get_child(0)
        for key in game._fleet._spaceships:
            m.min_health = mini(m.min_health, game._fleet._spaceships[key].health)

        for child in level.get_node("Enemies").get_children():
            if not (child is Enemy) or child.is_queued_for_deletion():
                continue
            if child.has_arrived():
                m.kinds_seen[child.get_script().get_global_name()] = true
            if child is Penguin:
                m.penguin_slides = maxi(m.penguin_slides, child.slides)
            if child is SnowyOwl:
                m.flakes_thrown = maxi(m.flakes_thrown, child.flakes_thrown)
                m.flakes_caught = maxi(m.flakes_caught, child.flakes_caught)
            if child is PolarBear:
                m.snowballs_rolled = maxi(m.snowballs_rolled, child.snowballs_rolled)
                m.biggest_snowball = maxf(m.biggest_snowball, child.biggest_snowball)
            if child is Orca:
                m.orca_leaps = maxi(m.orca_leaps, child.leaps)
                m.orca_airborne = maxi(m.orca_airborne, child.airborne_seen)
            if child is Iceberg:
                m.iceberg_calved = maxi(m.iceberg_calved, child.calved)
                if child.is_alive() and child.size() < 1.0:
                    m.iceberg_shrank = true
            if child is IceWall:
                if child.is_alive() and child.energy < child.max_energy:
                    m.wall_hit = true
            if child is GiantWalrus:
                m.walrus_claps = maxi(m.walrus_claps, child.claps())
                m.walrus_flops = maxi(m.walrus_flops, child.flops())
                m.walls_raised = maxi(m.walls_raised, child.walls_raised())
                if child.energy < child.max_energy:
                    m.walrus_lost_energy = true
                if child.is_fleeing() and child.minions().is_empty():
                    m.walls_followed_walrus = true

        for child in level.get_node("Projectiles").get_children():
            var rocket := child as Rocket
            if rocket != null:
                m.looks_seen[rocket.look] = true

    game.queue_free()
    # NOTE: The game may be freed in the middle of a message, i.e., paused.
    paused = false
    await create_timer(0.2).timeout
    return m


func _check_seventh_level() -> void:
    print("--- seventh level")
    var level: Node = (load(_SEVENTH) as PackedScene).instantiate()
    _check(level.name == "Seventh", "seventh: the level is called Seventh (%s)" % level.name)
    var chests: ChestDrops = level.get_node("ChestDrops")
    _check(chests.enabled, "seventh: the treasure chests are enabled")
    _check(
        not chests.styles.is_empty() and not chests.styles.has(Chest.Style.WOODEN),
        "seventh: the chests come in icy styles (%s)" % str(chests.styles)
    )

    var material := (level.get_node("Stars") as ColorRect).material as ShaderMaterial
    _check(
        material != null and material.shader.resource_path.ends_with("arctic.gdshader"),
        "seventh: the background is the arctic sea"
    )
    # NOTE: The headless renderer knows no shader defaults, so we read the code.
    var scroll := RegEx.create_from_string("uniform float scroll_speed = ([0-9.]+);")
    var found := scroll.search(material.shader.code)
    var scroll_speed := float(found.get_string(1)) if found != null else -1.0

    var waiting: Array[String] = []
    var waves := {}
    for child in level.get_node("Enemies").get_children():
        var enemy := child as Enemy
        if enemy == null:
            continue
        if enemy.waits_for_others:
            waiting.append(enemy.get_script().get_global_name())
            _check(
                is_equal_approx(enemy.entry_delay, 2.0),
                "seventh: the boss enters 2 s after the others (%.1f)" % enemy.entry_delay
            )
        else:
            var wave := enemy.name.substr(0, 5)
            waves[wave] = waves.get(wave, 0) + 1
        if enemy is GroundEnemy:
            _check(
                is_equal_approx(enemy.ground_speed, scroll_speed),
                (
                    "seventh: %s slides with the ice (%.1f vs. %.1f)"
                    % [enemy.name, enemy.ground_speed, scroll_speed]
                )
            )
        if enemy is GiantWalrus:
            _check(
                is_equal_approx(enemy.ground_speed, scroll_speed),
                "seventh: the ice walls of the walrus slide with the ice"
            )
    _check(
        waiting == ["GiantWalrus"],
        "seventh: the giant walrus is the only one to wait for the others (%s)" % str(waiting)
    )
    _check(
        waves.size() >= 4 and waves.size() <= 5,
        "seventh: four or five waves (%s)" % str(waves.keys())
    )
    var crowded := waves.values().filter(func(count): return count > 2)
    _check(crowded.is_empty(), "seventh: at most two enemies per wave (%s)" % str(waves))
    level.free()


func _run() -> void:
    _check_seventh_level()

    var m: Metrics

    m = await _play_case(
        "penguin and snowy owl",
        _TESTS + "/test_penguin_owl/test_penguin_owl.tscn",
        _TESTS + "/test_penguin_owl/test_penguin_owl_players.gd",
        70.0
    )
    _check(m.penguin_slides >= 2, "penguin: it toboggans around (%d)" % m.penguin_slides)
    _check(
        m.looks_seen.has(Rocket.Look.SNOWBALL),
        "penguin: it throws the snowballs (%s)" % str(m.looks_seen.keys())
    )
    _check(m.flakes_thrown >= 2, "snowy owl: it throws the snowflakes (%d)" % m.flakes_thrown)
    _check(
        m.flakes_caught >= 1,
        "snowy owl: the snowflakes fly back and it catches them (%d)" % m.flakes_caught
    )
    _check(
        m.looks_seen.has(Rocket.Look.SNOWFLAKE),
        "snowy owl: the snowflakes fly (%s)" % str(m.looks_seen.keys())
    )
    _check(
        m.messages.has("You did it!"),
        "penguin and snowy owl: the player chases them away (%s)" % str(m.messages)
    )

    m = await _play_case(
        "polar bear and orca",
        _TESTS + "/test_bear_orca/test_bear_orca.tscn",
        _TESTS + "/test_bear_orca/test_bear_orca_players.gd",
        85.0
    )
    _check(m.snowballs_rolled >= 1, "polar bear: it rolls the snowballs (%d)" % m.snowballs_rolled)
    _check(
        m.biggest_snowball >= 1.5,
        "polar bear: the snowballs grow as they roll (x%.2f)" % m.biggest_snowball
    )
    _check(m.orca_leaps >= 1, "orca: it leaps (%d)" % m.orca_leaps)
    _check(m.orca_airborne >= 1, "orca: it is up in the air (%d)" % m.orca_airborne)
    _check(
        m.looks_seen.has(Rocket.Look.BUBBLE),
        "orca: it splashes the water drops (%s)" % str(m.looks_seen.keys())
    )
    _check(
        m.messages.has("You did it!"),
        "polar bear and orca: the player chases them away (%s)" % str(m.messages)
    )

    m = await _play_case(
        "iceberg",
        _TESTS + "/test_iceberg/test_iceberg.tscn",
        _TESTS + "/test_iceberg/test_iceberg_players.gd",
        80.0
    )
    _check(
        m.looks_seen.has(Rocket.Look.ICICLE),
        "iceberg: it fires the icicles (%s)" % str(m.looks_seen.keys())
    )
    _check(m.iceberg_shrank, "iceberg: it shrinks as it is hit")
    _check(m.iceberg_calved == 2, "iceberg: two ice cubes break off (%d)" % m.iceberg_calved)
    _check(m.kinds_seen.has("IceCube"), "iceberg: the ice cubes come out")
    _check(
        m.messages.has("You did it!"),
        "iceberg: the player chases it and its ice cubes away (%s)" % str(m.messages)
    )

    for round in range(_WALRUS_ROUNDS):
        m = await _play_case(
            "giant walrus, round %d" % (round + 1),
            _TESTS + "/test_giant_walrus/test_giant_walrus.tscn",
            _TESTS + "/test_giant_walrus/test_giant_walrus_players.gd",
            120.0
        )
        _check(m.walrus_claps >= 1, "giant walrus: it claps the snowballs (%d)" % m.walrus_claps)
        _check(m.walrus_flops >= 1, "giant walrus: it belly-flops (%d)" % m.walrus_flops)
        _check(m.walls_raised >= 3, "giant walrus: it raises the ice walls (%d)" % m.walls_raised)
        _check(m.wall_hit, "giant walrus: the bullets bump into the ice walls")
        _check(
            m.looks_seen.has(Rocket.Look.ICICLE) and m.looks_seen.has(Rocket.Look.SNOWBALL),
            "giant walrus: the snowballs and the ice chunks fly (%s)" % str(m.looks_seen.keys())
        )
        _check(m.walrus_lost_energy, "giant walrus: the players hit it")
        _check(m.walls_followed_walrus, "giant walrus: the ice walls go away with it")
        _check(
            m.messages.has("You did it!"),
            (
                "giant walrus: the players chase it away (%s, lowest health %d)"
                % [str(m.messages), m.min_health]
            )
        )

    print("RESULT: %s" % ("OK" if _failures.is_empty() else "FAILED %s" % str(_failures)))
    quit(0 if _failures.is_empty() else 1)
