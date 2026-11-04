extends ScriptedHeads

## Show the darts: they dive weaving and come around from the top. The player
## sweeps from side to side at the bottom, sometimes crossing a dart.


func _play() -> void:
    appear(0, Vector2(200, 950))
    for i in range(4):
        await glide(0, Vector2(1720, 950), 3.0)
        await glide(0, Vector2(200, 950), 3.0)
