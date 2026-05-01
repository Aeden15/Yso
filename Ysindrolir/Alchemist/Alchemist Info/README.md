# Alchemist

Current workspace snapshot: April 26, 2026.

Primary active development is focused on Magi and Alchemist.

## What is here

- `Alchemical skill_reference chart`
  Canonical local reference for Alchemy, Physiology, and Formulation entries confirmed from the supplied screenshots/text only.

- `Core/physiology.lua`
  Physiology-only balance/evaluate/homunculus state surface, target evaluate/vitals freshness, AK humour read-through helpers, and full skillchart humour-affliction pools.

- `Core/formulation.lua`
  Formulation-only namespace/bootstrap for phial skill usage, discovery, warning, timing, and action-builder helper state.

- `Core/group damage.lua`
  Alchemist party damage route for the existing `adam` toggle. It now builds lane-combo payloads (`free/eq/class/bal`) instead of returning the first single legal action.

- `Core/duel route.lua`
  Alchemist duel lock-pressure route for `aduel`, now using the same lane-combo payload model and shieldbreak-as-EQ-slot behavior as group damage.

- `Aurify route.lua`
  Real Aurify route module (`alchemist_aurify_route`) for bleed pressure into Aurify windows, exposed by alias `bleed`.

- `Route instructions.txt`
  Checklist for keeping current and future Alchemist routes on the AK ownership/read-through model.

- `alchemist_group_damage.lua`
  Root loader shim so the shared route bootstrap can require `Core/group damage.lua` despite the canonical file name containing a space.

- `alchemist_duel_route.lua`
  Root loader shim so the shared route bootstrap can require `Core/duel route.lua` despite the canonical file name containing a space.

- `alchemist_aurify_route.lua`
  Root loader shim so the shared route bootstrap can require `Aurify route.lua`.

- `Core/formulation_phials.lua`
  `phiallist` parsing, phial-only tracking, validation, lookup, and readable display helpers.

- `Core/formulation_resolve.lua`
  Chart-driven formulation resolver used to keep delivery rules centralized.

- `Core/formulation_build.lua`
  Wield and action-string builder for thin Formulation aliases; thrown phial formulations require explicit `ground` or a direction.

- `Core/formulation_chart.lua`
  Display-only `fchart` pop-up chart for quick Formulation skill/effect lookup. It does not participate in phial crafting, compound resolution, permanent phial policy, or route automation.

- `Triggers/Alchemy/Physiology/humour_balance.lua`
  Workspace-side Physiology live handler for evaluate/vitals freshness, temper/wrack/truewrack balance effects, homunculus corrupt, owner-specific homunculus stance, ready lines, and AK-aligned humour-eat lines.

- `Triggers/Alchemy/Formulation/phiallist.lua`
  Workspace-side hook that routes `phiallist` lines into the shared phial parser.

- `Triggers/Alchemy/Alchemy/phlogistication_start.lua`
- `Triggers/Alchemy/Alchemy/phlogistication_expire.lua`
- `Triggers/Alchemy/Alchemy/vitrification_start.lua`
- `Triggers/Alchemy/Alchemy/vitrification_expire.lua`
  Workspace-side trigger scripts for Alchemy debuff state (`phlogistication` and `vitrification`) routed through `Yso.alc.phys.set_alchemy_debuff`.

- `Aliases`, `Triggers`, `Scripts`
  Workspace mirrors for the Alchemist XML organization.

## Current focus

- Physiology humour intel is AK-owned; Yso keeps evaluate freshness/vitals and reads `ak.alchemist.humour` for current-target planning.
- Group, duel, and aurify routes all use lane-combo payload builders with explicit `direct_order` support for non-queue mode.
- Normal temper pressure in group, duel, and aurify routes folds into one configurable class queue payload:
  `temper <target> <humour>&&evaluate <target> humours&&educe <metal> <target>&&wrack/truewrack ...`.
  Instant-kill branches keep their own clear-style queue setting and default to `addclearfull`.
