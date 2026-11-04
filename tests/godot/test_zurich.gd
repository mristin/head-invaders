extends SceneTree
## Play the test levels of the city of Zurich with their scripted players,
## headless, and check that each new enemy and the banker show their behavior
## and can be chased away. Check the tenth level itself as well.
##
## Run it directly:
##   godot --headless --fixed-fps 60 --path . --script tests/godot/test_zurich.gd

const _TESTS: String = "res://scenes/tests/levels"

var _failures: Array[String] = []


class Metrics:
    var messages := []
    var looks_seen := {}
    var kinds_seen := {}
    var swan_flew := false
    var swimmer_on_river := false
    var pigeon_mirrored := false
    var tram_stops := 0
    var tram_danced := 0
    var hipster_swoops := 0
    var punk_loops := 0
    var banker_flyovers := 0
    var banker_dives := 0
    var banker_aimed := false
    var coin_bounces := 0


func _check(condition: bool, message: String) -> void:
    print(("PASS " if condition else "FAIL ") + message)
    if not condition:
        _failures.append(message)


func _initialize() -> void:
    _run.call_deferred()


func _play_case(title: String, name: String, seconds: float) -> Metrics:
    print("--- ", title)
    var level_path := "%s/test_%s/test_%s.tscn" % [_TESTS, name, name]
    var players_path := "%s/test_%s/test_%s_players.gd" % [_TESTS, name, name]
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
        if m.messages.has("You did it!"):
            break
        if game.get_tree().paused:
            continue

        var level := game.get_node("Screen").get_child(0)
        var ship: Spaceship = null
        for key in game._fleet._spaceships:
            ship = game._fleet._spaceships[key]
            break

        for child in level.get_node("Enemies").get_children():
            var enemy := child as Enemy
            if enemy == null or enemy.is_queued_for_deletion() or not enemy.has_arrived():
                continue
            m.kinds_seen[enemy.get_script().get_global_name()] = true
            if not enemy.is_alive():
                continue
            if enemy is Swan and enemy.is_flying():
                m.swan_flew = true
            if enemy is LimmatSwimmer:
                var river: float = enemy.river_x()
                if (
                    not is_nan(river)
                    and absf(enemy.global_position.x - river) < 30.0
                    and absf(river - 960.0) > 10.0
                ):
                    m.swimmer_on_river = true
            if enemy is Pigeon and ship != null and absf(ship.global_position.x - 960.0) > 400.0:
                var mirrored := 1920.0 - ship.global_position.x
                if absf(enemy.global_position.x - mirrored) < 60.0:
                    m.pigeon_mirrored = true
            if enemy is Tram:
                m.tram_stops = maxi(m.tram_stops, enemy.stops())
                m.tram_danced = maxi(m.tram_danced, enemy.danced_sparks())
            if enemy is ScooterHipster:
                m.hipster_swoops = maxi(m.hipster_swoops, enemy.swoops())
            if enemy is Punk:
                m.punk_loops = maxi(m.punk_loops, enemy.loops())
            if enemy is Banker:
                m.banker_flyovers = maxi(m.banker_flyovers, enemy.flyovers())
                m.banker_dives = maxi(m.banker_dives, enemy.dives())
                m.coin_bounces = maxi(m.coin_bounces, enemy.coin_bounces())
                m.banker_aimed = m.banker_aimed or enemy.is_aiming()

        for child in level.get_node("Projectiles").get_children():
            if child is Rocket:
                m.looks_seen[child.look] = true

    game.queue_free()
    # NOTE: The game may be freed in the middle of a message, i.e., paused.
    paused = false
    await create_timer(0.2).timeout
    return m


