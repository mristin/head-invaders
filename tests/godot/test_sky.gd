extends SceneTree
## Test the sky kingdom of the eighth level: the level itself, and each of its
## creatures and the grumpy storm cloud in its own test level, played by
## the scripted players, headless.
##
## Run it directly:
##   godot --headless --fixed-fps 60 --path . --script tests/godot/test_sky.gd

const _TESTS: String = "res://scenes/tests/levels"
const _EIGHTH: String = "res://scenes/levels/eighth/eighth.tscn"

## How many times we play the storm cloud, so that the players beat it
## reliably, not by chance.
const _BOSS_RUNS: int = 3

var _failures: Array[String] = []


class Metrics:
    var messages := []
    var kinds_seen := {}
    var looks_seen := {}
    var fans_shaken := 0
    var kite_swings := 0
    var sandbags_dropped := 0
    var highest_hop := 0.0
    var falling_sandbag_sped_up := false
    var showers := 0
    var darts_thrown := 0
    var darts_caught := 0
    var loops := 0
    var lanes_warned := 0
    var strikes := 0
    var lightning_hits := 0
    var gusts := 0
    var fastest_pushed_drop := 0.0
    var sneezed := false
    var little_clouds_seen := false
    var cloud_lost_energy := false
    var little_clouds_followed := false
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
    var sandbag_speeds := {}
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
            break

        var level := game.get_node("Screen").get_child(0)
        for key in game._fleet._spaceships:
            m.min_health = mini(m.min_health, game._fleet._spaceships[key].health)

        for child in level.get_node("Enemies").get_children():
            if not (child is Enemy) or child.is_queued_for_deletion():
                continue
            if child.has_arrived():
                m.kinds_seen[child.get_script().get_global_name()] = true
            if child is Kite:
                m.fans_shaken = maxi(m.fans_shaken, child.fans_shaken)
                m.kite_swings = maxi(m.kite_swings, child.swings)
            if child is HotAirBalloon:
                m.sandbags_dropped = maxi(m.sandbags_dropped, child.sandbags_dropped)
                m.highest_hop = maxf(m.highest_hop, child.highest_hop)
            if child is RainCloud:
                m.showers = maxi(m.showers, child.showers)
                if child.spawned_in_place and child.has_arrived():
                    m.little_clouds_seen = true
            if child is PaperPlane:
                m.darts_thrown = maxi(m.darts_thrown, child.darts_thrown)
                m.darts_caught = maxi(m.darts_caught, child.darts_caught)
                m.loops = maxi(m.loops, child.loops)
            if child is StormCloud:
                m.lanes_warned = maxi(m.lanes_warned, child.lanes_warned)
                m.strikes = maxi(m.strikes, child.strikes)
                m.lightning_hits = maxi(m.lightning_hits, child.lightning_hits)
                m.gusts = maxi(m.gusts, child.gusts)
                m.fastest_pushed_drop = maxf(m.fastest_pushed_drop, child.fastest_pushed_drop)
                if child.sneezed:
                    m.sneezed = true
                if child.energy < child.max_energy:
                    m.cloud_lost_energy = true
                if child.is_fleeing() and child.sneezed and child.minions().is_empty():
                    m.little_clouds_followed = true

        for child in level.get_node("Projectiles").get_children():
            var rocket := child as Rocket
            if rocket == null:
                continue
            m.looks_seen[rocket.look] = true
            if rocket.look == Rocket.Look.SANDBAG:
                var speed := rocket.velocity.length()
                if sandbag_speeds.has(rocket) and speed > sandbag_speeds[rocket] + 1.0:
                    m.falling_sandbag_sped_up = true
                sandbag_speeds[rocket] = speed

    game.queue_free()
    # NOTE: The game may be freed in the middle of a message, i.e., paused.
    paused = false
    await create_timer(0.2).timeout
    return m


func _check_eighth_level() -> void:
    print("--- eighth level")
    var level: Node = (load(_EIGHTH) as PackedScene).instantiate()
    _check(level.name == "Eighth", "eighth: the level is called Eighth (%s)" % level.name)
    var chests: ChestDrops = level.get_node("ChestDrops")
    _check(chests.enabled, "eighth: the treasure chests are enabled")

    var material := (level.get_node("Stars") as ColorRect).material as ShaderMaterial
    _check(
        material != null and material.shader.resource_path.ends_with("sky.gdshader"),
        "eighth: the background is the sky kingdom"
    )
    # NOTE: The headless renderer knows no shader defaults, so we read the code.
    var scroll := RegEx.create_from_string("uniform float scroll_speed = ([0-9.]+);")
    var found := scroll.search(material.shader.code)
    var scroll_speed := float(found.get_string(1)) if found != null else -1.0

    var waiting: Array[String] = []
    var waves := {}
    var kinds := {}
    for child in level.get_node("Enemies").get_children():
        var enemy := child as Enemy
        if enemy == null:
            continue
        kinds[enemy.get_script().get_global_name()] = true
        if enemy.waits_for_others:
            waiting.append(enemy.get_script().get_global_name())
            _check(
                is_equal_approx(enemy.entry_delay, 2.0),
                "eighth: the boss enters 2 s after the others (%.1f)" % enemy.entry_delay
            )
        else:
            var wave := enemy.name.substr(0, 5)
            waves[wave] = waves.get(wave, 0) + 1
        if enemy is GroundEnemy:
            _check(
                is_equal_approx(enemy.ground_speed, scroll_speed),
                (
                    "eighth: %s slides with the clouds (%.1f vs. %.1f)"
                    % [enemy.name, enemy.ground_speed, scroll_speed]
                )
            )
    _check(
        waiting == ["StormCloud"],
        "eighth: the storm cloud is the only one to wait for the others (%s)" % str(waiting)
    )
    for kind in ["Kite", "HotAirBalloon", "RainCloud", "PaperPlane"]:
        _check(kinds.has(kind), "eighth: the %s comes in the level" % kind)
    _check(
        waves.size() >= 4 and waves.size() <= 5,
        "eighth: four or five waves (%s)" % str(waves.keys())
    )
    var crowded := waves.values().filter(func(count): return count > 2)
    _check(crowded.is_empty(), "eighth: at most two enemies per wave (%s)" % str(waves))
    level.free()