- Shieldbreak is now an EQ slot (`educe copper <target>`) that still allows legal class/bal follow-through in the same payload, with pronoun-inclusive AK shield parse coverage and callable fallback checks via `Yso.shield(target)` (plus `.up/.set` compatibility).
- Aurification execute window is treated as an EQ finisher with default gate `hp <= 60` and `mp <= 60` (both required), and installs through `QUEUE ADDCLEARFULL`.
- `bleed` toggles `alchemist_aurify_route`.
- Reave execute is now a conservative instant-kill planner addition after Aurification, requiring trusted evaluate intel, humour balance ready, all four humours tempered, and no self channel-blocking hinder states; it also installs through `QUEUE ADDCLEARFULL`.
- Physiology humour-balance lane tracking as its own ready/not-ready state.
- Physiology now tracks active Alchemy timed debuffs per target with fallback expiry (`phlogistication` and `vitrification`) via:
  `set_alchemy_debuff`, `alchemy_debuff_active`, and `can_use_alchemy_debuff`.
- Formulation phial support that is delivery-aware, chart-driven, and separated from Physiology humour logic.
- Display-only `fchart` Formulation chart for quick lookup of confirmed skill names and simple effects.
- Physiology humour pools match the skillchart for choleric, melancholic, phlegmatic, and sanguine.
- Thin alias bodies that route through shared helpers instead of duplicating delivery syntax.

## Notes

- The formulation layer is phial/use-only and does not own humour or affliction-pressure logic.
- The `fchart` helper is display-only and should remain separate from phial crafting, compound resolution, permanent phial assignment, and route automation.
- Vials are ignored as substitutes.
- Missing phials fail safely and may request a `phiallist` refresh once.
- Thrown phial formulations require explicit `ground` or a direction.
- Group damage owns its default affliction pressure list; Physiology only owns the legal humour-affliction pools.
- Manual alteration values remain user-driven for now. No potency/stability/volatility caps are enforced in this pass.
- Live Physiology XML triggers use rolled-up pronoun regexes rather than per-pronoun/per-humour trigger copies.
- Paralysis is gated by AK's current-target sanguine count (`>= 2`), and target swaps require a fresh `evaluate <target> humours` before humour-state planning resumes.
- `educe salt` is treated as a post-shieldbreak/post-execute self-purge EQ action and is blocked while `stupidity` is present.
- TODO: Legacy-driven self-affliction handling should prioritize or reprioritize `stupidity` before relying on Salt.

## Patch Notes (April 27, 2026 - Homunculus Corrupt Parser Fix)

- Replaced invalid PCRE-style fallback parsing in `Triggers/Alchemy/Physiology/humour_balance.lua` with valid Lua patterns for possessive target lines:
  - `Target's body, corrupting ...`
  - `Target' body, corrupting ...`
- Synced the same parser fix into embedded `Ysindrolir/mudlet packages/Yso system.xml` so source and package behavior stay in parity.
- Added regression coverage in `Yso/Tests and rebuilds/test_alchemist_group_damage.lua` for possessive homunculus-corrupt lines to ensure parsed target ownership is correct.
- Diagnostic observation: Legacy `Dor` empty script container in `Legacy V2.1.xml` was intentionally left unchanged in this pass.

## Patch Notes (April 28, 2026 - Route Reset Repair)

- Added shared route reset cleanup across group damage, duel, and Aurify so
  start/stop, target swap, target clear/slain, and AK reset events clear stale
  busy/waiting/last-attack/evaluate/homunculus state without disabling active
  routes.
- Humour cooldown failure now marks humour balance unavailable, clears
  pending/staged class state, and clears the server class queue.
- `wrack` and `truewrack` are now treated as BAL-lane commands by generic queue
  inference, while route payloads continue to set lanes explicitly.
