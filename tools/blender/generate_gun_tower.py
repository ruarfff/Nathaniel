"""Create the editable Iron & Ink gun tower source."""

from iron_ink_towers import build_tower
from rig_gun_tower import rig_gun_tower


def build():
    build_tower("gun")
    rig_gun_tower()
