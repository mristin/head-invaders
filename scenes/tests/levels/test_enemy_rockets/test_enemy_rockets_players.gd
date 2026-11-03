extends ScriptedHeads

## Show the enemy rockets: the upper saucer fires through the lower one without
## hurting it. The player first takes the hits, then dodges from side to side.


func _play() -> void:
    appear(0, Vector2(960, 950))
    await wait(5.0)
    for i in range(3):
        await glide(0, Vector2(500, 950), 1.2)
        await wait(1.0)
        await glide(0, Vector2(1420, 950), 1.8)
        await wait(1.0)
