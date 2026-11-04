extends ScriptedHeads

## Play the first level with a crowd: ten players weave across the lower half
## of the screen and fight the waves together.

const _COUNT: int = 10


func _play() -> void:
    for id in range(_COUNT):
        appear(id, _weave(id, 0.0))
        await wait(0.3)

    var elapsed := 0.0
    while elapsed < 40.0:
        await get_tree().process_frame
        elapsed += get_process_delta_time()
        for id in range(_COUNT):
            teleport(id, _weave(id, elapsed))


func _weave(id: int, t: float) -> Vector2:
    var phase := TAU * id / _COUNT
    return Vector2(960.0 + sin(t * 0.3 + phase) * 800.0, 800.0 + sin(t * 0.7 + phase * 2.0) * 180.0)
