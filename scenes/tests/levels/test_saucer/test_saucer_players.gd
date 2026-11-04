extends ScriptedHeads

## Show a single saucer: it descends, cruises, bobs, fires at the player, and
## the player chases it away, which accomplishes the level.


func _play() -> void:
    appear(0, Vector2(960, 950))
    await wait(2.0)
    await chase(0, func(): return below_nearest_enemy(0, 900.0), 12.0)
