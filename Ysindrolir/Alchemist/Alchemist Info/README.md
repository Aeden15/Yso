# Alchemist

Current workspace snapshot: April 21, 2026.

Occultist is on hold. Primary active development is currently focused on Magi and Alchemist.

## What is here

- `Alchemical skill_reference chart`
  Canonical local reference for Alchemy, Physiology, and Formulation entries confirmed from the supplied screenshots/text only.

- `Core/physiology.lua`
  Physiology-only balance/evaluate/homunculus state surface, target evaluate/vitals freshness, AK humour read-through helpers, and full skillchart humour-affliction pools.

- `Core/formulation.lua`
  Formulation-only namespace/bootstrap for phial skill usage, discovery, warning, timing, and action-builder helper state.

- `Core/group damage.lua`
  Alchemist party damage route for the existing `adam` toggle: owns route-specific affliction pressure, requires fresh evaluate on target swap, reads AK humour counts for legality, tempers through the direct humour lane, and spends BAL on hybrid `truewrack` only when both lanes have route value.

- `Core/duel route.lua`
  Alchemist duel lock-pressure route for the `aduel` toggle: owns route-specific pressure intent, keeps evaluate freshness AK-aligned, supports aurify EQ windows, uses conservative phlegmatic inundate and homunculus corrupt windows, and falls back to deterministic affliction wracks when hybrid value is not present.

- `Route instructions.txt`
  Checklist for keeping current and future Alchemist routes on the AK ownership/read-through model.

- `alchemist_group_damage.lua`
  Root loader shim so the shared route bootstrap can require `Core/group damage.lua` despite the canonical file name containing a space.

- `alchemist_duel_route.lua`
  Root loader shim so the shared route bootstrap can require `Core/duel route.lua` despite the canonical file name containing a space.

- `Core/formulation_phials.lua`
  `phiallist` parsing, phial-only tracking, validation, lookup, and readable display helpers.

- `Core/formulation_resolve.lua`
  Chart-driven formulation resolver used to keep delivery rules centralized.

- `Core/formulation_build.lua`
  Wield and action-string builder for thin Formulation aliases; thrown phial formulations require explicit `ground` or a direction.

- `Triggers/Alchemy/Physiology/humour_balance.lua`
  Workspace-side Physiology live handler for evaluate/vitals freshness, temper/wrack/truewrack balance effects, homunculus corrupt, owner-specific homunculus stance, ready lines, and AK-aligned humour-eat lines.

- `Triggers/Alchemy/Formulation/phiallist.lua`
  Workspace-side hook that routes `phiallist` lines into the shared phial parser.

- `Aliases`, `Triggers`, `Scripts`
  Workspace mirrors for the Alchemist XML organization.

## Current focus

- Physiology humour intel is AK-owned; Yso keeps only evaluate freshness/vitals and reads `ak.alchemist.humour` for current-target planning.
- Alchemist group damage route under `adam`, using `evaluate <target> humours`, `temper <target> <humour>`, useful `truewrack <target> <humour> <affliction>`, and deterministic `wrack <target> <affliction>` fallback.
- Alchemist duel route under `aduel`, with lock-pressure defaults (`paralysis`, `asthma`, `impatience`), aurify finish windows, conservative `inundate <target> phlegmatic`, and conservative `homunculus corrupt <target>` timing.
- Physiology humour-balance lane tracking as its own ready/not-ready state.
- Formulation phial support that is delivery-aware, chart-driven, and separated from Physiology humour logic.
- Physiology humour pools match the skillchart for choleric, melancholic, phlegmatic, and sanguine.
- Thin alias bodies that route through shared helpers instead of duplicating delivery syntax.

## Notes

- The formulation layer is phial/use-only and does not own humour or affliction-pressure logic.
- Vials are ignored as substitutes.
- Missing phials fail safely and may request a `phiallist` refresh once.
- Thrown phial formulations require explicit `ground` or a direction.
- Group damage owns its default affliction pressure list; Physiology only owns the legal humour-affliction pools.
- Manual alteration values remain user-driven for now. No potency/stability/volatility caps are enforced in this pass.
- Live Physiology XML triggers use rolled-up pronoun regexes rather than per-pronoun/per-humour trigger copies.
- Paralysis is gated by AK's current-target sanguine count (`>= 2`), and target swaps require a fresh `evaluate <target> humours` before humour-state planning resumes.
