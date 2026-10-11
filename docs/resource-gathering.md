# Resource gathering

Nathaniel's backpack gathers Soldier, Gun Soldier, and Boss bodies. Deployed
Hermes can recover new deaths inside his build zone with one side winch.
Both paths preserve each body's stored value and credit resources only when
his chest intake accepts the bundle. Nathaniel's two arms handle one body at
a time, and the starter rack holds one bundle.

The [boss corpse and enemy death design](../concept-art/enemy-deaths.md)
is implemented. One boss leaves one body, compressed into one bundle in one
starter slot. The bundle retains a pale crest shard and dark prism. Grunts and
spawners leave no matter. In survival, the run continues and boss matter uses
the normal collection and delivery loop. Its current value is **10 resources**,
a provisional soldier-value default, not approved final balance. Change it in
`GameBalance.RESOURCE_VALUES`. Campaign boss death still ends play immediately.
It adds no recovery window or automatic boss payout; Continue resets cargo
and resources.

## Collect and deliver

Click a visible corpse to move Nathaniel to its ground position. The selected
body has Nathaniel's amber highlight, and the HUD says **Collecting corpse**.
The highlight clears when the body enters the backpack or expires, or when
movement is replaced or stopped. A full rack shows **Cargo full. Deliver to
Hermes first** instead of a pickup highlight. Collection still starts
automatically within reach and uses the existing nearest-body rule.

Approach within 44 logical points of a body. The arms unfold, grip the shell,
crush it, and place one compact bundle in the rack. Grabbing takes 0.28 seconds;
crushing and loading take 0.32 seconds. Movement, aiming, and firing stay active.
Moving out of reach before the grip cancels collection. After the grip, the
body belongs to the backpack and no longer appears on the ground.

The rack shows each occupied slot. At capacity, the arms stay folded near other
bodies. The HUD reports cargo separately from resources. With Nathaniel selected,
tap Hermes in the world while carrying a bundle to return to him immediately.
Repeated taps keep the delivery action and never select Hermes or open his
ring. Delivery keeps Nathaniel selected and focused. The return order tracks Hermes and stops
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

## Hermes automatic recovery

The selected [G1 side winch](../concept-art/hermes-auto-consume.md) works while
Hermes is alive and deployed. Eligibility is recorded when a collectible enemy
dies inside or on his actual build boundary, currently 240 logical points.
The damage source does not matter. Deployment does not sweep older bodies,
and packing up clears the current deployment's pending list. Debug-created
bundles from `spawn_resource` do not enter that list.

Before launch, the simulation checks the body's range, visibility, ownership,
and route again. It checks the full body width along a straight ground pull
to the outer guide and the short guide path into the chest. Solid terrain,
towers, and spawners block the route. Live mobile units and flat tower conduits
do not. Blocked bodies remain available to Nathaniel and can be retried while
they are eligible. The winch has no rope pathfinding or hidden cargo buffer.

The guide keeps full bodies outside the 44-point deployed footprint plus their
radius. The final leg compresses matter into the intake. If this leg is
interrupted, the full body drops at its last clear exterior point.

Hermes selects the armed body with the shortest remaining lifetime, then the
closest body, then the lowest stable ID. Permanently disarmed bodies follow
armed bodies. A waiting or reserved body still expires. The hook must make
contact before the deadline; expiry wins at exact contact. Contact permanently
disarms the body without awarding resources.

The initial timings are tuning values in `GameBalance`:

| Stage | Seconds | Ownership and resource rule |
| --- | --- | --- |
| Launch and clamp | 0.2 + 0.1 | One reserved ground body; decay continues until contact. |
| Reel | 0.7 | One disarmed shell moves along the ground route. |
| Crush | 0.15 | The shell becomes its existing compact bundle at the intake lip. |
| Feed | 0.15 | Intake acceptance removes the body and credits its stored value once. |
| Reset | 0.2 | The empty hook returns before the next launch. |

The cannon keeps its combat target and fire timing throughout recovery.
The build outline remains the range indicator. No new input, upgrade, cost,
or HUD button is needed.

### Claim and intake priority

