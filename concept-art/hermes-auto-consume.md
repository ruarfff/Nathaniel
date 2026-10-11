# Hermes: automatic corpse recovery

Deployed Hermes fires a grapple, disables a corpse's self-destruct, pulls it
to his intake, and consumes it. Selected design: **G1 / Side winch**, one compact
mechanism, one body at a time, with the cannon free to keep firing.

The user approved this design on 2026-10-11 and gave **Hermes priority over
Nathaniel when claiming a corpse**. The prototype is implemented; the
[resource guide](../docs/resource-gathering.md) records its rules and timings.
The user also confirmed **collectible corpses only**. Soldier, Gun Soldier, and
Boss are eligible kinds. Grunts and spawners keep their explosions and leave
no matter. The rules below define the first implementation. Numeric timing
values remain starting points for playtesting.

Use the [implementation handoff](hermes-auto-consume-implementation-prompt.md)
for work on the current branch.

## Three visual directions

![Three grapple mechanisms for deployed Hermes](iron-and-ink/28-hermes-grapple-options.png)

| Direction | Motion and appearance | Design tradeoff |
| --- | --- | --- |
| **G1 / Side winch — selected** | A low swivel launches a broad clamp on a physical cable. A reel pulls the body to the chest intake. | Few rigid parts; leaves the head and cannon clear. Routing from behind Hermes needs a blockout. |
| **G2 / Folding boom** | A short hinged crane lifts the body slightly and guides it into the intake. | Strong industrial character; taller, with more joints and more overlap with the cannon. |
| **G3 / Arm launchers** | Forearms unfold into two launch cradles. One clamp works while the other stays stowed. | Uses Hermes's existing limbs, but adds clutter around the intake and stabilizers. |

G1 is the selected appearance. G2 and G3 remain historical alternatives;
do not implement them. The comparison sheet predates the selection and still
labels G1 as recommended. G3 does not grant two simultaneous pulls.
The G labels are separate from the selected A / Iron & Ink art direction and
C / Context ring HUD.

For G1, put the reel on a short pivoting yoke beside the intake. Keep the
two-jaw clamp broad enough to read at normal zoom. Its flat contact pad uses
the same disarm language as Nathaniel's backpack: clamp, brief amber glint,
then dark alien seams. Show the cable attached to both the reel and clamp
throughout the pull.

Use a thin, round, dark cable with a light edge. Tower connections remain
flat, segmented ground conduits. Neither should resemble a laser. The clamp
launch has a mechanical snap, without a weapon muzzle flash.

The launcher needs all-around coverage. Prototype a short guide arm which
turns around Hermes's outer footprint and brings the load to the front lip.
It must clear the stabilizers, cannon, and tower sockets. The sheet shows a
front-side pull only; rear and far-side routing are not solved by the image.
Resolve the guide routing within G1 before polishing the model. Report a
blockout failure rather than changing the selected mechanism or hiding an
aiming blind spot inside an otherwise circular recovery zone.

## Why this helps the game

Base placement becomes an economy decision. A good position lets Hermes
recover kills while Nathaniel fights or searches. A bad position leaves
valuable bodies beyond the zone or behind cover. The player gets a visible
reward for defending a useful position, without repeated collection taps.

Nathaniel keeps three jobs: gathering outside the base, reaching obstructed
bodies, and saving excess bodies before they decay. One winch prevents a
large wave from becoming instant income. Waiting bodies still flash and
dissolve, so the backpack remains useful even inside the base.

Start with automatic recovery as part of deployed Hermes. It needs no
resource cost, manual trigger, new context-ring slot, or settings toggle.
Do not reduce his cannon fire rate while he collects. The limits are where
the player deploys him, which bodies he can reach, and how fast he consumes.

## Zone and eligibility

Use the actual build-zone radius and Hermes's logical ground position. The
current radius is **240 logical points**, with the boundary included. Do not
use his 300-point cannon range, tower weapon coverage, sprite bounds, or a
second recovery ring. Changes to the build radius should change recovery
range with it.

For the first prototype, record eligibility when a collectible enemy dies:

- Hermes must be alive and deployed at that moment.
- The corpse's ground position must be inside or on his build boundary.
- The source of the killing damage does not matter.
- The body must still be inside the zone and unsecured when claimed. A
  Nathaniel grab that has not reached successful grip can be superseded.
- It must be visible to the player's side and have a clear pull route.

Use **no sweep of old corpses when deploying**. Deploying before a
fight is the decision this version rewards. A kill outside the zone remains
Nathaniel's job even if a tower fired the shot. Packing up clears unfinished
automatic candidates; a later deployment does not reclaim that old list.
This death-time eligibility rule is part of the new mechanic. Preserve it
through saves; do not infer eligibility from proximity after loading.

