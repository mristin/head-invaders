extends SceneTree
## Test the desert of the sixth level: the level itself, and each of its
## creatures and the great scarab in its own test level, played by the scripted
## players, headless.
##
## Run it directly:
##   godot --headless --fixed-fps 60 --path . --script tests/godot/test_desert.gd

const _TESTS: String = "res://scenes/tests/levels"
const _SIXTH: String = "res://scenes/levels/sixth/sixth.tscn"

var _failures: Array[String] = []


class Metrics:
    var messages := []
    var kinds_seen := {}
    var looks_seen := {}
    var rings_puffed := 0
    var needles_aimed := 0
    var twisters_spun := 0
    var twister_sides := {}
    var worm_pops := 0
    var worm_burrowed_seen := false
    var worm_hit_while_burrowed := false
    var mirages_cast := 0
    var mirage_seen := false
    var ball_bounced := 0
    var ball_rolls := 0
    var ball_followed_scarab := false
    var scarab_lost_energy := false
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
    var worm_energy := {}
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
            if child is Cactus:
                m.rings_puffed = maxi(m.rings_puffed, child.rings_puffed)
                m.needles_aimed = maxi(m.needles_aimed, child.needles_aimed)
            if child is Djinn:
                m.twisters_spun = maxi(m.twisters_spun, child.twisters_spun)
            if child is SandWorm:
                m.worm_pops = maxi(m.worm_pops, child.pops)
                # NOTE: We compare the energy between two samples in the sand.
                var burrowed: bool = (
                    child.has_arrived() and child.is_alive() and child.is_burrowed()
                )
                if burrowed:
                    m.worm_burrowed_seen = true
                    if worm_energy.has(child) and worm_energy[child] != child.energy:
                        m.worm_hit_while_burrowed = true
                    worm_energy[child] = child.energy
                else:
                    worm_energy.erase(child)
            if child is MirageFox:
                m.mirages_cast = maxi(m.mirages_cast, child.mirages_cast)
                if child.has_mirage():
                    m.mirage_seen = true
            if child is GreatScarab:
                if child.energy < child.max_energy:
                    m.scarab_lost_energy = true
                var ball: SunBall = child.sun_ball()
                if ball != null:
                    m.ball_bounced = maxi(m.ball_bounced, ball.bounced_hits)
                    m.ball_rolls = maxi(m.ball_rolls, ball.rolls)
                if child.is_fleeing() and child.minions().is_empty():
                    m.ball_followed_scarab = true

        for child in level.get_node("Projectiles").get_children():
            var rocket := child as Rocket
            if rocket == null:
                continue
            m.looks_seen[rocket.look] = true
            if rocket.look == Rocket.Look.TWISTER and rocket.velocity.length() > 0.0:
                m.twister_sides[signf(rocket.velocity.x)] = true

    game.queue_free()
    # NOTE: The game may be freed in the middle of a message, i.e., paused.
    paused = false
    await create_timer(0.2).timeout
    return m


func _check_sixth_level() -> void:
    print("--- sixth level")
    var level: Node = (load(_SIXTH) as PackedScene).instantiate()
    _check(level.name == "Sixth", "sixth: the level is called Sixth (%s)" % level.name)
    _check(level.get_node("ChestDrops").enabled, "sixth: the treasure chests are enabled")

    var material := (level.get_node("Stars") as ColorRect).material as ShaderMaterial
    _check(
        material != null and material.shader.resource_path.ends_with("desert.gdshader"),
        "sixth: the background is the desert"
    )
    # NOTE: The headless renderer knows no shader defaults, so we read the code.
    var scroll := RegEx.create_from_string("uniform float scroll_speed = ([0-9.]+);")
    var found := scroll.search(material.shader.code)
    var scroll_speed := float(found.get_string(1)) if found != null else -1.0

    var waiting: Array[String] = []
    var waves := {}
    var enemies := 0
    for child in level.get_node("Enemies").get_children():
        var enemy := child as Enemy
        if enemy == null:
            continue
        enemies += 1
        if enemy.waits_for_others:
            waiting.append(enemy.get_script().get_global_name())
            _check(
                is_equal_approx(enemy.entry_delay, 2.0),
                "sixth: the boss enters 2 s after the others (%.1f)" % enemy.entry_delay
            )
        else:
            var wave := enemy.name.substr(0, 5)
            waves[wave] = waves.get(wave, 0) + 1
        if enemy is GroundEnemy:
            _check(
                is_equal_approx(enemy.ground_speed, scroll_speed),
                (
                    "sixth: %s slides with the sand (%.1f vs. %.1f)"
                    % [enemy.name, enemy.ground_speed, scroll_speed]
                )
            )
    _check(
        waiting == ["GreatScarab"],
        "sixth: the great scarab is the only one to wait for the others (%s)" % str(waiting)
    )
    _check(
        waves.size() >= 4 and waves.size() <= 5,
        "sixth: four or five waves (%s)" % str(waves.keys())
    )
    var crowded := waves.values().filter(func(count): return count > 2)
    _check(crowded.is_empty(), "sixth: at most two enemies per wave (%s)" % str(waves))
    level.free()


