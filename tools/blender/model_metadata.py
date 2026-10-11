"""Guard model-only exports while retaining the existing sprite provenance."""


def validate_model_only_metadata(metadata, source, source_hash, settings, profile):
    if metadata.get("source") != source or metadata.get("source_sha256") != source_hash:
        raise ValueError("Saved source differs from the sprite export; run a full art-render.")
    density = settings["render_density"]
    expected = {
        "profile": profile,
        "render_density": density,
        "world_points_per_unit": settings["world_points_per_unit"],
        "blender_xy_basis_pixels": [[-32 * density, 16 * density], [32 * density, 16 * density]],
        "logical_xy_from_blender": ["32 * Y", "32 * X"],
    }
    if any(metadata.get(key) != value for key, value in expected.items()):
        raise ValueError("Model projection or profile differs from the sprite export; run a full art-render.")
    canvas = metadata.get("uncropped_canvas", metadata.get("canvas"))
    anchor = metadata.get("uncropped_anchor", metadata.get("anchor"))
    if canvas != [value * density for value in settings["canvas"]] or anchor != [value * density for value in settings["anchor"]]:
        raise ValueError("Model canvas or anchor differs from the sprite export; run a full art-render.")
    for logical, pixels in (("logical_canvas", "canvas"), ("logical_anchor", "anchor")):
        if metadata.get(logical) != [value / density for value in metadata[pixels]]:
            raise ValueError("Sprite logical coordinates disagree with its pixels; run a full art-render.")
    if not metadata.get("model"):
        raise ValueError("Asset has no previous model export; run a full art-render.")


def replace_model_metadata(metadata, model):
    return {**metadata, "model": model}
