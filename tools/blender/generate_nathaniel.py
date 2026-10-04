"""Create Nathaniel's editable animated Blender source."""

from iron_ink_characters import build_character
from rig_nathaniel import rig_character


def build():
    build_character("nathaniel")
    rig_character()
