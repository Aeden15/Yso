Yso Systems Workspace
=====================
Last updated: March 29, 2026

This root README is now a workspace snapshot rather than a changelog.
Class-specific detail lives in the class folders.

Current fixes
-------------
  Legacy Occultist basher ATTEND opener -- Legacy Basher V2.1.xml now uses
  gmcp.IRE.Target.Info.hpperc for denizen HP gating and auto-queues
  attend @tar as the first Occultist bashing action on a new denizen target at
  >=100% HP, then re-queues ATTEND if that same target drops below full and
  later returns to >=100%. ATTEND state resets on hunt-off and kill transitions.

  XML mirrors synced with canonical sources — all bug fixes from the canonical
  Lua modules (Bugs 3, 6, 8, 10-13 + aurum bucket) are now applied to the
  Mudlet-facing XML mirror copies under xml/. Both canonical and XML surfaces
  match.

  Escape button separator ownership fixed — yso_escape_button.lua no longer
  initializes global Yso.sep to ";;". It now inherits Yso.sep/Yso.cfg and
  falls back to "&&", so load order cannot override the canonical separator.
  Its _now() helper also normalizes millisecond getEpoch() values.

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

Syncing with OneDrive Desktop
-----------------------------
  The "Yso systems" folder on your Desktop is synced by OneDrive.
  sync_workspace.ps1 mirrors files between the git clone and that
  Desktop folder so changes flow in both directions.

  First-time setup:
    1. Clone the repo OUTSIDE OneDrive (e.g. C:\repos\Yso).
       OneDrive lock-file conflicts can corrupt .git internals.

         git clone https://github.com/Aeden15/Yso.git C:\repos\Yso

    2. Make sure "Yso systems" exists on your Desktop.  The script
       auto-detects common OneDrive Desktop paths such as:
         %USERPROFILE%\OneDrive\Desktop\Yso systems
         %USERPROFILE%\Desktop\Yso systems
       Pass -DesktopPath explicitly if yours differs.

  Push repo changes to the Desktop:
    cd C:\repos\Yso
    .\sync.cmd push            # repo -> Desktop
    .\sync.cmd push -DryRun    # preview only

  Pull Desktop edits back into the repo:
    cd C:\repos\Yso
    .\sync.cmd pull            # Desktop -> repo
    git diff                   # review
    git add -A && git commit -m "sync from desktop"
    git push

  Execution policy note:
    If calling sync_workspace.ps1 directly gives a "running scripts is
    disabled" error, use sync.cmd instead — it passes -ExecutionPolicy
    Bypass automatically.  Or unlock .ps1 scripts for your user once:

      Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned

  What gets synced:
    Repo  Ysindrolir/         <->  Desktop  Yso systems/Ysindrolir/
    Repo  README.md/.txt      <->  Desktop  Yso systems/README.md/.txt

  Git-only files (.git/, .gitignore, etc.) are excluded automatically.
