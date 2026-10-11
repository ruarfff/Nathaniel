# Resource gathering

Soldier, Gun Soldier, and Boss deaths leave one collectible body each. Grunts
and spawners leave no matter. Nathaniel carries compressed bodies in his
backpack; deployed Hermes recovers eligible deaths with one side winch.
Both paths credit each body's stored value once, at chest intake acceptance.
Values, reach, capacity, costs, and stage timings live in
[GameBalance](../scripts/domain/game_balance.gd); boss value and winch throughput
remain provisional.

Survival continues after boss death. Campaign boss death ends play immediately;
there is no recovery window or automatic payout. Continue resets cargo and resources.

## Collect and deliver

Clicking a visible corpse orders Nathaniel to its ground position and gives it
an amber highlight until grip, expiry, or cancellation. Collection also starts
automatically within reach using the nearest-body rule. A full rack shows
**Cargo full. Deliver to Hermes first**. Two arms handle one body at a time.

During `grab`, the body remains on the ground and its armed timer continues.
Leaving reach or dying cancels the grab. Successful grip requires a living
Nathaniel, a body in reach, and a free cargo slot. Expiry wins at the exact
deadline. Grip reserves the slot, assigns ownership, and permanently disarms
the body in one transition; `crush` then loads its compact bundle. Movement,
aim, and firing stay active.

With Nathaniel selected and carrying cargo, tap Hermes to return and deliver.
Repeated taps retain that order and Nathaniel's selection. The order tracks
Hermes and waits within intake reach until all cargo is accepted. Movement or
Stop cancels it. Delivery works with following or deployed Hermes.

The arms `present` one bundle, then `feed` it into the chest. Acceptance removes
the body and credits its value once. The contained furnace pulse delays the
next intake turn and gives no additional credit. Leaving range or losing Hermes
before acceptance returns the bundle to its rack. Nathaniel's death drops held
matter safely; an ungripped body keeps its remaining armed lifetime.

Capacity and reach upgrades use the command tray while Build is open and the
same wallet as towers.
They retain one arm pair, add visible rack clamps or extend the end links, and
survive saves and spare-life respawns. A fresh level uses the starter backpack.

## Hermes automatic recovery

The selected [G1 side winch](../concept-art/hermes-auto-consume.md) runs only
while Hermes is alive and deployed. Eligibility is recorded when a collectible
enemy dies inside or on his actual build boundary. The damage source does not
matter. Deployment does not sweep older bodies; pack-up clears pending eligibility.
Debug-created `spawn_resource` bundles are not eligible.

Before launch, recheck range, visibility, ownership, and the full body's route:
a straight ground pull to the outer guide, then the authored guide-to-intake
path. Solid terrain, towers, and spawners block it. Live mobile units and flat
tower conduits do not. Skip blocked bodies and retry while eligible. There is
one active body, no rope pathfinding, and no hidden cargo buffer.

The guide keeps full bodies outside Hermes's deployed footprint plus their
radius. The final leg compresses the load; interruption drops the full body at
its last clear exterior point.

Choose the armed body with the shortest remaining lifetime, then shortest
distance, then lowest stable ID. Disarmed bodies follow armed bodies. Reservation
and launch do not stop expiry. Successful clamp contact permanently disarms;
expiry wins at exact contact. Reel, crush, and feed then lead to intake acceptance,
followed by an empty-hook reset. The cannon keeps its target and fire timing.
The existing build outline shows range; recovery needs no new input or upgrade.

### Claim and intake priority

Resolve expiry first, a valid Hermes claim second, and backpack grip completion
third. When he can launch now, Hermes can take a loose body or supersede a
pre-grip grab. Clear only that body's obsolete grab progress and presentation
state; preserve unrelated cargo and orders. A body gripped in an earlier step
remains Nathaniel's. A busy or blocked winch does not reserve waiting bodies.

The chest accepts one bundle at a time. Finish manual delivery already in progress
before launching. If Nathaniel reaches intake range during a pull, finish the
pull, then accept his held cargo before launching again. A distant return order
does not reserve intake. Nathaniel can leave while waiting and keeps his cargo
until acceptance.

### Interruptions

Before contact, pack-up or Hermes death releases the armed body with its
remaining lifetime. After contact, either event or a newly blocked route drops
it at its safe ground position, permanently disarmed and collectible by Nathaniel.
Neither case credits matter. After acceptance, the credit remains and the body
cannot return. Hermes death still ends the run.

Pause freezes jobs, body motion, expiry, and intake feedback. A fresh run or scene
transition clears unfinished jobs and cables. [Saves](saves.md) preserve waiting
eligibility, exclusive ownership, route progress, expiry, disarm, and reset time.
An unavailable owner releases or safely drops the body on load. Older saves gain
no inferred eligibility or active hook.

## Corpse self-destruct

Armed bodies expire after the lifetime in `GameBalance`. The final warning window
is part of that lifetime. Dissolution is a short visual tail after resource loss:
it causes no damage, chain reaction, or recoverable residue. Boss collapse is
also part of the deadline and stops when grip takes ownership.

Starting a grab or reserving a hook does not disarm. A successful grip or clamp
contact does, permanently. A full rack cannot grip another body; reach and
capacity upgrades do not extend deadlines or disarm nearby bodies. Disarmed
cargo never warns, including after a death drop or interrupted transfer.

The simulation owns expiry and disarm. Presentation reads the remaining armed
time for warning flashes and retains only the dissolve image after expiry.
Pause freezes both. Loading preserves remaining time; it never resets a deadline
or restores expired matter. Older held cargo loads disarmed; older loose bodies
keep their saved armed time. See the [effect study](../concept-art/resource-gathering.md#corpse-self-destruct).

## State, artwork, and checks

`GameSimulation` owns body identity, slots, handling phases, and credit.
Bodies remain in the corpse collection until accepted or expired. Presentation
displays that state; animation callbacks never award resources.

Edit `art/blender/sources/nathaniel.blend`, `hermes.blend`, and
`hermes_anchor.blend` for the gathering rigs. Keep them separate from weapon and
locomotion mounts. `boss_corpse.blend` supplies the full shell;
`boss_bundle.blend` supplies the one-slot crest-and-prism bundle.
Use the [Blender pipeline](blender-assets.md), not generated runtime edits.

`tools/blender/resource_gathering.py` verifies the saved controls and export
hashes. Use the pinned Blender version:

```sh
rtk blender --background --factory-startup --disable-autoexec --python-exit-code 1 --python tools/blender/resource_gathering.py -- verify all
rtk make test-resource-gathering
rtk make art-resource-gathering art-enemy-deaths
rtk make test format-check
```

Focused checks cover eligibility, claim order, route clearance, expiry, shared
intake, interruptions, upgrades, saves, HUD orders, and live rigs. Captures use
scripted state. Use [testing](testing.md) for real platform input checks.
