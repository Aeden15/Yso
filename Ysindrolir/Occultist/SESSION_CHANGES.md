# Yso Occultist — Session Change Log
Date: 2026-04-17

---

## Sync Status

| Step | Status |
|---|---|
| Canonical `.lua` sources edited | ✅ Done |
| `xml/` mirrors refreshed | ✅ Done (bash copy) |
| `Yso system.xml` rebuilt | ⚠️ **Pending — must run on Windows** |

### To complete sync (run from `Ysindrolir/Occultist/`):
```
lua tools/rebuild_yso_system_xml.lua
```
or
```
.\tools\rebuild_yso_system_xml.ps1
```

---

## Files Changed This Session

### Core

| Canonical Source | xml Mirror | Change |
|---|---|---|
| `modules/Yso/Core/queue.lua` | `xml/yso_queue.lua` | Refactor + `_now()` pcall fix (see below) |
| `modules/Yso/Core/modes.lua` | `xml/yso_modes.lua` | Bug fix: `M.toggle()` silent failure in party mode |

### Combat

| Canonical Source | xml Mirror | Change |
|---|---|---|
| `modules/Yso/Combat/parry.lua` | `xml/parry.lua` | Bug fix: dead score branch in `_restore_finished()` |
| `modules/Yso/Combat/offense_core.lua` | *(no mirror — direct)* | Bug fix: inverted success check in `Core.off()` |
| `modules/Yso/Combat/offense_driver.lua` | *(no mirror — direct)* | Bug fix: three silent stub functions ignored arguments |

### Occultist

| Canonical Source | xml Mirror | Change |
|---|---|---|
| `modules/Yso/Combat/occultist/companions.lua` | `xml/yso_occultist_companions.lua` | Bug fix: `getEpoch()` missing pcall in `_now()` |
| `modules/Yso/Combat/occultist/softlock_gate.lua` | `xml/softlock_gate.lua` | Bug fix: `_support_instill()` keep_paralysis condition inverted |
| `modules/Yso/Combat/occultist/offense_helpers.lua` | `xml/yso_occultist_offense.lua` | Bug fix: `pcall(Q.emit)` discarded emit return value |

### Routes

| Canonical Source | xml Mirror | Change |
|---|---|---|
| `modules/Yso/Combat/routes/occ_aff.lua` | *(no mirror — direct)* | Bug fixes: empty elseif blocks, `_burst_ready()` gate bypass, `explain()` discarding payload |
| `modules/Yso/Combat/routes/group_damage.lua` | *(no mirror — direct)* | Bug fix: stale `eq_category` after avoid_overlap; removed dead `_worm_mark` / `_worm_mark_used` / `_worm_is_active` |
| `modules/Yso/Combat/routes/lock.lua` | *(no mirror — direct)* | Bug fix: stub route spinning forever (missing `not_implemented` stop entry) |
| `modules/Yso/Combat/routes/finisher.lua` | *(no mirror — direct)* | Bug fix: same as lock.lua |

---

## All Bugs Fixed (13 total)

### Pass 1

1. **`offense_core.lua`** — `Core.off()` returned success when the route failed to stop (inverted boolean check).

2. **`offense_driver.lua`** — `D.set_policy()`, `D.set_active()`, and `D.tick()` ignored their arguments entirely; all three were dead stubs.

3. **`occ_aff.lua`** — Empty `elseif` blocks left eq/bal lanes unguarded; opposing route could fill the slot. Fixed with `__hold__` sentinel (stripped before emission).

4. **`occ_aff.lua`** — `_burst_ready()` early-return bypassed `_cleanse_ready` gate check on cleanseaura / truename commands.

5. **`occ_aff.lua`** — `explain()` called `pcall(A.build_payload)` but never captured the second return value, so the payload was always lost.

### Pass 2

6. **`lock.lua` / `finisher.lua`** — Stub routes spun the loop forever because `not_implemented` was absent from `alias_loop_stop_details`.

