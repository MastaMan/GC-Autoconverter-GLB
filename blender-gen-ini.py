# Blender INI Generator
# 1.0.0
# Vasyl Lukianenko 
# 3DGROUND
# https://3dground.net

import bpy
import re
import configparser
import os
import mathutils

blend_file_path = bpy.data.filepath
blend_filename = os.path.basename(blend_file_path)
blend_dirname = os.path.dirname(blend_file_path)
blend_filename_no_ext = os.path.splitext(blend_filename)[0]
config_file_name = f"{blend_file_path}.ini"
config = configparser.ConfigParser()
ver = bpy.app.version_string
scene = bpy.context.scene
scene_name = scene.name
# system_units = scene.unit_settings.system
system_units = "Metric"
display_units = scene.unit_settings.length_unit
render_engine = scene.render.engine
total_polygons = 0
total_vertices = 0
width = 0
height = 0
depth = 0
unique_textures = set()
suffix_pattern = re.compile(r'\.\d+$')

def is_packed_images():
    packed_images = []
    for image in bpy.data.images:
        if image.packed_files is not None and len(image.packed_files) > 0:
            packed_images.append(image.filepath)
    
    if len(packed_images) > 0: return True
    return False

def get_scene_dimensions():
    min_corner = mathutils.Vector((float('inf'), float('inf'), float('inf')))
    max_corner = mathutils.Vector((float('-inf'), float('-inf'), float('-inf')))
    
    for obj in scene.objects:
        if obj.type in {'MESH', 'CURVE', 'SURFACE', 'META', 'FONT'}:
            # Apply transformations
            obj_eval = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
            bbox_corners = [obj_eval.matrix_world @ mathutils.Vector(corner) for corner in obj_eval.bound_box]
            
            for corner in bbox_corners:
                min_corner = mathutils.Vector((
                    min(min_corner.x, corner.x),
                    min(min_corner.y, corner.y),
                    min(min_corner.z, corner.z)
                ))
                max_corner = mathutils.Vector((
                    max(max_corner.x, corner.x),
                    max(max_corner.y, corner.y),
                    max(max_corner.z, corner.z)
                ))
    
    scene_dimensions = max_corner - min_corner
    return scene_dimensions


for obj in scene.objects:
    if obj.type == 'MESH':
        mesh = obj.data
        total_polygons += len(mesh.polygons)
        total_vertices += len(mesh.vertices)

        for material in obj.data.materials:
            if material and material.use_nodes:
                for node in material.node_tree.nodes:
                    if node.type == 'TEX_IMAGE' and node.image:
                        texture_name = os.path.basename(node.image.filepath)
                        clean_texture_name = re.sub(suffix_pattern, '', texture_name)
                        unique_textures.add(clean_texture_name)


scene_dimensions = get_scene_dimensions()

width, depth, height = scene_dimensions
width = round(width, 2)
height = round(height, 2)
depth = round(depth, 2)

config['INDEX'] = {
    'BLENDER_VER': bpy.app.version_string,
    'POLYS': str(total_polygons),
    'VERT': str(total_vertices),
    'RENDER': render_engine,
    'SYSTEM_UNITS': system_units,
    'DISPLAY_UNITS': display_units,
    'IS_PACKED_IMAGES': str(is_packed_images()),
}

config['DIMENSION'] = {
    'WIDTH': str(width),
    'HEIGHT': str(height),
    'LENGTH': str(depth),
}

unique_textures_section = {}

for texture in unique_textures:
    unique_textures_section[texture] = ""

config['TEXTURES'] = unique_textures_section

with open(config_file_name, 'w') as configfile:
    config.write(configfile)