func _run() -> void:
    _check_eighth_level()

    var m: Metrics

    m = await _play_case(
        "kite and hot-air balloon",
        _TESTS + "/test_kite_balloon/test_kite_balloon.tscn",
        _TESTS + "/test_kite_balloon/test_kite_balloon_players.gd",
        70.0
    )
    _check(m.kite_swings >= 2, "kite: it swings to and fro on its string (%d)" % m.kite_swings)
    _check(m.fans_shaken >= 1, "kite: it shakes out the fans of stars (%d)" % m.fans_shaken)
    _check(
        m.sandbags_dropped >= 1, "hot-air balloon: it drops the sandbags (%d)" % m.sandbags_dropped
    )
    _check(m.falling_sandbag_sped_up, "hot-air balloon: the sandbags fall faster and faster")
    _check(m.highest_hop > 50.0, "hot-air balloon: it hops up after a drop (%.0f)" % m.highest_hop)
    _check(
        m.looks_seen.has(Rocket.Look.ZAP) and m.looks_seen.has(Rocket.Look.SANDBAG),
        "kite and hot-air balloon: the stars and the sandbags fly (%s)" % str(m.looks_seen.keys())
    )
    _check(
        m.messages.has("You did it!"),
        "kite and hot-air balloon: the player chases them away (%s)" % str(m.messages)
    )

    m = await _play_case(
        "rain cloud and paper plane",
        _TESTS + "/test_cloud_plane/test_cloud_plane.tscn",
        _TESTS + "/test_cloud_plane/test_cloud_plane_players.gd",
        70.0
    )
    _check(m.showers >= 1, "rain cloud: it rains the showers (%d)" % m.showers)
    _check(m.darts_thrown >= 2, "paper plane: it throws the darts (%d)" % m.darts_thrown)
    _check(
        m.darts_caught >= 1,
        "paper plane: the darts come back like boomerangs (%d)" % m.darts_caught
    )
    _check(m.loops >= 1, "paper plane: it flies a loop-the-loop (%d)" % m.loops)
    _check(
        m.looks_seen.has(Rocket.Look.RAINDROP) and m.looks_seen.has(Rocket.Look.PAPER_DART),
        (
            "rain cloud and paper plane: the raindrops and the darts fly (%s)"
            % str(m.looks_seen.keys())
        )
    )
    _check(
        m.messages.has("You did it!"),
        "rain cloud and paper plane: the player chases them away (%s)" % str(m.messages)
    )

    for run in range(_BOSS_RUNS):
        m = await _play_case(
            "storm cloud, run %d" % (run + 1),
            _TESTS + "/test_storm_cloud/test_storm_cloud.tscn",
            _TESTS + "/test_storm_cloud/test_storm_cloud_players.gd",
            120.0
        )
        _check(
            m.strikes >= 1 and m.lanes_warned >= m.strikes,
            (
                "storm cloud: the lanes glow before the lightning (%d lanes, %d strikes)"
                % [m.lanes_warned, m.strikes]
            )
        )
        _check(
            m.lightning_hits == 0,
            "storm cloud: the players step out of the lanes in time (%d hits)" % m.lightning_hits
        )
        _check(m.gusts >= 1, "storm cloud: it blows the gusts of wind (%d)" % m.gusts)
        _check(
            m.fastest_pushed_drop > 100.0,
            "storm cloud: the wind pushes the raindrops sideways (%.0f)" % m.fastest_pushed_drop
        )
        _check(
            m.sneezed and m.little_clouds_seen,
            "storm cloud: it sneezes out the little rain clouds when low on energy"
        )
        _check(m.cloud_lost_energy, "storm cloud: the players hit it")
        _check(m.little_clouds_followed, "storm cloud: the little rain clouds follow it home")
        _check(
            m.messages.has("You did it!"),
            "storm cloud: the players chase it away (%s)" % str(m.messages)
        )

    print("RESULT: %s" % ("OK" if _failures.is_empty() else "FAILED %s" % str(_failures)))
    quit(0 if _failures.is_empty() else 1)