7. **`parry.lua`** — `_restore_finished()` used `_self_score("damagedleftleg")` which can never match the score table (key mismatch). Replaced with `_self_has_aff()`.

8. **`modes.lua`** — `M.toggle()` in party mode returned `false` silently with no feedback. Now echoes an explanatory message.

9. **`queue.lua`** — Writhe check at load used `Yso.self` directly before other modules had loaded. Fixed with `tempTimer(0, ...)` deferral.

### Pass 3

10. **`companions.lua`** — `getEpoch()` called without pcall in `_now()`, inconsistent with every other module.

11. **`offense_helpers.lua`** — `pcall(Q.emit, payload)` captured only the pcall success flag, not `Q.emit`'s own return. Caller always got `true` even when emit rejected the payload.

12. **`softlock_gate.lua`** — `_support_instill()` condition was `== false` so nil (unconfigured) defaulted to instilling paralysis. Flipped to `== true` so paralysis-keeping is an explicit opt-in.

13. **`group_damage.lua`** — (a) `_worm_mark`, `_worm_mark_used`, `_worm_is_active` were local functions never called anywhere — dead code removed. (b) `p.eq_category` stayed set after `avoid_overlap` cleared `p.eq`, leaking a stale category into `payload.meta` and `explain()` output.

### queue.lua Refactor (same session)

Structural cleanup only — no behaviour changes:
- Added section dividers (Locals / Constants / Internal helpers / Public API sections / Raw QUEUE wrappers / Startup initialisation)
- `_now()` now wraps `getEpoch()` in pcall, consistent with all other modules
- `_lane_key()` moved into Internal helpers section with a clarifying comment on the Achaea queue-type alias strings
- `_QTYPE_MAP` and `_VALID_WAKE_LANES` given explanatory comments
- `_coerce_stage_args()` documented (swap/infer compat behaviour)
- `Q.push` annotated as alias for `Q.stage`
- `Q.mark_payload_fired` converted from bare assignment to a proper documented public function

---

## Sync Workflow (for reference)

```
Edit canonical source in modules/Yso/...
        ↓
lua tools/refresh_xml_mirrors.lua      ← copies sources → modules/Yso/xml/ mirrors
        ↓
lua tools/rebuild_yso_system_xml.lua   ← embeds mirrors into Yso system.xml (Windows only)
```

Direct-promoted files (no mirror step needed):
- `Combat/offense_core.lua`
- `Combat/offense_driver.lua`
- `Combat/routes/occ_aff.lua`
- `Combat/routes/group_damage.lua`
- `Combat/routes/lock.lua`
- `Combat/routes/finisher.lua`

---

## Recovery + Pulse Centralization (2026-04-17 Evening)

- Restored `mudlet packages/Yso system.xml` from known-good commit `b7eca0f` and rebuilt on Windows.
- Fixed corruption root cause: `0x00` control byte in `modules/Yso/xml/softlock_gate.lua` was removed by regenerating mirrors from canonical source before rebuild.
- Hardened `tools/rebuild_yso_system_xml.lua`:
  - Fails fast if any source or output contains forbidden control bytes (`<0x20` except TAB/LF/CR).
  - Rewrites pulse wake trigger scripts to use centralized line-event handling.
- Hardened `tools/rebuild_yso_system_xml.ps1`:
  - Runs strict post-build XML parse and fails if package XML is not valid.
- Added centralized pulse line-event handling in `modules/Yso/Core/wake_bus.lua`:
  - Handles all pulse wake-line sources (`eq/bal recovered/blocked/queued/run`, entity ready/down/missing).
  - Uses clean-line `Yso.util.cecho_line(...)` output with lane+state wording (`[Yso] EQ`, `[Yso] BAL blocked`, `[Yso] ENT ready`, etc.).
  - Gags original matched lines when called from package triggers.
  - Uses lane colors (EQ green, BAL DarkOrange, ENT blue/cyan).
