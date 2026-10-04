# Hermes build mode: anchor base

Hermes becomes the base. His torso lowers, his legs fold under him, and four
short stabilizers lock against the ground. His square head and chest intake
remain visible. A short cannon unfolds above the body and can turn while the
base stays still.

This is a visual proposal for the requested build mode, not a gameplay
implementation or a mechanically validated transformation.

![Deployed Hermes with three connected towers](iron-and-ink/05-hermes-anchor-base.png)

## Transformation

Keep the familiar head, intake, shoulder panels, and feet throughout the
change. Fold existing armor into a wider, lower body rather than enclosing
Hermes inside another building. The proposed deployed silhouette is about
twice his standing width and two-thirds his standing height. These are visual
targets, not new collision dimensions.

The head remains clear above the chest, with the cannon behind it. The gun
can track targets without turning the anchored body. Keep arm and cannon
parts simple enough to fold on a few rigid pivots. The exact packing of these
parts needs a Blender blockout; the images do not prove it will fit.

## Physical links

Each tower has a direct armored conduit to a visible socket on Hermes. Use
dark, flat, segmented links with ochre bands and a small ground shadow. Give
both ends a clear connector so a link reads as attached equipment.

Keep each conduit much narrower than a tower base. Leave it visible during
the whole deployed state. A few moving amber marks can show matter travelling
out during construction and back during reclamation. Stop those marks while
idle; the solid link remains visible without them. The large arrows in the
storyboard explain direction and do not need to appear in game.

Route links through clear ground and keep them away from character silhouettes
where possible. The three-link layout is a composition example, not a tower
limit. Link routing and depth sorting need a separate gameplay-scale check.

## Deploy and reclaim

![Six-stage deployment and reclamation sequence](iron-and-ink/06-hermes-deploy-recycle.png)

1. **Mobile:** Hermes walks in his normal biped form, with the cannon folded.
2. **Lock down:** lower the body, plant the stabilizers, and raise the cannon.
3. **Fabricate:** extend a conduit to the build location. The tower base forms
   first, then the pedestal rises and the folded head opens. Matter marks move
   away from Hermes.
4. **Hold:** Hermes stays planted and can fire at enemies. The complete tower
   remains physically connected.
5. **Reclaim:** fold the tower head and lower its pedestal. Show matter moving
   back to Hermes while the link stays attached. Reclaim the tower feet and
   base as well, then retract the conduit from its far end toward Hermes.
6. **Move out:** after every tower and link is gone, fold the anchors and gun,
   then raise Hermes into his walking form. Leave no foundation or scrap.

The storyboard follows one gun tower to make the sequence clear. Apply the
same reclamation sequence to the entire base. Towers should fold and compress
rather than burst apart, so teardown reads as deliberate recovery rather than
combat damage. Keep Hermes anchored until all returns are complete.

The sequence proposes visual order only. Transition duration, interruption
rules, and combat behavior during the transition remain undecided.

## Simple Blender construction

Use one shared body with separate rigid parts for the head, shoulder shells,
legs, anchors, and cannon. Start with a small set of key poses. Reuse the
existing tower base; animate its head folding and pedestal lowering. Build
the link from one short straight section, a bend, and two socket ends.

Preserve the 45-degree azimuth and 30-degree elevation used by the other
concepts. Make the anchored stance readable before adding wear or small
mechanisms. Keep terrain detail lower than in the scene illustration.

Test the wider base and links at actual game size, including towers behind
Hermes and units walking across a link. The current 128 by 128 prop canvas
may need a separate framing choice for deployed Hermes; preserve the ground
anchor and world scale rather than shrinking him to fit. No sprite, animation,
or in-game readability test has been completed for this proposal.
