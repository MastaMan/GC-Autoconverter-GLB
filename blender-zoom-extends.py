import bpy

bpy.context.preferences.view.show_splash = False

def get_view3d():
    for window_manager in bpy.data.window_managers:
        for window in window_manager.windows:
            for area in window.screen.areas:
                if area.type == 'VIEW_3D':
                    for region in area.regions:
                        if region.type == 'WINDOW':
                            return dict(window=window, workspace=window.workspace, screen=window.screen, area=area, region=region)

    raise Exception('View3D context not found.')


with bpy.context.temp_override(**get_view3d()):
    bpy.ops.view3d.view_all(center=False)