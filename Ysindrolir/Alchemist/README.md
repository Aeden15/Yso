# Alchemist

Current workspace snapshot: April 20, 2026.

Occultist is on hold. Primary active development is currently focused on Magi and Alchemist.

## What is here

- `Alchemical skill_reference chart`
  Canonical local reference for Alchemy, Physiology, and Formulation entries confirmed from the supplied screenshots/text only.

- `Core/formulation.lua`
  Shared Alchemist namespace/bootstrap, humour-balance state surface, and formulation helper state.

- `Core/formulation_phials.lua`
  `phiallist` parsing, phial-only tracking, validation, lookup, and readable display helpers.

- `Core/formulation_resolve.lua`
  Chart-driven formulation resolver used to keep delivery rules centralized.

- `Core/formulation_build.lua`
  Wield and action-string builder for thin Formulation aliases.

- `Triggers/Alchemy/Physiology/humour_balance.lua`
  Workspace-side humour-balance line handler for Physiology temper spend/ready tracking.

- `Triggers/Alchemy/Formulation/phiallist.lua`
  Workspace-side hook that routes `phiallist` lines into the shared phial parser.

- `Aliases`, `Triggers`, `Scripts`
  Workspace mirrors for the Alchemist XML organization.

## Current focus

- Physiology humour-balance lane tracking as its own ready/not-ready state.
- Formulation phial support that is delivery-aware and chart-driven.
- Thin alias bodies that route through shared helpers instead of duplicating delivery syntax.

## Notes

- The formulation layer is phial-only.
- Vials are ignored as substitutes.
- Missing phials fail safely and may request a `phiallist` refresh once.
- Manual alteration values remain user-driven for now. No potency/stability/volatility caps are enforced in this pass.
