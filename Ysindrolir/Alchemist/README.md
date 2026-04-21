# Alchemist

Current workspace snapshot: April 21, 2026.

Occultist is on hold. Primary active development is currently focused on Magi and Alchemist.

## What is here

- `Alchemical skill_reference chart`
  Canonical local reference for Alchemy, Physiology, and Formulation entries confirmed from the supplied screenshots/text only.

- `Core/formulation.lua`
  Shared Alchemist namespace/bootstrap, humour-balance/evaluate/homunculus state surface, Physiology target humour intel, and formulation helper state.

- `Core/group damage.lua`
  Alchemist party damage route for the existing `adam` toggle: evaluates dirty humour intel, tempers through the direct humour lane, and spends BAL on hybrid `truewrack`.

- `alchemist_group_damage.lua`
  Loader shim so the shared route bootstrap can require the route despite the canonical file name containing a space.

- `Core/formulation_phials.lua`
  `phiallist` parsing, phial-only tracking, validation, lookup, and readable display helpers.

- `Core/formulation_resolve.lua`
  Chart-driven formulation resolver used to keep delivery rules centralized.

- `Core/formulation_build.lua`
  Wield and action-string builder for thin Formulation aliases.

- `Triggers/Alchemy/Physiology/humour_balance.lua`
  Workspace-side Physiology live handler for evaluate, temper, wrack/truewrack, homunculus corrupt, ready lines, exact vitals, and dirtying events.

- `Triggers/Alchemy/Formulation/phiallist.lua`
  Workspace-side hook that routes `phiallist` lines into the shared phial parser.

- `Aliases`, `Triggers`, `Scripts`
  Workspace mirrors for the Alchemist XML organization.

## Current focus

- Physiology humour intel with separate inferred live counts and steady evaluate counts.
- Alchemist group damage route under `adam`, using `evaluate <target> humours`, `temper <target> <humour>`, and `truewrack <target> <humour> <affliction>`.
- Physiology humour-balance lane tracking as its own ready/not-ready state.
- Formulation phial support that is delivery-aware and chart-driven.
- Thin alias bodies that route through shared helpers instead of duplicating delivery syntax.

## Notes

- The formulation layer is phial-only.
- Vials are ignored as substitutes.
- Missing phials fail safely and may request a `phiallist` refresh once.
- Manual alteration values remain user-driven for now. No potency/stability/volatility caps are enforced in this pass.
- Live Physiology XML triggers use rolled-up pronoun regexes rather than per-pronoun/per-humour trigger copies.
- Paralysis is gated only by confirmed steady sanguine count from evaluate (`>= 2`), not inferred live temper count.
