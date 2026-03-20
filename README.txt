Yso Systems Workspace
=====================
Last updated: 2026-03-18

This root README is now a workspace index.
Class-specific notes live in the class folders.

Blademaster Spar 3 follow-up patches are now reflected in the Occultist
workspace, including aff-route free-lane parry injection, opener READAURA
forcing, AK cure/reopen tracking adjustments, and the Legacy Blademaster
mobility reprio ladder. See Ysindrolir/Occultist/README.txt for the detailed
per-file notes.


Documentation Map
-----------------
  Ysindrolir/AFFLICTION_CURES.txt
    Shared Achaea affliction list (action, herbal cure, alchemical cure).
    Reference for both Magi and Occultist (curative types, predict_cure, offense).

  Ysindrolir/Occultist/README.txt
    Occultist architecture, routes, READAURA tracking, export notes,
    and current automation status.

  Ysindrolir/Magi/README.txt
    Magi-specific notes, helpers, and future Magi-only work.

  Ysindrolir/Occultist/modules/Yso/xml/README_EXPORT_ONLY.txt
    Canonical-vs-exported file notes for the Occultist package.


Workspace Layout
----------------
  Ysindrolir/Occultist/
    Canonical Occultist source, route logic, integration modules,
    and export inputs for Yso.

  Ysindrolir/Magi/
    Magi-specific helpers and class-local notes.

  Ysindrolir/mudlet packages/
    Exported Mudlet packages, including:
      Yso system.xml
      AK.xml


Notes
-----
  Yso system.xml is rebuilt from the Occultist source tree.
  AK.xml is maintained separately and may also carry compatibility patches.
  This Desktop workspace is intended to be the primary working copy for
  editing, Cursor, Mudlet, and git operations so code changes and commits
  happen in the same folder.
  The separate Documents/GitHub clone can be kept as a fallback copy, but it
  should not be the place where changes are manually re-synced before commit.
  Root-level docs should stay class-agnostic now that this workspace supports
  more than one class.
