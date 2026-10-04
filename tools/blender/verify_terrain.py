"""Check source-preserving terrain export with an artist-edited saved material."""

import json

import bpy


def verify_terrain(pipeline, settings):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene["asset_profile"] = "terrain_probe"
    scene["artist_note"] = "Keep terrain material edits"
    collection = bpy.data.collections.new("Ground tile")
    scene.collection.children.link(collection)
    bpy.ops.mesh.primitive_plane_add(size=1)
    obj = bpy.context.object
    for owner in list(obj.users_collection):
        owner.objects.unlink(obj)
    collection.objects.link(obj)
    material = bpy.data.materials.new("Artist soil")
    material.use_nodes = True
    shader = material.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (0.55, 0.08, 0.04, 1)
    obj.data.materials.append(material)
    empty = bpy.data.collections.new("Occupancy only")
    scene.collection.children.link(empty)
    scene["asset_terrain"] = json.dumps({"tiles": [
        {"name": "soil", "collection": collection.name},
        {"name": "empty", "collection": empty.name, "empty": True},
    ]})
    configured = dict(settings, profiles=dict(settings["profiles"], terrain_probe={
        "canvas": [66, 34], "anchor": [33, 17], "render_density": 1, "samples": 1}))
    source = pipeline.source_path("terrain_probe")
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    original_hash = pipeline.digest(source)
    pipeline.render("terrain_probe", configured)
    atlas = pipeline.IMAGES / "terrain_probe_atlas_0.png"
    original_png = atlas.read_bytes()
    assert pipeline.digest(source) == original_hash
    bpy.ops.wm.open_mainfile(filepath=str(source), use_scripts=False)
    bpy.data.collections["Ground tile"].hide_viewport = True
    bpy.data.materials["Artist soil"].node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.04, 0.18, 0.48, 1)
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    edited_hash = pipeline.digest(source)
    pipeline.render("terrain_probe", configured)
    edited_png = atlas.read_bytes()
    assert edited_png != original_png, "Saved terrain material edit did not reach the atlas"
    metadata = json.loads((pipeline.IMAGES / "terrain_probe.json").read_text())
    assert metadata["source_sha256"] == edited_hash
    assert metadata["tile_size"] == [64, 32]
    assert metadata["tiles"][1]["empty"]
    image = bpy.data.images.load(str(atlas), check_existing=False)
    width, height = image.size
    alpha = list(image.pixels)[3::4]
    bpy.data.images.remove(image)
    assert any(value > 0 for row in range(height) for value in alpha[row * width:row * width + width // 2])
    assert not any(value > 0 for row in range(height) for value in alpha[row * width + width // 2:(row + 1) * width])
    tileset = (pipeline.ROOT / metadata["tileset"]).read_text()
    assert "use_texture_padding = false" in tileset
    assert 'blend_mode = 4' in tileset
    assert tileset.count('/material = SubResource("TerrainBlend")') == 2
    assert metadata["import_premultiplied_alpha"]
    assert 'process/premult_alpha=true' in atlas.with_suffix('.png.import').read_text()
    pipeline.render("terrain_probe", configured)
    assert pipeline.digest(source) == edited_hash
    assert atlas.read_bytes() == edited_png, "Repeat terrain export changed PNG bytes"
    bpy.ops.wm.open_mainfile(filepath=str(source), use_scripts=False)
    assert bpy.context.scene["artist_note"] == "Keep terrain material edits"
    assert bpy.data.collections["Ground tile"].hide_viewport
    spec = json.loads(bpy.context.scene["asset_terrain"])
    spec["tiles"].reverse()
    bpy.context.scene["asset_terrain"] = json.dumps(spec)
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    try:
        pipeline.render("terrain_probe", configured)
    except ValueError as error:
        assert "Terrain address would change" in str(error)
    else:
        raise AssertionError("Reordered terrain tiles silently changed painted level meanings")
    assert atlas.read_bytes() == edited_png
    off_center = dict(configured, profiles=dict(configured["profiles"], terrain_probe={
        "canvas": [66, 34], "anchor": [34, 17], "render_density": 1, "samples": 1}))
    try:
        pipeline.render("terrain_probe", off_center)
    except ValueError as error:
        assert "centered canvas anchor" in str(error)
    else:
        raise AssertionError("Off-center terrain would shift native tile artwork")
    print("PASS: terrain material edits survive export; transparent occupancy; padded native atlas; identical repeat PNG")
