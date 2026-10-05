# Resource gathering

Nathaniel's backpack gathers Soldier and Gun Soldier bodies. Both mechanical
arms handle one body at a time. The starter rack holds one bundle. A bundle is
cargo; it becomes ten spendable resources only after Hermes accepts it.

The [boss corpse and enemy death concepts](../concept-art/enemy-deaths.md)
propose adding collectible boss matter while grunts and spawners explode
without leaving resources. This extension is not implemented. In survival,
boss matter can support the ongoing run through the normal collection loop;
its value remains undecided. Campaign bosses that end a level need a separate
collection opportunity and reward decision because victory stops collection
and Continue resets cargo and resources.

## Collect and deliver

Approach within 44 logical points of a body. The arms unfold, grip the shell,
crush it, and place one compact bundle in the rack. Grabbing takes 0.28 seconds;
crushing and loading take 0.32 seconds. Movement, aiming, and firing stay active.
Moving out of reach before the grip cancels collection. After the grip, the
body belongs to the backpack and no longer appears on the ground.

The rack shows each occupied slot. At capacity, the arms stay folded near other
bodies. The HUD reports cargo separately from resources. Use **Deliver cargo**
or click Hermes while carrying a bundle to return to him. This closes Build
and follows Nathaniel with the camera. The return order tracks Hermes and stops
within intake range until all cargo is accepted. A movement order or Stop
cancels the return. Hermes can receive cargo while following or deployed;
delivery does not change his mode.

Within 48 logical points, the arms present one bundle for 0.22 seconds, then
feed it through the chest intake for 0.38 seconds. Hermes accepts it once,
credits its value, and closes the intake. A contained amber furnace pulse lasts
0.55 seconds before the next bundle can enter. Moving outside delivery range
before acceptance returns the bundle to its rack. The pulse never creates
resources.

Armed bodies expire after ten seconds. A successful grip permanently disarms
the body. Nathaniel's death drops held matter at his death position, still safe;
an ungripped armed body retains its remaining lifetime. Hermes's death cancels an
unfinished transfer without credit. Pause freezes all handling and furnace
timers.

## Corpse self-destruct

Implemented from the 2026-10-04 concept. Self-destruct uses the existing
ten-second lifetime and does not change the value of delivered matter.

Aliens start an internal self-destruct sequence when they die. The sequence
destroys their remaining matter, so Nathaniel must reach a body before it
expires. His backpack gathering tool disables the mechanism during the grip.
The body can then be crushed, carried, and fed to Hermes.

The sequence is **warning flashes, then dissolution**, with a successful
grip stopping self-destruct. Timings remain subject to gameplay balance.

| State | Timing | Appearance and resource rule |
| --- | --- | --- |
| Armed | First 7 seconds after death | Intact body with dim alien seams; collection is available. |
| Warning | Final 3 seconds of the existing 10-second lifetime | Local flashes across the shell and seams; collection is still available. |
| Dissolving | At expiry, for 0.6 seconds | Shell vanishes in coarse patches. The resource is already lost and cannot be collected. |
| Disarmed | Successful grip before expiry | Warning stops immediately; the body has no expiry timer. Continue crush and carry. |

The warning is part of the ten-second lifetime, not extra time. Dissolution
is a visual tail after resource loss. This is internal breakdown: it causes
no blast damage, chain reaction, or recoverable residue. Keep the current
resource-producing enemy types and ten-resource value per accepted bundle.

### Disarm during collection

Use the existing successful grip at the end of the 0.28-second grab phase as
the disarm point. A contact pad inside one clamp disables the mechanism while
both arms secure the shell. This adds no button, separate channel time, tool
arm, or resource cost. The starter backpack includes the disarm function.

Starting a grab does not stop the timer. Leaving reach or dying before grip
cancels that grab and leaves the original deadline unchanged. A full rack
cannot grip or disarm another body. The arms still process one body at a time;
reach and capacity upgrades do not extend corpse lifetimes or disable nearby
bodies automatically. Movement, aim, and firing keep their current behavior.

