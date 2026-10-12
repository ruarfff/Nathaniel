# Implement tech and research

Implement tech drops and collection, Hermes's research center, and a paused
upgrade menu for the Nathaniel survival demo. Deliver the complete gameplay
loop, readable production art, touch controls, save compatibility, and tests.

Work in `/Users/ruairi/dev/Nathaniel` on the current branch, verified as `main`
when this handoff was prepared. Preserve the existing uncommitted work,
including survival maps, actor rendering, resource effects, and concept files.
Recheck the checkout before editing. Follow `AGENTS.md`, prefix shell commands
with `rtk`, and leave commits, pushes, and pull requests to an explicit request.

## Design and scope

Read [Tech and research](research-and-tech.md) and inspect all three sheets:
[tech collection](iron-and-ink/30-tech-collection.png),
[research center](iron-and-ink/31-research-center.png), and
[research menu](iron-and-ink/32-research-menu.png).
Use that document for visual states, interaction details, and initial balance
values. Implement its four upgrade tracks as the starting demo catalog;
keep the proposed costs, yields, and modifiers centralized and easy to tune.
They are playtest defaults, not final balance commitments.

Two rules are confirmed: tech becomes spendable as soon as Nathaniel picks it
up, and researched upgrades last only for the current survival run. There is
no tech delivery step or permanent progression.

Target the survival demo. Preserve campaign behavior and save compatibility;
campaign progression and a wider HUD redesign are separate work. Keep the
existing campaign upgrade path if enabling research there would require new
campaign economy decisions. In survival, research replaces the old
matter-priced backpack purchase path.

