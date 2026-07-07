# Blender Import GLB
# 1.0.0
# Vasyl Lukianenko 
# 3DGROUND
# https://3dground.net


import bpy
import sys
import os

argv = sys.argv

glb_file_path = argv[argv.index("--") + 1]
blend_file_path = argv[argv.index("--") + 2]

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

bpy.ops.import_scene.gltf(filepath=glb_file_path)

# Display textures
for area in bpy.context.screen.areas:
    if area.type == 'VIEW_3D':
        for space in area.spaces:
            if space.type == 'VIEW_3D':
                space.shading.type = 'SOLID'
                space.shading.color_type = 'TEXTURE'


bpy.ops.wm.save_as_mainfile(filepath=blend_file_path)

bpy.ops.file.unpack_all(method='USE_LOCAL')

# Zoom extends
bpy.ops.view3d.view_selected()
for i in range(self.zoom_delta):
    bpy.ops.view3d.dolly(delta=1, mx=context.region.width/2, my=context.region.height/2)

bpy.ops.wm.save_as_mainfile(filepath=blend_file_path)