Require a direct clear route from the body to the winch's outer guide, with
enough width for the body, not just a thin ray for the hook. Then use a short
authored guide-to-intake path which clears Hermes's own parts. Check both
segments. Blocking buildings and solid scenery stop a pull; live units and
flat base conduits do not. Skip obstructed bodies and retry while they remain
eligible. Do not build rope pathfinding for the first version. A newly
blocked route releases the load safely. Fog must not reveal a hidden corpse
or its details through a hook or activity indicator.

## Recovery sequence

![Detect, fire, clamp, reel, crush, and consume](iron-and-ink/29-hermes-grapple-sequence.png)

The storyboard uses a boss shell to show the largest current collectible.
The same sequence applies to the smaller soldier bodies.

1. **Detect.** Choose one eligible, unsecured corpse. Prefer the armed body
   with the least time left. Break ties by distance, then stable entity ID.
   Safe bodies come after armed ones. Waiting creates no protected storage.
2. **Fire.** Reserve that one body and launch the clamp. Its decay timer
   continues. Reservation does not disarm it or credit resources.
3. **Clamp.** On successful contact, disable self-destruct permanently.
   Extinguish the warning at the contact glint. Expiry wins if contact and
   expiry occur on the same simulation step, matching the backpack rule.
4. **Reel.** Pull the secured body across the ground. Keep its shell and
   shadow visible. A short dust skid sells its weight; the cannon can track
   and fire at a different target.
5. **Crush.** Guide the body onto the intake lip. Fold it into its existing
   compact bundle between broad crusher plates. Hide the mesh change behind
   the plates, then release the clamp and retract it.
6. **Consume.** Accept the bundle once, remove it, and credit its stored
   resource value. Close the grille and show the contained furnace pulse.
   Return the winch to its ready pose before selecting another body.

Suggested starting cycle: 0.2 seconds to launch, 0.1 to clamp, 0.7 to reel,
0.3 to accept, and 0.2 to reset: about **1.5 seconds per body**. These are
animation and throughput targets to test. Use the same cycle for each corpse
kind initially; adjust the drag pose and intake compression for the boss.
Do not add a boss-only grapple upgrade or a second resource multiplier.

A waiting corpse can expire. A hook in flight can fail. Once clamped, the
body is safe even if Hermes is interrupted. The system automatically attempts
recovery; it does not guarantee that every eligible body will survive a burst
of deaths.

## Nathaniel, ownership, and the shared intake

One body has one owner: loose, reserved for a grab, held by Nathaniel, held
by the winch, or accepted by Hermes. Do not show a ground copy after a pull
starts, create an extra bundle, or award matter at hook contact.

**Hermes has collection priority when he can launch now.** He can take an
eligible loose body which Nathaniel is approaching or has reserved for a
grab that has not reached successful grip. Clear that body's old backpack
grab target, progress, and animation state atomically. Preserve unrelated
cargo and orders. Nathaniel can then collect another eligible body.

Resolve conflicts in this order: corpse expiry, a valid Hermes claim, then
Nathaniel's successful grip. Thus Hermes wins a claim against a grip that
would complete on the same simulation step. A body Nathaniel successfully
gripped in an earlier step stays his; Hermes cannot take held cargo.

Hermes can claim only when alive, deployed, ready to fire the winch, and
able to reach a visible eligible body. The shared intake must also allow a
new launch under the rules below. A busy or blocked Hermes does not reserve
waiting bodies or prevent Nathaniel from gathering them.

Once the hook has claimed a body, exclude it from Nathaniel's candidates so
he cannot restart or finish a stale grab. Claiming alone does not freeze
expiry. Hermes can supersede a nearly complete backpack grab and still lose
the corpse before hook contact; priority adds no grace period.

The chest has one intake. A delivery already in progress finishes first.
Do not fire a new hook while Nathaniel is delivering or waiting within intake
reach.
If Nathaniel reaches the intake during an automatic pull, finish that pull,
then give his delivery the next intake turn before firing another hook.
Do not reserve the furnace merely because he has a distant delivery order.
Waiting at the intake must not trap him; moving away cancels that wait.
His cargo remains in his rack until accepted. Empty it and credit its value
only at acceptance, using the existing delivery contract.

Collection priority and intake priority are separate: Hermes wins claims
for loose bodies; Nathaniel's held cargo gets the next intake turn. This
keeps manual delivery useful during busy waves and prevents two bundles
from entering the same opening. The grapple holds at most one body and has
no hidden buffer. Never apply a refund or resource bonus for choosing one
delivery method over the other.

## Interruptions and game modes

