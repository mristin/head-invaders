class_name CameraExtension
extends RefCounted

## Load CameraServerExtension, which provides the camera feeds on Windows,
## where Godot 4.6 implements no camera.
##
## See addons/CameraServerExtension/CameraServerExtension.gdextension.

## The extension removes its feeds when it is freed, so we keep it for the whole
## game.
static var _instance: Object = null


## Load the extension on Windows, and do nothing on the other platforms.
##
## Call it after [member CameraServer.monitoring_feeds] has been set.
##
## Return an explanation for the players if there will be no camera, or an empty
## string otherwise.
static func start() -> String:
    if OS.get_name() != "Windows" or _instance != null:
        return ""

    # NOTE (mristin):
    # The packaging puts the extension next to the executable; in the editor, it
    # stays in the project.
    var directory := (
        ProjectSettings.globalize_path("res://addons/CameraServerExtension")
        if OS.has_feature("editor")
        else OS.get_executable_path().get_base_dir()
    )
    var path := directory.path_join("CameraServerExtension.gdextension")

    var unsupported := (
        "The camera extension for Windows is missing or broken, "
        + "so the game can not use the camera."
    )

    if not FileAccess.file_exists(path):
        push_warning("The camera extension %s is missing." % path)
        return unsupported

    var status := GDExtensionManager.load_extension(path)
    if (
        status != GDExtensionManager.LOAD_STATUS_OK
        and status != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED
    ):
        push_warning("The camera extension %s did not load: %d." % [path, status])
        return unsupported

    if not ClassDB.class_exists("CameraServerExtension"):
        push_warning("The camera extension %s provides no CameraServerExtension." % path)
        return unsupported

    _instance = ClassDB.instantiate("CameraServerExtension")
    print("Loaded the camera extension %s." % path)

    if _instance != null and not _instance.call("permission_granted"):
        return (
            "Windows does not allow the game to use the camera. "
            + "Please allow it in Settings, Privacy & security, Camera."
        )

    return ""


## List the formats of a feed.
##
## The formats of the extension's feeds must be called by name, since the methods
## of [CameraFeed] do not reach them; a call by name works for all the feeds.
static func get_formats(feed: CameraFeed) -> Array:
    return feed.call("get_formats")


## Set the format of a feed, see [method get_formats].
static func set_format(feed: CameraFeed, index: int) -> void:
    feed.call("set_format", index, {})
