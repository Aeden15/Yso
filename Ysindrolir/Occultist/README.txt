Yso System - Occultist Combat Automation for Achaea (Mudlet)
============================================================
Last updated: April 21, 2026


Current status
--------------
This package now uses a unified wake/queue/route contract across active routes.
Route decision logic remains route-local (Sunder-style), while transport and loop
control are shared:

  line events -> wake bus -> queue/emit -> ack payload -> route callbacks -> mode loop

The mode timer loop remains the owner of periodic ticks. Wake/ack nudges only
request immediate re-evaluation.


Active routes
-------------
  oc_aff             - Occultist duel affliction route
  group_damage       - Occultist party damage route (team dam)
  group_aff          - Occultist party affliction route (team aff)
  magi_focus         - Magi duel convergence route
  magi_group_damage  - Magi party damage route (team dam)
  magi_dmg           - Magi duel damage route
  alchemist_group_damage - Alchemist party damage route (adam / team dam)


Wake + lane events
------------------
Pulse wake-line triggers are centralized through:
  modules/Yso/Core/wake_bus.lua

Handled line sources:
  line:eq_recovered
  line:bal_recovered
  line:eq_blocked
  line:bal_blocked
  line:eq_queued
  line:bal_queued
  line:eq_run
  line:bal_run
  line:entity_ready
  line:entity_down
  line:entity_missing

Behavior:
  clean-line cechos via Yso.util.cecho_line(...)
  optional gagging of source lines (deleteLine)
  route-loop nudges via Yso.mode.nudge_route_loop(...)

BAL blocked trigger coverage includes both:
  You must regain balance first.
  Balance used:


Route payload/ack contract
--------------------------
Routes emit through the shared route helper (RouteInterface) and now pass explicit:
  opts.route
  opts.target

Ack payloads retain legacy top-level lane fields, and now include richer metadata:
  lanes
  meta.route
  meta.target
  route_by_lane
  target_by_lane

Waiting/in-flight lifecycle is normalized for active routes:
  set on successful emit
  clear on ack / route off / reset paths


Sync workflow
-------------
From Ysindrolir/Occultist:

  lua tools/refresh_xml_mirrors.lua
  .\tools\rebuild_yso_system_xml.ps1

The PowerShell wrapper runs strict XML parse validation after rebuild.


Rebuild hardening
-----------------
tools/rebuild_yso_system_xml.lua now fails fast on forbidden control bytes in:
  injected script bodies
  final rebuilt XML

This prevents writing corrupted package XML artifacts.


Testing
-------
Primary regression suite (run from repository root):
  lua Ysindrolir/Occultist/tests/test_occ_aff_loop_requeue.lua
  lua Ysindrolir/Occultist/tests/test_queue_writhe_block.lua
  lua Ysindrolir/Occultist/tests/test_magi_focus.lua
  lua Ysindrolir/Occultist/tests/test_magi_group_damage.lua
  lua Ysindrolir/Occultist/tests/test_alchemist_group_damage.lua
  lua Ysindrolir/Occultist/tests/test_reliability_sweep.lua

Contract tests added for unified wake/ack flow:
  lua Ysindrolir/Occultist/tests/test_wake_route_contract.lua
  lua Ysindrolir/Occultist/tests/test_magi_dmg.lua


Generated artifacts
-------------------
Canonical source is under:
  modules/Yso/Core
  modules/Yso/Combat
  modules/Yso/Integration

XML mirrors are generated under:
  modules/Yso/xml

Primary package artifact:
  ../mudlet packages/Yso system.xml
