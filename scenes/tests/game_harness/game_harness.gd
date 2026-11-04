extends Control

## Make a harness for testing the levels in isolation.
##
## Each test comes with the scripted players, so that the test shows its
## behavior on its own. Alternatively, the tester plays it with the mouse or
## the camera.

enum Controller { SCRIPTED, MOUSE, CAMERA }


class TestCase:
    var title: String
    var level_path: String
    var players_path: String

    func _init(case_title: String, level: String, players: String) -> void:
        title = case_title
        level_path = level
        players_path = players


const _TESTS: String = "res://scenes/tests/levels"

var _cases: Array[TestCase] = [
    TestCase.new(
        "First level, a crowd of ten players",
        "res://scenes/levels/first/first.tscn",
        _TESTS + "/test_crowd/test_crowd_players.gd"
    ),
    TestCase.new(
        "Second level, a crowd of ten players",
        "res://scenes/levels/second/second.tscn",
        _TESTS + "/test_crowd/test_crowd_players.gd"
    ),
    TestCase.new(
        "Third level (forest), a crowd of ten players",
        "res://scenes/levels/third/third.tscn",
        _TESTS + "/test_crowd/test_crowd_players.gd"
    ),
    TestCase.new(
        "Fourth level (water), a crowd of ten players",
        "res://scenes/levels/fourth/fourth.tscn",
        _TESTS + "/test_crowd/test_crowd_players.gd"
    ),
    TestCase.new(
        "Fifth level (lava), a crowd of ten players",
        "res://scenes/levels/fifth/fifth.tscn",
        _TESTS + "/test_crowd/test_crowd_players.gd"
    ),
    TestCase.new(
        "Sixth level (desert), a crowd of ten players",
        "res://scenes/levels/sixth/sixth.tscn",
        _TESTS + "/test_crowd/test_crowd_players.gd"
    ),
    TestCase.new(
        "Seventh level (ice), a crowd of ten players",
        "res://scenes/levels/seventh/seventh.tscn",
        _TESTS + "/test_crowd/test_crowd_players.gd"
    ),
    TestCase.new(
        "Eighth level (sky kingdom), a crowd of ten players",
        "res://scenes/levels/eighth/eighth.tscn",
        _TESTS + "/test_crowd/test_crowd_players.gd"
    ),
    TestCase.new(
        "Ninth level (Swiss Alps), a crowd of ten players",
        "res://scenes/levels/ninth/ninth.tscn",
        _TESTS + "/test_crowd/test_crowd_players.gd"
    ),
    TestCase.new(
        "Tenth level (Zurich), a crowd of ten players",
        "res://scenes/levels/tenth/tenth.tscn",
        _TESTS + "/test_crowd/test_crowd_players.gd"
    ),
    TestCase.new(
        "Players: colors, overlaps, leaving and returning",
        _TESTS + "/test_players/test_players.tscn",
        _TESTS + "/test_players/test_players_players.gd"
    ),
    TestCase.new(
        "Saucer: it flees, the level is accomplished",
        _TESTS + "/test_saucer/test_saucer.tscn",
        _TESTS + "/test_saucer/test_saucer_players.gd"
    ),
    TestCase.new(
        "Darts: diving, weaving and coming around",
        _TESTS + "/test_dart/test_dart.tscn",
        _TESTS + "/test_dart/test_dart_players.gd"
    ),
    TestCase.new(
        "Jelly, orbiter and zipper: the new aliens",
        _TESTS + "/test_new_aliens/test_new_aliens.tscn",
        _TESTS + "/test_new_aliens/test_new_aliens_players.gd"
    ),
    TestCase.new(
        "Queen: her fans, her showers, her darts",
        _TESTS + "/test_queen/test_queen.tscn",
        _TESTS + "/test_queen/test_queen_players.gd"
    ),
    TestCase.new(
        "Slime and puffer: splitting, bouncing and puffing",
        _TESTS + "/test_slime_puffer/test_slime_puffer.tscn",
        _TESTS + "/test_slime_puffer/test_slime_puffer_players.gd"
    ),
    TestCase.new(
        "Treasure chests: shoot them open, catch the bubble",
        _TESTS + "/test_chests/test_chests.tscn",
        _TESTS + "/test_chests/test_chests_players.gd"
    ),
    TestCase.new(
        "Mothership: pinwheel, pods, zippers and chests",
        _TESTS + "/test_mothership/test_mothership.tscn",
        _TESTS + "/test_mothership/test_mothership_players.gd"
    ),
    TestCase.new(
        "Forest critters: mushroom and ladybug on the ground",
        _TESTS + "/test_forest_critters/test_forest_critters.tscn",
        _TESTS + "/test_forest_critters/test_forest_critters_players.gd"
    ),
    TestCase.new(
        "Old oak: acorns, spores and mushrooms",
        _TESTS + "/test_old_oak/test_old_oak.tscn",
        _TESTS + "/test_old_oak/test_old_oak_players.gd"
    ),
    TestCase.new(
        "Sea critters: shark, jellyfish and octopus",
        _TESTS + "/test_sea_critters/test_sea_critters.tscn",
        _TESTS + "/test_sea_critters/test_sea_critters_players.gd"
    ),
    TestCase.new(
        "Alligator and giant clam: drifting, snapping, bouncing",
        _TESTS + "/test_gator_clam/test_gator_clam.tscn",
        _TESTS + "/test_gator_clam/test_gator_clam_players.gd"
    ),
    TestCase.new(
        "Sea serpent: winding, diving and splashing",
        _TESTS + "/test_sea_serpent/test_sea_serpent.tscn",
        _TESTS + "/test_sea_serpent/test_sea_serpent_players.gd"
    ),
    TestCase.new(
        "Lava flyers: dragonling and jet dwarf",
        _TESTS + "/test_lava_flyers/test_lava_flyers.tscn",
        _TESTS + "/test_lava_flyers/test_lava_flyers_players.gd"
    ),
    TestCase.new(
        "Lava ground: lizard, snake, golem and volcano",
        _TESTS + "/test_lava_ground/test_lava_ground.tscn",
        _TESTS + "/test_lava_ground/test_lava_ground_players.gd"
    ),
    TestCase.new(
        "Great dragon: fire breath, fireball rain and swoops",
        _TESTS + "/test_great_dragon/test_great_dragon.tscn",
        _TESTS + "/test_great_dragon/test_great_dragon_players.gd"
    ),
    TestCase.new(
        "Cactus and djinn: hanging needles and winding twisters",
        _TESTS + "/test_cactus_djinn/test_cactus_djinn.tscn",
        _TESTS + "/test_cactus_djinn/test_cactus_djinn_players.gd"
    ),
    TestCase.new(
        "Sand worm and mirage fox: burrowing and mirages",
        _TESTS + "/test_worm_fox/test_worm_fox.tscn",
        _TESTS + "/test_worm_fox/test_worm_fox_players.gd"
    ),
    TestCase.new(
        "Great scarab: the sun ball shield and the roll",
        _TESTS + "/test_great_scarab/test_great_scarab.tscn",
        _TESTS + "/test_great_scarab/test_great_scarab_players.gd"
    ),
    TestCase.new(
        "Penguin and snowy owl: zigzag slides and boomerang snowflakes",
        _TESTS + "/test_penguin_owl/test_penguin_owl.tscn",
        _TESTS + "/test_penguin_owl/test_penguin_owl_players.gd"
    ),
    TestCase.new(
        "Polar bear and orca: growing snowballs and the marked leap",
        _TESTS + "/test_bear_orca/test_bear_orca.tscn",
        _TESTS + "/test_bear_orca/test_bear_orca_players.gd"
    ),
    TestCase.new(
        "Iceberg: it shrinks and calves the ice cubes",
        _TESTS + "/test_iceberg/test_iceberg.tscn",
        _TESTS + "/test_iceberg/test_iceberg_players.gd"
    ),
    TestCase.new(
        "Giant walrus: the clap, the belly flop and the ice walls",
        _TESTS + "/test_giant_walrus/test_giant_walrus.tscn",
        _TESTS + "/test_giant_walrus/test_giant_walrus_players.gd"
    ),
    TestCase.new(
        "Kite and hot-air balloon: the swinging kite and the sandbags",
        _TESTS + "/test_kite_balloon/test_kite_balloon.tscn",
        _TESTS + "/test_kite_balloon/test_kite_balloon_players.gd"
    ),
    TestCase.new(
        "Rain cloud and paper plane: the showers and the boomerang darts",
        _TESTS + "/test_cloud_plane/test_cloud_plane.tscn",
        _TESTS + "/test_cloud_plane/test_cloud_plane_players.gd"
    ),
    TestCase.new(
        "Storm cloud: the lightning lanes, the rain and the gusts",
        _TESTS + "/test_storm_cloud/test_storm_cloud.tscn",
        _TESTS + "/test_storm_cloud/test_storm_cloud_players.gd"
    ),
    TestCase.new(
        "Bell cow and marmot: moo rings and peek-a-boo burrows",
        _TESTS + "/test_cow_marmot/test_cow_marmot.tscn",
        _TESTS + "/test_cow_marmot/test_cow_marmot_players.gd"
    ),
    TestCase.new(
        "Gondola and yodeler: the cable car and the echo",
        _TESTS + "/test_gondola_yodeler/test_gondola_yodeler.tscn",
        _TESTS + "/test_gondola_yodeler/test_gondola_yodeler_players.gd"
    ),
    TestCase.new(
        "Cuckoo clock: the countdown and the chimes",
        _TESTS + "/test_cuckoo_clock/test_cuckoo_clock.tscn",
        _TESTS + "/test_cuckoo_clock/test_cuckoo_clock_players.gd"
    ),
    TestCase.new(
        "Swan and Limmat swimmer: taking off, floating down the river",
        _TESTS + "/test_swan_swimmer/test_swan_swimmer.tscn",
        _TESTS + "/test_swan_swimmer/test_swan_swimmer_players.gd"
    ),
    TestCase.new(
        "Pigeon and tram: mirroring, dancing sparks",
        _TESTS + "/test_pigeon_tram/test_pigeon_tram.tscn",
        _TESTS + "/test_pigeon_tram/test_pigeon_tram_players.gd"
    ),
    TestCase.new(
        "E-scooter hipster and punk: swoops and loops",
        _TESTS + "/test_hipster_punk/test_hipster_punk.tscn",
        _TESTS + "/test_hipster_punk/test_hipster_punk_players.gd"
    ),
    TestCase.new(
        "Banker pig: money rain, bouncing coins, telegraphed dives",
        _TESTS + "/test_banker/test_banker.tscn",
        _TESTS + "/test_banker/test_banker_players.gd"
    ),
    TestCase.new(
        "Collision: blinking, the shrinking ring, try again",
        _TESTS + "/test_collision/test_collision.tscn",
        _TESTS + "/test_collision/test_collision_players.gd"
    ),
    TestCase.new(
        "Enemy rockets: through the enemies, into the player",
        _TESTS + "/test_enemy_rockets/test_enemy_rockets.tscn",
        _TESTS + "/test_enemy_rockets/test_enemy_rockets_players.gd"
    ),
    TestCase.new(
        "Pickups: the chests and all the weapons",
        _TESTS + "/test_pickups/test_pickups.tscn",
        _TESTS + "/test_pickups/test_pickups_players.gd"
    ),
    TestCase.new(
        "Leave and return: the damage and the color are kept",
        _TESTS + "/test_leave_and_return/test_leave_and_return.tscn",
        _TESTS + "/test_leave_and_return/test_leave_and_return_players.gd"
    ),
]
@onready var select_test: OptionButton = $Panel/SelectTest
@onready var select_controller: OptionButton = $Panel/SelectController