At grip completion, the simulation must confirm that Nathaniel is alive,
the body is in reach, a slot is available, and the body is either already
disarmed or has an armed lifetime greater than zero. At the exact expiry
boundary, expiry wins. Reserve the slot, assign the body, and mark it
disarmed in one accepted transition. Once dissolution starts, reaching the
body cannot rescue it.

Disarm is permanent. If Nathaniel dies after a successful
grip, the dropped body remains safe and can be collected again.
Hermes's death or an interrupted delivery also leaves retained cargo safe.
Gripping or disarming gives no spendable resources; Hermes still credits each
accepted bundle once.

Pause freezes the countdown, warning phase, and dissolution. Saves must retain
armed time remaining and permanent disarm status; loading must not reset a
deadline or restore lost matter. For older saves, treat held cargo as disarmed
and loose bodies as armed with their saved time remaining. Old loose bodies
do not record whether they were previously carried.

### Effect and acceptance checks

Use the [self-destruct concept](../concept-art/resource-gathering.md#corpse-self-destruct)
for appearance, clamp contact, and simple production options. The simulation
owns eligibility and disarm state; presentation only displays the warning and
retains a short dissolve effect after expiry.

Automated checks cover warning onset, collection during warning,
expiry during a grab, the exact expiry boundary, full capacity, interruption
before grip, safe cargo dropped after death, pause, and save/load in each
state. Confirm that disarmed cargo never flashes, expired matter gives no
credit, and delivery still credits once. Inspect the effect at normal game zoom
on sand and dark rubble, including several corpses with different deadlines.
The [verification record](verification.md) lists completed checks and platform limits.

## Backpack upgrades

Open **Build** to buy the two upgrades independently. They use the same wallet
as towers and retain the same pair of arms. These are provisional balance
values; the concept did not specify costs or a progression schedule.

| Upgrade | Starter | First upgrade | Second upgrade |
| --- | --- | --- | --- |
| Cargo slots | 1 | 2, costs 20 | 3, costs 40 |
| Collection reach | 44 | 60, costs 15 | 76, costs 30 |

Distances are logical world points. Reach extends the end links; capacity adds
visible rack clamps. Upgrades survive saving and spare-life respawns. A fresh
level starts with the starter backpack. Balance and stage timings live in
`scripts/domain/game_balance.gd`.

## State and artwork

`GameSimulation` owns body identity, cargo slots, handling phases, and credit.
Each body has one phase: `loose`, `grab`, `crush`, `carry`, `present`, or `feed`.
The body remains in the corpse collection until accepted or expired. The
presentation reads this state and animates the two arms and Hermes's intake.

The editable sources are `art/blender/sources/nathaniel.blend`, `hermes.blend`,
and `hermes_anchor.blend`. The gathering rig stays separate from the existing
weapon mounts and locomotion. Export through the [Blender pipeline](blender-assets.md);
do not edit generated models or sprites. The [concept sheets](../concept-art/resource-gathering.md)
remain the visual reference.

`tools/blender/resource_gathering.py` provides an explicit, idempotent source
migration and verifies the saved controls and export hashes. Ordinary exports
never run that migration. Use the pinned Blender version:

```sh
rtk blender --background --factory-startup --disable-autoexec --python-exit-code 1 --python tools/blender/resource_gathering.py -- verify all
```

Snapshots retain upgrade levels, handling progress, cargo ownership, the return
order, and the remaining furnace pulse. Older saves receive starter defaults.
If an older save carries more than one body, the first stays in the rack and the others
drop beside Nathaniel, permanently disarmed. No matter is discarded
or credited during migration. The save format stays at version 1.

## Checks

```sh
rtk make test-resource-gathering
rtk make art-resource-gathering
rtk make test
rtk make format-check
```

The focused checks cover capacity, range, interrupted handling, death, sequential
credit, upgrades, saves, HUD commands, and live model rigs. The capture target
uses scripted game state for collection, full racks, and both intake heights.
Real platform input and export results are recorded in [verification](verification.md).