When the winch can launch now, Hermes can take a loose body or a backpack grab
that has not completed its grip. Resolve expiry first, the valid hook claim
second, and backpack grip completion third. The claim clears that body's
obsolete grab progress and presentation state. It preserves unrelated cargo
and orders. A body gripped in an earlier step remains Nathaniel's. A busy or
blocked winch does not prevent him from collecting waiting bodies.

The chest receives one bundle at a time. Finish a manual delivery already in
progress before launching a hook. If Nathaniel reaches intake range during
a pull, finish that pull, then accept his held cargo before launching again.
A distant return order does not reserve the intake. Nathaniel can leave while
waiting; his cargo remains in the rack until acceptance. Manual delivery works
with either Hermes form.

### Interruptions

Packing up or losing Hermes before clamp contact releases the armed body with
its remaining lifetime. After contact, either event or a newly blocked route
drops the body at its current safe ground position, permanently disarmed and
available to Nathaniel. Neither case credits resources. After acceptance, the
credit remains and the body cannot return. Hermes death still ends the run.

Pause freezes the job, ground motion, corpse timers, and intake feedback.
A fresh run or scene transition clears unfinished jobs and visual cables.
Saves retain unclaimed death-time eligibility, exclusive ownership, route
progress, expiry, permanent disarm, and reset time. Loading with an unavailable
owner releases or safely drops the body. Older saves receive no inferred
eligibility or active hook. Survival continues after boss death; campaign
victory still stops collection immediately.

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
no blast damage, chain reaction, or recoverable residue. Soldier variants and
boss matter use these same rules. Boss collapse is part of the ten-second
lifetime and ends immediately when grip takes ownership.

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

Open **Hermes’s ring** to show the separate backpack upgrade controls. They use the same wallet
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
Each body has one phase: `loose`, `grab`, `crush`, `carry`, `present`, `feed`,
`winch_launch`, `winch_reel`, `winch_crush`, or `winch_feed`.
The body remains in the corpse collection until accepted or expired. The
presentation reads this state and animates the two arms and Hermes's intake.

The editable sources are `art/blender/sources/nathaniel.blend`, `hermes.blend`,
and `hermes_anchor.blend`. The gathering rig stays separate from the existing
weapon mounts and locomotion. Export through the [Blender pipeline](blender-assets.md);
do not edit generated models or sprites. The [concept sheets](../concept-art/resource-gathering.md)
remain the visual reference.

`boss_corpse.blend` contains the collapsed saved boss parts. `boss_bundle.blend`
contains the compressed crest and prism. The bundle's exported GLB fits the
existing rack and both intake heights. These sources use the same export
pipeline; no living character source or weapon rig is rebuilt for boss cargo.

`tools/blender/resource_gathering.py` provides an explicit, idempotent source
migration and verifies the saved controls and export hashes. Ordinary exports
never run that migration. Use the pinned Blender version:

```sh
rtk blender --background --factory-startup --disable-autoexec --python-exit-code 1 --python tools/blender/resource_gathering.py -- verify all
```

Snapshots retain upgrade levels, handling progress, cargo and winch ownership,
death-time recovery eligibility, the return order, and the remaining furnace
pulse. Older saves receive starter defaults.
If an older save carries more than one body, the first stays in the rack and the others
drop beside Nathaniel, permanently disarmed. No matter is discarded
or credited during migration. The save format stays at version 1.

## Checks

```sh
rtk make test-resource-gathering
rtk make art-resource-gathering
rtk make art-enemy-deaths
rtk make test
rtk make format-check
```

The focused checks cover capacity, range, interrupted handling, death, sequential
credit, upgrades, saves, HUD commands, and live model rigs. Automatic recovery
checks also cover death-time eligibility, urgent-body order, all-around routes,
body clearance, visibility, contested grips, shared intake, exact contact expiry,
per-phase interruptions, and campaign versus survival outcomes. The capture target
uses scripted game state for collection, full racks, and both intake heights.
`art-enemy-deaths` also captures boss warning and dissolve, a complete scripted
survival delivery, both shell sequences, and simultaneous deaths at normal zoom.
Real platform input and export results are recorded in [verification](verification.md).
