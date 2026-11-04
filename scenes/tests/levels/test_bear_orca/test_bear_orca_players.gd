extends ScriptedHeads

## Show the polar bear and the orca: the player waits at the side first, so
## that the bear rolls its growing snowballs and the orca leaps to its marked
## spot. Then the player chases both away.


func _play() -> void:
    appear(0, Vector2(180, 950))
    await wait(18.0)
    await chase(0, func(): return below_nearest_enemy(0, 950.0), 60.0)