func _ready() -> void:
    for test_case in _cases:
        if not ResourceLoader.exists(test_case.level_path):
            push_error("The level could not be found: %s" % test_case.level_path)
        if not ResourceLoader.exists(test_case.players_path):
            push_error("The scripted players could not be found: %s" % test_case.players_path)
        select_test.add_item(test_case.title)

    select_controller.add_item("Scripted players", Controller.SCRIPTED)
    select_controller.add_item("Mouse (Space: leave/return, 1-9: bots)", Controller.MOUSE)
    select_controller.add_item("Camera", Controller.CAMERA)

    select_test.grab_focus()


func _on_play_pressed() -> void:
    var index := select_test.get_selected_id()
    if index < 0 or index >= _cases.size():
        return
    var test_case := _cases[index]
    var levels: Array[String] = [test_case.level_path]

    match select_controller.get_selected_id():
        Controller.CAMERA:
            var select_camera = load("res://scenes/select_camera/select_camera.tscn").instantiate()
            select_camera.level_scene_paths = levels
            get_tree().root.add_child(select_camera)
            queue_free()
            return
        Controller.MOUSE:
            _start_game(
                load("res://scenes/tests/mouse_heads/mouse_heads.tscn").instantiate(), levels
            )
        _:
            var players: HeadController = (load(test_case.players_path) as GDScript).new()
            _start_game(players, levels)


func _start_game(controller: HeadController, levels: Array[String]) -> void:
    var game: Game = load("res://scenes/game/game.tscn").instantiate()
    game.own_head_controllers([controller])
    game.level_scene_paths = levels

    get_tree().root.add_child(game)
    queue_free()
