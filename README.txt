Yso systems status - May 5, 2026
================================

Supported classes are Magi and Alchemist, plus shared Yso core. Removed class
stacks are not active automation paths in this repo or in the Mudlet package.

Mudlet workflow (package-first)
-------------------------------
- Canonical runtime: install/import Ysindrolir/mudlet packages/, especially
  Yso system.xml (and .mpackage exports when used). Behavior comes from
  embedded scripts and Mudlet script load order.
- Do not activate routes with runtime require()/pcall(require, ...). Do not use
  YSO_ROOT, package.path, or repo-root probing for route loading. Globals such
  as Yso and route tables are set up by the package's script order.
- Operating: use package aliases/toggles in Mudlet (e.g. Magi mdam, mfocus,
  mgd; Alchemist adam, aduel). Combat mode plus per-route toggles drive offense.
- Repo tree: Lua under Ysindrolir/Yso/ and Ysindrolir/Alchemist/ is the git
  source. Ysindrolir/scripts/export_yso_system_xml.ps1 is optional maintenance
  to re-embed scripts into Yso system.xml when working split-layout sources --
  not mandatory for everyday play if you edit the package in Mudlet.

Kept in tree
------------
- Shared Yso core, curing, queue, routes, targets, AK/Legacy integration.
- Magi and Alchemist class automation.
- Neutral Yso.entities API for future class-neutral pet support.

Tests: Ysindrolir/Yso/Tests and rebuilds/ (Magi, Alchemist, shared).

Optional Yso.net.cfg.dry_run (defaults off) suppresses live sends for local tests.

Recent patch notes (summary)
---------------------------
- May 2026: queue ADD/clearfull, Alchemist temper/physiology/evaluate fixes,
  wrack legality and alias cleanup, optional export script coverage for XML sync.
- April 2026: Alchemist route resets, evaluate gates, Aurify/lane payloads,
  homunculus parser fix, Mudlet package triggers synced where noted.

Older notes that mentioned bootstrap loaders, package.path, or require chains
describe superseded experiments; live loading is Mudlet package order only.
