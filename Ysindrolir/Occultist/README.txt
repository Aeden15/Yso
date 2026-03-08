Update (2026-03-08) — Bootstrap load order, Integration path, predict_cure fine-tune
----------------------------------------------------------------------------
Changes applied to Yso system.xml and disk modules:

Bootstrap / package.path:
- Fixed critical load order bug: bootstrap.lua was loaded LAST in _entry.lua, meaning
  package.path was not configured when all other safe_require() calls ran. Moved bootstrap
  to the first safe_require in _entry.lua.
- Added root/Yso/?.lua and root/Yso/?/init.lua to package.path in bootstrap.lua, fixing
  require("Integration.mudlet") which lives at modules/Yso/Integration/mudlet.lua.
- Synced both disk bootstrap.lua and the embedded Bootstrap script in Yso system.xml.

occ_aff_burst.lua (XML sync):
- Added missing _ensure_registered() local function to the embedded XML copy — the XML
  only had the group_damage version, scoped locally to that script.
- Added missing AB.automation_toggle() to the embedded XML copy. The ^aff$ alias calls
  this function; without it the alias printed "module not loaded".
- AB.toggle() now calls _ensure_registered() in the XML (matching the disk version).

Cleanseaura alias:
- Changed regex from ^cleanse(?:\s+(\w+))?$ to ^cleanse\s*(.*)$ for robustness. The old
  non-capturing group was mutating in live Mudlet, causing the target to land in matches[3]
  instead of matches[2].
- Added Yso.get_target() as the first fallback when no arg is provided (before AK, before
  global target), matching the Readaura alias pattern.

occie_random_generator.lua:
- Added ak/ak.occie/ak.occie.aura initialization guards and field defaults (physical,
  mental, unknownparse) to the disk version, matching the XML version.

yso_predict_cure.lua fine-tuning:
- Added time decay: P.cfg.decay_after_sec (default 60s). After no observation for this
  duration, the target's distribution is wiped on the next update.
- Added C.clear(who) public API and auto-clear on target switch in C.observe().
- Per-affliction fusion weights: P.cfg.fusion_per_aff_bayes / fusion_per_aff_mc tables.
  Unlisted afflictions default to P.cfg.fusion_weight_bayes (0.5). MC weight derived as
  (1 - bayes_weight) unless overridden.
- AK score 0 zeroing: after every blend step in B.update and M.update, any affliction
  with AK score == 0 is set to probability 0 and the distribution is renormalized.
- Monte Carlo now uses proper particle sampling (200 particles) instead of direct weight
  blending.
- Lifecycle clearing: P.wire() now hooks sysTargetDeath, sysTargetDied, gmcp.Char.Room,
  and sysInstallPackage. Target prediction state is cleared on any of these events.

Audit notes:
- All disk module pairs verified identical via fc.exe:
  • xml/occ_aff_burst.lua == Combat/routes/occ_aff_burst.lua
  • xml/group_damage.lua == Combat/routes/group_damage.lua
  • xml/yso_orchestrator.lua == Core/orchestrator.lua
  • xml/yso_offense_coordination.lua == Combat/offense_driver.lua
- GD.tick (no backslash) confirmed in both disk and XML.
- "smoke" spelling confirmed correct everywhere (no "smole" typo).
- cecho newlines confirmed as \n (not \\n) in api_stuff and XML.

Update (2026-03-08) — Aff alias consolidation + occ_aff_burst module toggle fix
----------------------------------------------------------------------------
Changes applied to the superseding Yso systems.zip workspace and bundled Mudlet exports:
- Moved the `^aff$` toggle implementation into the `occ_aff_burst` route module as `AB.automation_toggle()`.
- Kept the Yso system `Affliction automation` alias as a thin wrapper that now calls the route module instead of duplicating toggle logic inline.
- Removed duplicate `^aff$` aliases from the standalone / bundled `Yso offense aliases.xml` package so `^aff$` now has a single intended toggle entrypoint.
- Added self-registration to `occ_aff_burst` via `_ensure_registered()` and wired `AB.toggle()` to call it, so the route can register with `Yso.Orchestrator` even though `occ_aff_burst` loads before `yso_orchestrator` in `_entry.lua`.

Audit notes:
- Re-synced the patched `occ_aff_burst.lua` source into the xml mirror and bundled `Yso system.xml`.
- XML parse check passed for the patched `Yso system.xml` and `Yso offense aliases.xml`.
- Lua syntax check passed for both `modules/Yso/Combat/routes/occ_aff_burst.lua` and `modules/Yso/xml/occ_aff_burst.lua`.
- Verified the bundled `Yso offense aliases.xml` no longer contains any `^aff$` alias entries.

Update (2026-03-08) — Mode autoswitch idle fix + combat-default fallback
-----------------------------------------------------------------------
Changes applied to the ZIP workspace and the in-zip Mudlet XML export (Ysindrolir/mudlet_packages/Yso system.xml):
- Fixed Yso.mode autoswitch so idle/init no longer forces `bash`.
- Idle fallback now defaults to `combat` (off-style/default state), which prevents automatic Occultist bash upkeep from summoning entourage entities on login/idle.
- Added sticky manual bash preservation:
  • explicit `mbash` / `mhunt` continues to stay in bash until you change it.
  • autoswitch will not rip you out of a manual bash selection just because combat timers expire.
