extends ScriptedHeads

## Show the pigeon and the tram. First the player goes from one side to
## the other, and the pigeon mirrors the player at the top, while the tram
## rides, stops, rings and lets its sparks dance down. Then the player chases
## them away, and meets the pigeon in the middle.


func _play() -> void:
    appear(0, Vector2(150, 950))
    await wait(5.0)
    await glide(0, Vector2(1770, 950), 4.0)
    await wait(4.0)
    await glide(0, Vector2(150, 950), 4.0)
    await chase(0, func(): return below_nearest_enemy(0, 930.0), 60.0)
