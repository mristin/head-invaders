extends ScriptedHeads

## Show the jelly, the orbiter and the zipper: the jelly drifts after the
## player and puffs the fans, the orbiter circles, and the zipper hops around.
## The player chases them away one by one.


func _play() -> void:
    appear(0, Vector2(960, 950))
    await wait(3.0)
    await chase(0, func(): return below_nearest_enemy(0, 920.0), 40.0)
