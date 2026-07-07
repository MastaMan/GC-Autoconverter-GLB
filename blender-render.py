
# Blender GLB Render
# 1.0.0
# Vasyl Lukianenko 
# 3DGROUND
# https://3dground.net

import bpy
import math
import os
import glob
import sys

argv = sys.argv

glb = argv[argv.index("--") + 1]
render_file_name = argv[argv.index("--") + 2]
hdri = argv[argv.index("--") + 3]

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

bpy.ops.import_scene.gltf(filepath=glb)

# Display textures
for area in bpy.context.screen.areas:
    if area.type == 'VIEW_3D':
        for space in area.spaces:
            if space.type == 'VIEW_3D':
                space.shading.type = 'SOLID'
                space.shading.color_type = 'TEXTURE'

# Define time limit for rendering (in seconds)
max_samples = 12
scene = bpy.context.scene
obj = bpy.ops.object

glb_dirname = os.path.dirname(glb)

# Render settings
def setup_render():
   # if scene.render.engine == 'CYCLES':
   #     scene.cycles.progressive = 'PATH'
   #     scene.cycles.samples = 20
   # elif scene.render.engine == 'BLENDER_EEVEE':
   #     scene.eevee.taa_render_samples = 20

    scene.render.engine = 'CYCLES'
    scene.cycles.progressive = 'PATH'
    scene.cycles.samples = max_samples
    scene.render.resolution_x = 1024
    scene.render.resolution_y = 1024
    scene.render.film_transparent = True
    #scene.render.image_settings.file_format = 'JPEG'
    #scene.render.image_settings.quality = 90  # JPEG quality (0 to 100)
    scene.render.filepath = render_file_name
    if os.path.exists(render_file_name):
        os.remove(render_file_name)

render_file = setup_render()

# Create and configure camera
def setup_camera():
    obj.select_all(action='DESELECT')
    obj.select_by_type(type='CAMERA')
    obj.delete()
    obj.camera_add(location=(0, 0, 0)) 
    camera = bpy.context.object
    camera.rotation_mode = 'XYZ'
    camera.rotation_euler = (math.radians(72), 0, math.radians(-36))
    scene.camera = camera
    obj.select_all(action='SELECT')
    bpy.ops.view3d.camera_to_view_selected()
    camera.data.lens *= 0.95
    return camera

camera = setup_camera()

def setup_hdri_environment():
    bpy.context.scene.world.use_nodes = True
    world = bpy.context.scene.world
    nodes = world.node_tree.nodes

    for node in nodes:
        nodes.remove(node)

    bg_node = nodes.new(type='ShaderNodeTexEnvironment')
    bg_node.image = bpy.data.images.load(hdri)
    
    output_node = nodes.new(type='ShaderNodeOutputWorld')

    links = world.node_tree.links
    links.new(bg_node.outputs[0], output_node.inputs[0])

setup_hdri_environment()

# Start rendering
try:
    bpy.ops.render.render(write_still=True)
except:
    print("Render stopped due to time limit or other interruption.")

print("Render completed or stopped.")