- Changed `Yso.mode.on_disengage()` to return to `combat` instead of `bash`.
  • disengaging no longer backslides into automatic bash upkeep.

Audit notes:
- Re-synced both patched mode scripts into the bundled `Yso system.xml` export.
- Lua syntax check passed for:
  • modules/Yso/xml/yso_modes.lua
  • modules/Yso/xml/yso_mode_autoswitch.lua
- XML parse check passed for the patched `Yso system.xml`.
- Verified the bundled export no longer contains:
  • `Yso.mode.set("bash", reason or "idle")`
  • `function M.on_disengage(reason) return M.set("bash", ... )`

Update (2026-03-07) — Class-scoped defensive segregation (Occultist vs Magi)
------------------------------------------------------------------------------------------------
Changes applied to the superseding Yso systems.zip workspace and bundled Yso system.xml export:
- Added shared class tracking helpers under Yso.classinfo with GMCP + class-swap-line support:
  • gmcp.Char.Status / gmcp.Char.Vitals refresh Yso.class
  • text fallback: ^You are now a member of the (\w+) class\.$
- Occultist-only defensive automation is now hard-gated by detected class so it will not emit while on Magi:
  • auto Priestess tarot self-heal
  • auto Magician tarot mana-heal
  • auto Fool tarot cleanse
  • Occultist escape-button tarot / Domination fallback chain
  • Occultist bash-upkeep / primebond helper / occie aura parser now consult the shared class gate
- Bundled Yso system.xml was also patched in-place for the XML-only Domination defense helpers that are not yet mirrored into disk Lua files.

Audit notes:
- Performed a second syntax audit on all changed disk Lua files plus the patched XML-only defense helper bodies before re-zipping.
- Magi-specific defensive behavior remains a separate future layer; this pass only prevents Occultist tarot / Domination defense logic from bleeding into Magi.

Update (2026-03-07) — Common route contract hooks + conservative truename branch gating
------------------------------------------------------------------------------------------------
Changes applied to the superseding Yso systems.zip workspace:
- Route interface now provides a canonical `ensure_hooks()` helper so combat routes expose the full lifecycle hook surface as callable stubs even when a hook is currently a no-op.
- `group_damage` and `occ_aff_burst` now advertise the full lifecycle hook set in their route contracts and register stub hooks through the shared interface helper.
- Orchestrator arbitration now supports narrow route-local preemption over shared universal categories when an action explicitly marks `prefer_over_shared=true`.
- `occ_aff_burst` now applies a conservative truename entry gate:
  • requires 2 stable pulses before entering the cleanseaura/truename mini-branch
  • keeps the truename work folded into parent-route explain output rather than exposing a separate branch state
  • records the prior non-truename checkpoint so aborts naturally resume from the earlier phase checkpoint
  • marks truename-branch EQ actions as route-local-preferred for the narrow cases where they should beat shared universal layers

Audit notes:
- Refreshed xml mirror Lua files from the patched combat/core sources.
- Performed a second parse audit on the patched combat/core route files plus their xml mirrors before re-zipping.

Update (2026-03-07) — Combat-mode Occultist affliction burst route + cleanseaura aff-side planner
------------------------------------------------------------------------------------------------
Changes applied to the superseding Yso systems.zip workspace and bundled Yso system.xml export:
- Added a new orchestrated duel route: `occ_aff_burst`.
  • Scope: combat mode only (not hunt, not party).
  • Burst flow: mana-bury -> cleanseaura -> truename availability -> whispering madness -> mentals -> enlighten gate -> speed strip -> utter truename -> command minion.
- Added a shared `Yso.off.oc.cleanseaura` planner surface and implemented the new `plan_aff()` branch for mana-burst work.
  • Limb-side namespace remains available; this pass adds the affliction-side planner rather than replacing legacy limb concepts.
- Offense driver now understands `occ_aff_burst` as a first-class route and auto-resolves combat mode to that route when policy=`auto`, while party damage still resolves to `group_damage`.
- Group damage route now asks the driver for the current resolved route instead of hard-reading only `state.active`, so combat/party routing stays under one authority.
- Skillchart-aligned command semantics were used for this pass:
  • `PINCHAURA <target> <defence>` only for aura defences such as speed.
  • `ATTEND <target>` is used for blind/deaf correction when aura intel says those are suppressing mental-passive value.
  • `COMMAND MINION AT <target>` is the execute entity command for the unravel finish window.

Audit notes:
- Synced the new route and driver changes into the xml mirrors and the bundled Yso system.xml inside the workspace zip.
- Firelord was intentionally left out of this route pass per current planning direction.

Update (2026-03-07) — Orchestrator single-authority pass
------------------------------------------------------------
This pass finishes the structural ownership move so automated Occultist offense emits now belong to the orchestrator only.

Changes:
- group_damage remains the active route module, but only as an orchestrator proposal source.
- offense_driver remains for policy/active-route state, not direct route ticking.
- occultist_offense is now helper-only and no longer auto-registers into the pulse bus.
- route-off cleanup stays staged as `order loyals passive` and resolves through orchestrator commit.

Recommended next live checks:
- confirm only one automated emit path fires per wake
- confirm group_damage OFF sends exactly one `order loyals passive` through orchestrator
- confirm no stale occultist_offense route emits appear when policy=auto and active=group_damage

