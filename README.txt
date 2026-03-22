Yso Systems Workspace
=====================
Last updated: March 21, 2026

This root README is now a workspace snapshot rather than a changelog.
Class-specific detail lives in the class folders.

Current fixes
-------------
  Occultist offense is now alias-owned end to end. Shared send memory lives in
  offense_state.lua, and the old orchestrator is no longer part of the active
  route pipeline.

  The wake bus now retries staged queue commits on lane wakes. Manual lane
  aliases such as cleanse can queue while EQ is down and flush on reopen.

  The stale generic package:
    Ysindrolir/mudlet packages/Devtools.xml
  has been retired. Split devtools sources now live at:
    Ysindrolir/Occultist/Occultist Devtools.xml
    Ysindrolir/Magi/MagiDevtools.xml

  Export artifacts were refreshed from the canonical workspace sources,
  including Yso system.xml and the wake-bus/queue mirrors that feed it.

Documentation map
-----------------
  Ysindrolir/Occultist/README.txt
    Occultist architecture, routes, aliases, export notes, and current status.

  Ysindrolir/Magi/README.txt
    Magi-specific notes, helper files, and current package status.

  Ysindrolir/Occultist/modules/Yso/xml/README_EXPORT_ONLY.txt
    Canonical-vs-exported file notes for the Occultist package.

Workspace layout
----------------
  Ysindrolir/Occultist/
    Canonical Occultist source, route logic, integration modules,
    and export inputs for Yso.

  Ysindrolir/Magi/
    Magi-specific helpers and class-local package notes.

  Ysindrolir/mudlet packages/
    Exported Mudlet packages, including:
      Yso system.xml
      AK.xml
      Yso offense aliases.xml
      limb.1.2.xml

Notes
-----
  Yso system.xml is rebuilt from the Occultist source tree.
  AK.xml is maintained separately and may also carry compatibility patches.
  Root-level docs should stay class-agnostic now that this workspace supports
  more than one class.
