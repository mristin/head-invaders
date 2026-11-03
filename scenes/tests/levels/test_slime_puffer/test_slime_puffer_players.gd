extends ScriptedHeads

## Show the slime and the puffer: the slime hops and splits into two little
## slimes, and the puffer bounces around and puffs a ring of rockets. The player
## chases them away one by one.


func _play() -> void:
    appear(0, Vector2(960, 950))
    await wait(2.0)
    await chase(0, func(): return below_nearest_enemy(0, 920.0), 40.0)