Update (2026-03-06) — Occultist group_damage structural realignment (HL/SENS/CLUM core + slickness optional)
----------------------------------------------------------------------------------------------------------------
Changes applied to BOTH the disk workspace and Yso system.xml / Yso system.mpackage export:
- Corrected group_damage route contract to keep:
  • core required affs = healthleech + sensitivity + clumsiness
  • optional 4th support = slickness
- Reworked group_damage planning around the clarified route rules:
  • refresh dropped core affs immediately
  • if healthleech is missing but the other two core affs are present, EQ continues repeatable `warp <target>` while ENTITY rebuilds via worm
  • if healthleech is present and full burst is available, pair EQ `warp <target>` with ENTITY `command firelord at <target> healthleech`
  • if only one of those paired burst lanes is ready, the burst is held until both are ready
- Target intake for group_damage is now AK-target only.
- Route-off cleanup now uses `order loyals passive` (all loyals), replacing stale entourage-only cleanup in this route.
- Group_damage entity selection now favors route-critical or better follow-up value contributions first:
  • worm for healthleech
  • storm for clumsiness
  • bubonis/slime opportunistically for asthma-based slickness/paralysis follow-up
  • sycophant / bloodleech / hound / humbug / chimera as lower-priority support pressure
- BAL lane fallback support added for non-damage windows:
  • aeon
  • hangedman
  • ruinated justice

Audit notes:
- Removed a stale duplicate core-count helper left during the patch pass.
- Removed the last route-local `order entourage passive` fallback string from the commit hook.
- Synced the patched group_damage.lua back into the in-zip Mudlet XML export and the standalone mpackage XML so both exports reflect the same route logic.

Update (2026-03-06) — group_damage sync pass: keep storm + normalize slime + helper/audit repair
-------------------------------------------------------------------------------------------------
Changes applied to the ZIP workspace and the in-zip Mudlet XML export (Ysindrolir/Occultist/mudlet_packages/Yso system.xml):
- Kept STORM in the group_damage entity plan and optional-third support role.
- Normalized SLIME usage to plain syntax only:
  • command slime at <target>
  (no trailing affliction argument).
- group_damage entity priority now supports:
  • worm for missing healthleech
  • slime for missing sensitivity
  • storm for missing clumsiness
  • then normal damage rotation
- Repaired internal helper mismatches in group_damage.lua that would have caused runtime failures / stale state:
  • added local target / EQ / BAL / room-id helpers
  • restored _tkey / _worm_active aliases used elsewhere in the module
  • fixed worm/syc duration config key mismatches
  • fixed commit-hook mark helpers so worm/syc timers latch on actual send
- Shared Occultist entity rotation in this workspace now includes slime while retaining storm.

Audit notes:
- Synced the patched group_damage.lua into the in-zip Mudlet XML export so the disk workspace and bundled XML are aligned for this pass.
- Reviewed the patched route for unresolved references from the previous upload before re-zipping.
- README updated to reflect the current route-specific core for group_damage:
  • healthleech + sensitivity are the core setup
  • clumsiness remains the optional third support affliction

Update (2026-03-04) — group_damage.lua parse fix + follow_mode policy scoping
----------------------------------------------------------------------------
- Fixed group_damage.lua Lua syntax error ('<eof>' expected near 'end') by removing an extra stray `end` in GD.tick().
- Yso.off.driver follow_mode now applies ONLY when policy="auto" (active policy is never overridden).
- Reminder: per-target immediate Sycophant refresh-on-target-change is SUPPRESSED (30s gating is respected).

(See the top-level Yso systems/README.txt for the full patch log.)


Update (2026-03-03) — Offense Driver (active route only) + per-target Sycophant refresh + shieldbreak hard pre-empt
---------------------------------------------------------------------------------------------------------------
Changes applied to BOTH the disk workspace AND Yso system.xml (Mudlet import):
- New single top-level dispatcher: Yso.off.driver
  • Runs ONE offense route per pulse flush (policy="auto" by default).
  • When enabled, other offense ticks early-return unless invoked by the driver.
  • Pulse handler: "offense_driver" at order -10 (runs before all other offense callbacks).
  • Manual control:
      - lua Yso.off.driver.toggle(true|false)
      - lua Yso.off.driver.set_policy("active"|"auto")
      - lua Yso.off.driver.set_active("occultist_offense"|"group_damage"|"clock")

- Emitter safety: Yso.emit now marks pulse _did_emit during a flush
  • Prevents multiple offense callbacks from emitting in the same wake-cycle.

- Sycophant: per-target immediate refresh (ignores the 30s gating on target swap)
  • group_damage.lua: on target change, forces "command sycophant at <tgt>" as the first eligible entity command.
  • yso_occultist_offense.lua: same forced sycophant-on-target-change behavior.

- Shieldbreak priority:
  • yso_occultist_offense.lua now hard-preempts shieldbreak as EQ-only/solo and returns (no entity piggyback).

Notes:
- The forced Sycophant fires once per new target as soon as the entity lane is ready (it is suppressed if shieldbreak fires first).
- If you prefer automatic selection, switch driver policy to "auto" (clock -> group_damage -> occultist_offense) based on enabled modules.

