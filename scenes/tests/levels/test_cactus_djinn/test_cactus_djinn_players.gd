extends ScriptedHeads

## Show the cactus and the djinn. First the player waits at the side, so that
## the cactus puffs out its ring of needles, which hang and then fly at
## the player, and the djinn spins up its winding twisters. Then the player
## chases them away.


func _play() -> void:
    appear(0, Vector2(150, 950))
    await wait(9.0)
    await chase(0, func(): return below_nearest_enemy(0, 920.0), 60.0)
