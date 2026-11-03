extends ScriptedHeads

## Show the penguin and the snowy owl: the player waits at the side first, so
## that the penguin toboggans around and throws its snowballs, and the owl
## throws its snowflakes, which fly back to it. Then the player chases both
## away.


func _play() -> void:
    appear(0, Vector2(180, 950))
    await wait(9.0)
    await chase(0, func(): return below_nearest_enemy(0, 950.0), 60.0)