Update (2026-03-02) — Central AEON module (shared across routes)
---------------------------------------------------------------
- Added: modules/Yso/xml/yso_aeon.lua (Yso.occ.aeon)
  • Shared request()/tick() controller for AEON application.
  • Uses READAURA speed truth + PINCHAURA speed strip + a verified 3s post-SIP window (Option A).
  • Tarot AEON fling is enforced as BAL-only/solo (outd aeon&&fling aeon at <tgt>), clearing other staged lanes.
- Added ingest shims so AK READAURA def lines populate Yso.occ aura snapshots:
  • Yso.ingest.aura_begin / aura_def / aura_end
- Entity lane hardening:
  • Yso.state.ent_ready() is now false while off-balance (prevents entity sends during Tarot AEON recovery).

Update (2026-03-02) — Limb route fixes (Odd limb route log analysis)
--------------------------------------------------------------------------------
Based on "Odd limb route" battle log analysis:

1. Instills over bodywarp: Limb route now prioritizes PURE LIMB PRESSURE before
   support instills. Order: pinchaura → interlink → BODYWARP → SHRIVEL+CRONE →
   support affs (asthma, slickness, paralysis, anorexia) → AEON → Enervate → Lust.

2. INTERLINK added: Limb route now uses INTERLINK before BODYWARP (config:
   lim_use_interlink=true, cds.interlink=3.0). Interlink binds target for warping.

3. Lust de-prioritized: Lust manaleech moved to end of limb route (after Enervate).
   Enervate is primary mana drain; Lust only when nothing else to do.

4. Config: lim_use_interlink, cds.interlink added to Cleanseaura C.cfg.


Update (2026-03-02) — XML corruption repair + _entry.lua fix + entourage normalization + readaura hardening
--------------------------------------------------------------------------------------------------------------
Repairs applied to: Yso system.xml, Yso offense aliases.xml, _entry.lua

XML corruption fix (root cause of persistent "missing scripts" on reload):
- Replaced all 6 instances of raw && with &amp;&amp; inside <script> tags.
  Raw & is illegal in XML and caused Mudlet's parser to silently drop script blocks.
  Affected locations: group_damage anti-tumble Lust, Empress pull, tumble-begin, tumble-out, leap-out.

_entry.lua — duplicate oc_isCurrentTarget block removed:
- Lines 155-168 contained a leftover duplicate of the oc_isCurrentTarget function body
  (14 lines of dead code between the function's closing `end` and the `if` guard's closing `end`).
- This syntax error could cause the entire _entry.lua loader to fail, preventing all
  filesystem-based Yso modules from loading.

"order loyals" normalized to "order entourage" everywhere:
- Yso system.xml: 5 instances fixed (party-mode kill/passive, GD.cfg.off_passive_cmd,
  GD OFF echo, GD.tick fallback).
- Yso offense aliases.xml: 1 instance fixed (^entpass$ alias).
- Now consistent with the Cleanseaura clock_loyals_on_cmd / clock_loyals_off_cmd config.

Readaura bug fixes re-applied (were missing from restored backup):
- ^ra$ alias: changed isActive="no" to isActive="yes"; added set_readaura_ready(false, "manual_ra")
  before sending so manual usage correctly marks cooldown.
- Readaura Refusal trigger: fixed broken call chain (was checking ak.deleteFull but calling
  Yso.deleteFull); now checks Yso.deleteFull with deleteLine() fallback.
- aura_finalize: added pending-target mismatch debug warning (logs when finalize target
  differs from _aura_pending.t). Added 8-second fallback tempTimer to re-enable
  readaura_ready if the AK cooldown trigger never fires.

Structural validation:
- Both Yso system.xml and Yso offense aliases.xml confirmed valid XML (PowerShell [xml] parse).
- _entry.lua confirmed clean nesting with no orphaned blocks.

Cleanseaura limb-route logic verified intact (not modified, all components present):
- Config: route, lim_affs_for_aeon, lim_pinchaura_order, lim_bodywarp_lesser, entity timers,
  clock_loyals_on_cmd/off_cmd.
- Helpers: _route_is_limb, _lb_hits, _pick_limb_target, _limb_support_count,
  _mark_entity_window, _entity_window_allows, _entity_cmd, _next_limb_entity,
  _append_limb_entity, _aura_up, _next_pinchaura_def, _clock_loyals_on/_off.
- LIMB planner: entity priming (worm then sycophant), timer refresh, pinchaura strip
  (speed + caloric), support affs, AEON gate, outd lust&&fling lust manaleech,
  Enervate pressure, BODYWARP + SHRIVEL + CRONE pure limb pressure with entity riders.
- C.toggle: resets priming flags + loyals ON/OFF on clock toggle.
- ^aff$ and ^lim$ aliases in Yso offense aliases.xml confirmed present.


Update (2026-03-01) — Cancel Lust/Empress automation + pause offense on leap-out
--------------------------------------------------------------------------------
Changes applied to BOTH the disk workspace AND Yso system.xml (Mudlet import):
- CANCELLED Lust/Empress reactive automation:
  • yso_offense_coordination.lua: tumble_begin/tumble_out no longer auto-queue Lust/Empress (config-gated).
  • group_damage.lua: anti-tumble + empress-pull rescue is now disabled by default (GD.cfg.rescue_lust_empress=false).
