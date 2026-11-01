# Achaea workspace link

The independent **Yso Workspace Link** package provides a one-command update path
for the Mudlet profile named **Achaea**. Other profiles cannot use it and install
no file watches. AK and Yso still run from embedded XML scripts in native Mudlet
load order; no route Lua files are loaded from disk at runtime.

## One-time setup

First run `scripts/publish_workspace_link.ps1` from the workspace to prepare the
validated XML receipts. They are local build artifacts and are not stored in Git.

Import `mudlet packages/Yso Workspace Link.xml` into **Achaea**, or run:

```lua
lua installPackage([[C:/Users/shuji/OneDrive/Desktop/Yso systems/Ysindrolir/mudlet packages/Yso Workspace Link.xml]])
```

Stop all combat/hunting routes, disable Legacy Basher, and clear their outstanding
queues. Run `ysolink`. It verifies both workspace XMLs, saves a complete profile
backup, then converts the existing AK and Yso system package installations into
native modules. AK loads first (priority 0), then Yso (priority 1).
Save the profile after setup completes so those module settings are retained.

The original package names must be exactly `AK` and `Yso system`. An existing
module pointing somewhere else is refused rather than replaced. The bridge stays
outside these modules so its controls survive reloads.

## Future edits

1. Edit workspace Lua and rebuild the affected XML using its existing scoped builder.
2. Run `scripts/publish_workspace_link.ps1` in the workspace. It parses both XMLs
   and publishes byte-exact validation snapshots plus the extracted Lua bodies.
   Mudlet compiles those bodies with its own Lua version before replacing anything.
   A built XML that differs from its validated snapshot is refused.
3. Mudlet reports that the built XML changed. File watches notify only.
4. While automation is stopped, run **`ysoreload`**. It updates AK then Yso without
   manually importing either XML. Run **`ysostatus`** to inspect their state.

Both modules are refreshed together. Editing Lua without rebuilding its XML does
not change the running profile. Rebuilds and Git pushes remain separate from
applying an update in Mudlet. The bridge never restarts offense automatically.

## File ownership and recovery

Workspace XMLs are read-only inputs. Modules point to copies under
`getMudletHomeDir()/yso-workspace/modules/`; module synchronization is disabled.
This prevents Mudlet profile saves or editor changes from overwriting workspace
sources. Applied snapshots are stored separately from Mudlet's editable module
copies so a profile save does not create false workspace-change notices.

Initial profile backups are under `yso-workspace/backups/`. Before each module is
replaced, its existing profile-local XML is retained as `<name>.previous.xml`.
Reload errors stop the sequence and report partial completion; live Lua state is
not transactionally rolled back. The failed module's prior staging file is restored
when available. Correct the built XML and rerun `ysolink`/`ysoreload`, or restore the
profile backup through Mudlet's profile manager if migration failed.

If native module loading takes longer than 20 seconds, the bridge keeps the update
busy, refuses retries and route starts, and holds offense paused until the late
completion arrives. A timeout does not cancel a deferred Mudlet reload. If it
never completes, restart the profile before retrying. Staging bytes are checked
again on completion to detect concurrent profile-save writeback. A terminal
failure leaves offense paused until you correct it; a successful update restores
the prior pause state without starting any route.

The self-affliction and serverside-policy install-once hooks are explicitly
rearmed after Yso reload; existing affliction rows and curing configuration remain.
No game commands are issued by the bridge itself.
Reloaded modules can run their normal initialization queries.

Rebuild the bridge with `scripts/build_workspace_link_package.ps1`; verify with
`scripts/test_workspace_link_package.ps1`. Ordinary changes to AK/Yso do not
require reinstalling the bridge. Changes to the bridge controller itself require
reimporting its small standalone package once.