func _run() -> void:
    _check_sixth_level()

    var m: Metrics

    m = await _play_case(
        "cactus and djinn",
        _TESTS + "/test_cactus_djinn/test_cactus_djinn.tscn",
        _TESTS + "/test_cactus_djinn/test_cactus_djinn_players.gd",
        60.0
    )
    _check(m.rings_puffed >= 1, "cactus: it puffs out the ring of needles (%d)" % m.rings_puffed)
    _check(
        m.needles_aimed >= 3,
        "cactus: the hanging needles turn and fly at the player (%d)" % m.needles_aimed
    )
    _check(m.twisters_spun >= 1, "djinn: it spins up the twisters (%d)" % m.twisters_spun)
    _check(
        m.twister_sides.has(1.0) and m.twister_sides.has(-1.0),
        "djinn: the twisters wind from side to side (%s)" % str(m.twister_sides.keys())
    )
    _check(
        m.looks_seen.has(Rocket.Look.NEEDLE) and m.looks_seen.has(Rocket.Look.TWISTER),
        "cactus and djinn: the needles and the twisters fly (%s)" % str(m.looks_seen.keys())
    )
    _check(
        m.messages.has("You did it!"),
        "cactus and djinn: the player chases them away (%s)" % str(m.messages)
    )

    m = await _play_case(
        "sand worm and mirage fox",
        _TESTS + "/test_worm_fox/test_worm_fox.tscn",
        _TESTS + "/test_worm_fox/test_worm_fox_players.gd",
        70.0
    )
    _check(m.worm_burrowed_seen, "sand worm: it burrows under the sand")
    _check(not m.worm_hit_while_burrowed, "sand worm: the bullets can not reach it in the sand")
    _check(m.worm_pops >= 2, "sand worm: it pops up again and again (%d)" % m.worm_pops)
    _check(
        m.mirages_cast >= 1 and m.mirage_seen,
        "mirage fox: it casts its mirage (%d)" % m.mirages_cast
    )
    _check(
        m.looks_seen.has(Rocket.Look.SAND),
        "sand worm and mirage fox: the sand balls fly (%s)" % str(m.looks_seen.keys())
    )
    _check(
        m.messages.has("You did it!"),
        "sand worm and mirage fox: the player chases them away (%s)" % str(m.messages)
    )

    m = await _play_case(
        "great scarab",
        _TESTS + "/test_great_scarab/test_great_scarab.tscn",
        _TESTS + "/test_great_scarab/test_great_scarab_players.gd",
        110.0
    )
    _check(
        m.ball_bounced > 0,
        "great scarab: the bullets bounce off the sun ball (%d)" % m.ball_bounced
    )
    _check(m.ball_rolls >= 1, "great scarab: it rolls the sun ball (%d)" % m.ball_rolls)
    _check(m.scarab_lost_energy, "great scarab: the players get around the sun ball")
    _check(m.ball_followed_scarab, "great scarab: the sun ball follows it home")
    _check(
        m.messages.has("You did it!"),
        "great scarab: the players chase it away (%s)" % str(m.messages)
    )

    print("RESULT: %s" % ("OK" if _failures.is_empty() else "FAILED %s" % str(_failures)))
    quit(0 if _failures.is_empty() else 1)