func _check_tenth_level() -> void:
    print("--- tenth level")
    # NOTE: We inspect the enemies before the level starts, i.e., before their
    # entry delays count down.
    var level: Node = load("res://scenes/levels/tenth/tenth.tscn").instantiate()

    _check(level.name == "Tenth", "tenth: the level is called Tenth (%s)" % level.name)
    var map := level.get_node_or_null("ZurichMap") as ZurichMap
    _check(map != null, "tenth: the map of Zurich is there")
    _check(not (level.get_node("Stars") as CanvasItem).visible, "tenth: the stars are hidden")
    _check((level.get_node("ChestDrops") as ChestDrops).enabled, "tenth: the chests are enabled")

    var waiting: Array[String] = []
    var kinds := {}
    var waves := {}
    for child in level.get_node("Enemies").get_children():
        var enemy := child as Enemy
        if enemy == null:
            continue
        kinds[enemy.get_script().get_global_name()] = true
        if enemy.waits_for_others:
            waiting.append(enemy.get_script().get_global_name())
        else:
            var wave := floori(enemy.entry_delay / 14.0)
            waves[wave] = waves.get(wave, 0) + 1
        if enemy is GroundEnemy and map != null:
            _check(
                is_equal_approx(enemy.ground_speed, map.scroll_speed),
                (
                    "tenth: %s slides with the map (%.1f vs %.1f)"
                    % [enemy.name, enemy.ground_speed, map.scroll_speed]
                )
            )
    _check(waiting == ["Banker"], "tenth: only the banker waits for the others (%s)" % waiting)
    var boss := level.get_node("Enemies/Banker") as Enemy
    _check(
        boss != null and is_equal_approx(boss.entry_delay, 2.0),
        "tenth: the banker comes 2 s after the others"
    )
    var crowded := waves.values().filter(func(count: int) -> bool: return count > 2)
    _check(
        waves.size() >= 4 and crowded.is_empty(),
        "tenth: 4 to 5 waves of at most 2 enemies (%s)" % str(waves)
    )
    for kind in ["Swan", "LimmatSwimmer", "Pigeon", "Tram", "ScooterHipster", "Punk"]:
        _check(kinds.has(kind), "tenth: the %s comes" % kind)

    root.add_child(level)
    await create_timer(0.5).timeout
    _check(
        map != null and map.distance > 0.0 and map.get_node("Ground").get_child_count() > 0,
        "tenth: the map slides and draws its chunks"
    )
    level.queue_free()
    await create_timer(0.1).timeout


func _run() -> void:
    await _check_tenth_level()

    var m: Metrics

    m = await _play_case("swan and swimmer", "swan_swimmer", 70.0)
    _check(m.swan_flew, "swan and swimmer: the swan takes off")
    _check(m.swimmer_on_river, "swan and swimmer: the swimmer floats on the Limmat")
    _check(
        m.looks_seen.has(Rocket.Look.BUBBLE),
        "swan and swimmer: the water drops fly (%s)" % str(m.looks_seen.keys())
    )
    _check(
        m.messages.has("You did it!"),
        "swan and swimmer: the player chases them away (%s)" % str(m.messages)
    )

    m = await _play_case("pigeon and tram", "pigeon_tram", 75.0)
    _check(m.pigeon_mirrored, "pigeon and tram: the pigeon mirrors the player")
    _check(m.tram_stops > 0, "pigeon and tram: the tram stops (%d)" % m.tram_stops)
    _check(m.tram_danced > 0, "pigeon and tram: the sparks dance (%d)" % m.tram_danced)
    _check(
        m.looks_seen.has(Rocket.Look.PEARL) and m.looks_seen.has(Rocket.Look.ZAP),
        "pigeon and tram: the crumbs and the sparks fly (%s)" % str(m.looks_seen.keys())
    )
    _check(
        m.messages.has("You did it!"),
        "pigeon and tram: the player chases them away (%s)" % str(m.messages)
    )

    m = await _play_case("hipster and punk", "hipster_punk", 75.0)
    _check(m.hipster_swoops > 0, "hipster and punk: the hipster swoops (%d)" % m.hipster_swoops)
    _check(m.punk_loops > 0, "hipster and punk: the punk loops (%d)" % m.punk_loops)
    _check(
        m.looks_seen.has(Rocket.Look.COFFEE_BEAN) and m.looks_seen.has(Rocket.Look.INK),
        "hipster and punk: the beans and the paint fly (%s)" % str(m.looks_seen.keys())
    )
    _check(
        m.messages.has("You did it!"),
        "hipster and punk: the player chases them away (%s)" % str(m.messages)
    )

    m = await _play_case("banker", "banker", 150.0)
    _check(m.banker_flyovers >= 2, "banker: he flies over (%d)" % m.banker_flyovers)
    _check(m.banker_aimed, "banker: he shows where he dives")
    _check(m.banker_dives > 0, "banker: he dives (%d)" % m.banker_dives)
    _check(m.coin_bounces > 0, "banker: his coins bounce (%d)" % m.coin_bounces)
    _check(
        m.looks_seen.has(Rocket.Look.BANKNOTE) and m.looks_seen.has(Rocket.Look.COIN),
        "banker: the banknotes and the coins fly (%s)" % str(m.looks_seen.keys())
    )
    _check(
        m.messages.has("You did it!"), "banker: the players chase him away (%s)" % str(m.messages)
    )

    print("RESULT: %s" % ("OK" if _failures.is_empty() else "FAILED %s" % str(_failures)))
    quit(0 if _failures.is_empty() else 1)