- Leap-out behavior:
  • On: "<tgt> leaps ... to the <dir>." offense automation is PAUSED (EQ/BAL/ENTITY lane payloads halted)
    via Yso.pause_offense(true, "target_leap_out").
  • Setting a new target auto-resumes offense: Yso.targeting.set() calls Yso.pause_offense(false, "target_set", true).
- Emitter safety:
  • Api stuff: added Yso.pause_offense()/Yso.offense_paused() and a small emit() gate that blocks emits tagged as offense
    while paused (opts.reason heuristics).

Notes:
- If you ever want to re-enable the old reactions, set:
    Yso.off.coord.cfg.lust_empress_automation = true
    GD.cfg.rescue_lust_empress = true


Update (2026-03-01) — Freestyle-only payload policy + lane wake cleanup
---------------------------------------------------------------------------
Changes applied to the disk workspace + Yso system.xml (Mudlet import):
- Payload mode is now LOCKED to: as_available (freestyle).
  • Removed the old "legacy paired" (paired) switchpoint. `legacy paired` no longer exists as a command.
  • `freestyle` remains available to re-assert the mode, but it always resolves to as_available.
- Removed redundant disk-level tempRegexTrigger "failsafe" duplicates for entity lane readiness inside the pulse bus.
  • Entity/EQ/BAL lane wakes now come from the XML Pulse triggers + GMCP vitals only.
  • This prevents duplicate lane wake reasons and keeps live-testing signal clean.

Notes:
- This does NOT attempt to perfect 1v1 group_damage behavior; the focus here is correctness of EQ/BAL/ENTITY lane readiness + wake.
- Next: offline lane tests to measure and tune per-lane wake timing / throttles.

Update (2026-02-28) — DRY-run lane lab: no ENT spend / no lock mutation
-----------------------------------------------------------------------
Fixes applied to BOTH the disk workspace AND Yso.mpackage:
- DRY-run correctness: when Yso.net.cfg.dry_run == true,
  • Yso.queue.commit() no longer calls Yso.locks.note_payload/note_send (prevents ENT from flipping DOWN during lane lab).
  • Yso.queue.emit() no longer hard-spends ENT (set_ent_ready(false)) during DRY.
  • Yso.net.emit_payload() no longer flips ENT DOWN during DRY.
Result:
- Devtools “Lane Lab” tests match expectation: lanes only change when you explicitly toggle them (ylane ...), not because a DRY commit mutated state.


Update (2026-02-28) — Devtools alias fix + entity lane re-stage + qtype mapping + bootstrap non-clobber
---------------------------------------------------------------------------------------
Fixes applied to BOTH the disk workspace AND Yso.mpackage:
- Devtools: ^yreload/^yinit no longer dofile() a dead hardcoded path (C:\Achaea\Occultist\lua\init.lua).
  • yreload now prefers Yso.reload() when available; otherwise it attempts a disk bootstrap load from the workspace root.
- Queue lane mapping: legacy qtype strings no longer mis-route BAL into EQ.
  • "ebc!p!w!t" => bal, "ec!p!w!t" => eq.
- Entity lane: on "disregards your order" / cooldown-fail, the last entity COMMAND is re-staged (best-effort) so pressure isn't lost.
- Payload classifier: ORDER is treated as FREE lane (not entity lane), and COMMAND gremlin/soulmaster are excluded from entity spend.
- Bootstrap: secondary bootstrap no longer clobbers package.path; it now guards on _G.yso_bootstrap_done and prepends patterns.
- Integration.mudlet: RELEASE installs (mpackage-only) no longer error; Integration.mudlet is provided via package.preload fallback.


Update (2026-02-28): wrappers fixed + use Yso_FIXED.mpackage.

    Yso Occultist Modules Bundle
    ===========================


Update (2026-02-27) — Entity lane hardening (no-more "disregard" deadlock)
-----------------------------------------------------------------------
- SSOT entity lane now has timed recovery on send/fail:
  • Added Yso.state.ent_busy(seconds) which schedules a recovery timer.
  • Yso.locks.note_payload() detects COMMAND <entity> and applies per-entity cooldowns.
  • Prevents stalls when "You may command another entity..." is missed or when a disregard flips flags.
- Yso.pulse.entity_ack("sent") now calls P.wake() (prevents silent stall if ready line is missed).
- ORDER <minion> is no longer treated as an entity-balance lane action in pulse pipeline parsing.
- Added disk-level failsafe triggers for:
  • "You may command another entity to do your bidding." (sets entity lane ready)
  • "<entity> disregards your order." (sets short backoff + timed recovery)
