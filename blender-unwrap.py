import math
import os
import sys
import traceback

import bpy


def log(message):
    print(str(message), flush=True)
    return True


def get_arg(index, default_value):
    if len(sys.argv) > index:
        return sys.argv[index]
    return default_value


def get_bool_arg(value, default_value):
    if value is None:
        return default_value

    text_value = str(value).strip().lower()
    if text_value in ("1", "true", "yes", "on"):
        return True
    if text_value in ("0", "false", "no", "off"):
        return False
    return default_value


def get_cli_args():
    if "--" not in sys.argv:
        raise RuntimeError("Missing -- arguments. Expected: input.obj output.obj resolution method angleLimit islandMargin packIslands")

    args = sys.argv[(sys.argv.index("--") + 1):]
    if len(args) < 2:
        raise RuntimeError("Missing input/output OBJ paths.")

    input_obj = args[0]
    output_obj = args[1]
    resolution = int(args[2]) if len(args) > 2 else 1024
    unwrap_method = args[3] if len(args) > 3 else "smart_project"
    angle_limit = float(args[4]) if len(args) > 4 else 66.6
    island_margin = float(args[5]) if len(args) > 5 else 0.02
    pack_islands = get_bool_arg(args[6], True) if len(args) > 6 else True

    if unwrap_method not in ("smart_project", "lightmap_pack"):
        unwrap_method = "smart_project"

    return input_obj, output_obj, resolution, unwrap_method, angle_limit, island_margin, pack_islands


def clear_scene():
    bpy.ops.object.mode_set(mode="OBJECT") if bpy.ops.object.mode_set.poll() else None
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    return True


def import_obj(filepath):
    if not os.path.exists(filepath):
        raise RuntimeError("Input OBJ does not exist: " + filepath)

    try:
        bpy.ops.wm.obj_import(filepath=filepath)
    except Exception:
        bpy.ops.import_scene.obj(filepath=filepath)

    mesh_objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if len(mesh_objects) < 1:
        raise RuntimeError("OBJ import created no mesh objects.")

    return mesh_objects


def export_obj(filepath, mesh_objects):
    folder = os.path.dirname(filepath)
    if folder and not os.path.exists(folder):
        os.makedirs(folder)

    bpy.ops.object.mode_set(mode="OBJECT") if bpy.ops.object.mode_set.poll() else None
    bpy.ops.object.select_all(action="DESELECT")
    for obj in mesh_objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = mesh_objects[0]

    try:
        bpy.ops.wm.obj_export(
            filepath=filepath,
            export_selected_objects=True,
            export_uv=True,
            export_materials=False,
            export_triangulated_mesh=False,
        )
    except Exception:
        bpy.ops.export_scene.obj(
            filepath=filepath,
            use_selection=True,
            use_materials=False,
            use_uvs=True,
            use_triangles=False,
        )

    if not os.path.exists(filepath):
        raise RuntimeError("OBJ export did not create output file: " + filepath)

    return True


def pack_uv_islands(island_margin):
    try:
        bpy.ops.uv.average_islands_scale()
    except Exception as exc:
        log("WARNING: average_islands_scale failed: " + str(exc))

    try:
        bpy.ops.uv.pack_islands(
            rotate=True,
            scale=True,
            margin=island_margin,
        )
    except TypeError:
        try:
            bpy.ops.uv.pack_islands(
                rotate=True,
                margin=island_margin,
            )
        except TypeError:
            bpy.ops.uv.pack_islands(margin=island_margin)

    return True


def unwrap_object(obj, unwrap_method, angle_limit, island_margin, pack_islands):
    bpy.ops.object.mode_set(mode="OBJECT") if bpy.ops.object.mode_set.poll() else None
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj

    mesh = obj.data
    if len(mesh.polygons) < 1:
        raise RuntimeError("Mesh has no polygons: " + obj.name)

    if len(mesh.uv_layers) < 1:
        mesh.uv_layers.new(name="AO")
    mesh.uv_layers.active_index = len(mesh.uv_layers) - 1

    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_mode(type="FACE")
    bpy.ops.mesh.select_all(action="SELECT")

    if unwrap_method == "lightmap_pack":
        margin_div = 100
        if island_margin > 0.0:
            margin_div = max(1, int(round(1.0 / island_margin)))

        bpy.ops.uv.lightmap_pack(
            PREF_CONTEXT="SEL_FACES",
            PREF_PACK_IN_ONE=True,
            PREF_NEW_UVLAYER=False,
            PREF_BOX_DIV=12,
            PREF_MARGIN_DIV=margin_div,
        )
    else:
        smart_angle = math.radians(angle_limit)
        try:
            bpy.ops.uv.smart_project(
                angle_limit=smart_angle,
                island_margin=island_margin,
                area_weight=0.0,
                correct_aspect=True,
                scale_to_bounds=False,
            )
        except TypeError:
            try:
                bpy.ops.uv.smart_project(
                    angle_limit=smart_angle,
                    island_margin=island_margin,
                    user_area_weight=0.0,
                    use_aspect=True,
                    stretch_to_bounds=False,
                )
            except TypeError:
                bpy.ops.uv.smart_project(
                    angle_limit=smart_angle,
                    island_margin=island_margin,
                )

    if pack_islands:
        pack_uv_islands(island_margin)

    bpy.ops.object.mode_set(mode="OBJECT")
    mesh.uv_layers.active_index = len(mesh.uv_layers) - 1
    return True


def main():
    input_obj, output_obj, resolution, unwrap_method, angle_limit, island_margin, pack_islands = get_cli_args()

    log("Blender unwrap started")
    log("Input: " + input_obj)
    log("Output: " + output_obj)
    log("Resolution: " + str(resolution))
    log("Method: " + unwrap_method)
    log("Angle limit: " + str(angle_limit))
    log("Island margin: " + str(island_margin))
    log("Pack islands: " + str(pack_islands))

    clear_scene()
    mesh_objects = import_obj(input_obj)
    log("Imported mesh objects: " + str(len(mesh_objects)))

    total_polygons = 0
    for obj in mesh_objects:
        total_polygons += len(obj.data.polygons)
        unwrap_object(obj, unwrap_method, angle_limit, island_margin, pack_islands)
        log("Unwrapped: " + obj.name + " polygons=" + str(len(obj.data.polygons)))

    log("Total polygons: " + str(total_polygons))
    export_obj(output_obj, mesh_objects)
    log("Blender unwrap finished")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        log("ERROR: " + str(exc))
        traceback.print_exc()
        sys.exit(1)
