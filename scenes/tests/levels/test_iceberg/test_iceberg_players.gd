extends ScriptedHeads

## Show the iceberg: the player waits at the side first, so that it fires its
## icicles, then chases it, so that it cracks and the little ice cubes break
## off, and chases them away too.


func _play() -> void:
    appear(0, Vector2(180, 950))
    await wait(15.0)
    await chase(0, func(): return below_nearest_enemy(0, 950.0), 60.0)