- Skill chart update:
  • Added missing Lycantha (Hound) AB id + cooldown (2.20s entity).

    Intended install location (matches your Mudlet bootstrap):
      C:\Achaea\Yso\modules\

    This zip contains:
      - Integration/mudlet.lua  (Mudlet trigger bridge: require("Integration.mudlet"))
      - Yso/_entry.lua          (disk-workspace loader; loads Yso/xml/*.lua in order)
      - Yso/xml/*               (canonical scripts you should edit)

    Wrapper modules (compat shims):
      - The tiny modules under Yso/ (Core/*, Combat/*, etc.) are convenience shims.
      - These were previously corrupted (self-require recursion). They are now fixed to:
          • require("Yso") (loads _entry)
          • return the best-effort canonical namespace (or Yso)

    Mudlet import:
      - Import Yso_FIXED.mpackage (included at ZIP root).
      - The older Yso.mpackage could import “missing scripts” due to XML corruption.

    Mudlet Bootstrap snippet (paste into a Mudlet script):

      _G.yso_default_package_path = _G.yso_default_package_path or package.path
      local root = "C:/Achaea/Yso/modules"
      root = tostring(root):gsub("\\","/"):gsub("/+$","")
      if not package.path:find(root .. "/?.lua", 1, true) then
        package.path = (root .. "/?.lua") .. ";" .. package.path
      end
      if not package.path:find(root .. "/?/init.lua", 1, true) then
        package.path = (root .. "/?/init.lua") .. ";" .. package.path
      end

    Quick test (Mudlet input line):
      lua pcall(require, "Integration.mudlet")
      lua pcall(require, "Yso")
      lua pcall(require, "Combat.offense_core")
========================================
CLEANUP + BUGFIXES APPLIED (2026-02-23 10:02Z)
- Fixed Q._stage -> Q._staged (_queue_has_staged)
- Added Q.clear(lane) if missing
- api_stuff cmd_sep default -> && (via pipe_sep)
- softlock_gate legacy qtype 'ebc!p!w!t!' -> 'eq'
- yso_queue autocommit forced false (if present)
- bootstrap auto_roots loop no longer capped at 3 (best-effort)
- Deleted: duel_limbs / unravel_* / duplicates / desktop.ini / Bug fixes.pdf (inside archive)
================================================================================
PARTY MODE + GROUP DAMAGE PATCH (2026-02-24)
- Added new Yso.mode "party" with subroutes: party aff / party dam
  • Includes tempAlias support: mode / mode <hunt|combat|party> / party [aff|dam] / partyroute <aff|dam>
  • Party route "dam" auto-starts group_damage driver (Yso.off.oc.dmg or Yso.off.oc.group_damage)
  • Party route "aff" placeholder (driver not implemented yet)
  • Leaving party mode stops ONLY the group_damage driver started by party (ownership tracking)
- Mode autoswitch now RESPECTS party mode (will not flip you hunt/combat while party is active)
- Pipeline separator policy updated:
  • Default separator is "&&" (Achaea CONFIG SEPARATOR)
  • Yso.net/Yso.queue now allow "&&" as a valid separator (in addition to "|" and ";;")
- group_damage send path refactored:
  • Lane-aware emission (free/eq/class/bal) with readiness gating (Yso.locks/Yso.state)
  • No server-side QUEUE commands; emits via Yso.emit/Yso.queue.emit
- Duplicates removed from workspace zip:
  • Deleted nested duplicate tree: "Yso systems/Yso systems/..."
  • Deleted: desktop.ini
========================================

========================================
ENTITY LANE BOOTSTRAP + PAIRED FALLBACK (2026-02-26)
- Entity readiness no longer gets stuck false across reloads:
  • If GMCP charstats shows 'Entity: Yes' and there is no active backoff,
    Yso.state.ent_ready() will bootstrap to true when stale.
- Payload mode 'paired' no longer hard-stalls when entity lane is down:
  • commit() will still allow EQ/BAL to drip while waiting for ENTITY to recover
    (ENTITY will not be emitted solo from the paired-branch).
- Group damage driver updated to match the above semantics:
  • Tries to include ENTITY in opener/setup, but does not stall if entity is down.
========================================

========================================
GROUP DAMAGE AUTOMATION FIXES (2026-02-26)
- Fixed fatal XML-export escape bug in yso_queue.lua (\" tokens) that prevented Yso.queue/Yso.net from loading.
- group_damage now performs lazy pulse registration on enable (fixes load-order skips).
- group_damage registers at pulse order=0 so it is not starved by orchestrator (order=1, exclusive) when enabled.
- party dam route always claims ownership, so leaving party reliably stops group_damage.
========================================

========================================
MUDLET IMPORT + PACKAGE PARITY FIX (2026-02-26)
- yso_modes.lua output avoids "\\n" escape sequences (uses string.char(10)) to prevent import-time quote issues.
- Simplified party-dam echo quoting (single-quote string build).
- Removed legacy: group_damage_queue_DEPRECATED.lua (old queue-based driver) from the mpackage; group_damage.lua is canonical.
========================================

========================================
DIAGNOSTIC FIXES (2026-02-27) — LUST / EMPRESS / ANTI-TUMBLE
- Implemented stateful rescue in group_damage.lua (GD):
  • GD.mark_tumble(tgt, dir) + GD.mark_tumble_out(tgt, diru)
  • GD.mark_empress_fail() -> 10s backoff to prevent Empress spam
  • GD.mark_lust_landed(tgt) -> wakes empress retry immediately
  • Tick ordering: stop_pending + enabled guards run before rescue logic (no empress-after-stop).
  • Adds presence/timeout safety so pending empress does not stick forever.

- yso_offense_coordination.lua:
  • Added _gd() / _gd_enabled() helpers and guards to prevent double-firing when GD is enabled.
  • Soulmaster anti-tumble command is dispatched on EQ lane (eq_clear), not class/entity.
  • tumble_out trigger now marks GD state (GD.mark_tumble_out) before falling back to legacy reaction.

- Mudlet triggers (in Yso.mpackage):
  • "Empress fail" now calls GD.mark_empress_fail().
  • "Lusted target" regex fixed (% -> $) and expanded pronouns including:
    (?:he|she|it|they|faes|faen|fae|them)
========================================


========================================
Update (2026-02-28) — Group Damage Log Tightening (freestyle/as_available)
--------------------------------------------------------------------
Freestyle / as_available payload isolation
- Added lane wake reasons:
  • lane:eq / lane:bal emitted on GMCP 0→1 regain (Yso.locks.sync_vitals)
  • lane:class emitted when entity balance becomes ready (Yso.state.set_ent_ready)
- Yso.queue.commit() now honors opts.wake_lane in as_available:
  • Emits ONLY the waking lane (plus FREE) to prevent piggybacking EQ on entity wake.
- group_damage.lua now consumes pulse reasons and emits per-lane in as_available:
  • If both lanes wake in the same flush, emits each lane separately (FREE opener only once).

Worm (COMMAND WORM) duration gating (~20s)
- Fixed clock mismatch in group_damage worm gating:
  • group_damage.lua now uses Yso.util.now() (seconds; converts getEpoch ms) for worm_until timers.
  • Prevents re-commanding worm every entity balance due to treating 20s as ~20ms.

Entity lane failure handling
- Added entity failure trigger: "<entity> disregards your order." now forces entity lane not-ready/backoff.

- Worm is treated as a ~20s DoT per target:
  • Tracks a per-target worm window (~20s) and avoids re-commanding until it expires.
  • Healthleech is applied on the chewing/tick message, so overlap with instill healthleech is waste.
- Overlap guard:
  • Drops/replaces "instill <tgt> with healthleech" if worm (or entity HL pressure) is already in play.
  • Prefers "instill <tgt> with sensitivity" when available, otherwise skips the redundant HL instill.

Locks hygiene
- Fixed an indentation/structure bug where L.sync_vitals() and L.note_payload() were being defined inside L.note_send().
  These are now defined once (stable SSOT behavior).


Update (2026-02-28) — oc_isCurrentTarget shim + Sycophant automation + mode-alias collision fix
------------------------------------------------------------------------------------------
Fixes:
- Added global back-compat shim `oc_isCurrentTarget(who)` so legacy triggers like “Target - eat” / “Standing” no longer error with:
  `attempt to call global 'oc_isCurrentTarget' (a nil value)`.
  • Implemented in disk loader (_entry.lua) and in mpackage early-load script (Yso.state).

- Group damage route (party dam): added Sycophant (Rixil) vitals pressure to BOTH payload styles:
  • Freestyle (as_available) and Combo (paired).
  • Emits `command sycophant at <target>` when Rixil is missing, gated ~30s per target (tracks send-success).

- Mode aliases: removed Yso’s `^hunt$` mode alias (it clobbered Legacy’s hunt automation).
  • New mode alias: `^mhunt$` (mode switch only).
  • Added a one-time cecho reminder: type `party` to use the group-damage route (default: party dam).


Update (2026-02-28) — Storm syntax + Sycophant 30s + entity cooldown stability
---------------------------------------------------------------------------------------
Fixes applied to BOTH the disk workspace AND Yso.mpackage:
- Storm syntax: group damage route no longer appends an affliction argument.
  • Uses: COMMAND STORM AT <target>
- Sycophant automation: group damage route now commands sycophant purely on an internal per-target timer (30s),
  not on rixil aff-score (since rixil has no reliable expiry line).
  • Uses: COMMAND SYCOPHANT AT <target>
  • Starts/refreshes a 30s per-target gate when emitted.
- Freestyle/as_available opener: when no explicit wake-lane is known (e.g. initial toggle), ENTITY lane is preferred
  so an entity command is actually included in the opener when possible.
  • Additionally, when EQ wakes and ENTITY is also ready (but didn’t explicitly wake), ENTITY is piggybacked onto EQ.
- Entity cooldown stability:
  • Added DOMINATION storm cooldown mapping (2.20s) to the entity cooldown table.
  • Fixed P.entity_ack() timestamp unit mismatch (getEpoch ms vs seconds) so re-stage-on-fail works reliably.
  • Added failsafe trigger for: "You may not command another entity so soon." -> applies cooldown backoff + re-stage.

Notes:
- These changes specifically target the log pattern where ENTITY is marked ready, but storm is still rejected as too soon,
  producing "disregards your order" / "may not command another entity so soon" loops.
Update (2026-02-28) — Mudlet Lua parse fix (stray backslash-escaped quotes)
--------------------------------------------------------------------------
Fixes applied to BOTH the disk workspace AND Yso.mpackage:
- Fixed Lua syntax errors in the Mudlet scripts:
  • Yso Scripts/Core scripts/Api stuff
  • Yso Scripts/Core scripts/Yso list of functions
- Root cause: auto-export contained code like type(fn)==\"function\" (illegal outside strings).
- Patch: replaced those with type(fn)=="function".


=== Patch Notes (2026-03-04) ===
- FIX: Disabled automatic target clearing on movement (not_in_room) by default.
  - New config: Yso.cfg.target_autoclear_not_in_room (default false).
  - When false, Room.Players/Room.Characters presence checks do NOT clear your target.
- CHANGE: Offense driver default policy is now "manual" (no automation on login).
- CHANGE: Offense driver default active route is "none" (idle until you select a route).

Next pass alignment:
- Convert group_damage to propose(ctx) (route API) first.
- Add kernel + lane state machine scaffolding (lane-ready flip driven; coalescing EQ>ENT>BAL).
- Keep devtools disabled/dry off by default on load.


=== Patch Notes (2026-03-07) ===
- STRUCTURE: Added a new Occultist phase-one entity framework via `entity_registry.lua`.
  - Split responsibilities across `Domination reference` (reference data), `entity_registry.lua` (selector/state), and route/orchestrator consumers.
- GROUP DAMAGE: Reworked entity selection to use ranked legal candidates instead of route-local rotation.
  - Phase-one entity roster: worm, storm, slime, sycophant, humbug, firelord.
  - Reserved paired burst is now explicit: Firelord is reserved only for the healthleech warp pair when EQ is ready.
  - Bootstrap now anchors on worm + sycophant, with exact bootstrap exit behavior wired into the selector.
  - Optional support includes humbug(addiction when primebonded) and slime follow-up pressure; optional slickness can be instilled when EQ is free and no higher-priority work exists.
- ORCHESTRATOR: Stamps the solved category per lane for debug/audit visibility.
- LIFECYCLE: Added entity invalidation tracking with target-swap clear, AK-valid revalidation clear, manual-success clear, and a small timeout fallback.
- CLEANUP: Fixed Occultist affmap storm syntax note to `COMMAND STORM AT <tgt>`.

Audit focus for this pass:
- Static integrity of the new entity registry integration.
- Route still uses AK target intake and route-off `order loyals passive`.
- Next live test focus should be entity invalidation clears, bootstrap exit, and reserved Firelord pairing.


[2026-03-07] Source-of-truth restructuring
- Promoted the active Occultist combat stack into the modular Lua tree.
- Treat modules/Yso/Core and modules/Yso/Combat as the canonical editable source for the promoted files.
- Treat modules/Yso/xml as export mirrors/staging only for those promoted files.
- Added EXPORT_MANIFEST.lua and tools/refresh_xml_mirrors.lua to keep modular source and xml mirrors aligned before rebuilding Yso system.xml.
- Promoted files this pass: orchestrator, wake_bus, offense_driver, domination_reference, entity_registry, group_damage, offense_helpers.
- Unpromoted xml files remain legacy until migrated in later structural passes.

2026-03-07 route-interface planning patch:
- Added canonical Occultist common route-contract source at modules/Yso/Combat/route_interface.lua
- Shared universal categories are now defense_break and anti_tumble
- Recommended orchestrator override policy is narrow_global_only (hard global conditions + shared universal categories only)
- group_damage now advertises the common route contract while keeping its route-local categories separate
- Magi folder left untouched

2026-03-07 aff-burst alias/toggle patch:
- Added a real permanent `^aff$` Mudlet alias to the main Yso system package (not tempAlias-only behavior).
- `^aff$` now toggles the Occultist duel affliction burst automation ON/OFF instead of merely setting a route flag.
- ON behavior:
  - forces combat mode,
  - sets offense driver enabled,
  - sets driver policy to `auto`,
  - sets active route to `occ_aff_burst`,
  - sets cleanseaura compatibility route to `aff`.
- OFF behavior:
  - disables `occ_aff_burst`,
  - sets driver active route to `none`,
  - returns driver policy to `manual`.
- Added `AB.toggle() / AB.start() / AB.stop()` to the `occ_aff_burst` module in both canonical route source and xml mirror.
- Mirrored the same `^aff$` behavior into `Yso offense aliases.xml` so the sidecar alias pack stays in sync.

Audit:
- Lua syntax checked for both `occ_aff_burst.lua` route copies.
- Mudlet XML parsed after alias insertion and embedded-script refresh.
- README updated so the alias/toggle behavior is documented in-package.
- Removed the temporary post-utter entity filler from `occ_aff_burst`; execute window now reserves for truename utterance without auto-commanding an unsupported follow-up entity action.

Update (2026-03-07) — Bash mode rename + non-Occultist bash-upkeep guard
-----------------------------------------------------------------------
Fixes applied to the disk workspace and refreshed Yso system XML:
- Renamed Yso PvE play-mode semantics from `hunt` to `bash`.
  • Canonical mode names are now: `bash`, `combat`, `party`.
  • `mode bash` and `^mbash$` are the primary bash-mode entry points.
  • Back-compat remains for legacy `mode hunt` / `^mhunt$`, but they normalize to `bash`.
- Fixed Occultist-only bash upkeep so it no longer runs on non-Occultist classes.
  • Prevents Occultist entity/orb/pathfinder/hound upkeep from firing while on classes like Magi.
  • PRIMEBOND bash/combat refresh remains Occultist-gated.
- Refreshed mode autoswitch to idle back into `bash` instead of `hunt`.
- XML alias cleanup:
  • Replaced the old static `Hunt mode` alias with `Bash mode` using `^mbash$`.

Audit:
- Rechecked for active `Yso.mode.set("hunt", ...)` usage in the patched mode scripts and XML alias block.
- Confirmed no bash-upkeep command path can send Occultist summon/entity commands unless class == `Occultist`.