Before changing code, read the [README task map](../README.md#find-the-right-files),
[domain guide](../scripts/domain/README.md),
[architecture](../docs/architecture.md), and
[current gathering rules](../docs/resource-gathering.md).
Read [saves](../docs/saves.md) for persistence,
[authoring](../docs/authoring.md) and the [Blender pipeline](../docs/blender-assets.md)
for assets, and [testing](../docs/testing.md) before playtesting. Inspect current
source; older concept sheets are appearance references, not runtime truth.

## Tech drops and collection

- On accepted grunt death, including spawner children, create one small tech
  pickup. On spawner death, create one larger core pack. Start with 1 and 8
  tech respectively. Preserve both explosion effects and the lack of matter
  corpses. Soldiers, gun soldiers, and bosses keep their current matter rules.
- Create the resource once in the domain death path, independently of effect
  callbacks. Drops never expire, dissolve, or use corpse warning/disarm state.
  They remain until collected or the run ends, including across save/resume.
- Keep drops nonblocking, inside bounds, and reachable. Use nearby valid
  ground if the death position is obstructed. Preserve the value if a valid
  placement must be deferred. Building placement must leave pickups accessible.
- Nathaniel automatically collects eligible tech within short, clear reach.
  Tapping a drop orders him to approach it by a valid route. Automatic pickup
  does not redirect his movement. Respect obstacles, cancellation, and a
  higher-priority corpse rescue or active matter grip/delivery.
- Use a separate short backpack collector and cassette. Full matter cargo
  does not prevent tech collection. Tech uses no corpse slot, capacity limit,
  unbanked inventory, furnace, or Hermes winch. Neither a center nor deployed
  Hermes is required for collection. Apply collection-reach upgrades to both
  matter and tech tools.
- At successful pickup, remove or consume the claimed drop and credit the
  tech wallet in one domain operation. Show the updated counter and a small
  quantity cue. An interrupted pickup before acceptance leaves the resource;
  interruption after acceptance cannot award or restore it again.
- Merge nearby unclaimed drops into quantity-preserving stacks in the same
  accessible local area. Bound visible stack geometry, not the saved value.
  Never merge across walls, include a claimed drop, or delete old tech to limit
  object count. Repeated death events, taps, and restore must not duplicate it.

All grunts earn tech, including spawned children. Treat sustained spawner
farming as a playtest case; do not silently make identical grunts worthless.

## Research center

Use Hermes's fourth build slot for Research. Start with the design's 10-matter
construction cost, normal build radius and footprint, and existing placement
checks, including survival route protection. Reserve the singleton when a build
is accepted so repeated inputs cannot create two pending centers. Release the
reservation if construction is cancelled without completing.

Only one living or pending center may exist. While it exists, show a clear
`Research built` state and prevent another purchase. Rebuilding after destruction
or recycling is allowed. Keep the center noncombatant and connected to deployed
Hermes by the existing broad ground conduit. Use normal owned-structure
targeting, damage, obstruction, and removal behavior.

Packing Hermes up recycles the center with the base and uses the existing
matter refund rule. Destruction gives no refund. Tech and learned ranks survive
either event within the run; research expenditure is never refunded. Rebuilding
restores menu access without resetting or repurchasing learned ranks.

A direct tap/click on a ready center opens Research from any selected-character
state; Nathaniel does not walk to it. If a context ring is open, the same tap
replaces that ring with Research rather than only dismissing it. During active
build placement, preserve placement input priority. Add no new portrait actions and preserve current
Hermes/Nathaniel selection, focus, delivery, and build controls.

## Upgrade menu and pause

Implement the menu as a native game interface. Show Research, Paused, the tech
balance, and Resume. Use Nathaniel, Hermes, and Defenses categories. Large screens
use a list beside a detail panel; narrow screens use a full-width list followed
by details, with Back returning to the list while remaining paused.

Each track shows its rank, exact current-to-next effect, and next cost. Selecting
a row only opens details. An explicit Research button buys one rank instantly,
updates the balance/effect, and leaves the menu open. Require a fresh input for
another rank. Support available, insufficient-tech, maximum-rank, and stale or
invalid purchase states. Keep the reason visible when purchase is disabled.

Use the four tracks and rank table in the design:

- Cargo capacity: preserve the existing 1/2/3 body capacities.
- Collection reach: preserve the existing 44/60/76 world-unit ranges.
- Shoulder cooling: change only Hermes's mobile laser cooldown.
- Reinforced plating: change maximum health for existing and newly built gun,
  laser, and heal towers; preserve existing health fractions when applying it.

Derive each rank from the original baseline. Restore, redeployment, rebuilding,
and reopening the menu must not compound modifiers. Preserve existing backpack
ranks from old saves and charge only for the next rank. In survival, remove
the old matter-purchase controls and reject that alternate purchase command.

Opening Research pauses the simulation immediately and consumes the opening
input. Freeze AI, waves, combat, projectiles, corpse deadlines, collection,
winches, and world effects. UI focus, scrolling, and feedback remain active.

Authorize purchases through a domain command that validates an active research
session, a living connected center, a valid next rank, and sufficient tech.
Deduction and application are atomic. The existing paused-upgrade rejection
must not be bypassed by briefly running the simulation or allowing all commands
while paused. Validate again when accepting the purchase, not only when drawing
the button.

Resume closes Research. Escape/system Back first leaves a narrow-screen detail
view, then closes the menu. Background taps never issue world commands or close
it accidentally. Release only the research pause: preserve any earlier pause,
application suspension, or game-over state. If the center or run becomes invalid,
close the menu safely without clearing other pause owners or spending tech.

Every action must work by touch. Use separated targets of at least 48 logical
UI pixels, safe-area margins, readable text, and visible focus. Keep essential
details out of hover tooltips. On short screens, scroll details above a stable
purchase control. Preserve supported orientations; portrait support is not a
new requirement of this task. Keyboard controls may supplement touch.

## State and assets

Keep resource quantities, ownership, learned ranks, singleton checks, purchase
rules, and gameplay modifiers in `scripts/domain/`. `GameSimulation` owns mutable
state and entity changes. Presentation handles hit testing, UI, art, and effects;
infrastructure handles file persistence. Extend existing systems instead of
creating a second resource simulation or UI-owned wallet.

Current entry points include `damage_entity()`, `step()`, `upgrade_gathering()`,
`place_tower()`, and `snapshot()`/`restore()` in `game_simulation.gd`;
world hit testing and view mapping in `game_app.gd`; build/menu controls in
`game_ui.gd`; and pointer/touch handling in `game_input.gd`. `spawn_resource()`
currently means an expiring corpse, so do not treat it as a generic tech drop.

Persist tech, ground stacks and their identifiers, learned ranks, center state,
and any in-progress collection ownership needed for exact restoration. Existing
saves load with zero tech and no drops while retaining purchased backpack ranks.
Their saved actor values already include upgrades; migration must not apply
those upgrades twice. Validate new kinds, unique IDs, quantities, rank bounds,
ownership, and singleton state at both snapshot restore and save-store loading.
Preserve established saved identifiers and storage identity. Save/resume retains
the same survival map and research. New Run and Retry reset the tech economy and
ranks; Retry still preserves its chosen map. Spare-life respawn retains progress.
Define a safe restored menu/pause state without persisting stale UI ownership.
Use temporary test storage, never live user saves.

Build the two tech shapes, small collector/cassette, folding center, shared tech
icon, and menu from the supplied art direction. Include pickup feedback, center
deployment/recycle/destruction, and the visible base connection. Use saved
Blender sources and the current export pipeline, which supports both sprites
and live models; choose the existing appropriate path for each asset. Preserve
native authored content. Concept PNGs are references, not runtime sprites or
screens to paste over gameplay.

Keep geometry simple, silhouettes clear, and glow contained. World effects
remain paused in the menu; a center scan can play after Resume. Check tech on
sand, grass, and rubble and the center beside other towers at actual game zoom.

## Validation and completion

Add focused regression coverage for:

- Both death sources, spawner children, exactly-once rewards, no expiry,
  full-cargo collection, obstacle reach, approach cancellation, priority against
  corpse rescue, stack quantity conservation, and save during pickup.
- Singleton and duplicate build inputs, invalid placement/route sealing,
  teardown refund, destruction, rebuild, connection ownership, and retained
  wallet/ranks when the center is removed.
- Every rank, affordability and maximum ranks, duplicate/stale purchase inputs,
  old-save rank migration, modifier non-compounding, existing/new tower health,
  and rejection of the replaced survival matter-upgrade path.
- Center hit testing, consumed opening input, narrow-screen Back, background
  input capture, full simulation freeze, permitted purchase while paused, and
  correct nested pause/app-suspension handling.
- New Run, Retry, spare-life respawn, save/resume, legacy saves, all four survival
  maps, and unchanged campaign behavior.

Run `rtk make format-check` and relevant targets: `test-gameplay`,
`test-resource-gathering`, `test-hermes-base`, `test-services`, `test-presentation`,
`test-content`, `test-survival`, `test-demo`, and applicable art checks. Extend
the tests to cover research; existing passing tests alone do not establish new
behavior. Run the full `rtk make test` suite. Use `rtk make help` for current
asset/export commands. Distinguish
pre-existing failures in this shared checkout from failures caused by this work.

Play the complete loop on desktop and exported web where available: kill both
drop types, collect while carrying matter, build the center, buy each upgrade,
resume combat, pack up, rebuild, save, and resume. Verify real mouse, keyboard,
and available touch input. Report untested iOS, gestures, or platforms plainly;
synthetic events and a successful export do not establish real touch behavior.

Capture gameplay-scale assets and the menu at desktop and small landscape-phone
sizes. Check long-run drop count and collection cost, and compare immediate
spawner kills with leaving a spawner alive. Update runtime resource, controls,
authoring, and save documentation with the implemented rules.

Finish with screenshots, changed files, check/export results, balance observations,
and remaining limits. Completion means the full loop is playable with finished
visuals, correct paused purchases and persistence, and usable touch controls.