| Event | Proposed result |
| --- | --- |
| Corpse expires before contact | Cancel the claim, retract the empty hook, and let the existing dissolve finish. No reward. |
| Pack up or Hermes dies before contact | Release the reservation. The loose corpse keeps its remaining armed lifetime. |
| Pack up, Hermes death, or blocked route after contact | Drop the one held body at its current valid ground position. It stays permanently disarmed and can be collected by Nathaniel. No reward yet. |
| Interrupt after intake acceptance | Keep the one completed resource credit. Do not recreate the body or credit it again. |
| Pause | Freeze the job, corpse timers, and all corresponding motion. |
| Save and load | Restore ownership, expiry or permanent disarm, phase, and any credited state without replaying a reward. Preserve unclaimed corpses' eligibility for this deployment too; do not infer it from current proximity. Resume only with a valid deployed owner; otherwise release or safely drop as above. |
| Restart, scene change, or run end | Clear pending jobs and visual cables. Do not transfer an unfinished body into another run. |

Survival bosses fit the ongoing recovery loop. Campaign boss death currently
ends play immediately. Preserve that outcome: this proposal does not create
a victory collection window or an automatic boss payout. Those would need a
separate game-flow decision.

## HUD and feedback

The existing build outline communicates range. Keep it quiet during combat;
show it clearly when Hermes is selected or the player places a tower. No
permanent additional ring is needed.

Hermes's portrait continues to show his **combat target**, never a corpse.
The moving clamp and intake provide the main activity cues. If an off-screen
cue is useful, add one small read-only hook mark to his status area; it must
not become a button or change the portrait's select-and-focus behavior.
No new input is needed on touch, desktop, or web.

Use one local receipt when matter is accepted and the existing resource
counter changes. Keep the warning, contact glint, cable, and furnace pulse
different in shape and timing. Avoid repeated notice text for bodies behind
cover, screen flashes, camera shakes, or a long glowing beam.

## Production and first playtest

Build G1 from one drum, one swivel yoke, a short guide, two clamp jaws, and
the existing intake lip. Use rigid animation poses. Draw the cable between
anchors with a shallow bend when slack; no physics rope is required. Share
the corpse and compressed bundle art with the backpack. Keep the concept's
45-degree azimuth and 30-degree elevation for sprite studies.

Check the rear approach and all facing directions before refining surfaces.
At normal zoom, the player must distinguish a moving hook from a base conduit
and see that a clamped body has stopped flashing. Check sand, dark rubble,
several towers, and concurrent cannon fire. These sheets are not calibrated
Blender renders or tested animation.

The first playtest should compare a sparse fight, a burst of deaths, and a
mixed wave with many grunts. Record how many eligible corpses were consumed,
rescued by Nathaniel, blocked, or lost to expiry. Also measure how long his
delivery waits and whether the player can understand a missed recovery.

Watch for these failures:

- **Camping pays too well:** adjust the winch cycle or encounter pressure
  first. Do not silently cut corpse value or add a second radius.
- **Backpack feels unnecessary:** test bodies outside the zone, behind cover,
  and arriving faster than one winch can process.
- **Too much unexplained loss:** check visibility and launch-to-contact delay
  before changing the established self-destruct timer.
- **Unreadable combat:** reduce cable brightness and dust before reducing
  the clarity of the clamp and disarm cue.
- **Busy base blocks delivery:** enforce Nathaniel's next-intake priority.

Acceptance checks should cover the exact range boundary, all collectible
kinds, no grunt/spawner loot, Hermes pre-grip priority, protected held cargo,
an unavailable winch, simultaneous claims, contact at expiry, blocked
routes, manual delivery during a pull, teardown at each phase, Hermes death,
pause, save/load, and one resource credit per corpse. Check survival and
campaign outcomes separately. No runtime or device acceptance is claimed by
this design study.

Document validation for this concept pass checks local links, prompt records,
and the repository format rules. The implemented prototype has focused rule
and rendering checks; its timings and balance still need the playtests above.

## Existing implementation and source

The current [resource guide](../docs/resource-gathering.md) defines corpse
expiry, permanent disarm, backpack ownership, and physical delivery. The
[base guide](hermes-build-mode.md) defines Hermes's deployed form and links.
Current code gives Soldier, Gun Soldier, and Boss corpses 10 resources each;
this proposal reuses the corpse's value rather than hard-coding a new award.

Gameplay state belongs in the domain simulation. Presentation displays its
grapple, corpse, and intake states; animation callbacks must not create
resources. The original study changed no domain code, saved formats, or
production assets. The implementation now uses the saved side-winch rig,
domain recovery phases, and backward-compatible snapshot fields described in
the resource guide.

The two sheets were made with the built-in imagegen tool. Exact prompts and
reference images are recorded in [prompts.json](prompts.json).
