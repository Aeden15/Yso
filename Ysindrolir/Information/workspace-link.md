# Coordinated Yso releases and workspace updates

The independent **Yso Workspace Link** controller manages the **Achaea** profile. It never disconnects the game or starts combat. Source XMLs are read-only inputs; installed modules use profile-local copies with synchronization disabled.

## Check the whole system

**`ysocheck`** produces a read-only readiness report: authentication, packages/APIs, release consistency, curing, route blockers, queued work, class suspension, equipment, supplies, startup work, and required restarts. `Yso.system.check({echo=false})` returns structured results. `scope='install'` omits gameplay authentication requirements. Checks do not send discovery commands, alter priorities, or repair configuration.

**`ysostatus`** shows workspace/release state and the last update error. Before Yso is installed, the standalone controller can run `ysoinstall` and its installation preflight without relying on Yso globals.

## Build a verified release

Use PowerShell 7 with Lua 5.4 and `luac` on PATH. Rebuild edited sources with their scoped builders, then run:

```powershell
pwsh -NoProfile -File './Ysindrolir/scripts/verify_yso.ps1'
pwsh -NoProfile -File './Ysindrolir/scripts/build_yso_release.ps1'
```

The verifier supplies standalone fixtures, executes package wrappers in disposable copies, compiles embedded Lua, checks parity and credentials, and writes JSON results plus logs. Fixture-only Lua suites are reported as covered by their wrappers. GitHub Actions uses the same verifier.

The release builder verifies a frozen source snapshot and publishes the exact checked package bytes in an immutable directory under `Ysindrolir/releases/`. `current.json` selects the bundle. Failures preserve the previous selection. Generated releases and local receipts are excluded from Git and synchronization; rebuild them locally after syncing.

Managed packages: Legacy Core, AK, limb support, Yso, Legacy Basher, Legacy UI, and the workspace controller. The manifest records identities, dependency order, hashes, and restart policy. Older standalone Stormhammer exports and `Target things` remain optional; detected overlap is reported rather than installed automatically.

## Install or update the full bundle

1. Import the built `mudlet packages/Yso Workspace Link.xml` bootstrap controller into **Achaea**.
2. Wait until you have logged out normally. Installation requires a confirmed disconnected state using Mudlet 4.12+ APIs and fails closed if status is unknown. It never disconnects you.
3. Run **`ysoinstall`**. It validates the manifest, hashes, receipts, and native Lua before replacement, verifies profile/managed-file backups, then applies modules in dependency order using completion events.
4. Wait for completion, then restart the profile before connecting or resuming automation. This retires old globals, handlers, and timers.
5. Log in normally and run **`ysocheck`**. Resolve blocking results before explicitly starting offense or hunting.

Profile settings and unrelated packages are preserved. Rebuilding or pushing to GitHub does not perform a live installation.

## AK/Yso-only hot updates

**`ysolink`** and **`ysoreload`** remain for the narrower AK/Yso path while automation is stopped. Publish byte-exact local receipts using `scripts/publish_workspace_link.ps1` after scoped rebuilds. A coordinated installation permits hot updates only when non-hot package hashes are unchanged and the published release matches the proposed AK/Yso bytes. Legacy, UI, Basher, limb, or controller changes require offline `ysoinstall` and a restart.

The first coordinated installation uses `ysoinstall`; missing or unreadable installed-release metadata cannot establish safe non-hot peers and therefore blocks the narrower update path.

File watches only notify; they never apply changes. AK reloads before Yso. Updates never restart routes automatically.

## Failure and recovery

Preflight failures occur before replacement. Later failures can leave a partial update; the controller reports it and leaves offense blocked. Native deferred reloads cannot be canceled by killing a timer, so a timeout remains waiting for completion and rejects overlapping retries.

Inspect `ysostatus` and the reported backup under `getMudletHomeDir()/yso-workspace/backups/`. Correct the source/release and retry after the prior operation settles. If uncertain, restore the verified profile backup using Mudlet's profile manager. Restoring staged XML alone does not roll back live Lua globals. A pending-install marker survives restart and prevents inconsistent packages from being treated as ready.

## Alchemist and networking policy

Alchemist offense defaults disabled: routes, offensive aliases, queued helpers, and Legacy hunting. Tracking and self-curing utilities remain. Future explicit enable uses `Yso.alchemist_offense.set_enabled(true)` after access returns; imports/checks never enable it. Physiology diagnostics use optional guarded trace events without hard-coded files or a `yajl` requirement.

Discord feedback/install posting and embedded credentials are removed. Historical exposed tokens still require owner-side revocation. Legacy's independent updater is disabled so it cannot overwrite managed releases. Character data uses validated caches until a secure endpoint is verified; no HTTP fallback is enabled. Cached online status is historical.

Connection-drop, interrupted-install and reload tests use simulated APIs. Verification never intentionally interrupts a live game session.
