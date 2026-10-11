# Implement Hermes's automatic corpse recovery

Implement the selected **G1 / Side winch** in this checkout of Nathaniel:
`/Users/ruairi/dev/Nathaniel`. The branch was `main` when this handoff was
prepared on 2026-10-11. Work on this branch, preserve existing local changes,
and inspect the current source before editing. If the checkout has changed,
report that discrepancy rather than switching branches or resetting files.
Create no commit, push, or pull request unless the user requests it.

## Read first

Read the repository `AGENTS.md` and the
[selected design](hermes-auto-consume.md). That design is the behavior
contract, including eligibility, claim priority, shared intake, interruptions,
and save continuity. The two visual references are
[grapple options](iron-and-ink/28-hermes-grapple-options.png), **G1 only**, and
[the recovery sequence](iron-and-ink/29-hermes-grapple-sequence.png).
The comparison image's “recommended” label predates the user's selection.

Before changing simulation and saves, read
[domain rules](../scripts/domain/README.md),
[resource gathering](../docs/resource-gathering.md), and
[save compatibility](../docs/saves.md). Before changing art or effects, read
[authoring](../docs/authoring.md) and the
[Blender pipeline](../docs/blender-assets.md). Use current code and the README
task map for implemented behavior; older concept notes may describe proposals.

## Required behavior

Deployed Hermes automatically claims a collectible corpse, fires a physical
clamp, disables self-destruct on contact, reels the body into his chest,
compresses it, and consumes it. Use one side winch and one active body. Keep
his cannon, combat targeting, and fire rate independent of collection.

- Soldier, Gun Soldier, and Boss are collectible. Grunt and spawner deaths
  retain their existing explosions and give no matter. Reuse each corpse's
  stored value; add no multiplier, new loot kind, or recovery cost.
- Record eligibility at death while Hermes is alive and deployed, using the
  actual build radius, ground coordinates, and inclusive boundary. There is
  no sweep of older bodies on deployment. Preserve candidate eligibility
  for the current deployment through save/load; pack-up clears it.
- Recheck visibility, availability, range, and body clearance before launch.
  Use a direct route to the outer guide and a short authored route to the
  intake. Skip blocked bodies; avoid rope pathfinding. The design defines
  which obstacles stop a pull and how an interrupted body drops.
- Choose the armed body nearest expiry, then distance, then stable ID.
  Disarmed bodies follow armed bodies. Waiting bodies are not protected.
- Decay continues through reservation and launch. Successful clamp contact
  permanently disarms; exact expiry wins. Only intake acceptance awards
  matter, exactly once. Reuse the existing bundle and furnace feedback.
- Start with the design's approximately 1.5-second cycle. Keep timings named
  and adjustable. They are initial tuning values, not tested balance.

## Hermes has priority before grip

Resolve a contested body in this order: expiry, a valid Hermes claim, then
Nathaniel grip completion. Hermes can atomically supersede Nathaniel's
approach or pre-grip reservation, including a grip which would complete on
that same step. A body successfully gripped in an earlier step remains
Nathaniel's; Hermes cannot take held cargo.

Claim only if Hermes can launch now: alive, deployed, winch ready, visible
eligible body, clear route, and no manual intake delivery or nearby delivery
wait preventing launch. Mere eligibility must not block Nathaniel while
Hermes is busy. Candidate filtering must allow takeover of a pre-grip
reservation, rather than rejecting every reserved corpse.

When Hermes takes over, clear only the obsolete grab target, progress, and
animation state for that body. Preserve unrelated cargo and orders. Exclude
the body from Nathaniel's candidates immediately. Do not let a stale grab
complete after the takeover. Keep expiry running, even if that means the
hook loses a body which Nathaniel was about to secure.

## Intake and interruption

Keep collection priority separate from intake priority. Finish a manual
delivery already in progress. If Nathaniel arrives during a pull, finish
that pull and serve his held cargo before launching again. A distant delivery
order does not reserve the furnace, and Nathaniel can leave while waiting.
Manual delivery still works with mobile or deployed Hermes.

Implement every interruption in the design's table. Before contact, release
the armed body with its remaining lifetime. After contact but before
acceptance, drop it safely and permanently disarmed. After acceptance,
retain the single credit and never recreate the body. Pause freezes both
rules and motion. Clear pending work on scene/run transitions.

Save and validate pending eligibility, exclusive ownership, progress,
remaining expiry, disarm, and consumption state without duplicate rewards.
Use backward-compatible defaults for saves without this mechanic and retain
the project's documented save identifiers. Survival continues normally;
campaign victory remains immediate, without an added collection window or
automatic boss payout. Hermes death still ends the run.

## Integration and appearance

Keep mutable gameplay state and arbitration in `GameSimulation` and the
domain layer. Use simulation methods for entity changes so combat indexes
stay correct. Presentation must not award resources from animation callbacks.
Inspect `battlefield_rules.gd`, `game_simulation.gd`, `world_navigation.gd`,
and save validation before choosing the smallest suitable integration.

Inspect `hermes_view.gd`, `resource_gathering_view.gd`, and `world_effects.gd`
for display integration. Add the reel, yoke, guide, and two-jaw clamp to the
saved Blender sources and regenerate through the normal pipeline. Keep
mobile Hermes's existing silhouette and shoulder laser. Use a narrow physical
cable, an amber contact cue, a short ground drag, and the contained furnace
pulse. Keep tower conduits visually distinct.

Block out rear and side retrieval before polishing. G1 must clear Hermes's
anchors, cannon, and tower sockets; retain G1 rather than silently substituting
the crane. Show only one copy of each body or bundle at every phase.

This is passive behavior. Preserve the selected HUD and input rules: no new
button or ring slot, and the portrait continues to show Hermes's combat
target. Update the implemented resource guide and relevant authoring/save
documentation to describe the final behavior.

## Verification and completion

Add focused tests for inclusive range, death-time eligibility, no old-body
sweep, all collectible kinds, no grunt/spawner loot, candidate order, and
blocked or hidden targets. Cover the contested claim order, prior-step
protected grip, busy winch, stale grab cancellation, expiry at contact,
manual delivery during a pull, and one credit per body.

Test teardown and death before contact, after contact, and after acceptance;
pause; restart; waiting-candidate and active-job save round trips; older-save
defaults; and separate survival/campaign outcomes. Extend existing suites
where practical rather than creating a second collection model for tests.

Run the relevant Make targets, prefixed with `rtk`:

- `rtk make format-check`
- `rtk make test-resource-gathering test-gameplay test-services`
- `rtk make test-hermes-base test-presentation test-art`
- `rtk make test`

Use the existing art capture targets, such as `art-hermes-base` and
`art-resource-gathering`, extending them to exercise the new sequence.
Inspect captures at normal gameplay zoom: all approach directions, a boss,
several connected towers, simultaneous cannon fire, warning cancellation,
Nathaniel delivering, and pack-up during a pull.

Read [testing](../docs/testing.md) and [verification](../docs/verification.md)
before playtests and platform claims. Export and run supported targets as
required by the repository. Report real input checks separately from
synthetic tests, builds, and captures; name untested platforms or gestures.

Finish with the implemented behavior, relevant changed files, checks run,
capture paths, and any remaining limitation. The work is complete when the
selected side winch is visible in gameplay and the recovery, priority,
interruption, and persistence rules pass verification.
